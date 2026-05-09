import IhsanCore
import SwiftData

internal actor ModelContainerAccess {
    static let shared = ModelContainerAccess()

    private var cachedContainer: ModelContainer?

    private init() {}

    func container() throws -> ModelContainer {
        if let cachedContainer {
            return cachedContainer
        }

        let newContainer = try IhsanModelContainerFactory.makeContainer(inMemory: false)
        cachedContainer = newContainer
        return newContainer
    }

    func setContainer(_ container: ModelContainer) {
        cachedContainer = container
    }

    func reset() {
        cachedContainer = nil
    }
}
