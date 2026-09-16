import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            EntrenarView()
                .tabItem { Label("Entrenar", systemImage: "dumbbell.fill") }

            HistorialView()
                .tabItem { Label("Historial", systemImage: "clock.fill") }

            EjerciciosView()
                .tabItem { Label("Ejercicios", systemImage: "list.bullet") }
        }
    }
}
