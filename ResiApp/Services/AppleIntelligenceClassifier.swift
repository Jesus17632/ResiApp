//
//  AppleIntelligenceClassifier.swift
//  ResiApp
//
//  Implementación del protocolo ManureClassifierService usando:
//  - Vision (extracción de etiquetas + color de la foto)
//  - Foundation Models (razonamiento estructurado @Generable)
//
//  Especializado en estiércol bovino exclusivamente.
//

import Foundation
import FoundationModels

struct AppleIntelligenceClassifier: ManureClassifierService {

    nonisolated func classify(imageData: Data) async throws -> ManureClassification {

        // 1. Verificar disponibilidad del modelo on-device.
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw ClassifierError.modelUnavailable(
                reason: "Tu dispositivo no soporta Apple Intelligence."
            )
        case .unavailable(.appleIntelligenceNotEnabled):
            throw ClassifierError.modelUnavailable(
                reason: "Apple Intelligence está desactivado. Actívalo en Configuración → Apple Intelligence y Siri."
            )
        case .unavailable(.modelNotReady):
            throw ClassifierError.modelUnavailable(
                reason: "El modelo on-device aún se está descargando. Conecta tu iPhone a Wi-Fi y carga, e inténtalo en unos minutos."
            )
        case .unavailable(_):
            throw ClassifierError.modelUnavailable(
                reason: "Apple Intelligence no está disponible en este momento."
            )
        }

        // 2. Vision: extraer descripción textual de la foto.
        let visionDescription = try await VisionFeatureExtractor.extractFeatures(from: imageData)

        // 3. Foundation Models: razonar sobre la descripción y emitir
        //    el struct ManureClassification con guided generation.
        let session = LanguageModelSession(
            instructions: """
            Eres un experto en gestión de estiércol bovino en México. Tu trabajo es \
            estimar las características de pilas de estiércol fotografiadas por productores \
            ganaderos, basándote en una descripción visual extraída por visión por computadora.

            Reglas para humedad (específicas para estiércol bovino):
            - Fresco/reciente (menos de 48 h): color marrón muy oscuro, casi negro, brillante por humedad → 75–85%.
            - Semicompostado (1 a 4 semanas): color marrón medio, mate, sin brillo → 45–65%.
            - Maduro/seco (más de un mes): color claro, grisáceo o terroso, textura quebradiza → 15–35%.

            Reglas para volumen:
            - El sistema solo te dice qué etiquetas detectó Vision, no la escala real.
            - Estima conservador: entre 0.5 m³ (carretilla) y 8.0 m³ (montón grande).

            Reglas para esApto:
            - false si las etiquetas indican plástico, metal, escombros, o material no orgánico.
            - false si Vision no detectó nada relacionado con materia orgánica con confianza > 0.4.
            - true en el resto de casos.

            Responde siempre en español neutro de México.
            """
        )

        let prompt = """
        Análisis de Vision sobre la foto de la pila de estiércol bovino:

        \(visionDescription)

        Estima los parámetros de la pila con base en esta información.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ManureClassification.self
            )
            return response.content
        } catch {
            throw ClassifierError.inferenceFailed(error.localizedDescription)
        }
    }
}
