import AppKit
import SwiftUI

@main
struct TOCKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(width: 800, height: 700)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("导航") {
                Button("专注") {
                    appState.selectedPage = .focus
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("统计") {
                    appState.selectedPage = .statistics
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("任务") {
                    appState.selectedPage = .tasks
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            CommandMenu("计时") {
                Button("开始专注") {
                    appState.startFocus()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!appState.canStartFocus)

                Button(appState.isTimerRunning ? "暂停" : "继续") {
                    appState.togglePause()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!appState.sessionPhase.isActive)

                Button("结束") {
                    appState.endSession()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.sessionPhase == .idle)

                if appState.sessionPhase.isFocusPhase {
                    Button("去休息") {
                        appState.startBreak()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.configure()
        if AppState.shared.notificationsEnabled {
            NotificationManager.shared.requestAuthorization()
        }
        statusBarController.configure(appState: AppState.shared)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.prepareForTermination()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first { $0.identifier == .tockMainWindow }?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
