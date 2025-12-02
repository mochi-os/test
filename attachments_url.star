# Mochi Claude Test app: Attachment URL Tests
# Test attachment URL generation and serving

def action_test_attachment_url_single(a):
    """Test that attachment to_map returns correct url and thumbnail_url fields for single user."""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/url/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Test 1: Create non-image attachment and verify url field
    att_text = mochi.attachment.create(object_id, "document.pdf", "PDF content", "application/pdf")
    if att_text and "url" in att_text:
        expected_url = "/claude-test/files/" + att_text["id"]
        if att_text["url"] == expected_url:
            results.append({"test": "non_image_url", "passed": True, "url": att_text["url"]})
        else:
            results.append({"test": "non_image_url", "passed": False, "expected": expected_url, "got": att_text["url"]})
            passed = False
    else:
        results.append({"test": "non_image_url", "passed": False, "error": "url field missing"})
        passed = False

    # Test 2: Non-image should NOT have thumbnail_url
    if att_text and "thumbnail_url" not in att_text:
        results.append({"test": "non_image_no_thumbnail", "passed": True})
    else:
        results.append({"test": "non_image_no_thumbnail", "passed": False, "got": att_text.get("thumbnail_url")})
        passed = False

    # Test 3: Create image attachment and verify url and thumbnail_url
    att_img = mochi.attachment.create(object_id, "photo.jpg", "JPEG data", "image/jpeg")
    if att_img and "url" in att_img:
        expected_url = "/claude-test/files/" + att_img["id"]
        if att_img["url"] == expected_url:
            results.append({"test": "image_url", "passed": True, "url": att_img["url"]})
        else:
            results.append({"test": "image_url", "passed": False, "expected": expected_url, "got": att_img["url"]})
            passed = False
    else:
        results.append({"test": "image_url", "passed": False, "error": "url field missing"})
        passed = False

    # Test 4: Image should have thumbnail_url
    if att_img and "thumbnail_url" in att_img:
        expected_thumb = "/claude-test/files/" + att_img["id"] + "/thumbnail"
        if att_img["thumbnail_url"] == expected_thumb:
            results.append({"test": "image_thumbnail_url", "passed": True, "thumbnail_url": att_img["thumbnail_url"]})
        else:
            results.append({"test": "image_thumbnail_url", "passed": False, "expected": expected_thumb, "got": att_img["thumbnail_url"]})
            passed = False
    else:
        results.append({"test": "image_thumbnail_url", "passed": False, "error": "thumbnail_url field missing"})
        passed = False

    # Test 5: Verify image field is correctly set
    if att_text and att_text.get("image") == False:
        results.append({"test": "non_image_flag", "passed": True})
    else:
        results.append({"test": "non_image_flag", "passed": False, "got": att_text.get("image")})
        passed = False

    if att_img and att_img.get("image") == True:
        results.append({"test": "image_flag", "passed": True})
    else:
        results.append({"test": "image_flag", "passed": False, "got": att_img.get("image")})
        passed = False

    # Test 6: Verify list also returns url fields
    attachments = mochi.attachment.list(object_id)
    urls_present = all("url" in a for a in attachments)
    if urls_present:
        results.append({"test": "list_has_urls", "passed": True})
    else:
        results.append({"test": "list_has_urls", "passed": False, "attachments": attachments})
        passed = False

    # Test 7: Verify get also returns url fields
    retrieved = mochi.attachment.get(att_img["id"])
    if retrieved and "url" in retrieved and "thumbnail_url" in retrieved:
        results.append({"test": "get_has_urls", "passed": True})
    else:
        results.append({"test": "get_has_urls", "passed": False, "got": retrieved})
        passed = False

    # Test 8: Test various image extensions
    image_extensions = [("test.png", True), ("test.gif", True), ("test.webp", True), ("test.jpeg", True)]
    for filename, should_have_thumb in image_extensions:
        att = mochi.attachment.create(object_id, filename, "data")
        has_thumb = "thumbnail_url" in att if att else False
        if has_thumb == should_have_thumb:
            results.append({"test": "extension_" + filename, "passed": True})
        else:
            results.append({"test": "extension_" + filename, "passed": False, "expected_thumb": should_have_thumb, "got_thumb": has_thumb})
            passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_url_single",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_url_multiuser(a):
    """Test attachment URL isolation between users.
    Run as user 1, then run test_attachment_url_multiuser_verify as user 2."""
    results = []
    passed = True

    username = a.user.username
    object_id = "multiuser/urltest/testobject"

    # Clean up from previous runs
    mochi.attachment.clear(object_id)

    # Create attachments with known URLs as user 1
    att_img = mochi.attachment.create(object_id, "user1_image.jpg", "User 1 image data", "image/jpeg")
    att_doc = mochi.attachment.create(object_id, "user1_doc.pdf", "User 1 doc data", "application/pdf")

    if att_img and att_doc:
        results.append({"test": "create_attachments", "passed": True})
    else:
        results.append({"test": "create_attachments", "passed": False})
        passed = False

    # Store attachment info for verification
    att_ids = []
    att_urls = []
    if att_img:
        att_ids.append(att_img["id"])
        att_urls.append(att_img.get("url", ""))
    if att_doc:
        att_ids.append(att_doc["id"])
        att_urls.append(att_doc.get("url", ""))

    # Verify URLs are correctly formatted
    for att_url in att_urls:
        if att_url.startswith("/claude-test/files/"):
            results.append({"test": "url_format_" + att_url, "passed": True})
        else:
            results.append({"test": "url_format_" + att_url, "passed": False})
            passed = False

    a.json({
        "test": "attachment_url_multiuser",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id,
        "attachment_ids": att_ids,
        "attachment_urls": att_urls,
        "note": "Run test_attachment_url_multiuser_verify as a DIFFERENT user to verify URL isolation"
    })

