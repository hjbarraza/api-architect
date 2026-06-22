#!/bin/sh
# smoke-verify.sh — hit a live endpoint, capture a CONCRETE runtime observation,
# and validate the response against the OpenAPI schema.
#
# Implements the manual's "Smoke — basic production readiness" test (Testing
# Matrix) and the verification stance: gates passing is necessary, not
# sufficient — prove behavior with a real request/response, not just a green
# build. This script prints status + headers + body (the runtime observation)
# and then, when --spec is given, validates THE CAPTURED RESPONSE BODY against
# the OpenAPI contract — the same bytes shown in the observation, not a second
# request.
#
# ---------------------------------------------------------------------------
# TOOLS THIS SCRIPT EXPECTS:
#
#   curl      — REQUIRED. The request engine. (Pre-installed on macOS/most Linux.)
#   jq        — REQUIRED. Parses/pretty-prints JSON and reads the expected status.
#
#   For OpenAPI response validation (OPTIONAL but recommended):
#     python3            — runs the embedded validator that resolves the response
#                          schema for this method+path+status and checks the
#                          captured body against it.
#     python "jsonschema" package — REQUIRED for the actual schema check.
#         Install: pipx install jsonschema   (or: pip install jsonschema)
#     python "PyYAML" package     — only needed when --spec is YAML (.yaml/.yml).
#         Install: pip install pyyaml         (JSON specs need no extra package)
#   If python3 or the jsonschema package is missing (or a YAML spec is given
#   without PyYAML), the script still performs the smoke check (status + body)
#   and reports that schema validation was SKIPPED — it never claims the
#   captured body was validated when it was not.
# ---------------------------------------------------------------------------
#
# USAGE
#   scripts/smoke-verify.sh --url <URL> [options]
#
# OPTIONS
#   --url URL           Endpoint to hit (required).
#   --method M          HTTP method (default: GET).
#   --expect CODE       Expected HTTP status (default: 200). Mismatch => exit 1.
#   --data DATA         Request body (sets Content-Type: application/json unless -H given).
#   --header "K: V"     Extra header (repeatable).
#   --spec FILE         OpenAPI spec (JSON or YAML) for response-body validation.
#   --no-validate       Skip schema validation even when --spec is given.
#
# EXAMPLES
#   scripts/smoke-verify.sh --url http://localhost:8080/v1/orders --expect 200 --spec openapi.yaml
#   scripts/smoke-verify.sh --url http://localhost:8080/v1/orders --method POST \
#       --data '{"sku":"abc","qty":1}' --expect 201 --header "Authorization: Bearer $TOKEN"
#
# EXIT CODES
#   0  endpoint reachable, status matched, schema valid (or validation skipped)
#   1  status mismatch OR schema validation failed
#   2  usage / environment error (missing curl/jq, missing --url, missing spec)

set -eu

prog=$(basename "$0")

usage() {
  sed -n '2,40p' "$0" >&2 2>/dev/null || true
  printf '\n%s: see header for full usage.\n' "$prog" >&2
  exit 2
}
die() { printf '%s: %s\n' "$prog" "$1" >&2; exit "${2:-2}"; }

command -v curl >/dev/null 2>&1 || die "curl not found (required)." 2
command -v jq   >/dev/null 2>&1 || die "jq not found (required)." 2

URL=""
METHOD="GET"
EXPECT="200"
DATA=""
SPEC=""
VALIDATE=1
# Extra headers are appended to this file (one per line) and replayed onto the
# curl invocation later — keeps multi-word header values safe under POSIX sh.
HEADER_FILE=$(mktemp 2>/dev/null || printf '/tmp/smoke-hdr.%s' "$$")
trap 'rm -f "$HEADER_FILE" "${BODY_FILE:-}" "${HDR_OUT:-}" 2>/dev/null || true' EXIT
have_ct_header=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --url)        URL="${2:-}"; shift 2 ;;
    --method)     METHOD="${2:-}"; shift 2 ;;
    --expect)     EXPECT="${2:-}"; shift 2 ;;
    --data)       DATA="${2:-}"; shift 2 ;;
    --header)     printf '%s\n' "${2:-}" >> "$HEADER_FILE"
                  case "$(printf '%s' "${2:-}" | tr '[:upper:]' '[:lower:]')" in
                    content-type:*) have_ct_header=1 ;;
                  esac
                  shift 2 ;;
    --spec)       SPEC="${2:-}"; shift 2 ;;
    --no-validate) VALIDATE=0; shift ;;
    -h|--help)    usage ;;
    *)            die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$URL" ] || die "--url is required." 2

