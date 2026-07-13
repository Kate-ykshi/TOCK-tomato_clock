import Combine
import SwiftUI

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedPage: AppPage = .focus
    @Published var userName: String = "TOCK"
    @Published var showsTimerInMenuBar: Bool = true
    @Published var notificationsEnabled: Bool = true
    @Published var timerMode: TimerMode = .countdown
    @Published var focusMinutes: Int = 25
    @Published var breakMinutes: Int = 5
    @Published var isMenuBarTimerTemporarilyHidden: Bool = false
    @Published var selectedCategoryID: UUID
    @Published var taskInput: String = ""
    @Published var isEditingTasks: Bool = false
    @Published var selectedStatisticsRange: StatisticsRange = .day
    @Published var selectedStatisticsCategoryID: UUID?
    @Published var categories: [FocusCategory]
    @Published var focusSessions: [FocusSessionRecord]
    @Published private(set) var sessionPhase: TimerSessionPhase = .idle
    @Published private(set) var isTimerRunning: Bool = false
    @Published private(set) var remainingSeconds: Int = 25 * 60
    @Published private(set) var elapsedFocusSeconds: Int = 0
    @Published private(set) var overtimeSeconds: Int = 0
    @Published private(set) var focusSegmentCount: Int = 3

    private let persistenceStore = PersistenceStore()
    private var ticker: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var activeTaskID: UUID?
    private var activeCategoryID: UUID?
    private var currentFocusStartedAt: Date?
    private var lastTickDate: Date?
    private var activeDayIdentifier = AppSnapshot.dayIdentifier(for: Date())
    private var hasRecordedActiveFocus = false

    private init() {
        let defaultCategories = Self.defaultCategories()

        if let snapshot = persistenceStore.load(), !snapshot.categories.isEmpty {
            userName = snapshot.userName
            showsTimerInMenuBar = snapshot.showsTimerInMenuBar
            notificationsEnabled = snapshot.notificationsEnabled
            selectedStatisticsRange = snapshot.selectedStatisticsRange
            selectedStatisticsCategoryID = snapshot.selectedStatisticsCategoryID
            focusMinutes = snapshot.focusMinutes
            breakMinutes = snapshot.breakMinutes
            activeDayIdentifier = AppSnapshot.dayIdentifier(for: Date())
            let isSameSavedDay = snapshot.activeDayIdentifier == activeDayIdentifier
            categories = isSameSavedDay
                ? snapshot.categories
                : Self.resetTodayDurations(in: snapshot.categories)
            let loadedFocusSessions = isSameSavedDay && snapshot.focusSessions.isEmpty
                ? Self.backfilledFocusSessions(from: snapshot.categories)
                : snapshot.focusSessions
            focusSessions = loadedFocusSessions
            focusSegmentCount = isSameSavedDay
                ? snapshot.focusSegmentCount
                : loadedFocusSessions.filter { Calendar.current.isDateInToday($0.endedAt) }.count
            selectedCategoryID = snapshot.categories.contains(where: { $0.id == snapshot.selectedCategoryID })
                ? snapshot.selectedCategoryID
                : snapshot.categories[0].id
        } else {
            categories = defaultCategories
            focusSessions = Self.backfilledFocusSessions(from: defaultCategories)
            selectedCategoryID = defaultCategories[0].id
        }

        remainingSeconds = focusMinutes * 60
        setupAutosave()
    }

    deinit {
        ticker?.invalidate()
    }

    private static func defaultCategories() -> [FocusCategory] {
        let learning = FocusCategory(
            name: "学习",
            colorToken: .tockGreen,
            tasks: [
                FocusTask(name: "英语阅读", todayDurationSeconds: 0, bulletColorToken: .deepGreen),
                FocusTask(name: "SwiftUI 学习", todayDurationSeconds: 0, bulletColorToken: .tockGreen)
            ]
        )

        let writing = FocusCategory(
            name: "写作",
            colorToken: .tockCoral,
            tasks: [
                FocusTask(name: "PRD 整理", todayDurationSeconds: 0, bulletColorToken: .deepAmber),
                FocusTask(name: "日记", todayDurationSeconds: 0, bulletColorToken: .tockAmber)
            ]
        )

        let life = FocusCategory(
            name: "生活",
            colorToken: .deepGreen,
            tasks: [
                FocusTask(name: "整理房间", todayDurationSeconds: 0, bulletColorToken: .deepCoral),
                FocusTask(name: "散步", todayDurationSeconds: 0, bulletColorToken: .tockCoral)
            ]
        )

        return [learning, writing, life]
    }

    private static func resetTodayDurations(in categories: [FocusCategory]) -> [FocusCategory] {
        categories.map { category in
            var updatedCategory = category
            updatedCategory.tasks = category.tasks.map { task in
                var updatedTask = task
                updatedTask.todayDurationSeconds = 0
                return updatedTask
            }
            return updatedCategory
        }
    }

    private static func backfilledFocusSessions(from categories: [FocusCategory]) -> [FocusSessionRecord] {
        let calendar = Calendar.current
        var cursor = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            ?? Date().addingTimeInterval(-4 * 3600)
        var records: [FocusSessionRecord] = []

        for category in categories {
            for task in category.visibleTasks where task.todayDurationSeconds > 0 {
                let startedAt = cursor
                let endedAt = startedAt.addingTimeInterval(Double(task.todayDurationSeconds))
                records.append(
                    FocusSessionRecord(
                        taskID: task.id,
                        taskName: task.name,
                        categoryID: category.id,
                        categoryName: category.name,
                        categoryColorToken: category.colorToken,
                        startedAt: startedAt,
                        endedAt: endedAt,
                        durationSeconds: task.todayDurationSeconds
                    )
                )
                cursor = endedAt.addingTimeInterval(15 * 60)
            }
        }

        return records
    }

    var selectedCategory: FocusCategory {
        categories.first { $0.id == selectedCategoryID } ?? categories[0]
    }

    var settingsLocked: Bool {
        sessionPhase.isActive
    }

    var canStartFocus: Bool {
        !taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sessionPhase.isActive
    }

    var timerDisplay: String {
        switch sessionPhase {
        case .idle:
            return timerMode == .countdown ? DurationText.clock(focusMinutes * 60) : "00:00"
        case .focusCountdown, .breakCountdown:
            return DurationText.clock(remainingSeconds)
        case .focusCountup:
            return DurationText.clock(elapsedFocusSeconds)
        case .focusOvertime:
            return DurationText.signedClock(overtimeSeconds)
        case .breakFinished:
            return "00:00"
        }
    }

    var timerStatusText: String {
        switch sessionPhase {
        case .idle:
            return "准备专注"
        case .focusCountdown:
            return isTimerRunning ? "正在专注" : "专注已暂停"
        case .focusCountup:
            return isTimerRunning ? "正在正计时专注" : "专注已暂停"
        case .focusOvertime:
            return isTimerRunning ? "专注到点，正在加时" : "加时已暂停"
        case .breakCountdown:
            return isTimerRunning ? "休息中" : "休息已暂停"
        case .breakFinished:
            return "休息完成，等你开始下一段"
        }
    }

    var currentTaskName: String {
        if let activeTaskID,
           let task = categories.flatMap(\.tasks).first(where: { $0.id == activeTaskID }) {
            return task.name
        }

        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未选择任务" : trimmed
    }

    var todayFocusSeconds: Int {
        categories.reduce(0) { total, category in
            total + category.todayTotalSeconds
        }
    }

    var todayFocusText: String {
        DurationText.decimalHours(todayFocusSeconds)
    }

    var todayFocusChineseText: String {
        DurationText.chinese(todayFocusSeconds)
    }

    var averageFocusText: String {
        guard focusSegmentCount > 0 else { return "0分钟" }
        return DurationText.compact(todayFocusSeconds / focusSegmentCount)
    }

    var statusBarTitle: String {
        guard shouldShowMenuBarTimerText else { return "" }

        switch sessionPhase {
        case .focusCountdown, .focusCountup, .focusOvertime:
            return timerDisplay
        case .idle, .breakCountdown, .breakFinished:
            return ""
        }
    }

    var shouldShowMenuBarTimerText: Bool {
        guard showsTimerInMenuBar, !isMenuBarTimerTemporarilyHidden else { return false }

        switch sessionPhase {
        case .focusCountdown, .focusCountup, .focusOvertime:
            return true
        case .idle, .breakCountdown, .breakFinished:
            return false
        }
    }

    var activeAccentColor: Color {
        switch sessionPhase {
        case .breakCountdown, .breakFinished:
            return .tockGreen
        case .idle, .focusCountdown, .focusCountup, .focusOvertime:
            return .tockCoral
        }
    }

    var focusTaskSuggestions: [FocusTaskSuggestion] {
        let query = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        let suggestions = categories.flatMap { category in
            category.visibleTasks.compactMap { task -> (suggestion: FocusTaskSuggestion, score: Int, seconds: Int)? in
                let lowercasedName = task.name.lowercased()
                guard lowercasedName.contains(lowercasedQuery) else { return nil }

                let score: Int
                if lowercasedName == lowercasedQuery {
                    score = 0
                } else if lowercasedName.hasPrefix(lowercasedQuery) {
                    score = 1
                } else {
                    score = 2
                }

                return (
                    FocusTaskSuggestion(
                        id: task.id,
                        taskID: task.id,
                        taskName: task.name,
                        categoryID: category.id,
                        categoryName: category.name,
                        categoryColor: category.color,
                        bulletColor: task.bulletColor,
                        todayDurationText: task.todayDurationText
                    ),
                    score,
                    task.todayDurationSeconds
                )
            }
        }

        return suggestions
            .sorted {
                if $0.score != $1.score {
                    return $0.score < $1.score
                }
                return $0.seconds > $1.seconds
            }
            .map(\.suggestion)
            .prefix(3)
            .map { $0 }
    }

    func selectCategory(_ category: FocusCategory) {
        guard !settingsLocked else { return }
        selectedCategoryID = category.id
    }

    func selectTaskSuggestion(_ suggestion: FocusTaskSuggestion) {
        guard !settingsLocked else { return }
        taskInput = suggestion.taskName
        selectedCategoryID = suggestion.categoryID
    }

    func syncCategoryForExistingTaskName() {
        guard !settingsLocked else { return }
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let match = findTask(named: trimmed) {
            selectedCategoryID = match.categoryID
        }
    }

    func startFocus() {
        guard canStartFocus else { return }
        rolloverDayIfNeeded(now: Date())
        normalizeDurations()

        let resolvedTask = resolveTaskForSession()
        activeTaskID = resolvedTask.taskID
        activeCategoryID = resolvedTask.categoryID
        currentFocusStartedAt = Date()
        elapsedFocusSeconds = 0
        overtimeSeconds = 0
        hasRecordedActiveFocus = false

        if timerMode == .countdown {
            remainingSeconds = focusMinutes * 60
            sessionPhase = .focusCountdown
        } else {
            remainingSeconds = 0
            sessionPhase = .focusCountup
        }

        startTicker()
    }

    func togglePause() {
        guard sessionPhase.isActive else { return }
        isTimerRunning ? stopTicker(keepActive: true) : startTicker()
    }

    func startBreak() {
        guard sessionPhase.isFocusPhase else { return }
        commitFocusIfNeeded()
        normalizeDurations()

        remainingSeconds = breakMinutes * 60
        overtimeSeconds = 0
        sessionPhase = .breakCountdown
        startTicker()
    }

    func startNextFocusAfterBreak() {
        guard sessionPhase == .breakFinished else { return }
        sessionPhase = .idle
        startFocus()
    }

    func endSession() {
        if sessionPhase.isFocusPhase {
            commitFocusIfNeeded()
        }

        stopTicker(keepActive: false)
        sessionPhase = .idle
        remainingSeconds = focusMinutes * 60
        elapsedFocusSeconds = 0
        overtimeSeconds = 0
        currentFocusStartedAt = nil
        hasRecordedActiveFocus = false
    }

    func archiveTask(_ task: FocusTask) {
        for categoryIndex in categories.indices {
            if let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                categories[categoryIndex].tasks[taskIndex].isArchived = true
                return
            }
        }
    }

    func deleteTask(_ task: FocusTask) {
        if activeTaskID == task.id {
            endSession()
        }

        for categoryIndex in categories.indices {
            if let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                categories[categoryIndex].tasks.remove(at: taskIndex)
                return
            }
        }
    }

    func restoreTask(_ task: FocusTask) {
        for categoryIndex in categories.indices {
            if let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                categories[categoryIndex].tasks[taskIndex].isArchived = false
                return
            }
        }
    }

    func addCategory(name: String = "新分类", colorToken: TockColorToken? = nil) {
        let token = colorToken ?? nextCategoryColorToken()
        let category = FocusCategory(
            name: uniqueCategoryName(baseName: name),
            colorToken: token,
            tasks: []
        )

        categories.append(category)
        selectedCategoryID = category.id
    }

    var suggestedCategoryColorToken: TockColorToken {
        nextCategoryColorToken()
    }

    func updateCategoryName(_ category: FocusCategory, name: String) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[categoryIndex].name = name
    }

    func updateCategoryColor(_ category: FocusCategory, colorToken: TockColorToken) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[categoryIndex].colorToken = colorToken

        let visibleTaskIDs = categories[categoryIndex].visibleTasks.map(\.id)
        for visibleIndex in visibleTaskIDs.indices {
            guard let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == visibleTaskIDs[visibleIndex] }) else {
                continue
            }

            categories[categoryIndex].tasks[taskIndex].bulletColorToken = visibleIndex.isMultiple(of: 2)
                ? colorToken.companionTaskColor
                : colorToken
        }
    }

    func deleteCategory(_ category: FocusCategory) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else { return }

        let taskIDs = Set(categories[categoryIndex].tasks.map(\.id))
        if activeCategoryID == category.id || (activeTaskID.map { taskIDs.contains($0) } ?? false) {
            endSession()
        }

        categories.remove(at: categoryIndex)
        focusSessions.removeAll { $0.categoryID == category.id || taskIDs.contains($0.taskID) }

        if selectedStatisticsCategoryID == category.id {
            selectedStatisticsCategoryID = nil
        }

        if categories.isEmpty {
            let replacement = FocusCategory(
                name: "新分类",
                colorToken: nextCategoryColorToken(),
                tasks: []
            )
            categories = [replacement]
            selectedCategoryID = replacement.id
            return
        }

        if selectedCategoryID == category.id {
            let fallbackIndex = min(categoryIndex, categories.count - 1)
            selectedCategoryID = categories[fallbackIndex].id
        }
    }

    func addTask(to category: FocusCategory) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let visibleTaskCount = categories[categoryIndex].visibleTasks.count
        let task = FocusTask(
            name: uniqueTaskName(baseName: "新任务", in: categories[categoryIndex]),
            todayDurationSeconds: 0,
            bulletColorToken: visibleTaskCount.isMultiple(of: 2)
                ? categories[categoryIndex].colorToken.companionTaskColor
                : categories[categoryIndex].colorToken
        )

        categories[categoryIndex].tasks.append(task)
    }

    func updateTaskName(_ task: FocusTask, name: String) {
        for categoryIndex in categories.indices {
            if let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                categories[categoryIndex].tasks[taskIndex].name = name
                return
            }
        }
    }

    func toggleMenuBarTimerVisibility() {
        showsTimerInMenuBar.toggle()
        if showsTimerInMenuBar {
            isMenuBarTimerTemporarilyHidden = false
        }
    }

    func toggleMenuBarTimerTemporarilyHidden() {
        guard showsTimerInMenuBar else { return }

        switch sessionPhase {
        case .focusCountdown, .focusCountup, .focusOvertime:
            isMenuBarTimerTemporarilyHidden.toggle()
        case .idle, .breakCountdown, .breakFinished:
            break
        }
    }

    func selectStatisticsCategory(id: UUID?) {
        selectedStatisticsCategoryID = id
    }

    func prepareForTermination() {
        endSession()
        saveSnapshot()
    }

    func resetTasksAndStatistics() {
        endSession()
        let defaults = Self.defaultCategories()
        categories = defaults
        focusSessions = []
        selectedCategoryID = defaults[0].id
        selectedStatisticsCategoryID = nil
        selectedStatisticsRange = .day
        taskInput = ""
        focusSegmentCount = 0
        activeDayIdentifier = AppSnapshot.dayIdentifier(for: Date())
        saveSnapshot()
    }

    private func startTicker() {
        stopTicker(keepActive: true)
        isTimerRunning = true
        lastTickDate = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        ticker?.tolerance = 0.03

        if let ticker {
            RunLoop.main.add(ticker, forMode: .common)
        }
    }

    private func setupAutosave() {
        let settingsPublisher = Publishers.CombineLatest4(
            $userName,
            $focusMinutes,
            $breakMinutes,
            $selectedCategoryID
        )
        .map { _ in () }
        .eraseToAnyPublisher()

        let preferencePublisher = Publishers.CombineLatest3(
            $showsTimerInMenuBar,
            $notificationsEnabled,
            $selectedStatisticsRange
        )
        .map { _ in () }
        .eraseToAnyPublisher()

        let statisticsPublisher = Publishers.CombineLatest(
            $selectedStatisticsCategoryID,
            $focusSegmentCount
        )
        .map { _ in () }
        .eraseToAnyPublisher()

        let categoriesPublisher = $categories
            .map { _ in () }
            .eraseToAnyPublisher()

        let sessionsPublisher = $focusSessions
            .map { _ in () }
            .eraseToAnyPublisher()

        Publishers.Merge5(settingsPublisher, preferencePublisher, statisticsPublisher, categoriesPublisher, sessionsPublisher)
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSnapshot()
            }
            .store(in: &cancellables)
    }

    private func saveSnapshot() {
        persistenceStore.save(
            AppSnapshot(
                userName: userName,
                showsTimerInMenuBar: showsTimerInMenuBar,
                notificationsEnabled: notificationsEnabled,
                activeDayIdentifier: activeDayIdentifier,
                selectedStatisticsRange: selectedStatisticsRange,
                selectedStatisticsCategoryID: selectedStatisticsCategoryID,
                focusMinutes: focusMinutes,
                breakMinutes: breakMinutes,
                selectedCategoryID: selectedCategoryID,
                categories: categories,
                focusSegmentCount: focusSegmentCount,
                focusSessions: focusSessions
            )
        )
    }

    private func stopTicker(keepActive: Bool) {
        ticker?.invalidate()
        ticker = nil
        isTimerRunning = false
        lastTickDate = nil

        if !keepActive {
            activeTaskID = nil
            activeCategoryID = nil
        }
    }

    private func tick() {
        let now = Date()
        rolloverDayIfNeeded(now: now)
        let deltaSeconds = secondsSinceLastTick(now: now)
        guard deltaSeconds > 0 else { return }

        let result = TimerEngine.advance(
            TimerEngineState(
                phase: sessionPhase,
                remainingSeconds: remainingSeconds,
                elapsedFocusSeconds: elapsedFocusSeconds,
                overtimeSeconds: overtimeSeconds
            ),
            by: deltaSeconds
        )

        sessionPhase = result.state.phase
        remainingSeconds = result.state.remainingSeconds
        elapsedFocusSeconds = result.state.elapsedFocusSeconds
        overtimeSeconds = result.state.overtimeSeconds

        for event in result.events {
            switch event {
            case .focusFinished:
                sendNotification(
                    title: "专注时间到了",
                    body: "可以去休息，也可以继续加时。",
                    kind: .focusFinished
                )
            case .breakFinished:
                stopTicker(keepActive: true)
                sendNotification(
                    title: "休息结束啦",
                    body: "准备好后，手动开始下一段专注。",
                    kind: .breakFinished
                )
            }
        }
    }

    private func secondsSinceLastTick(now: Date) -> Int {
        guard let lastTickDate else {
            self.lastTickDate = now
            return 0
        }

        let seconds = Int(now.timeIntervalSince(lastTickDate).rounded(.down))
        guard seconds > 0 else { return 0 }

        self.lastTickDate = lastTickDate.addingTimeInterval(1)
        return 1
    }

    private func sendNotification(title: String, body: String, kind: TockNotificationKind) {
        guard notificationsEnabled else { return }
        NotificationManager.shared.send(title: title, body: body, kind: kind)
    }

    private func rolloverDayIfNeeded(now: Date) {
        let currentDayIdentifier = AppSnapshot.dayIdentifier(for: now)
        guard currentDayIdentifier != activeDayIdentifier else { return }

        categories = Self.resetTodayDurations(in: categories)
        focusSegmentCount = focusSessions.filter { Calendar.current.isDateInToday($0.endedAt) }.count
        activeDayIdentifier = currentDayIdentifier
    }

    private func normalizeDurations() {
        focusMinutes = min(max(focusMinutes, 1), 240)
        breakMinutes = min(max(breakMinutes, 1), 120)
    }

    private func resolveTaskForSession() -> (categoryID: UUID, taskID: UUID) {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = findTask(named: trimmed) {
            selectedCategoryID = match.categoryID
            return (match.categoryID, match.taskID)
        }

        let newTask = FocusTask(
            name: trimmed,
            todayDurationSeconds: 0,
            bulletColorToken: selectedCategory.colorToken
        )

        guard let categoryIndex = categories.firstIndex(where: { $0.id == selectedCategoryID }) else {
            categories[0].tasks.insert(newTask, at: 0)
            selectedCategoryID = categories[0].id
            return (categories[0].id, newTask.id)
        }

        categories[categoryIndex].tasks.insert(newTask, at: 0)
        return (categories[categoryIndex].id, newTask.id)
    }

    private func findTask(named name: String) -> (categoryID: UUID, taskID: UUID)? {
        for category in categories {
            if let task = category.tasks.first(where: { !$0.isArchived && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return (category.id, task.id)
            }
        }

        return nil
    }

    private func commitFocusIfNeeded() {
        guard !hasRecordedActiveFocus, elapsedFocusSeconds > 0 else { return }
        guard let activeTaskID,
              let categoryIndex = categories.firstIndex(where: { category in
                  category.tasks.contains(where: { $0.id == activeTaskID })
              }),
              let taskIndex = categories[categoryIndex].tasks.firstIndex(where: { $0.id == activeTaskID })
        else {
            return
        }

        let endedAt = Date()
        categories[categoryIndex].tasks[taskIndex].todayDurationSeconds += elapsedFocusSeconds
        categories[categoryIndex].tasks[taskIndex].lastUsedAt = endedAt
        focusSessions.append(
            FocusSessionRecord(
                taskID: categories[categoryIndex].tasks[taskIndex].id,
                taskName: categories[categoryIndex].tasks[taskIndex].name,
                categoryID: categories[categoryIndex].id,
                categoryName: categories[categoryIndex].name,
                categoryColorToken: categories[categoryIndex].colorToken,
                startedAt: currentFocusStartedAt ?? endedAt.addingTimeInterval(-Double(elapsedFocusSeconds)),
                endedAt: endedAt,
                durationSeconds: elapsedFocusSeconds
            )
        )
        focusSegmentCount += 1
        hasRecordedActiveFocus = true
    }

    private func nextCategoryColorToken() -> TockColorToken {
        let palette: [TockColorToken] = [.tockGreen, .deepGreen, .tockCoral, .tockAmber, .deepAmber, .deepCoral]
        return palette[categories.count % palette.count]
    }

    private func uniqueCategoryName(baseName: String) -> String {
        let existingNames = Set(categories.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private func uniqueTaskName(baseName: String, in category: FocusCategory) -> String {
        let existingNames = Set(category.tasks.filter { !$0.isArchived }.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }
}