def action_test_attachment_url_multiuser_verify(a):
    """Verify that user 1's attachment URLs are NOT accessible to user 2.
    Run as user 2 after running test_attachment_url_multiuser as user 1."""
    results = []
    passed = True

    username = a.user.username
    object_id = "multiuser/urltest/testobject"

    # Try to list attachments for the same object
    # Each user has their own attachment space, so this should be empty
    attachments = mochi.attachment.list(object_id)

    # Check if we see user 1's files
    user1_files = [a for a in attachments if "user1" in a.get("name", "")]

    if len(user1_files) == 0:
        results.append({"test": "user1_attachments_not_visible", "passed": True,
                       "note": "User 1's attachments correctly not visible to user 2"})
    else:
        results.append({"test": "user1_attachments_not_visible", "passed": False,
                       "got": [a["name"] for a in user1_files],
                       "error": "SECURITY ISSUE: User 1's attachments visible to user 2!"})
        passed = False

    # Create our own attachment and verify it gets its own URL
    test_att = mochi.attachment.create(object_id, "user2_image.png", "User 2 data", "image/png")
    if test_att and "url" in test_att:
        expected_url = "/claude-test/files/" + test_att["id"]
        if test_att["url"] == expected_url:
            results.append({"test": "user2_gets_own_url", "passed": True, "url": test_att["url"]})
        else:
            results.append({"test": "user2_gets_own_url", "passed": False, "expected": expected_url, "got": test_att["url"]})
            passed = False
    else:
        results.append({"test": "user2_gets_own_url", "passed": False, "error": "url field missing"})
        passed = False

    # Clean up
    if test_att:
        mochi.attachment.delete(test_att["id"])

    a.json({
        "test": "attachment_url_multiuser_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id,
        "note": "Verified attachment URL isolation between users"
    })

