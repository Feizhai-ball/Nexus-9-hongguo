#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="origin"
UPSTREAM="origin/main"
BRANCH="hgtv-custom"
GRADLE="$HOME/软件/gradle-8.14.3/bin/gradle"

cd "$ROOT"

echo "======================================"
echo " HGTV Upstream Sync"
echo "======================================"

# Check branch
CURRENT="$(git branch --show-current)"
if [[ "$CURRENT" != "$BRANCH" ]]; then
    echo "ERROR: Expected branch: $BRANCH"
    echo "Current branch: $CURRENT"
    exit 1
fi

# Require a clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Working tree is not clean."
    echo "Commit or safely back up your local changes first."
    git status --short
    exit 1
fi

# Check build tool
if [[ ! -x "$GRADLE" ]]; then
    echo "ERROR: Gradle not found: $GRADLE"
    exit 1
fi

# Fetch upstream
echo
echo "[1/4] Fetching upstream..."
git fetch --prune "$REMOTE"

if ! git show-ref --verify --quiet "refs/remotes/$UPSTREAM"; then
    echo "ERROR: Upstream branch $UPSTREAM does not exist."
    exit 1
fi

# Rebase custom commits onto upstream
echo
echo "[2/4] Synchronizing custom changes..."

if git merge-base --is-ancestor "$UPSTREAM" HEAD; then
    echo "Already based on the latest upstream."
else
    BACKUP="backup/pre-update-$(date +%Y%m%d-%H%M%S)"
    git branch "$BACKUP" HEAD
    echo "Backup branch created: $BACKUP"

    if ! git rebase "$UPSTREAM"; then
        echo
        echo "CONFLICT: Automatic rebase stopped."
        echo "Your backup branch is: $BACKUP"
        echo
        echo "Resolve conflicts, then run:"
        echo "  git add <resolved-files>"
        echo "  git rebase --continue"
        echo
        echo "To cancel the rebase:"
        echo "  git rebase --abort"
        exit 1
    fi
fi

# Build APK
echo
echo "[3/4] Building APK..."
"$GRADLE" -p "$ROOT/kotlin-tv" :app:assembleDebug

# Locate APK
echo
echo "[4/4] Build result:"
APK="$ROOT/kotlin-tv/app/build/platform/outputs/apk/debug/app-armeabi-v7a-debug.apk"

if [[ -f "$APK" ]]; then
    echo "Nexus 9 APK:"
    echo "$APK"
else
    echo "32-bit APK not found at the expected path."
    echo "Available APK files:"
    find "$ROOT/kotlin-tv/app/build" -type f -name '*.apk' -print
fi

echo
echo "HGTV update completed."
echo "Current commit:"
git log -1 --oneline
