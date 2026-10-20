import Foundation

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    /// Округление до `scale` знаков после запятой.
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    /// Строка без группировки разрядов, с точкой: подходит для поля ввода.
    var plainString: String {
        NSDecimalNumber(decimal: self).stringValue
    }

    /// Разбирает ввод пользователя: принимает и точку, и запятую.
    init?(userInput: String) {
        let normalized = userInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        self = value
    }
}
