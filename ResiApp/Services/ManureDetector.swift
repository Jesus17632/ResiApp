//
//  ManureDetector.swift
//  ResiApp
//
//  Detector "ligero" que se ejecuta en CADA frame del visor (a ~2 fps).
//  Combina dos requests de Vision on-device:
//
//  1. VNGenerateAttentionBasedSaliencyImageRequest
//     → devuelve la región más "saliente" de la imagen (lo que un humano
//       miraría primero). Esto nos da el bounding box que el overlay
//       3D animado va a seguir, sin necesidad de un modelo entrenado.
//
//  2. VNClassifyImageRequest
//     → devuelve etiquetas tipo "soil", "hay", "compost", "dirt", etc.
//       Las cruzamos contra una lista blanca para decidir si lo que
//       hay en cuadro "parece materia orgánica" (esLikelyManure).
//
//  IMPORTANTE: este detector NO sustituye al AppleIntelligenceClassifier
//  (Vision + Foundation Models). Su único trabajo es decidir CUÁNDO
//  disparar ese clasificador pesado y DÓNDE pintar el overlay.
//

import Foundation
import Vision
import CoreVideo
import CoreImage
import UIKit

/// Resultado de inspeccionar UN frame del visor.
struct DetectionResult {
    /// Bounding box en coordenadas Vision (origen abajo-izquierda, normalizado 0..1).
    /// Nil si no hubo región saliente.
    let boundingBox: CGRect?

    /// Heurística: ¿lo que hay en cuadro parece materia orgánica/estiércol?
    /// Combinación de etiquetas relevantes con confianza > 0.3.
    let isLikelyManure: Bool

    /// Confianza compuesta 0..1 — mezcla de la confianza de saliency
    /// y la de las etiquetas relevantes. Útil para mostrar % en el overlay.
    let confidence: Double

    /// Etiqueta principal detectada (para debug / UI). Ej: "soil", "hay".
    let topLabel: String?

    static let none = DetectionResult(
        boundingBox: nil,
        isLikelyManure: false,
        confidence: 0,
        topLabel: nil
    )
}

struct ManureDetector {

    /// Etiquetas de Vision que consideramos compatibles con materia orgánica.
    /// Vision usa el taxonomy de Apple: https://developer.apple.com/documentation/vision/vnclassifyimagerequest
    /// Esta lista es heurística — ajusta según veas en logs.
    private static let organicLabels: Set<String> = [
        "soil", "dirt", "ground", "mud", "compost", "manure",
        "hay", "straw", "grass", "vegetation", "fodder",
        "outdoor", "field", "farm", "agriculture",
        "plant_material", "organic_matter"
    ]

    /// Procesa un pixel buffer (frame del AVCaptureSession).
    static func detect(in pixelBuffer: CVPixelBuffer) async -> DetectionResult {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        return await detect(with: handler)
    }

    /// Procesa una imagen estática (rama de "elegir de galería").
    static func detect(in cgImage: CGImage) async -> DetectionResult {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return await detect(with: handler)
    }

    private static func detect(with handler: VNImageRequestHandler) async -> DetectionResult {
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        let classify = VNClassifyImageRequest()

        do {
            try handler.perform([saliency, classify])
        } catch {
            return .none
        }

        // 1. Bounding box saliente
        let salientBox: CGRect?
        var saliencyConfidence: Double = 0
        if let salObs = saliency.results?.first {
            // Vision puede devolver varias salient objects. Tomamos la unión
            // de las que tengan confianza decente, o la más grande si no hay objects.
            if let objects = salObs.salientObjects, !objects.isEmpty {
                let goodObjects = objects.filter { $0.confidence > 0.5 }
                let pool = goodObjects.isEmpty ? objects : goodObjects
                salientBox = pool
                    .map { $0.boundingBox }
                    .reduce(into: CGRect.null) { $0 = $0.union($1) }
                saliencyConfidence = Double(pool.map { $0.confidence }.max() ?? 0)
            } else {
                salientBox = nil
            }
        } else {
            salientBox = nil
        }

        // 2. Etiquetas
        let observations = classify.results ?? []
        let relevant = observations
            .filter { $0.confidence > 0.3 }
            .filter { organicLabels.contains($0.identifier.lowercased()) }

        let topRelevant = relevant.max(by: { $0.confidence < $1.confidence })
        let labelConfidence = Double(topRelevant?.confidence ?? 0)
        let isLikely = !relevant.isEmpty

        // 3. Confianza compuesta: necesitamos AMBAS señales para confiar.
        //    - Si solo hay saliency (algo en cuadro) pero ningún label orgánico → 0.
        //    - Si hay label pero el objeto está borroso/repartido → bajo.
        //    - Si ambos están altos → alto.
        let composite: Double
        if isLikely && salientBox != nil {
            composite = (saliencyConfidence * 0.4) + (labelConfidence * 0.6)
        } else if isLikely {
            composite = labelConfidence * 0.5
        } else {
            composite = 0
        }

        return DetectionResult(
            boundingBox: salientBox,
            isLikelyManure: isLikely,
            confidence: composite,
            topLabel: topRelevant?.identifier
        )
    }
}
