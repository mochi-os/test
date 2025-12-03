# Mochi Claude Test app: User management API tests
# Tests for mochi.user.* functions
# Note: Most functions require administrator role

def action_test_users_get_id(a):
    """Test mochi.user.get.id() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_id", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get current user by ID (we know our own ID exists)
    # We need to find our user ID first via list
    users = mochi.user.list(1, 0)
    if len(users) == 0:
        a.json({"test": "users_get_id", "status": "FAIL", "error": "No users found"})
        return

    user_id = users[0]["id"]
    result = mochi.user.get.id(user_id)

    if result == None:
        a.json({"test": "users_get_id", "status": "FAIL", "error": "get.id returned None for existing user"})
        return

    if "id" not in result or "username" not in result or "role" not in result:
        a.json({"test": "users_get_id", "status": "FAIL", "error": "Missing fields in result"})
        return

    a.json({"test": "users_get_id", "status": "PASS", "user": result})

def action_test_users_get_id_not_found(a):
    """Test mochi.user.get.id() returns None for non-existent user"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_id_not_found", "status": "SKIP", "reason": "Requires administrator role"})
        return

    result = mochi.user.get.id(999999)
    if result != None:
        a.json({"test": "users_get_id_not_found", "status": "FAIL", "error": "Should return None for non-existent user"})
        return

    a.json({"test": "users_get_id_not_found", "status": "PASS"})

def action_test_users_get_username(a):
    """Test mochi.user.get.username() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_username", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get current user's username
    username = a.user.username
    result = mochi.user.get.username(username)

    if result == None:
        a.json({"test": "users_get_username", "status": "FAIL", "error": "get.username returned None for existing user"})
        return

    if result["username"] != username:
        a.json({"test": "users_get_username", "status": "FAIL", "error": "Username mismatch"})
        return

    a.json({"test": "users_get_username", "status": "PASS", "user": result})

def action_test_users_get_username_not_found(a):
    """Test mochi.user.get.username() returns None for non-existent user"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_username_not_found", "status": "SKIP", "reason": "Requires administrator role"})
        return

    result = mochi.user.get.username("nonexistent@example.com")
    if result != None:
        a.json({"test": "users_get_username_not_found", "status": "FAIL", "error": "Should return None for non-existent user"})
        return

    a.json({"test": "users_get_username_not_found", "status": "PASS"})

def action_test_users_list(a):
    """Test mochi.user.list() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_list", "status": "SKIP", "reason": "Requires administrator role"})
        return

    users = mochi.user.list()

    if type(users) != "tuple":
        a.json({"test": "users_list", "status": "FAIL", "error": "Expected tuple, got: " + type(users)})
        return

    if len(users) == 0:
        a.json({"test": "users_list", "status": "FAIL", "error": "Expected at least 1 user"})
        return

    # Check first user has required fields
    user = users[0]
    if "id" not in user or "username" not in user or "role" not in user:
        a.json({"test": "users_list", "status": "FAIL", "error": "User missing required fields"})
        return

    a.json({"test": "users_list", "status": "PASS", "count": len(users)})

def action_test_users_list_pagination(a):
    """Test mochi.user.list() pagination - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_list_pagination", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get first user
    users1 = mochi.user.list(1, 0)
    if len(users1) != 1:
        a.json({"test": "users_list_pagination", "status": "FAIL", "error": "limit=1 should return 1 user"})
        return

    # Get all users to check count
    all_users = mochi.user.list(1000, 0)
    total = len(all_users)

    # Test offset beyond count
    users_empty = mochi.user.list(10, total + 100)
    if len(users_empty) != 0:
        a.json({"test": "users_list_pagination", "status": "FAIL", "error": "offset beyond count should return empty"})
        return

    a.json({"test": "users_list_pagination", "status": "PASS", "total": total})

