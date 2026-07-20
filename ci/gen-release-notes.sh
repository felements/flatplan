#!/usr/bin/env sh
# Generate release notes for the commit range since the previous v* tag via
# the Anthropic API. NEVER fails the pipeline: writes a plain commit-list
# fallback FIRST, then only overwrites it on a fully successful API call.
# Design: docs/superpowers/specs/2026-07-20-release-pipeline-design.md
set +e  # a single command's non-zero must never abort the script

VERSION="${PRODUCT_VERSION:-0.0.0}"
OUT="${RELEASE_NOTES_OUT:-release-notes.md}"
CONTEXT_DOC="${CONTEXT_DOC:-README.md}"
MODEL="${ANTHROPIC_MODEL:-claude-sonnet-5}"
ENABLED="${RELEASE_NOTES_ENABLED:-true}"
CURL_BIN="${CURL_BIN:-curl}"

mkdir -p "$(dirname "$OUT")" 2>/dev/null

# --- commit range: previous v* tag .. HEAD --------------------------------
PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null)"
if [ -n "$PREV_TAG" ]; then RANGE="$PREV_TAG..HEAD"; else RANGE="HEAD"; fi
COMMITS="$(git log --no-merges --format='- %s' "$RANGE" 2>/dev/null)"
[ -z "$COMMITS" ] && COMMITS="- (no changes since previous release)"

# --- fallback FIRST: the artifact always exists ---------------------------
printf '## flatplan v%s\n\n%s\n' "$VERSION" "$COMMITS" > "$OUT"

# --- gates: disabled / no key / no jq -> keep fallback --------------------
if [ "$ENABLED" != "true" ]; then
  echo "release-notes: disabled via RELEASE_NOTES_ENABLED; using fallback."; exit 0
fi
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "release-notes: ANTHROPIC_API_KEY unset; using fallback."; exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "release-notes: jq not found; using fallback."; exit 0
fi

# --- request body (jq -n escapes everything) ------------------------------
CONTEXT_TEXT=""; [ -f "$CONTEXT_DOC" ] && CONTEXT_TEXT="$(cat "$CONTEXT_DOC")"
SYSTEM='You write short release notes for flatplan, a simple personal finance tracker desktop app for Windows and Linux. Audience: end users first (plain language: what changed and why it matters to someone tracking their budget), developers second. Use the supplied product README only for domain vocabulary. Output GitHub-flavored Markdown ONLY, no preamble, in exactly this shape: one lead sentence summarizing the release; then 3-6 bullet points in plain user language; then a final line beginning "**In this build:**" with a terse technical summary for developers. Docs handling: do NOT add bullets for documentation churn — most doc commits are AI-authored specs, plans, and brainstorming notes (e.g. under docs/superpowers/) and are noise to users; only mention documentation when a user-facing document changed substantively. Do not invent anything not present in the commit list. Emit the Markdown directly as raw text; do NOT wrap the whole response in a fenced code block.'

REQ="$(jq -n \
  --arg model "$MODEL" --arg system "$SYSTEM" \
  --arg context "$CONTEXT_TEXT" --arg version "$VERSION" --arg commits "$COMMITS" \
  '{
     model: $model,
     max_tokens: 1024,
     thinking: {type: "disabled"},
     output_config: {effort: "low"},
     system: $system,
     messages: [ { role: "user", content:
       ("Release version: v" + $version
        + "\n\nProduct README (vocabulary only):\n" + $context
        + "\n\nCommits since the previous release:\n" + $commits) } ]
   }')"
if [ -z "$REQ" ]; then
  echo "release-notes: failed to build request JSON; using fallback."; exit 0
fi

# --- call the API; any non-2xx -> fallback --------------------------------
BODY="$(mktemp)"
HTTP="$("$CURL_BIN" -sS -o "$BODY" -w '%{http_code}' --max-time 120 \
  https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$REQ" 2>/dev/null)"
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "release-notes: curl failed (rc=$RC); using fallback."; rm -f "$BODY"; exit 0
fi
case "$HTTP" in
  2*) : ;;
  *)  echo "release-notes: API HTTP $HTTP; using fallback."; head -c 400 "$BODY" 2>/dev/null; echo
      rm -f "$BODY"; exit 0 ;;
esac

STOP="$(jq -r '.stop_reason // empty' "$BODY" 2>/dev/null)"
TEXT="$(jq -r '[.content[]? | select(.type=="text") | .text] | join("\n") // empty' "$BODY" 2>/dev/null)"
rm -f "$BODY"
if [ "$STOP" = "refusal" ] || [ -z "$TEXT" ]; then
  echo "release-notes: no usable text (stop_reason=$STOP); using fallback."; exit 0
fi

# --- success: overwrite the fallback --------------------------------------
printf '%s\n' "$TEXT" > "$OUT"
echo "release-notes: generated via $MODEL."
exit 0
