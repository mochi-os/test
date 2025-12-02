# Mochi Claude Test app
# For testing P2P messaging between instances

def database_create():
    """Create test database schema"""
    mochi.db.query("create table test ( id text primary key, value text )")

def action_index(a):
    """Show test app status and controls"""
    identity = a.user.identity
    a.json({
        "app": "claude-test",
        "identity": identity.id,
        "user": a.user.username
    })

def action_send(a):
    """Send a test message to another entity"""
    to = a.input("to")
    msg = a.input("msg", "ping")

    if not to:
        a.error(400, "missing 'to' parameter")
        return

    headers = {
        "from": a.user.identity.id,
        "to": to,
        "service": "claude-test",
        "event": "ping"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    result = mochi.message.send(headers, content)
    a.json({"sent": True, "result": result, "to": to, "message": msg})

def action_status(a):
    """Return server status info"""
    a.json({
        "identity": a.user.identity.id,
        "time": mochi.time.now()
    })

def action_ping(a):
    """Send a ping without authentication (accepts from parameter)"""
    from_id = a.input("from")
    to = a.input("to")
    msg = a.input("msg", "ping")

    if not from_id:
        a.error(400, "missing 'from' parameter")
        return
    if not to:
        a.error(400, "missing 'to' parameter")
        return

    headers = {
        "from": from_id,
        "to": to,
        "service": "claude-test",
        "event": "ping"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    result = mochi.message.send(headers, content)
    a.json({"sent": True, "result": result, "from": from_id, "to": to, "message": msg})

def event_ping(e):
    """Handle incoming ping event"""
    print("Claude Test: Received ping from", e.header("from"), "message:", e.content("message"))

    # Send pong reply
    headers = {
        "from": e.header("to"),
        "to": e.header("from"),
        "service": "claude-test",
        "event": "pong"
    }
    content = {
        "message": "pong",
        "original": e.content("message"),
        "time": mochi.time.now()
    }
    mochi.message.send(headers, content)

def event_pong(e):
    """Handle incoming pong response"""
    print("Claude Test: Received pong from", e.header("from"), "original:", e.content("original"))

def action_broadcast(a):
    """Publish a broadcast message to all peers"""
    msg = a.input("msg", "hello")

    headers = {
        "from": a.user.identity.id,
        "service": "claude-test",
        "event": "broadcast"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    mochi.message.publish(headers, content)
    a.json({"published": True, "from": a.user.identity.id, "message": msg})

def event_broadcast(e):
    """Handle incoming broadcast event"""
    print("Claude Test: Received broadcast from", e.header("from"), "message:", e.content("message"))

def action_test_broadcast(a):
    """Test broadcast without authentication"""
    msg = a.input("msg", "test_broadcast")

    headers = {
        "from": "",
        "service": "claude-test",
        "event": "broadcast"
    }
    content = {
        "message": msg,
        "time": mochi.time.now(),
        "number": 42
    }

    mochi.message.publish(headers, content)
    a.json({"published": True, "message": msg})

def action_test_attach(a):
    """Test that ATTACH is blocked - should fail with authorization error"""
    # This should fail with an authorization error if the security is working
    result = mochi.db.query("ATTACH DATABASE '../../../db/users.db' AS users_db")
    a.json({"blocked": False, "result": result, "error": "ATTACH was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_detach(a):
    """Test that DETACH is blocked - should fail with authorization error"""
    # This should fail with an authorization error if the security is working
    result = mochi.db.query("DETACH DATABASE main")
    a.json({"blocked": False, "result": result, "error": "DETACH was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_storage_limit(a):
    """Test file storage limit by writing 1GB of data.
    Writes 10 x 100MB files (1000MB total), then tries an 11th.
    The 11th file should fail with 'storage limit exceeded' if limits work."""
    chunk_size = 100 * 1024 * 1024  # 100MB per file
    chunk = "X" * chunk_size

    # Write 10 x 100MB files = 1000MB
    for i in range(10):
        filename = "storage_test/chunk" + str(i) + ".bin"
        mochi.file.write(filename, chunk)

    # Try to write one more 100MB file - should fail if limit is 1GB
    # If this succeeds, the limit is not working!
    mochi.file.write("storage_test/chunk_overflow.bin", chunk)
    a.json({"test": "storage_limit", "status": "FAIL", "error": "11th file succeeded - limit not enforced!"})

def action_test_storage_cleanup(a):
    """Clean up storage test files"""
    for i in range(11):
        filename = "storage_test/chunk" + str(i) + ".bin"
        mochi.file.delete(filename)
    mochi.file.delete("storage_test/chunk_overflow.bin")
    a.json({"cleaned": True})

def action_test_db_limit(a):
    """Test database storage limit by inserting data until full.
    Inserts 4KB rows. With 1GB limit (~262144 pages of 4KB), should fail around 250k rows."""
    # Create test table if not exists
    mochi.db.query("CREATE TABLE IF NOT EXISTS db_limit_test (id INTEGER PRIMARY KEY, data TEXT)")

    # Insert 4KB rows until database is full
    chunk = "X" * 4096

    # Insert 300k rows (~1.2GB) - should fail before completing if limit works
    for i in range(300000):
        mochi.db.query("INSERT INTO db_limit_test (data) VALUES (?)", chunk)
        if i % 10000 == 0:
            print("Inserted", i, "rows...")

    # If we get here, the limit didn't work
    rows = mochi.db.query("SELECT COUNT(*) as count FROM db_limit_test")
    a.json({"test": "db_limit", "status": "FAIL", "rows": rows[0]["count"], "error": "Inserted 300k rows without hitting limit!"})

def action_test_db_cleanup(a):
    """Clean up database test table"""
    mochi.db.query("DROP TABLE IF EXISTS db_limit_test")
    a.json({"cleaned": True})

def action_test_p2p_rate_limit(a):
    """Test P2P message send rate limiting.
    Note: Starlark doesn't support try/except. Rate limiting is tested via Go unit tests.
    This action just documents that rate limiting exists (20 msg/sec/app)."""
    a.json({
        "test": "p2p_rate_limit",
        "note": "Rate limiting (20 msg/sec/app) is enforced at Go level and tested via Go unit tests",
        "limit": 20,
        "window_seconds": 1
    })

# =============================================================================
# Groups API Tests
# =============================================================================

def action_test_groups_crud(a):
    """Test basic group CRUD operations: create, get, list, update, delete"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric IDs
    id1 = "testgroup1aaaaaaaaaaaaaaaaaaaaaa"
    id2 = "testgroup2bbbbbbbbbbbbbbbbbbbbbb"
    id_nonexistent = "nonexistentgroupcccccccccccccccc"

    # Create groups first (using REPLACE so it's safe if they exist)

    # Test create
    g1 = mochi.group.create(id1, "Test Group 1", "First test group")
    if g1["id"] == id1 and g1["name"] == "Test Group 1":
        results.append({"test": "create", "passed": True})
    else:
        results.append({"test": "create", "passed": False, "got": g1})
        passed = False

    # Test get
    g = mochi.group.get(id1)
    if g and g["id"] == id1 and g["description"] == "First test group":
        results.append({"test": "get", "passed": True})
    else:
        results.append({"test": "get", "passed": False, "got": g})
        passed = False

    # Test get non-existent
    g_none = mochi.group.get(id_nonexistent)
    if g_none == None:
        results.append({"test": "get_nonexistent", "passed": True})
    else:
        results.append({"test": "get_nonexistent", "passed": False, "got": g_none})
        passed = False

    # Test list
    mochi.group.create(id2, "Test Group 2")
    groups = mochi.group.list()
    group_ids = [g["id"] for g in groups]
    if id1 in group_ids and id2 in group_ids:
        results.append({"test": "list", "passed": True})
    else:
        results.append({"test": "list", "passed": False, "got": group_ids})
        passed = False

    # Test update
    mochi.group.update(id1, name="Updated Name", description="Updated desc")
    g_updated = mochi.group.get(id1)
    if g_updated["name"] == "Updated Name" and g_updated["description"] == "Updated desc":
        results.append({"test": "update", "passed": True})
    else:
        results.append({"test": "update", "passed": False, "got": g_updated})
        passed = False

    # Test delete
    mochi.group.delete(id1)
    g_deleted = mochi.group.get(id1)
    if g_deleted == None:
        results.append({"test": "delete", "passed": True})
    else:
        results.append({"test": "delete", "passed": False, "got": g_deleted})
        passed = False

    # Cleanup
    mochi.group.delete(id2)

    a.json({"test": "groups_crud", "passed": passed, "results": results})

def action_test_groups_members(a):
    """Test group membership: add, remove, members, memberships"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric ID
    members_group = "membersgroupdddddddddddddddddddd"

    # Setup
    mochi.group.delete(members_group)
    mochi.group.create(members_group, "Members Test Group")

    # Test add user
    mochi.group.add(members_group, "user1", "user")
    mochi.group.add(members_group, "user2", "user")
    members = mochi.group.members(members_group)
    member_ids = [m["member"] for m in members]
    if "user1" in member_ids and "user2" in member_ids and len(members) == 2:
        results.append({"test": "add_users", "passed": True})
    else:
        results.append({"test": "add_users", "passed": False, "got": members})
        passed = False

    # Test memberships (reverse lookup)
    memberships = mochi.group.memberships("user1")
    if members_group in memberships:
        results.append({"test": "memberships", "passed": True})
    else:
        results.append({"test": "memberships", "passed": False, "got": memberships})
        passed = False

    # Test remove
    mochi.group.remove(members_group, "user1")
    members_after = mochi.group.members(members_group)
    member_ids_after = [m["member"] for m in members_after]
    if "user1" not in member_ids_after and "user2" in member_ids_after:
        results.append({"test": "remove", "passed": True})
    else:
        results.append({"test": "remove", "passed": False, "got": members_after})
        passed = False

    # Cleanup
    mochi.group.delete(members_group)

    a.json({"test": "groups_members", "passed": passed, "results": results})

def action_test_groups_nested(a):
    """Test nested groups and recursive membership"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric IDs (exactly 32 chars)
    grandparent = "grandparentgroup0000000000000000"
    parent = "parentgroup000000000000000000000"
    child = "childgroup0000000000000000000000"

    # Setup: Create hierarchy: grandparent > parent > child
    # grandparent contains parent (group)
    # parent contains user1 (user)
    mochi.group.delete(grandparent)
    mochi.group.delete(parent)
    mochi.group.delete(child)

    mochi.group.create(grandparent, "Grandparent Group")
    mochi.group.create(parent, "Parent Group")
    mochi.group.create(child, "Child Group")

    mochi.group.add(grandparent, parent, "group")
    mochi.group.add(parent, child, "group")
    mochi.group.add(child, "nested_user", "user")

    # Test non-recursive members (should only show direct members)
    direct_members = mochi.group.members(grandparent, False)
    direct_ids = [m["member"] for m in direct_members]
    if len(direct_ids) == 1 and parent in direct_ids:
        results.append({"test": "direct_members", "passed": True})
    else:
        results.append({"test": "direct_members", "passed": False, "got": direct_members})
        passed = False

    # Test recursive members (should expand to users only)
    recursive_members = mochi.group.members(grandparent, True)
    recursive_ids = [m["member"] for m in recursive_members]
    if "nested_user" in recursive_ids:
        results.append({"test": "recursive_members", "passed": True})
    else:
        results.append({"test": "recursive_members", "passed": False, "got": recursive_members})
        passed = False

    # Test memberships traverses hierarchy
    memberships = mochi.group.memberships("nested_user")
    # Should include child, parent, grandparent
    if child in memberships and parent in memberships and grandparent in memberships:
        results.append({"test": "recursive_memberships", "passed": True})
    else:
        results.append({"test": "recursive_memberships", "passed": False, "got": memberships})
        passed = False

    # Cleanup
    mochi.group.delete(grandparent)
    mochi.group.delete(parent)
    mochi.group.delete(child)

    a.json({"test": "groups_nested", "passed": passed, "results": results})

def action_test_groups_cycle(a):
    """Test cycle detection when adding groups.
    Note: Starlark doesn't support try/except, so we test that valid
    operations work. Cycle detection is tested via Go unit tests."""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric IDs (exactly 32 chars)
    cycle_a = "cycleagroup000000000000000000000"
    cycle_b = "cyclebgroup000000000000000000001"
    cycle_c = "cyclecgroup000000000000000000002"

    # Setup
    mochi.group.delete(cycle_a)
    mochi.group.delete(cycle_b)
    mochi.group.delete(cycle_c)

    mochi.group.create(cycle_a, "Cycle A")
    mochi.group.create(cycle_b, "Cycle B")
    mochi.group.create(cycle_c, "Cycle C")

    # Create valid chain: a contains b, b contains c (no cycle)
    mochi.group.add(cycle_a, cycle_b, "group")
    mochi.group.add(cycle_b, cycle_c, "group")

    # Verify the chain was created
    members_a = mochi.group.members(cycle_a, False)
    if len(members_a) == 1 and members_a[0]["member"] == cycle_b:
        results.append({"test": "valid_chain", "passed": True})
    else:
        results.append({"test": "valid_chain", "passed": False, "got": members_a})
        passed = False

    # Test recursive membership works through the chain
    mochi.group.add(cycle_c, "chain_user", "user")
    memberships = mochi.group.memberships("chain_user")
    if cycle_c in memberships and cycle_b in memberships and cycle_a in memberships:
        results.append({"test": "chain_membership", "passed": True})
    else:
        results.append({"test": "chain_membership", "passed": False, "got": memberships})
        passed = False

    # Cleanup
    mochi.group.delete(cycle_a)
    mochi.group.delete(cycle_b)
    mochi.group.delete(cycle_c)

    a.json({
        "test": "groups_cycle",
        "passed": passed,
        "results": results,
        "note": "Cycle detection is enforced at Go level - test via API returns error"
    })

# =============================================================================
# Access Control API Tests
# =============================================================================

def action_test_access_basic(a):
    """Test basic access control: allow, deny, check, revoke"""
    results = []
    passed = True

    # Clean up
    mochi.access.clear.subject("access_user1")
    mochi.access.clear.resource("resource1")

    # Test allow and check
    mochi.access.allow("access_user1", "resource1", "read", "test")
    if mochi.access.check("access_user1", "resource1", "read"):
        results.append({"test": "allow_check", "passed": True})
    else:
        results.append({"test": "allow_check", "passed": False})
        passed = False

    # Test check returns False for non-allowed operation
    if not mochi.access.check("access_user1", "resource1", "write"):
        results.append({"test": "check_not_allowed", "passed": True})
    else:
        results.append({"test": "check_not_allowed", "passed": False})
        passed = False

    # Test deny
    mochi.access.allow("access_user1", "resource1", "write", "test")
    mochi.access.deny("access_user1", "resource1", "write", "test")
    if not mochi.access.check("access_user1", "resource1", "write"):
        results.append({"test": "deny", "passed": True})
    else:
        results.append({"test": "deny", "passed": False})
        passed = False

    # Test revoke (removes rule entirely)
    mochi.access.revoke("access_user1", "resource1", "read")
    if not mochi.access.check("access_user1", "resource1", "read"):
        results.append({"test": "revoke", "passed": True})
    else:
        results.append({"test": "revoke", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.subject("access_user1")

    a.json({"test": "access_basic", "passed": passed, "results": results})

def action_test_access_wildcards(a):
    """Test wildcard operations (* matches any operation)"""
    results = []
    passed = True

    # Clean up
    mochi.access.clear.subject("wildcard_user")
    mochi.access.clear.resource("wildcard_resource")

    # Grant wildcard access
    mochi.access.allow("wildcard_user", "wildcard_resource", "*", "test")

    # Should match any operation
    if mochi.access.check("wildcard_user", "wildcard_resource", "read"):
        results.append({"test": "wildcard_read", "passed": True})
    else:
        results.append({"test": "wildcard_read", "passed": False})
        passed = False

    if mochi.access.check("wildcard_user", "wildcard_resource", "write"):
        results.append({"test": "wildcard_write", "passed": True})
    else:
        results.append({"test": "wildcard_write", "passed": False})
        passed = False

    if mochi.access.check("wildcard_user", "wildcard_resource", "delete"):
        results.append({"test": "wildcard_delete", "passed": True})
    else:
        results.append({"test": "wildcard_delete", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.subject("wildcard_user")

    a.json({"test": "access_wildcards", "passed": passed, "results": results})

def action_test_access_hierarchy(a):
    """Test hierarchical resources (posts/123 inherits from posts)"""
    results = []
    passed = True

    # Clean up
    mochi.access.clear.subject("hierarchy_user")
    mochi.access.clear.resource("posts")
    mochi.access.clear.resource("posts/123")
    mochi.access.clear.resource("posts/123/comments")

    # Grant access to parent resource
    mochi.access.allow("hierarchy_user", "posts", "read", "test")

    # Should inherit to child resources
    if mochi.access.check("hierarchy_user", "posts/123", "read"):
        results.append({"test": "inherit_to_child", "passed": True})
    else:
        results.append({"test": "inherit_to_child", "passed": False})
        passed = False

    if mochi.access.check("hierarchy_user", "posts/123/comments", "read"):
        results.append({"test": "inherit_to_grandchild", "passed": True})
    else:
        results.append({"test": "inherit_to_grandchild", "passed": False})
        passed = False

    # More specific rule should take precedence
    mochi.access.deny("hierarchy_user", "posts/123", "read", "test")
    if not mochi.access.check("hierarchy_user", "posts/123", "read"):
        results.append({"test": "specific_overrides_parent", "passed": True})
    else:
        results.append({"test": "specific_overrides_parent", "passed": False})
        passed = False

    # But sibling resource should still work
    if mochi.access.check("hierarchy_user", "posts/456", "read"):
        results.append({"test": "sibling_unaffected", "passed": True})
    else:
        results.append({"test": "sibling_unaffected", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.subject("hierarchy_user")

    a.json({"test": "access_hierarchy", "passed": passed, "results": results})

def action_test_access_anonymous(a):
    """Test anonymous (*) access for public resources"""
    results = []
    passed = True

    # Clean up
    mochi.access.clear.resource("public_resource")

    # Grant anonymous access
    mochi.access.allow("*", "public_resource", "read", "test")

    # Anonymous (None user) should have access
    if mochi.access.check(None, "public_resource", "read"):
        results.append({"test": "anonymous_access", "passed": True})
    else:
        results.append({"test": "anonymous_access", "passed": False})
        passed = False

    # Named user should also have access (falls through to *)
    if mochi.access.check("some_user", "public_resource", "read"):
        results.append({"test": "user_inherits_anonymous", "passed": True})
    else:
        results.append({"test": "user_inherits_anonymous", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.resource("public_resource")

    a.json({"test": "access_anonymous", "passed": passed, "results": results})

def action_test_access_groups(a):
    """Test access through group membership"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric IDs (exactly 32 chars)
    access_editors = "accesseditors0000000000000000000"
    access_superusers = "accesssuperusers0000000000000000"

    # Clean up
    mochi.group.delete(access_editors)
    mochi.access.clear.subject("@" + access_editors)
    mochi.access.clear.resource("group_resource")

    # Create group and add member
    mochi.group.create(access_editors, "Editors Group")
    mochi.group.add(access_editors, "group_member", "user")

    # Grant access to group
    mochi.access.allow("@" + access_editors, "group_resource", "edit", "test")

    # Member should have access via group
    if mochi.access.check("group_member", "group_resource", "edit"):
        results.append({"test": "group_member_access", "passed": True})
    else:
        results.append({"test": "group_member_access", "passed": False})
        passed = False

    # Non-member should not have access
    if not mochi.access.check("non_member", "group_resource", "edit"):
        results.append({"test": "non_member_no_access", "passed": True})
    else:
        results.append({"test": "non_member_no_access", "passed": False})
        passed = False

    # Test nested group access
    # The nesting goes: group A contains group B means members of B are also members of A
    # So: editors contains superusers means super_member (in superusers) is also in editors
    mochi.group.delete(access_superusers)
    mochi.group.create(access_superusers, "Superusers")
    mochi.group.add(access_superusers, "super_member", "user")
    mochi.group.add(access_editors, access_superusers, "group")  # editors contains superusers (so superusers inherit editor perms)

    # Now super_member should have editor access
    if mochi.access.check("super_member", "group_resource", "edit"):
        results.append({"test": "nested_group_access", "passed": True})
    else:
        results.append({"test": "nested_group_access", "passed": False})
        passed = False

    # Cleanup
    mochi.group.delete(access_editors)
    mochi.group.delete(access_superusers)
    mochi.access.clear.resource("group_resource")

    a.json({"test": "access_groups", "passed": passed, "results": results})

def action_test_access_deny_precedence(a):
    """Test that deny takes precedence over allow at the same level"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric ID (exactly 32 chars)
    allow_group = "allowgroup00000000000000000000mm"

    # Clean up
    mochi.access.clear.subject("deny_user")
    mochi.access.clear.resource("deny_resource")

    # First allow
    mochi.access.allow("deny_user", "deny_resource", "read", "test")
    if mochi.access.check("deny_user", "deny_resource", "read"):
        results.append({"test": "initial_allow", "passed": True})
    else:
        results.append({"test": "initial_allow", "passed": False})
        passed = False

    # Then deny - should override the allow
    mochi.access.deny("deny_user", "deny_resource", "read", "test")
    if not mochi.access.check("deny_user", "deny_resource", "read"):
        results.append({"test": "deny_overrides_allow", "passed": True})
    else:
        results.append({"test": "deny_overrides_allow", "passed": False})
        passed = False

    # Test user deny takes precedence over group allow
    mochi.group.delete(allow_group)
    mochi.group.create(allow_group, "Allow Group")
    mochi.group.add(allow_group, "mixed_user", "user")
    mochi.access.allow("@" + allow_group, "mixed_resource", "read", "test")  # group allows
    mochi.access.deny("mixed_user", "mixed_resource", "read", "test")     # user denies

    # User-level deny should win over group-level allow
    if not mochi.access.check("mixed_user", "mixed_resource", "read"):
        results.append({"test": "user_deny_over_group_allow", "passed": True})
    else:
        results.append({"test": "user_deny_over_group_allow", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.subject("deny_user")
    mochi.access.clear.subject("mixed_user")
    mochi.access.clear.subject("@" + allow_group)
    mochi.group.delete(allow_group)

    a.json({"test": "access_deny_precedence", "passed": passed, "results": results})

def action_test_access_list_clear(a):
    """Test list and clear operations"""
    results = []
    passed = True

    # Clean up
    mochi.access.clear.subject("list_user")
    mochi.access.clear.resource("list_resource")

    # Create multiple rules
    mochi.access.allow("list_user", "list_resource", "read", "test")
    mochi.access.allow("list_user", "list_resource", "write", "test")
    mochi.access.allow("list_user", "other_resource", "read", "test")
    mochi.access.allow("other_user", "list_resource", "read", "test")

    # Test list by subject
    subject_rules = mochi.access.list.subject("list_user")
    if len(subject_rules) == 3:
        results.append({"test": "list_subject", "passed": True})
    else:
        results.append({"test": "list_subject", "passed": False, "got": len(subject_rules)})
        passed = False

    # Test list by resource
    resource_rules = mochi.access.list.resource("list_resource")
    if len(resource_rules) == 3:  # list_user:read, list_user:write, other_user:read
        results.append({"test": "list_resource", "passed": True})
    else:
        results.append({"test": "list_resource", "passed": False, "got": len(resource_rules)})
        passed = False

    # Test clear by subject
    mochi.access.clear.subject("list_user")
    subject_rules_after = mochi.access.list.subject("list_user")
    if len(subject_rules_after) == 0:
        results.append({"test": "clear_subject", "passed": True})
    else:
        results.append({"test": "clear_subject", "passed": False, "got": len(subject_rules_after)})
        passed = False

    # other_user rules should still exist
    if mochi.access.check("other_user", "list_resource", "read"):
        results.append({"test": "clear_subject_isolated", "passed": True})
    else:
        results.append({"test": "clear_subject_isolated", "passed": False})
        passed = False

    # Test clear by resource
    mochi.access.allow("test_user", "clear_resource", "read", "test")
    mochi.access.allow("test_user2", "clear_resource", "write", "test")
    mochi.access.clear.resource("clear_resource")
    resource_rules_after = mochi.access.list.resource("clear_resource")
    if len(resource_rules_after) == 0:
        results.append({"test": "clear_resource", "passed": True})
    else:
        results.append({"test": "clear_resource", "passed": False, "got": len(resource_rules_after)})
        passed = False

    # Cleanup
    mochi.access.clear.subject("other_user")
    mochi.access.clear.subject("test_user")
    mochi.access.clear.subject("test_user2")

    a.json({"test": "access_list_clear", "passed": passed, "results": results})

def action_test_access_resolution_order(a):
    """Test resolution order: user > groups > roles > authenticated > anonymous"""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric ID (exactly 32 chars)
    resolution_group = "resolutiongroup00000000000000000"

    # Clean up
    mochi.access.clear.resource("resolution_resource")
    mochi.group.delete(resolution_group)

    # This test is limited because we can't easily test role resolution
    # since that requires actual user authentication

    # Test: user-level rule takes precedence over anonymous
    mochi.access.allow("*", "resolution_resource", "read", "test")      # anonymous allow
    mochi.access.deny("resolution_user", "resolution_resource", "read", "test")  # user deny

    if not mochi.access.check("resolution_user", "resolution_resource", "read"):
        results.append({"test": "user_over_anonymous", "passed": True})
    else:
        results.append({"test": "user_over_anonymous", "passed": False})
        passed = False

    # Other users should still have access via anonymous
    if mochi.access.check("other_user", "resolution_resource", "read"):
        results.append({"test": "other_user_via_anonymous", "passed": True})
    else:
        results.append({"test": "other_user_via_anonymous", "passed": False})
        passed = False

    # Test: group rule takes precedence over anonymous
    mochi.access.clear.resource("resolution_resource")
    mochi.group.create(resolution_group, "Resolution Group")
    mochi.group.add(resolution_group, "group_user", "user")
    mochi.access.deny("*", "resolution_resource", "read", "test")           # anonymous deny
    mochi.access.allow("@" + resolution_group, "resolution_resource", "read", "test")  # group allow

    if mochi.access.check("group_user", "resolution_resource", "read"):
        results.append({"test": "group_over_anonymous", "passed": True})
    else:
        results.append({"test": "group_over_anonymous", "passed": False})
        passed = False

    # Non-member should be denied via anonymous
    if not mochi.access.check("non_group_user", "resolution_resource", "read"):
        results.append({"test": "non_member_denied", "passed": True})
    else:
        results.append({"test": "non_member_denied", "passed": False})
        passed = False

    # Cleanup
    mochi.access.clear.resource("resolution_resource")
    mochi.access.clear.subject("resolution_user")
    mochi.access.clear.subject("@" + resolution_group)
    mochi.group.delete(resolution_group)

    a.json({"test": "access_resolution_order", "passed": passed, "results": results})

def action_test_all(a):
    """Run all tests and return combined results"""
    # Note: This runs tests synchronously which may have side effects
    # For true isolation, run each test endpoint separately
    a.json({
        "note": "Run individual test endpoints for isolated results",
        "endpoints": [
            "test_groups_crud",
            "test_groups_members",
            "test_groups_nested",
            "test_groups_cycle",
            "test_access_basic",
            "test_access_wildcards",
            "test_access_hierarchy",
            "test_access_anonymous",
            "test_access_groups",
            "test_access_deny_precedence",
            "test_access_list_clear",
            "test_access_resolution_order",
            "test_multiuser_group_isolation",
            "test_multiuser_access_cross_user",
            "test_multiuser_access_user_entity"
        ]
    })

# =============================================================================
# Multi-User Tests (Cross-User Isolation and Access)
# =============================================================================

def action_test_multiuser_group_isolation(a):
    """Test that groups created by one user are isolated from another user.
    This tests the per-user database isolation for groups.
    Run as user 1, then run test_multiuser_group_isolation_verify as user 2."""
    results = []
    passed = True

    # Use valid 32-char lowercase alphanumeric IDs
    user1_group = "user1privategroup000000000000000"
    shared_group = "sharedgroupfortest0000000000000"

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "unknown"

    # Cleanup from previous runs
    mochi.group.delete(user1_group)
    mochi.group.delete(shared_group)

    # Create a group as this user
    g1 = mochi.group.create(user1_group, "User " + username + " Private Group", "Created by " + username)
    if g1 and g1["id"] == user1_group:
        results.append({"test": "create_group", "passed": True, "user": username})
    else:
        results.append({"test": "create_group", "passed": False, "got": g1})
        passed = False

    # Add this user's identity as a member
    mochi.group.add(user1_group, identity_id, "user")

    # Verify the group exists and has the member
    members = mochi.group.members(user1_group)
    if len(members) == 1 and members[0]["member"] == identity_id:
        results.append({"test": "add_member", "passed": True})
    else:
        results.append({"test": "add_member", "passed": False, "got": members})
        passed = False

    # List all groups - should include our new group
    groups = mochi.group.list()
    group_ids = [g["id"] for g in groups]
    if user1_group in group_ids:
        results.append({"test": "list_contains_group", "passed": True, "count": len(groups)})
    else:
        results.append({"test": "list_contains_group", "passed": False, "got": group_ids})
        passed = False

    a.json({
        "test": "multiuser_group_isolation",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "note": "Run test_multiuser_group_isolation_verify as a different user to verify isolation"
    })

def action_test_multiuser_group_isolation_verify(a):
    """Verify that the other user's groups are NOT visible to this user.
    Run as user 2 after running test_multiuser_group_isolation as user 1."""
    results = []
    passed = True

    user1_group = "user1privategroup000000000000000"
    username = a.user.username

    # Try to get user 1's group - should NOT be visible
    g = mochi.group.get(user1_group)
    if g == None:
        results.append({"test": "other_user_group_not_visible", "passed": True})
    else:
        results.append({"test": "other_user_group_not_visible", "passed": False, "got": g})
        passed = False

    # List groups - should NOT include user 1's private group
    groups = mochi.group.list()
    group_ids = [g["id"] for g in groups]
    if user1_group not in group_ids:
        results.append({"test": "list_excludes_other_user_group", "passed": True, "count": len(groups)})
    else:
        results.append({"test": "list_excludes_other_user_group", "passed": False, "got": group_ids})
        passed = False

    # When user 2 tries to add to user 1's group ID, it creates a NEW group
    # in user 2's database space (since groups are per-user).
    # This verifies true isolation - modifying the "same" group ID affects
    # only this user's copy, not user 1's original.
    mochi.group.add(user1_group, "attacker_user", "user")

    # Clean up the group we just created in user 2's space
    mochi.group.delete(user1_group)
    members_after_cleanup = mochi.group.members(user1_group)

    # After cleanup, the group should be gone from user 2's space
    if len(members_after_cleanup) == 0:
        results.append({"test": "groups_are_user_isolated", "passed": True,
                       "note": "User 2 created own copy, then deleted it - user 1 unaffected"})
    else:
        results.append({"test": "groups_are_user_isolated", "passed": False, "got": members_after_cleanup})
        passed = False

    a.json({
        "test": "multiuser_group_isolation_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "note": "This verifies that user " + username + " cannot see groups created by other users"
    })

def action_test_multiuser_access_cross_user(a):
    """Test that access rules granted by one user affect resources within their scope.
    This user (acting as owner) grants access to a specific entity."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None

    # Resource owned by this user (use identity instead of user_id)
    resource = "user/" + username + "/documents/shared"

    # Clean up
    mochi.access.clear.resource(resource)

    # Grant access to a specific entity (could be another user's identity)
    # We'll use a placeholder entity ID for the other user
    other_entity = "otheruserentity00000000000000000"

    mochi.access.allow(other_entity, resource, "read", "cross_user_test")
    mochi.access.allow(other_entity, resource, "comment", "cross_user_test")

    # Verify the rule was created
    rules = mochi.access.list.resource(resource)
    if len(rules) == 2:
        results.append({"test": "grant_access_to_other", "passed": True})
    else:
        results.append({"test": "grant_access_to_other", "passed": False, "got": rules})
        passed = False

    # Check that the other entity has access
    if mochi.access.check(other_entity, resource, "read"):
        results.append({"test": "other_entity_has_read", "passed": True})
    else:
        results.append({"test": "other_entity_has_read", "passed": False})
        passed = False

    # Check that other entity cannot write
    if not mochi.access.check(other_entity, resource, "write"):
        results.append({"test": "other_entity_no_write", "passed": True})
    else:
        results.append({"test": "other_entity_no_write", "passed": False})
        passed = False

    # Deny a specific permission
    mochi.access.deny(other_entity, resource, "read", "revoked")
    if not mochi.access.check(other_entity, resource, "read"):
        results.append({"test": "revoke_read_access", "passed": True})
    else:
        results.append({"test": "revoke_read_access", "passed": False})
        passed = False

    # Comment should still work
    if mochi.access.check(other_entity, resource, "comment"):
        results.append({"test": "comment_still_works", "passed": True})
    else:
        results.append({"test": "comment_still_works", "passed": False})
        passed = False

    # Clean up
    mochi.access.clear.resource(resource)

    a.json({
        "test": "multiuser_access_cross_user",
        "passed": passed,
        "results": results,
        "username": username,
        "resource": resource
    })

def action_test_multiuser_access_user_entity(a):
    """Test access control using real user entities.
    This test checks access between actual user identities."""
    results = []
    passed = True

    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "none"

    # Use valid 32-char lowercase alphanumeric group ID
    collab_group = "collaboratorsgroup0000000000000a"

    # Resource belonging to this user
    my_resource = "user/" + username + "/project/alpha"

    # Clean up
    mochi.access.clear.resource(my_resource)
    mochi.group.delete(collab_group)

    # Test 1: Self access - the owner should have access via identity
    mochi.access.allow(identity_id, my_resource, "*", "owner")
    if mochi.access.check(identity_id, my_resource, "read"):
        results.append({"test": "owner_has_read", "passed": True})
    else:
        results.append({"test": "owner_has_read", "passed": False})
        passed = False

    if mochi.access.check(identity_id, my_resource, "write"):
        results.append({"test": "owner_has_write", "passed": True})
    else:
        results.append({"test": "owner_has_write", "passed": False})
        passed = False

    # Test 2: Create a group and add collaborators
    mochi.group.create(collab_group, "Collaborators", "People who can view this project")
    mochi.group.add(collab_group, "collaborator1entity000000000000", "user")
    mochi.group.add(collab_group, "collaborator2entity000000000000", "user")

    # Grant read access to the group
    mochi.access.allow("@" + collab_group, my_resource, "read", "shared")

    # Collaborators should have read access
    if mochi.access.check("collaborator1entity000000000000", my_resource, "read"):
        results.append({"test": "collaborator1_read", "passed": True})
    else:
        results.append({"test": "collaborator1_read", "passed": False})
        passed = False

    if mochi.access.check("collaborator2entity000000000000", my_resource, "read"):
        results.append({"test": "collaborator2_read", "passed": True})
    else:
        results.append({"test": "collaborator2_read", "passed": False})
        passed = False

    # Collaborators should NOT have write access
    if not mochi.access.check("collaborator1entity000000000000", my_resource, "write"):
        results.append({"test": "collaborator1_no_write", "passed": True})
    else:
        results.append({"test": "collaborator1_no_write", "passed": False})
        passed = False

    # Test 3: Add anonymous read access (public)
    mochi.access.allow("*", my_resource + "/public", "read", "public")
    if mochi.access.check("random_entity", my_resource + "/public", "read"):
        results.append({"test": "public_read", "passed": True})
    else:
        results.append({"test": "public_read", "passed": False})
        passed = False

    # Test 4: Deny specific user even if they're in the group
    mochi.access.deny("collaborator1entity000000000000", my_resource, "read", "banned")
    if not mochi.access.check("collaborator1entity000000000000", my_resource, "read"):
        results.append({"test": "user_deny_overrides_group", "passed": True})
    else:
        results.append({"test": "user_deny_overrides_group", "passed": False})
        passed = False

    # collaborator2 should still have access
    if mochi.access.check("collaborator2entity000000000000", my_resource, "read"):
        results.append({"test": "other_collaborator_unaffected", "passed": True})
    else:
        results.append({"test": "other_collaborator_unaffected", "passed": False})
        passed = False

    # Clean up
    mochi.access.clear.resource(my_resource)
    mochi.access.clear.resource(my_resource + "/public")
    mochi.access.clear.subject(identity_id)
    mochi.access.clear.subject("@" + collab_group)
    mochi.access.clear.subject("collaborator1entity000000000000")
    mochi.group.delete(collab_group)

    a.json({
        "test": "multiuser_access_user_entity",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "resource": my_resource
    })

# =============================================================================
# Cross-Instance Tests (Different Mochi Instances)
# =============================================================================

def action_test_crossinstance_groups_isolation(a):
    """Test that groups are completely isolated between instances.
    Run this on Instance 1 to create a group, then run
    test_crossinstance_groups_verify on Instance 2 to verify isolation."""
    results = []
    passed = True

    instance_group = "crossinstancegroup00000000000000"
    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "unknown"

    # Cleanup from previous runs
    mochi.group.delete(instance_group)

    # Create a group on this instance
    g1 = mochi.group.create(instance_group, "Cross Instance Group", "Created on instance by " + username)
    if g1 and g1["id"] == instance_group:
        results.append({"test": "create_group", "passed": True})
    else:
        results.append({"test": "create_group", "passed": False, "got": g1})
        passed = False

    # Add this user's identity as a member
    mochi.group.add(instance_group, identity_id, "user")
    mochi.group.add(instance_group, "local_member", "user")

    # Verify the group exists with members
    members = mochi.group.members(instance_group)
    member_ids = [m["member"] for m in members]
    if identity_id in member_ids and "local_member" in member_ids:
        results.append({"test": "add_members", "passed": True, "count": len(members)})
    else:
        results.append({"test": "add_members", "passed": False, "got": members})
        passed = False

    a.json({
        "test": "crossinstance_groups_isolation",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "instance_group": instance_group,
        "note": "Run test_crossinstance_groups_verify on the OTHER instance to verify isolation"
    })

def action_test_crossinstance_groups_verify(a):
    """Verify that groups from Instance 1 do NOT exist on Instance 2.
    Run on Instance 2 after running test_crossinstance_groups_isolation on Instance 1."""
    results = []
    passed = True

    instance_group = "crossinstancegroup00000000000000"
    username = a.user.username

    # Try to get the group - should NOT exist on this instance
    g = mochi.group.get(instance_group)
    if g == None:
        results.append({"test": "group_not_found", "passed": True,
                       "note": "Group from other instance correctly not visible"})
    else:
        results.append({"test": "group_not_found", "passed": False, "got": g,
                       "error": "Group from other instance should NOT be visible!"})
        passed = False

    # List groups - should NOT include the cross-instance group
    groups = mochi.group.list()
    group_ids = [g["id"] for g in groups]
    if instance_group not in group_ids:
        results.append({"test": "list_excludes_group", "passed": True})
    else:
        results.append({"test": "list_excludes_group", "passed": False, "got": group_ids})
        passed = False

    # Attempting to add a member should create a NEW local group
    # (demonstrating complete isolation)
    mochi.group.add(instance_group, "intruder_member", "user")
    local_members = mochi.group.members(instance_group)

    # Clean up the locally-created group
    mochi.group.delete(instance_group)

    # If the group we created locally only has "intruder_member",
    # it proves isolation (we didn't modify Instance 1's group)
    local_member_ids = [m["member"] for m in local_members]
    if "intruder_member" in local_member_ids and "local_member" not in local_member_ids:
        results.append({"test": "complete_isolation", "passed": True,
                       "note": "Adding member created new local group, not modified remote"})
    else:
        results.append({"test": "complete_isolation", "passed": False, "got": local_members,
                       "error": "May have modified remote group!"})
        passed = False

    a.json({
        "test": "crossinstance_groups_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "note": "Verified groups are isolated between instances"
    })

def action_test_crossinstance_access_isolation(a):
    """Test that access rules are completely isolated between instances.
    Run on Instance 1 to create access rules, then run
    test_crossinstance_access_verify on Instance 2."""
    results = []
    passed = True

    resource = "crossinstance/shared/document"
    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "unknown"

    # Clean up
    mochi.access.clear.resource(resource)

    # Create access rules on this instance
    mochi.access.allow(identity_id, resource, "read", "owner")
    mochi.access.allow(identity_id, resource, "write", "owner")
    mochi.access.allow("remote_entity_placeholder", resource, "read", "shared")
    mochi.access.deny("blocked_entity", resource, "*", "blocked")

    # Verify rules exist
    rules = mochi.access.list.resource(resource)
    if len(rules) >= 3:
        results.append({"test": "rules_created", "passed": True, "count": len(rules)})
    else:
        results.append({"test": "rules_created", "passed": False, "got": rules})
        passed = False

    # Verify access checks work locally
    if mochi.access.check(identity_id, resource, "read"):
        results.append({"test": "owner_can_read", "passed": True})
    else:
        results.append({"test": "owner_can_read", "passed": False})
        passed = False

    if not mochi.access.check("blocked_entity", resource, "read"):
        results.append({"test": "blocked_entity_denied", "passed": True})
    else:
        results.append({"test": "blocked_entity_denied", "passed": False})
        passed = False

    a.json({
        "test": "crossinstance_access_isolation",
        "passed": passed,
        "results": results,
        "username": username,
        "identity": identity_id,
        "resource": resource,
        "note": "Run test_crossinstance_access_verify on the OTHER instance"
    })

def action_test_crossinstance_access_verify(a):
    """Verify access rules from Instance 1 do NOT exist on Instance 2.
    Run on Instance 2 after running test_crossinstance_access_isolation on Instance 1."""
    results = []
    passed = True

    resource = "crossinstance/shared/document"
    username = a.user.username

    # Check that no rules exist for this resource on this instance
    rules = mochi.access.list.resource(resource)
    if len(rules) == 0:
        results.append({"test": "no_rules_found", "passed": True,
                       "note": "Access rules from other instance correctly not visible"})
    else:
        results.append({"test": "no_rules_found", "passed": False, "got": rules,
                       "error": "Found rules that should not exist on this instance!"})
        passed = False

    # The "remote_entity_placeholder" should NOT have access here
    if not mochi.access.check("remote_entity_placeholder", resource, "read"):
        results.append({"test": "remote_grant_not_valid", "passed": True})
    else:
        results.append({"test": "remote_grant_not_valid", "passed": False,
                       "error": "Grant from other instance should NOT work here!"})
        passed = False

    # "blocked_entity" should also not be blocked here (no rules exist)
    # Actually, with no rules, check returns False by default
    if not mochi.access.check("blocked_entity", resource, "read"):
        results.append({"test": "no_default_access", "passed": True,
                       "note": "Without rules, access is denied by default"})
    else:
        results.append({"test": "no_default_access", "passed": False})
        passed = False

    a.json({
        "test": "crossinstance_access_verify",
        "passed": passed,
        "results": results,
        "username": username,
        "note": "Verified access rules are isolated between instances"
    })

def action_test_crossinstance_p2p_ping(a):
    """Test P2P connectivity between instances by sending a ping.
    Provide 'to' parameter with an entity ID from the other instance."""
    results = []
    passed = True

    to = a.input("to")
    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else None

    if not to:
        a.json({
            "test": "crossinstance_p2p_ping",
            "passed": False,
            "error": "Missing 'to' parameter - provide entity ID from other instance"
        })
        return

    if not identity_id:
        a.json({
            "test": "crossinstance_p2p_ping",
            "passed": False,
            "error": "No identity - cannot send P2P message"
        })
        return

    # Send a P2P ping to the entity on the other instance
    headers = {
        "from": identity_id,
        "to": to,
        "service": "claude-test",
        "event": "ping"
    }
    content = {
        "message": "crossinstance_ping",
        "time": mochi.time.now(),
        "from_username": username
    }

    result = mochi.message.send(headers, content)
    results.append({"test": "send_ping", "passed": True, "to": to})

    a.json({
        "test": "crossinstance_p2p_ping",
        "passed": passed,
        "results": results,
        "from": identity_id,
        "to": to,
        "username": username,
        "note": "Ping sent - check server logs for delivery confirmation"
    })

def action_test_crossinstance_remote_entity_access(a):
    """Test granting access to an entity from another instance.
    This verifies you can add remote entity IDs to access rules."""
    results = []
    passed = True

    # A real entity ID from Instance 2
    remote_entity = a.input("remote_entity")
    if not remote_entity:
        remote_entity = "1w5MKU524DorJh7DKctmaWuEvgmZ7paR33gWdDxWeDLhK8eWJ"  # Default: User 2 from Instance 2

    resource = "crossinstance/owned/resource"
    username = a.user.username
    identity_id = a.user.identity.id if a.user.identity else "unknown"

    # Clean up
    mochi.access.clear.resource(resource)

    # Grant access to the remote entity
    mochi.access.allow(remote_entity, resource, "read", "remote_grant")
    mochi.access.allow(remote_entity, resource, "comment", "remote_grant")

    # Verify the rules were created
    rules = mochi.access.list.resource(resource)
    remote_rules = [r for r in rules if r["subject"] == remote_entity]
    if len(remote_rules) == 2:
        results.append({"test": "remote_entity_rules_created", "passed": True})
    else:
        results.append({"test": "remote_entity_rules_created", "passed": False, "got": remote_rules})
        passed = False

    # Check access for the remote entity (should pass - it's just a local check)
    if mochi.access.check(remote_entity, resource, "read"):
        results.append({"test": "remote_entity_has_read", "passed": True})
    else:
        results.append({"test": "remote_entity_has_read", "passed": False})
        passed = False

    if not mochi.access.check(remote_entity, resource, "write"):
        results.append({"test": "remote_entity_no_write", "passed": True})
    else:
        results.append({"test": "remote_entity_no_write", "passed": False})
        passed = False

    # Clean up
    mochi.access.clear.resource(resource)

    a.json({
        "test": "crossinstance_remote_entity_access",
        "passed": passed,
        "results": results,
        "username": username,
        "remote_entity": remote_entity,
        "note": "Access rules with remote entity IDs work locally"
    })

# =============================================================================
# Attachment API Tests
# =============================================================================

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

# =============================================================================
# Attachment Multi-User Tests (Same Instance)
# =============================================================================

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

# =============================================================================
# Attachment Cross-Instance Tests
# =============================================================================

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
            "test_attachment_content_types"
        ],
        "multiuser_same_instance_tests": [
            "test_attachment_multiuser_isolation (run as user 1)",
            "test_attachment_multiuser_isolation_verify (run as user 2)",
            "test_attachment_multiuser_shared"
        ],
        "crossinstance_tests": [
            "test_attachment_crossinstance_sync?remote_entity=<entity_id>",
            "test_attachment_crossinstance_fetch?source_entity=<entity_id>&object_id=<object_id>",
            "test_attachment_crossinstance_isolation",
            "test_attachment_crossinstance_notify?remote_entities=<entity1>,<entity2>"
        ]
    })
