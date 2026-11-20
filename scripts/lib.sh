# Shared by every script in scripts/. Source it; do not execute it.
export LC_ALL=C

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ME="$(basename "$0")"

die() { echo "$ME: $1" >&2; exit "${2:-1}"; }

# Sets CHAOS_DIR (the repo's chaos/ directory) and REPO_ROOT (its parent).
# CHAOS_DIR may be preset; otherwise walk up from $PWD to the first chaos/ with a target.md or config.yaml.
find_chaos_dir() {
  if [[ -z "${CHAOS_DIR:-}" ]]; then
    local d="$PWD"
    while [[ "$d" != / ]]; do
      if [[ -f "$d/chaos/target.md" || -f "$d/chaos/config.yaml" ]]; then CHAOS_DIR="$d/chaos"; break; fi
      d="$(dirname "$d")"
    done
  fi
  [[ -n "${CHAOS_DIR:-}" && -d "$CHAOS_DIR" ]] || die "no chaos/ directory found; run /chaos:profile first"
  CHAOS_DIR="$(cd "$CHAOS_DIR" && pwd)"
  REPO_ROOT="$(dirname "$CHAOS_DIR")"
  export CHAOS_DIR REPO_ROOT
}

# fm_get <file> <key>: value of a flat `key: value` line in the file's YAML frontmatter.
# Strips surrounding quotes and trailing ` # comments`. Prints nothing if absent.
fm_get() {
  [[ -f "$1" ]] || return 0
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^'\''.*'\''$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$1"
}

# config_get <key> <default>: value from chaos/config.yaml (flat `key: value`), or the default.
config_get() {
  local v=""
  if [[ -f "$CHAOS_DIR/config.yaml" ]]; then
    v="$(awk -v key="$1" 'index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
      print v; exit }' "$CHAOS_DIR/config.yaml")"
  fi
  echo "${v:-$2}"
}

# to_seconds <duration>: "90", "90s", "5m", "1h" -> seconds. Returns 1 if unparseable.
to_seconds() {
  [[ "$1" =~ ^([0-9]+)(s|m|h)?$ ]] || return 1
  local n=${BASH_REMATCH[1]}
  case "${BASH_REMATCH[2]}" in
    m) echo $((n * 60)) ;;
    h) echo $((n * 3600)) ;;
    *) echo "$n" ;;
  esac
}

# binding_hash: sha256 over target.md (minus its reviewed_hash line) and every file in chaos/sandbox/.
binding_hash() {
  {
    grep -v '^reviewed_hash:' "$CHAOS_DIR/target.md"
    local f
    for f in $(cd "$CHAOS_DIR" && find sandbox -type f 2>/dev/null | sort); do
      echo "== $f"; cat "$CHAOS_DIR/$f"
    done
  } | sha256sum | cut -c1-16
}

# hypothesis_hash <id>: sha256 over the hypothesis's hypothesis.md, fault, check and, when present, abort.
hypothesis_hash() {
  local d="$CHAOS_DIR/hypotheses/$1" f
  {
    for f in hypothesis.md fault check; do
      echo "== $f"; cat "$d/$f" 2>/dev/null
    done
    if [[ -e "$d/abort" ]]; then echo "== abort"; cat "$d/abort"; fi
  } | sha256sum | cut -c1-16
}

# Review stamps live in chaos/.review as "key: hash" lines: "binding: …" and "hypothesis/<id>: …".
review_get() {
  [[ -f "$CHAOS_DIR/.review" ]] || return 0
  awk -v k="$1:" '$1 == k { print $2; exit }' "$CHAOS_DIR/.review"
}
review_set() {
  local f="$CHAOS_DIR/.review"
  { [[ -f "$f" ]] && awk -v k="$1:" '$1 != k' "$f"; echo "$1: $2"; } | sort > "$f.tmp"
  mv "$f.tmp" "$f"
}

now() { date -u +%FT%TZ; }

# strip_fm <file>: the file without its leading YAML frontmatter.
strip_fm() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; body = 1; next } fm { next } { print }' "$1" \
    | sed '/./,$!d'
}

# provenance_md <run-id>: the generated "## Provenance" section, built from the run's record.json.
provenance_md() {
  local f="$CHAOS_DIR/runs/$1/record.json"
  [[ -f "$f" ]] || die "no record for run $1"
  jq -r '
    def v(x): if x == null then "unknown" else (x | tostring) end;
    "## Provenance",
    "",
    "- Run: \(.run) (\(.mode // "run")), started \(.started_at)",
    "- Commit: \(if .provenance.commit == null then "not a git repository" else .provenance.commit end)\(if .provenance.dirty == true then " with uncommitted changes" else "" end)",
    "- Binding hash: \(v(.provenance.binding_hash)); hypothesis hash: \(v(.provenance.hypothesis_hash))",
    "- Fidelity: \(.provenance.fidelity // "no differences from production declared")",
    "- Baseline before the fault: \(v(.baseline))",
    "- Recovery after revert: \(if .recovered == true then "recovered after \(.recovery_seconds)s"
                                 elif .recovered == false then "NOT recovered after \(.observed_without_recovery_seconds)s"
                                 else "not measured" end)",
    "- Reproduction: \(if .reproduction == "skipped" then "not independently reproduced (target had not recovered)"
                       elif .reproduction == "repeated" then "repeated once from a fresh start"
                       else "not repeated" end)",
    (if .provenance.one_off == true then "- One-off fault: its effect was not asserted" else empty end),
    (if .provenance.source then "- Source: \(.provenance.source)" else empty end),
    (if .provenance.control == true then
       ([.phases[] | select(.phase | test("^check [0-9]+ exit")) | select(has("control"))] | last) as $c
       | if $c then "- Control group: experiment \($c.experiment // "not measured") vs control \($c.control // "not measured"), \(if $c.diff_percent then "\($c.diff_percent)%" else "no" end) difference (tolerance \(.provenance.tolerance_percent)%)"
         else "- Control group: tolerance \(.provenance.tolerance_percent)%, no comparison recorded" end
     else empty end),
    (if .aborted_by then "- Stopped early by the \(.aborted_by): \(.abort_output)" else empty end),
    "",
    "_Generated by the chaos plugin from the run record._"' "$f"
}

# publish_body <file> <out>: what a sink publishes: the file without frontmatter, plus the generated
# Provenance section when the frontmatter names a run.
publish_body() {
  local run
  run="$(fm_get "$1" run)"
  { strip_fm "$1"; if [[ -n "$run" ]]; then echo; provenance_md "$run"; fi; } > "$2"
}
