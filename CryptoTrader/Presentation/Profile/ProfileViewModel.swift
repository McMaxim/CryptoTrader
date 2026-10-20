import Foundation
import Observation

/// Контракт экрана профиля.
@MainActor
protocol ProfileViewModelProtocol: AnyObject, Observable, LeaderboardNavigable {
    var name: String { get set }
    var avatar: Avatar { get }
    var hasCustomAvatar: Bool { get }
    var valuation: PortfolioValuation? { get }
    var trades: [TradeRecord] { get }
    var isProcessingAvatar: Bool { get }
    var errorMessage: String? { get set }

    func observeChanges() async
    /// Автосохранение имени во время ввода (вызывается с задержкой после последнего символа).
    func autosaveName() async
    /// Окончательное сохранение: Return, потеря фокуса, уход с экрана.
    func commitName() async
    func setAvatar(imageData: Data) async
    func removeAvatar() async
    func resetAccount() async
}

@MainActor
@Observable
final class ProfileViewModel: ProfileViewModelProtocol {
    var name = ""
    private(set) var avatarData: Data?
    private(set) var valuation: PortfolioValuation?
    private(set) var trades: [TradeRecord] = []
    private(set) var isProcessingAvatar = false
    var errorMessage: String?

    /// Последняя сохранённая версия профиля.
    @ObservationIgnored private var savedProfile = UserProfile(name: "", avatarData: nil)
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let portfolioRepository: any PortfolioRepositoryProtocol
    @ObservationIgnored private let valuationService: any PortfolioValuationServiceProtocol
    @ObservationIgnored private let avatarProcessor: any AvatarProcessing
    @ObservationIgnored private let router: any AppRouting

    init(
        profileRepository: any ProfileRepositoryProtocol,
        portfolioRepository: any PortfolioRepositoryProtocol,
        valuationService: any PortfolioValuationServiceProtocol,
        avatarProcessor: any AvatarProcessing,
        router: any AppRouting
    ) {
        self.profileRepository = profileRepository
        self.portfolioRepository = portfolioRepository
        self.valuationService = valuationService
        self.avatarProcessor = avatarProcessor
        self.router = router
    }

    /// Пока имя редактируется, инициалы на аватаре меняются вместе с ним.
    var avatar: Avatar {
        let displayName = name.trimmingCharacters(in: .whitespaces).isEmpty ? savedProfile.name : name
        return Avatar(profile: UserProfile(name: displayName, avatarData: avatarData))
    }

    var hasCustomAvatar: Bool { avatarData != nil }

    /// Подписка сразу на профиль и на демо-счёт: две дочерние задачи в одной группе.
    func observeChanges() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observeProfile() }
            group.addTask { await self.observePortfolio() }
        }
    }

    func autosaveName() async {
        // Текст в поле не трогаем, чтобы не мешать вводу (например, пробелу в конце).
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != savedProfile.name else { return }
        await save(UserProfile(name: trimmed, avatarData: avatarData))
    }

    func commitName() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = savedProfile.name
            return
        }
        name = trimmed
        await autosaveName()
    }

    func setAvatar(imageData: Data) async {
        isProcessingAvatar = true
        defer { isProcessingAvatar = false }
        do {
            let processed = try await avatarProcessor.prepareAvatar(from: imageData)
            await save(UserProfile(name: savedProfile.name, avatarData: processed))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAvatar() async {
        await save(UserProfile(name: savedProfile.name, avatarData: nil))
    }

    func resetAccount() async {
        do {
            try await portfolioRepository.reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openLeaderboard() {
        router.showLeaderboard()
    }

    // MARK: - Private

    private func observeProfile() async {
        for await profile in await profileRepository.updates() {
            // Не затираем имя, которое пользователь сейчас набирает.
            let hasUnsavedEdits = !name.isEmpty && name != savedProfile.name && name != profile.name
            savedProfile = profile
            if !hasUnsavedEdits { name = profile.name }
            avatarData = profile.avatarData
        }
    }

    private func observePortfolio() async {
        for await portfolio in await portfolioRepository.updates() {
            trades = portfolio.trades
            valuation = await valuationService.valuate(portfolio)
        }
    }

    private func save(_ profile: UserProfile) async {
        do {
            try await profileRepository.save(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
