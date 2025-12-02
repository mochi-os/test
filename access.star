# Mochi Claude Test app: Access Control API Tests
# Test access control: allow, deny, check, wildcards, hierarchy, groups

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
