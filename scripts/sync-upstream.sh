#!/usr/bin/env bash
#
# ----------------------------------------------------------------------- //
#
# MODULE  : sync-upstream.sh
#
# PURPOSE : Merges upstream into my-changes, keeping the merge only if the
#           merge, build, lint, and test suite all succeed cleanly
#
# CREATED : 9/23/2026
#
# ----------------------------------------------------------------------- //

set -euo pipefail

readonly UPSTREAM_REMOTE="upstream"
readonly MIRROR_BRANCH="master"
readonly WORK_BRANCH="my-changes"
readonly BUILD_SCHEME="Stats"
readonly BUILD_DESTINATION="platform=macOS"
readonly BUILD_CONFIGURATION="Debug"

original_branch=""

log() {
    echo "[sync-upstream] $1"
}

# Aborts if the working tree is dirty or a merge/rebase is already in progress.
require_clean_worktree() {
    if [[ -n "$(git status --porcelain)" ]]; then
        log "Working tree is dirty. Commit or stash your changes first."
        exit 1
    fi
    if [[ -d "$(git rev-parse --git-dir)/rebase-merge" || -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]]; then
        log "A merge or rebase is already in progress. Resolve it first."
        exit 1
    fi
}

fetch_upstream() {
    log "Fetching $UPSTREAM_REMOTE..."
    git fetch "$UPSTREAM_REMOTE"
}

# Returns whether upstream/master has commits master doesn't have yet.
has_upstream_changes() {
    local behind_count
    behind_count=$(git rev-list --count "${MIRROR_BRANCH}..${UPSTREAM_REMOTE}/${MIRROR_BRANCH}")
    [[ "$behind_count" -gt 0 ]]
}

fast_forward_mirror_branch() {
    log "Fast-forwarding $MIRROR_BRANCH to $UPSTREAM_REMOTE/$MIRROR_BRANCH..."
    git checkout "$MIRROR_BRANCH"
    git merge --ff-only "$UPSTREAM_REMOTE/$MIRROR_BRANCH"
}

# Merges mirror branch into the work branch without committing; aborts and
# returns failure on conflicts, leaving the work branch untouched.
attempt_merge_into_work_branch() {
    log "Merging $MIRROR_BRANCH into $WORK_BRANCH (uncommitted)..."
    git checkout "$WORK_BRANCH"
    if ! git merge --no-commit --no-ff "$MIRROR_BRANCH"; then
        log "Merge conflicts detected. Aborting safely."
        git merge --abort
        return 1
    fi
    return 0
}

build_project() {
    log "Building $BUILD_SCHEME ($BUILD_CONFIGURATION)..."
    xcodebuild -scheme "$BUILD_SCHEME" -destination "$BUILD_DESTINATION" -configuration "$BUILD_CONFIGURATION" build
}

lint_project() {
    log "Linting with swiftlint..."
    swiftlint
}

run_test_suite() {
    log "Running test suite..."
    xcodebuild test -scheme "$BUILD_SCHEME" -destination "$BUILD_DESTINATION"
}

# Runs a gate function; on failure, rolls back the pending merge and exits.
run_gate() {
    local gate_name="$1"
    local gate_function="$2"
    if ! "$gate_function"; then
        log "$gate_name failed. Rolling back the merge to keep $WORK_BRANCH working."
        git merge --abort
        exit 1
    fi
}

restore_original_branch() {
    if [[ -n "$original_branch" && "$(git branch --show-current)" != "$original_branch" ]]; then
        git checkout "$original_branch"
    fi
}

main() {
    original_branch="$(git branch --show-current)"
    trap restore_original_branch EXIT

    require_clean_worktree
    fetch_upstream

    if ! has_upstream_changes; then
        log "Already up to date with $UPSTREAM_REMOTE/$MIRROR_BRANCH."
        exit 0
    fi

    fast_forward_mirror_branch

    if ! attempt_merge_into_work_branch; then
        log "Left $WORK_BRANCH untouched. Resolve the merge manually with:"
        log "  git checkout $WORK_BRANCH && git merge $MIRROR_BRANCH"
        exit 1
    fi

    run_gate "Build" build_project
    run_gate "Lint" lint_project
    run_gate "Tests" run_test_suite

    git commit --no-edit
    log "Merge committed on $WORK_BRANCH. Review it, then push $MIRROR_BRANCH and $WORK_BRANCH to origin yourself."
}

main "$@"
