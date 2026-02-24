#!/bin/bash
# Feeds Source Credibility Test Suite
# Tests credibility CRUD on feed sources via HTTP API
# Usage: ./test_credibility.sh

set -e

CURL_HELPER="/home/alistair/mochi/claude/scripts/curl.sh"

PASSED=0
FAILED=0
FEED_ENTITY=""
SOURCE_ID=""

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
echo "Feeds Source Credibility Test Suite"
echo "=============================================="

# ============================================================================
# SETUP: Create test feed
# ============================================================================

echo ""
echo "--- Setup ---"

RESULT=$("$CURL_HELPER" -a admin -X POST -H "Content-Type: application/json" -d '{"name":"Credibility Test Feed","privacy":"private"}' "/feeds/-/create")
FEED_ENTITY=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)

if [ -n "$FEED_ENTITY" ]; then
    echo "Created test feed: $FEED_ENTITY"
else
    echo "FATAL: Could not create test feed"
    echo "Response: $RESULT"
    exit 1
fi

# ============================================================================
# SOURCE CREDIBILITY TESTS
# ============================================================================

echo ""
echo "--- Add RSS Source ---"

# Test: Add an RSS source
RESULT=$(feed_curl POST "/sources/add" -H "Content-Type: application/json" -d '{"type":"rss","url":"https://feeds.bbci.co.uk/news/rss.xml"}')
if echo "$RESULT" | python3 -c "import sys, json; d=json.load(sys.stdin); assert 'data' in d and 'source' in d['data']" 2>/dev/null; then
    SOURCE_ID=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['source']['id'])" 2>/dev/null)
    if [ -n "$SOURCE_ID" ]; then
        pass "Add RSS source (id: $SOURCE_ID)"
    else
        fail "Add RSS source" "Could not extract source ID"
    fi
else
    fail "Add RSS source" "$RESULT"
fi

echo ""
echo "--- List Sources ---"

# Test: List sources — verify credibility field is present
RESULT=$(feed_curl GET "/sources")
CRED=$(echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
sources = d['data']['sources']
for s in sources:
    if s['id'] == '$SOURCE_ID':
        print(s.get('credibility', 'MISSING'))
        break
" 2>/dev/null)

if [ -n "$CRED" ] && [ "$CRED" != "MISSING" ]; then
    pass "List sources has credibility field (value: $CRED)"
else
    fail "List sources credibility" "credibility field missing or not found: $RESULT"
fi

echo ""
echo "--- Edit Credibility ---"

# Test: Edit credibility to 42
RESULT=$(feed_curl POST "/sources/edit" -H "Content-Type: application/json" -d "{\"source\":\"$SOURCE_ID\",\"credibility\":42}")
if echo "$RESULT" | grep -q '"ok":true'; then
    pass "Edit credibility to 42"
else
    fail "Edit credibility to 42" "$RESULT"
fi

# Test: Verify credibility is now 42
RESULT=$(feed_curl GET "/sources")
CRED=$(echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for s in d['data']['sources']:
    if s['id'] == '$SOURCE_ID':
        print(s['credibility'])
        break
" 2>/dev/null)

if [ "$CRED" = "42" ]; then
    pass "Verify credibility is 42"
else
    fail "Verify credibility is 42" "got: $CRED"
fi

echo ""
echo "--- Edit Name ---"

# Test: Edit source name
RESULT=$(feed_curl POST "/sources/edit" -H "Content-Type: application/json" -d "{\"source\":\"$SOURCE_ID\",\"name\":\"Renamed Source\"}")
if echo "$RESULT" | grep -q '"ok":true'; then
    pass "Edit source name"
else
    fail "Edit source name" "$RESULT"
fi

echo ""
echo "--- Boundary Validation ---"

# Test: Credibility too high (101)
RESULT=$(feed_curl POST "/sources/edit" -H "Content-Type: application/json" -d "{\"source\":\"$SOURCE_ID\",\"credibility\":101}")
HTTP_OK=$(echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('error' in d or 'ok' not in d.get('data', {}))
" 2>/dev/null)

if echo "$RESULT" | grep -qi "credibility\|between\|invalid\|error"; then
    pass "Reject credibility=101"
else
    fail "Reject credibility=101" "Expected error, got: $RESULT"
fi

# Test: Credibility too low (-1)
RESULT=$(feed_curl POST "/sources/edit" -H "Content-Type: application/json" -d "{\"source\":\"$SOURCE_ID\",\"credibility\":-1}")
if echo "$RESULT" | grep -qi "credibility\|between\|invalid\|error"; then
    pass "Reject credibility=-1"
else
    fail "Reject credibility=-1" "Expected error, got: $RESULT"
fi

# Verify credibility didn't change from 42 after invalid edits
RESULT=$(feed_curl GET "/sources")
CRED=$(echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for s in d['data']['sources']:
    if s['id'] == '$SOURCE_ID':
        print(s['credibility'])
        break
" 2>/dev/null)

if [ "$CRED" = "42" ]; then
    pass "Credibility unchanged after invalid edits"
else
    fail "Credibility unchanged after invalid edits" "got: $CRED, expected: 42"
fi

echo ""
echo "--- Edit Nonexistent Source ---"

# Test: Edit with bogus source ID
RESULT=$(feed_curl POST "/sources/edit" -H "Content-Type: application/json" -d '{"source":"nonexistent-id-999","credibility":50}')
if echo "$RESULT" | grep -qi "error\|not found\|invalid"; then
    pass "Reject edit of nonexistent source"
else
    fail "Reject edit of nonexistent source" "Expected error, got: $RESULT"
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