def action_test_users_count(a):
    """Test mochi.user.count() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_count", "status": "SKIP", "reason": "Requires administrator role"})
        return

    count = mochi.user.count()

    if type(count) != "int":
        a.json({"test": "users_count", "status": "FAIL", "error": "Expected int, got: " + type(count)})
        return

    if count < 1:
        a.json({"test": "users_count", "status": "FAIL", "error": "Expected at least 1 user"})
        return

    # Verify matches list length
    users = mochi.user.list(1000, 0)
    if count != len(users):
        a.json({"test": "users_count", "status": "FAIL", "error": "Count mismatch with list length"})
        return

    a.json({"test": "users_count", "status": "PASS", "count": count})

def action_test_users_create_update_delete(a):
    """Test mochi.user.create(), update(), delete() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_create_update_delete", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create a test user
    test_email = "test-" + mochi.random.alphanumeric(8) + "@example.com"
    user = mochi.user.create(test_email)

    if user == None:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "create() returned None"})
        return

    if user["username"] != test_email:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "Username mismatch after create"})
        return

    if user["role"] != "user":
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "Default role should be 'user'"})
        return

    user_id = user["id"]

    # Update role
    result = mochi.user.update(user_id, None, "administrator")
    if result != True:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "update() did not return True"})
        return

    # Verify update
    updated = mochi.user.get.id(user_id)
    if updated["role"] != "administrator":
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "Role not updated"})
        return

    # Update username
    new_email = "updated-" + mochi.random.alphanumeric(8) + "@example.com"
    mochi.user.update(user_id, new_email, None)
    updated = mochi.user.get.id(user_id)
    if updated["username"] != new_email:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "Username not updated"})
        return

    # Delete user
    result = mochi.user.delete(user_id)
    if result != True:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "delete() did not return True"})
        return

    # Verify deletion
    deleted = mochi.user.get.id(user_id)
    if deleted != None:
        a.json({"test": "users_create_update_delete", "status": "FAIL", "error": "User still exists after delete"})
        return

    a.json({"test": "users_create_update_delete", "status": "PASS"})

def action_test_users_create_with_role(a):
    """Test mochi.user.create() with role parameter - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_create_with_role", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create admin user
    test_email = "admin-" + mochi.random.alphanumeric(8) + "@example.com"
    user = mochi.user.create(test_email, "administrator")

    if user["role"] != "administrator":
        mochi.user.delete(user["id"])
        a.json({"test": "users_create_with_role", "status": "FAIL", "error": "Role should be 'administrator'"})
        return

    # Cleanup
    mochi.user.delete(user["id"])

    a.json({"test": "users_create_with_role", "status": "PASS"})

def action_test_users_create_duplicate(a):
    """Test mochi.user.create() fails for duplicate username - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_create_duplicate", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Try to create user with existing username
    existing_username = a.user.username
    user = mochi.user.create(existing_username)
    # Should have raised error - if we get here, test failed
    a.json({"test": "users_create_duplicate", "status": "FAIL", "error": "Should have failed for duplicate username"})

def action_test_users_delete_self(a):
    """Test mochi.user.delete() cannot delete self - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_delete_self", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get own user ID
    me = mochi.user.get.username(a.user.username)
    if me == None:
        a.json({"test": "users_delete_self", "status": "FAIL", "error": "Could not find own user"})
        return

    # Try to delete self - should fail
    result = mochi.user.delete(me["id"])
    # Should have raised error
    a.json({"test": "users_delete_self", "status": "FAIL", "error": "Should not be able to delete self"})

def action_test_users_invite_create(a):
    """Test mochi.user.invite.create() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_invite_create", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create invite with defaults
    invite = mochi.user.invite.create()

    if invite == None:
        a.json({"test": "users_invite_create", "status": "FAIL", "error": "create() returned None"})
        return

    if "code" not in invite or "uses" not in invite or "expires" not in invite:
        a.json({"test": "users_invite_create", "status": "FAIL", "error": "Missing fields in invite"})
        return

    if invite["uses"] != 1:
        a.json({"test": "users_invite_create", "status": "FAIL", "error": "Default uses should be 1"})
        return

    # Cleanup
    mochi.user.invite.delete(invite["code"])

    a.json({"test": "users_invite_create", "status": "PASS", "code": invite["code"]})

