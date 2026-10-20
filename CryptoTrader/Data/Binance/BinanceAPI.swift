import Foundation

/// Эндпоинты публичного REST API Binance. Для рыночных данных ключ не нужен.
/// Документация: https://developers.binance.com/docs/binance-spot-api-docs/rest-api
enum BinanceAPI {
    /// Есть зеркало только для рыночных данных: https://data-api.binance.vision
    static let baseURL = URL(string: "https://api.binance.com")!

    /// Статистика за 24 часа по всем парам (облегчённый формат MINI, ~1 МБ).
    static func allMiniTickers() -> URL {
        url("/api/v3/ticker/24hr", query: [("type", "MINI")])
    }

    /// Статистика за 24 часа по одной паре.
    static func miniTicker(symbol: String) -> URL {
        url("/api/v3/ticker/24hr", query: [("symbol", symbol), ("type", "MINI")])
    }

    /// Последние цены нескольких пар.
    static func prices(symbols: [String]) -> URL {
        let list = "[" + symbols.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        return url("/api/v3/ticker/price", query: [("symbols", list)])
    }

    /// Стакан пары.
    static func depth(symbol: String, limit: Int) -> URL {
        url("/api/v3/depth", query: [("symbol", symbol), ("limit", String(limit))])
    }

    private static func url(_ path: String, query: [(String, String)]) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        // Кодируем значения сами: в `symbols` есть кавычки и скобки.
        components.percentEncodedQueryItems = query.map { name, value in
            URLQueryItem(name: name, value: value.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        }
        return components.url!
    }
}

// MARK: - DTO

struct BinanceMiniTickerDTO: Decodable, Sendable {
    let symbol: String
    let openPrice: String
    let highPrice: String
    let lowPrice: String
    let lastPrice: String
    let quoteVolume: String
    /// Число сделок за 24 часа; 0 — пара не торгуется.
    let count: Int
}

struct BinancePriceDTO: Decodable, Sendable {
    let symbol: String
    let price: String
}

/// Уровни стакана приходят как `[["104.08", "275.161"], ...]`.
struct BinanceDepthDTO: Decodable, Sendable {
    let bids: [[String]]
    let asks: [[String]]
}
