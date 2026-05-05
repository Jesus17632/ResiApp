//
//  MarketplaceView.swift
//  ResiApp
//
//  Consume ManurePile reales via @Query en lugar de HardcodedData.
//  CapturaCard carga la foto real del disco (Documents/) si existe.
//

import SwiftUI
import SwiftData
import CoreLocation
internal import MapKit

struct MarketplaceView: View {

    // Lotes publicados por el productor — solo los que pasaron la IA y se publicaron.
    @Query(
        filter: #Predicate<ManurePile> { $0.syncStatusRaw == "available" },
        sort: \ManurePile.fecha,
        order: .reverse
    )
    private var lotes: [ManurePile]

    let columnasGrid = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if lotes.isEmpty {
                    estadoVacio
                } else {
                    ScrollView {
                        LazyVGrid(columns: columnasGrid, spacing: 16) {
                            ForEach(lotes) { pile in
                                CapturaCard(pile: pile)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Marketplace")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No hay lotes disponibles")
                .font(.headline)
            Text("Cuando un productor publique un lote bovino analizado por IA, aparecerá aquí.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card (recibe ManurePile, no SimulatedCapture)

struct CapturaCard: View {
    let pile: ManurePile

    @Environment(LocationManager.self) private var locationManager

    /// Intenta cargar el JPEG guardado en Documents/ por CapturaViewModel.
    /// Sincrónico y rápido para archivos pequeños — aceptable para hackathon.
    private var foto: UIImage? {
        guard let fileName = pile.fotoFileName,
              let dir = FileManager.default.urls(
                  for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private var distanciaKm: Double {
        let b = locationManager.region.center
        let buyerLoc = CLLocation(latitude: b.latitude, longitude: b.longitude)
        let pileLoc  = CLLocation(latitude: pile.latitud, longitude: pile.longitud)
        return pileLoc.distance(from: buyerLoc) / 1000.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Imagen real o placeholder gris
            ZStack {
                Color(.secondarySystemBackground)
                if let img = foto {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 110)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    // Especie siempre constante
                    Label("Bovino 🐄", systemImage: "pawprint.fill")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(pile.volumenM3, specifier: "%.1f") m³")
                        .font(.subheadline.bold())
                        .foregroundStyle(.appGreen)
                }

                Text("💧 \(pile.humedadPct, specifier: "%.0f")% humedad")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Divider().padding(.vertical, 2)

                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.appGreen)
                        .font(.caption2)
                    Text("A \(distanciaKm, specifier: "%.1f") km")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pile.fecha, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 3)
    }
}
