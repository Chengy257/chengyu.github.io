#!/usr/bin/env bash
set -euo pipefail

# Usage: git-sync [DIR] [MESSAGE]
# If first arg is an existing directory, use it as target; otherwise treat all args as message.
if [[ $# -gt 0 && -d "$1" ]]; then
    TARGET_DIR="$1"
    shift
else
    TARGET_DIR="$(dirname "$(realpath "$0")")"
fi
cd "$TARGET_DIR"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Helpers ─────────────────────────────────────────────
require_clean_worktree() {
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        return 1
    fi
    # Also check untracked files (skip submodules)
    local untracked
    untracked=$(git ls-files --others --exclude-standard)
    [ -z "$untracked" ]
}

get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

get_remote_commit() {
    git rev-parse --verify "origin/$(get_current_branch)" 2>/dev/null || echo ""
}

get_local_commit() {
    git rev-parse HEAD
}

# ── Pre-flight checks ──────────────────────────────────
# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not inside a git repository."
    exit 1
fi

# Fetch remote state (quiet)
info "Fetching remote state..."
git fetch --quiet 2>/dev/null || {
    warn "Could not fetch remote (network issue?). Continuing with local-only sync."
    FETCH_OK=false
}
FETCH_OK=${FETCH_OK:-true}

BRANCH=$(get_current_branch)
LOCAL=$(get_local_commit)
REMOTE=$(get_remote_commit)
BASE=$(git merge-base "$LOCAL" "$REMOTE" 2>/dev/null || echo "$LOCAL")

info "Branch: $BRANCH"
info "Local:  ${LOCAL:0:8}"
info "Remote: ${REMOTE:0:8}"

# ── Detect sync state ──────────────────────────────────
LOCAL_AHEAD=false
REMOTE_AHEAD=false
DIVERGED=false

if [ "$LOCAL" = "$REMOTE" ]; then
    info "Local and remote are in sync."
elif [ "$BASE" = "$REMOTE" ]; then
    LOCAL_AHEAD=true
    info "Local is ahead of remote."
elif [ "$BASE" = "$LOCAL" ]; then
    REMOTE_AHEAD=true
    info "Remote is ahead of local."
else
    DIVERGED=true
    warn "Local and remote have DIVERGED."
fi

# ── Step 1: Pull remote changes (if remote is ahead) ───
if $FETCH_OK && ($REMOTE_AHEAD || $DIVERGED); then
    # Stash local changes if any
    LOCAL_DIRTY=false
    if ! require_clean_worktree; then
        LOCAL_DIRTY=true
        info "Stashing local changes before pull..."
        git stash push --include-untracked -m "git_sync auto-stash $(date '+%Y-%m-%d %H:%M:%S')"
    fi

    info "Pulling remote changes..."
    if git pull --rebase origin "$BRANCH"; then
        ok "Pull successful."
    else
        err "Pull failed (possible conflict). Aborting."
        # Restore stash if we had one
        if $LOCAL_DIRTY; then
            info "Restoring stashed changes..."
            git stash pop
        fi
        exit 1
    fi

    # Restore stashed changes
    if $LOCAL_DIRTY; then
        info "Restoring stashed changes..."
        if git stash pop; then
            ok "Stash restored."
        else
            err "Stash pop failed (conflict). Run 'git stash list' and resolve manually."
            exit 1
        fi
    fi
fi

# ── Step 2: Commit local changes ───────────────────────
git add -A

if git diff --cached --quiet; then
    info "Nothing to commit."
else
    # Build commit message
    MSG="${*:-auto sync $(date '+%Y-%m-%d %H:%M:%S')}"
    git commit -m "$MSG"
    ok "Committed: $MSG"
    LOCAL_AHEAD=true
fi

# ── Step 3: Push ───────────────────────────────────────
if $FETCH_OK && ($LOCAL_AHEAD || ! $REMOTE_AHEAD); then
    # Re-check in case commit changed things
    LOCAL=$(get_local_commit)
    REMOTE=$(get_remote_commit)

    if [ "$LOCAL" != "$REMOTE" ]; then
        info "Pushing to origin/$BRANCH..."
        if git push origin "$BRANCH"; then
            ok "Push successful."
        else
            err "Push failed. Check network or permissions."
            exit 1
        fi
    else
        info "Already up to date with remote."
    fi
elif ! $FETCH_OK; then
    warn "Skipping push (remote unreachable)."
fi

# ── Summary ────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
ok "Sync complete."
echo "  Branch:  $BRANCH"
echo "  Commit:  $(get_local_commit | head -c 8)"
echo "  Status:  $(git status --short | head -5)"
if [ -n "$(git status --short)" ]; then
    TOTAL=$(git status --short | wc -l)
    echo "  (${TOTAL} file(s) with changes above, run 'git status' for full list)"
fi
echo "────────────────────────────────"
