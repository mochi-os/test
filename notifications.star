# Copyright © 2026 Mochisoft OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Notifications service permission-gate probes.
#
# The test app deliberately holds notifications/send but NOT
# notifications/read or notifications/manage, so it doubles as the
# unprivileged caller for the gated functions. A denied service call
# aborts the whole action (no try/except in Starlark), so each denial
# probe is its own action and the harness asserts on the HTTP error:
# a permission-required error means the gate held; a JSON body with
# "denied": False means the gate is missing.

def action_test_notifications_gate_read(a):
    """Must be DENIED: list requires notifications/read."""
    result = mochi.service.call("notifications", "list")
    a.json({"test": "notifications_gate_read", "denied": False, "rows": len(result or [])})

def action_test_notifications_gate_manage(a):
    """Must be DENIED: topic/list requires notifications/manage."""
    result = mochi.service.call("notifications", "topic/list")
    a.json({"test": "notifications_gate_manage", "denied": False, "rows": len(result or [])})

def action_test_notifications_emit(a):
    """Send a real notification through the routing pipeline and leave it in
    place; the RSS routing tests assert which feeds carry it. The topic row
    is created lazily with the user's default category."""
    topic = a.input("topic", "probe")
    object = a.input("object", "rss-probe")
    title = a.input("title", "RSS probe")
    body = a.input("body", "rss-routing-probe-body")
    event = a.input("event", "")
    sent = mochi.service.call("notifications", "send", topic, object, title, body, "", "Test probe", event_id=event)
    a.json({"sent": sent})

def action_test_notifications_cleanup(a):
    """Remove the emitted probe notification and its topic row."""
    topic = a.input("topic", "probe")
    object = a.input("object", "rss-probe")
    cleared = mochi.service.call("notifications", "clear/object", object)
    removed = mochi.service.call("notifications", "topic/remove", topic, object)
    a.json({"cleared": cleared, "removed": removed})

def action_test_notifications_send_clear(a):
    """Must SUCCEED: send stays ungated (context-stamped app id), and
    clear/object takes only the object, scoped to the calling app."""
    results = []

    sent = mochi.service.call(
        "notifications", "send",
        "probe", "gate-probe-1", "Gate probe", "Sent by the test app's permission-gate probe", "",
        "Test probe",
    )
    results.append({"test": "send_ungated", "passed": sent == 1})

    cleared = mochi.service.call("notifications", "clear/object", "gate-probe-1")
    results.append({"test": "clear_object_self_scoped", "passed": cleared == True})

    a.json({"test": "notifications_send_clear", "results": results})