# Default JSON content-type for bodies if the caller didn't set one.
if [ -n "$DATA" ] && [ "$have_ct_header" -eq 0 ]; then
  printf 'Content-Type: application/json\n' >> "$HEADER_FILE"
fi

BODY_FILE=$(mktemp 2>/dev/null || printf '/tmp/smoke-body.%s' "$$")
HDR_OUT=$(mktemp 2>/dev/null || printf '/tmp/smoke-hout.%s' "$$")

# Build curl invocation. -sS quiet but show errors; -D dumps response headers;
# -o writes the body; -w prints the status + timing for the observation.
set -- curl -sS -X "$METHOD" -D "$HDR_OUT" -o "$BODY_FILE" \
  -w '%{http_code} %{time_total}s' --max-time 30
while IFS= read -r h; do
  [ -n "$h" ] && set -- "$@" -H "$h"
done < "$HEADER_FILE"
[ -n "$DATA" ] && set -- "$@" --data "$DATA"
set -- "$@" "$URL"

printf '%s: %s %s\n' "$prog" "$METHOD" "$URL" >&2

# Run the request; capture status+timing from -w on stdout.
if ! wout=$("$@" 2>/tmp/smoke-curlerr.$$); then
  err=$(cat "/tmp/smoke-curlerr.$$" 2>/dev/null || true); rm -f "/tmp/smoke-curlerr.$$" 2>/dev/null || true
  die "request failed (endpoint unreachable?): ${err:-curl error}" 1
fi
rm -f "/tmp/smoke-curlerr.$$" 2>/dev/null || true

code=$(printf '%s' "$wout" | awk '{print $1}')
elapsed=$(printf '%s' "$wout" | awk '{print $2}')
# Portable case-insensitive Content-Type parse (no gawk IGNORECASE): lowercase
# the header name with tr, then grep the first Content-Type line and strip it.
content_type=$(tr -d '\r' < "$HDR_OUT" \
  | grep -i '^content-type:' \
  | head -n1 \
  | sed 's/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]:[[:space:]]*//' || true)

# ---- Print the CONCRETE runtime observation (the whole point of this script) ----
printf '\n===== RUNTIME OBSERVATION =====\n'
printf 'request : %s %s\n' "$METHOD" "$URL"
printf 'status  : %s (expected %s) in %s\n' "$code" "$EXPECT" "$elapsed"
printf 'type    : %s\n' "${content_type:-<none>}"
printf 'body    :\n'
# Pretty-print JSON if it parses; otherwise show the first 2KB raw.
if jq . "$BODY_FILE" >/dev/null 2>&1; then
  jq . "$BODY_FILE"
else
  head -c 2048 "$BODY_FILE"; printf '\n'
fi
printf '===============================\n\n'

# ---- Assertion 1: status code matches ----
if [ "$code" != "$EXPECT" ]; then
  die "status mismatch: got $code, expected $EXPECT." 1
fi

# ---- Assertion 2: validate THE CAPTURED RESPONSE BODY against the OpenAPI ----
# ---- operation's response schema (the same bytes printed above).         ----
if [ "$VALIDATE" -eq 0 ]; then
  printf '%s: schema validation SKIPPED (--no-validate).\n' "$prog" >&2
  printf '%s: PASS — %s returned %s.\n' "$prog" "$URL" "$code" >&2
  exit 0
fi

if [ -z "$SPEC" ]; then
  printf '%s: schema validation SKIPPED (no --spec given). Pass --spec openapi.yaml to validate the captured body.\n' "$prog" >&2
  printf '%s: PASS (smoke only) — %s returned %s.\n' "$prog" "$URL" "$code" >&2
  exit 0
