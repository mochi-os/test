# Copyright © 2026 Mochisoft OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Frame forging for P2P rejection tests.
#
# The p2p-test harness drives real actions through real handlers, so every
# frame it produces is well formed. That leaves every rejection path in an
# event handler - malformed markers, unauthorised writers, stale tuples -
# verified by inspection alone: a `return` no test has ever caused to fire.
#
# mochi.message.send is deliberately not constrained by the sending app's
# declared services, so this app can emit a frame addressed to another app's
# service and event with an arbitrary content dict. The frame is genuine: it
# travels the real queue, the real dispatch, and arrives authenticated as the
# calling user's identity. Only the payload is under the test's control, which
# is exactly the attacker's position - a participant who tampers with what
# their own client sends.
#
# apps/test is not published, so this lives with the other probes here rather
# than adding a test-only route to a shipped app.

def action_forge(a):
	"""Send an arbitrary content dict to another app's event handler.

	Inputs: to (recipient entity), service, event, and content (JSON object).
	The sender is the calling identity, so the caller must be whichever
	participant the receiving handler expects to hear from."""
	to = a.input("to")
	if not mochi.text.valid(to, "entity"):
		a.error(400, "invalid to")
		return

	service = a.input("service")
	event = a.input("event")
	if not service or not event:
		a.error(400, "service and event are required")
		return

	content = json.decode(a.input("content", "{}"), None)
	if content == None or type(content) != "dict":
		a.error(400, "content must be a JSON object")
		return

	result = mochi.message.send(
		{"from": a.user.identity.id, "to": to, "service": service, "event": event},
		content
	)
	a.json({"sent": True, "result": result, "service": service, "event": event})
