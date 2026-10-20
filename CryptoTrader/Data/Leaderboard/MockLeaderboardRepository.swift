import Foundation

/// Локальная замена серверного рейтинга: фиксированный список трейдеров,
/// задержка имитирует сетевой запрос. Для настоящего бэкенда достаточно
/// другой реализации `LeaderboardRepositoryProtocol`.
struct MockLeaderboardRepository: LeaderboardRepositoryProtocol {
    var latency: Duration = .milliseconds(300)

    func traders() async throws -> [Trader] {
        try await Task.sleep(for: latency)
        return Self.traders
    }

    static let traders: [Trader] = [
        trader("whale", "CryptoWhale", "fish.fill", pnl: "4820.15", trades: 312),
        trader("alexey", "Алексей К.", "pawprint.fill", pnl: "2310.40", trades: 148),
        trader("maria", "Мария_SOL", "moon.stars.fill", pnl: "1675.92", trades: 96),
        trader("hodler", "HODLer", "diamond.fill", pnl: "890.00", trades: 12),
        trader("dmitry", "Дмитрий", "flame.fill", pnl: "341.27", trades: 57),
        trader("satoshi", "SatoshiFan", "bitcoinsign", pnl: "-120.55", trades: 203),
        trader("anna", "Анна Т.", "leaf.fill", pnl: "-684.10", trades: 41),
        trader("bear", "BearMarket", "chart.line.downtrend.xyaxis", pnl: "-1532.80", trades: 77),
        trader("moon", "Moonboy", "moon.fill", pnl: "-2950.00", trades: 489),
    ]

    private static func trader(_ id: String, _ name: String, _ symbolName: String, pnl: String, trades: Int) -> Trader {
        Trader(
            id: id,
            name: name,
            symbolName: symbolName,
            pnl: Decimal(string: pnl, locale: Locale(identifier: "en_US_POSIX")) ?? 0,
            initialBalance: Portfolio.defaultInitialBalance,
            tradesCount: trades
        )
    }
}
