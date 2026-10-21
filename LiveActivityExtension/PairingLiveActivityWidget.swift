import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PairingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PairingActivityAttributes.self) { context in
            PairingLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.025, green: 0.04, blue: 0.07))
                .activitySystemActionForegroundColor(.cyan)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .foregroundStyle(Color.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.status).font(.headline)
                        Text(context.state.detail).font(.caption2).lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Location Lab • ペアリング状態")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "location.circle.fill").foregroundStyle(Color.cyan)
            } compactTrailing: {
                Image(systemName: "link").foregroundStyle(Color.cyan)
            } minimal: {
                Image(systemName: "link").foregroundStyle(Color.cyan)
            }
            .keylineTint(Color.cyan)
        }
    }
}

private struct PairingLockScreenView: View {
    let state: PairingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.title2).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.status).font(.headline).foregroundStyle(.white)
                Text(state.detail).font(.caption).foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}
