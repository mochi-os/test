# UnifiedPush distributor registration tests.
#
# Exercise the new push/register service function exposed by the
# notifications app. The Mochi-distributor case (no endpoint passed)
# should synthesise a path-only endpoint; the foreign-distributor case
# (endpoint passed) should store the URL verbatim.
#
# Requires the notifications/send permission to call the service. The
# test app already has it via apps_default.

def action_test_unifiedpush_register_local(a):
    """Mochi-distributor case: register without an endpoint. Server should
    synthesise a path-only endpoint pointing at /menu/-/push/inbound/<id>."""
    results = []

    result = mochi.service.call(
        "notifications", "push/register",
        label="test-local-distributor",
        auth="WPF1D0bTRYUiNH98kIfhjA",
        p256dh="BGc2vQrRsQGN6oKjmkP_3RaMtxAaAevBBe7N0xCv1tIJaEGI3DRD0fA73tk5Mt1JsmvP6Z8tFc8MGD7e2eUKHKM",
        endpoint="",
    )

    results.append({
        "test": "register_returns_data",
        "passed": result != None and result.get("id", 0) > 0,
    })

    if result and result.get("id"):
        endpoint = result.get("endpoint", "")
        results.append({
            "test": "endpoint_is_path_only",
            "passed": endpoint.startswith("/menu/-/push/inbound/"),
            "actual": endpoint,
        })
        results.append({
            "test": "endpoint_includes_account_id",
            "passed": str(result["id"]) in endpoint,
        })

        # Cleanup: remove the test subscription.
        mochi.service.call("notifications", "accounts/remove", id=result["id"])

    a.json({"test": "unifiedpush_register_local", "results": results})

def action_test_unifiedpush_register_foreign(a):
    """Third-party-distributor case: register WITH an endpoint URL. We can't
    introspect the stored endpoint from Starlark — `mochi.account.get`
    deliberately redacts the data column (it holds push subscription
    secrets / API keys / etc.). The Go test
    TestUnifiedPushDeliverRemote verifies the round-trip via an httptest
    server. Here we only assert the registration call itself succeeds and
    distinguishes the foreign case (different account id from local) so
    that the foreign code path in function_push_register is exercised."""
    results = []

    foreign_url = "https://ntfy.example/upabc"
    result = mochi.service.call(
        "notifications", "push/register",
        label="test-foreign-distributor",
        auth="WPF1D0bTRYUiNH98kIfhjA",
        p256dh="BGc2vQrRsQGN6oKjmkP_3RaMtxAaAevBBe7N0xCv1tIJaEGI3DRD0fA73tk5Mt1JsmvP6Z8tFc8MGD7e2eUKHKM",
        endpoint=foreign_url,
    )

    results.append({
        "test": "register_returns_data",
        "passed": result != None and result.get("id", 0) > 0,
    })

    if result and result.get("id"):
        # Foreign case must NOT echo back a synthesised path-only endpoint —
        # that's the local-distributor behaviour. The result either omits
        # `endpoint` or carries the foreign URL we passed in.
        echoed = result.get("endpoint", "")
        results.append({
            "test": "no_path_only_endpoint_synthesised",
            "passed": not echoed.startswith("/menu/-/push/inbound/"),
            "actual": echoed,
        })

        # Cleanup
        mochi.service.call("notifications", "accounts/remove", id=result["id"])

    a.json({"test": "unifiedpush_register_foreign", "results": results})

def action_test_unifiedpush_register_validation(a):
    """Missing auth/p256dh should fail registration."""
    results = []

    result = mochi.service.call(
        "notifications", "push/register",
        label="missing-keys",
        auth="",
        p256dh="",
        endpoint="",
    )

    results.append({
        "test": "missing_keys_returns_none",
        "passed": result == None,
    })

    a.json({"test": "unifiedpush_register_validation", "results": results})
