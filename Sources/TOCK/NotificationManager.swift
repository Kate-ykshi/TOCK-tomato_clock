import AppKit
import UserNotifications

enum TockNotificationKind {
    case focusFinished
    case breakFinished

    var categoryIdentifier: String {
        switch self {
        case .focusFinished:
            return "TOCK_FOCUS_FINISHED"
        case .breakFinished:
            return "TOCK_BREAK_FINISHED"
        }
    }
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private enum ActionID {
        static let startBreak = "TOCK_START_BREAK"
        static let endSession = "TOCK_END_SESSION"
        static let openMainWindow = "TOCK_OPEN_MAIN_WINDOW"
    }

    private override init() {
        super.init()
    }

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        configureCategories()
    }

    func requestAuthorization() {
        configure()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(title: String, body: String, kind: TockNotificationKind) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = kind.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case ActionID.startBreak:
                AppState.shared.startBreak()
            case ActionID.endSession:
                AppState.shared.endSession()
            case ActionID.openMainWindow, UNNotificationDefaultActionIdentifier:
                Self.openMainWindow()
            default:
                break
            }

            completionHandler()
        }
    }

    private func configureCategories() {
        let startBreak = UNNotificationAction(
            identifier: ActionID.startBreak,
            title: "去休息",
            options: [.foreground]
        )
        let endSession = UNNotificationAction(
            identifier: ActionID.endSession,
            title: "结束",
            options: []
        )
        let openMainWindow = UNNotificationAction(
            identifier: ActionID.openMainWindow,
            title: "打开 TOCK",
            options: [.foreground]
        )

        let focusFinished = UNNotificationCategory(
            identifier: TockNotificationKind.focusFinished.categoryIdentifier,
            actions: [startBreak, endSession],
            intentIdentifiers: [],
            options: []
        )
        let breakFinished = UNNotificationCategory(
            identifier: TockNotificationKind.breakFinished.categoryIdentifier,
            actions: [openMainWindow],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([focusFinished, breakFinished])
    }

    private static func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let mainWindow = NSApp.windows.first { $0.identifier == .tockMainWindow }
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
