import Foundation

/// Перевод DTO Binance в доменные модели. Цены приходят строками и разбираются
/// в `Decimal`, чтобы не терять точность на `Double`.
enum BinanceMapper {
    static let quoteAsset = "USDT"

    /// `nil`, если пара не к USDT или данные битые.
    static func coin(from dto: BinanceMiniTickerDTO) -> Coin? {
        guard dto.symbol.hasSuffix(quoteAsset), dto.symbol.count > quoteAsset.count,
              let last = decimal(dto.lastPrice),
              let open = decimal(dto.openPrice),
              let high = decimal(dto.highPrice),
              let low = decimal(dto.lowPrice),
              let volume = decimal(dto.quoteVolume)
        else { return nil }

        let base = String(dto.symbol.dropLast(quoteAsset.count))
        return Coin(
            symbol: dto.symbol,
            baseAsset: base,
            quoteAsset: quoteAsset,
            name: CoinNameCatalog.name(for: base),
            lastPrice: last,
            openPrice: open,
            highPrice: high,
            lowPrice: low,
            quoteVolume: volume
        )
    }

    static func orderBook(symbol: String, from dto: BinanceDepthDTO) -> OrderBook {
        OrderBook(symbol: symbol, bids: levels(dto.bids), asks: levels(dto.asks))
    }

    private static func levels(_ raw: [[String]]) -> [OrderBookLevel] {
        raw.compactMap { pair in
            guard pair.count >= 2,
                  let price = decimal(pair[0]),
                  let quantity = decimal(pair[1]),
                  quantity > 0
            else { return nil }
            return OrderBookLevel(price: price, quantity: quantity)
        }
    }

    static func decimal(_ string: String) -> Decimal? {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// Binance не отдаёт полные названия монет, поэтому для популярных держим словарь.
enum CoinNameCatalog {
    private static let names: [String: String] = [
        "BTC": "Bitcoin", "ETH": "Ethereum", "SOL": "Solana", "BNB": "BNB", "XRP": "XRP",
        "DOGE": "Dogecoin", "ADA": "Cardano", "TRX": "TRON", "TON": "Toncoin", "AVAX": "Avalanche",
        "LINK": "Chainlink", "DOT": "Polkadot", "POL": "Polygon", "SHIB": "Shiba Inu",
        "LTC": "Litecoin", "BCH": "Bitcoin Cash", "UNI": "Uniswap", "NEAR": "NEAR Protocol",
        "APT": "Aptos", "SUI": "Sui", "PEPE": "Pepe", "ARB": "Arbitrum", "OP": "Optimism",
        "ATOM": "Cosmos", "XLM": "Stellar", "ETC": "Ethereum Classic", "FIL": "Filecoin",
        "ICP": "Internet Computer", "HBAR": "Hedera", "WIF": "dogwifhat", "FET": "Artificial Superintelligence",
        "RENDER": "Render", "INJ": "Injective", "SEI": "Sei", "TIA": "Celestia", "AAVE": "Aave",
        "TRUMP": "Official Trump", "ENA": "Ethena", "WLD": "Worldcoin", "BONK": "Bonk",
        "FLOKI": "Floki", "ONDO": "Ondo", "JUP": "Jupiter", "TAO": "Bittensor", "PENGU": "Pudgy Penguins",
        "ALGO": "Algorand", "VET": "VeChain", "XTZ": "Tezos", "SAND": "The Sandbox", "MANA": "Decentraland",
        "GALA": "Gala", "CRV": "Curve DAO", "LDO": "Lido DAO", "MKR": "Maker", "RUNE": "THORChain",
        "STX": "Stacks", "IMX": "Immutable", "GRT": "The Graph", "EGLD": "MultiversX",
        "PAXG": "PAX Gold", "ZEC": "Zcash", "XMR": "Monero", "KAS": "Kaspa", "HYPE": "Hyperliquid",
    ]

    static func name(for baseAsset: String) -> String {
        names[baseAsset] ?? baseAsset
    }
}
