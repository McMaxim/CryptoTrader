import Foundation

protocol HTTPClient: Sendable {
    func get<Response: Decodable & Sendable>(_ url: URL, as type: Response.Type) async throws -> Response
}

enum NetworkError: LocalizedError, Equatable {
    case invalidResponse
    case transport(URLError.Code)
    case http(statusCode: Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Сервер вернул некорректный ответ"
        case .transport(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "Нет подключения к интернету"
            case .timedOut:
                return "Сервер не отвечает, попробуйте позже"
            default:
                return "Не удалось связаться с сервером"
            }
        case .http(let statusCode):
            switch statusCode {
            case 418, 429: return "Слишком много запросов к бирже, подождите немного"
            case 403, 451: return "Биржа недоступна из вашего региона"
            case 400: return "Пара недоступна для торговли"
            case 500...: return "Биржа временно недоступна"
            default: return "Ошибка сервера (код \(statusCode))"
            }
        case .decoding:
            return "Не удалось разобрать ответ сервера"
        }
    }
}
