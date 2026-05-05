//
//  ManureClassifierService.swift
//  ResiApp
//
//  Protocolo + tipo de salida estructurada (@Generable) + errores.
//  El protocolo permite swap futuro: hoy AppleIntelligenceClassifier,
//  mañana podría ser GeminiClassifier o un CoreML entrenado a medida.
//

import Foundation
import FoundationModels

/// Resultado del análisis de una pila. Las anotaciones @Guide le dicen
/// al modelo qué se espera en cada campo, y @Generable obliga a que
/// la respuesta tenga ese formato exacto (sin parsear JSON a mano).
@Generable
struct ManureClassification {
    @Guide(description: "Humedad del estiércol estimada en porcentaje, valor entre 0 y 100. Estiércol fresco/mojado: 70-85. Semicompostado: 40-60. Seco: 15-30.")
    let humedadPct: Double

    @Guide(description: "Volumen aproximado de la pila en metros cúbicos, valor entre 0.5 y 10. Una carretilla pequeña son ~0.5 m³, una pila grande ~5 m³.")
    let volumenEstimadoM3: Double

    @Guide(description: "Calidad para procesamiento. Exactamente una de: 'alta', 'media', 'baja'.")
    let calidadLabel: String

    @Guide(description: "True si el material es procesable para biogás o composta. False si tiene contaminantes visibles (plástico, metal, escombros), está demasiado seco, o claramente no es estiércol.")
    let esApto: Bool

    @Guide(description: "Justificación breve en español, máximo 2 oraciones, explicando por qué es apto o no, y por qué esa calidad.")
    let razon: String
}

// MARK: - Errores

enum ClassifierError: Error, LocalizedError {
    case modelUnavailable(reason: String)
    case visionFailed
    case inferenceFailed(String)
    case imageDataInvalid

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason): return reason
        case .visionFailed:                 return "No se pudo analizar la imagen con Vision."
        case .inferenceFailed(let msg):     return "Error de inferencia: \(msg)"
        case .imageDataInvalid:             return "La imagen no es válida."
        }
    }
}

// MARK: - Protocolo

protocol ManureClassifierService: Sendable {
    func classify(imageData: Data) async throws -> ManureClassification
}
