//
//  ManurePile.swift
//  ResiApp
//
//  Modelo principal: una pila de estiércol fotografiada por el productor.
//  La fuente animal es siempre bovina por construcción de la app.
//

import Foundation
import SwiftData

/// Estado del registro respecto al pipeline de análisis y matching.
enum SyncStatus: String, Codable {
    case pendingAnalysis  // Subida pero aún no analizada
    case available        // Analizada por IA, lista para aparecer en marketplace
    case matched          // Ya tiene un Match confirmado con una planta
}

@Model
final class ManurePile {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    var volumenM3: Double
    var humedadPct: Double

    // Ubicación
    var latitud: Double
    var longitud: Double

    var fotoFileName: String?
    var audioTranscripcion: String?

    /// Especie de origen. Constante por diseño: la app es exclusivamente bovina.
    var animalFuente: String = "Bovino 🐄"

    var syncStatusRaw: String

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingAnalysis }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        fecha: Date = .now,
        volumenM3: Double = 0,
        humedadPct: Double = 0,
        latitud: Double = 0,
        longitud: Double = 0,
        fotoFileName: String? = nil,
        audioTranscripcion: String? = nil,
        syncStatus: SyncStatus = .pendingAnalysis
    ) {
        self.id = id
        self.fecha = fecha
        self.volumenM3 = volumenM3
        self.humedadPct = humedadPct
        self.latitud = latitud
        self.longitud = longitud
        self.fotoFileName = fotoFileName
        self.audioTranscripcion = audioTranscripcion
        self.syncStatusRaw = syncStatus.rawValue
        // animalFuente queda con su valor por defecto "Bovino 🐄"
    }
}
