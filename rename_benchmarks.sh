#!/usr/bin/env bash
# Rename scrambled smt2 files to their original names and place them in the
# folder structure indicated by the yml's `# original_files:` comment, then
# delete the yml. Pass --apply to actually perform the operations; default is
# dry-run.
#
# This is the single_query variant: yml's `# original_files:` lines start
# with `non-incremental/QF_UF/` (vs `incremental/QF_UF/` in the incremental
# tarball), so we strip that prefix before resolving the destination path.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
fi

log() { printf '%s\n' "$*"; }

planned=0
missing_smt2=0
missing_orig=0
collisions=0

shopt -s nullglob
for yml in "$DIR"/*.yml; do
  # Extract input scrambled filename
  scrambled=$(grep -E "^input_files:" "$yml" | head -n1 | sed -E "s/^input_files:[[:space:]]*'([^']+)'.*/\1/")
  # Extract original_files path
  orig=$(grep -E "^# original_files:" "$yml" | head -n1 | sed -E "s/^# original_files:[[:space:]]*'([^']+)'.*/\1/")

  if [[ -z "$scrambled" || -z "$orig" ]]; then
    log "SKIP (cannot parse): $yml"
    ((missing_orig++)) || true
    continue
  fi

  # Strip leading "non-incremental/QF_UF/" so the path becomes relative to $DIR
  rel="${orig#non-incremental/QF_UF/}"
  dest="$DIR/$rel"
  destdir="$(dirname "$dest")"

  src="$DIR/$scrambled"
  if [[ ! -f "$src" ]]; then
    log "SKIP (missing smt2): $scrambled  (yml=$(basename "$yml"))"
    ((missing_smt2++)) || true
    continue
  fi
  if [[ -e "$dest" ]]; then
    log "SKIP (dest exists): $dest"
    ((collisions++)) || true
    continue
  fi

  log "MV  $scrambled  ->  $rel"
  log "RM  $(basename "$yml")"
  ((planned++)) || true

  if [[ $APPLY -eq 1 ]]; then
    mkdir -p "$destdir"
    mv "$src" "$dest"
    rm "$yml"
  fi
done

log ""
log "----"
log "planned moves : $planned"
log "missing smt2  : $missing_smt2"
log "parse errors  : $missing_orig"
log "collisions    : $collisions"
if [[ $APPLY -eq 0 ]]; then
  log "(dry run — re-run with --apply to perform)"
fi
