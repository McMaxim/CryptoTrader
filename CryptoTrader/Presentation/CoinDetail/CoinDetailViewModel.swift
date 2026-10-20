import Foundation
import Observation

/// Расчёт сделки, который показывается в окне покупки/продажи.
struct TradeQuote: Equatable {
    /// Кнопки быстрого выбора: доля от доступного.
    static let quickFractions: [Decimal] = [0.25, 0.5, 0.75, 1]

    let side: TradeSide
    /// Цена исполнения: лучшая цена из стакана.
    let price: Decimal
    /// Сумма в USDT.
    let amount: Decimal
    let quantity: Decimal
    let availableText: String
    /// Почему нельзя совершить сделку (`nil` — можно или поле пока пустое).
    let validationMessage: String?
    let canSubmit: Bool
}

/// Контракт экрана монеты.
@MainActor
protocol CoinDetailViewModelProtocol: AnyObject, Observable, LeaderboardNavigable {
    var coin: Coin { get }
    var orderBook: OrderBook? { get }
    /// Куда сдвинулась цена на последнем обновлении — для стрелки у цены.
    var tickTrend: PriceTrend { get }
    var streamError: String? { get }
    var holding: Holding? { get }
    var cash: Decimal { get }

    /// Открытое окно сделки (`nil` — закрыто).
    var activeTradeSide: TradeSide? { get set }
    var amountText: String { get set }
    var quote: TradeQuote? { get }
    var isSubmitting: Bool { get }
    var tradeError: String? { get }
    var toastMessage: String? { get }

    func startLiveUpdates() async
    func observePortfolio() async
    func beginTrade(_ side: TradeSide)
    /// Быстрый выбор: доля от доступного (0.25, 0.5, 0.75, 1).
    func applyFraction(_ fraction: Decimal)
    func submitTrade() async
    func dismissToast()
    func showChart()
}

@MainActor
@Observable
final class CoinDetailViewModel: CoinDetailViewModelProtocol {
    static let orderBookDepth = 15

    private(set) var coin: Coin
    private(set) var orderBook: OrderBook?
    private(set) var tickTrend: PriceTrend
    private(set) var streamError: String?
    private(set) var holding: Holding?
    private(set) var cash: Decimal = 0

    var activeTradeSide: TradeSide?
    var amountText = ""
    private(set) var isSubmitting = false
    private(set) var tradeError: String?
    private(set) var toastMessage: String?

    /// Доля, выбранная кнопкой «100%» и т.п. Действует, пока текст поля не меняли руками.
    @ObservationIgnored private var selectedFraction: (fraction: Decimal, text: String)?
    @ObservationIgnored private let liveMarketService: any LiveMarketServiceProtocol
    @ObservationIgnored private let portfolioRepository: any PortfolioRepositoryProtocol
    @ObservationIgnored private let tradingService: any TradingServiceProtocol
    @ObservationIgnored private let router: any AppRouting

    init(
        coin: Coin,
        liveMarketService: any LiveMarketServiceProtocol,
        portfolioRepository: any PortfolioRepositoryProtocol,
        tradingService: any TradingServiceProtocol,
        router: any AppRouting
    ) {
        self.coin = coin
        self.tickTrend = coin.trend
        self.liveMarketService = liveMarketService
        self.portfolioRepository = portfolioRepository
        self.tradingService = tradingService
        self.router = router
    }

    // MARK: - Live data

    func startLiveUpdates() async {
        for await result in liveMarketService.snapshots(for: coin.symbol, depth: Self.orderBookDepth) {
            switch result {
            case .success(let snapshot):
                let trend = PriceTrend(delta: snapshot.coin.lastPrice - coin.lastPrice)
                if trend != .flat { tickTrend = trend }
                coin = snapshot.coin
                orderBook = snapshot.orderBook
                streamError = nil
            case .failure(let error):
                streamError = error.localizedDescription
            }
        }
    }

    func observePortfolio() async {
        for await portfolio in await portfolioRepository.updates() {
            cash = portfolio.cash
            holding = portfolio.holding(for: coin.symbol)
        }
    }

