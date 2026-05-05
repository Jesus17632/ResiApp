//
//  ResiAppApp.swift
//  ResiApp
//
//  

import SwiftUI
import SwiftData

@main
struct ResiAppApp: App {
    @State private var locationManager = LocationManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ManurePile.self,
            ProcessingPlant.self,
            Match.self,
            ProducerProfile.self,
            SimulatedCapture.self,
            BuyerProfile.self          // ← nuevo
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { locationManager.requestPermission() }
        }
        .modelContainer(sharedModelContainer)
        .environment(locationManager)
    }
}

// MARK: - Vista raíz

struct RootView: View {
    @AppStorage("userRole") private var userRole: String = ""

    var body: some View {
        switch userRole {
        case "productor": ProductorTabView()
        case "comprador": CompradorTabView()
        default:          RolSelectorView()
        }
    }
}

// MARK: - TabViews

struct ProductorTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var perfiles: [ProducerProfile]

    @State private var mostrarOnboarding = false

    var body: some View {
        TabView {
            MapView()
                .tabItem { Label("Mapa", systemImage: "map") }
            CapturaView()
                .tabItem { Label("Captura", systemImage: "camera.fill") }
            PerfilProductorView()
                .tabItem { Label("Perfil", systemImage: "person") }
        }
        .onAppear {
            if perfiles.isEmpty { mostrarOnboarding = true }
        }
        .sheet(isPresented: $mostrarOnboarding) {
            ProducerOnboardingView(
                onComplete: { mostrarOnboarding = false },
                onBack: { mostrarOnboarding = false }
            )
                .interactiveDismissDisabled()
        }
    }
}

struct CompradorTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var perfiles: [BuyerProfile]

    @State private var mostrarOnboarding = false

    var body: some View {
        TabView {
            MapView()
                .tabItem { Label("Mapa", systemImage: "map") }
            MarketplaceView()
                .tabItem { Label("Marketplace", systemImage: "storefront") }
            PerfilCompradorView()
                .tabItem { Label("Perfil", systemImage: "person") }
        }
        .onAppear {
            if perfiles.isEmpty { mostrarOnboarding = true }
        }
        // ← CAMBIADO: .sheet → .fullScreenCover para que no salga de abajo
        .fullScreenCover(isPresented: $mostrarOnboarding) {
            BuyerOnboardingView(
                onComplete: { mostrarOnboarding = false },
                onBack: { mostrarOnboarding = false }
            )
            .interactiveDismissDisabled()
        }
    }
}

#Preview {
    RootView()
}
