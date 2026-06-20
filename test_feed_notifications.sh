#!/bin/bash
# Copyright © 2026 Mochi OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Per-Feed Notification Settings Test Suite
# Tests notification settings CRUD on feeds via HTTP API
# Usage: ./test_feed_notifications.sh

set -e

CURL_HELPER="/home/alistair/mochi/claude/scripts/curl.sh"

PASSED=0
FAILED=0
FEED_ENTITY=""

pass() {
    echo "[PASS] $1"
    ((PASSED++)) || true
}

fail() {
    echo "[FAIL] $1: $2"
    ((FAILED++)) || true
}

# Helper to make feed-level requests (entity context with /-/ prefix)
feed_curl() {
    local method="$1"
    local path="$2"
    shift 2
    "$CURL_HELPER" -a admin -X "$method" "$@" "/feeds/$FEED_ENTITY/-$path"
}

echo "=============================================="
echo "Per-Feed Notification Settings Test Suite"
echo "=============================================="

# ============================================================================
# SETUP: Create test feed
# ============================================================================

echo ""
echo "--- Setup ---"

RESULT=$("$CURL_HELPER" -a admin -X POST -H "Content-Type: application/json" -d '{"name":"Notification Test Feed","privacy":"private"}' "/feeds/-/create")
FEED_ENTITY=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)

if [ -n "$FEED_ENTITY" ]; then
    echo "Created test feed: $FEED_ENTITY"
else
    echo "FATAL: Could not create test feed"
    echo "Response: $RESULT"
    exit 1
fi

# ============================================================================
# TEST: Get default notification settings (no custom settings)
# ============================================================================

echo ""
echo "--- Get Default Settings ---"

RESULT=$(feed_curl GET "/notifications/get")
ENABLED=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['enabled'])" 2>/dev/null)
MODE=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['mode'])" 2>/dev/null)
CUSTOM=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['custom'])" 2>/dev/null)

if [ "$ENABLED" = "True" ]; then
    pass "Default enabled=True"
else
    fail "Default enabled=True" "got: $ENABLED"
fi

if [ "$MODE" = "all" ]; then
    pass "Default mode=all"
else
    fail "Default mode=all" "got: $MODE"
fi

if [ "$CUSTOM" = "False" ]; then
    pass "Default custom=False"
else
    fail "Default custom=False" "got: $CUSTOM"
fi

# ============================================================================
# TEST: Set notification settings (create custom)
# ============================================================================

echo ""
echo "--- Set Custom Settings ---"

# Set enabled=1, mode=all
RESULT=$(feed_curl POST "/notifications/set" -H "Content-Type: application/json" -d '{"enabled":"1","mode":"all"}')
if echo "$RESULT" | grep -q '"success":true'; then
    pass "Set notifications (enabled=1, mode=all)"
else
    fail "Set notifications (enabled=1, mode=all)" "$RESULT"
fi

# Verify custom settings applied
RESULT=$(feed_curl GET "/notifications/get")
ENABLED=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['enabled'])" 2>/dev/null)
MODE=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['mode'])" 2>/dev/null)
CUSTOM=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['custom'])" 2>/dev/null)

if [ "$ENABLED" = "True" ]; then
    pass "Verify enabled=True after set"
else
    fail "Verify enabled=True after set" "got: $ENABLED"
fi

if [ "$MODE" = "all" ]; then
    pass "Verify mode=all after set"
else
    fail "Verify mode=all after set" "got: $MODE"
fi

if [ "$CUSTOM" = "True" ]; then
    pass "Verify custom=True after set"
else
    fail "Verify custom=True after set" "got: $CUSTOM"
fi

# ============================================================================
# TEST: Update settings (disable notifications)
# ============================================================================

echo ""
echo "--- Update Settings ---"

RESULT=$(feed_curl POST "/notifications/set" -H "Content-Type: application/json" -d '{"enabled":"0","mode":"all"}')
if echo "$RESULT" | grep -q '"success":true'; then
    pass "Update notifications (enabled=0)"
else
    fail "Update notifications (enabled=0)" "$RESULT"
fi

RESULT=$(feed_curl GET "/notifications/get")
ENABLED=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['enabled'])" 2>/dev/null)

if [ "$ENABLED" = "False" ]; then
    pass "Verify enabled=False after disable"
else
    fail "Verify enabled=False after disable" "got: $ENABLED"
fi

# ============================================================================
# TEST: Update mode back to each
# ============================================================================

echo ""
echo "--- Update Mode ---"

RESULT=$(feed_curl POST "/notifications/set" -H "Content-Type: application/json" -d '{"enabled":"1","mode":"each"}')
if echo "$RESULT" | grep -q '"success":true'; then
    pass "Update mode to each"
else
    fail "Update mode to each" "$RESULT"
fi

RESULT=$(feed_curl GET "/notifications/get")
MODE=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['mode'])" 2>/dev/null)

if [ "$MODE" = "each" ]; then
    pass "Verify mode=each after update"
else
    fail "Verify mode=each after update" "got: $MODE"
fi

# ============================================================================
# TEST: Invalid mode
# ============================================================================

echo ""
echo "--- Validation ---"

RESULT=$(feed_curl POST "/notifications/set" -H "Content-Type: application/json" -d '{"enabled":"1","mode":"invalid"}')
if echo "$RESULT" | grep -qi "error\|must be"; then
    pass "Reject invalid mode"
else
    fail "Reject invalid mode" "$RESULT"
fi

# ============================================================================
# TEST: Reset to defaults
# ============================================================================

echo ""
echo "--- Reset to Defaults ---"

RESULT=$(feed_curl POST "/notifications/reset")
if echo "$RESULT" | grep -q '"success":true'; then
    pass "Reset notifications"
else
    fail "Reset notifications" "$RESULT"
fi

# Verify back to defaults
RESULT=$(feed_curl GET "/notifications/get")
CUSTOM=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['custom'])" 2>/dev/null)
ENABLED=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['enabled'])" 2>/dev/null)
MODE=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['mode'])" 2>/dev/null)

if [ "$CUSTOM" = "False" ]; then
    pass "Verify custom=False after reset"
else
    fail "Verify custom=False after reset" "got: $CUSTOM"
fi

if [ "$ENABLED" = "True" ]; then
    pass "Verify enabled=True after reset"
else
    fail "Verify enabled=True after reset" "got: $ENABLED"
fi

if [ "$MODE" = "all" ]; then
    pass "Verify mode=all after reset"
else
    fail "Verify mode=all after reset" "got: $MODE"
fi

# ============================================================================
# TEST: Set and then delete feed (cleanup of notification settings)
# ============================================================================

echo ""
echo "--- Cleanup on Delete ---"

# Set custom settings again
RESULT=$(feed_curl POST "/notifications/set" -H "Content-Type: application/json" -d '{"enabled":"1","mode":"all"}')
if echo "$RESULT" | grep -q '"success":true'; then
    pass "Set notifications before delete"
else
    fail "Set notifications before delete" "$RESULT"
fi

# ============================================================================
# CLEANUP
# ============================================================================

echo ""
echo "--- Cleanup ---"

RESULT=$(feed_curl POST "/delete")
if echo "$RESULT" | grep -q '"success":true'; then
    echo "Deleted test feed"
else
    echo "WARNING: Could not delete test feed: $RESULT"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=============================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=============================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi
