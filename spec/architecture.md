# Architecture

Scratch follows the layered architecture in `~/Notes/Tech Notes/Work Notes/Architecture Design.md` (the "note") strictly. That note is the source of truth for the pattern. These rows pin down how it applies to a single app target, and which parts `scripts/arch-lint.sh` checks mechanically, so a violation fails `scripts/check.sh` instead of waiting for review.

## Layers and folders

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-1` | Every Swift file in the app target lives in exactly one layer folder: `App/`, `Container/`, `Gateways/`, `UseCases/`, `State/`, `Models/`, `Routing/` or `UI/`. | done | `test-arch-lint.sh: file_outside_layers, file_at_root` |
| `ARCH-2` | Actions flow one way, View → ViewModel → UseCase → Gateway, and state flows back up through published properties. No layer calls one above it. | done | `test-arch-lint.sh: gateway_names_*, usecase_names_*, model_names_gateway, routing_names_view, ui_names_gateway, strings_do_not_hide_code`; `manual:` spec-verifier review per change |
| `ARCH-3` | Every Gateway, UseCase and RoutingUseCase boundary is a protocol. Concrete implementations (`Remote…Gateway`, `Keychain…Gateway`, `Default…UseCase` and the like) are referenced by name only in their own folder, in `Container/` and in tests. | done | `test-arch-lint.sh: ui_names_concrete_usecase, usecase_names_concrete_gateway, ui_names_concrete_routing_usecase, has_protocol_exposes_concrete` |
| `ARCH-4` | Files in `Gateways/`, `UseCases/`, `State/`, `Models/` and `Routing/` don't import SwiftUI or UIKit. | done | `test-arch-lint.sh: ui_import_in_usecase, uikit_import_in_gateway, access_level_import, scoped_import, exported_import` |
| `ARCH-5` | A Gateway does I/O and translates the result into domain types from `Models/`. It holds no business rules and knows nothing of UseCases, UI or navigation. | done | `test-arch-lint.sh: gateway_names_usecase, gateway_names_state, gateway_names_router`; `manual:` spec-verifier review per change (no business rules) |
| `ARCH-6` | A UseCase holds the business rules, coordinates Gateways and updates shared state in `State/`. It knows nothing of Views, ViewModels, Routes or the Coordinator. | done | `test-arch-lint.sh: usecase_names_coordinator, usecase_names_ui_type, usecase_names_container` |
| `ARCH-7` | Domain errors that cross layers are types in `Models/`, so a ViewModel never needs a Gateway's or UseCase's own type to read an error. | done | `test-arch-lint.sh: system_error_in_ui, usecase_names_concrete_gateway` |

## ViewModels and Views

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-8` | Each screen has an `…Action` enum, and its View talks to its ViewModel only by submitting actions (`handleAction(_:)`) and reading published state. A ViewModel exposes no other method to its View. | done | `test-arch-lint.sh: view_calls_method, view_trailing_closure_call, view_assigns_state, view_mutates_state, view_binds_directly, view_property_not_named_viewmodel` |
| `ARCH-9` | Each ViewModel declares its dependencies as `typealias UseCases = Has… & Has…` of single-requirement `Has*` protocols, and receives one `useCases` object. | done | `test-arch-lint.sh: viewmodel_without_usecases, viewmodel_extra_dependency, has_protocol_two_requirements` |
| `ARCH-10` | ViewModels and shared state objects are `@MainActor` `ObservableObject`s with `@Published` properties, as in the note. | done | `test-arch-lint.sh: viewmodel_not_observable, struct_viewmodel, nonisolated_viewmodel, state_not_observable, unpublished_state, actor_state, observation_macro` |

