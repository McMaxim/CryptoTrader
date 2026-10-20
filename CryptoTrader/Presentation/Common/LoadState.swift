import Foundation

/// Состояние загрузки экрана.
enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}
