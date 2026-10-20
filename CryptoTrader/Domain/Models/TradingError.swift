import Foundation

enum TradingError: LocalizedError, Equatable {
    case invalidAmount
    case amountBelowMinimum(Decimal)
    case priceUnavailable
    case insufficientFunds(available: Decimal)
    case insufficientAsset(asset: String, available: Decimal)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            "Введите сумму больше нуля"
        case .amountBelowMinimum(let minimum):
            "Минимальная сумма сделки — \(minimum.formattedUSD)"
        case .priceUnavailable:
            "Нет актуальной цены, попробуйте через секунду"
        case .insufficientFunds(let available):
            "Недостаточно средств. Доступно \(available.formattedUSD)"
        case .insufficientAsset(let asset, let available):
            "Недостаточно \(asset). Доступно \(available.formattedQuantity)"
        }
    }
}
