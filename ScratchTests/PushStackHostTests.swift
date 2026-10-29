import SwiftUI
import Testing
@testable import Scratch

private final class StackPortSpy: NavigationStackPort {
    private(set) var roots = 0

    func stack(root: AnyView) -> AnyView {
        roots += 1
        return root
    }
}

struct PushStackHostTests {
    private func push(_ key: String) -> NavigationDestination { .push(key: key, AnyView(Text(key))) }

    @Test func aPushIsAddedToThePath() {
        let host = PushStackHost()

        #expect(host.handle(push("album:a1")))
        #expect(host.handle(push("album:a2")))
        #expect(host.path.map(\.key) == ["album:a1", "album:a2"])
    }

    @Test func theSameScreenIsNotPushedOnTopOfItself() {
        let host = PushStackHost()

        #expect(host.handle(push("album:a1")))
        #expect(host.handle(push("album:a1")))
        #expect(host.path.count == 1)
    }

    @Test func theSameScreenCanBePushedAgainOnceSomethingElseIsOnTop() {
        let host = PushStackHost()
        _ = host.handle(push("album:a1"))
        _ = host.handle(push("album:a2"))
        _ = host.handle(push("album:a1"))

        #expect(host.path.map(\.key) == ["album:a1", "album:a2", "album:a1"])
    }

    @Test func otherDestinationsAreLeftToOtherHandlers() {
        let host = PushStackHost()

        #expect(!host.handle(.dismissSheet))
        #expect(!host.handle(.alert(AlertContent(title: "", message: ""))))
        #expect(!host.handle(.root(AnyView(Text("")))))
        #expect(host.path.isEmpty)
    }

    @Test func aNewStackStartsEmpty() {
        let host = PushStackHost()
        _ = host.handle(push("album:a1"))

        _ = host.stack(root: AnyView(Text("root")))

        #expect(host.path.isEmpty)
    }

    @Test func theMainScreenIsBuiltInsideTheHostsStack() {
        let port = StackPortSpy()
        let factory = AppViewFactory()
        factory.useCases = TestContainer.build()
        factory.navigationStack = port

        guard case .root = factory.destination(for: .library, with: AppFlowData()) else {
            Issue.record("expected the main screen as the root")
            return
        }

        #expect(port.roots == 1)
    }
}
