# Mochi Claude Test app: Attachment Multi-User Tests
# Test attachment isolation and sharing between users

def action_test_attachment_multiuser_isolation(a):
    """Test that attachments are isolated between users on the same instance.
    Run as user 1, then run test_attachment_multiuser_isolation_verify as user 2."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "unknown"

    # Object ID that user 1 creates attachments for
    object_id = "multiuser/isolation/testobject"

    # Clean up from previous runs
    mochi.attachment.clear(object_id)

    # Create attachments as this user
    att1 = mochi.attachment.create(object_id, "user1_file1.txt", "Secret content from " + username, "text/plain", "User1 Caption", "Private")
    att2 = mochi.attachment.create(object_id, "user1_file2.jpg", "Image from " + username, "image/jpeg")

    if att1 and att2:
        results.append({"test": "create_attachments", "passed": True})
    else:
        results.append({"test": "create_attachments", "passed": False})
        passed = False

    # Verify we can list them
    attachments = mochi.attachment.list(object_id)
    if len(attachments) == 2:
        results.append({"test": "list_own_attachments", "passed": True})
    else:
        results.append({"test": "list_own_attachments", "passed": False, "got": len(attachments)})
        passed = False

    # Store the IDs for verification
    att_ids = [att1["id"], att2["id"]]

    a.json({
        "test": "attachment_multiuser_isolation",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "object": object_id,
        "attachment_ids": att_ids,
        "note": "Run test_attachment_multiuser_isolation_verify as a DIFFERENT user"
    })

def action_test_attachment_multiuser_isolation_verify(a):
    """Verify that user 1's attachments are NOT visible to user 2.
    Run as user 2 after running test_attachment_multiuser_isolation as user 1."""
    results = []
    passed = True

    username = a.user.username
    object_id = "multiuser/isolation/testobject"

    # Try to list attachments for the same object
    # Each user has their own attachment space, so this should be empty or different
    attachments = mochi.attachment.list(object_id)

    # Check if we see user 1's files
    user1_files = [a for a in attachments if "user1" in a["name"]]

    if len(user1_files) == 0:
        results.append({"test": "user1_attachments_not_visible", "passed": True,
                       "note": "User 1's attachments correctly not visible to user 2"})
    else:
        results.append({"test": "user1_attachments_not_visible", "passed": False,
                       "got": [a["name"] for a in user1_files],
                       "error": "SECURITY ISSUE: User 1's attachments visible to user 2!"})
        passed = False

    # Create our own attachment to verify we have a separate space
    test_att = mochi.attachment.create(object_id, "user2_test.txt", "User 2 content")
    if test_att:
        results.append({"test": "user2_can_create", "passed": True})
    else:
        results.append({"test": "user2_can_create", "passed": False})
        passed = False

    # Verify our attachment exists
    our_attachments = mochi.attachment.list(object_id)
    our_names = [a["name"] for a in our_attachments]
    if "user2_test.txt" in our_names:
        results.append({"test": "user2_attachment_visible", "passed": True})
    else:
        results.append({"test": "user2_attachment_visible", "passed": False, "got": our_names})
        passed = False

    # Clean up our test attachment
    if test_att:
        mochi.attachment.delete(test_att["id"])

    a.json({
        "test": "attachment_multiuser_isolation_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id,
        "note": "Verified attachment isolation between users"
    })

def action_test_attachment_multiuser_shared(a):
    """Test sharing attachments between users via entities.
    This simulates a feed/forum where owner creates content and shares with subscribers."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None

    if not identity_id:
        a.json({
            "test": "attachment_multiuser_shared",
            "passed": False,
            "error": "No identity - cannot test sharing"
        })
        return

    # Create an object using the entity ID (like a feed post)
    object_id = identity_id + "/sharedpost/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachments
    att1 = mochi.attachment.create(object_id, "shared_image.jpg", "Shared image data", "image/jpeg", "Shared Photo", "For subscribers")
    att2 = mochi.attachment.create(object_id, "shared_doc.pdf", "Shared document", "application/pdf")

    if att1 and att2:
        results.append({"test": "create_shared_attachments", "passed": True})
    else:
        results.append({"test": "create_shared_attachments", "passed": False})
        passed = False

    # Verify attachments exist
    attachments = mochi.attachment.list(object_id)
    if len(attachments) == 2:
        results.append({"test": "list_shared_attachments", "passed": True})
    else:
        results.append({"test": "list_shared_attachments", "passed": False, "got": len(attachments)})
        passed = False

    # Note: Actual sharing via sync/fetch is tested in cross-instance tests
    # Here we just verify the creation works with entity-based object IDs

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_multiuser_shared",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "object": object_id,
        "note": "Entity-based object IDs work for shared content"
    })

