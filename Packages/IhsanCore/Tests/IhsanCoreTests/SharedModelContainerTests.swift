import IhsanCore
import SwiftData
import XCTest

/// Pins the process-wide container registry the whole commit path
/// depends on: the container the app registers is the instance every
/// consumer gets back — never a second mirrored instance over the
/// same store.
final class SharedModelContainerTests: XCTestCase {

    override func tearDown() {
        IhsanSharedModelContainer.shared.reset()
        super.tearDown()
    }

    func testRegisteredContainerIsReturnedByIdentity() throws {
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        IhsanSharedModelContainer.shared.register(container)

        let resolved = try IhsanSharedModelContainer.shared.container()
        XCTAssertIdentical(resolved, container)
    }

    func testReRegistrationReplacesTheContainer() throws {
        let first = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        let second = try IhsanModelContainerFactory.makeContainer(inMemory: true)

        IhsanSharedModelContainer.shared.register(first)
        IhsanSharedModelContainer.shared.register(second)

        let resolved = try IhsanSharedModelContainer.shared.container()
        XCTAssertIdentical(resolved, second)
    }

    func testRepeatedResolutionIsStable() throws {
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        IhsanSharedModelContainer.shared.register(container)

        let a = try IhsanSharedModelContainer.shared.container()
        let b = try IhsanSharedModelContainer.shared.container()
        XCTAssertIdentical(a, b)
    }
}
