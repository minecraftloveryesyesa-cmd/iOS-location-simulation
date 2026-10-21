import ActivityKit
import Foundation

@MainActor
enum PairingActivityManager {
    private static var currentActivity: Activity<PairingActivityAttributes>?

    static func start(status: String = "ペアリング待機", detail: String = "iOSの設定からペアリングを開始") throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "PairingActivity", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "設定でライブアクティビティが許可されているか確認してください。"])
        }
        if currentActivity == nil {
            currentActivity = Activity<PairingActivityAttributes>.activities.first
        }
        let state = PairingActivityAttributes.ContentState(status: status, detail: detail)
        if let activity = currentActivity {
            Task { await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800))) }
            return
        }
        let attributes = PairingActivityAttributes(sessionName: "Location Lab")
        currentActivity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800)),
            pushType: nil
        )
    }

    static func update(status: String, detail: String) {
        if currentActivity == nil {
            currentActivity = Activity<PairingActivityAttributes>.activities.first
        }
        let state = PairingActivityAttributes.ContentState(status: status, detail: detail)
        guard let activity = currentActivity else {
            try? start(status: status, detail: detail)
            return
        }
        Task { await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800))) }
    }

    static func end() {
        if currentActivity == nil {
            currentActivity = Activity<PairingActivityAttributes>.activities.first
        }
        guard let activity = currentActivity else { return }
        let state = PairingActivityAttributes.ContentState(status: "表示終了", detail: "Location Lab")
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate) }
        currentActivity = nil
    }
}
