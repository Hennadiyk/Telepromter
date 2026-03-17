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

    // Tracks whether the user has intentionally started the camera session
    // nonisolated(unsafe) because it is read from @Sendable NotificationCenter closures on the main queue
    @ObservationIgnored nonisolated(unsafe) private var userWantsSessionRunning = false

    @ObservationIgnored @AppStorage("selectedResolution") var selectedResolution: VideoResolution = .hd1080 {
        didSet { updateCameraSettings() }
    }
    @ObservationIgnored @AppStorage("selectedFrameRate") var selectedFrameRate: FrameRate = .fps30 {
        didSet { updateCameraSettings() }
    }
    @ObservationIgnored @AppStorage("contdownOnOff") var countdownOnOff: Bool = false
    @ObservationIgnored @AppStorage("selectedCountdown") var selectedCountdown = 3

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

        captureSession.sessionPreset = preset
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
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            let compatibleFormat = device.formats.first { format in
                let supportsResolution = format.isSupported(for: resolution)
                let supportsFrameRate = format.videoSupportedFrameRateRanges.contains {
                    $0.minFrameRate <= frameRate && $0.maxFrameRate >= frameRate
                }
                return supportsResolution && supportsFrameRate
            }

            if let format = compatibleFormat {
                device.activeFormat = format
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
            } else if let fallback = device.formats.first(where: { $0.isSupported(for: resolution) }) {
                device.activeFormat = fallback
                let maxFPS = fallback.videoSupportedFrameRateRanges.sorted { $0.maxFrameRate < $1.maxFrameRate }.last?.maxFrameRate ?? 30.0
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFPS))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
                Task { @MainActor [weak self] in
                    self?.postAlert(message: "Frame rate \(Int(frameRate)) fps not supported. Using \(Int(maxFPS)) fps.")
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.postAlert(message: "No compatible format found for \(resolutionName)")
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

    var id: Int { rawValue }
}
