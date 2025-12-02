# Mochi Claude Test app: User preferences tests
# Tests for a.user.preference.get(), set(), delete(), all()

def action_test_preferences_get_default(a):
    """Test getting a preference that doesn't exist returns None"""
    result = a.user.preference.get("nonexistent_pref")
    if result != None:
        a.json({"test": "preferences_get_default", "status": "FAIL", "error": "Expected None, got: " + str(result)})
        return
    a.json({"test": "preferences_get_default", "status": "PASS"})

def action_test_preferences_set_get(a):
    """Test setting and getting a preference"""
    # Set a preference
    a.user.preference.set("test_theme", "dark")

    # Get it back
    result = a.user.preference.get("test_theme")
    if result != "dark":
        a.json({"test": "preferences_set_get", "status": "FAIL", "error": "Expected 'dark', got: " + str(result)})
        return

    a.json({"test": "preferences_set_get", "status": "PASS"})

def action_test_preferences_update(a):
    """Test updating an existing preference"""
    # Set initial value
    a.user.preference.set("test_update", "initial")

    # Update it
    a.user.preference.set("test_update", "updated")

    # Verify update
    result = a.user.preference.get("test_update")
    if result != "updated":
        a.json({"test": "preferences_update", "status": "FAIL", "error": "Expected 'updated', got: " + str(result)})
        return

    a.json({"test": "preferences_update", "status": "PASS"})

def action_test_preferences_multiple(a):
    """Test setting multiple preferences"""
    a.user.preference.set("pref_a", "value_a")
    a.user.preference.set("pref_b", "value_b")
    a.user.preference.set("pref_c", "value_c")

    # Verify all
    if a.user.preference.get("pref_a") != "value_a":
        a.json({"test": "preferences_multiple", "status": "FAIL", "error": "pref_a mismatch"})
        return
    if a.user.preference.get("pref_b") != "value_b":
        a.json({"test": "preferences_multiple", "status": "FAIL", "error": "pref_b mismatch"})
        return
    if a.user.preference.get("pref_c") != "value_c":
        a.json({"test": "preferences_multiple", "status": "FAIL", "error": "pref_c mismatch"})
        return

    a.json({"test": "preferences_multiple", "status": "PASS"})

def action_test_preferences_all(a):
    """Test getting all preferences as dict"""
    # Set some preferences
    a.user.preference.set("all_test_1", "value1")
    a.user.preference.set("all_test_2", "value2")

    # Get all preferences
    prefs = a.user.preference.all()

    if type(prefs) != "dict":
        a.json({"test": "preferences_all", "status": "FAIL", "error": "Expected dict, got: " + type(prefs)})
        return

    if prefs.get("all_test_1") != "value1":
        a.json({"test": "preferences_all", "status": "FAIL", "error": "all_test_1 not in preferences"})
        return
    if prefs.get("all_test_2") != "value2":
        a.json({"test": "preferences_all", "status": "FAIL", "error": "all_test_2 not in preferences"})
        return

    a.json({"test": "preferences_all", "status": "PASS", "count": len(prefs)})

def action_test_preferences_return_value(a):
    """Test that setting a preference returns the value"""
    result = a.user.preference.set("return_test", "returned_value")

    if result != "returned_value":
        a.json({"test": "preferences_return_value", "status": "FAIL", "error": "Expected 'returned_value', got: " + str(result)})
        return

    a.json({"test": "preferences_return_value", "status": "PASS"})

def action_test_preferences_special_chars(a):
    """Test preferences with special characters in values"""
    special_value = "hello world! @#$%^&*() 日本語"
    a.user.preference.set("special_test", special_value)

    result = a.user.preference.get("special_test")
    if result != special_value:
        a.json({"test": "preferences_special_chars", "status": "FAIL", "error": "Value mismatch with special chars"})
        return

    a.json({"test": "preferences_special_chars", "status": "PASS"})

def action_test_preferences_empty_value(a):
    """Test setting empty string as preference value"""
    a.user.preference.set("empty_test", "")

    result = a.user.preference.get("empty_test")
    if result != "":
        a.json({"test": "preferences_empty_value", "status": "FAIL", "error": "Expected empty string, got: " + str(result)})
        return

    a.json({"test": "preferences_empty_value", "status": "PASS"})

def action_test_preferences_delete(a):
    """Test deleting a preference"""
    # Set a preference
    a.user.preference.set("delete_test", "to_delete")

    # Verify it exists
    if a.user.preference.get("delete_test") != "to_delete":
        a.json({"test": "preferences_delete", "status": "FAIL", "error": "Preference not set"})
        return

    # Delete it
    deleted = a.user.preference.delete("delete_test")
    if not deleted:
        a.json({"test": "preferences_delete", "status": "FAIL", "error": "Delete returned False"})
        return

    # Verify it's gone
    if a.user.preference.get("delete_test") != None:
        a.json({"test": "preferences_delete", "status": "FAIL", "error": "Preference still exists after delete"})
        return

    # Delete again should return False
    deleted_again = a.user.preference.delete("delete_test")
    if deleted_again:
        a.json({"test": "preferences_delete", "status": "FAIL", "error": "Delete of non-existent returned True"})
        return

    a.json({"test": "preferences_delete", "status": "PASS"})

def action_test_preferences_cleanup(a):
    """Clean up test preferences (informational - preferences persist)"""
    # Note: There's no delete API, preferences persist
    # This just documents what preferences were created during testing
    prefs = a.user.preference.all()
    test_prefs = [k for k in prefs.keys() if "test" in k.lower()]
    a.json({"test": "preferences_cleanup", "status": "INFO", "test_preferences": test_prefs})

def action_test_preferences_suite(a):
    """Run all preference tests in sequence"""
    results = []

    # Test 1: Get default (None)
    result = a.user.preference.get("suite_nonexistent")
    results.append({"test": "get_default", "pass": result == None})

    # Test 2: Set and get
    a.user.preference.set("suite_theme", "dark")
    result = a.user.preference.get("suite_theme")
    results.append({"test": "set_get", "pass": result == "dark"})

    # Test 3: Update
    a.user.preference.set("suite_theme", "light")
    result = a.user.preference.get("suite_theme")
    results.append({"test": "update", "pass": result == "light"})

    # Test 4: Get all
    prefs = a.user.preference.all()
    results.append({"test": "get_all", "pass": type(prefs) == "dict" and "suite_theme" in prefs})

    # Test 5: Return value from set
    ret = a.user.preference.set("suite_return", "test")
    results.append({"test": "return_value", "pass": ret == "test"})

    # Test 6: Delete
    a.user.preference.set("suite_delete", "to_delete")
    deleted = a.user.preference.delete("suite_delete")
    gone = a.user.preference.get("suite_delete") == None
    results.append({"test": "delete", "pass": deleted and gone})

    # Count passes
    passed = len([r for r in results if r["pass"]])
    total = len(results)

    status = "PASS" if passed == total else "FAIL"
    a.json({"test": "preferences_suite", "status": status, "passed": passed, "total": total, "results": results})
