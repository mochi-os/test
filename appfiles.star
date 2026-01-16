# Mochi Test app: App file API tests
# Tests for mochi.app.file.* and a.write_from_app()

# =============================================================================
# mochi.app.file.exists() tests
# =============================================================================

def action_test_appfile_exists_found(a):
    """Test mochi.app.file.exists() with an existing file"""
    result = mochi.app.file.exists("testdata/sample.txt")
    if result:
        a.json({"test": "appfile_exists_found", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_found", "status": "FAIL", "error": "File should exist but doesn't"})

def action_test_appfile_exists_not_found(a):
    """Test mochi.app.file.exists() with a non-existent file"""
    result = mochi.app.file.exists("testdata/nonexistent.txt")
    if not result:
        a.json({"test": "appfile_exists_not_found", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_not_found", "status": "FAIL", "error": "File should not exist"})

def action_test_appfile_exists_directory(a):
    """Test mochi.app.file.exists() with a directory"""
    result = mochi.app.file.exists("testdata")
    if result:
        a.json({"test": "appfile_exists_directory", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_directory", "status": "FAIL", "error": "Directory should exist"})

def action_test_appfile_exists_nested(a):
    """Test mochi.app.file.exists() with a nested file"""
    result = mochi.app.file.exists("testdata/subdir/nested.txt")
    if result:
        a.json({"test": "appfile_exists_nested", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_nested", "status": "FAIL", "error": "Nested file should exist"})

def action_test_appfile_exists_traversal(a):
    """Test mochi.app.file.exists() rejects path traversal attempts"""
    # These should all return False or be rejected
    tests = [
        "../app.json",
        "testdata/../../../etc/passwd",
        "..\\app.json",
    ]

    for path in tests:
        result = mochi.app.file.exists(path)
        if result:
            a.json({"test": "appfile_exists_traversal", "status": "FAIL", "error": "Path traversal not blocked: " + path})
            return

    a.json({"test": "appfile_exists_traversal", "status": "ok"})

def action_test_appfile_exists_dotfile(a):
    """Test mochi.app.file.exists() rejects paths starting with dot"""
    # Paths starting with . should be rejected by validation
    result = mochi.app.file.exists(".hidden")
    if not result:
        a.json({"test": "appfile_exists_dotfile", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_dotfile", "status": "FAIL", "error": "Dotfile path should be rejected"})

# =============================================================================
# mochi.app.file.list() tests
# =============================================================================

def action_test_appfile_list_directory(a):
    """Test mochi.app.file.list() on a directory"""
    result = mochi.app.file.list("testdata")
    if "sample.txt" in result and "config.json" in result and "subdir" in result:
        a.json({"test": "appfile_list_directory", "status": "ok", "files": result})
    else:
        a.json({"test": "appfile_list_directory", "status": "FAIL", "error": "Expected files not found", "files": result})

def action_test_appfile_list_subdirectory(a):
    """Test mochi.app.file.list() on a subdirectory"""
    result = mochi.app.file.list("testdata/subdir")
    if "nested.txt" in result:
        a.json({"test": "appfile_list_subdirectory", "status": "ok", "files": result})
    else:
        a.json({"test": "appfile_list_subdirectory", "status": "FAIL", "error": "Expected nested.txt not found", "files": result})

def action_test_appfile_list_missing(a):
    """Test mochi.app.file.list() on a non-existent directory returns empty list"""
    result = mochi.app.file.list("nonexistent_directory")
    if len(result) == 0:
        a.json({"test": "appfile_list_missing", "status": "ok"})
    else:
        a.json({"test": "appfile_list_missing", "status": "FAIL", "error": "Should return empty list", "result": result})

def action_test_appfile_list_file(a):
    """Test mochi.app.file.list() on a file (not directory) returns empty list"""
    result = mochi.app.file.list("testdata/sample.txt")
    if len(result) == 0:
        a.json({"test": "appfile_list_file", "status": "ok"})
    else:
        a.json({"test": "appfile_list_file", "status": "FAIL", "error": "Should return empty list for file", "result": result})

def action_test_appfile_list_traversal(a):
    """Test mochi.app.file.list() rejects path traversal attempts"""
    result = mochi.app.file.list("../")
    if len(result) == 0:
        a.json({"test": "appfile_list_traversal", "status": "ok"})
    else:
        a.json({"test": "appfile_list_traversal", "status": "FAIL", "error": "Path traversal not blocked", "result": result})

# =============================================================================
# mochi.app.file.read() tests
# =============================================================================

def action_test_appfile_read_text(a):
    """Test mochi.app.file.read() on a text file"""
    result = mochi.app.file.read("testdata/sample.txt")
    content = str(result)
    if "sample text file" in content:
        a.json({"test": "appfile_read_text", "status": "ok", "length": len(result)})
    else:
        a.json({"test": "appfile_read_text", "status": "FAIL", "error": "Content mismatch", "content": content[:100]})

def action_test_appfile_read_json(a):
    """Test mochi.app.file.read() on a JSON file"""
    result = mochi.app.file.read("testdata/config.json")
    content = str(result)
    if '"name": "test"' in content:
        a.json({"test": "appfile_read_json", "status": "ok"})
    else:
        a.json({"test": "appfile_read_json", "status": "FAIL", "error": "Content mismatch", "content": content})

def action_test_appfile_read_nested(a):
    """Test mochi.app.file.read() on a nested file"""
    result = mochi.app.file.read("testdata/subdir/nested.txt")
    content = str(result)
    if "Nested file content" in content:
        a.json({"test": "appfile_read_nested", "status": "ok"})
    else:
        a.json({"test": "appfile_read_nested", "status": "FAIL", "error": "Content mismatch", "content": content})

def action_test_appfile_read_appjson(a):
    """Test mochi.app.file.read() can read app.json (app's own manifest)"""
    result = mochi.app.file.read("app.json")
    content = str(result)
    if '"version"' in content:
        a.json({"test": "appfile_read_appjson", "status": "ok"})
    else:
        a.json({"test": "appfile_read_appjson", "status": "FAIL", "error": "Could not read app.json"})

def action_test_appfile_read_missing(a):
    """Test mochi.app.file.read() on a non-existent file returns error"""
    # In Starlark, we can't catch exceptions, so this test documents expected behavior
    # The function should return an error when file doesn't exist
    a.json({
        "test": "appfile_read_missing",
        "status": "info",
        "note": "Cannot test error case in Starlark (no try/except). mochi.app.file.read() returns error for missing files."
    })

def action_test_appfile_read_traversal(a):
    """Test mochi.app.file.read() rejects path traversal - documents expected behavior"""
    # Can't test this directly without try/except, but validation should block it
    a.json({
        "test": "appfile_read_traversal",
        "status": "info",
        "note": "Path traversal (../) is blocked by filepath validation. Cannot test error case in Starlark."
    })

# =============================================================================
# a.write_from_app() tests
# =============================================================================

def action_test_write_from_app_text(a):
    """Test a.write_from_app() serves a text file"""
    # This action serves the file directly - test by calling and checking response
    a.write_from_app("testdata/sample.txt")

def action_test_write_from_app_json(a):
    """Test a.write_from_app() serves a JSON file with correct content-type"""
    a.write_from_app("testdata/config.json")

def action_test_write_from_app_nested(a):
    """Test a.write_from_app() serves a nested file"""
    a.write_from_app("testdata/subdir/nested.txt")

def action_test_write_from_app_custom_content_type(a):
    """Test a.write_from_app() respects manually set Content-Type"""
    a.header("Content-Type", "text/plain; charset=utf-8")
    a.write_from_app("testdata/config.json")

def action_test_write_from_app_missing(a):
    """Test a.write_from_app() returns 404 for missing file"""
    a.write_from_app("testdata/nonexistent.txt")

def action_test_write_from_app_traversal(a):
    """Test a.write_from_app() rejects path traversal"""
    # Should return 400 Bad Request for invalid path
    a.write_from_app("../app.json")

# =============================================================================
# Test suites
# =============================================================================

def action_test_appfile_exists_suite(a):
    """Run all mochi.app.file.exists() tests"""
    results = []

    # exists found
    r = mochi.app.file.exists("testdata/sample.txt")
    results.append({"test": "exists_found", "passed": r == True})

    # exists not found
    r = mochi.app.file.exists("testdata/nonexistent.txt")
    results.append({"test": "exists_not_found", "passed": r == False})

    # exists directory
    r = mochi.app.file.exists("testdata")
    results.append({"test": "exists_directory", "passed": r == True})

    # exists nested
    r = mochi.app.file.exists("testdata/subdir/nested.txt")
    results.append({"test": "exists_nested", "passed": r == True})

    # exists traversal blocked
    r = mochi.app.file.exists("../app.json")
    results.append({"test": "exists_traversal_blocked", "passed": r == False})

    # exists dotfile blocked
    r = mochi.app.file.exists(".git")
    results.append({"test": "exists_dotfile_blocked", "passed": r == False})

    passed = len([r for r in results if r["passed"]])
    total = len(results)

    a.json({
        "test": "appfile_exists_suite",
        "status": "ok" if passed == total else "FAIL",
        "passed": passed,
        "total": total,
        "results": results
    })

def action_test_appfile_list_suite(a):
    """Run all mochi.app.file.list() tests"""
    results = []

    # list directory
    r = mochi.app.file.list("testdata")
    results.append({"test": "list_directory", "passed": "sample.txt" in r and "config.json" in r})

    # list subdirectory
    r = mochi.app.file.list("testdata/subdir")
    results.append({"test": "list_subdirectory", "passed": "nested.txt" in r})

    # list missing returns empty
    r = mochi.app.file.list("nonexistent")
    results.append({"test": "list_missing", "passed": len(r) == 0})

    # list file returns empty
    r = mochi.app.file.list("testdata/sample.txt")
    results.append({"test": "list_file", "passed": len(r) == 0})

    # list traversal blocked
    r = mochi.app.file.list("../")
    results.append({"test": "list_traversal_blocked", "passed": len(r) == 0})

    passed = len([r for r in results if r["passed"]])
    total = len(results)

    a.json({
        "test": "appfile_list_suite",
        "status": "ok" if passed == total else "FAIL",
        "passed": passed,
        "total": total,
        "results": results
    })

def action_test_appfile_read_suite(a):
    """Run all mochi.app.file.read() tests"""
    results = []

    # read text file
    r = mochi.app.file.read("testdata/sample.txt")
    results.append({"test": "read_text", "passed": "sample text file" in str(r)})

    # read json file
    r = mochi.app.file.read("testdata/config.json")
    results.append({"test": "read_json", "passed": '"name": "test"' in str(r)})

    # read nested file
    r = mochi.app.file.read("testdata/subdir/nested.txt")
    results.append({"test": "read_nested", "passed": "Nested file content" in str(r)})

    # read app.json
    r = mochi.app.file.read("app.json")
    results.append({"test": "read_appjson", "passed": '"version"' in str(r)})

    passed = len([r for r in results if r["passed"]])
    total = len(results)

    a.json({
        "test": "appfile_read_suite",
        "status": "ok" if passed == total else "FAIL",
        "passed": passed,
        "total": total,
        "results": results
    })

def action_test_appfile_suite(a):
    """Run all app file API tests"""
    results = []

    # === exists tests ===
    r = mochi.app.file.exists("testdata/sample.txt")
    results.append({"test": "exists_found", "passed": r == True})

    r = mochi.app.file.exists("testdata/nonexistent.txt")
    results.append({"test": "exists_not_found", "passed": r == False})

    r = mochi.app.file.exists("testdata")
    results.append({"test": "exists_directory", "passed": r == True})

    r = mochi.app.file.exists("testdata/subdir/nested.txt")
    results.append({"test": "exists_nested", "passed": r == True})

    r = mochi.app.file.exists("../app.json")
    results.append({"test": "exists_traversal_blocked", "passed": r == False})

    r = mochi.app.file.exists(".git")
    results.append({"test": "exists_dotfile_blocked", "passed": r == False})

    # === list tests ===
    r = mochi.app.file.list("testdata")
    results.append({"test": "list_directory", "passed": "sample.txt" in r and "config.json" in r})

    r = mochi.app.file.list("testdata/subdir")
    results.append({"test": "list_subdirectory", "passed": "nested.txt" in r})

    r = mochi.app.file.list("nonexistent")
    results.append({"test": "list_missing", "passed": len(r) == 0})

    r = mochi.app.file.list("testdata/sample.txt")
    results.append({"test": "list_file_not_dir", "passed": len(r) == 0})

    r = mochi.app.file.list("../")
    results.append({"test": "list_traversal_blocked", "passed": len(r) == 0})

    # === read tests ===
    r = mochi.app.file.read("testdata/sample.txt")
    results.append({"test": "read_text", "passed": "sample text file" in str(r)})

    r = mochi.app.file.read("testdata/config.json")
    results.append({"test": "read_json", "passed": '"name": "test"' in str(r)})

    r = mochi.app.file.read("testdata/subdir/nested.txt")
    results.append({"test": "read_nested", "passed": "Nested file content" in str(r)})

    r = mochi.app.file.read("app.json")
    results.append({"test": "read_appjson", "passed": '"version"' in str(r)})

    passed = len([r for r in results if r["passed"]])
    total = len(results)

    a.json({
        "test": "appfile_suite",
        "status": "ok" if passed == total else "FAIL",
        "passed": passed,
        "total": total,
        "results": results
    })

# =============================================================================
# P2P streaming tests (e.write_from_app / s.write_from_app)
# =============================================================================

def event_appfile_stream(e):
    """Event handler that streams an app file back to the caller.
    Expects e.content("path") to specify which file to stream."""
    path = e.content("path")
    if not path:
        path = "testdata/sample.txt"
    e.write_from_app(path)

def action_test_appfile_p2p_stream(a):
    """Test P2P streaming of app files.
    Sends a request to another instance to stream back a file.
    Requires 'to' parameter with entity ID from other instance."""
    to = a.input("to")
    path = a.input("path", "testdata/sample.txt")

    identity_id = a.user.identity.id if a.user.identity else None

    if not to:
        a.json({
            "test": "appfile_p2p_stream",
            "status": "info",
            "error": "Missing 'to' parameter - provide entity ID from other instance",
            "note": "This test requires two instances. Run with ?to=<entity_id>&path=<file_path>"
        })
        return

    if not identity_id:
        a.json({
            "test": "appfile_p2p_stream",
            "status": "FAIL",
            "error": "No identity - cannot send P2P message"
        })
        return

    # Send request to stream the file
    headers = {
        "from": identity_id,
        "to": to,
        "service": "test",
        "event": "appfile_stream"
    }
    content = {
        "path": path
    }

    result = mochi.message.send(headers, content)

    a.json({
        "test": "appfile_p2p_stream",
        "status": "ok",
        "from": identity_id,
        "to": to,
        "path": path,
        "note": "Request sent - file will be streamed back via P2P"
    })
