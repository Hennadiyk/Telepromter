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
    var audioLevelsBuffer: [Float] = Array(repeating: 0.0, count: 40)

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

    var selectedResolution: VideoResolution = .hd1080 {
        didSet {
            UserDefaults.standard.set(selectedResolution.rawValue, forKey: "selectedResolution")
            // Clamp frame rate if no longer supported at the new resolution
            if !supportedFrameRates.contains(selectedFrameRate) {
                selectedFrameRate = supportedFrameRates.last ?? .fps30
            } else {
                updateCameraSettings()
            }
        }
    }
    var selectedFrameRate: FrameRate = .fps30 {
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
    @ObservationIgnored private var recordingTimer: Timer?
    @ObservationIgnored private var countdownTimer: Timer?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "video.sessionQueue")

    override init() {
        super.init()
        if let raw = UserDefaults.standard.string(forKey: "selectedResolution"),
           let value = VideoResolution(rawValue: raw) { selectedResolution = value }
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
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            for input in self.captureSession.inputs { self.captureSession.removeInput(input) }
            for output in self.captureSession.outputs { self.captureSession.removeOutput(output) }
            self.captureSession.commitConfiguration()
            self.currentInput = nil
            self.currentCamera = nil
            self.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)
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
            sessionQueue.async { [weak self] in
                self?.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)
                self?.startSessionOnSessionQueue()
            }
        } else if videoStatus != .denied && audioStatus != .denied {
            requestPermissions { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.sessionQueue.async { [weak self] in
                            self?.setupCameraOnSessionQueue(preset: preset, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)
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

        PHPhotoLibrary.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                if status != .authorized {
                    self?.postAlert(message: "Photo Library access denied")
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

            let newPosition: AVCaptureDevice.Position = currentCamera.position == .back ? .front : .back
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
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
                    Task { @MainActor [weak self] in
                        self?.setupRotationCoordinator(for: newCamera)
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

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Task { @MainActor [weak self] in self?.postAlert(message: "Recording failed: \(error.localizedDescription)") }
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: outputFileURL, options: nil)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.lastVideoLocalURL = outputFileURL
                    self.generateThumbnail(for: outputFileURL)
                    self.postAlert(message: "Video saved to Photos")
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
        guard let channel = connection.audioChannels.first else { return }
        let power = channel.averagePowerLevel
        let normalizedLevel = min(1.0, pow(10, power / 20) * 4)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.audioLevel = normalizedLevel
            self.audioLevelsBuffer.append(normalizedLevel)
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
        resolutionName: String
    ) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Use .inputPriority for all cases so we can set activeFormat directly.
        // Setting device.activeFormat (done in configureCameraSettingsOnSessionQueue) automatically
        // switches the session preset to .inputPriority — we set it here proactively to avoid
        // the session trying to auto-configure the format when commitConfiguration() is called.
        captureSession.sessionPreset = .inputPriority
        captureSession.automaticallyConfiguresApplicationAudioSession = false

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            let availableInputs = audioSession.availableInputs ?? []
            if let bluetoothInput = availableInputs.first(where: { $0.portType == .bluetoothHFP }) {
                try audioSession.setPreferredInput(bluetoothInput)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.postAlert(message: "Failed to configure audio session for Bluetooth: \(error.localizedDescription)")
            }
            return
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            Task { @MainActor [weak self] in self?.postAlert(message: "No camera available") }
            return
        }
        currentCamera = camera

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentInput = input
                configureCameraSettingsOnSessionQueue(for: camera, frameRate: frameRate, resolution: resolution, resolutionName: resolutionName)
                Task { @MainActor [weak self] in self?.setupRotationCoordinator(for: camera) }
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
                // Only video-capable formats (exclude photo-only formats)
                guard format.mediaType == .video else { return false }
                guard format.isSupported(for: resolution) else { return false }
                return format.videoSupportedFrameRateRanges.contains {
                    $0.maxFrameRate >= frameRate
                }
            }
            // Among all qualifying formats, prefer larger dimensions (higher quality) then
            // the one whose max frame rate is closest to (but >= ) the requested rate.
            .sorted { a, b in
                let dimA = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                let dimB = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
                let areaA = Int(dimA.width) * Int(dimA.height)
                let areaB = Int(dimB.width) * Int(dimB.height)
                if areaA != areaB { return areaA > areaB }
                let maxA = a.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                let maxB = b.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                return maxA < maxB  // prefer lower (closer to requested) among equal-res formats
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
                    .filter { $0.mediaType == .video && $0.isSupported(for: resolution) }
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
            Task { @MainActor [weak self] in self?.isSessionRunning = true }
        }
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
            // Setting device.activeFormat inside configureCameraSettingsOnSessionQueue automatically
            // changes the session preset to .inputPriority — no manual preset change needed.
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
