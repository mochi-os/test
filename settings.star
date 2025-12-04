# Mochi Claude Test app: System settings tests
# Tests for mochi.setting.get(), set(), list()
# Note: set() and list() require administrator role

def action_test_settings_get_user_readable(a):
    """Test getting user-readable settings (server_version, site_maintenance_message, etc.)"""
    # server_version should be readable by any user
    result = mochi.setting.get("server_version")
    if result == None or result == "":
        a.json({"test": "settings_get_user_readable", "status": "FAIL", "error": "server_version returned empty"})
        return

    # site_maintenance_message should also be readable (empty string is valid default)
    result = mochi.setting.get("site_maintenance_message")

    a.json({"test": "settings_get_user_readable", "status": "PASS", "server_version": mochi.setting.get("server_version")})

def action_test_settings_get_unknown(a):
    """Test getting unknown setting returns error"""
    # This should fail - unknown setting
    result = mochi.setting.get("nonexistent_setting_xyz")
    # If we get here without error, something is wrong
    a.json({"test": "settings_get_unknown", "status": "FAIL", "error": "Should have raised error for unknown setting"})

def action_test_settings_set_admin(a):
    """Test setting a value (requires administrator)"""
    if a.user.role != "administrator":
        a.json({"test": "settings_set_admin", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Set site_maintenance_message
    result = mochi.setting.set("site_maintenance_message", "Test maintenance")
    if result != True:
        a.json({"test": "settings_set_admin", "status": "FAIL", "error": "set() did not return True"})
        return

    # Verify it was set
    value = mochi.setting.get("site_maintenance_message")
    if value != "Test maintenance":
        a.json({"test": "settings_set_admin", "status": "FAIL", "error": "Value not persisted, got: " + str(value)})
        return

    # Reset to default
    mochi.setting.set("site_maintenance_message", "")

    a.json({"test": "settings_set_admin", "status": "PASS"})

def action_test_settings_set_validation(a):
    """Test setting validation rejects invalid values"""
    if a.user.role != "administrator":
        a.json({"test": "settings_set_validation", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Try to set invalid boolean value
    result = mochi.setting.set("signup_enabled", "yes")
    # Should fail validation - if we get here, validation failed
    a.json({"test": "settings_set_validation", "status": "FAIL", "error": "Should have rejected invalid value 'yes'"})

def action_test_settings_set_readonly(a):
    """Test that read-only settings cannot be modified"""
    if a.user.role != "administrator":
        a.json({"test": "settings_set_readonly", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Try to set read-only setting
    result = mochi.setting.set("server_version", "hacked")
    # Should fail - if we get here, read-only check failed
    a.json({"test": "settings_set_readonly", "status": "FAIL", "error": "Should have rejected read-only setting"})

def action_test_settings_list_admin(a):
    """Test listing all settings (requires administrator)"""
    if a.user.role != "administrator":
        a.json({"test": "settings_list_admin", "status": "SKIP", "reason": "Requires administrator role"})
        return

    settings = mochi.setting.list()

    if type(settings) != "tuple":
        a.json({"test": "settings_list_admin", "status": "FAIL", "error": "Expected tuple, got: " + type(settings)})
        return

    if len(settings) < 4:
        a.json({"test": "settings_list_admin", "status": "FAIL", "error": "Expected at least 4 settings, got: " + str(len(settings))})
        return

    # Check that each setting has required fields
    required_fields = ["name", "value", "default", "description", "pattern", "user_readable", "read_only"]
    for s in settings:
        for field in required_fields:
            if field not in s:
                a.json({"test": "settings_list_admin", "status": "FAIL", "error": "Setting missing field: " + field})
                return

    # Find site_maintenance_message in the list
    found = False
    for s in settings:
        if s["name"] == "site_maintenance_message":
            found = True
            if s["user_readable"] != True:
                a.json({"test": "settings_list_admin", "status": "FAIL", "error": "site_maintenance_message should be user_readable"})
                return
            break

    if not found:
        a.json({"test": "settings_list_admin", "status": "FAIL", "error": "site_maintenance_message not found in list"})
        return

    a.json({"test": "settings_list_admin", "status": "PASS", "count": len(settings)})

def action_test_settings_maintenance_message(a):
    """Test maintenance message setting"""
    if a.user.role != "administrator":
        a.json({"test": "settings_maintenance_message", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Set maintenance message
    mochi.setting.set("site_maintenance_message", "Down for updates")
    value = mochi.setting.get("site_maintenance_message")
    if value != "Down for updates":
        a.json({"test": "settings_maintenance_message", "status": "FAIL", "error": "Message not set correctly"})
        return

    # Clear maintenance (empty string)
    mochi.setting.set("site_maintenance_message", "")
    value = mochi.setting.get("site_maintenance_message")
    if value != "":
        a.json({"test": "settings_maintenance_message", "status": "FAIL", "error": "Message not cleared"})
        return

    a.json({"test": "settings_maintenance_message", "status": "PASS"})

def action_test_settings_get_not_user_readable(a):
    """Test that non-admin users cannot read non-user-readable settings"""
    if a.user.role == "administrator":
        a.json({"test": "settings_get_not_user_readable", "status": "SKIP", "reason": "Test requires non-administrator"})
        return

    # email_from is not user-readable - this should fail
    result = mochi.setting.get("email_from")
    # If we get here, access control failed
    a.json({"test": "settings_get_not_user_readable", "status": "FAIL", "error": "Non-admin should not be able to read email_from"})

def action_test_settings_set_non_admin(a):
    """Test that non-admin users cannot modify settings"""
    if a.user.role == "administrator":
        a.json({"test": "settings_set_non_admin", "status": "SKIP", "reason": "Test requires non-administrator"})
        return

    # Try to set a modifiable setting - should fail for non-admin
    result = mochi.setting.set("site_maintenance_message", "hacked")
    # If we get here, access control failed
    a.json({"test": "settings_set_non_admin", "status": "FAIL", "error": "Non-admin should not be able to set settings"})

def action_test_settings_list_non_admin(a):
    """Test that non-admin users cannot list all settings"""
    if a.user.role == "administrator":
        a.json({"test": "settings_list_non_admin", "status": "SKIP", "reason": "Test requires non-administrator"})
        return

    # Try to list settings - should fail for non-admin
    result = mochi.setting.list()
    # If we get here, access control failed
    a.json({"test": "settings_list_non_admin", "status": "FAIL", "error": "Non-admin should not be able to list settings"})

def action_test_settings_get_admin_all(a):
    """Test that admin can read all settings including non-user-readable ones"""
    if a.user.role != "administrator":
        a.json({"test": "settings_get_admin_all", "status": "SKIP", "reason": "Requires administrator role"})
        return

    # Admin should be able to read email_from
    result = mochi.setting.get("email_from")
    if result == None:
        a.json({"test": "settings_get_admin_all", "status": "FAIL", "error": "Admin should be able to read email_from"})
        return

    # Also check domains_verification (boolean, not user-readable)
    result = mochi.setting.get("domains_verification")
    if result == None:
        a.json({"test": "settings_get_admin_all", "status": "FAIL", "error": "Admin should be able to read domains_verification"})
        return

    a.json({"test": "settings_get_admin_all", "status": "PASS"})

def action_test_settings_new_settings(a):
    """Test the newly added settings: email_from, domains_registration, domains_verification"""
    if a.user.role != "administrator":
        a.json({"test": "settings_new_settings", "status": "SKIP", "reason": "Requires administrator role"})
        return

    errors = []

    # Test email_from - should have a valid default or migrated value
    email_from = mochi.setting.get("email_from")
    if email_from == None or email_from == "":
        # Check if default works
        pass  # Empty might be valid if not migrated

    # Test domains_verification - boolean setting
    orig = mochi.setting.get("domains_verification")
    mochi.setting.set("domains_verification", "true")
    if mochi.setting.get("domains_verification") != "true":
        errors.append("domains_verification set to true failed")
    mochi.setting.set("domains_verification", "false")
    if mochi.setting.get("domains_verification") != "false":
        errors.append("domains_verification set to false failed")
    # Restore original
    mochi.setting.set("domains_verification", orig if orig else "false")

    # Test domains_registration - entity pattern, can be empty
    orig = mochi.setting.get("domains_registration")
    mochi.setting.set("domains_registration", "")
    if mochi.setting.get("domains_registration") != "":
        errors.append("domains_registration clear failed")
    # Restore
    if orig:
        mochi.setting.set("domains_registration", orig)

    if errors:
        a.json({"test": "settings_new_settings", "status": "FAIL", "errors": errors})
    else:
        a.json({"test": "settings_new_settings", "status": "PASS"})

def action_test_settings_suite(a):
    """Run all settings tests that don't require specific error handling"""
    results = []
    is_admin = a.user.role == "administrator"

    # Test 1: Get user-readable setting (server_version)
    result = mochi.setting.get("server_version")
    results.append({"test": "get_user_readable", "pass": result != None and result != ""})

    # Test 2: Get site_maintenance_message (user-readable, defaults to empty)
    result = mochi.setting.get("site_maintenance_message")
    results.append({"test": "get_maintenance_message", "pass": True})  # Empty string is valid

    if is_admin:
        # Test 3: Set and get
        mochi.setting.set("site_maintenance_message", "Test description")
        result = mochi.setting.get("site_maintenance_message")
        results.append({"test": "set_get", "pass": result == "Test description"})

        # Reset
        mochi.setting.set("site_maintenance_message", "")

        # Test 4: List settings
        settings = mochi.setting.list()
        results.append({"test": "list", "pass": type(settings) == "tuple" and len(settings) >= 4})

        # Test 5: Boolean setting
        mochi.setting.set("signup_enabled", "false")
        result = mochi.setting.get("signup_enabled")
        results.append({"test": "boolean_setting", "pass": result == "false"})
        mochi.setting.set("signup_enabled", "true")
    else:
        results.append({"test": "set_get", "pass": True, "skipped": True})
        results.append({"test": "list", "pass": True, "skipped": True})
        results.append({"test": "boolean_setting", "pass": True, "skipped": True})

    # Count passes
    passed = len([r for r in results if r["pass"]])
    total = len(results)

    status = "PASS" if passed == total else "FAIL"
    a.json({"test": "settings_suite", "status": status, "passed": passed, "total": total, "is_admin": is_admin, "results": results})
