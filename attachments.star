# Mochi Claude Test app: Attachment API Tests
# Single-user tests for attachment CRUD operations

def action_test_attachment_create(a):
    """Test creating attachments from binary data (mochi.attachment.create)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/create/" + mochi.uid()

    # Clean up from previous runs
    mochi.attachment.clear(object_id)

    # Test 1: Create basic attachment with data
    data1 = "Hello, this is test file content!"
    att1 = mochi.attachment.create(object_id, "test1.txt", data1)
    if att1 and att1["name"] == "test1.txt" and att1["size"] == len(data1):
        results.append({"test": "create_basic", "passed": True})
    else:
        results.append({"test": "create_basic", "passed": False, "got": att1})
        passed = False

    # Test 2: Create with content type
    data2 = '{"key": "value"}'
    att2 = mochi.attachment.create(object_id, "data.json", data2, "application/json")
    if att2 and att2["content_type"] == "application/json":
        results.append({"test": "create_with_content_type", "passed": True})
    else:
        results.append({"test": "create_with_content_type", "passed": False, "got": att2})
        passed = False

    # Test 3: Create with caption and description
    data3 = "Image placeholder data"
    att3 = mochi.attachment.create(object_id, "image.png", data3, "image/png", "My Caption", "A detailed description")
    if att3 and att3["caption"] == "My Caption" and att3["description"] == "A detailed description":
        results.append({"test": "create_with_metadata", "passed": True})
    else:
        results.append({"test": "create_with_metadata", "passed": False, "got": att3})
        passed = False

    # Test 4: Verify list shows all attachments
    attachments = mochi.attachment.list(object_id)
    if len(attachments) == 3:
        results.append({"test": "list_count", "passed": True})
    else:
        results.append({"test": "list_count", "passed": False, "got": len(attachments)})
        passed = False

    # Test 5: Verify rank ordering (newer attachments get higher rank)
    ranks = [a["rank"] for a in attachments]
    if ranks == sorted(ranks):
        results.append({"test": "rank_ordering", "passed": True})
    else:
        results.append({"test": "rank_ordering", "passed": False, "got": ranks})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_create",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_insert(a):
    """Test inserting attachments at specific positions (mochi.attachment.insert)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/insert/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create initial attachments (positions are 1-based after creation)
    mochi.attachment.create(object_id, "first.txt", "First file")
    mochi.attachment.create(object_id, "second.txt", "Second file")
    mochi.attachment.create(object_id, "third.txt", "Third file")

    # Test 1: Insert at position 1 (beginning) - positions are 1-based
    att_begin = mochi.attachment.insert(object_id, "new_first.txt", "New first content", 1)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[0] == "new_first.txt":
        results.append({"test": "insert_at_beginning", "passed": True})
    else:
        results.append({"test": "insert_at_beginning", "passed": False, "got": names})
        passed = False

    # Test 2: Insert at position 3 (middle)
    mochi.attachment.insert(object_id, "middle.txt", "Middle content", 3)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[2] == "middle.txt":
        results.append({"test": "insert_at_middle", "passed": True})
    else:
        results.append({"test": "insert_at_middle", "passed": False, "got": names})
        passed = False

    # Test 3: Insert at end (using large position)
    mochi.attachment.insert(object_id, "last.txt", "Last content", 999)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[-1] == "last.txt":
        results.append({"test": "insert_at_end", "passed": True})
    else:
        results.append({"test": "insert_at_end", "passed": False, "got": names})
        passed = False

    # Test 4: Insert with content type and metadata
    mochi.attachment.insert(object_id, "meta.json", "{}", 2, "application/json", "Caption", "Description")
    attachments = mochi.attachment.list(object_id)
    meta_att = [a for a in attachments if a["name"] == "meta.json"]
    if len(meta_att) == 1 and meta_att[0]["content_type"] == "application/json":
        results.append({"test": "insert_with_metadata", "passed": True})
    else:
        results.append({"test": "insert_with_metadata", "passed": False, "got": meta_att})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_insert",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_update(a):
    """Test updating attachment metadata (mochi.attachment.update)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/update/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create an attachment
    att = mochi.attachment.create(object_id, "updateme.txt", "Content to update", "text/plain", "Original Caption", "Original Description")
    att_id = att["id"]

    # Test 1: Update caption only
    mochi.attachment.update(att_id, "New Caption", "Original Description")
    updated = mochi.attachment.get(att_id)
    if updated["caption"] == "New Caption" and updated["description"] == "Original Description":
        results.append({"test": "update_caption", "passed": True})
    else:
        results.append({"test": "update_caption", "passed": False, "got": updated})
        passed = False

    # Test 2: Update description only
    mochi.attachment.update(att_id, "New Caption", "New Description")
    updated = mochi.attachment.get(att_id)
    if updated["description"] == "New Description":
        results.append({"test": "update_description", "passed": True})
    else:
        results.append({"test": "update_description", "passed": False, "got": updated})
        passed = False

    # Test 3: Update both to empty
    mochi.attachment.update(att_id, "", "")
    updated = mochi.attachment.get(att_id)
    if updated["caption"] == "" and updated["description"] == "":
        results.append({"test": "update_to_empty", "passed": True})
    else:
        results.append({"test": "update_to_empty", "passed": False, "got": updated})
        passed = False

    # Test 4: Verify other fields unchanged
    if updated["name"] == "updateme.txt" and updated["content_type"] == "text/plain":
        results.append({"test": "other_fields_unchanged", "passed": True})
    else:
        results.append({"test": "other_fields_unchanged", "passed": False, "got": updated})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_update",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_move(a):
    """Test moving attachments to different positions (mochi.attachment.move)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/move/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachments: a, b, c, d, e
    ids = {}
    for name in ["a.txt", "b.txt", "c.txt", "d.txt", "e.txt"]:
        att = mochi.attachment.create(object_id, name, "Content for " + name)
        ids[name] = att["id"]

    # Test 1: Move "e" to position 1 (beginning) - positions are 1-based
    mochi.attachment.move(ids["e.txt"], 1)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[0] == "e.txt":
        results.append({"test": "move_to_beginning", "passed": True})
    else:
        results.append({"test": "move_to_beginning", "passed": False, "got": names})
        passed = False

    # Test 2: Move "a" to position 3 (middle)
    mochi.attachment.move(ids["a.txt"], 3)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[2] == "a.txt":
        results.append({"test": "move_to_middle", "passed": True})
    else:
        results.append({"test": "move_to_middle", "passed": False, "got": names})
        passed = False

    # Test 3: Move "e" to end (large position)
    mochi.attachment.move(ids["e.txt"], 999)
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if names[-1] == "e.txt":
        results.append({"test": "move_to_end", "passed": True})
    else:
        results.append({"test": "move_to_end", "passed": False, "got": names})
        passed = False

    # Test 4: Move to same position (positions are 1-based)
    initial_order = [a["name"] for a in mochi.attachment.list(object_id)]
    mid_idx = len(initial_order) // 2
    mid_name = initial_order[mid_idx]
    mid_id = ids[mid_name]
    mochi.attachment.move(mid_id, mid_idx + 1)  # 1-based
    after_order = [a["name"] for a in mochi.attachment.list(object_id)]
    if initial_order == after_order:
        results.append({"test": "move_to_same", "passed": True})
    else:
        results.append({"test": "move_to_same", "passed": False, "got": after_order})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_move",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_delete(a):
    """Test deleting individual attachments (mochi.attachment.delete)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/delete/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachments
    att1 = mochi.attachment.create(object_id, "keep1.txt", "Keep this")
    att2 = mochi.attachment.create(object_id, "delete_me.txt", "Delete this")
    att3 = mochi.attachment.create(object_id, "keep2.txt", "Keep this too")

    # Test 1: Delete middle attachment
    mochi.attachment.delete(att2["id"])
    attachments = mochi.attachment.list(object_id)
    names = [a["name"] for a in attachments]
    if "delete_me.txt" not in names and len(attachments) == 2:
        results.append({"test": "delete_one", "passed": True})
    else:
        results.append({"test": "delete_one", "passed": False, "got": names})
        passed = False

    # Test 2: Verify deleted attachment returns None
    deleted = mochi.attachment.get(att2["id"])
    if deleted == None:
        results.append({"test": "get_deleted_returns_none", "passed": True})
    else:
        results.append({"test": "get_deleted_returns_none", "passed": False, "got": deleted})
        passed = False

    # Test 3: Remaining attachments still accessible
    remaining1 = mochi.attachment.get(att1["id"])
    remaining3 = mochi.attachment.get(att3["id"])
    if remaining1 and remaining3:
        results.append({"test": "remaining_accessible", "passed": True})
    else:
        results.append({"test": "remaining_accessible", "passed": False})
        passed = False

    # Test 4: Delete first attachment
    mochi.attachment.delete(att1["id"])
    attachments = mochi.attachment.list(object_id)
    if len(attachments) == 1 and attachments[0]["name"] == "keep2.txt":
        results.append({"test": "delete_first", "passed": True})
    else:
        results.append({"test": "delete_first", "passed": False, "got": [a["name"] for a in attachments]})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_delete",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_clear(a):
    """Test clearing all attachments for an object (mochi.attachment.clear)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/clear/" + mochi.uid()
    other_object_id = "test/attachment/clear/other/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)
    mochi.attachment.clear(other_object_id)

    # Create attachments on main object
    mochi.attachment.create(object_id, "file1.txt", "Content 1")
    mochi.attachment.create(object_id, "file2.txt", "Content 2")
    mochi.attachment.create(object_id, "file3.txt", "Content 3")

    # Create attachments on other object (should not be affected)
    other_att = mochi.attachment.create(other_object_id, "other.txt", "Other content")

    # Test 1: Verify attachments exist
    initial = mochi.attachment.list(object_id)
    if len(initial) == 3:
        results.append({"test": "initial_count", "passed": True})
    else:
        results.append({"test": "initial_count", "passed": False, "got": len(initial)})
        passed = False

    # Test 2: Clear all attachments
    mochi.attachment.clear(object_id)
    after_clear = mochi.attachment.list(object_id)
    if len(after_clear) == 0:
        results.append({"test": "clear_removes_all", "passed": True})
    else:
        results.append({"test": "clear_removes_all", "passed": False, "got": len(after_clear)})
        passed = False

    # Test 3: Other object unaffected
    other_attachments = mochi.attachment.list(other_object_id)
    if len(other_attachments) == 1 and other_attachments[0]["name"] == "other.txt":
        results.append({"test": "other_object_unaffected", "passed": True})
    else:
        results.append({"test": "other_object_unaffected", "passed": False, "got": other_attachments})
        passed = False

    # Test 4: Clear already empty object (should not error)
    mochi.attachment.clear(object_id)
    still_empty = mochi.attachment.list(object_id)
    if len(still_empty) == 0:
        results.append({"test": "clear_empty_ok", "passed": True})
    else:
        results.append({"test": "clear_empty_ok", "passed": False, "got": len(still_empty)})
        passed = False

    # Clean up
    mochi.attachment.clear(other_object_id)

    a.json({
        "test": "attachment_clear",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_get_data_path(a):
    """Test getting attachment by ID, data, and path (mochi.attachment.get/data/path)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/getdatapath/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Create attachment with known content
    original_content = "This is the exact content to verify."
    att = mochi.attachment.create(object_id, "verify.txt", original_content, "text/plain", "Test Caption", "Test Desc")
    att_id = att["id"]

    # Test 1: Get attachment by ID
    retrieved = mochi.attachment.get(att_id)
    if retrieved and retrieved["id"] == att_id and retrieved["name"] == "verify.txt":
        results.append({"test": "get_by_id", "passed": True})
    else:
        results.append({"test": "get_by_id", "passed": False, "got": retrieved})
        passed = False

    # Test 2: Verify all fields present in get()
    expected_fields = ["id", "object", "entity", "name", "size", "content_type", "creator", "caption", "description", "rank", "created"]
    missing = [f for f in expected_fields if f not in retrieved]
    if len(missing) == 0:
        results.append({"test": "all_fields_present", "passed": True})
    else:
        results.append({"test": "all_fields_present", "passed": False, "missing": missing})
        passed = False

    # Test 3: Get attachment data (returns tuple of bytes, convert to string)
    data = mochi.attachment.data(att_id)
    # Convert tuple of bytes to string for comparison
    data_str = "".join([chr(b) for b in data]) if data else None
    if data_str == original_content:
        results.append({"test": "data_matches", "passed": True})
    else:
        results.append({"test": "data_matches", "passed": False, "got_len": len(data) if data else None, "expected_len": len(original_content)})
        passed = False

    # Test 4: Get attachment path
    path = mochi.attachment.path(att_id)
    if path and len(path) > 0:
        results.append({"test": "path_returned", "passed": True})
    else:
        results.append({"test": "path_returned", "passed": False, "got": path})
        passed = False

    # Test 5: Get non-existent attachment
    fake_id = "nonexistent_attachment_id_12345"
    fake_att = mochi.attachment.get(fake_id)
    if fake_att == None:
        results.append({"test": "get_nonexistent", "passed": True})
    else:
        results.append({"test": "get_nonexistent", "passed": False, "got": fake_att})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_get_data_path",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_list(a):
    """Test listing attachments with ordering (mochi.attachment.list)"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/list/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Test 1: List empty object
    empty_list = mochi.attachment.list(object_id)
    if len(empty_list) == 0:
        results.append({"test": "list_empty", "passed": True})
    else:
        results.append({"test": "list_empty", "passed": False, "got": len(empty_list)})
        passed = False

    # Create attachments in order
    names = ["alpha.txt", "beta.txt", "gamma.txt", "delta.txt"]
    for name in names:
        mochi.attachment.create(object_id, name, "Content for " + name)

    # Test 2: List returns all attachments
    all_attachments = mochi.attachment.list(object_id)
    if len(all_attachments) == 4:
        results.append({"test": "list_all", "passed": True})
    else:
        results.append({"test": "list_all", "passed": False, "got": len(all_attachments)})
        passed = False

    # Test 3: List returns attachments ordered by rank
    returned_names = [a["name"] for a in all_attachments]
    if returned_names == names:
        results.append({"test": "list_ordered", "passed": True})
    else:
        results.append({"test": "list_ordered", "passed": False, "expected": names, "got": returned_names})
        passed = False

    # Test 4: Each attachment has required fields
    required_fields = ["id", "name", "size", "content_type", "rank"]
    first_att = all_attachments[0]
    missing = [f for f in required_fields if f not in first_att]
    if len(missing) == 0:
        results.append({"test": "list_has_fields", "passed": True})
    else:
        results.append({"test": "list_has_fields", "passed": False, "missing": missing})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_list",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_crud(a):
    """Combined CRUD test mimicking Chat/Feeds/Forums patterns"""
    results = []
    passed = True

    username = a.user.username

    # Simulate different object patterns from the apps (no underscores allowed in object IDs)
    chat_object = "chat/testchatid/" + mochi.uid()  # Chat pattern
    post_object = "post/" + mochi.uid()  # Feeds/Forums pattern

    # Clean up
    mochi.attachment.clear(chat_object)
    mochi.attachment.clear(post_object)

    # Test 1: Chat-style attachments (multiple files per message)
    mochi.attachment.create(chat_object, "image.jpg", "fake_image_data", "image/jpeg")
    mochi.attachment.create(chat_object, "document.pdf", "fake_pdf_data", "application/pdf")
    chat_attachments = mochi.attachment.list(chat_object)
    if len(chat_attachments) == 2:
        results.append({"test": "chat_pattern", "passed": True})
    else:
        results.append({"test": "chat_pattern", "passed": False, "got": len(chat_attachments)})
        passed = False

    # Test 2: Feeds/Forums-style attachments (files for a post)
    att1 = mochi.attachment.create(post_object, "photo1.jpg", "photo1_data", "image/jpeg", "First photo", "Description 1")
    att2 = mochi.attachment.create(post_object, "photo2.jpg", "photo2_data", "image/jpeg", "Second photo", "Description 2")
    post_attachments = mochi.attachment.list(post_object)
    if len(post_attachments) == 2:
        results.append({"test": "post_pattern", "passed": True})
    else:
        results.append({"test": "post_pattern", "passed": False, "got": len(post_attachments)})
        passed = False

    # Test 3: Update attachment caption (like editing a photo description)
    mochi.attachment.update(att1["id"], "Updated Caption", "Updated Description")
    updated = mochi.attachment.get(att1["id"])
    if updated["caption"] == "Updated Caption":
        results.append({"test": "update_caption", "passed": True})
    else:
        results.append({"test": "update_caption", "passed": False, "got": updated})
        passed = False

    # Test 4: Reorder attachments (like drag-drop reordering) - positions are 1-based
    mochi.attachment.move(att2["id"], 1)
    reordered = mochi.attachment.list(post_object)
    if reordered[0]["name"] == "photo2.jpg":
        results.append({"test": "reorder", "passed": True})
    else:
        results.append({"test": "reorder", "passed": False, "got": [a["name"] for a in reordered]})
        passed = False

    # Test 5: Delete one attachment (like removing a photo from post)
    mochi.attachment.delete(att1["id"])
    after_delete = mochi.attachment.list(post_object)
    if len(after_delete) == 1 and after_delete[0]["name"] == "photo2.jpg":
        results.append({"test": "delete_one", "passed": True})
    else:
        results.append({"test": "delete_one", "passed": False, "got": [a["name"] for a in after_delete]})
        passed = False

    # Test 6: Clear all (like deleting a message/post)
    mochi.attachment.clear(chat_object)
    cleared = mochi.attachment.list(chat_object)
    if len(cleared) == 0:
        results.append({"test": "clear_all", "passed": True})
    else:
        results.append({"test": "clear_all", "passed": False, "got": len(cleared)})
        passed = False

    # Clean up
    mochi.attachment.clear(post_object)

    a.json({
        "test": "attachment_crud",
        "passed": passed,
        "results": results,
        "username": username,
        "note": "Combined CRUD test mimicking Chat/Feeds/Forums patterns"
    })

def action_test_attachment_binary(a):
    """Test binary data handling in attachments"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/binary/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Test 1: Create with various data sizes
    small_data = "X"
    att_small = mochi.attachment.create(object_id, "small.bin", small_data)
    if att_small["size"] == 1:
        results.append({"test": "small_size", "passed": True})
    else:
        results.append({"test": "small_size", "passed": False, "got": att_small["size"]})
        passed = False

    # Test 2: Medium data (1KB)
    medium_data = "M" * 1024
    att_medium = mochi.attachment.create(object_id, "medium.bin", medium_data)
    if att_medium["size"] == 1024:
        results.append({"test": "medium_size", "passed": True})
    else:
        results.append({"test": "medium_size", "passed": False, "got": att_medium["size"]})
        passed = False

    # Test 3: Larger data (100KB)
    large_data = "L" * (100 * 1024)
    att_large = mochi.attachment.create(object_id, "large.bin", large_data)
    if att_large["size"] == 100 * 1024:
        results.append({"test": "large_size", "passed": True})
    else:
        results.append({"test": "large_size", "passed": False, "got": att_large["size"]})
        passed = False

    # Test 4: Verify data integrity (convert tuple of bytes to string)
    retrieved = mochi.attachment.data(att_medium["id"])
    retrieved_str = "".join([chr(b) for b in retrieved]) if retrieved else None
    if retrieved_str == medium_data:
        results.append({"test": "data_integrity", "passed": True})
    else:
        results.append({"test": "data_integrity", "passed": False, "match": retrieved_str == medium_data})
        passed = False

    # Test 5: Empty data
    empty_data = ""
    att_empty = mochi.attachment.create(object_id, "empty.bin", empty_data)
    if att_empty["size"] == 0:
        results.append({"test": "empty_size", "passed": True})
    else:
        results.append({"test": "empty_size", "passed": False, "got": att_empty["size"]})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_binary",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

def action_test_attachment_content_types(a):
    """Test various content types"""
    results = []
    passed = True

    username = a.user.username
    object_id = "test/attachment/contenttypes/" + mochi.uid()

    # Clean up
    mochi.attachment.clear(object_id)

    # Test various content types
    content_types = [
        ("text.txt", "text/plain"),
        ("doc.html", "text/html"),
        ("data.json", "application/json"),
        ("photo.jpg", "image/jpeg"),
        ("photo.png", "image/png"),
        ("video.mp4", "video/mp4"),
        ("audio.mp3", "audio/mpeg"),
        ("archive.zip", "application/zip"),
        ("doc.pdf", "application/pdf"),
    ]

    for name, content_type in content_types:
        att = mochi.attachment.create(object_id, name, "test content", content_type)
        if att["content_type"] == content_type:
            results.append({"test": "type_" + name, "passed": True})
        else:
            results.append({"test": "type_" + name, "passed": False, "expected": content_type, "got": att["content_type"]})
            passed = False

    # Test default content type (when not specified)
    att_default = mochi.attachment.create(object_id, "unknown.xyz", "test content")
    if att_default and "content_type" in att_default:
        results.append({"test": "default_type", "passed": True, "got": att_default["content_type"]})
    else:
        results.append({"test": "default_type", "passed": False})
        passed = False

    # Clean up
    mochi.attachment.clear(object_id)

    a.json({
        "test": "attachment_content_types",
        "passed": passed,
        "results": results,
        "username": username,
        "object": object_id
    })

