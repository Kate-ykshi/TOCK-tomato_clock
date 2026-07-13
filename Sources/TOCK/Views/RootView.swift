import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 178)

            Divider()
                .background(Color.line)

            Group {
                switch appState.selectedPage {
                case .focus:
                    FocusView()
                case .statistics:
                    StatisticsView()
                case .tasks:
                    TasksView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .background(MainWindowAccessor())
        .onAppear {
            StatusBarController.shared.configure(appState: appState)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                profileHeader
            }
            .buttonStyle(.plain)
            .focusable(false)
            .padding(.top, 64)
            .padding(.horizontal, 24)

            VStack(spacing: 16) {
                ForEach(AppPage.allCases) { page in
                    Button {
                        appState.selectedPage = page
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(appState.selectedPage == page ? Color.tockGreen : Color.line)
                                .frame(width: 18, height: 18)

                            Text(page.rawValue)
                                .font(.system(size: 15, weight: appState.selectedPage == page ? .bold : .semibold))
                                .foregroundStyle(appState.selectedPage == page ? Color.primaryText : Color.secondaryText)

                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                        .background(appState.selectedPage == page ? Color.tockGreen.opacity(0.16) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.top, 58)
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.panelBackground)
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.tockGreen.opacity(0.22))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .fill(Color.tockGreen)
                        .frame(width: 18, height: 18)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text("TOCK")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                Text(appState.userName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primaryText.opacity(0.78))
                    .lineLimit(1)
                Text("今日 \(appState.todayFocusText)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primaryText)

            VStack(alignment: .leading, spacing: 14) {
                Text("个人")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.tockGreen.opacity(0.22))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Circle()
                                .fill(Color.tockGreen)
                                .frame(width: 20, height: 20)
                        }

                    TextField("名字", text: $appState.userName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.line)
                        }
                }
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 14) {
                Text("使用习惯")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                Toggle("菜单栏显示时间", isOn: $appState.showsTimerInMenuBar)
                    .toggleStyle(.switch)

                Toggle("专注/休息结束时发送系统通知", isOn: $appState.notificationsEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: appState.notificationsEnabled) { _, isEnabled in
                        if isEnabled {
                            NotificationManager.shared.requestAuthorization()
                        }
                    }
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("数据管理")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重置任务与统计")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                        Text("保留个人设置，清空任务、分类和专注记录。")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                    }

                    Spacer()

                    Button("重置") {
                        isShowingResetConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.deepCoral)
                    .frame(width: 58, height: 32)
                    .background(Color.deepCoral.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("提示")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text("关闭主窗口不会停止计时。你可以从菜单栏再次打开 TOCK。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            .settingsCard()

            Spacer()
        }
        .padding(26)
        .frame(width: 430, height: 470)
        .background(Color.appBackground)
        .alert("重置任务与统计？", isPresented: $isShowingResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                appState.resetTasksAndStatistics()
            }
        } message: {
            Text("这会清空任务、分类和专注记录，但会保留你的名字、通知和菜单栏设置。")
        }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = "TOCK"
            window.identifier = .tockMainWindow
            window.contentMinSize = NSSize(width: 800, height: 700)
            window.contentMaxSize = NSSize(width: 800, height: 700)
            window.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.line)
            }
    }
}

extension NSUserInterfaceItemIdentifier {
    static let tockMainWindow = NSUserInterfaceItemIdentifier("TOCKMainWindow")
}
