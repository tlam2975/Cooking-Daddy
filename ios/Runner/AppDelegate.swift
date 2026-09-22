import ActivityKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let liveActivityBridge = CookingLiveActivityBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: "com.tlam.cookingdaddy/live_activity",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [liveActivityBridge] call, result in
      Task {
        do {
          switch call.method {
          case "isSupported":
            let isSupported = liveActivityBridge.isSupported
            await MainActor.run { result(isSupported) }
          case "start":
            try await liveActivityBridge.start(arguments: call.arguments)
            await MainActor.run { result(nil) }
          case "update":
            try await liveActivityBridge.update(arguments: call.arguments)
            await MainActor.run { result(nil) }
          case "end":
            try await liveActivityBridge.end(arguments: call.arguments)
            await MainActor.run { result(nil) }
          default:
            await MainActor.run { result(FlutterMethodNotImplemented) }
          }
        } catch {
          let flutterError = FlutterError(
            code: "live_activity_error",
            message: error.localizedDescription,
            details: nil
          )
          await MainActor.run { result(flutterError) }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class CookingLiveActivityBridge {
  var isSupported: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  func start(arguments: Any?) async throws {
    guard isSupported else {
      throw CookingLiveActivityError.notAuthorized
    }
    let snapshot = try parse(arguments)

    for activity in Activity<CookingActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }

    let attributes = CookingActivityAttributes(recipeName: snapshot.recipeName)
    let content = ActivityContent(
      state: snapshot.state,
      staleDate: snapshot.state.timerEnd
    )
    _ = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
  }

  func update(arguments: Any?) async throws {
    let snapshot = try parse(arguments)
    let content = ActivityContent(
      state: snapshot.state,
      staleDate: snapshot.state.timerEnd
    )
    for activity in Activity<CookingActivityAttributes>.activities {
      await activity.update(content)
    }
  }

  func end(arguments: Any?) async throws {
    let snapshot = try parse(arguments)
    let content = ActivityContent(state: snapshot.state, staleDate: nil)
    let dismissalPolicy: ActivityUIDismissalPolicy = snapshot.state.isCompleted
      ? .after(Date().addingTimeInterval(15))
      : .immediate

    for activity in Activity<CookingActivityAttributes>.activities {
      await activity.end(content, dismissalPolicy: dismissalPolicy)
    }
  }

  private func parse(_ arguments: Any?) throws -> CookingActivitySnapshot {
    guard
      let values = arguments as? [String: Any],
      let recipeName = values["recipeName"] as? String,
      let instruction = values["instruction"] as? String,
      let activityType = values["activityType"] as? String,
      let stepIndex = (values["stepIndex"] as? NSNumber)?.intValue,
      let totalSteps = (values["totalSteps"] as? NSNumber)?.intValue,
      let progress = (values["progress"] as? NSNumber)?.doubleValue,
      let isCompleted = values["isCompleted"] as? Bool
    else {
      throw CookingLiveActivityError.invalidPayload
    }

    let timerEnd: Date?
    if let milliseconds = (values["timerEndEpochMilliseconds"] as? NSNumber)?.doubleValue {
      timerEnd = Date(timeIntervalSince1970: milliseconds / 1_000)
    } else {
      timerEnd = nil
    }

    return CookingActivitySnapshot(
      recipeName: recipeName,
      state: CookingActivityAttributes.ContentState(
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        instruction: instruction,
        activityType: activityType,
        progress: min(max(progress, 0), 1),
        timerEnd: timerEnd,
        isCompleted: isCompleted
      )
    )
  }
}

private struct CookingActivitySnapshot {
  let recipeName: String
  let state: CookingActivityAttributes.ContentState
}

private enum CookingLiveActivityError: LocalizedError {
  case invalidPayload
  case notAuthorized

  var errorDescription: String? {
    switch self {
    case .invalidPayload:
      "The cooking Live Activity received an invalid state."
    case .notAuthorized:
      "Live Activities are disabled on this device."
    }
  }
}
