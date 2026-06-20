#!/bin/bash
# Copyright © 2026 Mochi OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Starlark-pool authoriser test suite.
#
# Asserts the per-action authoriser policy on the Starlark connection
# pool (db.go db_authorise_starlark) and the api-layer string-prefix
# gate (db.go db_starlark_sql_blocked) by hitting test-app endpoints
# in apps/test/core.star.
#
# Each "denied" endpoint is expected to return a non-200 because the
# Starlark error aborts the action — the body should NOT contain
# "blocked":false or "status":"FAIL". The single "allowed" endpoint
# runs the full set of legitimate operations sequentially and returns
# {"status":"PASS"} when every step succeeds.
#
# Usage: ./test_authoriser.sh [-i <1|2>]

set -u

CURL="/home/alistair/mochi/claude/scripts/curl.sh"
INSTANCE="1"
if [ "${1:-}" = "-i" ] && [ -n "${2:-}" ]; then
    INSTANCE="$2"
fi
CURL_ARGS=( -i "$INSTANCE" -p )

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED+1)); }
fail() { echo "[FAIL] $1: $2"; FAILED=$((FAILED+1)); }

# expect_denied <name> <endpoint>
# Hits the endpoint and passes the test iff the response body contains
# an "error" key (i.e. the action errored out, which means the SQL was
# blocked).
expect_denied() {
    local name="$1"
    local endpoint="$2"
    local body
    body=$("$CURL" "${CURL_ARGS[@]}" "$endpoint" 2>&1)
    if echo "$body" | grep -q '"status":"FAIL"'; then
        fail "$name" "Action returned FAIL — SQL was NOT blocked: $body"
    elif echo "$body" | grep -q '"error":'; then
        pass "$name (errored as expected: $(echo "$body" | grep -o '"error":"[^"]*"' | head -1))"
    else
        fail "$name" "Unexpected response: $body"
    fi
}

# expect_allowed <endpoint>
# Hits the endpoint and passes iff the response is {"status":"PASS",...}.
expect_allowed() {
    local name="$1"
    local endpoint="$2"
    local body
    body=$("$CURL" "${CURL_ARGS[@]}" "$endpoint" 2>&1)
    if echo "$body" | grep -q '"status":"PASS"'; then
        pass "$name"
    else
        fail "$name" "Expected PASS, got: $body"
    fi
}

echo "=============================================="
echo "Starlark Authoriser Test Suite"
echo "=============================================="

# ---- denied at api-layer string-prefix gate ----
expect_denied "ATTACH"        "/test/test_attach"
expect_denied "DETACH"        "/test/test_detach"
expect_denied "PRAGMA write"  "/test/test_authoriser_pragma_write"
expect_denied "VACUUM"        "/test/test_authoriser_vacuum"
expect_denied "ANALYZE"       "/test/test_authoriser_analyze"

# ---- denied at SQLite authoriser ----
expect_denied "PRAGMA in BEGIN/COMMIT" "/test/test_authoriser_pragma_multistmt"
expect_denied "CREATE TRIGGER"          "/test/test_authoriser_create_trigger"
expect_denied "CREATE VIRTUAL TABLE"    "/test/test_authoriser_create_vtable"

# ---- foreign_keys=ON liveness ----
# Test attempts an FK-violating INSERT; if it succeeds the action
# returns FAIL, otherwise the action errors out — denied is correct.
expect_denied "FK violation caught"    "/test/test_authoriser_fk_violation"
"$CURL" "${CURL_ARGS[@]}" "/test/test_authoriser_fk_cleanup" >/dev/null 2>&1

# ---- allowed: full CRUD + DDL + transactions ----
# Run these last so any earlier multistmt-induced pool pollution has
# been cleared by the defensive rollback wrapper.
expect_allowed "allowed CRUD/DDL/transactions" "/test/test_authoriser_allowed"
expect_allowed "introspection (mochi.db.table/indexes/tables)" "/test/test_authoriser_introspection"
expect_allowed "fresh-app round-trip"          "/test/test_authoriser_roundtrip"

echo ""
echo "=============================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "=============================================="
exit $FAILED
