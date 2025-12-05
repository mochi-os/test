# Mochi Claude Test app: Core functions
# Database setup, basic actions, events, and utility tests

def database_create():
    """Create test database schema"""
    mochi.db.query("create table test ( id text primary key, value text )")

def action_index(a):
    """Show test app status and controls"""
    identity = a.user.identity
    a.json({
        "app": "claude-test",
        "identity": identity.id,
        "user": a.user.username
    })

def action_send(a):
    """Send a test message to another entity"""
    to = a.input("to")
    msg = a.input("msg", "ping")

    if not to:
        a.error(400, "missing 'to' parameter")
        return

    headers = {
        "from": a.user.identity.id,
        "to": to,
        "service": "claude-test",
        "event": "ping"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    result = mochi.message.send(headers, content)
    a.json({"sent": True, "result": result, "to": to, "message": msg})

def action_status(a):
    """Return server status info"""
    a.json({
        "identity": a.user.identity.id,
        "time": mochi.time.now()
    })

def action_ping(a):
    """Send a ping without authentication (accepts from parameter)"""
    from_id = a.input("from")
    to = a.input("to")
    msg = a.input("msg", "ping")

    if not from_id:
        a.error(400, "missing 'from' parameter")
        return
    if not to:
        a.error(400, "missing 'to' parameter")
        return

    headers = {
        "from": from_id,
        "to": to,
        "service": "claude-test",
        "event": "ping"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    result = mochi.message.send(headers, content)
    a.json({"sent": True, "result": result, "from": from_id, "to": to, "message": msg})

def event_ping(e):
    """Handle incoming ping event"""
    print("Claude Test: Received ping from", e.header("from"), "message:", e.content("message"))

    # Send pong reply
    headers = {
        "from": e.header("to"),
        "to": e.header("from"),
        "service": "claude-test",
        "event": "pong"
    }
    content = {
        "message": "pong",
        "original": e.content("message"),
        "time": mochi.time.now()
    }
    mochi.message.send(headers, content)

def event_pong(e):
    """Handle incoming pong response"""
    print("Claude Test: Received pong from", e.header("from"), "original:", e.content("original"))

def action_broadcast(a):
    """Publish a broadcast message to all peers"""
    msg = a.input("msg", "hello")

    headers = {
        "from": a.user.identity.id,
        "service": "claude-test",
        "event": "broadcast"
    }
    content = {
        "message": msg,
        "time": mochi.time.now()
    }

    mochi.message.publish(headers, content)
    a.json({"published": True, "from": a.user.identity.id, "message": msg})

def event_broadcast(e):
    """Handle incoming broadcast event"""
    print("Claude Test: Received broadcast from", e.header("from"), "message:", e.content("message"))

def action_test_broadcast(a):
    """Test broadcast without authentication"""
    msg = a.input("msg", "test_broadcast")

    headers = {
        "from": "",
        "service": "claude-test",
        "event": "broadcast"
    }
    content = {
        "message": msg,
        "time": mochi.time.now(),
        "number": 42
    }

    mochi.message.publish(headers, content)
    a.json({"published": True, "message": msg})

def action_test_attach(a):
    """Test that ATTACH is blocked - should fail with authorization error"""
    # This should fail with an authorization error if the security is working
    result = mochi.db.query("ATTACH DATABASE '../../../db/users.db' AS users_db")
    a.json({"blocked": False, "result": result, "error": "ATTACH was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_detach(a):
    """Test that DETACH is blocked - should fail with authorization error"""
    # This should fail with an authorization error if the security is working
    result = mochi.db.query("DETACH DATABASE main")
    a.json({"blocked": False, "result": result, "error": "DETACH was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_storage_limit(a):
    """Test file storage limit by writing 1GB of data.
    Writes 10 x 100MB files (1000MB total), then tries an 11th.
    The 11th file should fail with 'storage limit exceeded' if limits work."""
    chunk_size = 100 * 1024 * 1024  # 100MB per file
    chunk = "X" * chunk_size

    # Write 10 x 100MB files = 1000MB
    for i in range(10):
        filename = "storage_test/chunk" + str(i) + ".bin"
        mochi.file.write(filename, chunk)

    # Try to write one more 100MB file - should fail if limit is 1GB
    # If this succeeds, the limit is not working!
    mochi.file.write("storage_test/chunk_overflow.bin", chunk)
    a.json({"test": "storage_limit", "status": "FAIL", "error": "11th file succeeded - limit not enforced!"})

def action_test_storage_cleanup(a):
    """Clean up storage test files"""
    for i in range(11):
        filename = "storage_test/chunk" + str(i) + ".bin"
        mochi.file.delete(filename)
    mochi.file.delete("storage_test/chunk_overflow.bin")
    a.json({"cleaned": True})

def action_test_db_limit(a):
    """Test database storage limit by inserting data until full.
    Inserts 4KB rows. With 1GB limit (~262144 pages of 4KB), should fail around 250k rows."""
    # Create test table if not exists
    mochi.db.query("CREATE TABLE IF NOT EXISTS db_limit_test (id INTEGER PRIMARY KEY, data TEXT)")

    # Insert 4KB rows until database is full
    chunk = "X" * 4096

    # Insert 300k rows (~1.2GB) - should fail before completing if limit works
    for i in range(300000):
        mochi.db.query("INSERT INTO db_limit_test (data) VALUES (?)", chunk)
        if i % 10000 == 0:
            print("Inserted", i, "rows...")

    # If we get here, the limit didn't work
    rows = mochi.db.query("SELECT COUNT(*) as count FROM db_limit_test")
    a.json({"test": "db_limit", "status": "FAIL", "rows": rows[0]["count"], "error": "Inserted 300k rows without hitting limit!"})

def action_test_db_cleanup(a):
    """Clean up database test table"""
    mochi.db.query("DROP TABLE IF EXISTS db_limit_test")
    a.json({"cleaned": True})

def action_test_p2p_rate_limit(a):
    """Test P2P message send rate limiting.
    Note: Starlark doesn't support try/except. Rate limiting is tested via Go unit tests.
    This action just documents that rate limiting exists (20 msg/sec/app)."""
    a.json({
        "test": "p2p_rate_limit",
        "note": "Rate limiting (20 msg/sec/app) is enforced at Go level and tested via Go unit tests",
        "limit": 20,
        "window_seconds": 1
    })

# Cookie tests

def action_test_cookie_set(a):
    """Test setting a cookie"""
    name = a.input("name", "test_cookie")
    value = a.input("value", "test_value")
    a.cookie.set(name, value)
    a.json({"test": "cookie_set", "status": "ok", "name": name, "value": value})

def action_test_cookie_get(a):
    """Test getting a cookie"""
    name = a.input("name", "test_cookie")
    default = a.input("default", "")
    value = a.cookie.get(name, default)
    a.json({"test": "cookie_get", "status": "ok", "name": name, "value": value})

def action_test_cookie_unset(a):
    """Test unsetting a cookie"""
    name = a.input("name", "test_cookie")
    a.cookie.unset(name)
    a.json({"test": "cookie_unset", "status": "ok", "name": name})
