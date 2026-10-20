import Foundation

/// Собирает рейтинг: трейдеры «с сервера» плюс текущий пользователь с его демо-счётом.
protocol LeaderboardServiceProtocol: Sendable {
    func leaderboard() async throws -> Leaderboard
}

struct LeaderboardService: LeaderboardServiceProtocol {
    static let currentUserID = "me"

    let leaderboardRepository: any LeaderboardRepositoryProtocol
    let profileRepository: any ProfileRepositoryProtocol
    let portfolioRepository: any PortfolioRepositoryProtocol
    let valuationService: any PortfolioValuationServiceProtocol

    func leaderboard() async throws -> Leaderboard {
        // Три независимых источника грузятся параллельно (structured concurrency).
        async let traders = leaderboardRepository.traders()
        async let profile = profileRepository.profile()
        async let portfolio = portfolioRepository.portfolio()
        let (others, me, myPortfolio) = try await (traders, profile, portfolio)

        let valuation = await valuationService.valuate(myPortfolio)

        let rows: [Row] = others.map { trader in
            Row(
                id: trader.id,
                name: trader.name,
                avatar: .symbol(trader.symbolName),
                pnl: trader.pnl,
                pnlPercent: trader.initialBalance == 0 ? 0 : (trader.pnl / trader.initialBalance * 100).doubleValue,
                tradesCount: trader.tradesCount,
                isCurrentUser: false
            )
        } + [Row(
            id: Self.currentUserID,
            name: me.name,
            avatar: Avatar(profile: me),
            pnl: valuation.pnl,
            pnlPercent: valuation.pnlPercent,
            tradesCount: myPortfolio.tradesCount,
            isCurrentUser: true
        )]

        let entries = rows
            .sorted { lhs, rhs in
                lhs.pnlPercent != rhs.pnlPercent ? lhs.pnlPercent > rhs.pnlPercent : lhs.isCurrentUser
            }
            .enumerated()
            .map { index, row in
                LeaderboardEntry(
                    id: row.id,
                    rank: index + 1,
                    name: row.name,
                    avatar: row.avatar,
                    pnl: row.pnl,
                    pnlPercent: row.pnlPercent,
                    tradesCount: row.tradesCount,
                    isCurrentUser: row.isCurrentUser
                )
            }
        return Leaderboard(entries: entries)
    }

    private struct Row {
        let id: String
        let name: String
        let avatar: Avatar
        let pnl: Decimal
        let pnlPercent: Double
        let tradesCount: Int
        let isCurrentUser: Bool
    }
}
