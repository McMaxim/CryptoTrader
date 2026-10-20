import Foundation

/// Рыночные данные из публичного API Binance.
///
/// Binance не умеет отдавать список тикеров постранично, поэтому репозиторий
/// один раз загружает снимок рынка (один запрос), сортирует его и отдаёт страницы
/// из кэша. Первая страница перезагружает снимок, если он старше `cacheLifetime`
/// или если просили `forceRefresh` (pull-to-refresh).
///
/// `actor` защищает кэш от одновременного доступа из разных задач.
actor BinanceMarketRepository: MarketRepositoryProtocol {
    /// Пары, которые всегда стоят первыми: Solana по умолчанию, затем Ethereum.
    static let pinnedSymbols = ["SOLUSDT", "ETHUSDT"]

    /// Стейблкоины к USDT не показываем: их курс почти не меняется.
    private static let excludedBaseAssets: Set<String> = [
        "USDC", "FDUSD", "TUSD", "BUSD", "DAI", "USDP", "EUR", "AEUR", "EURI",
        "USDE", "XUSD", "USD1", "BFUSD", "RLUSD", "PYUSD", "UST",
    ]

    private let client: any HTTPClient
    private let cacheLifetime: TimeInterval
    private var universe: [Coin] = []
    private var universeLoadedAt: Date?

    init(client: any HTTPClient, cacheLifetime: TimeInterval = 60) {
        self.client = client
        self.cacheLifetime = cacheLifetime
    }

    func coins(page: Int, pageSize: Int, forceRefresh: Bool) async throws -> Page<Coin> {
        if universe.isEmpty || (page == 0 && (forceRefresh || isCacheExpired)) {
            universe = try await loadUniverse()
            universeLoadedAt = .now
        }

        let start = page * pageSize
        guard start < universe.count else {
            return Page(items: [], index: page, hasMore: false)
        }
        let end = min(start + pageSize, universe.count)
        return Page(items: Array(universe[start..<end]), index: page, hasMore: end < universe.count)
    }

    func coin(symbol: String) async throws -> Coin {
        let dto = try await client.get(BinanceAPI.miniTicker(symbol: symbol), as: BinanceMiniTickerDTO.self)
        guard let coin = BinanceMapper.coin(from: dto) else { throw NetworkError.invalidResponse }
        return coin
    }

    func prices(symbols: [String]) async throws -> [String: Decimal] {
        guard !symbols.isEmpty else { return [:] }
        let dtos = try await client.get(BinanceAPI.prices(symbols: symbols), as: [BinancePriceDTO].self)
        let pairs = dtos.compactMap { dto in BinanceMapper.decimal(dto.price).map { (dto.symbol, $0) } }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    func orderBook(symbol: String, depth: Int) async throws -> OrderBook {
        let dto = try await client.get(BinanceAPI.depth(symbol: symbol, limit: depth), as: BinanceDepthDTO.self)
        return BinanceMapper.orderBook(symbol: symbol, from: dto)
    }

    // MARK: - Private

    private var isCacheExpired: Bool {
        guard let universeLoadedAt else { return true }
        return Date.now.timeIntervalSince(universeLoadedAt) > cacheLifetime
    }

    private func loadUniverse() async throws -> [Coin] {
        let tickers = try await client.get(BinanceAPI.allMiniTickers(), as: [BinanceMiniTickerDTO].self)
        let coins = tickers
            .filter { $0.count > 0 }
            .compactMap(BinanceMapper.coin(from:))
            .filter { !Self.excludedBaseAssets.contains($0.baseAsset) && $0.lastPrice > 0 }

        let pinned = Self.pinnedSymbols.compactMap { symbol in coins.first { $0.symbol == symbol } }
        let rest = coins
            .filter { !Self.pinnedSymbols.contains($0.symbol) }
            .sorted { $0.quoteVolume > $1.quoteVolume }
        return pinned + rest
    }
}
