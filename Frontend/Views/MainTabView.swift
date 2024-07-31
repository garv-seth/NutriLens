import SwiftUI

struct MainTabView: View {
    @StateObject private var foodLogViewModel = FoodLogViewModel()
    @StateObject private var insightsViewModel = InsightsViewModel()

    var body: some View {
        TabView {
            FoodScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }

            FoodLogView()
                .environmentObject(foodLogViewModel)
                .tabItem {
                    Label("Food Log", systemImage: "list.bullet")
                }

            InsightsView()
                .environmentObject(insightsViewModel)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
