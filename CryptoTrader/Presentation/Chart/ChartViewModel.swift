import Foundation
import Observation

/// Контракт экрана графика.
@MainActor
protocol ChartViewModelProtocol: AnyObject, Observable, LeaderboardNavigable {
    var title: String { get }
    var intervals: [ChartInterval] { get }
    var selectedInterval: ChartInterval { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    /// Меняется при «Повторить», чтобы WebView перезагрузил тот же URL.
    var reloadToken: Int { get }

    func chartURL(isDarkMode: Bool) -> URL
    func loadingStarted()
    func loadingFinished()
    func loadingFailed(_ error: any Error)
    func retry()
}

@MainActor
@Observable
final class ChartViewModel: ChartViewModelProtocol {
    let intervals = ChartInterval.allCases
    var selectedInterval: ChartInterval = .oneHour
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var reloadToken = 0

    @ObservationIgnored private let coin: Coin
    @ObservationIgnored private let urlProvider: any ChartURLProviding
    @ObservationIgnored private let router: any AppRouting

    init(coin: Coin, urlProvider: any ChartURLProviding, router: any AppRouting) {
        self.coin = coin
        self.urlProvider = urlProvider
        self.router = router
    }

    var title: String { "\(coin.pairTitle) · график" }

    func chartURL(isDarkMode: Bool) -> URL {
        urlProvider.chartURL(symbol: coin.symbol, interval: selectedInterval, isDarkMode: isDarkMode)
    }

    func loadingStarted() {
        isLoading = true
        errorMessage = nil
    }

    func loadingFinished() {
        isLoading = false
    }

    func loadingFailed(_ error: any Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    func retry() {
        errorMessage = nil
        reloadToken += 1
    }

    func openLeaderboard() {
        router.showLeaderboard()
    }
}
