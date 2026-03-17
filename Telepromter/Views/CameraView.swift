//
//  CameraView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/12/25.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        PreviewContainerView(previewLayer: previewLayer)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewContainerView else { return }
        view.previewLayer.frame = UIScreen.main.bounds
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

class PreviewContainerView: UIView {
    let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        self.layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
