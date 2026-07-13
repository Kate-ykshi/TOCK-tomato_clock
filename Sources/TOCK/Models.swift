import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case focus = "专注"
    case statistics = "统计"
    case tasks = "任务"

    var id: String { rawValue }
}

enum TimerMode: String, CaseIterable, Identifiable {
    case countdown = "倒计时"
    case countup = "正计时"

    var id: String { rawValue }
}

enum StatisticsRange: String, CaseIterable, Codable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "今天"
        case .week:
            return "本周"
        case .month:
            return "本月"
        case .year:
            return "今年"
        }
    }
}

enum TimerSessionPhase: Equatable {
    case idle
    case focusCountdown
    case focusCountup
    case focusOvertime
    case breakCountdown
    case breakFinished

    var isFocusPhase: Bool {
        switch self {
        case .focusCountdown, .focusCountup, .focusOvertime:
            return true
        case .idle, .breakCountdown, .breakFinished:
            return false
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .breakFinished:
            return false
        case .focusCountdown, .focusCountup, .focusOvertime, .breakCountdown:
            return true
        }
    }
}

enum TockColorToken: String, CaseIterable, Codable, Identifiable {
    case tockGreen
    case deepGreen
    case tockAmber
    case deepAmber
    case tockCoral
    case deepCoral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tockGreen:
            return "蓝色"
        case .deepGreen:
            return "绿色"
        case .tockAmber:
            return "黄色"
        case .deepAmber:
            return "紫色"
        case .tockCoral:
            return "红色"
        case .deepCoral:
            return "橙色"
        }
    }

    var color: Color {
        switch self {
        case .tockGreen:
            return .tockGreen
        case .deepGreen:
            return .deepGreen
        case .tockAmber:
            return .tockAmber
        case .deepAmber:
            return .deepAmber
        case .tockCoral:
            return .tockCoral
        case .deepCoral:
            return .deepCoral
        }
    }

    var companionTaskColor: TockColorToken {
        switch self {
        case .tockGreen, .deepGreen:
            return .deepGreen
        case .tockAmber, .deepAmber:
            return .deepAmber
        case .tockCoral, .deepCoral:
            return .deepCoral
        }
    }
}

struct FocusCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var colorToken: TockColorToken
    var tasks: [FocusTask]

    init(id: UUID = UUID(), name: String, colorToken: TockColorToken, tasks: [FocusTask]) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.tasks = tasks
    }

    var color: Color {
        colorToken.color
    }

    var todayTotalSeconds: Int {
        tasks.reduce(0) { $0 + $1.todayDurationSeconds }
    }

    var visibleTasks: [FocusTask] {
        tasks
            .filter { !$0.isArchived }
            .sorted {
                switch ($0.lastUsedAt, $1.lastUsedAt) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return $0.name < $1.name
                }
            }
    }

    var archivedTasks: [FocusTask] {
        tasks.filter(\.isArchived)
    }

    var todayTotalText: String {
        "今日 \(DurationText.compact(todayTotalSeconds))"
    }
}

struct FocusTask: Identifiable, Codable {
    let id: UUID
    var name: String
    var todayDurationSeconds: Int
    var bulletColorToken: TockColorToken
    var isArchived: Bool
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        todayDurationSeconds: Int,
        bulletColorToken: TockColorToken,
        isArchived: Bool = false,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.todayDurationSeconds = todayDurationSeconds
        self.bulletColorToken = bulletColorToken
        self.isArchived = isArchived
        self.lastUsedAt = lastUsedAt
    }

    var bulletColor: Color {
        bulletColorToken.color
    }

    var todayDurationText: String {
        DurationText.compact(todayDurationSeconds)
    }
}

struct FocusTaskSuggestion: Identifiable {
    let id: UUID
    let taskID: UUID
    let taskName: String
    let categoryID: UUID
    let categoryName: String
    let categoryColor: Color
    let bulletColor: Color
    let todayDurationText: String
}

struct FocusSessionRecord: Identifiable, Codable {
    let id: UUID
    var taskID: UUID
    var taskName: String
    var categoryID: UUID
    var categoryName: String
    var categoryColorToken: TockColorToken
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int

    init(
        id: UUID = UUID(),
        taskID: UUID,
        taskName: String,
        categoryID: UUID,
        categoryName: String,
        categoryColorToken: TockColorToken,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int
    ) {
        self.id = id
        self.taskID = taskID
        self.taskName = taskName
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.categoryColorToken = categoryColorToken
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
    }
}

enum DurationText {
    static func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    static func signedClock(_ seconds: Int) -> String {
        "+\(clock(seconds))"
    }

    static func compact(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours)h\(remainingMinutes)m" : "\(hours)h"
        }

        return "\(remainingMinutes)m"
    }

    static func chinese(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours)小时 \(remainingMinutes)分钟" : "\(hours)小时"
        }

        return "\(remainingMinutes)分钟"
    }

    static func decimalHours(_ seconds: Int) -> String {
        let hours = Double(max(0, seconds)) / 3600
        let rounded = (hours * 10).rounded() / 10
        if rounded == floor(rounded) {
            return "\(Int(rounded)) 小时"
        }
        return String(format: "%.1f 小时", rounded)
    }
}

extension Color {
    static let appBackground = Color(red: 0.90, green: 0.95, blue: 0.99)
    static let panelBackground = Color(red: 0.94, green: 0.98, blue: 1.00)
    static let cardBackground = Color.white.opacity(0.86)
    static let line = Color(red: 0.80, green: 0.88, blue: 0.94)
    static let primaryText = Color(red: 0.13, green: 0.15, blue: 0.17)
    static let secondaryText = Color(red: 0.45, green: 0.51, blue: 0.56)
    static let deleteRed = Color(red: 0.87, green: 0.20, blue: 0.20)
    static let tockGreen = Color(red: 0.42, green: 0.69, blue: 0.94)
    static let deepGreen = Color(red: 0.35, green: 0.68, blue: 0.49)
    static let tockAmber = Color(red: 0.91, green: 0.70, blue: 0.26)
    static let deepAmber = Color(red: 0.58, green: 0.48, blue: 0.88)
    static let tockCoral = Color(red: 0.82, green: 0.32, blue: 0.31)
    static let deepCoral = Color(red: 0.88, green: 0.47, blue: 0.25)
}
