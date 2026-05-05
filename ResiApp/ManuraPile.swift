//
//  ManurePile.swift
//  EcoVinculo
//
//  Modelo principal: una pila de estiércol fotografiada por el productor.
//

import Foundation
import SwiftData

/// Estado del registro respecto al pipeline de análisis y matching.
/// Se almacena como String (rawValue) en SwiftData; se expone como enum vía propiedad calculada.
enum SyncStatus: String, Codable {
    case pendingAnalysis  // Subida pero aún no analizada (offline o esperando IA)
    case available        // Analizada por Gemini, lista para aparecer en marketplace
    case matched          // Ya tiene un Match confirmado con una planta
}

@Model
final class ManurePile {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    var volumenM3: Double
    var humedadPct: Double

    // Ubicación: lat/lon como Double porque CLLocationCoordinate2D no es Codable.
    // En Bloque 2/3 se llenan con CoreLocation.
    var latitud: Double
    var longitud: Double

    // Solo el nombre del archivo dentro de Documents/, no la ruta absoluta.
    // Esto sobrevive reinstalaciones del simulador y cambios de container ID.
    var fotoFileName: String?

    var audioTranscripcion: String?

    // SwiftData persiste el rawValue. La propiedad calculada `syncStatus` da la API tipo enum.
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
    }
}
