import Foundation
import SwiftData

// Модели SwiftData. Наружу из слоя данных не выходят: репозитории
// переводят их в доменные структуры (`toDomain()`), которые безопасно передавать между потоками.

@Model
final class ProfileEntity {
    var name: String
    /// Большие бинарные данные SwiftData хранит отдельным файлом.
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date

    init(name: String, avatarData: Data? = nil, createdAt: Date = .now) {
        self.name = name
        self.avatarData = avatarData
        self.createdAt = createdAt
    }

    func toDomain() -> UserProfile {
        UserProfile(name: name, avatarData: avatarData)
    }
}

@Model
final class AccountEntity {
    var cash: Decimal
    var initialBalance: Decimal
    var createdAt: Date

    init(initialBalance: Decimal, createdAt: Date = .now) {
        self.cash = initialBalance
        self.initialBalance = initialBalance
        self.createdAt = createdAt
    }
}

@Model
final class HoldingEntity {
    @Attribute(.unique) var symbol: String
    var baseAsset: String
    var quantity: Decimal
    var averagePrice: Decimal

    init(symbol: String, baseAsset: String, quantity: Decimal, averagePrice: Decimal) {
        self.symbol = symbol
        self.baseAsset = baseAsset
        self.quantity = quantity
        self.averagePrice = averagePrice
    }

    func toDomain() -> Holding {
        Holding(symbol: symbol, baseAsset: baseAsset, quantity: quantity, averagePrice: averagePrice)
    }
}

@Model
final class TradeEntity {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var baseAsset: String
    var sideRawValue: String
    var quantity: Decimal
    var price: Decimal
    var date: Date

    init(id: UUID = UUID(), order: TradeOrder, date: Date = .now) {
        self.id = id
        self.symbol = order.symbol
        self.baseAsset = order.baseAsset
        self.sideRawValue = order.side.rawValue
        self.quantity = order.quantity
        self.price = order.price
        self.date = date
    }

    func toDomain() -> TradeRecord? {
        guard let side = TradeSide(rawValue: sideRawValue) else { return nil }
        return TradeRecord(
            id: id, symbol: symbol, baseAsset: baseAsset, side: side,
            quantity: quantity, price: price, date: date
        )
    }
}

enum PersistenceContainer {
    static var schema: Schema {
        Schema([ProfileEntity.self, AccountEntity.self, HoldingEntity.self, TradeEntity.self])
    }

    static func makeShared() -> ModelContainer {
        // При первом запуске папки ещё нет — без неё CoreData пишет в лог пачку ошибок.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            // Хранилище повреждено — не падаем, работаем в памяти до перезапуска.
            assertionFailure("Не удалось открыть хранилище: \(error)")
            return makeInMemory()
        }
    }

    static func makeInMemory() -> ModelContainer {
        // In-memory контейнер с валидной схемой создаётся всегда.
        try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}
