import Foundation

/// Один уровень стакана: цена и суммарный объём заявок по ней.
struct OrderBookLevel: Hashable, Sendable {
    let price: Decimal
    let quantity: Decimal

    var total: Decimal { price * quantity }
}

/// Биржевой стакан: заявки на покупку (bids) и на продажу (asks).
struct OrderBook: Equatable, Sendable {
    let symbol: String
    /// Заявки на покупку по убыванию цены: первая — лучшая.
    let bids: [OrderBookLevel]
    /// Заявки на продажу по возрастанию цены: первая — лучшая.
    let asks: [OrderBookLevel]

    var bestBid: Decimal? { bids.first?.price }
    var bestAsk: Decimal? { asks.first?.price }

    var spread: Decimal? {
        guard let bestBid, let bestAsk else { return nil }
        return bestAsk - bestBid
    }

    var midPrice: Decimal? {
        guard let bestBid, let bestAsk else { return nil }
        return (bestBid + bestAsk) / 2
    }
}

/// Одно обновление экрана монеты: свежий тикер и стакан.
struct MarketSnapshot: Sendable {
    let coin: Coin
    let orderBook: OrderBook
}