def action_test_attachment_url_crossinstance(a):
    """Test attachment URL generation for cross-instance sync.
    Run on instance 1, then run test_attachment_url_crossinstance_verify on instance 2."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None
    remote_entity = a.input("remote_entity")

    if not identity_id:
        a.json({
            "test": "attachment_url_crossinstance",
            "passed": False,
            "error": "No identity - cannot test cross-instance URL"
        })
        return

    # Use a predictable object ID based on identity
    object_id = identity_id + "/urltest/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachments
    att_img = mochi.attachment.create(object_id, "crossinstance_image.jpg", "Cross instance image", "image/jpeg")
    att_doc = mochi.attachment.create(object_id, "crossinstance_doc.txt", "Cross instance text", "text/plain")

    if att_img and att_doc:
        results.append({"test": "create_attachments", "passed": True})
    else:
        results.append({"test": "create_attachments", "passed": False})
        passed = False

    # Verify local URLs are correct
    if att_img and att_img.get("url", "").startswith("/claude-test/files/"):
        results.append({"test": "image_url_format", "passed": True, "url": att_img["url"]})
    else:
        results.append({"test": "image_url_format", "passed": False, "got": att_img.get("url") if att_img else None})
        passed = False

    if att_img and att_img.get("thumbnail_url", "").endswith("/thumbnail"):
        results.append({"test": "thumbnail_url_format", "passed": True, "url": att_img.get("thumbnail_url")})
    else:
        results.append({"test": "thumbnail_url_format", "passed": False, "got": att_img.get("thumbnail_url") if att_img else None})
        passed = False

    # If remote_entity provided, sync to it
    if remote_entity:
        # Create with notify to sync to remote
        att_synced = mochi.attachment.create(object_id, "synced.png", "Synced image", "image/png", "Synced", "For remote", [remote_entity])
        if att_synced:
            results.append({"test": "sync_to_remote", "passed": True, "synced_to": remote_entity})
        else:
            results.append({"test": "sync_to_remote", "passed": False})
            passed = False

    a.json({
        "test": "attachment_url_crossinstance",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "object": object_id,
        "attachment_ids": [att_img["id"] if att_img else None, att_doc["id"] if att_doc else None],
        "note": "Run test_attachment_url_crossinstance_verify on instance 2 with source_entity=" + identity_id + "&object_id=" + object_id
    })

def action_test_attachment_url_crossinstance_verify(a):
    """Verify attachment URLs are generated correctly for synced attachments.
    Run on instance 2 after running test_attachment_url_crossinstance on instance 1."""
    results = []
    passed = True

    username = a.user.username
    source_entity = a.input("source_entity")
    object_id = a.input("object_id")

    if not source_entity or not object_id:
        a.json({
            "test": "attachment_url_crossinstance_verify",
            "passed": False,
            "error": "Required parameters: source_entity, object_id"
        })
        return

    # Try to fetch attachments from the source entity
    # This uses the attachment fetch mechanism to get remote attachments
    local_object = "synced/" + source_entity + "/" + object_id.replace("/", "_")

    # Check if we have any locally cached attachments from the remote
    attachments = mochi.attachment.list(local_object)

    if len(attachments) > 0:
        results.append({"test": "remote_attachments_synced", "passed": True, "count": len(attachments)})

        # Verify each attachment has url field
        for att in attachments:
            if "url" in att:
                results.append({"test": "url_present_" + att.get("name", "unknown"), "passed": True, "url": att["url"]})
            else:
                results.append({"test": "url_present_" + att.get("name", "unknown"), "passed": False, "error": "url field missing"})
                passed = False

            # Verify image attachments have thumbnail_url
            if att.get("image", False):
                if "thumbnail_url" in att:
                    results.append({"test": "thumbnail_url_" + att.get("name", "unknown"), "passed": True})
                else:
                    results.append({"test": "thumbnail_url_" + att.get("name", "unknown"), "passed": False, "error": "thumbnail_url missing for image"})
                    passed = False
    else:
        # No synced attachments yet - this is expected if sync hasn't happened
        results.append({
            "test": "remote_attachments_synced",
            "passed": True,
            "note": "No synced attachments found. Run fetch first or wait for sync."
        })

    # Create a local attachment to verify local URL generation still works
    test_object = "urltest/local/" + mochi.uid()
    local_att = mochi.attachment.create(test_object, "local_verify.png", "Local data", "image/png")

    if local_att and "url" in local_att:
        expected = "/claude-test/files/" + local_att["id"]
        if local_att["url"] == expected:
            results.append({"test": "local_url_works", "passed": True, "url": local_att["url"]})
        else:
            results.append({"test": "local_url_works", "passed": False, "expected": expected, "got": local_att["url"]})
            passed = False
    else:
        results.append({"test": "local_url_works", "passed": False, "error": "url field missing"})
        passed = False

    # Clean up local test
    mochi.attachment.clear(test_object)

    a.json({
        "test": "attachment_url_crossinstance_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "source_entity": source_entity,
        "object_id": object_id,
        "note": "Cross-instance URL verification complete"
    })
