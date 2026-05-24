//
//  CameraView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/12/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    let previewLayer: AVCaptureVideoPreviewLayer
    let aspectRatio: VideoAspectRatio
    var showGuides: Bool = true

    var body: some View {
        CameraPreviewView(previewLayer: previewLayer)
            .overlay {
                if showGuides {
                    CropBarsOverlay(aspectRatio: aspectRatio)
                }
            }
    }
}

// MARK: - UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainerView {
        PreviewContainerView(previewLayer: previewLayer)
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
    }
}

class PreviewContainerView: UIView {
    let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - Crop guide lines overlay

struct CropBarsOverlay: View {
    let aspectRatio: VideoAspectRatio

    var body: some View {
        GeometryReader { geo in
            let targetRatio = aspectRatio.size.width / aspectRatio.size.height
            let screenRatio = geo.size.width / geo.size.height

            if abs(targetRatio - screenRatio) > 0.01 {
                Canvas { ctx, size in
                    if targetRatio < screenRatio {
                        // Vertical guide lines (side crop)
                        let x = (size.width - size.height * targetRatio) / 2
                        for xPos in [x, size.width - x] {
                            ctx.stroke(Path { p in
                                p.move(to: CGPoint(x: xPos, y: 0))
                                p.addLine(to: CGPoint(x: xPos, y: size.height))
                            }, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
                        }
                    } else {
                        // Horizontal guide lines (top/bottom crop)
                        let y = (size.height - size.width / targetRatio) / 2
                        for yPos in [y, size.height - y] {
                            ctx.stroke(Path { p in
                                p.move(to: CGPoint(x: 0, y: yPos))
                                p.addLine(to: CGPoint(x: size.width, y: yPos))
                            }, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
                        }
                    }
                }
            }
        }
    }
}