def action_test_users_invite_create_custom(a):
    """Test mochi.user.invite.create() with custom parameters - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_invite_create_custom", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create invite with custom uses and expires
    invite = mochi.user.invite.create(10, 30)

    if invite["uses"] != 10:
        mochi.user.invite.delete(invite["code"])
        a.json({"test": "users_invite_create_custom", "status": "FAIL", "error": "Uses should be 10"})
        return

    # Cleanup
    mochi.user.invite.delete(invite["code"])

    a.json({"test": "users_invite_create_custom", "status": "PASS"})

def action_test_users_invite_list(a):
    """Test mochi.user.invite.list() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_invite_list", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create a test invite
    invite = mochi.user.invite.create()

    # List invites
    invites = mochi.user.invite.list()

    if type(invites) != "tuple":
        mochi.user.invite.delete(invite["code"])
        a.json({"test": "users_invite_list", "status": "FAIL", "error": "Expected tuple, got: " + type(invites)})
        return

    # Find our invite in the list
    found = False
    for inv in invites:
        if inv["code"] == invite["code"]:
            found = True
            break

    if not found:
        mochi.user.invite.delete(invite["code"])
        a.json({"test": "users_invite_list", "status": "FAIL", "error": "Created invite not found in list"})
        return

    # Cleanup
    mochi.user.invite.delete(invite["code"])

    a.json({"test": "users_invite_list", "status": "PASS", "count": len(invites)})

def action_test_users_invite_delete(a):
    """Test mochi.user.invite.delete() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_invite_delete", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Create invite
    invite = mochi.user.invite.create()
    code = invite["code"]

    # Verify it's valid
    if not mochi.user.invite.validate(code):
        a.json({"test": "users_invite_delete", "status": "FAIL", "error": "New invite should be valid"})
        return

    # Delete it
    result = mochi.user.invite.delete(code)
    if result != True:
        a.json({"test": "users_invite_delete", "status": "FAIL", "error": "delete() did not return True"})
        return

    # Verify it's no longer valid
    if mochi.user.invite.validate(code):
        a.json({"test": "users_invite_delete", "status": "FAIL", "error": "Deleted invite should not be valid"})
        return

    a.json({"test": "users_invite_delete", "status": "PASS"})

def action_test_users_invite_validate(a):
    """Test mochi.user.invite.validate() - available to all users"""
    # This test doesn't require admin - validate is public

    # Test with non-existent code
    result = mochi.user.invite.validate("nonexistent_code_xyz")
    if result != False:
        a.json({"test": "users_invite_validate", "status": "FAIL", "error": "Should return False for invalid code"})
        return

    # If admin, create and test a real invite
    if a.user.role == "administrator":
        invite = mochi.user.invite.create()
        result = mochi.user.invite.validate(invite["code"])
        if result != True:
            mochi.user.invite.delete(invite["code"])
            a.json({"test": "users_invite_validate", "status": "FAIL", "error": "Should return True for valid code"})
            return
        mochi.user.invite.delete(invite["code"])

    a.json({"test": "users_invite_validate", "status": "PASS"})

def action_test_users_suite(a):
    """Run all user tests that don't require error handling"""
    results = []
    is_admin = a.user.role == "administrator"

    # Test 1: Validate non-existent invite (public)
    result = mochi.user.invite.validate("nonexistent_xyz")
    results.append({"test": "invite_validate_invalid", "pass": result == False})

    if is_admin:
        # Test 2: Count users
        count = mochi.user.count()
        results.append({"test": "count", "pass": count >= 1})

        # Test 3: List users
        users = mochi.user.list()
        results.append({"test": "list", "pass": len(users) >= 1})

        # Test 4: Get user by username
        me = mochi.user.get.username(a.user.username)
        results.append({"test": "get_username", "pass": me != None and me["username"] == a.user.username})

        # Test 5: Create and delete invite
        invite = mochi.user.invite.create()
        valid = mochi.user.invite.validate(invite["code"])
        mochi.user.invite.delete(invite["code"])
        invalid = mochi.user.invite.validate(invite["code"])
        results.append({"test": "invite_lifecycle", "pass": valid == True and invalid == False})

        # Test 6: Create, update, delete user
        test_email = "suite-" + mochi.random.alphanumeric(8) + "@example.com"
        user = mochi.user.create(test_email)
        created = user != None and user["username"] == test_email
        if created:
            mochi.user.update(user["id"], None, "administrator")
            updated = mochi.user.get.id(user["id"])
            role_updated = updated["role"] == "administrator"
            mochi.user.delete(user["id"])
            deleted = mochi.user.get.id(user["id"]) == None
            results.append({"test": "user_lifecycle", "pass": created and role_updated and deleted})
        else:
            results.append({"test": "user_lifecycle", "pass": False})
    else:
        results.append({"test": "count", "pass": True, "skipped": True})
        results.append({"test": "list", "pass": True, "skipped": True})
        results.append({"test": "get_username", "pass": True, "skipped": True})
        results.append({"test": "invite_lifecycle", "pass": True, "skipped": True})
        results.append({"test": "user_lifecycle", "pass": True, "skipped": True})

    # Count passes
    passed = len([r for r in results if r["pass"]])
    total = len(results)

    status = "PASS" if passed == total else "FAIL"
    a.json({"test": "users_suite", "status": status, "passed": passed, "total": total, "is_admin": is_admin, "results": results})

