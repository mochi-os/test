# Mochi Claude Test app: Groups API Tests
# Test group CRUD, membership, nesting, and cycle detection

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
