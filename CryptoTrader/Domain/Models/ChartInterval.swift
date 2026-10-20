import Foundation

/// Таймфрейм графика. `rawValue` — значение параметра `interval` у TradingView.
enum ChartInterval: String, CaseIterable, Identifiable, Sendable {
    case fifteenMinutes = "15"
    case oneHour = "60"
    case fourHours = "240"
    case oneDay = "D"
    case oneWeek = "W"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fifteenMinutes: "15м"
        case .oneHour: "1ч"
        case .fourHours: "4ч"
        case .oneDay: "1Д"
        case .oneWeek: "1Н"
        }
    }
}
