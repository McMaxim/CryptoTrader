import Foundation
import Testing
@testable import CryptoTrader

@Suite("Торговый сервис")
struct TradingServiceTests {
    @Test("Сумма переводится в количество с округлением вниз до 8 знаков")
    func buyConvertsAmountToQuantity() async throws {
        let spy = SpyPortfolioRepository()
        let service = TradingService(portfolioRepository: spy)

        _ = try await service.buy(.stub("SOL"), spending: 100, at: 3)

        let order = try #require(await spy.executedOrders.first)
        #expect(order.side == .buy)
        #expect(order.quantity == dec("33.33333333"))
        #expect(order.price == 3)
    }

    @Test("Покупка меньше $1 запрещена")
    func buyRejectsTinyAmount() async {
        let service = TradingService(portfolioRepository: SpyPortfolioRepository())
        await #expect(throws: TradingError.amountBelowMinimum(1)) {
            _ = try await service.buy(.stub("SOL"), spending: dec("0.5"), at: 100)
        }
    }

    @Test("Без цены сделка невозможна")
    func rejectsZeroPrice() async {
        let service = TradingService(portfolioRepository: SpyPortfolioRepository())
        await #expect(throws: TradingError.priceUnavailable) {
            _ = try await service.sell(.stub("SOL"), quantity: 1, at: 0)
        }
    }
}

@Suite("Рейтинг")
struct LeaderboardServiceTests {
    @Test("Пользователь встаёт в рейтинг по своей доходности")
    func currentUserIsRankedByPnL() async throws {
        let portfolio = SpyPortfolioRepository()
        await portfolio.setPortfolio(Portfolio(
            cash: 9_000, initialBalance: 10_000,
            holdings: [Holding(symbol: "SOLUSDT", baseAsset: "SOL", quantity: 10, averagePrice: 100)],
            trades: [], tradesCount: 1
        ))
        // Цена выросла со 100 до 130: счёт = 9000 + 1300 = 10300, т.е. +3%.
        let market = StubMarketRepository(prices: ["SOLUSDT": 130])
        let service = LeaderboardService(
            leaderboardRepository: StubLeaderboardRepository(traders: [
                Trader(id: "a", name: "A", symbolName: "fish.fill", pnl: 500, initialBalance: 10_000, tradesCount: 5),
                Trader(id: "b", name: "B", symbolName: "pawprint.fill", pnl: -100, initialBalance: 10_000, tradesCount: 5),
            ]),
            profileRepository: StubProfileRepository(),
            portfolioRepository: portfolio,
            valuationService: PortfolioValuationService(marketRepository: market)
        )

        let leaderboard = try await service.leaderboard()

        #expect(leaderboard.entries.map(\.id) == ["a", LeaderboardService.currentUserID, "b"])
        let me = try #require(leaderboard.currentUser)
        #expect(me.rank == 2)
        #expect(me.pnl == 300)
        #expect(me.name == "Тест")
    }

    @Test("Без цен с биржи позиции оцениваются по цене покупки")
    func valuationFallsBackToAveragePrice() async {
        let service = PortfolioValuationService(marketRepository: StubMarketRepository(error: NetworkError.transport(.notConnectedToInternet)))
        let valuation = await service.valuate(Portfolio(
            cash: 9_000, initialBalance: 10_000,
            holdings: [Holding(symbol: "SOLUSDT", baseAsset: "SOL", quantity: 10, averagePrice: 100)],
            trades: [], tradesCount: 1
        ))
        #expect(valuation.equity == 10_000)
        #expect(valuation.usesLivePrices == false)
    }
}

@Suite("Разбор ответов Binance")
struct BinanceMapperTests {
    @Test("Тикер превращается в монету")
    func mapsTicker() throws {
        let json = """
        {"symbol":"SOLUSDT","openPrice":"100.00000000","highPrice":"110.5","lowPrice":"95.1",
         "lastPrice":"104.09000000","volume":"1774688.194","quoteVolume":"185630607.24684","count":550571}
        """
        let dto = try JSONDecoder().decode(BinanceMiniTickerDTO.self, from: Data(json.utf8))
        let coin = try #require(BinanceMapper.coin(from: dto))

        #expect(coin.baseAsset == "SOL")
        #expect(coin.name == "Solana")
        #expect(coin.lastPrice == dec("104.09"))
        #expect(abs(coin.priceChangePercent - 4.09) < 0.0001)
        #expect(coin.trend == .up)
    }

    @Test("Пары не к USDT отбрасываются")
    func skipsNonUSDTPairs() throws {
        let json = """
        {"symbol":"ETHBTC","openPrice":"1","highPrice":"1","lowPrice":"1","lastPrice":"1","quoteVolume":"1","count":1}
        """
        let dto = try JSONDecoder().decode(BinanceMiniTickerDTO.self, from: Data(json.utf8))
        #expect(BinanceMapper.coin(from: dto) == nil)
    }

    @Test("Стакан: лучшие цены и спред")
    func mapsOrderBook() throws {
        let json = """
        {"lastUpdateId":1,"bids":[["104.08","275.161"],["104.07","279.173"]],"asks":[["104.09","161.751"],["104.10","317.055"]]}
        """
        let dto = try JSONDecoder().decode(BinanceDepthDTO.self, from: Data(json.utf8))
        let book = BinanceMapper.orderBook(symbol: "SOLUSDT", from: dto)

        #expect(book.bestBid == dec("104.08"))
        #expect(book.bestAsk == dec("104.09"))
        #expect(book.spread == dec("0.01"))
        #expect(book.bids.count == 2)
    }

    @Test("Список пар для запроса цен корректно кодируется в URL")
    func encodesSymbolsQuery() {
        let url = BinanceAPI.prices(symbols: ["SOLUSDT", "ETHUSDT"])
        #expect(url.absoluteString == "https://api.binance.com/api/v3/ticker/price?symbols=%5B%22SOLUSDT%22%2C%22ETHUSDT%22%5D")
    }
}
