import Foundation
import Observation

/// Контракт экрана списка монет. View знает только его.
@MainActor
protocol CoinListViewModelProtocol: AnyObject, Observable, LeaderboardNavigable {
    var coins: [Coin] { get }
    var state: LoadState { get }
    var isLoadingNextPage: Bool { get }
    var nextPageError: String? { get }
    var hasMore: Bool { get }
    var profile: UserProfile? { get }

    func loadInitial() async
    func refresh() async
    /// Вызывается, когда на экране появляется строка: у конца списка подгружает следующую страницу.
    func loadNextPageIfNeeded(after coin: Coin) async
    func retryNextPage() async
    func observeProfile() async
    func select(_ coin: Coin)
    func openProfile()
}

@MainActor
@Observable
final class CoinListViewModel: CoinListViewModelProtocol {
    static let pageSize = 20
    /// За сколько строк до конца начинать грузить следующую страницу.
    static let prefetchDistance = 5

    private(set) var coins: [Coin] = []
    private(set) var state: LoadState = .idle
    private(set) var isLoadingNextPage = false
    private(set) var nextPageError: String?
    private(set) var hasMore = true
    private(set) var profile: UserProfile?

    @ObservationIgnored private var currentPage = 0
    @ObservationIgnored private let marketRepository: any MarketRepositoryProtocol
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let router: any AppRouting

    init(
        marketRepository: any MarketRepositoryProtocol,
        profileRepository: any ProfileRepositoryProtocol,
        router: any AppRouting
    ) {
        self.marketRepository = marketRepository
        self.profileRepository = profileRepository
        self.router = router
    }

    func loadInitial() async {
        guard state == .idle else { return }
        state = .loading
        await loadFirstPage(forceRefresh: false)
    }

    func refresh() async {
        if coins.isEmpty { state = .loading }
        await loadFirstPage(forceRefresh: true)
    }

    func loadNextPageIfNeeded(after coin: Coin) async {
        guard state == .loaded, hasMore, !isLoadingNextPage, nextPageError == nil,
              let index = coins.firstIndex(where: { $0.id == coin.id }),
              index >= coins.count - Self.prefetchDistance
        else { return }
        await loadNextPage()
    }

    func retryNextPage() async {
        nextPageError = nil
        await loadNextPage()
    }

    func observeProfile() async {
        for await profile in await profileRepository.updates() {
            self.profile = profile
        }
    }

    func select(_ coin: Coin) {
        router.push(.coinDetail(coin))
    }

    func openProfile() {
        router.push(.profile)
    }

    func openLeaderboard() {
        router.showLeaderboard()
    }

    // MARK: - Private

    private func loadFirstPage(forceRefresh: Bool) async {
        do {
            let page = try await marketRepository.coins(page: 0, pageSize: Self.pageSize, forceRefresh: forceRefresh)
            coins = page.items
            currentPage = 0
            hasMore = page.hasMore
            nextPageError = nil
            state = .loaded
        } catch is CancellationError {
            // Экран ушёл до окончания загрузки — при возвращении начнём заново.
            if coins.isEmpty { state = .idle }
        } catch {
            if coins.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    private func loadNextPage() async {
        guard !isLoadingNextPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await marketRepository.coins(
                page: currentPage + 1, pageSize: Self.pageSize, forceRefresh: false
            )
            let known = Set(coins.map(\.id))
            coins += page.items.filter { !known.contains($0.id) }
            currentPage = page.index
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            nextPageError = error.localizedDescription
        }
    }
}
