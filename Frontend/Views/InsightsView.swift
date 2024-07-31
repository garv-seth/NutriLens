import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var insightsViewModel: InsightsViewModel

    var body: some View {
        NavigationView {
            if let insights = insightsViewModel.insights {
                List {
                    Section(header: Text("Weekly Calorie Data")) {
                        // Display weekly calorie data
                        ForEach(insights.weeklyCalorieData, id: \.self) { data in
                            Text("\(data) calories")
                        }
                    }

                    Section(header: Text("Nutrient Breakdown")) {
                        // Display nutrient breakdown
                        ForEach(insights.nutrientBreakdown, id: \.self) { data in
                            Text("\(data)")
                        }
                    }

                    Section(header: Text("Insights")) {
                        ForEach(insights.insights, id: \.self) { insight in
                            Text(insight)
                        }
                    }
                }
                .navigationTitle("Nutrition Insights")
            } else {
                Text("Loading insights...")
            }
        }
        .onAppear {
            insightsViewModel.fetchInsights()
        }
    }
}
