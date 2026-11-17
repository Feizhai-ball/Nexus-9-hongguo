#!/usr/bin/env bash
set -Eeuo pipefail

# HGTV Nexus 9 updater
# Run this script from the ROOT of the hongguoTV source repository.
# This file is stored in Feizhai-ball/Nexus-9-hongguo and copied here.

REMOTE="${REMOTE:-origin}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
CUSTOM_BRANCH="${CUSTOM_BRANCH:-hgtv-custom}"
GRADLE="${GRADLE:-$HOME/软件/gradle-8.14.3/bin/gradle}"
APK_REL="kotlin-tv/app/build/platform/outputs/apk/debug/app-armeabi-v7a-debug.apk"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: Run this script inside the hongguoTV Git repository."
    exit 1
}
cd "$ROOT"

UPSTREAM_REF="$REMOTE/$UPSTREAM_BRANCH"

echo "=========================================="
echo " HGTV Nexus 9 Upstream Update + Build"
echo "=========================================="
echo "Repository: $ROOT"
echo "Remote:     $REMOTE"
echo "Upstream:   $UPSTREAM_REF"
echo "Custom:     $CUSTOM_BRANCH"

# 1. Verify expected repository layout and branch.
CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$CUSTOM_BRANCH" ]]; then
    echo "ERROR: Expected branch '$CUSTOM_BRANCH'; current branch is '$CURRENT_BRANCH'."
    exit 1
fi

if [[ ! -f "$ROOT/kotlin-tv/settings.gradle.kts" &&
      ! -f "$ROOT/kotlin-tv/settings.gradle" ]]; then
    echo "ERROR: kotlin-tv Gradle project was not found."
    exit 1
fi

if [[ ! -x "$GRADLE" ]]; then
    echo "ERROR: Gradle executable not found: $GRADLE"
    echo "Set GRADLE=/path/to/gradle and run again."
    exit 1
fi

# 2. Never overwrite uncommitted work.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Working tree is not clean."
    echo "Commit intended changes or safely back them up first."
    git status --short
    exit 1
fi

# 3. Fetch upstream.
echo
echo "[1/7] Fetching upstream..."
git fetch --prune "$REMOTE"

if ! git show-ref --verify --quiet "refs/remotes/$UPSTREAM_REF"; then
    echo "ERROR: Remote branch '$UPSTREAM_REF' was not found."
    exit 1
fi

echo "Upstream commit:"
git log -1 --oneline "$UPSTREAM_REF"

# 4. Preserve the exact pre-update commit, then fast-forward or rebase.
echo
echo "[2/7] Synchronizing custom branch..."
if git merge-base --is-ancestor "$UPSTREAM_REF" HEAD; then
    echo "Custom branch already contains the latest upstream."
elif git merge-base --is-ancestor HEAD "$UPSTREAM_REF"; then
    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP_BRANCH="backup/pre-update-$STAMP"
    git branch "$BACKUP_BRANCH" HEAD
    echo "Recovery branch: $BACKUP_BRANCH"
    git merge --ff-only "$UPSTREAM_REF"
else
    if ! git merge-base "$UPSTREAM_REF" HEAD >/dev/null; then
        echo "ERROR: Custom branch and upstream have no common ancestor."
        exit 1
    fi

    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP_BRANCH="backup/pre-update-$STAMP"
    git branch "$BACKUP_BRANCH" HEAD
    echo "Recovery branch: $BACKUP_BRANCH"

    if ! git rebase "$UPSTREAM_REF"; then
        echo
        echo "REBASE CONFLICT: stopped without discarding either side."
        echo "Recovery branch: $BACKUP_BRANCH"
        echo "Resolve files, then run:"
        echo "  git add <resolved-files>"
        echo "  git rebase --continue"
        echo "Or cancel with:"
        echo "  git rebase --abort"
        exit 1
    fi
fi

