import Foundation

struct NutritionInsights: Codable {
    var weeklyCalorieData: [Int]
    var nutrientBreakdown: [Double]
    var insights: [String]
}