    // MARK: - Trading

    var quote: TradeQuote? {
        guard let side = activeTradeSide else { return nil }
        let price = executionPrice(for: side)
        let amount = Decimal(userInput: amountText)

        var quantity: Decimal = 0
        if let amount, price > 0 {
            if side == .sell, let holding, let selectedFraction,
               selectedFraction.fraction == 1, selectedFraction.text == amountText {
                // «Продать всё» — ровно всё количество, без остатка от округления.
                quantity = holding.quantity
            } else {
                quantity = (amount / price).rounded(scale: TradingService.quantityScale, mode: .down)
            }
        }

        let message = validationMessage(side: side, amount: amount, quantity: quantity)
        return TradeQuote(
            side: side,
            price: price,
            amount: amount ?? 0,
            quantity: quantity,
            availableText: availableText(for: side, price: price),
            validationMessage: message,
            canSubmit: message == nil && (amount ?? 0) > 0 && quantity > 0
        )
    }

    func beginTrade(_ side: TradeSide) {
        amountText = ""
        selectedFraction = nil
        tradeError = nil
        activeTradeSide = side
    }

    func applyFraction(_ fraction: Decimal) {
        guard let side = activeTradeSide else { return }
        let available: Decimal = switch side {
        case .buy: cash
        case .sell: (holding?.quantity ?? 0) * executionPrice(for: .sell)
        }
        let text = (available * fraction).rounded(scale: 2, mode: .down).plainString
        amountText = text
        selectedFraction = (fraction, text)
        tradeError = nil
    }

    func submitTrade() async {
        guard let side = activeTradeSide, let quote, quote.canSubmit, !isSubmitting else { return }
        isSubmitting = true
        tradeError = nil
        defer { isSubmitting = false }

        do {
            let record: TradeRecord
            switch side {
            case .buy:
                record = try await tradingService.buy(coin, spending: quote.amount, at: quote.price)
            case .sell:
                record = try await tradingService.sell(coin, quantity: quote.quantity, at: quote.price)
            }
            activeTradeSide = nil
            let verb = side == .buy ? "Куплено" : "Продано"
            toastMessage = "\(verb) \(record.quantity.formattedQuantity) \(record.baseAsset) по $\(record.price.formattedPrice)"
        } catch {
            tradeError = error.localizedDescription
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    // MARK: - Navigation

    func showChart() {
        router.push(.chart(coin))
    }

    func openLeaderboard() {
        router.showLeaderboard()
    }

    // MARK: - Private

    /// Покупаем по лучшей цене продавца, продаём по лучшей цене покупателя.
    private func executionPrice(for side: TradeSide) -> Decimal {
        switch side {
        case .buy: orderBook?.bestAsk ?? coin.lastPrice
        case .sell: orderBook?.bestBid ?? coin.lastPrice
        }
    }

    private func availableText(for side: TradeSide, price: Decimal) -> String {
        switch side {
        case .buy:
            return "Доступно: \(cash.formattedUSD)"
        case .sell:
            let quantity = holding?.quantity ?? 0
            return "Доступно: \(quantity.formattedQuantity) \(coin.baseAsset) ≈ \((quantity * price).formattedUSD)"
        }
    }

    private func validationMessage(side: TradeSide, amount: Decimal?, quantity: Decimal) -> String? {
        guard !amountText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let amount, amount > 0 else { return TradingError.invalidAmount.errorDescription }

        switch side {
        case .buy:
            if amount < TradingService.minimumOrderValue {
                return TradingError.amountBelowMinimum(TradingService.minimumOrderValue).errorDescription
            }
            if amount > cash {
                return TradingError.insufficientFunds(available: cash).errorDescription
            }
        case .sell:
            let available = holding?.quantity ?? 0
            if available == 0 {
                return "У вас пока нет \(coin.baseAsset)"
            }
            if quantity > available {
                return TradingError.insufficientAsset(asset: coin.baseAsset, available: available).errorDescription
            }
        }
        return nil
    }
}