fi
[ -f "$SPEC" ] || die "spec not found: $SPEC" 2

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s: schema validation SKIPPED — python3 not found (install python3 + jsonschema to validate the captured body).\n' "$prog" >&2
  printf '%s: Smoke check PASSED: %s returned %s. Contract NOT verified.\n' "$prog" "$URL" "$code" >&2
  exit 0
fi

# Request path (no scheme/host, no query) used to locate the OpenAPI operation.
REQ_PATH=$(printf '%s' "$URL" | sed -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*##' -e 's/?.*$//')
[ -n "$REQ_PATH" ] || REQ_PATH="/"

# Embedded validator. Resolves the response schema for this method+path+status
# from the spec (handling $ref, path templating, OpenAPI 3 content schemas and
# Swagger 2 response schemas, and the `default` response) and checks the
# captured body file against it with jsonschema. Exit codes:
#   0 = body conforms   1 = body does NOT conform   3 = cannot validate (skip)
set +e
python3 - "$SPEC" "$METHOD" "$REQ_PATH" "$code" "$BODY_FILE" <<'PYEOF'
import json, re, sys

spec_path, method, req_path, status, body_path = sys.argv[1:6]
method = method.lower()

def skip(msg):
    sys.stderr.write("SKIP: %s\n" % msg); sys.exit(3)
def fail(msg):
    sys.stderr.write("FAIL: %s\n" % msg); sys.exit(1)

# Load the spec (JSON natively; YAML only if PyYAML is present).
with open(spec_path, "rb") as f:
    raw = f.read()
try:
    spec = json.loads(raw)
except Exception:
    try:
        import yaml
    except ImportError:
        skip("spec is not JSON and PyYAML is not installed (pip install pyyaml) — cannot parse YAML spec")
    try:
        spec = yaml.safe_load(raw)
    except Exception as e:
        skip("could not parse spec: %s" % e)
if not isinstance(spec, dict):
    skip("spec root is not an object")

try:
    from jsonschema import Draft7Validator
except ImportError:
    skip("python 'jsonschema' package not installed (pipx install jsonschema) — captured body NOT validated")

def resolve_pointer(ref):
    # Resolve an internal JSON pointer ('#/a/b') against the spec root.
    cur = spec
    for part in ref[2:].split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        if not isinstance(cur, dict) or part not in cur:
            skip("could not resolve $ref %s" % ref)
        cur = cur[part]
    return cur

def deref(node, seen=None):
    # Resolve a chain of top-level $refs (internal '#/...' pointers).
    seen = seen or set()
    while isinstance(node, dict) and "$ref" in node:
        ref = node["$ref"]
        if ref in seen or not ref.startswith("#/"):
            break
        seen.add(ref)
        node = resolve_pointer(ref)
    return node

def inline_refs(node, stack=None):
    # Recursively inline every internal $ref into a self-contained schema so the
    # validator needs no registry/resolver (robust across jsonschema versions).
    # Cycles (a schema that references itself) are left as a permissive {} to
    # avoid infinite recursion — the captured body is finite, so finite checks
    # still apply at the non-recursive levels.
    stack = stack or set()
    if isinstance(node, dict):
        if "$ref" in node and isinstance(node["$ref"], str) and node["$ref"].startswith("#/"):
            ref = node["$ref"]
            if ref in stack:
                return {}
            target = resolve_pointer(ref)
            return inline_refs(target, stack | {ref})
        return {k: inline_refs(v, stack) for k, v in node.items()}
    if isinstance(node, list):
        return [inline_refs(v, stack) for v in node]
    return node
    return node

paths = spec.get("paths") or {}

def path_matches(template, actual):
    # Convert /v1/orders/{id} -> regex; compare segment counts and literals.
    t = [s for s in template.strip("/").split("/") if s != ""]
    a = [s for s in actual.strip("/").split("/") if s != ""]
    if len(t) != len(a):
        return False
    for ts, as_ in zip(t, a):
        if ts.startswith("{") and ts.endswith("}"):
            continue
        if ts != as_:
            return False
    return True

# Locate the path item: prefer an exact key, else a templated match.
item = paths.get(req_path)
if item is None:
    for tmpl, val in paths.items():
        if path_matches(tmpl, req_path):
            item, req_path = val, tmpl
            break
if item is None:
    skip("no path in spec matches %s" % req_path)
item = deref(item)

op = item.get(method)
if op is None:
    skip("no %s operation defined for %s in spec" % (method.upper(), req_path))
op = deref(op)

responses = op.get("responses") or {}
resp = responses.get(status) or responses.get(str(status)) or responses.get("default")
if resp is None:
    skip("no response defined for status %s (or default) on %s %s" % (status, method.upper(), req_path))
resp = deref(resp)

# OpenAPI 3: responses.<code>.content.<media>.schema ; Swagger 2: responses.<code>.schema
schema = None
content = resp.get("content")
if isinstance(content, dict):
    media = content.get("application/json")
    if media is None:
        for k, v in content.items():
            if "json" in k.lower():
                media = v; break
    if isinstance(media, dict):
        schema = media.get("schema")
if schema is None:
    schema = resp.get("schema")  # Swagger 2

if schema is None:
    # A response with no body schema (e.g. 204) — nothing to validate. Exit 4 so
    # the wrapper reports "no schema to check", not a false "body conforms".
    sys.stderr.write("NOSCHEMA: no response body schema declared for %s %s -> %s; nothing to validate.\n"
                     % (method.upper(), req_path, status))
    sys.exit(4)

# Load and parse the captured body.
with open(body_path, "rb") as f:
    body_raw = f.read()
if body_raw.strip() == b"":
    # Empty body. A schema is declared (we'd have exited above otherwise), so an
    # empty body fails the contract unless the schema explicitly permits it.
    fail("response body is empty but a body schema is declared for %s" % status)
try:
    body = json.loads(body_raw)
except Exception as e:
    fail("captured response body is not valid JSON (%s); schema expects JSON" % e)

# Inline internal $refs (#/components/schemas/..., #/definitions/...) so the
# schema is self-contained, then validate the CAPTURED body against it.
schema = inline_refs(schema)
validator = Draft7Validator(schema)
errors = sorted(validator.iter_errors(body), key=lambda e: list(e.path))
if errors:
    for e in errors[:10]:
        loc = "/".join(str(p) for p in e.path) or "<root>"
        sys.stderr.write("  - at %s: %s\n" % (loc, e.message))
    fail("captured response body does NOT conform to the %s %s -> %s schema (%d error(s))"
         % (method.upper(), req_path, status, len(errors)))

sys.stderr.write("OK: captured response body conforms to the %s %s -> %s schema.\n"
                 % (method.upper(), req_path, status))
sys.exit(0)
PYEOF
rc=$?
set -e

case "$rc" in
  0)
    printf '%s: PASS — %s returned %s and the CAPTURED body conforms to %s.\n' "$prog" "$URL" "$code" "$SPEC" >&2
    exit 0
    ;;
  1)
    die "schema validation FAILED — captured response body does not conform to $SPEC." 1
    ;;
  4)
    # The matched response declares no body schema (e.g. 204) — there is nothing
    # to validate. The status already matched, so this is a pass, but say so
    # accurately rather than claiming the body "conforms".
    printf '%s: PASS — %s returned %s; spec declares no response body schema, nothing to validate.\n' "$prog" "$URL" "$code" >&2
    exit 0
    ;;
  *)
    # rc=3 (cannot validate: missing jsonschema/PyYAML, unresolved ref, no op) or
    # any other non-fatal validator issue — degrade honestly, never claim a pass.
    printf '%s: schema validation SKIPPED (see reason above). Captured body NOT validated.\n' "$prog" >&2
    printf '%s: Smoke check PASSED: %s returned %s. Contract NOT verified.\n' "$prog" "$URL" "$code" >&2
    exit 0
    ;;
esac
