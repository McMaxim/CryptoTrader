import Foundation

/// Оценивает портфель по текущим ценам биржи.
protocol PortfolioValuationServiceProtocol: Sendable {
    func valuate(_ portfolio: Portfolio) async -> PortfolioValuation
}

struct PortfolioValuationService: PortfolioValuationServiceProtocol {
    let marketRepository: any MarketRepositoryProtocol

    func valuate(_ portfolio: Portfolio) async -> PortfolioValuation {
        let symbols = portfolio.holdings.map(\.symbol)
        var prices: [String: Decimal] = [:]
        var usesLivePrices = true

        if !symbols.isEmpty {
            do {
                prices = try await marketRepository.prices(symbols: symbols)
            } catch {
                // Без сети не ломаем экран: оцениваем по цене покупки и помечаем это.
                usesLivePrices = false
            }
        }

        let positions = portfolio.holdings.map { holding in
            PortfolioValuation.Position(
                holding: holding,
                currentPrice: prices[holding.symbol] ?? holding.averagePrice
            )
        }
        return PortfolioValuation(
            cash: portfolio.cash,
            initialBalance: portfolio.initialBalance,
            positions: positions,
            usesLivePrices: usesLivePrices
        )
    }
}
