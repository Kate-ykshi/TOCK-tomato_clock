import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingNewCategorySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("专注")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .padding(.top, 48)
                .padding(.leading, 32)

            Spacer(minLength: 22)

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    if appState.sessionPhase != .idle {
                        Text(appState.timerStatusText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(appState.activeAccentColor)
                    }

                    Text(appState.timerDisplay)
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryText)
                        .contentTransition(.numericText())
                }
                .padding(.top, 32)

                TimerModeSelector(
                    selection: $appState.timerMode,
                    isLocked: appState.settingsLocked
                )
                .disabled(appState.settingsLocked)
                .opacity(appState.settingsLocked ? 0.55 : 1)

                VStack(spacing: 14) {
                    TextField("搜索或输入任务", text: $appState.taskInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 22)
                        .frame(width: 294, height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.line)
                        }
                        .disabled(appState.settingsLocked)
                        .opacity(appState.settingsLocked ? 0.68 : 1)
                        .onChange(of: appState.taskInput) { _, _ in
                            appState.syncCategoryForExistingTaskName()
                        }

                    taskSuggestions

                    categorySelector
                        .frame(width: 294, height: 46)
                        .disabled(appState.settingsLocked)
                        .opacity(appState.settingsLocked ? 0.68 : 1)
                }

                HStack(spacing: 22) {
                    DurationEditorCard(title: "专注", minutes: $appState.focusMinutes, isLocked: appState.settingsLocked)
                    DurationEditorCard(title: "休息", minutes: $appState.breakMinutes, isLocked: appState.settingsLocked)
                }

                if appState.sessionPhase.isActive || appState.sessionPhase == .breakFinished {
                    Text("当前任务：\(appState.currentTaskName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }

                sessionControls
                    .padding(.bottom, 28)
            }
            .frame(width: 410)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.black.opacity(0.10), radius: 24, y: 16)
            )
            .frame(maxWidth: .infinity)

            Spacer(minLength: 28)
        }
        .sheet(isPresented: $isShowingNewCategorySheet) {
            NewCategorySheet(initialColorToken: appState.suggestedCategoryColorToken) { name, colorToken in
                appState.addCategory(name: name, colorToken: colorToken)
            }
        }
    }

    private var categorySelector: some View {
        Menu {
            ForEach(appState.categories) { category in
                Button {
                    appState.selectCategory(category)
                } label: {
                    Text(category.name)
                }
            }

            Divider()

            Button("+ 新建分类") {
                isShowingNewCategorySheet = true
            }
        } label: {
            HStack(spacing: 12) {
                Text("分类")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)

                Circle()
                    .fill(appState.selectedCategory.color)
                    .frame(width: 16, height: 16)

                Text(appState.selectedCategory.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primaryText)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                ForEach(appState.categories.prefix(4)) { category in
                    Circle()
                        .fill(category.color)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.line)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var taskSuggestions: some View {
        let suggestions = appState.focusTaskSuggestions
        let trimmedInput = appState.taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let isExactSingleMatch = suggestions.count == 1
            && suggestions[0].taskName.caseInsensitiveCompare(trimmedInput) == .orderedSame

        if !suggestions.isEmpty && !isExactSingleMatch && !appState.settingsLocked {
            VStack(spacing: 7) {
                ForEach(suggestions) { suggestion in
                    Button {
                        appState.selectTaskSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(suggestion.bulletColor)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.taskName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)

                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(suggestion.categoryColor)
                                        .frame(width: 6, height: 6)
                                    Text(suggestion.categoryName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }

                            Spacer()

                            Text(suggestion.todayDurationText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .frame(width: 294, height: 38)
                        .background(Color.panelBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.line.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        switch appState.sessionPhase {
        case .idle:
            Button("开始") {
                appState.startFocus()
            }
            .primaryTimerButton(color: appState.activeAccentColor)
            .disabled(!appState.canStartFocus)
            .opacity(appState.canStartFocus ? 1 : 0.45)
            .keyboardShortcut(.return, modifiers: .command)

        case .focusCountdown:
            HStack(spacing: 12) {
                Button(appState.isTimerRunning ? "暂停" : "继续") {
                    appState.togglePause()
                }
                .secondaryTimerButton()
                .keyboardShortcut("p", modifiers: .command)

                Button("结束") {
                    appState.endSession()
                }
                .primaryTimerButton(color: appState.activeAccentColor)
                .keyboardShortcut("e", modifiers: .command)
            }

        case .focusCountup, .focusOvertime:
            HStack(spacing: 10) {
                Button(appState.isTimerRunning ? "暂停" : "继续") {
                    appState.togglePause()
                }
                .secondaryTimerButton(width: 74)
                .keyboardShortcut("p", modifiers: .command)

                Button("去休息") {
                    appState.startBreak()
                }
                .primaryTimerButton(color: .tockGreen, width: 88)
                .keyboardShortcut("r", modifiers: .command)

                Button("结束") {
                    appState.endSession()
                }
                .secondaryTimerButton(width: 74)
                .keyboardShortcut("e", modifiers: .command)
            }

        case .breakCountdown:
            HStack(spacing: 12) {
                Button(appState.isTimerRunning ? "暂停" : "继续") {
                    appState.togglePause()
                }
                .secondaryTimerButton()
                .keyboardShortcut("p", modifiers: .command)

                Button("结束") {
                    appState.endSession()
                }
                .primaryTimerButton(color: .tockGreen)
                .keyboardShortcut("e", modifiers: .command)
            }

        case .breakFinished:
            HStack(spacing: 12) {
                Button("下一段") {
                    appState.startNextFocusAfterBreak()
                }
                .primaryTimerButton(color: .tockCoral)
                .keyboardShortcut(.return, modifiers: .command)

                Button("结束") {
                    appState.endSession()
                }
                .secondaryTimerButton()
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}

private struct TimerModeSelector: View {
    @Binding var selection: TimerMode
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases) { mode in
                Button {
                    guard !isLocked else { return }
                    selection = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selection == mode ? Color.primaryText : Color.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(selection == mode ? Color.tockGreen.opacity(0.16) : Color.clear)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .frame(width: 170, height: 34)
        .background(Color.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.line)
        }
    }
}

private struct DurationEditorCard: View {
    let title: String
    @Binding var minutes: Int
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("", value: $minutes, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 38)
                    .disabled(isLocked)

                Text("分")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primaryText)
            }
        }
        .frame(width: 116, height: 50)
        .background(Color.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.line)
        }
        .opacity(isLocked ? 0.65 : 1)
    }
}

private extension Button {
    func primaryTimerButton(color: Color, width: CGFloat = 124) -> some View {
        self
            .buttonStyle(.plain)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: width, height: 46)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func secondaryTimerButton(width: CGFloat = 86) -> some View {
        self
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.primaryText)
            .frame(width: width, height: 46)
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.line)
            }
    }
}
