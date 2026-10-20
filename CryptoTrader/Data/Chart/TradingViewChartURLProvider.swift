import Foundation

/// Ссылка на виджет графика TradingView. Данные графика не грузим и не рисуем сами:
/// WebView открывает готовую страницу виджета по URL.
struct TradingViewChartURLProvider: ChartURLProviding {
    private static let widgetURL = URL(string: "https://s.tradingview.com/widgetembed/")!

    func chartURL(symbol: String, interval: ChartInterval, isDarkMode: Bool) -> URL {
        var components = URLComponents(url: Self.widgetURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: "BINANCE:\(symbol)"),
            URLQueryItem(name: "interval", value: interval.rawValue),
            URLQueryItem(name: "theme", value: isDarkMode ? "dark" : "light"),
            URLQueryItem(name: "style", value: "1"),
            URLQueryItem(name: "locale", value: "ru"),
            URLQueryItem(name: "timezone", value: "Etc/UTC"),
            URLQueryItem(name: "hidesidetoolbar", value: "1"),
            URLQueryItem(name: "symboledit", value: "0"),
            URLQueryItem(name: "saveimage", value: "0"),
            URLQueryItem(name: "hideideas", value: "1"),
        ]
        return components.url!
    }
}
