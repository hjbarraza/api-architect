#!/bin/sh
# inject-manual.sh — inject the api-architect manual pointer as live context.
#
# Wired to two events in hooks/hooks.json — both are events that CAN inject
# context into the model via hookSpecificOutput.additionalContext:
#   SessionStart     — fires once when the session begins; always injects the
#                      manual location + operating loop so the read is on record
#                      before any work starts.
#   UserPromptSubmit — fires before each user turn is processed. Detects
#                      API-shaped prompts and, the first time it sees one in a
#                      session, attaches the same reminder as additionalContext.
#                      It never blocks the prompt.
#
# Why not PreToolUse: PreToolUse hooks cannot inject context — their documented
# output is permissionDecision / updatedInput, not additionalContext. Only
# SessionStart and UserPromptSubmit support additionalContext, so those are the
# events used here for guaranteed context injection.
#
# Contract: reads the hook event JSON from stdin, writes a single hook output
# JSON object to stdout, exits 0. Emits ONLY documented fields:
#   - hookSpecificOutput.{hookEventName, additionalContext}  (inject context)
#   - continue / suppressOutput                              (stay silent)
# Requires only POSIX sh + jq.
#
# To suppress per-turn reminder noise we mark the session once with a flag file
# under TMPDIR; SessionStart always speaks, UserPromptSubmit speaks the first
# time it sees API-shaped work in a session and then stays quiet.

set -eu

# ${CLAUDE_PLUGIN_ROOT} is exported by Claude Code for plugin hooks. Fall back to
# resolving relative to this script so the hook still works if run by hand.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  PLUGIN_ROOT=$(CDPATH= cd -- "$script_dir/.." && pwd)
fi

MANUAL_PATH="$PLUGIN_ROOT/references/api-manual.md"
ADDENDUM_PATH="$PLUGIN_ROOT/references/agent-native-addendum.md"

# jq is required to parse the event and emit valid JSON. If it is missing, stay
# silent and non-blocking rather than corrupting the hook channel.
if ! command -v jq >/dev/null 2>&1; then
  printf '{"continue": true}\n'
  exit 0
fi

input=$(cat 2>/dev/null || printf '')
[ -n "$input" ] || input='{}'

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || printf '')
session_id=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null || printf 'nosession')

# The reminder text. Keep it short and load-bearing: WHERE the manual is, that it
# is the source of truth, and the operating loop the agent must run. The exact
# rules are NOT copied here on purpose — the agent must read them live.
reminder=$(cat <<EOF
api-architect: before API work, read the bundled manual — it is the source of truth. Read it live, do not work from memory.

  Manual:   $MANUAL_PATH
  Addendum: $ADDENDUM_PATH  (agent-native parity / CRUD)

Default Operating Loop (run it, in order):
  1. Clarify the job (consumer, goal, data, auth, compatibility) — apply Clarify-vs-Assume.
  2. Choose the boundary (do not split services without a named reason).
  3. Choose the API style (REST/resource-oriented HTTP by default).
  4. Draft the contract FIRST (paths, methods, bodies, errors, auth, pagination) in OpenAPI/proto.
  5. Implement surgically in the existing repo layering.
  6. Verify with focused tests (negative, auth-failure, retry, idempotency, compatibility).
  7. Prepare release + operation (docs, observability, rollout/rollback, deprecation).

Before merging: run the Pre-Merge Review Checklist and the schema-diff compatibility gate
(scripts/schema-diff.sh) — it must pass with no breaking change. Verify behavior at runtime
(scripts/smoke-verify.sh), not just that gates are green.
EOF
)

# Emit additionalContext for the given event name. Both SessionStart and
# UserPromptSubmit support hookSpecificOutput.additionalContext.
emit_context() {
  jq -n --arg ev "$1" --arg ctx "$reminder" '{
    hookSpecificOutput: {
      hookEventName: $ev,
      additionalContext: $ctx
    }
  }'
}

emit_silent() {
  printf '{"continue": true, "suppressOutput": true}\n'
}

case "$event" in
  SessionStart)
    # Always speak at session start so the manual location is on record day one.
    emit_context "SessionStart"
    exit 0
    ;;
  UserPromptSubmit)
    : # fall through to API-shape detection below
    ;;
  *)
    # Unknown / other event: do nothing, stay non-blocking.
    emit_silent
    exit 0
    ;;
esac

# ---- UserPromptSubmit path: only inject when the prompt looks like API work. ----

prompt=$(printf '%s' "$input" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null || printf '')

# Lowercase for case-insensitive matching.
hay=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')

is_api_work=0
case "$hay" in
  *api*|*openapi*|*swagger*|*oasdiff*|*asyncapi*|*proto*|*grpc*) is_api_work=1 ;;
  *endpoint*|*route*|*handler*|*controller*|*middleware*) is_api_work=1 ;;
  *rest*|*restful*|*idempoten*|*webhook*|*"status code"*) is_api_work=1 ;;
  *curl*|*httpie*|*"schema diff"*|*schema-diff*|*smoke-verify*) is_api_work=1 ;;
esac

if [ "$is_api_work" -eq 0 ]; then
  emit_silent
  exit 0
fi

# Dedupe: inject the UserPromptSubmit reminder at most once per session to avoid
# spamming it on every subsequent turn. SessionStart already injects once; this
# catches sessions where API work starts mid-stream.
flag_dir="${TMPDIR:-/tmp}"
flag_file="$flag_dir/api-architect-manual-$session_id.flag"
if [ -f "$flag_file" ]; then
  emit_silent
  exit 0
fi
: > "$flag_file" 2>/dev/null || true

emit_context "UserPromptSubmit"
exit 0
