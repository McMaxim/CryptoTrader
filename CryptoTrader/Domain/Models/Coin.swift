import Foundation

/// Спотовая торговая пара, например SOL/USDT.
struct Coin: Identifiable, Hashable, Sendable {
    /// Тикер пары на бирже: `SOLUSDT`.
    let symbol: String
    /// Торгуемая монета: `SOL`.
    let baseAsset: String
    /// Валюта котировки: `USDT`.
    let quoteAsset: String
    /// Человекочитаемое имя: `Solana`.
    let name: String
    let lastPrice: Decimal
    /// Цена 24 часа назад — от неё считается изменение за сутки.
    let openPrice: Decimal
    let highPrice: Decimal
    let lowPrice: Decimal
    /// Оборот за 24 часа в валюте котировки.
    let quoteVolume: Decimal

    var id: String { symbol }
    var pairTitle: String { "\(baseAsset)/\(quoteAsset)" }
    var priceChange: Decimal { lastPrice - openPrice }

    var priceChangePercent: Double {
        guard openPrice != 0 else { return 0 }
        return (priceChange / openPrice * 100).doubleValue
    }

    var trend: PriceTrend { PriceTrend(delta: priceChange) }
}

/// Куда движется цена: вверх, вниз или стоит на месте.
enum PriceTrend: Sendable, Equatable {
    case up, down, flat

    init(delta: Decimal) {
        if delta > 0 {
            self = .up
        } else if delta < 0 {
            self = .down
        } else {
            self = .flat
        }
    }
}
