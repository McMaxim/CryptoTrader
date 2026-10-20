import Foundation
import Testing
@testable import CryptoTrader

/// ViewModel зависят только от протоколов, поэтому в тестах их легко собрать на заглушках.
@MainActor
@Suite("ViewModel")
struct ViewModelTests {
    @Test("Список монет подгружается страницами, пока не кончится")
    func coinListPaginates() async throws {
        let coins = (0..<45).map { Coin.stub("C\($0)") }
        let viewModel = CoinListViewModel(
            marketRepository: StubMarketRepository(coins: coins),
            profileRepository: StubProfileRepository(),
            router: SpyRouter()
        )

        await viewModel.loadInitial()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.coins.count == 20)

        // Строка из начала списка не запускает загрузку.
        await viewModel.loadNextPageIfNeeded(after: viewModel.coins[0])
        #expect(viewModel.coins.count == 20)

        await viewModel.loadNextPageIfNeeded(after: try #require(viewModel.coins.last))
        #expect(viewModel.coins.count == 40)

        await viewModel.loadNextPageIfNeeded(after: try #require(viewModel.coins.last))
        #expect(viewModel.coins.count == 45)
        #expect(viewModel.hasMore == false)
    }

    @Test("Ошибка первой страницы показывается на экране")
    func coinListShowsError() async {
        let viewModel = CoinListViewModel(
            marketRepository: StubMarketRepository(error: NetworkError.http(statusCode: 451)),
            profileRepository: StubProfileRepository(),
            router: SpyRouter()
        )
        await viewModel.loadInitial()
        #expect(viewModel.state == .failed("Биржа недоступна из вашего региона"))
    }

    @Test("Нажатие на монету открывает экран стакана")
    func selectingCoinNavigates() {
        let router = SpyRouter()
        let viewModel = CoinListViewModel(
            marketRepository: StubMarketRepository(),
            profileRepository: StubProfileRepository(),
            router: router
        )
        let coin = Coin.stub("SOL")

        viewModel.select(coin)
        viewModel.openLeaderboard()

        #expect(router.pushed == [.coinDetail(coin)])
        #expect(router.leaderboardShown == 1)
    }

    @Test("Покупка на 50% баланса уходит в торговый сервис")
    func coinDetailBuysHalfOfCash() async throws {
        let portfolio = SpyPortfolioRepository()
        let viewModel = CoinDetailViewModel(
            coin: .stub("SOL", price: "200"),
            liveMarketService: PollingLiveMarketService(repository: StubMarketRepository(), interval: .seconds(1)),
            portfolioRepository: portfolio,
            tradingService: TradingService(portfolioRepository: portfolio),
            router: SpyRouter()
        )
        // Получаем баланс из потока портфеля и останавливаем подписку.
        let observation = Task { await viewModel.observePortfolio() }
        while viewModel.cash == 0 { await Task.yield() }
        observation.cancel()

        viewModel.beginTrade(.buy)
        viewModel.applyFraction(0.5)
        #expect(viewModel.amountText == "5000")
        #expect(viewModel.quote?.quantity == 25)
        #expect(viewModel.quote?.canSubmit == true)

        await viewModel.submitTrade()

        let order = try #require(await portfolio.executedOrders.first)
        #expect(order.quantity == 25)
        #expect(order.price == 200)
        #expect(viewModel.activeTradeSide == nil)
        #expect(viewModel.toastMessage != nil)
    }

    @Test("Загрузка рейтинга не затирает только что сохранённое имя")
    func leaderboardKeepsLatestProfile() async throws {
        let profiles = StubProfileRepository()
        await profiles.save(UserProfile(name: "Новое имя"))
        // Сервис отдаёт рейтинг, собранный ещё со старым именем.
        let staleService = StubLeaderboardService(entries: [
            LeaderboardEntry(id: "me", rank: 1, name: "Старое имя", avatar: .initials("СИ"),
                             pnl: 0, pnlPercent: 0, tradesCount: 0, isCurrentUser: true),
        ])
        let viewModel = LeaderboardViewModel(
            leaderboardService: staleService, profileRepository: profiles, router: SpyRouter()
        )

        // Профиль из потока приходит раньше, чем заканчивается загрузка.
        let observation = Task { await viewModel.observeProfile() }
        for _ in 0..<20 { await Task.yield() }
        await viewModel.load()
        observation.cancel()

        #expect(viewModel.currentUser?.name == "Новое имя")
    }

    @Test("Нельзя продать монету, которой нет")
    func coinDetailBlocksSellWithoutHolding() {
        let portfolio = SpyPortfolioRepository()
        let viewModel = CoinDetailViewModel(
            coin: .stub("SOL"),
            liveMarketService: PollingLiveMarketService(repository: StubMarketRepository(), interval: .seconds(1)),
            portfolioRepository: portfolio,
            tradingService: TradingService(portfolioRepository: portfolio),
            router: SpyRouter()
        )
        viewModel.beginTrade(.sell)
        viewModel.amountText = "10"
        #expect(viewModel.quote?.canSubmit == false)
        #expect(viewModel.quote?.validationMessage == "У вас пока нет SOL")
    }
}
