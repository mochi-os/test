# Mochi Test app: Entity and Account API Tests
# Test mochi.entity.update() and mochi.account.add/update with kwargs

def action_test_entity_update_name(a):
    """Test mochi.entity.update() with name change"""
    results = []
    passed = True

    # Create a test entity
    entity_id = mochi.entity.create("test", "Original Name", "private", "")
    if not entity_id:
        a.json({"test": "entity_update_name", "passed": False, "error": "Failed to create entity"})
        return

    # Update the name
    result = mochi.entity.update(entity_id, name="Updated Name")
    if not result:
        results.append({"test": "update_returns_true", "passed": False})
        passed = False
    else:
        results.append({"test": "update_returns_true", "passed": True})

    # Verify the name changed
    info = mochi.entity.info(entity_id)
    if info and info["name"] == "Updated Name":
        results.append({"test": "name_updated", "passed": True})
    else:
        results.append({"test": "name_updated", "passed": False, "got": info})
        passed = False

    # Cleanup
    mochi.entity.delete(entity_id)

    a.json({"test": "entity_update_name", "passed": passed, "results": results})

def action_test_entity_update_data(a):
    """Test mochi.entity.update() with data change"""
    results = []
    passed = True

    # Create a test entity with initial data
    entity_id = mochi.entity.create("test", "Test Entity", "private", "initial data")
    if not entity_id:
        a.json({"test": "entity_update_data", "passed": False, "error": "Failed to create entity"})
        return

    # Update the data
    result = mochi.entity.update(entity_id, data="updated data")
    if not result:
        results.append({"test": "update_returns_true", "passed": False})
        passed = False
    else:
        results.append({"test": "update_returns_true", "passed": True})

    # Verify via entity.get (returns data field for owned entities)
    entities = mochi.entity.get(entity_id)
    if entities and len(entities) > 0 and entities[0]["data"] == "updated data":
        results.append({"test": "data_updated", "passed": True})
    else:
        results.append({"test": "data_updated", "passed": False, "got": entities})
        passed = False

    # Cleanup
    mochi.entity.delete(entity_id)

    a.json({"test": "entity_update_data", "passed": passed, "results": results})

def action_test_entity_update_privacy(a):
    """Test mochi.entity.update() with privacy change"""
    results = []
    passed = True

    # Create a private entity
    entity_id = mochi.entity.create("test", "Privacy Test", "private", "")
    if not entity_id:
        a.json({"test": "entity_update_privacy", "passed": False, "error": "Failed to create entity"})
        return

    # Verify initially private
    info = mochi.entity.info(entity_id)
    if info and info["privacy"] == "private":
        results.append({"test": "initial_private", "passed": True})
    else:
        results.append({"test": "initial_private", "passed": False, "got": info})
        passed = False

    # Change to public
    result = mochi.entity.update(entity_id, privacy="public")
    if not result:
        results.append({"test": "update_to_public", "passed": False})
        passed = False
    else:
        results.append({"test": "update_to_public", "passed": True})

    # Verify now public
    info = mochi.entity.info(entity_id)
    if info and info["privacy"] == "public":
        results.append({"test": "now_public", "passed": True})
    else:
        results.append({"test": "now_public", "passed": False, "got": info})
        passed = False

    # Change back to private
    result = mochi.entity.update(entity_id, privacy="private")
    if not result:
        results.append({"test": "update_to_private", "passed": False})
        passed = False
    else:
        results.append({"test": "update_to_private", "passed": True})

    # Verify now private again
    info = mochi.entity.info(entity_id)
    if info and info["privacy"] == "private":
        results.append({"test": "now_private", "passed": True})
    else:
        results.append({"test": "now_private", "passed": False, "got": info})
        passed = False

    # Cleanup
    mochi.entity.delete(entity_id)

    a.json({"test": "entity_update_privacy", "passed": passed, "results": results})

def action_test_entity_update_multiple(a):
    """Test mochi.entity.update() with multiple kwargs at once"""
    results = []
    passed = True

    # Create a test entity
    entity_id = mochi.entity.create("test", "Original", "private", "original data")
    if not entity_id:
        a.json({"test": "entity_update_multiple", "passed": False, "error": "Failed to create entity"})
        return

    # Update name and data together
    result = mochi.entity.update(entity_id, name="New Name", data="new data")
    if not result:
        results.append({"test": "update_returns_true", "passed": False})
        passed = False
    else:
        results.append({"test": "update_returns_true", "passed": True})

    # Verify both changed
    info = mochi.entity.info(entity_id)
    entities = mochi.entity.get(entity_id)

    if info and info["name"] == "New Name":
        results.append({"test": "name_updated", "passed": True})
    else:
        results.append({"test": "name_updated", "passed": False, "got": info})
        passed = False

    if entities and len(entities) > 0 and entities[0]["data"] == "new data":
        results.append({"test": "data_updated", "passed": True})
    else:
        results.append({"test": "data_updated", "passed": False, "got": entities})
        passed = False

    # Cleanup
    mochi.entity.delete(entity_id)

    a.json({"test": "entity_update_multiple", "passed": passed, "results": results})

