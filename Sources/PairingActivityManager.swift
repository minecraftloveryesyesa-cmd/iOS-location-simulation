import ActivityKit
import Foundation

@MainActor
enum PairingActivityManager {
    private static var currentActivity: Activity<PairingActivityAttributes>?

    static func start() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(
                domain: "PairingActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "設定でライブアクティビティが許可されているか確認してください。"]
            )
        }

        // 実際のペアリングコードはまだ取得できないため、状態のみを表示する。
        let attributes = PairingActivityAttributes(sessionName: "Location Lab")
        let state = PairingActivityAttributes.ContentState(
            status: "ペアリング待機",
            detail: "アプリのペアリング情報を設定してください"
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60))
        currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end() {
        guard let activity = currentActivity else { return }
        let finalState = PairingActivityAttributes.ContentState(
            status: "表示終了",
            detail: "Location Lab"
        )
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
