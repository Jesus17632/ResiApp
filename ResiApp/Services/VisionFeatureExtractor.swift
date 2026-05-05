//
//  VisionFeatureExtractor.swift
//  ResiApp
//
//  Cambios en este pass:
//  - CIContext como `static let` (mismo fix que en CapturaViewModel).
//    Antes se creaba en cada análisis → costo de instanciación de Metal/GPU
//    a cada rato. Ahora vive una sola vez en el proceso.
//

import Foundation
import Vision
import UIKit
import CoreImage
import os.log

private let log = Logger(subsystem: "ResiApp", category: "Vision")

struct VisionFeatureExtractor {

    /// CIContext compartido — costoso de instanciar (configura GPU/Metal),
    /// barato de reusar. Igual que en CapturaViewModel.
    nonisolated(unsafe) private static let ciContext = CIContext(
        options: [.useSoftwareRenderer: false]
    )

    /// Procesa la imagen y devuelve un texto descriptivo corto.
    nonisolated static func extractFeatures(from imageData: Data) async throws -> String {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw ClassifierError.imageDataInvalid
        }

        // 1. Clasificación general (etiquetas tipo "hay", "soil", "organic-matter", etc.)
        let classifyStart = Date()
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw ClassifierError.visionFailed
        }
        log.debug("vision classify took \(Date().timeIntervalSince(classifyStart))s")

        let observations = request.results ?? []
        let topLabels = observations
            .filter { $0.confidence > 0.2 }
            .prefix(8)
            .map { "\($0.identifier) (\(String(format: "%.2f", $0.confidence)))" }
            .joined(separator: ", ")

        // 2. Color promedio dominante (importante: estiércol mojado es más oscuro)
        let colorStart = Date()
        let colorDescription = dominantColorDescription(of: uiImage)
        log.debug("color avg took \(Date().timeIntervalSince(colorStart))s")

        // 3. Tamaño y orientación
        let size = uiImage.size
        let aspecto = size.width > size.height ? "horizontal" : "vertical"

        return """
        Etiquetas de Vision: \(topLabels.isEmpty ? "ninguna confiable" : topLabels)
        Color promedio: \(colorDescription)
        Imagen \(aspecto), \(Int(size.width))×\(Int(size.height)) px
        """
    }

    // MARK: - Color promedio

    /// Reduce la imagen a 1×1 píxel con CIAreaAverage para obtener el
    /// color promedio aproximado, y devuelve una descripción humana.
    private static func dominantColorDescription(of image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "indeterminado" }

        let inputImage = CIImage(cgImage: cgImage)
        let extent = inputImage.extent

        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let outputImage = filter?.outputImage else { return "indeterminado" }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return describeColor(r: Int(bitmap[0]), g: Int(bitmap[1]), b: Int(bitmap[2]))
    }

    /// Heurística simple para nombrar un color en español por sus componentes RGB.
    private static func describeColor(r: Int, g: Int, b: Int) -> String {
        let maxC = Swift.max(r, g, b)
        let minC = Swift.min(r, g, b)
        let delta = maxC - minC
        let lum = (r + g + b) / 3

        let luminosidad: String
        switch lum {
        case ..<60:     luminosidad = "muy oscuro"
        case 60..<110:  luminosidad = "oscuro"
        case 110..<170: luminosidad = "medio"
        case 170..<220: luminosidad = "claro"
        default:        luminosidad = "muy claro"
        }

        if delta < 25 {
            return "gris \(luminosidad) (RGB \(r),\(g),\(b))"
        }

        let tono: String
        if r >= g && r >= b {
            if g > b + 20      { tono = "marrón/anaranjado" }
            else if b > g + 20 { tono = "rojizo/púrpura" }
            else               { tono = "rojo" }
        } else if g >= r && g >= b {
            if r > b + 20 { tono = "verde-amarillento" }
            else          { tono = "verde" }
        } else {
            tono = "azul"
        }

        return "\(tono) \(luminosidad) (RGB \(r),\(g),\(b))"
    }
}
