#!/usr/bin/env bash
# Verifies this mirror against its upstream source:
#   repo:   https://github.com/ethereum-optimism/optimism
#   path:   rust/op-revm
#   commit: b40d2ce097b928fe1a4ec79a8a1925eb231c675e (tag op-reth/v2.4.0)
#
# Every file must be byte-identical to upstream, except Cargo.toml, whose
# `workspace = true` inheritances are flattened to the monorepo workspace's
# concrete values so the crate builds standalone; its diff is printed for
# manual review instead of failing the check.
#
# Requires: curl, diff. Uses the GitHub contents API (unauthenticated).
set -euo pipefail

UPSTREAM_REPO="ethereum-optimism/optimism"
UPSTREAM_PATH="rust/op-revm"
COMMIT="b40d2ce097b928fe1a4ec79a8a1925eb231c675e"
ROOT="$(cd "$(dirname "$0")" && pwd)"
RAW_BASE="https://raw.githubusercontent.com/${UPSTREAM_REPO}/${COMMIT}/${UPSTREAM_PATH}"
API_BASE="https://api.github.com/repos/${UPSTREAM_REPO}/contents/${UPSTREAM_PATH}"

# Recursively list upstream files via the contents API.
list_upstream() {
    local subpath="$1"
    local url="${API_BASE}${subpath:+/$subpath}?ref=${COMMIT}"
    local entries
    entries=$(curl -sSf "$url")
    echo "$entries" | python3 -c '
import json, sys
for e in json.load(sys.stdin):
    print(e["type"], e["path"])
' | while read -r type path; do
        rel="${path#"${UPSTREAM_PATH}"/}"
        if [ "$type" = "dir" ]; then
            list_upstream "$rel"
        else
            echo "$rel"
        fi
    done
}

echo "Listing upstream files at ${COMMIT:0:12}..."
upstream_files=$(list_upstream "")

status=0

# Local files that upstream does not have (mirror-only files are allowed
# but must be declared here).
allowed_extra="verify.sh PROVENANCE.md .gitignore"
while IFS= read -r local_file; do
    rel="${local_file#"$ROOT"/}"
    case " $allowed_extra " in *" $rel "*) continue ;; esac
    # Skip gitignored files (target/, Cargo.lock): they can't be committed,
    # so they can't pollute the mirror.
    if git -C "$ROOT" check-ignore -q "$rel" 2>/dev/null; then
        continue
    fi
    if ! grep -qxF "$rel" <<<"$upstream_files"; then
        echo "EXTRA (not in upstream): $rel"
        status=1
    fi
done < <(find "$ROOT" -type f -not -path "$ROOT/.git/*")

# Upstream files: present and byte-identical (Cargo.toml reviewed, not failed).
while IFS= read -r rel; do
    local_path="$ROOT/$rel"
    if [ ! -f "$local_path" ]; then
        echo "MISSING: $rel"
        status=1
        continue
    fi
    tmp=$(mktemp)
    curl -sSf "$RAW_BASE/$rel" -o "$tmp"
    if [ "$rel" = "Cargo.toml" ]; then
        echo "--- Cargo.toml diff vs upstream (expected: workspace inheritance flattened) ---"
        diff -u --color=auto "$tmp" "$local_path" || true
        echo "--- end Cargo.toml diff ---"
    elif ! cmp -s "$tmp" "$local_path"; then
        echo "DIFFERS: $rel"
        status=1
    else
        echo "OK: $rel"
    fi
    rm -f "$tmp"
done <<<"$upstream_files"

if [ "$status" -eq 0 ]; then
    echo "VERIFIED: all files byte-identical to upstream (Cargo.toml diff above for review)."
else
    echo "FAILED: mirror diverges from upstream beyond the documented Cargo.toml changes."
fi
exit "$status"
