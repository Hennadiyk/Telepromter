//
//  CameraPreview.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/12/25.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView(previewLayer: previewLayer)
        print("CameraPreview makeUIView: session=\(previewLayer.session != nil)")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewContainerView else { return }
        DispatchQueue.main.async {
            view.previewLayer.frame = UIScreen.main.bounds
            view.setNeedsLayout()
            view.layoutIfNeeded()
            print("CameraPreview updateUIView: frame=\(view.previewLayer.frame)")
        }
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
        print("PreviewContainerView layoutSubviews: frame=\(bounds)")
    }
}
