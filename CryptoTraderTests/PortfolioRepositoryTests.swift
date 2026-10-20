import Foundation
import Testing
@testable import CryptoTrader

@Suite("Демо-счёт в SwiftData")
struct PortfolioRepositoryTests {
    private let repository = SwiftDataPortfolioRepository(modelContainer: PersistenceContainer.makeInMemory())

    private func order(_ side: TradeSide, _ quantity: String, at price: String, base: String = "SOL") -> TradeOrder {
        TradeOrder(symbol: "\(base)USDT", baseAsset: base, side: side, quantity: dec(quantity), price: dec(price))
    }

    @Test("Новый счёт начинается с $10,000")
    func newAccountHasDefaultBalance() async throws {
        let portfolio = try await repository.portfolio()
        #expect(portfolio.cash == Portfolio.defaultInitialBalance)
        #expect(portfolio.holdings.isEmpty)
        #expect(portfolio.tradesCount == 0)
    }

    @Test("Покупка списывает деньги и создаёт позицию")
    func buyDebitsCashAndCreatesHolding() async throws {
        _ = try await repository.execute(order(.buy, "2", at: "100.5"))

        let portfolio = try await repository.portfolio()
        #expect(portfolio.cash == dec("9799"))
        #expect(portfolio.holding(for: "SOLUSDT")?.quantity == dec("2"))
        #expect(portfolio.holding(for: "SOLUSDT")?.averagePrice == dec("100.5"))
        #expect(portfolio.tradesCount == 1)
    }

    @Test("Повторная покупка усредняет цену")
    func secondBuyAveragesPrice() async throws {
        _ = try await repository.execute(order(.buy, "1", at: "100"))
        _ = try await repository.execute(order(.buy, "1", at: "200"))

        let holding = try await repository.portfolio().holding(for: "SOLUSDT")
        #expect(holding?.quantity == dec("2"))
        #expect(holding?.averagePrice == dec("150"))
    }

    @Test("Продажа всего закрывает позицию и возвращает деньги")
    func sellAllClosesPosition() async throws {
        _ = try await repository.execute(order(.buy, "2", at: "100"))
        _ = try await repository.execute(order(.sell, "2", at: "110"))

        let portfolio = try await repository.portfolio()
        #expect(portfolio.cash == dec("10020"))
        #expect(portfolio.holdings.isEmpty)
        #expect(portfolio.trades.map(\.side) == [.sell, .buy])
    }

    @Test("Нельзя потратить больше, чем есть")
    func cannotOverspend() async throws {
        await #expect(throws: TradingError.insufficientFunds(available: 10_000)) {
            _ = try await repository.execute(order(.buy, "1", at: "20000"))
        }
        #expect(try await repository.portfolio().cash == Portfolio.defaultInitialBalance)
    }

    @Test("Нельзя продать больше, чем куплено")
    func cannotOversell() async throws {
        _ = try await repository.execute(order(.buy, "1", at: "100"))
        await #expect(throws: TradingError.insufficientAsset(asset: "SOL", available: 1)) {
            _ = try await repository.execute(order(.sell, "1.5", at: "100"))
        }
    }

    @Test("Сброс возвращает начальное состояние")
    func resetRestoresInitialState() async throws {
        _ = try await repository.execute(order(.buy, "3", at: "50"))
        try await repository.reset()

        let portfolio = try await repository.portfolio()
        #expect(portfolio.cash == Portfolio.defaultInitialBalance)
        #expect(portfolio.holdings.isEmpty)
        #expect(portfolio.tradesCount == 0)
    }

    @Test("Decimal сохраняется без потери точности")
    func decimalPrecisionSurvivesPersistence() async throws {
        _ = try await repository.execute(order(.buy, "0.1", at: "0.2", base: "DOGE"))
        _ = try await repository.execute(order(.buy, "0.00000001", at: "123456.78", base: "BTC"))

        let portfolio = try await repository.portfolio()
        #expect(portfolio.cash == dec("10000") - dec("0.02") - dec("0.0012345678"))
        #expect(portfolio.holding(for: "BTCUSDT")?.quantity == dec("0.00000001"))
    }

    @Test("Подписчики получают изменения портфеля")
    func updatesStreamPublishesChanges() async throws {
        let stream = await repository.updates()
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial?.cash == Portfolio.defaultInitialBalance)

        _ = try await repository.execute(order(.buy, "1", at: "100"))
        let updated = await iterator.next()
        #expect(updated?.cash == dec("9900"))
    }
}
