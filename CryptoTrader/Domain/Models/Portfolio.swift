import Foundation

enum TradeSide: String, Sendable, Codable, CaseIterable {
    case buy
    case sell
}

/// Позиция на демо-счёте.
struct Holding: Identifiable, Hashable, Sendable {
    let symbol: String
    let baseAsset: String
    let quantity: Decimal
    /// Средняя цена покупки.
    let averagePrice: Decimal

    var id: String { symbol }
    var costBasis: Decimal { quantity * averagePrice }
}

/// Исполненная сделка.
struct TradeRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let symbol: String
    let baseAsset: String
    let side: TradeSide
    let quantity: Decimal
    let price: Decimal
    let date: Date

    var total: Decimal { quantity * price }
}

/// Демо-счёт: свободные деньги, позиции и последние сделки.
struct Portfolio: Equatable, Sendable {
    static let defaultInitialBalance: Decimal = 10_000

    let cash: Decimal
    let initialBalance: Decimal
    let holdings: [Holding]
    /// Последние сделки, новые сверху.
    let trades: [TradeRecord]
    /// Сколько всего сделок совершено.
    let tradesCount: Int

    func holding(for symbol: String) -> Holding? {
        holdings.first { $0.symbol == symbol }
    }
}

/// Заявка на исполнение на демо-счёте.
struct TradeOrder: Sendable {
    let symbol: String
    let baseAsset: String
    let side: TradeSide
    let quantity: Decimal
    let price: Decimal

    var total: Decimal { quantity * price }
}

/// Оценка портфеля по текущим рыночным ценам.
struct PortfolioValuation: Equatable, Sendable {
    struct Position: Identifiable, Equatable, Sendable {
        let holding: Holding
        let currentPrice: Decimal

        var id: String { holding.symbol }
        var value: Decimal { holding.quantity * currentPrice }
        var pnl: Decimal { value - holding.costBasis }
        var pnlPercent: Double {
            guard holding.costBasis != 0 else { return 0 }
            return (pnl / holding.costBasis * 100).doubleValue
        }
    }

    let cash: Decimal
    let initialBalance: Decimal
    let positions: [Position]
    /// `false`, если цены получить не удалось и позиции оценены по цене покупки.
    let usesLivePrices: Bool

    var positionsValue: Decimal { positions.reduce(0) { $0 + $1.value } }
    var equity: Decimal { cash + positionsValue }
    var pnl: Decimal { equity - initialBalance }
    var pnlPercent: Double {
        guard initialBalance != 0 else { return 0 }
        return (pnl / initialBalance * 100).doubleValue
    }
}
