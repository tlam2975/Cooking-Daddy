import ActivityKit
import Foundation

struct CookingActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let stepIndex: Int
    let totalSteps: Int
    let instruction: String
    let activityType: String
    let progress: Double
    let timerEnd: Date?
    let isCompleted: Bool
  }

  let recipeName: String
}
