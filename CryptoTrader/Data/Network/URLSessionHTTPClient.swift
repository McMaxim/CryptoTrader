import Foundation

/// HTTP-клиент на `URLSession`.
///
/// Callback-API `dataTask(with:completionHandler:)` превращается в `async` через
/// `withCheckedThrowingContinuation`, а отмена Swift-задачи пробрасывается в `URLSessionTask`
/// через `withTaskCancellationHandler`.
final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get<Response: Decodable & Sendable>(_ url: URL, as type: Response.Type) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let box = DataTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
                let task = session.dataTask(with: request) { data, response, error in
                    // continuation возобновляется ровно один раз — в completion handler.
                    continuation.resume(with: Self.result(data: data, response: response, error: error))
                }
                box.start(task)
            }
        } onCancel: {
            box.cancel()
        }
    }

    private static func result(data: Data?, response: URLResponse?, error: (any Error)?) -> Result<Data, any Error> {
        if let error {
            let urlError = error as? URLError
            if urlError?.code == .cancelled {
                return .failure(CancellationError())
            }
            return .failure(NetworkError.transport(urlError?.code ?? .unknown))
        }
        guard let http = response as? HTTPURLResponse, let data else {
            return .failure(NetworkError.invalidResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            return .failure(NetworkError.http(statusCode: http.statusCode))
        }
        return .success(data)
    }
}

/// Хранит `URLSessionDataTask`, чтобы его можно было отменить из `onCancel`.
/// Отмена может прийти раньше, чем задача создана, поэтому состояние защищено замком.
private final class DataTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func start(_ task: URLSessionDataTask) {
        let cancelled = lock.withLock {
            self.task = task
            return isCancelled
        }
        task.resume()
        if cancelled { task.cancel() }
    }

    func cancel() {
        let task = lock.withLock {
            isCancelled = true
            return self.task
        }
        task?.cancel()
    }
}
