import Foundation
@testable import CryptoTrader

func dec(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}

extension Coin {
    static func stub(_ base: String, price: String = "100") -> Coin {
        Coin(
            symbol: "\(base)USDT", baseAsset: base, quoteAsset: "USDT", name: base,
            lastPrice: dec(price), openPrice: dec(price), highPrice: dec(price), lowPrice: dec(price),
            quoteVolume: 1_000
        )
    }
}

/// Рынок из заранее заданного списка — для тестов пагинации и рейтинга.
struct StubMarketRepository: MarketRepositoryProtocol {
    var coins: [Coin] = []
    var prices: [String: Decimal] = [:]
    var error: (any Error)?

    func coins(page: Int, pageSize: Int, forceRefresh: Bool) async throws -> Page<Coin> {
        if let error { throw error }
        let start = page * pageSize
        let end = min(start + pageSize, coins.count)
        let items = start < end ? Array(coins[start..<end]) : []
        return Page(items: items, index: page, hasMore: end < coins.count)
    }

    func coin(symbol: String) async throws -> Coin {
        guard let coin = coins.first(where: { $0.symbol == symbol }) else { throw NetworkError.http(statusCode: 400) }
        return coin
    }

    func prices(symbols: [String]) async throws -> [String: Decimal] {
        if let error { throw error }
        return prices
    }

    func orderBook(symbol: String, depth: Int) async throws -> OrderBook {
        OrderBook(symbol: symbol, bids: [], asks: [])
    }
}

actor StubProfileRepository: ProfileRepositoryProtocol {
    var current = UserProfile(name: "Тест", avatarData: nil)

    func profile() -> UserProfile { current }
    func save(_ profile: UserProfile) { current = profile }
    func updates() -> AsyncStream<UserProfile> {
        AsyncStream { $0.yield(current) }
    }
}

/// Запоминает заявки, которые сервис отправил на исполнение.
actor SpyPortfolioRepository: PortfolioRepositoryProtocol {
    private(set) var executedOrders: [TradeOrder] = []
    var stubbedPortfolio = Portfolio(
        cash: Portfolio.defaultInitialBalance, initialBalance: Portfolio.defaultInitialBalance,
        holdings: [], trades: [], tradesCount: 0
    )

    func setPortfolio(_ portfolio: Portfolio) { stubbedPortfolio = portfolio }

    func portfolio() -> Portfolio { stubbedPortfolio }

    func execute(_ order: TradeOrder) -> TradeRecord {
        executedOrders.append(order)
        return TradeRecord(
            id: UUID(), symbol: order.symbol, baseAsset: order.baseAsset, side: order.side,
            quantity: order.quantity, price: order.price, date: .now
        )
    }

    func reset() {}

    func updates() -> AsyncStream<Portfolio> {
        AsyncStream { $0.yield(stubbedPortfolio) }
    }
}

struct StubLeaderboardRepository: LeaderboardRepositoryProtocol {
    var traders: [Trader]
    func traders() async throws -> [Trader] { traders }
}

struct StubLeaderboardService: LeaderboardServiceProtocol {
    var entries: [LeaderboardEntry]
    func leaderboard() async throws -> Leaderboard { Leaderboard(entries: entries) }
}

@MainActor
final class SpyRouter: AppRouting {
    private(set) var pushed: [Route] = []
    private(set) var leaderboardShown = 0

    func push(_ route: Route) { pushed.append(route) }
    func pop() {}
    func showLeaderboard() { leaderboardShown += 1 }
}