# 5. Verify removed features have not silently returned upstream.
echo
echo "[3/7] Checking removed phone/social features..."
for dir in app/src/main core/src/main; do
    if [[ ! -d "$ROOT/$dir" ]]; then
        echo "ERROR: Expected source directory missing: $dir"
        exit 1
    fi
done

if grep -RniE --include='*.kt' --include='*.java' --include='*.xml' \
    'TvSocial|CommentEmoji|DanmakuLayout|TimedCommentWindows|AppCommentPages|CommentBytes|CommentSignature|CommentTransport|PublicComments|TimedComments|comment_emoji|danmakuButton|commentsButton|detailComments|弹幕设置|发送弹幕|评论 · 第|查看评论|剧评|PhoneConsole|PhoneControlCatalog|PhoneControlServer|PhoneControlPage' \
    app/src/main core/src/main; then
    echo "ERROR: Removed phone-control/comment/danmaku implementation appears in production source."
    echo "Review the upstream changes before building."
    exit 1
else
    echo "PASS: no known removed-feature implementation markers found."
fi

# 6. Guard the known touch-mode Back behavior. This is a static regression
# check for the exact fix recorded in TOUCH_FOCUS_CHECKLIST.md.
echo
echo "[4/9] Checking touch-mode ranking Back guard..."
MAIN_ACTIVITY="$ROOT/app/src/main/kotlin/com/hongguotv/nativeapp/MainActivity.kt"
if [[ ! -f "$MAIN_ACTIVITY" ]]; then
    echo "ERROR: MainActivity.kt not found; cannot verify touch-mode Back behavior."
    exit 1
fi
if ! grep -Fq '!window.decorView.isInTouchMode' "$MAIN_ACTIVITY" ||
   ! grep -Fq 'rankingScreen?.backToTop()' "$MAIN_ACTIVITY"; then
    echo "ERROR: The known touch-mode ranking Back guard appears to be missing."
    echo "Review goBack() against TOUCH_FOCUS_CHECKLIST.md before building."
    exit 1
fi
echo "PASS: touch-mode guard and ranking backToTop action are present."
echo "NOTE: this is a source-marker check, not proof of runtime behavior."

# 7. Run focused tests. The full app suite has known unrelated failures
# in the current baseline; keep this list explicit and easy to maintain.
echo
echo "[5/9] Running Core tests..."
"$GRADLE" -p "$ROOT/kotlin-tv" :core:test --no-daemon

echo
echo "[6/9] Running RankingScreen regression tests..."
"$GRADLE" -p "$ROOT/kotlin-tv" :app:testDebugUnitTest \
    --tests 'com.hongguotv.nativeapp.RankingScreenTest' \
    --no-daemon

echo
echo "[7/9] Running the social-removal UI regression test..."
"$GRADLE" -p "$ROOT/kotlin-tv" :app:testDebugUnitTest \
    --tests 'com.hongguotv.nativeapp.TvUsabilityTest.detailKeepsPlaybackCommentsAndSeparateSecondaryActions' \
    --no-daemon

# 8. Build and verify the Nexus 9 32-bit APK.
echo
echo "[8/9] Building Debug APK..."
"$GRADLE" -p "$ROOT/kotlin-tv" :app:assembleDebug --no-daemon

echo
echo "[9/9] Verifying Nexus 9 APK..."
APK="$ROOT/$APK_REL"
if [[ ! -f "$APK" ]]; then
    echo "ERROR: Expected ARMv7 APK not found: $APK"
    echo "Available APK files:"
    find "$ROOT/kotlin-tv/app/build" -type f -name '*.apk' -print
    exit 1
fi

echo
echo "=========================================="
echo " UPDATE AND BUILD SUCCESSFUL"
echo "=========================================="
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo "APK:    $APK"
ls -lh "$APK"
echo "SHA256:"
sha256sum "$APK"

echo
echo "Install manually after connecting Nexus 9:"
echo "adb install -r \"$APK\""
echo
echo "No commits were pushed to the upstream repository."
