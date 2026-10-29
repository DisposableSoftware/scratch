#!/usr/bin/env bash
# Tests for scripts/arch-lint.sh: a small source tree that follows every rule, and one break of
# each rule on top of it.
# Usage: scripts/test-arch-lint.sh [TEST...]   (runs every test by default)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-arch-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT

die() { echo "$*"; exit 1; }
put() { mkdir -p "$(dirname "$src/$1")" && cat >"$src/$1"; }

# One file per layer, wired the way spec/architecture.md says.
base() {
  src="$work/$T"
  put Models/Track.swift <<'EOF'
struct Track: Equatable { var title: String }
enum LibraryError: Error { case offline }
EOF
  put Gateways/TrackGateway.swift <<'EOF'
import Foundation
protocol TrackGateway { func tracks() async throws -> [Track] }
final class RemoteTrackGateway: TrackGateway {
    func tracks() async throws -> [Track] { [] }
}
EOF
  put State/LibraryState.swift <<'EOF'
import Combine
final class LibraryState: ObservableObject { @Published var tracks: [Track] = [] }
EOF
  put UseCases/LibraryUseCase.swift <<'EOF'
// Knows nothing of the ViewModel or the Coordinator; this comment must not trip the lint.
protocol LibraryUseCase { func load() async throws }
final class DefaultLibraryUseCase: LibraryUseCase {
    private let gateway: TrackGateway
    private let state: LibraryState
    init(gateway: TrackGateway, state: LibraryState) { self.gateway = gateway; self.state = state }
    func load() async throws { state.tracks = try await gateway.tracks() }
}
EOF
  put Routing/AppRouter.swift <<'EOF'
enum AppStep { case setup, library }
struct AppRouter { func nextStep(from step: AppStep) -> AppStep? { step == .setup ? .library : nil } }
EOF
  put UI/AppRoutingUseCase.swift <<'EOF'
protocol Coordinator: AnyObject {}
protocol AppRoutingUseCase { func start() async }
struct DefaultAppRoutingUseCase: AppRoutingUseCase {
    let router: AppRouter
    let coordinator: Coordinator
    func start() async {}
}
EOF
  put Container/AppContainer.swift <<'EOF'
protocol HasLibraryUseCase { var libraryUseCase: LibraryUseCase { get } }
protocol HasCoordinator {
    var coordinator: Coordinator { get }
}
typealias AllUseCases = HasLibraryUseCase
    & HasCoordinator
final class AppContainer: AllUseCases {
    let coordinator: Coordinator
    let libraryUseCase: LibraryUseCase
    init(coordinator: Coordinator) {
        libraryUseCase = DefaultLibraryUseCase(gateway: RemoteTrackGateway(), state: LibraryState())
        self.coordinator = coordinator
        _ = DefaultAppRoutingUseCase(router: AppRouter(), coordinator: coordinator)
    }
}
EOF
  put UI/LibraryViewModel.swift <<'EOF'
import Combine
enum LibraryAction { case load, rename(String) }
final class LibraryViewModel: ViewModel {
    typealias UseCases = HasLibraryUseCase
    let useCases: UseCases
    @Published var name = ""
    init(useCases: UseCases) { self.useCases = useCases }
    func handleAction(_ action: LibraryAction) async -> SideEffect { .none }
}
EOF
  put UI/LibraryView.swift <<'EOF'
import SwiftUI
struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var body: some View {
        // A URL in a string must not hide what follows: "https://example.com", "*/*"
        TextField("Name // not a comment, */* not a block", text: viewModel.binding(\.name, to: { .rename($0) }))
            .onAppear { viewModel.submitAction(.load) }
    }
}
EOF
  put App/ScratchApp.swift <<'EOF'
import SwiftUI
final class Nav: Coordinator {}
@main struct ScratchApp: App { var body: some Scene { WindowGroup { Text("") } } }
EOF
}

