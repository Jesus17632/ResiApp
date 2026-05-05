//
//  CameraPreviewView.swift
//  ResiApp
//
//  Wrapper de AVCaptureVideoPreviewLayer para SwiftUI.
//  Adaptado del componente equivalente en Tlane.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    #if targetEnvironment(simulator)
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1.0)

        let label = UILabel()
        label.text = "Cámara no disponible en Simulator"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    #else
    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.setSession(session)
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {}

    /// Detiene la sesión en background al destruir la vista (libera el hardware).
    static func dismantleUIView(_ uiView: PreviewLayerView, coordinator: ()) {
        Task.detached {
            uiView.session?.stopRunning()
        }
    }

    final class PreviewLayerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var session: AVCaptureSession?

        func setSession(_ session: AVCaptureSession) {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
            self.session = session
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }

        /// Convierte un rect en coordenadas Vision (origen abajo-izquierda, normalizado)
        /// a coordenadas de la vista (puntos en pantalla, origen arriba-izquierda).
        /// La vista expone esto para que el overlay pinte el bounding box correcto.
        func convertVisionRect(_ visionRect: CGRect) -> CGRect {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return .zero }
            // Vision: (x, y, w, h) con y desde abajo. El método de AVCaptureVideoPreviewLayer
            // espera Apple-style normalized rect (y desde arriba), así que volteamos.
            let metadataRect = CGRect(
                x: visionRect.origin.x,
                y: 1.0 - visionRect.origin.y - visionRect.height,
                width: visionRect.width,
                height: visionRect.height
            )
            return previewLayer.layerRectConverted(fromMetadataOutputRect: metadataRect)
        }
    }
    #endif
}
