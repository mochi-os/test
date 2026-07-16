# Copyright © 2026 Mochisoft OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Mochi Test app: App file API tests
# Tests for mochi.app.asset.* and a.write.asset()

# =============================================================================
# mochi.app.asset.exists() tests
# =============================================================================

def action_test_appfile_exists_found(a):
    """Test mochi.app.asset.exists() with an existing file"""
    result = mochi.app.asset.exists("testdata/sample.txt")
    if result:
        a.json({"test": "appfile_exists_found", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_found", "status": "FAIL", "error": "File should exist but doesn't"})

def action_test_appfile_exists_not_found(a):
    """Test mochi.app.asset.exists() with a non-existent file"""
    result = mochi.app.asset.exists("testdata/nonexistent.txt")
    if not result:
        a.json({"test": "appfile_exists_not_found", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_not_found", "status": "FAIL", "error": "File should not exist"})

def action_test_appfile_exists_directory(a):
    """Test mochi.app.asset.exists() with a directory"""
    result = mochi.app.asset.exists("testdata")
    if result:
        a.json({"test": "appfile_exists_directory", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_directory", "status": "FAIL", "error": "Directory should exist"})

def action_test_appfile_exists_nested(a):
    """Test mochi.app.asset.exists() with a nested file"""
    result = mochi.app.asset.exists("testdata/subdir/nested.txt")
    if result:
        a.json({"test": "appfile_exists_nested", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_nested", "status": "FAIL", "error": "Nested file should exist"})

def action_test_appfile_exists_traversal(a):
    """Test mochi.app.asset.exists() rejects path traversal attempts"""
    # These should all return False or be rejected
    tests = [
        "../app.json",
        "testdata/../../../etc/passwd",
        "..\\app.json",
    ]

    for path in tests:
        result = mochi.app.asset.exists(path)
        if result:
            a.json({"test": "appfile_exists_traversal", "status": "FAIL", "error": "Path traversal not blocked: " + path})
            return

    a.json({"test": "appfile_exists_traversal", "status": "ok"})

def action_test_appfile_exists_dotfile(a):
    """Test mochi.app.asset.exists() rejects paths starting with dot"""
    # Paths starting with . should be rejected by validation
    result = mochi.app.asset.exists(".hidden")
    if not result:
        a.json({"test": "appfile_exists_dotfile", "status": "ok"})
    else:
        a.json({"test": "appfile_exists_dotfile", "status": "FAIL", "error": "Dotfile path should be rejected"})

# =============================================================================
# mochi.app.asset.list() tests
# =============================================================================

def action_test_appfile_list_directory(a):
    """Test mochi.app.asset.list() on a directory"""
    result = mochi.app.asset.list("testdata")
    if "sample.txt" in result and "config.json" in result and "subdir" in result:
        a.json({"test": "appfile_list_directory", "status": "ok", "files": result})
    else:
        a.json({"test": "appfile_list_directory", "status": "FAIL", "error": "Expected files not found", "files": result})

def action_test_appfile_list_subdirectory(a):
    """Test mochi.app.asset.list() on a subdirectory"""
    result = mochi.app.asset.list("testdata/subdir")
    if "nested.txt" in result:
        a.json({"test": "appfile_list_subdirectory", "status": "ok", "files": result})
    else:
        a.json({"test": "appfile_list_subdirectory", "status": "FAIL", "error": "Expected nested.txt not found", "files": result})

def action_test_appfile_list_missing(a):
    """Test mochi.app.asset.list() on a non-existent directory returns empty list"""
    result = mochi.app.asset.list("nonexistent_directory")
    if len(result) == 0:
        a.json({"test": "appfile_list_missing", "status": "ok"})
    else:
        a.json({"test": "appfile_list_missing", "status": "FAIL", "error": "Should return empty list", "result": result})

def action_test_appfile_list_file(a):
    """Test mochi.app.asset.list() on a file (not directory) returns empty list"""
    result = mochi.app.asset.list("testdata/sample.txt")
    if len(result) == 0:
        a.json({"test": "appfile_list_file", "status": "ok"})
    else:
        a.json({"test": "appfile_list_file", "status": "FAIL", "error": "Should return empty list for file", "result": result})

def action_test_appfile_list_traversal(a):
    """Test mochi.app.asset.list() rejects path traversal attempts"""
    result = mochi.app.asset.list("../")
    if len(result) == 0:
        a.json({"test": "appfile_list_traversal", "status": "ok"})
    else:
        a.json({"test": "appfile_list_traversal", "status": "FAIL", "error": "Path traversal not blocked", "result": result})

# =============================================================================
# mochi.app.asset.read() tests
# =============================================================================

def action_test_appfile_read_text(a):
    """Test mochi.app.asset.read() on a text file"""
    result = mochi.app.asset.read("testdata/sample.txt")
    content = str(result)
    if "sample text file" in content:
        a.json({"test": "appfile_read_text", "status": "ok", "length": len(result)})
    else:
        a.json({"test": "appfile_read_text", "status": "FAIL", "error": "Content mismatch", "content": content[:100]})

def action_test_appfile_read_json(a):
    """Test mochi.app.asset.read() on a JSON file"""
    result = mochi.app.asset.read("testdata/config.json")
    content = str(result)
    if '"name": "test"' in content:
        a.json({"test": "appfile_read_json", "status": "ok"})
    else:
        a.json({"test": "appfile_read_json", "status": "FAIL", "error": "Content mismatch", "content": content})

def action_test_appfile_read_nested(a):
    """Test mochi.app.asset.read() on a nested file"""
    result = mochi.app.asset.read("testdata/subdir/nested.txt")
    content = str(result)
    if "Nested file content" in content:
        a.json({"test": "appfile_read_nested", "status": "ok"})
    else:
        a.json({"test": "appfile_read_nested", "status": "FAIL", "error": "Content mismatch", "content": content})

def action_test_appfile_read_appjson(a):
    """Test mochi.app.asset.read() can read app.json (app's own manifest)"""
    result = mochi.app.asset.read("app.json")
    content = str(result)
    if '"version"' in content:
        a.json({"test": "appfile_read_appjson", "status": "ok"})
    else:
        a.json({"test": "appfile_read_appjson", "status": "FAIL", "error": "Could not read app.json"})

def action_test_appfile_read_missing(a):
    """Test mochi.app.asset.read() on a non-existent file returns error"""
    # In Starlark, we can't catch exceptions, so this test documents expected behavior
    # The function should return an error when file doesn't exist
    a.json({
        "test": "appfile_read_missing",
        "status": "info",
        "note": "Cannot test error case in Starlark (no try/except). mochi.app.asset.read() returns error for missing files."
    })

def action_test_appfile_read_traversal(a):
    """Test mochi.app.asset.read() rejects path traversal - documents expected behavior"""
    # Can't test this directly without try/except, but validation should block it
    a.json({
        "test": "appfile_read_traversal",
        "status": "info",
        "note": "Path traversal (../) is blocked by filepath validation. Cannot test error case in Starlark."
    })

# =============================================================================
# a.write.asset() tests
# =============================================================================

def action_test_write_from_app_text(a):
    """Test a.write.asset() serves a text file"""
    # This action serves the file directly - test by calling and checking response
    a.write.asset("testdata/sample.txt")

def action_test_write_from_app_json(a):
    """Test a.write.asset() serves a JSON file with correct content-type"""
    a.write.asset("testdata/config.json")

def action_test_write_from_app_nested(a):
    """Test a.write.asset() serves a nested file"""
    a.write.asset("testdata/subdir/nested.txt")

def action_test_write_from_app_custom_content_type(a):
    """Test a.write.asset() respects manually set Content-Type"""
    a.header("Content-Type", "text/plain; charset=utf-8")
    a.write.asset("testdata/config.json")

def action_test_write_from_app_missing(a):
    """Test a.write.asset() returns 404 for missing file"""
    a.write.asset("testdata/nonexistent.txt")

def action_test_write_from_app_traversal(a):
    """Test a.write.asset() rejects path traversal"""
    # Should return 400 Bad Request for invalid path
    a.write.asset("../app.json")

# =============================================================================
# Test suites
# =============================================================================

def action_test_appfile_exists_suite(a):
    """Run all mochi.app.asset.exists() tests"""
    results = []

    # exists found
    r = mochi.app.asset.exists("testdata/sample.txt")
    results.append({"test": "exists_found", "passed": r == True})

    # exists not found
    r = mochi.app.asset.exists("testdata/nonexistent.txt")
    results.append({"test": "exists_not_found", "passed": r == False})

    # exists directory
    r = mochi.app.asset.exists("testdata")
    results.append({"test": "exists_directory", "passed": r == True})

    # exists nested
    r = mochi.app.asset.exists("testdata/subdir/nested.txt")
    results.append({"test": "exists_nested", "passed": r == True})

    # exists traversal blocked
    r = mochi.app.asset.exists("../app.json")
    results.append({"test": "exists_traversal_blocked", "passed": r == False})

    # exists dotfile blocked
    r = mochi.app.asset.exists(".git")
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
    """Run all mochi.app.asset.list() tests"""
    results = []

    # list directory
    r = mochi.app.asset.list("testdata")
    results.append({"test": "list_directory", "passed": "sample.txt" in r and "config.json" in r})

    # list subdirectory
    r = mochi.app.asset.list("testdata/subdir")
    results.append({"test": "list_subdirectory", "passed": "nested.txt" in r})

    # list missing returns empty
    r = mochi.app.asset.list("nonexistent")
    results.append({"test": "list_missing", "passed": len(r) == 0})

    # list file returns empty
    r = mochi.app.asset.list("testdata/sample.txt")
    results.append({"test": "list_file", "passed": len(r) == 0})

    # list traversal blocked
    r = mochi.app.asset.list("../")
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
    """Run all mochi.app.asset.read() tests"""
    results = []

    # read text file
    r = mochi.app.asset.read("testdata/sample.txt")
    results.append({"test": "read_text", "passed": "sample text file" in str(r)})

    # read json file
    r = mochi.app.asset.read("testdata/config.json")
    results.append({"test": "read_json", "passed": '"name": "test"' in str(r)})

    # read nested file
    r = mochi.app.asset.read("testdata/subdir/nested.txt")
    results.append({"test": "read_nested", "passed": "Nested file content" in str(r)})

    # read app.json
    r = mochi.app.asset.read("app.json")
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
    r = mochi.app.asset.exists("testdata/sample.txt")
    results.append({"test": "exists_found", "passed": r == True})

    r = mochi.app.asset.exists("testdata/nonexistent.txt")
    results.append({"test": "exists_not_found", "passed": r == False})

    r = mochi.app.asset.exists("testdata")
    results.append({"test": "exists_directory", "passed": r == True})

    r = mochi.app.asset.exists("testdata/subdir/nested.txt")
    results.append({"test": "exists_nested", "passed": r == True})

    r = mochi.app.asset.exists("../app.json")
    results.append({"test": "exists_traversal_blocked", "passed": r == False})

    r = mochi.app.asset.exists(".git")
    results.append({"test": "exists_dotfile_blocked", "passed": r == False})

    # === list tests ===
    r = mochi.app.asset.list("testdata")
    results.append({"test": "list_directory", "passed": "sample.txt" in r and "config.json" in r})

    r = mochi.app.asset.list("testdata/subdir")
    results.append({"test": "list_subdirectory", "passed": "nested.txt" in r})

    r = mochi.app.asset.list("nonexistent")
    results.append({"test": "list_missing", "passed": len(r) == 0})

    r = mochi.app.asset.list("testdata/sample.txt")
    results.append({"test": "list_file_not_dir", "passed": len(r) == 0})

    r = mochi.app.asset.list("../")
    results.append({"test": "list_traversal_blocked", "passed": len(r) == 0})

    # === read tests ===
    r = mochi.app.asset.read("testdata/sample.txt")
    results.append({"test": "read_text", "passed": "sample text file" in str(r)})

    r = mochi.app.asset.read("testdata/config.json")
    results.append({"test": "read_json", "passed": '"name": "test"' in str(r)})

    r = mochi.app.asset.read("testdata/subdir/nested.txt")
    results.append({"test": "read_nested", "passed": "Nested file content" in str(r)})

    r = mochi.app.asset.read("app.json")
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
# P2P streaming tests (e.write.asset / s.write.asset)
# =============================================================================

def event_appfile_stream(e):
    """Event handler that streams an app file back to the caller.
    Expects e.content("path") to specify which file to stream."""
    path = e.content("path")
    if not path:
        path = "testdata/sample.txt"
    e.write.asset(path)

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
