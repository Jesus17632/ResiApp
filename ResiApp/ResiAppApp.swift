

import SwiftUI
import SwiftData

@main
struct ResiAppApp: App {

    // LocationManager compartido. Se crea una sola vez y se inyecta vía
    // .environment(...) a todas las vistas que lo necesiten.
    // Como es @Observable (iOS 17+), usamos @State, no @StateObject.
    @State private var locationManager = LocationManager()

    /// ModelContainer compartido para los 3 modelos de SwiftData.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ManurePile.self,
            ProcessingPlant.self,
            Match.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    // Pedir permiso de ubicación al arrancar la app.
                    // El sistema solo muestra el alert la primera vez;
                    // las llamadas subsecuentes son no-op.
                    locationManager.requestPermission()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(locationManager)
    }
}

// MARK: - Vista raíz

/// Decide qué mostrar según el rol guardado.
/// Lee @AppStorage directamente para que PerfilView pueda resetear
/// el rol y la UI reaccione automáticamente.
struct RootView: View {
    @AppStorage("userRole") private var userRole: String = ""

    var body: some View {
        switch userRole {
        case "productor":
            ProductorTabView()
        case "comprador":
            CompradorTabView()
        default:
            RolSelectorView()
        }
    }
}

// MARK: - TabViews por rol

/// Pestañas del rol "productor": Mapa, Captura, Perfil.
struct ProductorTabView: View {
    var body: some View {
        TabView {
            MapView()   // ← Vista del compañero (NO mi MapaView)
                .tabItem { Label("Mapa", systemImage: "map") }

            CapturaView()
                .tabItem { Label("Captura", systemImage: "camera.fill") }

            PerfilView()
                .tabItem { Label("Perfil", systemImage: "person") }
        }
    }
}

/// Pestañas del rol "comprador": Mapa, Marketplace, Perfil.
struct CompradorTabView: View {
    var body: some View {
        TabView {
            MapView()   // ← Vista del compañero
                .tabItem { Label("Mapa", systemImage: "map") }

            MarketplaceView()
                .tabItem { Label("Marketplace", systemImage: "storefront") }

            PerfilView()
                .tabItem { Label("Perfil", systemImage: "person") }
        }
    }
}
