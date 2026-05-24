//
//  VideoCameraViewModel.swift
//  Teleprompter
//
//  Created by Hennadiy Kvasov on 6/12/25.
//

import Foundation
import AVFoundation
import Photos
import UIKit
import AVKit
import SwiftUI
import CoreMedia
import Observation

@Observable @MainActor
final class VideoCameraViewModel: NSObject {
    var isRecording = false
    var countdown: Int? = nil
    var showAlert = false
    var alertMessage = ""
    var isSessionRunning = false
    var recordingTime: TimeInterval = 0
    var lastVideoThumbnail: UIImage?
    var lastVideoLocalURL: URL?
    var deviceOrientation: UIDeviceOrientation = .unknown
    var audioLevel: Float = 0.0
    var videoSavedToPhotos = false
    var audioLevelsBuffer: [Float] = Array(repeating: 0.0, count: 40)
    var isFrontCamera = true
    var availableZoomOptions: [ZoomOption] = []
    var selectedZoomFactor: Double = 1.0
    var isSavingVideo = false
    var showAspectGuides: Bool = true
    var isSwitchingCamera = false

    /// Frame rates actually supported by the front camera at the selected resolution.
    var supportedFrameRates: [FrameRate] {
        guard let camera = currentCamera ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return FrameRate.allCases
        }
        let resolution = selectedResolution.preset
        let maxFPS = camera.formats
            .filter { $0.mediaType == .video && $0.isSupported(for: resolution) }
            .flatMap { $0.videoSupportedFrameRateRanges }
            .map { $0.maxFrameRate }
            .max() ?? 30
        return FrameRate.allCases.filter { Double($0.rawValue) <= maxFPS }
    }

    // Tracks whether the user has intentionally started the camera session
    // nonisolated(unsafe) because it is read from @Sendable NotificationCenter closures on the main queue
    @ObservationIgnored nonisolated(unsafe) private var userWantsSessionRunning = false

    var selectedResolution: VideoResolution = .uhd4K {
        didSet {
            UserDefaults.standard.set(selectedResolution.rawValue, forKey: "selectedResolution")
            // Clamp frame rate if no longer supported at the new resolution
            if !supportedFrameRates.contains(selectedFrameRate) {
                selectedFrameRate = supportedFrameRates.last ?? .fps60
            } else {
                updateCameraSettings()
            }
        }
    }
    var selectedAspectRatio: VideoAspectRatio = .portrait {
        didSet { UserDefaults.standard.set(selectedAspectRatio.rawValue, forKey: "selectedAspectRatio") }
    }
    var selectedFrameRate: FrameRate = .fps60 {
        didSet {
            UserDefaults.standard.set(selectedFrameRate.rawValue, forKey: "selectedFrameRate")
            updateCameraSettings()
        }
    }
    var countdownOnOff: Bool = false {
        didSet { UserDefaults.standard.set(countdownOnOff, forKey: "contdownOnOff") }
    }
    var selectedCountdown: Int = 3 {
        didSet { UserDefaults.standard.set(selectedCountdown, forKey: "selectedCountdown") }
    }

    // AVFoundation objects accessed from sessionQueue — not Sendable, marked nonisolated(unsafe)
    @ObservationIgnored nonisolated(unsafe) private let captureSession = AVCaptureSession()
    @ObservationIgnored nonisolated(unsafe) private let videoOutput = AVCaptureMovieFileOutput()
    @ObservationIgnored nonisolated(unsafe) private let audioOutput = AVCaptureAudioDataOutput()
    @ObservationIgnored nonisolated(unsafe) private var currentCamera: AVCaptureDevice?
    @ObservationIgnored nonisolated(unsafe) private var currentInput: AVCaptureDeviceInput?
    // fps and zoom to apply once the session starts (virtual devices only)
    @ObservationIgnored nonisolated(unsafe) private var pendingPostStartFrameRate: Double? = nil
    @ObservationIgnored nonisolated(unsafe) private var pendingPostStartZoom: Double? = nil
    // set synchronously on the main thread before the session stops so fileOutput can read it
    @ObservationIgnored nonisolated(unsafe) private var recordingStoppedByBackground = false
    @ObservationIgnored private var recordingTimer: Timer?
    @ObservationIgnored private var countdownTimer: Timer?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "video.sessionQueue")

    override init() {
        super.init()
        if let raw = UserDefaults.standard.string(forKey: "selectedResolution"),
           let value = VideoResolution(rawValue: raw) { selectedResolution = value }
        if let raw = UserDefaults.standard.string(forKey: "selectedAspectRatio"),
           let value = VideoAspectRatio(rawValue: raw) { selectedAspectRatio = value }
        if let raw = UserDefaults.standard.object(forKey: "selectedFrameRate") as? Int,
           let value = FrameRate(rawValue: raw) { selectedFrameRate = value }
countdownOnOff = UserDefaults.standard.bool(forKey: "contdownOnOff")
        let countdown = UserDefaults.standard.integer(forKey: "selectedCountdown")
        if countdown > 0 { selectedCountdown = countdown }
        setupPreviewLayer()
        setupOrientationObserver()
        setupAppLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePreviewOrientation() }
        }
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.userWantsSessionRunning == true else { return }
            // Flag set synchronously so fileOutput can read it before any async hop
            self?.recordingStoppedByBackground = true
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else {
                    self?.recordingStoppedByBackground = false
                    return
                }
                self.stopRecording()
            }
            self?.sessionQueue.async { [weak self] in
                self?.captureSession.stopRunning()
                Task { @MainActor [weak self] in self?.isSessionRunning = false }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.userWantsSessionRunning == true else { return }
            Task { @MainActor [weak self] in self?.restartSession() }
        }

        NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            guard self?.userWantsSessionRunning == true else { return }
            self?.sessionQueue.async { [weak self] in
                self?.captureSession.stopRunning()
                Task { @MainActor [weak self] in self?.isSessionRunning = false }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            guard self?.userWantsSessionRunning == true else { return }
            Task { @MainActor [weak self] in self?.restartSession() }
        }
    }

    /// Fully tears down and rebuilds the session to recover from interruptions.
    func restartSession() {
        let preset = selectedResolution.preset
        let frameRate = Double(selectedFrameRate.rawValue)
        let resolution = selectedResolution.preset
        let resolutionName = selectedResolution.rawValue
        let useFront = isFrontCamera
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            for input in self.captureSession.inputs { self.captureSession.removeInput(input) }
            for output in self.captureSession.outputs { self.captureSession.removeOutput(output) }
            self.captureSession.commitConfiguration()
            self.currentInput = nil
            self.currentCamera = nil
            self.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName, useFrontCamera: useFront)
            self.startSessionOnSessionQueue()
        }
    }

    func updatePreviewOrientation() {
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation.isValidInterfaceOrientation {
            deviceOrientation = currentOrientation
        }
        guard let rotationCoordinator = rotationCoordinator else { return }
        guard let connection = previewLayer.connection else { return }
        previewLayer.frame = UIScreen.main.bounds
        connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
    }

    func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        let preset = selectedResolution.preset
        let frameRate = Double(selectedFrameRate.rawValue)
        let resolution = selectedResolution.preset
        let resolutionName = selectedResolution.rawValue

        if videoStatus == .authorized && audioStatus == .authorized {
            userWantsSessionRunning = true
            sessionQueue.async { [weak self] in
                self?.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName, useFrontCamera: true)
                self?.startSessionOnSessionQueue()
            }
        } else if videoStatus != .denied && audioStatus != .denied {
            requestPermissions { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.userWantsSessionRunning = true
                        self.sessionQueue.async { [weak self] in
                            self?.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName, useFrontCamera: true)
                            self?.startSessionOnSessionQueue()
                        }
                    } else {
                        self.postAlert(message: "Camera or microphone access denied")
                    }
                }
            }
        } else {
            postAlert(message: "Camera or microphone access denied")
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            Task { @MainActor [weak self] in
                if status == .denied || status == .restricted {
                    self?.postAlert(message: "Photo Library access denied. Please enable in Settings.")
                }
            }
        }
    }

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                completion(videoGranted && audioGranted)
            }
        }
    }

    func switchCamera() {
        withAnimation(.easeInOut(duration: 0.25)) { isSwitchingCamera = true }
        let frameRate = Double(selectedFrameRate.rawValue)
        let resolution = selectedResolution.preset
        let resolutionName = selectedResolution.rawValue
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.currentInput,
                  let currentCamera = self.currentCamera else { return }

            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            self.captureSession.removeInput(currentInput)

            let isCurrentlyFront = currentCamera.position == .front
            let newCamera: AVCaptureDevice?
            if isCurrentlyFront {
                newCamera = self.bestBackCamera()
            } else {
                newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            }

            guard let newCamera else {
                self.captureSession.addInput(currentInput)
                Task { @MainActor [weak self] in self?.postAlert(message: "Unable to switch camera") }
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.currentCamera = newCamera
                    self.currentInput = newInput
                    self.configureCameraSettingsOnSessionQueue(for: newCamera, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)

                    let zoomOptions = isCurrentlyFront ? self.buildZoomOptions(for: newCamera) : []
                    let defaultZoom = zoomOptions.first(where: { $0.label == "1×" })?.factor ?? 1.0

                    // Session is running during switchCamera — videoZoomFactor can be set now
                    if isCurrentlyFront && !newCamera.virtualDeviceSwitchOverVideoZoomFactors.isEmpty {
                        do {
                            try newCamera.lockForConfiguration()
                            newCamera.videoZoomFactor = CGFloat(defaultZoom)
                            newCamera.unlockForConfiguration()
                        } catch {}
                    }

                    Task { @MainActor [weak self] in
                        self?.isFrontCamera = !isCurrentlyFront
                        self?.availableZoomOptions = zoomOptions
                        self?.selectedZoomFactor = defaultZoom
                        self?.setupRotationCoordinator(for: newCamera)
                        withAnimation(.easeInOut(duration: 0.35)) {
                            self?.isSwitchingCamera = false
                        }
                    }
                } else {
                    self.captureSession.addInput(currentInput)
                    Task { @MainActor [weak self] in self?.postAlert(message: "Failed to add new camera input") }
                }
            } catch {
                self.captureSession.addInput(currentInput)
                Task { @MainActor [weak self] in
                    self?.postAlert(message: "Camera switch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func setZoom(_ factor: Double) {
        selectedZoomFactor = factor
        sessionQueue.async { [weak self] in
            guard let self, let camera = self.currentCamera else { return }
            do {
                try camera.lockForConfiguration()
                camera.ramp(toVideoZoomFactor: CGFloat(factor), withRate: 8.0)
                camera.unlockForConfiguration()
            } catch {}
        }
    }

    nonisolated private func bestBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        return session.devices.first
    }

    nonisolated private func buildZoomOptions(for device: AVCaptureDevice) -> [ZoomOption] {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { Double(truncating: $0) }
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor

        guard !switchOvers.isEmpty else {
            return [ZoomOption(factor: max(1.0, minZoom), label: "1×")]
        }

        let wideFactor = switchOvers[0]  // device factor that shows as "1×" to the user

        // Fixed display levels: 0.5×, 1×, 2×, 4×, 8×
        // 0.5× = ultrawide (device minZoom), others are multiples of wideFactor
        let targets: [(multiplier: Double, label: String)] = [
            (0.5, "0.5×"), (1.0, "1×"), (2.0, "2×"), (4.0, "4×"), (8.0, "8×")
        ]
        return targets.compactMap { target in
            let factor = target.multiplier == 0.5 ? minZoom : wideFactor * target.multiplier
            guard factor >= minZoom && factor <= maxZoom else { return nil }
            return ZoomOption(factor: factor, label: target.label)
        }
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let backgroundStop = recordingStoppedByBackground
        recordingStoppedByBackground = false

        if let error = error, !backgroundStop {
            Task { @MainActor [weak self] in self?.postAlert(message: "Recording failed: \(error.localizedDescription)") }
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isSavingVideo = true }
            let aspectRatio = await MainActor.run { self.selectedAspectRatio }
            let finalURL: URL
            if aspectRatio == .widescreen {
                finalURL = outputFileURL
            } else if let cropped = await self.exportCropped(from: outputFileURL, aspectRatio: aspectRatio) {
                finalURL = cropped
            } else {
                finalURL = outputFileURL
            }
            self.saveToPhotos(url: finalURL)
        }
    }

    nonisolated private func exportCropped(from inputURL: URL, aspectRatio: VideoAspectRatio) async -> URL? {
        let asset = AVURLAsset(url: inputURL)
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await videoTrack.load(.naturalSize),
              let preferredTransform = try? await videoTrack.load(.preferredTransform),
              let nominalFrameRate = try? await videoTrack.load(.nominalFrameRate),
              let duration = try? await asset.load(.duration) else { return nil }

        // Compute display size (accounts for rotation stored in the track transform)
        let isRotated = preferredTransform.b != 0 || preferredTransform.c != 0
        let displaySize = isRotated
            ? CGSize(width: naturalSize.height, height: naturalSize.width)
            : naturalSize

        let targetRatio = aspectRatio.size.width / aspectRatio.size.height
        let sourceRatio = displaySize.width / displaySize.height

        // Already the right ratio — no re-encode needed (e.g. portrait recording + 9:16 selected)
        if abs(targetRatio - sourceRatio) < 0.01 { return nil }

        var renderSize: CGSize
        if targetRatio > sourceRatio {
            let h = (displaySize.width / targetRatio / 2).rounded() * 2
            renderSize = CGSize(width: displaySize.width, height: h)
        } else {
            let w = (displaySize.height * targetRatio / 2).rounded() * 2
            renderSize = CGSize(width: w, height: displaySize.height)
        }

        let cropOrigin = CGPoint(
            x: (displaySize.width  - renderSize.width)  / 2,
            y: (displaySize.height - renderSize.height) / 2
        )

        // Compose: track preferred transform → then offset to center the crop
        let cropTransform = preferredTransform.concatenating(
            CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y)
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(cropTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        let fps = max(1, Int32(nominalFrameRate.rounded()))
        videoComposition.frameDuration = CMTime(value: 1, timescale: fps)
        videoComposition.instructions = [instruction]

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cropped_\(Date().timeIntervalSince1970).mov")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else { return nil }
        exporter.videoComposition = videoComposition

        do {
            try await exporter.export(to: outputURL, as: .mov)
            return outputURL
        } catch {
            return nil
        }
    }

    nonisolated private func saveToPhotos(url: URL) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSavingVideo = false
                if success {
                    self.lastVideoLocalURL = url
                    self.generateThumbnail(for: url)
                    self.videoSavedToPhotos = true
                } else {
                    self.postAlert(message: "Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        generator.generateCGImageAsynchronously(for: time) { [weak self] cgImage, _, _ in
            guard let cgImage else { return }
            let thumbnail = UIImage(cgImage: cgImage)
            Task { @MainActor [weak self] in self?.lastVideoThumbnail = thumbnail }
        }
    }

    func openInPhotosApp(videoURL: URL) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let videos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        guard let asset = videos.firstObject else { return }

        PHPhotoLibrary.shared().performChanges {} completionHandler: { success, _ in
            guard success else { return }
            Task { @MainActor in
                let localId = asset.localIdentifier
                if let photosURL = URL(string: "photos-redirect://\(localId)"),
                   UIApplication.shared.canOpenURL(photosURL) {
                    UIApplication.shared.open(photosURL)
                }
            }
        }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee,
              let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let byteCount = CMBlockBufferGetDataLength(dataBuffer)
        guard byteCount > 0 else { return }

        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: byteCount, destination: &bytes) == kCMBlockBufferNoErr else { return }

        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let rms: Float

        if isFloat {
            let count = byteCount / MemoryLayout<Float32>.size
            guard count > 0 else { return }
            let sum = bytes.withUnsafeBytes { ptr in
                ptr.bindMemory(to: Float32.self).reduce(0 as Float) { $0 + $1 * $1 }
            }
            rms = sqrt(sum / Float(count))
        } else {
            let count = byteCount / MemoryLayout<Int16>.size
            guard count > 0 else { return }
            let sum = bytes.withUnsafeBytes { ptr in
                ptr.bindMemory(to: Int16.self).reduce(0 as Float) { $0 + Float($1) * Float($1) }
            }
            rms = sqrt(sum / Float(count)) / Float(Int16.max)
        }

        let level = min(1.0, rms * 8)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.audioLevel = level
            self.audioLevelsBuffer.append(level)
            if self.audioLevelsBuffer.count > 40 {
                self.audioLevelsBuffer.removeFirst()
            }
        }
    }

    private func setupPreviewLayer() {
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
    }

    private func setupRotationCoordinator(for device: AVCaptureDevice) {
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        updatePreviewOrientation()
    }

    nonisolated private func setupCameraOnSessionQueue(
        preset: AVCaptureSession.Preset,
        frameRate: Double,
        resolution: AVCaptureSession.Preset,
        resolutionName: String,
        useFrontCamera: Bool
    ) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs { captureSession.removeInput(input) }
        for output in captureSession.outputs { captureSession.removeOutput(output) }
        currentInput = nil
        currentCamera = nil

        captureSession.automaticallyConfiguresApplicationAudioSession = false

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            let availableInputs = audioSession.availableInputs ?? []
            if let bluetoothInput = availableInputs.first(where: { $0.portType == .bluetoothHFP }) {
                try? audioSession.setPreferredInput(bluetoothInput)
            }
        } catch {
            // Bluetooth setup failed — fall back to basic audio session and continue
            try? audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
            try? audioSession.setActive(true)
        }

        let camera: AVCaptureDevice?
        if useFrontCamera {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            camera = bestBackCamera()
        }

        guard let camera else {
            Task { @MainActor [weak self] in self?.postAlert(message: "No camera available") }
            return
        }
        currentCamera = camera

        // Always use inputPriority — manual activeFormat selection gives precise fps control
        // and filters ALL ProRes variants (including 422 HQ which requires external storage).
        captureSession.sessionPreset = .inputPriority

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentInput = input
                configureCameraSettingsOnSessionQueue(for: camera, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)

                let zoomOptions = useFrontCamera ? [] : buildZoomOptions(for: camera)
                let defaultZoom = zoomOptions.first(where: { $0.label == "1×" })?.factor ?? 1.0

                if !useFrontCamera && !camera.virtualDeviceSwitchOverVideoZoomFactors.isEmpty {
                    // videoZoomFactor requires a running session — defer to post-start
                    pendingPostStartZoom = defaultZoom
                }

                Task { @MainActor [weak self] in
                    self?.isFrontCamera = useFrontCamera
                    self?.availableZoomOptions = zoomOptions
                    self?.selectedZoomFactor = defaultZoom
                    self?.setupRotationCoordinator(for: camera)
                }
            } else {
                Task { @MainActor [weak self] in self?.postAlert(message: "Failed to add camera input") }
                return
            }

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                Task { @MainActor [weak self] in self?.postAlert(message: "Failed to add video output") }
                return
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.postAlert(message: "Camera setup failed: \(error.localizedDescription)")
            }
            return
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
                if captureSession.canAddOutput(audioOutput) {
                    captureSession.addOutput(audioOutput)
                    audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audio_queue"))
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.postAlert(message: "Audio setup failed: \(error.localizedDescription)")
                }
                return
            }
        } else {
            Task { @MainActor [weak self] in self?.postAlert(message: "No audio device available") }
            return
        }
    }

    nonisolated private func configureCameraSettingsOnSessionQueue(
        for device: AVCaptureDevice,
        frameRate: Double,
        resolution: AVCaptureSession.Preset,
        resolutionName: String
    ) {
        // Find the best format: must support the requested resolution, and prefer the one
        // with the highest max frame rate that still meets or exceeds the requested fps.
        // Sort by descending maxFrameRate so we pick the format that exactly supports the
        // requested fps (or higher) at the requested resolution — not just any matching format.
        let candidateFormats = device.formats
            .filter { format in
                // Only standard H.264/HEVC formats — whitelist excludes ProRes and any unknown codec
                guard format.mediaType == .video else { return false }
                guard format.isStandardVideoCodec else { return false }
                guard format.isSupported(for: resolution) else { return false }
                return format.videoSupportedFrameRateRanges.contains {
                    $0.maxFrameRate >= frameRate
                }
            }
            // Prefer formats that exactly match the standard preset dimensions — oversized formats
            // (e.g. 4032x3024 on virtual cameras) technically pass the >= check but can cause
            // fps instability. Among exact matches, prefer the one closest to the requested fps.
            .sorted { a, b in
                let dimA = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                let dimB = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
                let targetW: Int32
                let targetH: Int32
                switch resolution {
                case .hd4K3840x2160:  targetW = 3840; targetH = 2160
                case .hd1920x1080:    targetW = 1920; targetH = 1080
                case .hd1280x720:     targetW = 1280; targetH = 720
                default:              targetW = 3840; targetH = 2160
                }
                let aExact = dimA.width == targetW && dimA.height == targetH
                let bExact = dimB.width == targetW && dimB.height == targetH
                if aExact != bExact { return aExact }
                let areaA = Int(dimA.width) * Int(dimA.height)
                let areaB = Int(dimB.width) * Int(dimB.height)
                if areaA != areaB { return areaA > areaB }
                let maxA = a.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                let maxB = b.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                return maxA < maxB  // prefer fps closest to (but >= ) requested
            }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            if let format = candidateFormats.first {
                // Setting activeFormat automatically changes the session preset to .inputPriority
                device.activeFormat = format
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
            } else {
                // No format supports the requested fps — fall back to max available fps at resolution
                let fallbackFormats = device.formats
                    .filter { $0.mediaType == .video && $0.isStandardVideoCodec && $0.isSupported(for: resolution) }
                    .sorted { a, b in
                        let maxA = a.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                        let maxB = b.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                        return maxA > maxB
                    }
                if let fallback = fallbackFormats.first,
                   let maxFPS = fallback.videoSupportedFrameRateRanges.map({ $0.maxFrameRate }).max() {
                    device.activeFormat = fallback
                    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFPS))
                    device.activeVideoMinFrameDuration = frameDuration
                    device.activeVideoMaxFrameDuration = frameDuration
                    Task { @MainActor [weak self] in
                        self?.postAlert(message: "\(Int(frameRate)) fps not supported at \(resolutionName). Using \(Int(maxFPS)) fps.")
                    }
                } else if let lastResort = device.formats.first(where: { $0.mediaType == .video && $0.isStandardVideoCodec }) {
                    // No format matches the requested resolution — use any compatible format to
                    // guarantee we never record with ProRes active on internal storage.
                    device.activeFormat = lastResort
                } else {
                    Task { @MainActor [weak self] in
                        self?.postAlert(message: "No compatible format found for \(resolutionName)")
                    }
                }
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.postAlert(message: "Failed to configure camera: \(error.localizedDescription)")
            }
        }
    }

    func startRecording() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("video_\(Date().timeIntervalSince1970).mov") else {
            postAlert(message: "Cannot create output file")
            return
        }
        isRecording = true

        if countdownOnOff {
            countdown = selectedCountdown
            var countdownValue = countdown
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    withAnimation(.smooth) {
                        if let current = countdownValue, current > 0 {
                            countdownValue = current - 1
                            self.countdown = countdownValue
                        } else {
                            timer.invalidate()
                            self.countdown = nil
                            if let connection = self.videoOutput.connection(with: .video),
                               let rotationCoordinator = self.rotationCoordinator {
                                connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
                            }
                            self.videoOutput.startRecording(to: url, recordingDelegate: self)
                            self.recordingTime = 0
                            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                                Task { @MainActor [weak self] in self?.recordingTime += 1 }
                            }
                        }
                    }
                }
            }
        } else {
            if let connection = videoOutput.connection(with: .video),
               let rotationCoordinator = rotationCoordinator {
                connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            }
            videoOutput.startRecording(to: url, recordingDelegate: self)
            recordingTime = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.recordingTime += 1 }
            }
        }
    }

    func stopRecording() {
        countdown = nil
        countdownTimer?.invalidate()
        videoOutput.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
    }

    func startSession() {
        userWantsSessionRunning = true
        sessionQueue.async { [weak self] in
            self?.startSessionOnSessionQueue()
        }
    }

    nonisolated private func startSessionOnSessionQueue() {
        if !captureSession.isRunning {
            captureSession.startRunning()
            applyVirtualCameraPostStartSettings()
            Task { @MainActor [weak self] in self?.isSessionRunning = true }
        }
    }

    nonisolated private func applyVirtualCameraPostStartSettings() {
        guard let camera = currentCamera,
              !camera.virtualDeviceSwitchOverVideoZoomFactors.isEmpty,
              let zoom = pendingPostStartZoom else { return }
        pendingPostStartZoom = nil
        pendingPostStartFrameRate = nil
        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = CGFloat(zoom)
            camera.unlockForConfiguration()
        } catch {}
    }

    func stopSession() {
        userWantsSessionRunning = false
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor [weak self] in self?.isSessionRunning = false }
            }
        }
    }

    private func postAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

    private func updateCameraSettings() {
        let frameRate = Double(selectedFrameRate.rawValue)
        let resolution = selectedResolution.preset
        let resolutionName = selectedResolution.rawValue
        sessionQueue.async { [weak self] in
            guard let self = self, let camera = self.currentCamera else { return }
            self.configureCameraSettingsOnSessionQueue(for: camera, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoCameraViewModel: AVCaptureFileOutputRecordingDelegate {}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension VideoCameraViewModel: AVCaptureAudioDataOutputSampleBufferDelegate {}

// MARK: - AVCaptureDevice.Format helpers
extension AVCaptureDevice.Format {
    /// True for standard capture formats (YUV). False for any ProRes variant.
    /// Capture format descriptions use pixel-format FourCCs (e.g. '420v', '420f'),
    /// not encoding codec types — so we blacklist ProRes rather than whitelisting H.264/HEVC.
    var isStandardVideoCodec: Bool {
        let subType = CMFormatDescriptionGetMediaSubType(formatDescription)
        let proResTypes: Set<FourCharCode> = [
            kCMVideoCodecType_AppleProRes4444XQ,
            kCMVideoCodecType_AppleProRes4444,
            kCMVideoCodecType_AppleProRes422HQ,
            kCMVideoCodecType_AppleProRes422,
            kCMVideoCodecType_AppleProRes422LT,
            kCMVideoCodecType_AppleProRes422Proxy,
            0x72777066, // ProRes RAW  ('rwpf')
            0x72777068  // ProRes RAW High ('rwph')
        ]
        return !proResTypes.contains(subType)
    }

    func isSupported(for preset: AVCaptureSession.Preset) -> Bool {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        switch preset {
        case .hd1280x720:   return dimensions.width >= 1280 && dimensions.height >= 720
        case .hd1920x1080:  return dimensions.width >= 1920 && dimensions.height >= 1080
        case .hd4K3840x2160: return dimensions.width >= 3840 && dimensions.height >= 2160
        default: return false
        }
    }
}

// MARK: - Enums
enum VideoResolution: String, CaseIterable, Identifiable {
    case hd720 = "720"
    case hd1080 = "1080"
    case uhd4K = "4k"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hd720:  return "720p"
        case .hd1080: return "1080"
        case .uhd4K:  return "4K"
        }
    }

    var preset: AVCaptureSession.Preset {
        switch self {
        case .hd720:  return .hd1280x720
        case .hd1080: return .hd1920x1080
        case .uhd4K:  return .hd4K3840x2160
        }
    }
}

enum FrameRate: Int, CaseIterable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
}

struct ZoomOption: Identifiable, Equatable {
    var id: Double { factor }
    let factor: Double
    let label: String
}

enum VideoAspectRatio: String, CaseIterable, Identifiable {
    case widescreen = "16:9"
    case classic    = "4:3"
    case square     = "1:1"
    case portrait43 = "3:4"
    case portrait   = "9:16"

    var id: String { rawValue }

    var label: String { rawValue }

    var size: CGSize {
        switch self {
        case .widescreen: return CGSize(width: 16, height: 9)
        case .classic:    return CGSize(width: 4,  height: 3)
        case .square:     return CGSize(width: 1,  height: 1)
        case .portrait43: return CGSize(width: 3,  height: 4)
        case .portrait:   return CGSize(width: 9,  height: 16)
        }
    }
}
