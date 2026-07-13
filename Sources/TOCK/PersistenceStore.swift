import Foundation

struct AppSnapshot: Codable {
    var userName: String
    var showsTimerInMenuBar: Bool
    var notificationsEnabled: Bool
    var activeDayIdentifier: String
    var selectedStatisticsRange: StatisticsRange
    var selectedStatisticsCategoryID: UUID?
    var focusMinutes: Int
    var breakMinutes: Int
    var selectedCategoryID: UUID
    var categories: [FocusCategory]
    var focusSegmentCount: Int
    var focusSessions: [FocusSessionRecord]

    init(
        userName: String,
        showsTimerInMenuBar: Bool,
        notificationsEnabled: Bool,
        activeDayIdentifier: String,
        selectedStatisticsRange: StatisticsRange,
        selectedStatisticsCategoryID: UUID?,
        focusMinutes: Int,
        breakMinutes: Int,
        selectedCategoryID: UUID,
        categories: [FocusCategory],
        focusSegmentCount: Int,
        focusSessions: [FocusSessionRecord]
    ) {
        self.userName = userName
        self.showsTimerInMenuBar = showsTimerInMenuBar
        self.notificationsEnabled = notificationsEnabled
        self.activeDayIdentifier = activeDayIdentifier
        self.selectedStatisticsRange = selectedStatisticsRange
        self.selectedStatisticsCategoryID = selectedStatisticsCategoryID
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.selectedCategoryID = selectedCategoryID
        self.categories = categories
        self.focusSegmentCount = focusSegmentCount
        self.focusSessions = focusSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "TOCK"
        showsTimerInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showsTimerInMenuBar) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        activeDayIdentifier = try container.decodeIfPresent(String.self, forKey: .activeDayIdentifier)
            ?? Self.dayIdentifier(for: Date())
        selectedStatisticsRange = try container.decodeIfPresent(StatisticsRange.self, forKey: .selectedStatisticsRange) ?? .day
        selectedStatisticsCategoryID = try container.decodeIfPresent(UUID.self, forKey: .selectedStatisticsCategoryID)
        focusMinutes = try container.decode(Int.self, forKey: .focusMinutes)
        breakMinutes = try container.decode(Int.self, forKey: .breakMinutes)
        selectedCategoryID = try container.decode(UUID.self, forKey: .selectedCategoryID)
        categories = try container.decode([FocusCategory].self, forKey: .categories)
        focusSegmentCount = try container.decode(Int.self, forKey: .focusSegmentCount)
        focusSessions = try container.decodeIfPresent([FocusSessionRecord].self, forKey: .focusSessions) ?? []
    }

    static func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

final class PersistenceStore {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folderURL = baseURL.appendingPathComponent("TOCK", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("state.json")
    }

    func load() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Local saving should never interrupt a focus session.
        }
    }
}
