import SwiftUI

/// Собирает экраны: создаёт ViewModel с нужными зависимостями и отдаёт View.
/// Сами View получают ViewModel через generic-параметр и знают только её протокол.
@MainActor
struct ScreenFactory {
    let dependencies: AppDependencies

    func makeCoinList() -> some View {
        CoinListView(viewModel: CoinListViewModel(
            marketRepository: dependencies.marketRepository,
            profileRepository: dependencies.profileRepository,
            router: dependencies.router
        ))
    }

    @ViewBuilder
    func makeScreen(for route: Route) -> some View {
        switch route {
        case .coinDetail(let coin):
            CoinDetailView(viewModel: CoinDetailViewModel(
                coin: coin,
                liveMarketService: dependencies.liveMarketService,
                portfolioRepository: dependencies.portfolioRepository,
                tradingService: dependencies.tradingService,
                router: dependencies.router
            ))
        case .chart(let coin):
            ChartView(viewModel: ChartViewModel(
                coin: coin,
                urlProvider: dependencies.chartURLProvider,
                router: dependencies.router
            ))
        case .leaderboard:
            LeaderboardView(viewModel: LeaderboardViewModel(
                leaderboardService: dependencies.leaderboardService,
                profileRepository: dependencies.profileRepository,
                router: dependencies.router
            ))
        case .profile:
            ProfileView(viewModel: ProfileViewModel(
                profileRepository: dependencies.profileRepository,
                portfolioRepository: dependencies.portfolioRepository,
                valuationService: dependencies.valuationService,
                avatarProcessor: dependencies.avatarProcessor,
                router: dependencies.router
            ))
        }
    }
}
