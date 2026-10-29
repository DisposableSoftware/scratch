#!/usr/bin/env bash
# Checks the app's Swift sources against the rules in spec/architecture.md that a script can see.
# Prints file:line: [rule] message for each violation, and exits 1 if there are any.
# String literals and comments are blanked before matching, so neither trips nor hides a rule.
# Usage: scripts/arch-lint.sh [SOURCE_DIR]   (defaults to Scratch)
set -euo pipefail
cd "$(dirname "$0")/.."

src=${1:-Scratch}
src=${src%/}
LAYERS=" App Container Gateways UseCases State Models Routing UI "
# The layers whose types a layer must not name. Container/ and App/ may name anything (App's own
# types are policed separately). UI/ may name the Has* protocols and AllUseCases from Container/.
forbidden_layers() {
  case $1 in
    Models) echo "State Gateways UseCases Routing UI Container App" ;;
    State) echo "Gateways UseCases Routing UI Container App" ;;
    Gateways) echo "State UseCases Routing UI Container App" ;;
    UseCases) echo "Routing UI Container App" ;;
    Routing) echo "Gateways UseCases UI Container App" ;;
    UI) echo "Gateways Container App" ;;
  esac
}
NOT_ID='[^A-Za-z0-9_]'
B="($NOT_ID|\$)"   # end of an identifier
A="(^|$NOT_ID)"    # start of an identifier
found=$(mktemp "${TMPDIR:-/tmp}/arch-lint.XXXXXX")
trap 'rm -f "$found"' EXIT

# "layer<TAB>file<TAB>line<TAB>code" for every line of every Swift file, with string literals
# emptied and comments removed (including multi-line strings and block comments).
index=$(find "$src" -name '*.swift' | sort | while read -r f; do
  rel=${f#"$src"/}
  layer=${rel%%/*}
  [ "$layer" = "$rel" ] && layer=-
  awk -v l="$layer" -v f="$f" '
    { out = ""; i = 1; n = length($0); s = $0
      while (i <= n) {
        c = substr(s, i, 1); two = substr(s, i, 2); three = substr(s, i, 3)
        if (mode == "block") { if (two == "*/") { mode = ""; i += 2 } else i++; continue }
        if (mode == "multi") { if (three == "\"\"\"") { mode = ""; out = out "\"\""; i += 3 } else i++; continue }
        if (mode == "str") {
          if (c == "\\") i += 2
          else if (c == "\"") { mode = ""; out = out "\""; i++ }
          else i++
          continue
        }
        if (two == "//") break
        if (two == "/*") { mode = "block"; i += 2; continue }
        if (three == "\"\"\"") { mode = "multi"; out = out "\"\""; i += 3; continue }
        if (c == "\"") { mode = "str"; out = out "\""; i++; continue }
        out = out c; i++
      }
      if (mode == "str") mode = ""
      print l "\t" f "\t" FNR "\t" out }' "$f"
done)
[ -n "$index" ] || { echo "arch-lint: no Swift files under $src" >&2; exit 1; }

# Lines of the index in the given layers ("A B C"), or outside them with -v.
in_layers() { awk -F'\t' -v want=" $2 " -v neg="$1" '{ hit = index(want, " " $1 " ") > 0 } (neg == "-v") != hit'; }
in_files() { awk -F'\t' -v want=" $1 " 'index(want, " " $2 " ") > 0'; }
# Index lines whose code matches an extended regex, or doesn't.
code_has() { awk -F'\t' -v re="$1" '$4 ~ re'; }
code_lacks() { awk -F'\t' -v re="$1" '$4 !~ re'; }
report() { awk -F'\t' -v r="$1" -v m="$2" '{ print $2 ":" $3 ": [" r "] " m }'; }
# Collects violations in a file: a pipeline's last command runs in a subshell in bash 3.2.
emit() { grep . >>"$found" || true; }
names_re() { echo "$1" | awk 'NF { printf "%s%s", sep, $0; sep = "|" }'; }

