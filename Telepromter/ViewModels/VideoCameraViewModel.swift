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

class VideoCameraViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    @Published var isRecording = false
    @Published var countdown: Int? = nil
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isSessionRunning = false
    @Published var recordingTime: TimeInterval = 0
    @Published var lastVideoThumbnail: UIImage?
    @Published var lastVideoLocalURL: URL?
    @Published var deviceOrientation: UIDeviceOrientation = .unknown
    @Published var audioLevel: Float = 0.0
    @Published var audioLevelsBuffer: [Float] = Array(repeating: 0.0, count: 40)
    
    @AppStorage("selectedResolution") var selectedResolution: VideoResolution = .hd1080 {
        didSet {
            updateCameraSettings()
        }
    }
    @AppStorage("selectedFrameRate") var selectedFrameRate: FrameRate = .fps30 {
        didSet {
            updateCameraSettings()
        }
    }
    @AppStorage("contdownOnOff") var countdownOnOff: Bool = false
    @AppStorage("selectedCountdown") var selectedCountdown = 3
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private var currentCamera: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var countdownTimer: Timer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    private let sessionQueue = DispatchQueue(label: "video.sessionQueue") // Serial queue for session operations
    
    override init() {
        super.init()
        setupPreviewLayer()
        setupOrientationObserver()
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
            self?.updatePreviewOrientation()
        }
    }
    
    func updatePreviewOrientation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentOrientation = UIDevice.current.orientation
            if currentOrientation.isValidInterfaceOrientation {
                self.deviceOrientation = currentOrientation
            }
            guard let rotationCoordinator = self.rotationCoordinator else { return }
            guard let connection = self.previewLayer.connection else { return }
            self.previewLayer.frame = UIScreen.main.bounds
            connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        }
    }
    
    func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if videoStatus == .authorized && audioStatus == .authorized {
            sessionQueue.async { [weak self] in
                self?.setupCamera()
                self?.startSession()
            }
        } else if videoStatus != .denied && audioStatus != .denied {
            requestPermissions { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.sessionQueue.async { [weak self] in
                            self?.setupCamera()
                            self?.startSession()
                        }
                    } else {
                        self?.showAlert(message: "Camera or microphone access denied")
                    }
                }
            }
        } else {
            showAlert(message: "Camera or microphone access denied")
        }
        
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status != .authorized {
                    self?.showAlert(message: "Photo Library access denied")
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
        sessionQueue.async { [weak self] in
            guard let self = self, let currentInput = self.currentInput, let currentCamera = self.currentCamera else { return }
            
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }
            
            self.captureSession.removeInput(currentInput)
            
            let newPosition: AVCaptureDevice.Position = currentCamera.position == .back ? .front : .back
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Unable to switch camera")
                }
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.currentCamera = newCamera
                    self.currentInput = newInput
                    self.configureCameraSettings(for: newCamera)
                    DispatchQueue.main.async {
                        self.setupRotationCoordinator(for: newCamera)
                    }
                } else {
                    self.captureSession.addInput(currentInput)
                    DispatchQueue.main.async {
                        self.showAlert(message: "Failed to add new camera input")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(message: "Camera switch failed: \(error.localizedDescription)")
                }
                self.captureSession.addInput(currentInput)
            }
        }
    }
    
    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            showAlert(message: "Recording failed: \(error.localizedDescription)")
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: outputFileURL, options: nil)
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.lastVideoLocalURL = outputFileURL
                    self?.generateThumbnail(for: outputFileURL)
                    self?.showAlert(message: "Video saved to Photos")
                } else {
                    self?.showAlert(message: "Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        generator.generateCGImageAsynchronously(for: time) { [weak self] cgImage, _, error in
            guard let self, let cgImage else { return }
            let thumbnail = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.lastVideoThumbnail = thumbnail
            }
        }
    }
    
    func openInPhotosApp(videoURL: URL) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let videos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        guard let asset = videos.firstObject else {
            print("❌ No recent video asset found.")
            return
        }
        
        PHPhotoLibrary.shared().performChanges {} completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    let localId = asset.localIdentifier
                    let photosURL = URL(string: "photos-redirect://\(localId)")!
                    
                    if UIApplication.shared.canOpenURL(photosURL) {
                        UIApplication.shared.open(photosURL, options: [:], completionHandler: nil)
                    } else {
                        print("❌ Cannot open Photos app.")
                    }
                }
            } else {
                print("❌ Photos permission issue or error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let channel = connection.audioChannels.first else { return }
        let power = channel.averagePowerLevel
        let normalizedLevel = min(1.0, pow(10, power / 20) * 4)
        
        DispatchQueue.main.async {
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewLayer.frame = UIScreen.main.bounds
        }
    }
    
    private func setupRotationCoordinator(for device: AVCaptureDevice) {
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        updatePreviewOrientation()
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        captureSession.sessionPreset = selectedResolution.preset
        captureSession.automaticallyConfiguresApplicationAudioSession = false
        
        // Configure audio session for Bluetooth microphones (e.g., AirPods)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            let availableInputs = audioSession.availableInputs ?? []
            if let bluetoothInput = availableInputs.first(where: { $0.portType == .bluetoothHFP }) {
                try audioSession.setPreferredInput(bluetoothInput)
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert(message: "Failed to configure audio session for Bluetooth: \(error.localizedDescription)")
            }
            return
        }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            DispatchQueue.main.async {
                self.showAlert(message: "No camera available")
            }
            return
        }
        currentCamera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentInput = input
                configureCameraSettings(for: camera)
                DispatchQueue.main.async {
                    self.setupRotationCoordinator(for: camera)
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to add camera input")
                }
                return
            }
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to add video output")
                }
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert(message: "Camera setup failed: \(error.localizedDescription)")
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
                DispatchQueue.main.async {
                    self.showAlert(message: "Audio setup failed: \(error.localizedDescription)")
                }
                return
            }
        } else {
            DispatchQueue.main.async {
                self.showAlert(message: "No audio device available")
            }
            return
        }
    }
    
    private func configureCameraSettings(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            // 🔹 Autofocus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            let targetFrameRate = Double(selectedFrameRate.rawValue)
            let targetResolution = selectedResolution.preset
            
            let compatibleFormat = device.formats.first { format in
                let supportsResolution = format.isSupported(for: targetResolution)
                let supportsFrameRate = format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= targetFrameRate && range.maxFrameRate >= targetFrameRate
                }
                return supportsResolution && supportsFrameRate
            }
            
            if let format = compatibleFormat {
                device.activeFormat = format
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
            } else if let fallbackFormat = device.formats.first(where: { $0.isSupported(for: targetResolution) }) {
                device.activeFormat = fallbackFormat
                let maxFrameRate = fallbackFormat.videoSupportedFrameRateRanges.sorted(by: { $0.maxFrameRate < $1.maxFrameRate }).last?.maxFrameRate ?? 30.0
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFrameRate))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
                DispatchQueue.main.async {
                    self.showAlert(message: "Frame rate \(Int(targetFrameRate)) fps not supported for \(self.selectedResolution.rawValue). Using \(Int(maxFrameRate)) fps.")
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(message: "No compatible format found for \(self.selectedResolution.rawValue)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert(message: "Failed to configure camera: \(error.localizedDescription)")
            }
        }
    }
    
    private func startRecording() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("video_\(Date().timeIntervalSince1970).mov") else {
            showAlert(message: "Cannot create output file")
            return
        }
        self.isRecording = true
        
        if countdownOnOff {
            countdown = selectedCountdown
            var countdownValue = countdown
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    withAnimation(.smooth) {
                        if let currentCountdown = countdownValue, currentCountdown > 0 {
                            countdownValue = currentCountdown - 1
                            self.countdown = countdownValue
                        } else {
                            timer.invalidate()
                            self.countdown = nil
                            if let connection = self.videoOutput.connection(with: .video), let rotationCoordinator = self.rotationCoordinator {
                                connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
                            }
                            self.videoOutput.startRecording(to: url, recordingDelegate: self)
                            self.recordingTime = 0
                            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                                self?.recordingTime += 1
                            }
                        }
                    }
                }
            }
        } else {
            if let connection = self.videoOutput.connection(with: .video), let rotationCoordinator = self.rotationCoordinator {
                connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            }
            self.videoOutput.startRecording(to: url, recordingDelegate: self)
            self.recordingTime = 0
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordingTime += 1
            }
        }
    }
    
    private func stopRecording() {
        countdown = nil
        countdownTimer?.invalidate()
        videoOutput.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.alertMessage = message
            self?.showAlert = true
        }
    }
    
    private func updateCameraSettings() {
        sessionQueue.async { [weak self] in
            guard let self = self, let camera = self.currentCamera else { return }
            self.configureCameraSettings(for: camera)
        }
    }
}

extension AVCaptureDevice.Format {
    func isSupported(for preset: AVCaptureSession.Preset) -> Bool {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        switch preset {
            case .hd1280x720:
                return dimensions.width >= 1280 && dimensions.height >= 720
            case .hd1920x1080:
                return dimensions.width >= 1920 && dimensions.height >= 1080
            case .hd4K3840x2160:
                return dimensions.width >= 3840 && dimensions.height >= 2160
            default:
                return false
        }
    }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case hd720 = "720"
    case hd1080 = "1080"
    case uhd4K = "4k"
    
    var id: String { rawValue }
    
    var preset: AVCaptureSession.Preset {
        switch self {
            case .hd720: return .hd1280x720
            case .hd1080: return .hd1920x1080
            case .uhd4K: return .hd4K3840x2160
        }
    }
}

enum FrameRate: Int, CaseIterable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    
    var id: Int { rawValue }
    
}

    
