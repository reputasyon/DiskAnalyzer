import SwiftUI

@main
struct DiskAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .defaultSize(width: 900, height: 600)
    }
}

struct MainView: View {
    enum Tab: String {
        case analyze = "Analiz"
        case cleanup = "Temizlik"
    }

    @State private var selectedTab: Tab = .analyze

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("Analiz", systemImage: "internaldrive.fill")
                }
                .tag(Tab.analyze)

            CleanupView()
                .tabItem {
                    Label("Temizlik", systemImage: "sparkles")
                }
                .tag(Tab.cleanup)
        }
    }
}
