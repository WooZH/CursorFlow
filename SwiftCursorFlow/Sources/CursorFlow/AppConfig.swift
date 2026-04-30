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
    var batteryProtectionEnabled: Bool = false
    var batteryThreshold: Int = 5
    var language: AppLanguage = .english
    var theme: AppTheme = .system

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

struct BatteryStatus: Equatable {
    var percentage: Int?
    var isCharging: Bool
}
