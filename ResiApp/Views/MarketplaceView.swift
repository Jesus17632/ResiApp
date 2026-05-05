//
//  MarketplaceView.swift
//  ResiApp
//

import SwiftUI
import SwiftData
import CoreLocation
internal import MapKit

struct MarketplaceView: View {

    let columnasGrid = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if HardcodedData.capturasMock.isEmpty {
                    estadoVacio
                } else {
                    ScrollView {
                        LazyVGrid(columns: columnasGrid, spacing: 16) {
                            ForEach(HardcodedData.capturasMock) { captura in
                                CapturaCard(captura: captura)
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
        VStack(spacing: 12) {
            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No hay capturas disponibles")
                .font(.headline)
            Text("Aún no se han registrado lotes bovinos en tu zona.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card

struct CapturaCard: View {
    let captura: SimulatedCapture
    @Environment(LocationManager.self) private var locationManager

    private var distanciaKm: Double {
        let b = locationManager.region.center
        let buyerLoc = CLLocation(latitude: b.latitude, longitude: b.longitude)
        let pileLoc  = CLLocation(latitude: captura.latitud, longitude: captura.longitud)
        return pileLoc.distance(from: buyerLoc) / 1000.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "photo.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 110)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Label("Bovino", systemImage: "pawprint.fill")
                        .font(.headline).lineLimit(1)
                    Spacer()
                    Text("\(captura.volumenM3, specifier: "%.0f") m³")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
                Text("💧 \(captura.humedadPct, specifier: "%.0f")% • \(captura.alimento)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Divider().padding(.vertical, 2)
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.green).font(.caption2)
                    Text("A \(distanciaKm, specifier: "%.1f") km")
                        .font(.caption2.bold()).foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 3)
    }
}   