## Navigation

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-11` | Moving between screens is decided by a Router: a pure value with a `…Step` enum and `nextStep(from:with:)`, with no side effects. A RoutingUseCase asks the Router for the next step and has the Coordinator navigate there. | done | `AppRouterTests`, `AppRoutingUseCaseTests` |
| `ARCH-12` | Navigation within one screen (a sheet, an alert) is a ViewModel-local `…Route` enum resolved to a destination and handed to the Coordinator. | done | `NavigationRouteTests`; `test-arch-lint.sh: view_navigation_link, view_own_sheet` |
| `ARCH-13` | The Coordinator is created in `App/`, which registers its destination handlers. Nothing outside `App/` and `Container/` knows how navigation is performed. | done | `test-arch-lint.sh: view_navigation_link, view_own_sheet, feature_names_host_type` |

## Composition

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-14` | `AppContainer` conforms to every `Has*` protocol, is built by a static `build(…)` that takes only what the app can't create itself (the URL session, the Coordinator, adapters), and is the only place UseCases, Gateways, Routers and RoutingUseCases are constructed. | done | `AppContainerTests`; `test-arch-lint.sh: router_built_outside_container, attribute_with_arguments, inferred_init, has_protocol_not_in_all` |
| `ARCH-15` | `App/` is the host and the other folders are the feature code. Feature code never references a type declared in `App/`. When it needs something only the host can provide, it declares a Port protocol, and an adapter in `App/` implements it and is passed to `AppContainer.build(…)`. | done | `test-arch-lint.sh: feature_names_host_type` |
| `ARCH-16` | Every Router and UseCase has unit tests. UseCase tests use mock Gateways and never touch the network, the Keychain or `UserDefaults`. Gateway tests use a stubbed URL protocol. | planned | `ScratchTests` |

## Implementation notes

- The note's Ports exist for a feature *package* inside a host app. Scratch has no package (one app target, by decision), so `ARCH-15` keeps the boundary inside the target: `App/` plays the host. Expect few or no Ports at first. Add one when feature code needs something the shell owns, not before.
- `ARCH-10` follows the note's `@Published` style rather than `@Observable`, because the note is the standard here. Main-actor isolation comes from the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. The lint rejects a `nonisolated` ViewModel or state class.
- `Routing/` holds only the pure Routers and their `…Step` enums. The navigation mechanism lives in `UI/`: the `Coordinator` protocol, the note's `NavigationDestination` enum, `NavigationRoute`, the view factory, and the RoutingUseCases. It's there because destinations carry views, and keeping it out of `Routing/` lets `ARCH-4` hold without a type-erased destination and a downcast in the Coordinator.
- A ViewModel with routes conforms to `RoutingViewModel` and names its Coordinator as `useCases.coordinator`. A `Has*` composition is an existential, which doesn't conform to its own protocols, so an extension constrained `where UseCases: HasCoordinator` never applies. The first version tried that, and the note's `navigateTo(.route)` failed to compile.
- `AppContainer.build(coordinator:networkSession:environment:)` follows the note's signature. `AppEnvironment` (in `Models/`) says where the app keeps what it stores (its `UserDefaults` and Keychain service), so tests can use their own.
- Gateway tests stub the network with `StubURLProtocol`. Storage Gateways, which have no protocol to stub, are tested against the real Keychain and `UserDefaults` under a throwaway service and suite.
- The unit tests run inside the app. When the app is hosting tests (`XCTestConfigurationFilePath` is set), it doesn't restore a saved server or route, so the test run never reaches a real server.
- `AppContainer` is a struct, as in the note. The note's `build` uses a `viewFactory` without saying where it comes from. Here `AppViewFactory` is a class that receives the finished container, because the ViewModels it builds need the use cases that the routing use case belongs to. The cycle this makes (factory, container, routing use case, factory) lives as long as the app. `AllUseCases` isn't class-bound, so it can't be held weakly.
- The note leaves `SideEffect` open. Here it has only `.none`, and `submitAction(_:)` runs each action in its own task. Add cases, or serialize actions, when a screen needs them, and give that change its own row.
- `viewModel.binding(_:to:)` is how a control writes: the binding reads published state and submits an action on set, so `ARCH-8` holds.
