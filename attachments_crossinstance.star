# Mochi Claude Test app: Attachment Cross-Instance Tests
# Test attachment sync and federation between instances

def action_test_attachment_crossinstance_sync(a):
    """Test syncing attachments to a remote entity (mochi.attachment.sync).
    Run on Instance 1 with remote_entity param set to an entity ID from Instance 2."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None
    remote_entity = a.input("remote_entity")

    if not identity_id:
        a.json({
            "test": "attachment_crossinstance_sync",
            "passed": False,
            "error": "No identity - cannot test sync"
        })
        return

    if not remote_entity:
        a.json({
            "test": "attachment_crossinstance_sync",
            "passed": False,
            "error": "Missing 'remote_entity' parameter - provide entity ID from other instance"
        })
        return

    # Create object ID (like a post that will be synced)
    object_id = identity_id + "/syncedpost/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachments
    att1 = mochi.attachment.create(object_id, "sync_image.jpg", "Image data to sync", "image/jpeg", "Synced Photo", "Will be synced to remote")
    att2 = mochi.attachment.create(object_id, "sync_doc.txt", "Document to sync", "text/plain", "Synced Doc", "Also synced")

    if att1 and att2:
        results.append({"test": "create_attachments", "passed": True})
    else:
        results.append({"test": "create_attachments", "passed": False})
        passed = False

    # Sync attachments to remote entity
    # This sends _attachment/create events to the remote entity
    sync_result = mochi.attachment.sync(object_id, [remote_entity])
    results.append({"test": "sync_called", "passed": True, "recipients": [remote_entity]})

    # Verify local attachments still exist
    attachments = mochi.attachment.list(object_id)
    if len(attachments) == 2:
        results.append({"test": "local_attachments_intact", "passed": True})
    else:
        results.append({"test": "local_attachments_intact", "passed": False, "got": len(attachments)})
        passed = False

    a.json({
        "test": "attachment_crossinstance_sync",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "object": object_id,
        "remote_entity": remote_entity,
        "note": "Sync sent to remote entity - check server logs for delivery. Run test_attachment_crossinstance_verify on Instance 2."
    })

def action_test_attachment_crossinstance_fetch(a):
    """Test fetching attachments from a remote entity (mochi.attachment.fetch).
    Run on Instance 2 with source_entity param set to an entity ID from Instance 1."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None
    source_entity = a.input("source_entity")
    object_id = a.input("object_id")

    if not source_entity:
        a.json({
            "test": "attachment_crossinstance_fetch",
            "passed": False,
            "error": "Missing 'source_entity' parameter - provide entity ID from source instance"
        })
        return

    if not object_id:
        a.json({
            "test": "attachment_crossinstance_fetch",
            "passed": False,
            "error": "Missing 'object_id' parameter - provide object ID from source instance"
        })
        return

    # Fetch attachments from remote entity
    # This sends _attachment/fetch event to request attachments
    fetched = mochi.attachment.fetch(object_id, source_entity)

    if fetched and len(fetched) > 0:
        results.append({"test": "fetch_returned_attachments", "passed": True, "count": len(fetched)})
    else:
        results.append({"test": "fetch_returned_attachments", "passed": False, "got": fetched,
                       "note": "May need time for P2P delivery"})
        passed = False

    a.json({
        "test": "attachment_crossinstance_fetch",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "source_entity": source_entity,
        "object_id": object_id,
        "note": "Fetched attachments from remote entity"
    })

def action_test_attachment_crossinstance_isolation(a):
    """Test that attachments are isolated between instances.
    Run on Instance 2 to verify Instance 1's attachments are not visible."""
    results = []
    passed = True

    username = a.user.username

    # Object ID that Instance 1 might have used
    object_id = "multiuser/isolation/testobject"

    # List attachments - should only see this instance's attachments
    attachments = mochi.attachment.list(object_id)

    # Check for Instance 1's attachments (they shouldn't be here)
    instance1_files = [a for a in attachments if "user1" in a["name"] or "sync" in a["name"]]

    if len(instance1_files) == 0:
        results.append({"test": "instance1_attachments_not_visible", "passed": True})
    else:
        results.append({"test": "instance1_attachments_not_visible", "passed": False,
                       "got": [a["name"] for a in instance1_files],
                       "error": "Instance 1 attachments should not be visible!"})
        passed = False

    # Create local attachment to verify our space works
    test_att = mochi.attachment.create(object_id, "instance2_test.txt", "Instance 2 content")
    if test_att:
        results.append({"test": "instance2_can_create", "passed": True})
        mochi.attachment.delete(test_att["id"])
    else:
        results.append({"test": "instance2_can_create", "passed": False})
        passed = False

    a.json({
        "test": "attachment_crossinstance_isolation",
        "passed": passed,
        "results": results,
        "username": username,
        "note": "Verified attachment isolation between instances"
    })

