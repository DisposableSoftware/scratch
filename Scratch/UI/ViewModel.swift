import Combine
import SwiftUI

/// A screen's ViewModel: published state out, `Action`s in (ARCH-8), dependencies through one
/// `useCases` object (ARCH-9).
protocol ViewModel: ObservableObject {
    associatedtype Action
    associatedtype UseCases

    var useCases: UseCases { get }

    func handleAction(_ action: Action) async -> SideEffect
}

/// What handling an action asks of its caller, beyond the state it published.
enum SideEffect: Equatable {
    case none
}

enum LifecycleAction: Equatable {
    case viewDidAppear
}

extension ViewModel {
    /// The View's way in: submit an action and let it run.
    func submitAction(_ action: Action) {
        Task { _ = await handleAction(action) }
    }

    /// A binding for controls like `TextField` that reads published state and writes by submitting
    /// an action, so a View never mutates ViewModel state directly.
    func binding<Value>(
        _ keyPath: KeyPath<Self, Value>,
        to action: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self.submitAction(action($0)) }
        )
    }
}
