import Foundation

/// Форматирование цен и количеств. Числа выводим в «биржевом» виде: $1,234.56.
enum NumberFormatting {
    static let locale = Locale(identifier: "en_US")

    /// Сколько знаков после запятой показывать для цены: у дешёвых монет нужно больше.
    static func priceFractionDigits(for price: Decimal) -> Int {
        let value = price.magnitude
        if value >= 100 { return 2 }
        if value >= 1 { return 4 }
        if value >= Decimal(string: "0.01")! { return 5 }
        return 8
    }

    static func quantityFractionDigits(for quantity: Decimal) -> Int {
        let value = quantity.magnitude
        if value >= 1000 { return 2 }
        if value >= 1 { return 4 }
        return 6
    }
}

extension Decimal {
    func formatted(fractionDigits: Int) -> String {
        formatted(.number.precision(.fractionLength(fractionDigits)).locale(NumberFormatting.locale))
    }

    var formattedPrice: String {
        formatted(fractionDigits: NumberFormatting.priceFractionDigits(for: self))
    }

    var formattedUSD: String {
        (self < 0 ? "−$" : "$") + magnitude.formatted(fractionDigits: 2)
    }

    var formattedSignedUSD: String {
        let sign = self > 0 ? "+" : (self < 0 ? "−" : "")
        return sign + "$" + magnitude.formatted(fractionDigits: 2)
    }

    /// Количество монет: лишние нули в конце отбрасываются.
    var formattedQuantity: String {
        let digits = NumberFormatting.quantityFractionDigits(for: self)
        return formatted(.number.precision(.fractionLength(0...digits)).locale(NumberFormatting.locale))
    }

    /// Короткая запись больших сумм: 185.6M.
    var formattedCompact: String {
        if magnitude < 10_000 { return formatted(fractionDigits: 2) }
        return doubleValue.formatted(
            .number.notation(.compactName).precision(.fractionLength(0...1)).locale(NumberFormatting.locale)
        )
    }
}

extension Double {
    var formattedPercent: String {
        formatted(.number.precision(.fractionLength(2)).locale(NumberFormatting.locale)) + "%"
    }

    var formattedSignedPercent: String {
        // Округляем до сотых заранее, чтобы −0.001% не превращалось в «-0.00%».
        let rounded = (self * 100).rounded() / 100
        guard rounded != 0 else { return 0.0.formattedPercent }
        return (rounded > 0 ? "+" : "") + rounded.formattedPercent
    }
}

enum RussianPlural {
    /// 1 сделка, 2 сделки, 5 сделок.
    static func trades(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "сделка"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = "сделки"
        } else {
            word = "сделок"
        }
        return "\(count) \(word)"
    }
}
