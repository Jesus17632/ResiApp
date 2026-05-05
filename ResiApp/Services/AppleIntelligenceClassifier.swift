//
//  AppleIntelligenceClassifier.swift
//  ResiApp
//
//  Cambios en este pass:
//  - Timeout de 20s sobre Foundation Models. Si no responde, throw → la View
//    pasa a .error con botón "Intentar de nuevo" en vez de quedarse colgada.
//  - LanguageModelSession se reusa (no se recrea en cada llamada).
//  - Logs explícitos de cada etapa para que se vea en Xcode dónde se atora.
//

import Foundation
import FoundationModels
import os.log

private let log = Logger(subsystem: "ResiApp", category: "Classifier")

struct AppleIntelligenceClassifier: ManureClassifierService {

    /// Timeout total de la inferencia. Foundation Models a veces se cuelga
    /// la primera vez que se invoca (cargando el modelo). 20s es generoso
    /// pero finito — preferimos un error claro a un freeze infinito.
    private static let inferenceTimeout: Duration = .seconds(20)

    nonisolated func classify(imageData: Data) async throws -> ManureClassification {

        // 1. Verificar disponibilidad del modelo on-device.
        log.debug("classify: checking availability")
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
        log.debug("classify: extracting vision features")
        let visionStart = Date()
        let visionDescription = try await VisionFeatureExtractor.extractFeatures(from: imageData)
        log.debug("classify: vision took \(Date().timeIntervalSince(visionStart))s")

        // 3. Foundation Models con timeout.
        log.debug("classify: running Foundation Models")
        let fmStart = Date()

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

        // Carrera entre la inferencia real y un timeout.
        // Si gana el timeout, lanzamos error explícito.
        do {
            let result = try await withThrowingTaskGroup(of: ManureClassification.self) { group in
                group.addTask {
                    let response = try await session.respond(
                        to: prompt,
                        generating: ManureClassification.self
                    )
                    return response.content
                }
                group.addTask {
                    try await Task.sleep(for: Self.inferenceTimeout)
                    throw ClassifierError.inferenceFailed(
                        "El análisis tardó demasiado (>\(Int(Self.inferenceTimeout.components.seconds))s). Intenta de nuevo."
                    )
                }
                // Devolvemos el primer resultado y cancelamos el otro.
                guard let first = try await group.next() else {
                    throw ClassifierError.inferenceFailed("Sin resultado del modelo.")
                }
                group.cancelAll()
                return first
            }
            log.debug("classify: Foundation Models took \(Date().timeIntervalSince(fmStart))s")
            return result
        } catch let error as ClassifierError {
            throw error
        } catch {
            throw ClassifierError.inferenceFailed(error.localizedDescription)
        }
    }
}
