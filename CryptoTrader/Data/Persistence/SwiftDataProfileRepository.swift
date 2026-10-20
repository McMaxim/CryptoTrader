import Foundation
import SwiftData

/// Профиль в SwiftData.
///
/// `@ModelActor` даёт актору собственный `ModelContext` и выполняет всю работу
/// с базой на фоновом исполнителе, а не на главном потоке.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepositoryProtocol {
    private var observers: [UUID: AsyncStream<UserProfile>.Continuation] = [:]

    func profile() throws -> UserProfile {
        try fetchOrCreate().toDomain()
    }

    func save(_ profile: UserProfile) throws {
        let entity = try fetchOrCreate()
        entity.name = profile.name
        entity.avatarData = profile.avatarData
        try modelContext.save()
        publish(entity.toDomain())
    }

    func updates() -> AsyncStream<UserProfile> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: UserProfile.self, bufferingPolicy: .bufferingNewest(1)
        )
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        if let current = try? profile() {
            continuation.yield(current)
        }
        return stream
    }

    // MARK: - Private

    private func publish(_ profile: UserProfile) {
        for continuation in observers.values {
            continuation.yield(profile)
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func fetchOrCreate() throws -> ProfileEntity {
        if let existing = try modelContext.fetch(FetchDescriptor<ProfileEntity>()).first {
            return existing
        }
        let entity = ProfileEntity(name: UserProfile.defaultName)
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }
}
