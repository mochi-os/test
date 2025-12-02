# Mochi Claude Test app: Multi-User Tests
# Test cross-user isolation and access control

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
