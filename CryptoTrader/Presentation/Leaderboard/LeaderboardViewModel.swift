import Foundation
import Observation

/// Контракт экрана рейтинга.
@MainActor
protocol LeaderboardViewModelProtocol: AnyObject, Observable {
    var state: LoadState { get }
    var entries: [LeaderboardEntry] { get }
    var currentUser: LeaderboardEntry? { get }

    func load() async
    func observeProfile() async
    func openProfile()
}

@MainActor
@Observable
final class LeaderboardViewModel: LeaderboardViewModelProtocol {
    private(set) var state: LoadState = .idle
    private(set) var entries: [LeaderboardEntry] = []

    /// Самый свежий профиль из потока изменений. Накладывается поверх каждой загрузки:
    /// иначе `load()`, начатый до сохранения имени, вернул бы старое имя.
    @ObservationIgnored private var latestProfile: UserProfile?
    @ObservationIgnored private let leaderboardService: any LeaderboardServiceProtocol
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let router: any AppRouting

    init(
        leaderboardService: any LeaderboardServiceProtocol,
        profileRepository: any ProfileRepositoryProtocol,
        router: any AppRouting
    ) {
        self.leaderboardService = leaderboardService
        self.profileRepository = profileRepository
        self.router = router
    }

    var currentUser: LeaderboardEntry? {
        entries.first(where: \.isCurrentUser)
    }

    /// Вызывается при каждом появлении экрана: после сделок место в рейтинге могло измениться.
    func load() async {
        if entries.isEmpty { state = .loading }
        do {
            entries = try await leaderboardService.leaderboard().entries
            applyLatestProfile()
            state = .loaded
        } catch is CancellationError {
            if entries.isEmpty { state = .idle }
        } catch {
            if entries.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    /// Имя и аватар обновляются в рейтинге сразу после изменения профиля.
    func observeProfile() async {
        for await profile in await profileRepository.updates() {
            latestProfile = profile
            applyLatestProfile()
        }
    }

    func openProfile() {
        router.push(.profile)
    }

    private func applyLatestProfile() {
        guard let profile = latestProfile,
              let index = entries.firstIndex(where: \.isCurrentUser)
        else { return }
        entries[index].name = profile.name
        entries[index].avatar = Avatar(profile: profile)
    }
}
