import Foundation
import SwiftData

/// Демо-счёт в SwiftData: баланс, позиции и история сделок.
///
/// Проверка баланса и запись сделки идут внутри одного вызова актора, поэтому
/// две одновременные покупки не смогут потратить одни и те же деньги.
@ModelActor
actor SwiftDataPortfolioRepository: PortfolioRepositoryProtocol {
    private static let tradesHistoryLimit = 50

    private var observers: [UUID: AsyncStream<Portfolio>.Continuation] = [:]

    func portfolio() throws -> Portfolio {
        try makePortfolio()
    }

    func execute(_ order: TradeOrder) throws -> TradeRecord {
        let account = try fetchOrCreateAccount()
        let holding = try fetchHolding(symbol: order.symbol)
        let total = order.total

        switch order.side {
        case .buy:
            guard account.cash >= total else {
                throw TradingError.insufficientFunds(available: account.cash)
            }
            account.cash -= total
            if let holding {
                let newQuantity = holding.quantity + order.quantity
                holding.averagePrice = ((holding.costBasis + total) / newQuantity).rounded(scale: 8)
                holding.quantity = newQuantity
            } else {
                modelContext.insert(HoldingEntity(
                    symbol: order.symbol,
                    baseAsset: order.baseAsset,
                    quantity: order.quantity,
                    averagePrice: order.price
                ))
            }

        case .sell:
            guard let holding, holding.quantity >= order.quantity else {
                throw TradingError.insufficientAsset(asset: order.baseAsset, available: holding?.quantity ?? 0)
            }
            account.cash += total
            holding.quantity -= order.quantity
            if holding.quantity <= 0 {
                modelContext.delete(holding)
            }
        }

        let trade = TradeEntity(order: order)
        modelContext.insert(trade)
        try modelContext.save()
        publish()

        return TradeRecord(
            id: trade.id, symbol: order.symbol, baseAsset: order.baseAsset, side: order.side,
            quantity: order.quantity, price: order.price, date: trade.date
        )
    }

    func reset() throws {
        try modelContext.fetch(FetchDescriptor<HoldingEntity>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<TradeEntity>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<AccountEntity>()).forEach(modelContext.delete)
        modelContext.insert(AccountEntity(initialBalance: Portfolio.defaultInitialBalance))
        try modelContext.save()
        publish()
    }

    func updates() -> AsyncStream<Portfolio> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Portfolio.self, bufferingPolicy: .bufferingNewest(1)
        )
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        if let current = try? makePortfolio() {
            continuation.yield(current)
        }
        return stream
    }

    // MARK: - Private

    private func publish() {
        guard !observers.isEmpty, let portfolio = try? makePortfolio() else { return }
        for continuation in observers.values {
            continuation.yield(portfolio)
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func makePortfolio() throws -> Portfolio {
        let account = try fetchOrCreateAccount()
        let holdings = try modelContext.fetch(FetchDescriptor<HoldingEntity>(sortBy: [SortDescriptor(\.symbol)]))

        var recentTrades = FetchDescriptor<TradeEntity>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        recentTrades.fetchLimit = Self.tradesHistoryLimit
        let trades = try modelContext.fetch(recentTrades)
        let tradesCount = try modelContext.fetchCount(FetchDescriptor<TradeEntity>())

        return Portfolio(
            cash: account.cash,
            initialBalance: account.initialBalance,
            holdings: holdings.map { $0.toDomain() },
            trades: trades.compactMap { $0.toDomain() },
            tradesCount: tradesCount
        )
    }

    private func fetchOrCreateAccount() throws -> AccountEntity {
        if let account = try modelContext.fetch(FetchDescriptor<AccountEntity>()).first {
            return account
        }
        let account = AccountEntity(initialBalance: Portfolio.defaultInitialBalance)
        modelContext.insert(account)
        try modelContext.save()
        return account
    }

    private func fetchHolding(symbol: String) throws -> HoldingEntity? {
        var descriptor = FetchDescriptor<HoldingEntity>(predicate: #Predicate { $0.symbol == symbol })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

private extension HoldingEntity {
    var costBasis: Decimal { quantity * averagePrice }
}
