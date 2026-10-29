import Testing
@testable import Scratch

struct AppContainerTests {
    @Test func buildKeepsTheCoordinatorItWasGiven() {
        let coordinator = CoordinatorSpy()
        let container = TestContainer.build(coordinator: coordinator)
        #expect(container.coordinator === coordinator)
    }
}