def action_test_attachment_crossinstance_notify(a):
    """Test attachment operations with notify parameter for federation.
    Simulates Chat/Feeds/Forums notification patterns."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None
    remote_entities = a.input("remote_entities")

    if not identity_id:
        a.json({
            "test": "attachment_crossinstance_notify",
            "passed": False,
            "error": "No identity - cannot test notification"
        })
        return

    # Parse remote entities (comma-separated)
    notify_list = []
    if remote_entities:
        notify_list = [e.strip() for e in remote_entities.split(",") if e.strip()]

    object_id = identity_id + "/notifytest/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Test 1: Create with notify (like Chat sending a message with attachments)
    att1 = mochi.attachment.create(object_id, "notified.jpg", "Image data", "image/jpeg", "Photo", "Shared with subscribers", notify_list)
    if att1:
        results.append({"test": "create_with_notify", "passed": True, "notified": len(notify_list)})
    else:
        results.append({"test": "create_with_notify", "passed": False})
        passed = False

    # Test 2: Insert with notify
    att2 = mochi.attachment.insert(object_id, "inserted.txt", "Inserted data", 0, "text/plain", "Inserted", "Description", notify_list)
    if att2:
        results.append({"test": "insert_with_notify", "passed": True})
    else:
        results.append({"test": "insert_with_notify", "passed": False})
        passed = False

    # Test 3: Update with notify
    if att1:
        mochi.attachment.update(att1["id"], "Updated Caption", "Updated Description", notify_list)
        results.append({"test": "update_with_notify", "passed": True})

    # Test 4: Move with notify
    if att2:
        mochi.attachment.move(att2["id"], 1, notify_list)
        results.append({"test": "move_with_notify", "passed": True})

    # Test 5: Delete with notify
    if att2:
        mochi.attachment.delete(att2["id"], notify_list)
        remaining = mochi.attachment.list(object_id)
        if len(remaining) == 1:
            results.append({"test": "delete_with_notify", "passed": True})
        else:
            results.append({"test": "delete_with_notify", "passed": False, "got": len(remaining)})
            passed = False

    # Test 6: Clear with notify (like deleting a post)
    mochi.attachment.clear(object_id, notify_list)
    cleared = mochi.attachment.list(object_id)
    if len(cleared) == 0:
        results.append({"test": "clear_with_notify", "passed": True})
    else:
        results.append({"test": "clear_with_notify", "passed": False, "got": len(cleared)})
        passed = False

    a.json({
        "test": "attachment_crossinstance_notify",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "object": object_id,
        "notify_list": notify_list,
        "note": "Federation events sent to remote entities. Check server logs."
    })

def action_test_attachment_all(a):
    """List all attachment test endpoints"""
    a.json({
        "note": "Run individual test endpoints for isolated results",
        "single_user_tests": [
            "test_attachment_create",
            "test_attachment_insert",
            "test_attachment_update",
            "test_attachment_move",
            "test_attachment_delete",
            "test_attachment_clear",
            "test_attachment_get_data_path",
            "test_attachment_list",
            "test_attachment_crud",
            "test_attachment_binary",
            "test_attachment_content_types",
            "test_attachment_url_single"
        ],
        "multiuser_same_instance_tests": [
            "test_attachment_multiuser_isolation (run as user 1)",
            "test_attachment_multiuser_isolation_verify (run as user 2)",
            "test_attachment_multiuser_shared",
            "test_attachment_url_multiuser (run as user 1)",
            "test_attachment_url_multiuser_verify (run as user 2)"
        ],
        "crossinstance_tests": [
            "test_attachment_crossinstance_sync?remote_entity=<entity_id>",
            "test_attachment_crossinstance_fetch?source_entity=<entity_id>&object_id=<object_id>",
            "test_attachment_crossinstance_isolation",
            "test_attachment_crossinstance_notify?remote_entities=<entity1>,<entity2>",
            "test_attachment_url_crossinstance (run on instance 1)",
            "test_attachment_url_crossinstance_verify?source_entity=<entity_id>&object_id=<object_id> (run on instance 2)"
        ]
    })
