# Architecture

Scratch follows the layered architecture in `~/Notes/Tech Notes/Work Notes/Architecture Design.md` (the "note") strictly. That note is the source of truth for the pattern. These rows pin down how it applies to a single app target, and which parts `scripts/arch-lint.sh` checks mechanically, so a violation fails `scripts/check.sh` instead of waiting for review.

## Layers and folders

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-1` | Every Swift file in the app target lives in exactly one layer folder: `App/`, `Container/`, `Gateways/`, `UseCases/`, `State/`, `Models/`, `Routing/` or `UI/`. | planned | `arch-lint: layer_folders` |
| `ARCH-2` | Actions flow one way, View → ViewModel → UseCase → Gateway, and state flows back up through published properties. No layer calls one above it. | planned | `arch-lint: no_upward_refs`; `manual:` spec-verifier review |
| `ARCH-3` | Every Gateway, UseCase and RoutingUseCase boundary is a protocol. Concrete implementations (`Remote…Gateway`, `Keychain…Gateway`, `Default…UseCase` and the like) are referenced by name only in their own folder, in `Container/` and in tests. | planned | `arch-lint: concrete_types_hidden` |
| `ARCH-4` | Files in `Gateways/`, `UseCases/`, `State/`, `Models/` and `Routing/` don't import SwiftUI or UIKit. | planned | `arch-lint: no_ui_imports` |
| `ARCH-5` | A Gateway does I/O and translates the result into domain types from `Models/`. It holds no business rules and knows nothing of UseCases, UI or navigation. | planned | `arch-lint: no_upward_refs`; `manual:` spec-verifier review |
| `ARCH-6` | A UseCase holds the business rules, coordinates Gateways and updates shared state in `State/`. It knows nothing of Views, ViewModels, Routes or the Coordinator. | planned | `arch-lint: no_upward_refs` |
| `ARCH-7` | Domain errors that cross layers are types in `Models/`, so a ViewModel never needs a Gateway's or UseCase's own type to read an error. | planned | `arch-lint: concrete_types_hidden` |

## ViewModels and Views

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-8` | Each screen has an `…Action` enum, and its View talks to its ViewModel only by submitting actions (`handleAction(_:)`) and reading published state. A ViewModel exposes no other method to its View. | planned | `arch-lint: views_submit_actions` |
| `ARCH-9` | Each ViewModel declares its dependencies as `typealias UseCases = Has… & Has…` of single-requirement `Has*` protocols, and receives one `useCases` object. | planned | `arch-lint: viewmodel_usecases` |
| `ARCH-10` | ViewModels and shared state objects are `@MainActor` `ObservableObject`s with `@Published` properties, as in the note. | planned | `arch-lint: observable_style` |

## Navigation

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-11` | Moving between screens is decided by a Router: a pure value with a `…Step` enum and `nextStep(from:with:)`, with no side effects. A RoutingUseCase asks the Router for the next step and has the Coordinator navigate there. | planned | `AppRouterTests` |
| `ARCH-12` | Navigation within one screen (a sheet, an alert) is a ViewModel-local `…Route` enum resolved to a destination and handed to the Coordinator. | planned | `manual:` spec-verifier review |
| `ARCH-13` | The Coordinator is created in `App/`, which registers its destination handlers. Nothing outside `App/` and `Container/` knows how navigation is performed. | planned | `arch-lint: no_upward_refs` |

## Composition

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ARCH-14` | `AppContainer` conforms to every `Has*` protocol, is built by a static `build(…)` that takes only what the app can't create itself (the URL session, the Coordinator, adapters), and is the only place UseCases, Gateways, Routers and RoutingUseCases are constructed. | planned | `arch-lint: constructors_in_container` |
| `ARCH-15` | `App/` is the host and the other folders are the feature code. Feature code never references a type declared in `App/`. When it needs something only the host can provide, it declares a Port protocol, and an adapter in `App/` implements it and is passed to `AppContainer.build(…)`. | planned | `arch-lint: host_types_hidden` |
| `ARCH-16` | Every Router and UseCase has unit tests. UseCase tests use mock Gateways and never touch the network, the Keychain or `UserDefaults`. Gateway tests use a stubbed URL protocol. | planned | `ScratchTests` |

## Implementation notes

- The note's Ports exist for a feature *package* inside a host app. Scratch has no package (one app target, by decision), so `ARCH-15` keeps the boundary inside the target: `App/` plays the host. Expect few or no Ports at first. Add one when feature code needs something the shell owns, not before.
- `ARCH-10` follows the note's `@Published` style rather than `@Observable`, because the note is the standard here.
