import Foundation

struct ClickPosition: Codable, Equatable {
    var x: Double
    var y: Double
}

struct AppConfig: Codable, Equatable {
    var timerEnabled: Bool = false
    var timerHours: Int = 1
    var timerMinutes: Int = 0
    var startAfter: TimeInterval = 10
    var clickInterval: TimeInterval = 1
    var clickButton: MouseButton = .left
    var clickPosition: ClickPosition?
    var keepAwakeEnabled: Bool = false
    var scheduleEnabled: Bool = false
    var scheduleStartHour: Int = 9
    var scheduleStartMinute: Int = 0
    var scheduleEndHour: Int = 18
    var scheduleEndMinute: Int = 0
    var batteryProtectionEnabled: Bool = false
    var batteryThreshold: Int = 5
    var language: AppLanguage = .english
    var theme: AppTheme = .system

    enum CodingKeys: String, CodingKey {
        case timerEnabled, timerHours, timerMinutes, startAfter, clickInterval, clickButton, clickPosition
        case keepAwakeEnabled, scheduleEnabled, scheduleStartHour, scheduleStartMinute, scheduleEndHour, scheduleEndMinute
        case batteryProtectionEnabled, batteryThreshold, language, theme
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timerEnabled = try c.decodeIfPresent(Bool.self, forKey: .timerEnabled) ?? false
        timerHours = try c.decodeIfPresent(Int.self, forKey: .timerHours) ?? 1
        timerMinutes = try c.decodeIfPresent(Int.self, forKey: .timerMinutes) ?? 0
        startAfter = try c.decodeIfPresent(TimeInterval.self, forKey: .startAfter) ?? 10
        clickInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .clickInterval) ?? 1
        clickButton = try c.decodeIfPresent(MouseButton.self, forKey: .clickButton) ?? .left
        clickPosition = try c.decodeIfPresent(ClickPosition.self, forKey: .clickPosition)
        keepAwakeEnabled = try c.decodeIfPresent(Bool.self, forKey: .keepAwakeEnabled) ?? false
        scheduleEnabled = try c.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? false
        scheduleStartHour = try c.decodeIfPresent(Int.self, forKey: .scheduleStartHour) ?? 9
        scheduleStartMinute = try c.decodeIfPresent(Int.self, forKey: .scheduleStartMinute) ?? 0
        scheduleEndHour = try c.decodeIfPresent(Int.self, forKey: .scheduleEndHour) ?? 18
        scheduleEndMinute = try c.decodeIfPresent(Int.self, forKey: .scheduleEndMinute) ?? 0
        batteryProtectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .batteryProtectionEnabled) ?? false
        batteryThreshold = try c.decodeIfPresent(Int.self, forKey: .batteryThreshold) ?? 5
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
    }

    static let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("CursorFlow", isDirectory: true).appendingPathComponent("config.json")
    }()

    static func load() -> AppConfig {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            return AppConfig()
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: Self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("CursorFlow config save failed: \(error)")
        }
    }
}

enum MouseButton: String, Codable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "EN"
    case chinese = "中文"
    case japanese = "日本語"

    var id: String { rawValue }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: String? {
        switch self {
        case .system: nil
        case .light: "light"
        case .dark: "dark"
        }
    }
}

enum AppProfile: String, CaseIterable, Identifiable {
    case meeting = "Meeting"
    case reading = "Reading"
    case focus = "Focus"

    var id: String { rawValue }
}

struct BatteryStatus: Equatable {
    var percentage: Int?
    var isCharging: Bool
}
