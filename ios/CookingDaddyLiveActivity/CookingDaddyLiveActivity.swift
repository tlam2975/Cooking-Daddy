import ActivityKit
import SwiftUI
import WidgetKit

private enum CookingColors {
  static let pink = Color(red: 1.0, green: 0.643, blue: 0.643)
  static let blush = Color(red: 1.0, green: 0.957, blue: 0.957)
  static let ink = Color(red: 0.294, green: 0.153, blue: 0.176)
}

struct CookingDaddyLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CookingActivityAttributes.self) { context in
      CookingLockScreenView(context: context)
        .activityBackgroundTint(CookingColors.pink)
        .activitySystemActionForegroundColor(CookingColors.ink)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          CookingIconBadge(
            activityType: context.state.activityType,
            size: 42,
            background: CookingColors.pink,
            foreground: CookingColors.ink
          )
        }

        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.recipeName)
              .font(.headline)
              .lineLimit(1)
            Text("\(context.state.stepIndex) / \(context.state.totalSteps)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        DynamicIslandExpandedRegion(.trailing) {
          CookingStatusView(state: context.state, tint: CookingColors.pink)
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text(context.state.instruction)
              .font(.subheadline)
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)

            CookingProgressView(
              state: context.state,
              track: Color.white.opacity(0.18),
              fill: CookingColors.pink,
              thumbBackground: CookingColors.pink,
              iconColor: CookingColors.ink
            )
          }
        }
      } compactLeading: {
        CookingActivityIcon(
          activityType: context.state.activityType,
          color: CookingColors.pink,
          size: 18
        )
        .frame(width: 22, height: 22)
      } compactTrailing: {
        Text("\(context.state.stepIndex)/\(context.state.totalSteps)")
          .font(.system(.caption, design: .rounded, weight: .semibold))
          .foregroundStyle(CookingColors.pink)
          .contentTransition(.numericText())
      } minimal: {
        CookingActivityIcon(
          activityType: context.state.activityType,
          color: CookingColors.pink,
          size: 17
        )
        .frame(width: 20, height: 20)
      }
      .keylineTint(CookingColors.pink)
    }
  }
}

private struct CookingLockScreenView: View {
  let context: ActivityViewContext<CookingActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(spacing: 12) {
        CookingIconBadge(
          activityType: context.state.activityType,
          size: 46,
          background: CookingColors.blush,
          foreground: CookingColors.ink
        )

        VStack(alignment: .leading, spacing: 3) {
          Text(context.attributes.recipeName)
            .font(.headline)
            .lineLimit(1)
          Text(context.state.instruction)
            .font(.subheadline)
            .lineLimit(2)
            .foregroundStyle(CookingColors.ink.opacity(0.78))
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 4) {
          CookingStatusView(state: context.state, tint: CookingColors.ink)
          Text("\(context.state.stepIndex) / \(context.state.totalSteps)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(CookingColors.ink.opacity(0.7))
        }
      }

      CookingProgressView(
        state: context.state,
        track: CookingColors.ink.opacity(0.18),
        fill: CookingColors.ink,
        thumbBackground: CookingColors.blush,
        iconColor: CookingColors.ink
      )
    }
    .padding(16)
    .foregroundStyle(CookingColors.ink)
  }
}

private struct CookingStatusView: View {
  let state: CookingActivityAttributes.ContentState
  let tint: Color

  var body: some View {
    Group {
      if let timerEnd = state.timerEnd, timerEnd > Date() {
        Text(timerInterval: Date()...timerEnd, countsDown: true)
          .monospacedDigit()
      } else if state.isCompleted {
        Image(systemName: "checkmark")
      } else {
        Text("\(Int((state.progress * 100).rounded()))%")
          .contentTransition(.numericText())
      }
    }
    .font(.system(.body, design: .rounded, weight: .bold))
    .foregroundStyle(tint)
    .lineLimit(1)
  }
}

private struct CookingProgressView: View {
  let state: CookingActivityAttributes.ContentState
  let track: Color
  let fill: Color
  let thumbBackground: Color
  let iconColor: Color

  private var progress: Double {
    min(max(state.progress, 0), 1)
  }

  var body: some View {
    GeometryReader { geometry in
      let thumbSize = 22.0
      let availableWidth = max(0, geometry.size.width - thumbSize)
      let thumbOffset = availableWidth * progress

      ZStack(alignment: .leading) {
        Capsule()
          .fill(track)
          .frame(height: 6)
          .padding(.horizontal, thumbSize / 2)

        Capsule()
          .fill(fill)
          .frame(width: max(6, availableWidth * progress), height: 6)
          .padding(.leading, thumbSize / 2)

        ZStack {
          Circle().fill(thumbBackground)
          CookingActivityIcon(
            activityType: state.activityType,
            color: iconColor,
            size: 13
          )
          .id(state.activityType)
          .transition(.scale.combined(with: .opacity))
        }
        .frame(width: thumbSize, height: thumbSize)
        .offset(x: thumbOffset)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .animation(.snappy(duration: 0.5), value: progress)
      .animation(.snappy(duration: 0.35), value: state.activityType)
    }
    .frame(height: 22)
  }
}

private struct CookingIconBadge: View {
  let activityType: String
  let size: CGFloat
  let background: Color
  let foreground: Color

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        .fill(background)
      CookingActivityIcon(
        activityType: activityType,
        color: foreground,
        size: size * 0.52
      )
      .id(activityType)
      .transition(.scale.combined(with: .opacity))
    }
    .frame(width: size, height: size)
  }
}

private struct CookingActivityIcon: View {
  let activityType: String
  let color: Color
  let size: CGFloat

  var body: some View {
    Group {
      if activityType == "mix" {
        WhiskShape()
          .stroke(
            color,
            style: StrokeStyle(
              lineWidth: max(1.4, size * 0.1),
              lineCap: .round,
              lineJoin: .round
            )
          )
          .rotationEffect(.degrees(-12))
      } else {
        Image(systemName: symbolName)
          .font(.system(size: size * 0.82, weight: .semibold))
          .foregroundStyle(color)
      }
    }
    .frame(width: size, height: size)
  }

  private var symbolName: String {
    switch activityType {
    case "chop": "scissors"
    case "heat": "flame.fill"
    case "bake": "oven.fill"
    case "wait": "hourglass"
    case "timer": "timer"
    case "plate": "fork.knife.circle.fill"
    case "complete": "checkmark"
    default: "fork.knife"
    }
  }
}

private struct WhiskShape: Shape {
  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height
    let joint = CGPoint(x: width * 0.42, y: height * 0.57)
    var path = Path()

    path.move(to: CGPoint(x: width * 0.1, y: height * 0.9))
    path.addLine(to: joint)

    for offset in [-0.12, 0.0, 0.12] {
      path.move(to: joint)
      path.addCurve(
        to: CGPoint(x: width * (0.73 + offset), y: height * 0.08),
        control1: CGPoint(x: width * (0.42 + offset), y: height * 0.34),
        control2: CGPoint(x: width * (0.58 + offset), y: height * 0.1)
      )
      path.addCurve(
        to: joint,
        control1: CGPoint(x: width * (0.98 + offset), y: height * 0.18),
        control2: CGPoint(x: width * (0.82 + offset), y: height * 0.48)
      )
    }

    return path
  }
}
