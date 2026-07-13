import AppKit
import Combine

final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var menu: NSMenu?

    func configure(appState: AppState) {
        self.appState = appState

        if statusItem != nil {
            updateStatusItem()
            menu = buildMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
        menu = buildMenu()

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                    self?.menu = self?.buildMenu()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func handleStatusItemClick() {
        guard let appState, let event = NSApp.currentEvent else { return }

        let isMenuClick = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isMenuClick {
            showMenu()
            return
        }

        switch appState.sessionPhase {
        case .focusCountdown, .focusCountup, .focusOvertime:
            appState.toggleMenuBarTimerTemporarilyHidden()
        case .idle, .breakCountdown, .breakFinished:
            openMainWindow()
        }
    }

    @objc private func toggleTimeVisibility() {
        appState?.toggleMenuBarTimerVisibility()
    }

    @objc private func toggleCompactVisibility() {
        appState?.toggleMenuBarTimerTemporarilyHidden()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let mainWindow = NSApp.windows.first { $0.identifier == .tockMainWindow }
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePause() {
        appState?.togglePause()
    }

    @objc private func startFocus() {
        appState?.startFocus()
    }

    @objc private func startBreak() {
        appState?.startBreak()
    }

    @objc private func startNextFocus() {
        appState?.startNextFocusAfterBreak()
    }

    @objc private func endSession() {
        appState?.endSession()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateStatusItem() {
        guard let statusItem, let button = statusItem.button, let appState else { return }

        let shouldShowText = appState.shouldShowMenuBarTimerText && !appState.statusBarTitle.isEmpty

        if shouldShowText {
            button.title = appState.statusBarTitle
            button.attributedTitle = NSAttributedString(string: "")
            button.image = makeTimerImage(text: appState.statusBarTitle)
            button.imagePosition = .imageOnly
            statusItem.length = max(30, (button.image?.size.width ?? 30) + 6)
        } else {
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "TOCK")
            image?.isTemplate = true
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = image
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
        }
    }

    private func makeTimerImage(text: String) -> NSImage? {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let imageSize = NSSize(width: ceil(textSize.width) + 4, height: 16)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: imageSize).fill()

        let drawPoint = NSPoint(
            x: 2,
            y: floor((imageSize.height - textSize.height) / 2)
        )
        (text as NSString).draw(at: drawPoint, withAttributes: attributes)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func showMenu() {
        guard let statusItem, let menu else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        guard let appState else { return NSMenu() }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "\(appState.currentTaskName)        \(appState.timerDisplay)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: appState.timerStatusText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        switch appState.sessionPhase {
        case .idle:
            let startItem = NSMenuItem(title: "开始专注", action: #selector(startFocus), keyEquivalent: "")
            startItem.isEnabled = appState.canStartFocus
            menu.addItem(startItem)
        case .focusCountdown:
            menu.addItem(NSMenuItem(title: appState.isTimerRunning ? "暂停" : "继续", action: #selector(togglePause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "结束", action: #selector(endSession), keyEquivalent: ""))
        case .focusCountup:
            menu.addItem(NSMenuItem(title: appState.isTimerRunning ? "暂停" : "继续", action: #selector(togglePause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "去休息", action: #selector(startBreak), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "结束", action: #selector(endSession), keyEquivalent: ""))
        case .focusOvertime:
            menu.addItem(NSMenuItem(title: appState.isTimerRunning ? "暂停" : "继续", action: #selector(togglePause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "去休息", action: #selector(startBreak), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "结束", action: #selector(endSession), keyEquivalent: ""))
        case .breakCountdown:
            menu.addItem(NSMenuItem(title: appState.isTimerRunning ? "暂停休息" : "继续休息", action: #selector(togglePause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "结束", action: #selector(endSession), keyEquivalent: ""))
        case .breakFinished:
            menu.addItem(NSMenuItem(title: "开始下一段专注", action: #selector(startNextFocus), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "结束", action: #selector(endSession), keyEquivalent: ""))
        }

        menu.addItem(.separator())

        if appState.showsTimerInMenuBar {
            let compactTitle = appState.isMenuBarTimerTemporarilyHidden ? "显示当前时间" : "暂时隐藏时间"
            menu.addItem(NSMenuItem(title: compactTitle, action: #selector(toggleCompactVisibility), keyEquivalent: ""))
        }

        let visibilityTitle = appState.showsTimerInMenuBar ? "隐藏时间" : "显示时间"
        menu.addItem(NSMenuItem(title: visibilityTitle, action: #selector(toggleTimeVisibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 TOCK", action: #selector(quitApp), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        return menu
    }
}