# Top-level declarations that aren't private: "layer<TAB>file<TAB>line<TAB>kind<TAB>name".
# Attributes may carry arguments, as in @available(iOS 27, *).
decls=$(echo "$index" | awk -F'\t' '
  { code = $4; gsub(/@[A-Za-z_]+(\([^)]*\))?[ \t]*/, "", code) }
  code ~ /^((public|internal|package|open|final|nonisolated|indirect)[ \t]+)*(class|struct|actor|enum|protocol|typealias)[ \t]+[A-Za-z_]/ {
    n = split(code, w, /[ \t:<{(=]+/)
    for (i = 1; i <= n; i++) if (w[i] ~ /^(class|struct|actor|enum|protocol|typealias)$/) { print $1 "\t" $2 "\t" $3 "\t" w[i] "\t" w[i + 1]; break }
  }')
decl_names() { echo "$decls" | awk -F'\t' -v want=" $1 " -v kinds=" $2 " 'index(want, " " $1 " ") && index(kinds, " " $4 " ") { print $5 }' | sort -u; }
ALL_KINDS="class struct actor enum protocol typealias"

# ARCH-1: every Swift file sits in one layer folder.
echo "$index" | awk -F'\t' -v L="$LAYERS" '!seen[$2]++ && index(L, " " $1 " ") == 0 { print $2 ":" $3 ": [layer_folders] not in one of the layer folders:" L }' | emit

# ARCH-4: no UI frameworks below the UI layer, in any import form.
echo "$index" | in_layers "" "Gateways UseCases State Models Routing" |
  code_has "^[ \t]*(@[A-Za-z_]+[ \t]+)*((public|package|internal|fileprivate|private)[ \t]+)?import[ \t]+((struct|class|enum|protocol|typealias|func|var|let)[ \t]+)?(SwiftUI|UIKit)([ \t.]|\$)" |
  report no_ui_imports "imports a UI framework; only UI/ and App/ may" | emit

# ARCH-2, 5, 6: no layer names a type declared in a layer it must not know about. The name
# suffixes also catch such types before they are declared.
for layer in Models State Gateways UseCases Routing UI; do
  forbidden=$(forbidden_layers "$layer")
  names=$(decl_names "$forbidden" "$ALL_KINDS")
  [ "$layer" != UI ] || names=$(echo "$names" | grep -vE '^(Has[A-Z].*|AllUseCases)$' || true)
  [ -z "$names" ] || echo "$index" | in_layers "" "$layer" | code_has "$A($(names_re "$names"))$B" |
    report no_upward_refs "names a type from a layer $layer/ must not know ($forbidden)" | emit
done
suffix() { echo "$index" | in_layers "" "$1" | code_has "$A[A-Za-z0-9_]*($2)$B" | report no_upward_refs "$3" | emit; }
suffix "Gateways" "UseCase|ViewModel|Coordinator|Route|Router|Step|Destination|View" "a Gateway names a UseCase, the UI or navigation"
suffix "UseCases" "ViewModel|Coordinator|Route|Router|Step|Destination|ViewFactory|View" "a UseCase names the UI or navigation"
suffix "State Models" "UseCase|ViewModel|Coordinator|Gateway|Route|Router|Step|Destination|View" "state and models name no other layer"
suffix "Routing" "ViewModel|Coordinator|Destination|ViewFactory|View|Gateway|UseCase" "a Router names the UI, a Gateway or a UseCase; Routers are pure"
suffix "UI" "Gateway" "the UI names a Gateway; go through a UseCase"

# ARCH-3, 7: concrete Gateway, UseCase and RoutingUseCase types are named only in their own
# folder and Container/, and never in a Has* protocol, which exposes protocols.
# The lines inside Has* protocol bodies.
has_bodies=$(echo "$index" | awk -F'\t' '
  $4 ~ /^[ \t]*protocol[ \t]+Has[A-Z]/ { print; on = ($4 !~ /}/); next }
  on { print; if ($4 ~ /^[ \t]*}/) on = 0 }')
echo "$decls" | awk -F'\t' '$4 != "protocol" && $4 != "typealias" && ($1 == "Gateways" || $1 == "UseCases" || $5 ~ /RoutingUseCase$/)' |
  while IFS=$'\t' read -r layer file _ _ name; do
    # RoutingUseCases sit in UI/ next to the ViewModels, so for them "own folder" is the own file.
    if [ "${name%RoutingUseCase}" != "$name" ]; then
      echo "$index" | in_layers -v "Container" | awk -F'\t' -v f="$file" '$2 != f' | code_has "$A$name$B" |
        report concrete_types_hidden "$name is a concrete RoutingUseCase; use its protocol"
    else
      echo "$index" | in_layers -v "$layer Container" | code_has "$A$name$B" |
        report concrete_types_hidden "$name is a concrete type from $layer/; use its protocol, or move a shared type to Models/"
    fi
    [ -z "$has_bodies" ] || echo "$has_bodies" | code_has "$A$name$B" |
      report concrete_types_hidden "a Has* protocol exposes the concrete $name; expose its protocol"
  done | emit
echo "$index" | in_layers "" "UI State UseCases Routing" | code_has "$A(URLError|DecodingError|EncodingError|CocoaError|NSError|POSIXError)$B" |
  report concrete_types_hidden "a system error crosses into this layer; map it to an error in Models/" | emit

# ARCH-14: UseCases, Gateways, Routers and RoutingUseCases are constructed only in Container/,
# including as an inferred `.init(…)`.
echo "$decls" | awk -F'\t' '$4 != "protocol" && $4 != "typealias" && $5 ~ /(Gateway|UseCase|Router)$/' |
  while IFS=$'\t' read -r _ _ _ _ name; do
    echo "$index" | in_layers -v "Container" | code_has "$A$name([.]init)?[(]|:[ \t]*$name[ \t]*=[ \t]*[.]init[(]" |
      report constructors_in_container "constructs $name outside Container/"
  done | emit
# The Container serves every ViewModel, so every Has* protocol is part of AllUseCases.
all_text=$(echo "$index" | in_layers "" "Container" | awk -F'\t' '
  $4 ~ /typealias[ \t]+AllUseCases/ { on = 1; print $4; prev = $4; next }
  on && ($4 ~ /^[ \t]*&/ || prev ~ /[&=][ \t]*$/) { print $4; prev = $4; next }
  { on = 0 }')
for p in $(decl_names "Container" "protocol" | grep '^Has' || true); do
  echo "$all_text" | grep -qE "$A$p$B" ||
    echo "$decls" | awk -F'\t' -v p="$p" '$5 == p { print $2 ":" $3 ": [constructors_in_container] " p " is missing from AllUseCases" }' | emit
done

# ARCH-9: a Has* protocol has a single requirement.
echo "$index" | in_layers "" "Container" | awk -F'\t' '
  $4 ~ /^[ \t]*protocol[ \t]+Has[A-Za-z0-9_]+/ {
    file = $2; line = $3; name = $4; sub(/^[ \t]*protocol[ \t]+/, "", name); sub(/[^A-Za-z0-9_].*/, "", name); reqs = 0; on = 1
    if ($4 ~ /}/) { rest = $4; sub(/^[^{]*[{]/, "", rest); reqs = gsub(/(var|func|subscript)[ \t]/, "", rest); report() }
    next }
  on && $4 ~ /^[ \t]*(static[ \t]+)?(var|func|subscript)[ \t(]/ { reqs++ }
  on && $4 ~ /^[ \t]*}/ { report() }
  function report() { if (reqs != 1) print file ":" line ": [viewmodel_usecases] " name " has " reqs " requirements; a Has* protocol has exactly one"; on = 0 }' | emit

# ARCH-15: feature code never names a type declared in App/.
app_names=$(decl_names "App" "$ALL_KINDS" | grep -vx 'ScratchApp' || true)
[ -z "$app_names" ] || echo "$index" | in_layers -v "App" | code_has "$A($(names_re "$app_names"))$B" |
  report host_types_hidden "names a type from App/; declare a Port protocol instead" | emit

# ARCH-8: Views submit actions and read state, nothing else.
view_files=$(echo "$index" | in_layers "" "UI" | code_has "^[ \t]*((public|internal|private|fileprivate)[ \t]+)?struct[ \t]+[A-Za-z0-9_]+[ \t]*:[^{]*${A}View$B" | cut -f2 | sort -u | tr '\n' ' ')
if [ -n "${view_files// /}" ]; then
  echo "$index" | in_files "$view_files" | code_has "${A}(let|var)[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*:[ \t]*[A-Za-z0-9_]*ViewModel$B" |
    code_lacks "${A}(let|var)[ \t]+viewModel[ \t]*:" |
    report views_submit_actions "a View's ViewModel property must be called viewModel" | emit
  echo "$index" | in_files "$view_files" | code_has "${A}viewModel[.][A-Za-z_][A-Za-z0-9_]*[ \t]*[({]" |
    code_lacks "${A}viewModel[.](submitAction|binding)[ \t]*[(]" |
    report views_submit_actions "calls a ViewModel method; submit an action instead" | emit
  echo "$index" | in_files "$view_files" | code_has "${A}viewModel[.][A-Za-z_][A-Za-z0-9_.]*[ \t]*([-+*/]?=[^=]|[.](append|remove|insert|toggle|sort)[A-Za-z]*[(])" |
    report views_submit_actions "changes ViewModel state; submit an action instead" | emit
  echo "$index" | in_files "$view_files" | code_has "[\$]viewModel[.]" |
    report views_submit_actions "binds straight to ViewModel state; use viewModel.binding(_:to:)" | emit
fi

# ARCH-12, 13: Views don't navigate on their own; navigation goes through the Coordinator.
echo "$index" | in_layers "" "UI" | code_has "${A}NavigationLink$B|[.](sheet|fullScreenCover|popover|alert|confirmationDialog|navigationDestination|inspector)[ \t]*[(]" |
  report navigation_through_coordinator "navigates from a View; submit an action and use a Route or Router" | emit

# ARCH-9, 10: ViewModels declare a UseCases typealias and take their dependencies through one
# useCases; they and shared state are main-actor ObservableObjects whose visible stored
# properties are @Published.
echo "$decls" | awk -F'\t' '$5 ~ /ViewModel$/ && $4 != "protocol" && $4 != "typealias"' |
  while IFS=$'\t' read -r _ file line kind name; do
    if [ "$kind" != class ]; then
      echo "$file:$line: [observable_style] $name is a $kind; a ViewModel is a class"
      continue
    fi
    grep -qE '^[ \t]*typealias[ \t]+UseCases[ \t]*=[ \t]*Has' "$file" ||
      echo "$file:$line: [viewmodel_usecases] $name has no 'typealias UseCases = Has… & …'"
    grep -qE '^[ \t]*let[ \t]+useCases[ \t]*:[ \t]*UseCases' "$file" ||
      echo "$file:$line: [viewmodel_usecases] $name has no 'let useCases: UseCases'"
    sed -n "${line}p" "$file" | grep -qE ":.*$A(RoutingViewModel|ViewModel)$B" ||
      echo "$file:$line: [observable_style] $name doesn't conform to ViewModel"
    echo "$index" | in_files "$file" | code_has "^[ \t]*init[ \t]*[(]" |
      code_lacks "useCases[ \t]*:[ \t]*UseCases[ \t]*[)]" |
      report viewmodel_usecases "$name's init must end with useCases: UseCases; dependencies come through useCases"
  done | emit
echo "$decls" | awk -F'\t' '$1 == "State" && ($4 == "class" || $4 == "actor")' |
  while IFS=$'\t' read -r _ file line kind name; do
    [ "$kind" = class ] || { echo "$file:$line: [observable_style] shared state $name is an actor; it is a main-actor class"; continue; }
    sed -n "${line}p" "$file" | grep -q 'ObservableObject' ||
      echo "$file:$line: [observable_style] shared state $name isn't an ObservableObject"
  done | emit
observed_files=$( { echo "$decls" | awk -F'\t' '$5 ~ /ViewModel$/ && $4 == "class" { print $2 }'
  echo "$decls" | awk -F'\t' '$1 == "State" && $4 == "class" { print $2 }'; } | sort -u | tr '\n' ' ')
if [ -n "${observed_files// /}" ]; then
  echo "$index" | in_files "$observed_files" |
    code_has "^[ \t]*((internal|public|package|private[(]set[)]|fileprivate[(]set[)])[ \t]+)*var[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*(:[^={]*)?(=[^{]*)?\$" |
    report observable_style "a visible stored property isn't @Published" | emit
  echo "$index" | in_files "$observed_files" | code_has "^[ \t]*(@[A-Za-z_]+[ \t]+)*nonisolated[ \t]+((final|public|internal)[ \t]+)*class$B" |
    report observable_style "a ViewModel or shared state is nonisolated; it is main-actor" | emit
fi
echo "$index" | code_has "(@Observable$B|import[ \t]+Observation$B)" |
  report observable_style "uses Observation; ARCH-10 uses ObservableObject and @Published" | emit

if [ -s "$found" ]; then
  sort -u "$found" >&2
  echo "arch-lint: $(sort -u "$found" | wc -l | tr -d ' ') problem(s)" >&2
  exit 1
fi