def action_test_users_get_identity(a):
    """Test mochi.user.get.identity() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_identity", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get own identity
    identity = a.user.identity.id
    result = mochi.user.get.identity(identity)

    if result == None:
        a.json({"test": "users_get_identity", "status": "FAIL", "error": "get.identity returned None for own identity"})
        return

    if result["username"] != a.user.username:
        a.json({"test": "users_get_identity", "status": "FAIL", "error": "Username mismatch"})
        return

    a.json({"test": "users_get_identity", "status": "PASS", "user": result})

def action_test_users_get_identity_not_found(a):
    """Test mochi.user.get.identity() returns None for non-existent identity"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_identity_not_found", "status": "SKIP", "reason": "Requires administrator role"})
        return

    result = mochi.user.get.identity("nonexistent_identity_xyz")
    if result != None:
        a.json({"test": "users_get_identity_not_found", "status": "FAIL", "error": "Should return None for non-existent identity"})
        return

    a.json({"test": "users_get_identity_not_found", "status": "PASS"})

def action_test_users_get_fingerprint(a):
    """Test mochi.user.get.fingerprint() - admin only"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_fingerprint", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get own fingerprint (without hyphens) using mochi.entity.fingerprint
    fingerprint = mochi.entity.fingerprint(a.user.identity.id)
    result = mochi.user.get.fingerprint(fingerprint)

    if result == None:
        a.json({"test": "users_get_fingerprint", "status": "FAIL", "error": "get.fingerprint returned None for own fingerprint"})
        return

    if result["username"] != a.user.username:
        a.json({"test": "users_get_fingerprint", "status": "FAIL", "error": "Username mismatch"})
        return

    a.json({"test": "users_get_fingerprint", "status": "PASS", "user": result})

def action_test_users_get_fingerprint_with_hyphens(a):
    """Test mochi.user.get.fingerprint() accepts fingerprint with hyphens"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_fingerprint_with_hyphens", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Get own fingerprint (with hyphens) using mochi.entity.fingerprint with hyphens=True
    fingerprint = mochi.entity.fingerprint(a.user.identity.id, True)
    result = mochi.user.get.fingerprint(fingerprint)

    if result == None:
        a.json({"test": "users_get_fingerprint_with_hyphens", "status": "FAIL", "error": "get.fingerprint should accept hyphens"})
        return

    if result["username"] != a.user.username:
        a.json({"test": "users_get_fingerprint_with_hyphens", "status": "FAIL", "error": "Username mismatch"})
        return

    a.json({"test": "users_get_fingerprint_with_hyphens", "status": "PASS"})

def action_test_users_get_fingerprint_not_found(a):
    """Test mochi.user.get.fingerprint() returns None for non-existent fingerprint"""
    if a.user.role != "administrator":
        a.json({"test": "users_get_fingerprint_not_found", "status": "SKIP", "reason": "Requires administrator role"})
        return

    result = mochi.user.get.fingerprint("nonexistent1234567890")
    if result != None:
        a.json({"test": "users_get_fingerprint_not_found", "status": "FAIL", "error": "Should return None for non-existent fingerprint"})
        return

    a.json({"test": "users_get_fingerprint_not_found", "status": "PASS"})