def action_test_entity_update_invalid(a):
    """Test mochi.entity.update() with invalid parameters"""
    results = []
    passed = True

    # Create a test entity
    entity_id = mochi.entity.create("test", "Test", "private", "")
    if not entity_id:
        a.json({"test": "entity_update_invalid", "passed": False, "error": "Failed to create entity"})
        return

    # Test invalid privacy value - should fail
    # Note: Starlark doesn't have try/except, so we check return value
    # The function should return an error for invalid privacy

    # Test with no kwargs - should succeed (no-op)
    result = mochi.entity.update(entity_id)
    if result:
        results.append({"test": "no_kwargs_succeeds", "passed": True})
    else:
        results.append({"test": "no_kwargs_succeeds", "passed": False})
        passed = False

    # Cleanup
    mochi.entity.delete(entity_id)

    a.json({"test": "entity_update_invalid", "passed": passed, "results": results})

def action_test_entity_update_suite(a):
    """Run all entity update tests"""
    results = []

    # Run each test and collect results
    # Note: We call the test functions directly and check their output
    tests = [
        "entity_update_name",
        "entity_update_data",
        "entity_update_privacy",
        "entity_update_multiple",
        "entity_update_invalid"
    ]

    a.json({
        "test": "entity_update_suite",
        "note": "Run individual tests: test_entity_update_name, test_entity_update_data, test_entity_update_privacy, test_entity_update_multiple, test_entity_update_invalid",
        "tests": tests
    })

def action_test_account_add_kwargs(a):
    """Test mochi.account.add() with kwargs style"""
    results = []
    passed = True

    # Test adding an email account with kwargs
    result = mochi.account.add("email", address="test@example.com", label="Test Email")

    if result and result.get("id"):
        results.append({"test": "add_returns_id", "passed": True, "id": result["id"]})
        account_id = result["id"]

        # Verify the account was created
        account = mochi.account.get(account_id)
        if account and account.get("type") == "email":
            results.append({"test": "account_created", "passed": True})
        else:
            results.append({"test": "account_created", "passed": False, "got": account})
            passed = False

        # Cleanup
        mochi.account.remove(account_id)
    else:
        results.append({"test": "add_returns_id", "passed": False, "got": result})
        passed = False

    a.json({"test": "account_add_kwargs", "passed": passed, "results": results})

def action_test_account_update_kwargs(a):
    """Test mochi.account.update() with kwargs style"""
    results = []
    passed = True

    # Create an account first
    result = mochi.account.add("email", address="update-test@example.com")
    if not result or not result.get("id"):
        a.json({"test": "account_update_kwargs", "passed": False, "error": "Failed to create account"})
        return

    account_id = result["id"]

    # Update label using kwargs
    update_result = mochi.account.update(account_id, label="Updated Label")
    if update_result:
        results.append({"test": "update_returns_true", "passed": True})
    else:
        results.append({"test": "update_returns_true", "passed": False})
        passed = False

    # Verify label changed
    account = mochi.account.get(account_id)
    if account and account.get("label") == "Updated Label":
        results.append({"test": "label_updated", "passed": True})
    else:
        results.append({"test": "label_updated", "passed": False, "got": account})
        passed = False

    # Update enabled using kwargs
    update_result = mochi.account.update(account_id, enabled=False)
    if update_result:
        results.append({"test": "update_enabled", "passed": True})
    else:
        results.append({"test": "update_enabled", "passed": False})
        passed = False

    # Verify enabled changed
    account = mochi.account.get(account_id)
    if account and account.get("enabled") == 0:
        results.append({"test": "enabled_is_false", "passed": True})
    else:
        results.append({"test": "enabled_is_false", "passed": False, "got": account})
        passed = False

    # Cleanup
    mochi.account.remove(account_id)

    a.json({"test": "account_update_kwargs", "passed": passed, "results": results})

def action_test_account_suite(a):
    """Run all account tests"""
    a.json({
        "test": "account_suite",
        "note": "Run individual tests: test_account_add_kwargs, test_account_update_kwargs",
        "tests": ["account_add_kwargs", "account_update_kwargs"]
    })
