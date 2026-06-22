#!/bin/sh
# schema-diff.sh — fail the build on a BREAKING API contract change.
#
# Implements the manual's "schema-diff compatibility gate in CI"
# (Release and Evolution section). Compares a base spec against a revised spec
# and EXITS NON-ZERO if the change is breaking, so it can gate a PR.
#
# ---------------------------------------------------------------------------
# TOOLS THIS SCRIPT EXPECTS (install one matching your spec format):
#
#   OpenAPI / Swagger (.yaml / .yml / .json):
#     oasdiff — https://github.com/oasdiff/oasdiff   (RECOMMENDED, default)
#       Install (Go):    go install github.com/oasdiff/oasdiff@latest
#       Install (brew):  brew tap oasdiff/homebrew-oasdiff && brew install oasdiff
#       Install (docker):docker pull oasdiff/oasdiff   (then OASDIFF="docker run --rm -v \"$PWD\":/work -w /work oasdiff/oasdiff")
#       Used as:  oasdiff breaking BASE REVISED   (exits non-zero on breaking)
#
#   Protocol Buffers (.proto):
#     protolock — https://github.com/nilslice/protolock
#       Install (Go):    go install github.com/nilslice/protolock/cmd/protolock@latest
#       Used as:  protolock status   (compares against a committed proto.lock)
#       Run once: protolock init      (to create the proto.lock baseline)
#
# Override the binary used via env: OASDIFF=... or PROTOLOCK=...
# ---------------------------------------------------------------------------
#
# USAGE
#   OpenAPI:  scripts/schema-diff.sh <base-spec> <revised-spec>
#             scripts/schema-diff.sh openapi.base.yaml openapi.yaml
#   Proto:    scripts/schema-diff.sh --proto [proto-root]
#             (uses protolock against the committed proto.lock; default root ".")
#
# In CI the base spec is typically the version on the target branch
# (e.g. `git show origin/main:openapi.yaml > openapi.base.yaml`).
#
# EXIT CODES
#   0  no breaking change (safe to merge)
#   1  breaking change detected (block the merge)
#   2  usage / environment error (missing tool, missing file, bad args)

set -eu

prog=$(basename "$0")

usage() {
  cat >&2 <<EOF
$prog — fail on a breaking API change.

  OpenAPI:  $prog <base-spec> <revised-spec>
  Proto:    $prog --proto [proto-root]

See the header of this script for the tools it expects and how to install them.
Exit: 0 = compatible, 1 = breaking, 2 = usage/environment error.
EOF
  exit 2
}

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit "${2:-2}"; }

[ "$#" -ge 1 ] || usage

# --------------------------------------------------------------------------
# Proto mode
# --------------------------------------------------------------------------
if [ "$1" = "--proto" ]; then
  proto_root="${2:-.}"
  PROTOLOCK="${PROTOLOCK:-protolock}"

  command -v "$PROTOLOCK" >/dev/null 2>&1 || die \
    "protolock not found. Install: go install github.com/nilslice/protolock/cmd/protolock@latest (run 'protolock init' once to create proto.lock)." 2

  [ -d "$proto_root" ] || die "proto root not found: $proto_root" 2

  if [ ! -f "$proto_root/proto.lock" ]; then
    die "no proto.lock in $proto_root — run 'cd $proto_root && $PROTOLOCK init' and commit it as the baseline." 2
  fi

  printf '%s: running protolock status in %s ...\n' "$prog" "$proto_root" >&2
  # `protolock status` exits non-zero when a rule (e.g. no-removed-fields,
  # no-changed-field-types, no-reused-field-numbers) is violated.
  if ( cd "$proto_root" && "$PROTOLOCK" status ); then
    printf '%s: OK — no breaking proto change.\n' "$prog" >&2
    exit 0
  else
    printf '%s: BREAKING proto change detected (see protolock output above).\n' "$prog" >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# OpenAPI mode (default)
# --------------------------------------------------------------------------
[ "$#" -eq 2 ] || usage
base="$1"
revised="$2"

[ -f "$base" ]    || die "base spec not found: $base" 2
[ -f "$revised" ] || die "revised spec not found: $revised" 2

OASDIFF="${OASDIFF:-oasdiff}"

# OASDIFF may be a multi-word command (e.g. a docker invocation); split on spaces.
# shellcheck disable=SC2086
set -- $OASDIFF
oasdiff_bin="$1"
command -v "$oasdiff_bin" >/dev/null 2>&1 || die \
  "oasdiff not found. Install: go install github.com/oasdiff/oasdiff@latest  (or 'brew install oasdiff'). See script header for docker." 2

printf '%s: running oasdiff breaking %s -> %s ...\n' "$prog" "$base" "$revised" >&2

# `oasdiff breaking` prints breaking changes and exits non-zero when any are
# found (with --fail-on ERR). We pass through its output for the PR log.
# shellcheck disable=SC2086
if $OASDIFF breaking --fail-on ERR "$base" "$revised"; then
  printf '%s: OK — no breaking OpenAPI change.\n' "$prog" >&2
  exit 0
else
  status=$?
  # oasdiff exits non-zero ONLY because of the --fail-on threshold here; treat
  # that as the breaking signal. (An env/usage failure would have tripped the
  # command-not-found / file checks above.)
  printf '%s: BREAKING OpenAPI change detected (see oasdiff output above).\n' "$prog" >&2
  exit 1
fi
