#!/bin/bash
# Entity and Account API Test Suite
# Tests mochi.entity.update() and mochi.account.add/update with kwargs
# Usage: ./test_entities.sh

set -e

SCRIPT_DIR="$(dirname "$0")"
CURL_HELPER="/home/alistair/mochi/test/claude/curl.sh"

PASSED=0
FAILED=0

pass() {
    echo "[PASS] $1"
    ((PASSED++)) || true
}

fail() {
    echo "[FAIL] $1: $2"
    ((FAILED++)) || true
}

# Helper to make test app requests
test_curl() {
    "$CURL_HELPER" -a admin "$@"
}

echo "=============================================="
echo "Entity and Account API Test Suite"
echo "=============================================="

# ============================================================================
# ENTITY UPDATE TESTS
# ============================================================================

echo ""
echo "--- Entity Update Tests ---"

# Test: Update entity name
RESULT=$(test_curl "/test/test_entity_update_name")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Entity update name"
else
    fail "Entity update name" "$RESULT"
fi

# Test: Update entity data
RESULT=$(test_curl "/test/test_entity_update_data")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Entity update data"
else
    fail "Entity update data" "$RESULT"
fi

# Test: Update entity privacy
RESULT=$(test_curl "/test/test_entity_update_privacy")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Entity update privacy"
else
    fail "Entity update privacy" "$RESULT"
fi

# Test: Update multiple entity fields
RESULT=$(test_curl "/test/test_entity_update_multiple")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Entity update multiple fields"
else
    fail "Entity update multiple fields" "$RESULT"
fi

# Test: Update with invalid parameters
RESULT=$(test_curl "/test/test_entity_update_invalid")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Entity update invalid params"
else
    fail "Entity update invalid params" "$RESULT"
fi

# ============================================================================
# ACCOUNT API TESTS (KWARGS STYLE)
# ============================================================================

echo ""
echo "--- Account API Tests (kwargs style) ---"

# Test: Add account with kwargs
RESULT=$(test_curl "/test/test_account_add_kwargs")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Account add with kwargs"
else
    fail "Account add with kwargs" "$RESULT"
fi

# Test: Update account with kwargs
RESULT=$(test_curl "/test/test_account_update_kwargs")
if echo "$RESULT" | grep -q '"passed":true'; then
    pass "Account update with kwargs"
else
    fail "Account update with kwargs" "$RESULT"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=============================================="
echo "Test Results: $PASSED passed, $FAILED failed"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
