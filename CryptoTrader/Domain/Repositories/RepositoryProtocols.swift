import Foundation

// Протоколы слоя данных. Объявлены в домене, реализованы в Data/:
// ViewModel и сервисы зависят от абстракций, а не от Binance или SwiftData.

/// Рыночные данные с биржи.
protocol MarketRepositoryProtocol: Sendable {
    /// Страница списка монет. `forceRefresh` заново загружает снимок рынка.
    func coins(page: Int, pageSize: Int, forceRefresh: Bool) async throws -> Page<Coin>
    /// Свежий тикер одной пары.
    func coin(symbol: String) async throws -> Coin
    /// Текущие цены нескольких пар: `["SOLUSDT": 104.09]`.
    func prices(symbols: [String]) async throws -> [String: Decimal]
    /// Стакан пары, `depth` уровней с каждой стороны.
    func orderBook(symbol: String, depth: Int) async throws -> OrderBook
}

/// Профиль пользователя (локально).
protocol ProfileRepositoryProtocol: Sendable {
    func profile() async throws -> UserProfile
    func save(_ profile: UserProfile) async throws
    /// Поток профиля: сразу отдаёт текущее значение, потом — каждое изменение.
    func updates() async -> AsyncStream<UserProfile>
}

/// Демо-счёт (локально).
protocol PortfolioRepositoryProtocol: Sendable {
    func portfolio() async throws -> Portfolio
    /// Атомарно проверяет баланс и исполняет сделку.
    func execute(_ order: TradeOrder) async throws -> TradeRecord
    /// Возвращает счёт к начальному балансу.
    func reset() async throws
    /// Поток портфеля: сразу отдаёт текущее значение, потом — каждое изменение.
    func updates() async -> AsyncStream<Portfolio>
}

/// Общий рейтинг трейдеров.
protocol LeaderboardRepositoryProtocol: Sendable {
    func traders() async throws -> [Trader]
}

/// Ссылка на график для встроенного WebView.
protocol ChartURLProviding: Sendable {
    func chartURL(symbol: String, interval: ChartInterval, isDarkMode: Bool) -> URL
}

/// Подготовка выбранной фотографии к сохранению как аватара.
protocol AvatarProcessing: Sendable {
    func prepareAvatar(from imageData: Data) async throws -> Data
}
