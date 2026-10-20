import Foundation

/// Живые обновления цены и стакана для экрана монеты.
protocol LiveMarketServiceProtocol: Sendable {
    /// Бесконечный поток обновлений. Ошибки не обрывают поток: приходят как `.failure`,
    /// и сервис продолжает попытки. Поток останавливается, когда отменяется задача-подписчик.
    func snapshots(for symbol: String, depth: Int) -> AsyncStream<Result<MarketSnapshot, any Error>>
}

/// Опрашивает REST API с заданным интервалом и складывает результаты в `AsyncStream`
/// через его continuation.
struct PollingLiveMarketService: LiveMarketServiceProtocol {
    let repository: any MarketRepositoryProtocol
    let interval: Duration

    func snapshots(for symbol: String, depth: Int) -> AsyncStream<Result<MarketSnapshot, any Error>> {
        // Храним только последнее значение: если UI не успевает, старые снимки не нужны.
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        // Тикер и стакан — независимые запросы, грузим параллельно.
                        async let coin = repository.coin(symbol: symbol)
                        async let book = repository.orderBook(symbol: symbol, depth: depth)
                        let snapshot = try await MarketSnapshot(coin: coin, orderBook: book)
                        continuation.yield(.success(snapshot))
                    } catch is CancellationError {
                        break
                    } catch {
                        continuation.yield(.failure(error))
                    }
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            // Подписчик ушёл (экран закрыт) — останавливаем опрос.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
