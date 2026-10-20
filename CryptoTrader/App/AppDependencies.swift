import Foundation
import SwiftData

/// Composition root: единственное место, где создаются конкретные реализации.
/// Всё остальное приложение зависит только от протоколов (принцип инверсии зависимостей).
@MainActor
final class AppDependencies {
    let router: AppRouter
    let marketRepository: any MarketRepositoryProtocol
    let liveMarketService: any LiveMarketServiceProtocol
    let profileRepository: any ProfileRepositoryProtocol
    let portfolioRepository: any PortfolioRepositoryProtocol
    let tradingService: any TradingServiceProtocol
    let valuationService: any PortfolioValuationServiceProtocol
    let leaderboardService: any LeaderboardServiceProtocol
    let chartURLProvider: any ChartURLProviding
    let avatarProcessor: any AvatarProcessing

    init(modelContainer: ModelContainer, httpClient: any HTTPClient = URLSessionHTTPClient()) {
        router = AppRouter()

        let market = BinanceMarketRepository(client: httpClient)
        marketRepository = market
        liveMarketService = PollingLiveMarketService(repository: market, interval: .seconds(1))

        let profiles = SwiftDataProfileRepository(modelContainer: modelContainer)
        let portfolio = SwiftDataPortfolioRepository(modelContainer: modelContainer)
        profileRepository = profiles
        portfolioRepository = portfolio

        tradingService = TradingService(portfolioRepository: portfolio)
        let valuation = PortfolioValuationService(marketRepository: market)
        valuationService = valuation
        leaderboardService = LeaderboardService(
            leaderboardRepository: MockLeaderboardRepository(),
            profileRepository: profiles,
            portfolioRepository: portfolio,
            valuationService: valuation
        )

        chartURLProvider = TradingViewChartURLProvider()
        avatarProcessor = AvatarImageProcessor()
    }

    static func live() -> AppDependencies {
        AppDependencies(modelContainer: PersistenceContainer.makeShared())
    }
}
