import Foundation

/// Бизнес-логика покупки и продажи на демо-счёте.
protocol TradingServiceProtocol: Sendable {
    /// Купить монету на сумму `amount` (в USDT) по цене `price`.
    func buy(_ coin: Coin, spending amount: Decimal, at price: Decimal) async throws -> TradeRecord
    /// Продать `quantity` монет по цене `price`.
    func sell(_ coin: Coin, quantity: Decimal, at price: Decimal) async throws -> TradeRecord
}

struct TradingService: TradingServiceProtocol {
    static let minimumOrderValue: Decimal = 1
    /// Точность количества монет, как на бирже.
    static let quantityScale = 8

    let portfolioRepository: any PortfolioRepositoryProtocol

    func buy(_ coin: Coin, spending amount: Decimal, at price: Decimal) async throws -> TradeRecord {
        guard price > 0 else { throw TradingError.priceUnavailable }
        guard amount > 0 else { throw TradingError.invalidAmount }
        guard amount >= Self.minimumOrderValue else {
            throw TradingError.amountBelowMinimum(Self.minimumOrderValue)
        }
        let quantity = (amount / price).rounded(scale: Self.quantityScale, mode: .down)
        guard quantity > 0 else { throw TradingError.invalidAmount }

        return try await portfolioRepository.execute(TradeOrder(
            symbol: coin.symbol, baseAsset: coin.baseAsset, side: .buy, quantity: quantity, price: price
        ))
    }

    func sell(_ coin: Coin, quantity: Decimal, at price: Decimal) async throws -> TradeRecord {
        guard price > 0 else { throw TradingError.priceUnavailable }
        let quantity = quantity.rounded(scale: Self.quantityScale, mode: .down)
        guard quantity > 0 else { throw TradingError.invalidAmount }

        return try await portfolioRepository.execute(TradeOrder(
            symbol: coin.symbol, baseAsset: coin.baseAsset, side: .sell, quantity: quantity, price: price
        ))
    }
}