passes() { "$root/scripts/arch-lint.sh" "$src" >"$work/$T.out" 2>&1 || die "arch-lint failed:"$'\n'"$(cat "$work/$T.out")"; }
fails_with() {
  if "$root/scripts/arch-lint.sh" "$src" >"$work/$T.out" 2>&1; then die "arch-lint passed; expected [$1]"; fi
  grep -qF "[$1]" "$work/$T.out" || die "arch-lint output lacks [$1]:"$'\n'"$(cat "$work/$T.out")"
  [ -z "${2:-}" ] || grep -qF -- "$2" "$work/$T.out" || die "arch-lint output lacks '$2':"$'\n'"$(cat "$work/$T.out")"
}

clean_tree_passes() { base; passes; }
file_outside_layers() { base; echo 'struct Loose {}' | put Misc/Loose.swift; fails_with layer_folders Misc/Loose.swift; }
file_at_root() { base; echo 'struct Loose {}' | put Loose.swift; fails_with layer_folders Loose.swift; }
ui_import_in_usecase() { base; printf 'import SwiftUI\nstruct Formatter {}\n' | put UseCases/Formatter.swift; fails_with no_ui_imports UseCases/Formatter.swift; }
uikit_import_in_gateway() { base; printf 'import UIKit\n' | put Gateways/Art.swift; fails_with no_ui_imports; }
gateway_names_usecase() { base; echo 'func f(_ u: LibraryUseCase) {}' | put Gateways/Bad.swift; fails_with no_upward_refs Gateways/Bad.swift; }
gateway_names_state() { base; echo 'func f(_ s: LibraryState) {}' | put Gateways/Bad.swift; fails_with no_upward_refs Gateways/Bad.swift; }
usecase_names_coordinator() { base; echo 'func f(_ c: Coordinator) {}' | put UseCases/Bad.swift; fails_with no_upward_refs UseCases/Bad.swift; }
model_names_gateway() { base; echo 'struct Bad { let g: TrackGateway }' | put Models/Bad.swift; fails_with no_upward_refs Models/Bad.swift; }
ui_names_gateway() { base; echo 'struct Bad { let g: TrackGateway }' | put UI/Bad.swift; fails_with no_upward_refs UI/Bad.swift; }
ui_names_concrete_usecase() { base; echo 'struct Bad { let u: DefaultLibraryUseCase }' | put UI/Bad.swift; fails_with concrete_types_hidden "DefaultLibraryUseCase"; }
usecase_names_concrete_gateway() { base; echo 'struct Bad { let g: RemoteTrackGateway }' | put UseCases/Bad.swift; fails_with concrete_types_hidden "RemoteTrackGateway"; }
router_built_outside_container() { base; echo 'func f() { _ = AppRouter() }' | put Routing/Bad.swift; fails_with constructors_in_container "AppRouter"; }
feature_names_host_type() { base; echo 'struct Bad { let n: Nav }' | put UI/Bad.swift; fails_with host_types_hidden UI/Bad.swift; }
view_calls_method() { base; printf 'import SwiftUI\nstruct V: View {\n    let viewModel: LibraryViewModel\n    var body: some View { Button("") { viewModel.reload() } }\n}\n' | put UI/Bad.swift; fails_with views_submit_actions "calls a ViewModel method"; }
view_binds_directly() { base; printf 'import SwiftUI\nstruct V: View {\n    @ObservedObject var viewModel: LibraryViewModel\n    var body: some View { TextField("", text: $viewModel.name) }\n}\n' | put UI/Bad.swift; fails_with views_submit_actions "binds straight"; }
viewmodel_without_usecases() { base; printf 'final class BadViewModel: ViewModel {\n    let deps: Int = 0\n}\n' | put UI/BadViewModel.swift; fails_with viewmodel_usecases BadViewModel; }
viewmodel_not_observable() { base; printf 'final class BadViewModel {\n    typealias UseCases = HasLibraryUseCase\n    let useCases: UseCases\n}\n' | put UI/BadViewModel.swift; fails_with observable_style BadViewModel; }
state_not_observable() { base; echo 'final class PlainState { var x = 0 }' | put State/PlainState.swift; fails_with observable_style PlainState; }
observation_macro() { base; printf 'import Observation\n@Observable final class X {}\n' | put UI/X.swift; fails_with observable_style "uses Observation"; }
private_helper_types_are_fine() { base; printf 'private struct Response {}\nfileprivate enum Keys {}\n' | put Gateways/Helpers.swift; echo 'let r = Response.self' | put UI/Uses.swift; passes; }
strings_do_not_hide_code() { base; printf 'import Foundation\nfunc f(r: inout URLRequest) { r.setValue("*/*", forHTTPHeaderField: "Accept"); _ = "https://a" }\nfunc g(_ v: LibraryViewModel) {}\n' | put Gateways/Strings.swift; fails_with no_upward_refs Gateways/Strings.swift:3; }
strings_do_not_trip_rules() { base; printf 'let label = "LibraryViewModel and Coordinator"\n' | put Models/Label.swift; passes; }
access_level_import() { base; printf 'public import SwiftUI\n' | put Models/A.swift; fails_with no_ui_imports Models/A.swift; }
scoped_import() { base; printf 'import struct SwiftUI.Color\n' | put Models/A.swift; fails_with no_ui_imports Models/A.swift; }
exported_import() { base; printf '@_exported import UIKit\n' | put Gateways/A.swift; fails_with no_ui_imports Gateways/A.swift; }
gateway_names_router() { base; echo 'func f(_ r: AppRouter) {}' | put Gateways/Bad.swift; fails_with no_upward_refs Gateways/Bad.swift; }
usecase_names_ui_type() { base; echo 'func f(_ a: LibraryAction) {}' | put UseCases/Bad.swift; fails_with no_upward_refs UseCases/Bad.swift; }
usecase_names_container() { base; echo 'func f(_ a: AllUseCases) {}' | put UseCases/Bad.swift; fails_with no_upward_refs UseCases/Bad.swift; }
routing_names_view() { base; echo 'func f(_ v: LibraryView) {}' | put Routing/Bad.swift; fails_with no_upward_refs Routing/Bad.swift; }
ui_names_concrete_routing_usecase() { base; echo 'struct Bad { let r: DefaultAppRoutingUseCase }' | put UI/Bad.swift; fails_with concrete_types_hidden DefaultAppRoutingUseCase; }
has_protocol_exposes_concrete() { base; printf 'protocol HasConcrete {\n    var x: DefaultLibraryUseCase { get }\n}\n' | put Container/HasConcrete.swift; fails_with concrete_types_hidden "a Has* protocol exposes"; }
has_protocol_two_requirements() { base; printf 'protocol HasTwo {\n    var a: Int { get }\n    var b: Int { get }\n}\n' | put Container/HasTwo.swift; fails_with viewmodel_usecases "HasTwo has 2 requirements"; }
has_protocol_not_in_all() { base; printf 'protocol HasLost {\n    var a: Int { get }\n}\n' | put Container/HasLost.swift; fails_with constructors_in_container "HasLost is missing from AllUseCases"; }
system_error_in_ui() { base; echo 'func f(_ e: Error) { if e is URLError {} }' | put UI/Bad.swift; fails_with concrete_types_hidden "system error"; }
attribute_with_arguments() { base; printf '@available(iOS 27, *) final class DefaultSneakyUseCase {}\n' | put UseCases/Sneaky.swift; echo 'let s = DefaultSneakyUseCase()' | put UI/Bad.swift; fails_with constructors_in_container DefaultSneakyUseCase; }
inferred_init() { base; echo 'struct S { let r: AppRouter = .init() }' | put UI/Bad.swift; fails_with constructors_in_container AppRouter; }
view_property_not_named_viewmodel() { base; printf 'import SwiftUI\nstruct V: View {\n    let vm: LibraryViewModel\n    var body: some View { Text("") }\n}\n' | put UI/V.swift; fails_with views_submit_actions "must be called viewModel"; }
view_assigns_state() { base; printf 'import SwiftUI\nstruct V: View {\n    let viewModel: LibraryViewModel\n    var body: some View { Button("") { viewModel.name = "" } }\n}\n' | put UI/V.swift; fails_with views_submit_actions "changes ViewModel state"; }
view_mutates_state() { base; printf 'import SwiftUI\nstruct V: View {\n    let viewModel: LibraryViewModel\n    var body: some View { Button("") { viewModel.items.append(1) } }\n}\n' | put UI/V.swift; fails_with views_submit_actions "changes ViewModel state"; }
view_trailing_closure_call() { base; printf 'import SwiftUI\nstruct V: View {\n    let viewModel: LibraryViewModel\n    var body: some View { Button("") { viewModel.reload { } } }\n}\n' | put UI/V.swift; fails_with views_submit_actions "calls a ViewModel method"; }
view_navigation_link() { base; printf 'import SwiftUI\nstruct V: View {\n    var body: some View { NavigationLink("x") { Text("") } }\n}\n' | put UI/V.swift; fails_with navigation_through_coordinator; }
view_own_sheet() { base; printf 'import SwiftUI\nstruct V: View {\n    var body: some View { Text("").sheet(isPresented: .constant(true)) { Text("") } }\n}\n' | put UI/V.swift; fails_with navigation_through_coordinator; }
struct_viewmodel() { base; printf 'struct SettingsViewModel {}\n' | put UI/SettingsViewModel.swift; fails_with observable_style "is a struct"; }
nonisolated_viewmodel() { base; printf 'nonisolated final class OddViewModel: ViewModel {\n    typealias UseCases = HasLibraryUseCase\n    let useCases: UseCases\n    init(useCases: UseCases) { self.useCases = useCases }\n}\n' | put UI/OddViewModel.swift; fails_with observable_style "nonisolated"; }
unpublished_state() { base; printf 'import Combine\nfinal class QueueState: ObservableObject {\n    var items: [Int] = []\n}\n' | put State/QueueState.swift; fails_with observable_style "isn't @Published"; }
private_storage_is_fine() { base; printf 'import Combine\nfinal class QueueState: ObservableObject {\n    @Published private(set) var items: [Int] = []\n    private var cursor = 0\n    var count: Int { items.count }\n}\n' | put State/QueueState.swift; passes; }
actor_state() { base; echo 'actor QueueState {}' | put State/QueueState.swift; fails_with observable_style "is an actor"; }
viewmodel_extra_dependency() { base; printf 'import Combine\nfinal class ExtraViewModel: ViewModel {\n    typealias UseCases = HasLibraryUseCase\n    let useCases: UseCases\n    init(useCases: UseCases, gatewayish: Int) { self.useCases = useCases }\n}\n' | put UI/ExtraViewModel.swift; fails_with viewmodel_usecases "init must end with useCases"; }
viewmodel_screen_value_is_fine() { base; printf 'import Combine\nfinal class DetailViewModel: ViewModel {\n    typealias UseCases = HasLibraryUseCase\n    let useCases: UseCases\n    let track: Track\n    init(track: Track, useCases: UseCases) { self.track = track; self.useCases = useCases }\n    func handleAction(_ action: Int) async -> SideEffect { .none }\n}\n' | put UI/DetailViewModel.swift; passes; }
block_comments_ignored() { base; printf '/* ViewModel\n   Coordinator */\nstruct Fine {}\n' | put UseCases/Fine.swift; passes; }

if [ $# -gt 0 ]; then tests=("$@"); else
  tests=()
  while read -r _ _ f; do
    case $f in base | put | die | passes | fails_with) ;; *) tests+=("$f") ;; esac
  done < <(declare -F)
fi

failed=0
for T in "${tests[@]}"; do
  set +e
  (set -e; "$T") >"$work/$T.log" 2>&1
  rc=$?
  set -e
  if [ $rc = 0 ]; then echo "ok   $T"; else
    echo "FAIL $T"; sed 's/^/     /' "$work/$T.log"; failed=$((failed + 1))
  fi
done
[ "$failed" = 0 ] || { echo "$failed of ${#tests[@]} arch-lint test(s) failed" >&2; exit 1; }
