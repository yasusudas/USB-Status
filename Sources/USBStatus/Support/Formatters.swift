import Foundation

enum USBFormatters {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func shortTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func shortDateTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func watts(_ value: Double) -> String {
        if value == 0 {
            return "0.0 W"
        }
        return String(format: "%.1f W", value)
    }

    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func milliamps(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return "\(Int(value.rounded())) mA"
    }

    static func milliamps(_ value: Double?, language: AppLanguage) -> String {
        guard let value else { return L10n.text(.unknown, language) }
        return "\(Int(value.rounded())) mA"
    }

    static func compact(_ value: String?, fallback: String = "Unknown") -> String {
        guard let value else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func compact(_ value: String?, language: AppLanguage) -> String {
        compact(value, fallback: L10n.text(.unknown, language))
    }
}
