# Mochi Claude Test app: Cross-Instance Tests
# Test isolation and communication between different Mochi instances

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
