# Mochi Claude Test app: Core functions
# Database setup, basic actions, events, and utility tests

def database_create():
    """Create test database schema"""
    mochi.db.execute("create table test ( id text primary key, value text )")
    mochi.db.execute("create table test_excluded ( id text primary key, value text )")

def database_upgrade(version):
    if version == 3:
        mochi.db.execute("create table if not exists test_excluded ( id text primary key, value text )")
    if version == 4:
        # Stage 16: add an extra column so an op emitted at schema 4
        # can be tested against a receiver still at schema 3 (deferred
        # until the receiver migrates and drains pending).
        if not mochi.db.row("select 1 from pragma_table_info('test') where name = 'extra'"):
            mochi.db.execute("alter table test add column extra text not null default ''")
    if version == 5:
        # Stage 20: a trivial bump so a test-app op emitted at schema 5
        # defers on a receiver still at schema 4 — exercises per-DB
        # stream independence (the deferred test stream must not stall
        # other apps' streams).
        if not mochi.db.row("select 1 from pragma_table_info('test') where name = 'note'"):
            mochi.db.execute("alter table test add column note text not null default ''")

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

def action_replication_write(a):
    id = a.input("id")
    value = a.input("value")
    if not id or not value:
        a.error(400, "missing id or value")
        return
    mochi.db.execute("insert into test (id, value) values (?, ?)", id, value)
    a.json({"ok": True, "id": id, "value": value})

def action_replication_read(a):
    id = a.input("id")
    if not id:
        a.error(400, "missing id")
        return
    row = mochi.db.row("select value from test where id = ?", id)
    a.json({"id": id, "value": row["value"] if row else None})

def action_replication_update(a):
    id = a.input("id")
    value = a.input("value")
    if not id or not value:
        a.error(400, "missing id or value")
        return
    mochi.db.execute("update test set value = ? where id = ?", value, id)
    a.json({"ok": True, "id": id, "value": value})

def action_replication_delete(a):
    id = a.input("id")
    if not id:
        a.error(400, "missing id")
        return
    mochi.db.execute("delete from test where id = ?", id)
    a.json({"ok": True, "id": id})

def action_replication_excluded_write(a):
    id = a.input("id")
    value = a.input("value")
    if not id or not value:
        a.error(400, "missing id or value")
        return
    mochi.db.execute("insert into test_excluded (id, value) values (?, ?)", id, value)
    a.json({"ok": True, "id": id, "value": value})

# Stage 14: Transactions — verify the deferred-emit-on-commit model.
# Each entry point inserts a known id prefix so the cross-instance
# inspector can scope its check, and avoids polluting the table for
# unrelated tests.

def action_replication_transaction_commit(a):
    """Insert two rows in a single tx and commit. Both rows should
    replicate to the other host."""
    mochi.db.execute("delete from test where id like 'tx-commit-%'")
    t = mochi.db.transaction()
    t.execute("insert into test (id, value) values (?, ?)", "tx-commit-a", "A")
    t.execute("insert into test (id, value) values (?, ?)", "tx-commit-b", "B")
    t.commit()
    rows = mochi.db.rows("select id, value from test where id like 'tx-commit-%' order by id")
    a.json({"committed": True, "rows": rows})

def action_replication_transaction_rollback(a):
    """Insert in a tx then explicitly roll back. Nothing should
    replicate to the other host."""
    mochi.db.execute("delete from test where id like 'tx-rollback-%'")
    t = mochi.db.transaction()
    t.execute("insert into test (id, value) values (?, ?)", "tx-rollback-a", "A")
    t.rollback()
    rows = mochi.db.rows("select id, value from test where id like 'tx-rollback-%' order by id")
    a.json({"committed": False, "rows": rows})

def action_replication_transaction_fail(a):
    """Insert row A, attempt an insert that violates the primary-key
    constraint, let the resulting error propagate so the action
    tear-down auto-rolls back the tx. Nothing should land locally or
    replicate."""
    mochi.db.execute("delete from test where id like 'tx-fail-%'")
    t = mochi.db.transaction()
    t.execute("insert into test (id, value) values (?, ?)", "tx-fail-a", "A")
    # Same primary key: constraint violation propagates out of t.execute,
    # so the action handler exits with an error and the tear-down rolls
    # the transaction back. No commit() reached.
    t.execute("insert into test (id, value) values (?, ?)", "tx-fail-a", "duplicate")
    # Not reached.
    a.json({"unreachable": True})

def action_replication_transaction_inspect(a):
    """Read back the tx-* rows so cross-instance checks can compare."""
    rows = mochi.db.rows("select id, value from test where id like 'tx-%' order by id")
    a.json({"rows": rows})

# Stage 16: schema-bump defer/wake-up
def action_replication_schema_write(a):
    """Insert a row that uses the schema-4 'extra' column. Emitted at
    schema 4; receivers still on schema 3 must defer until they
    upgrade and drain pending."""
    id = a.input("id")
    value = a.input("value", "")
    extra = a.input("extra", "")
    if not id:
        a.error(400, "missing id")
        return
    mochi.db.execute("insert into test (id, value, extra) values (?, ?, ?)", id, value, extra)
    a.json({"ok": True, "id": id, "value": value, "extra": extra})

def action_replication_schema_inspect(a):
    """Read back schema-* rows for cross-instance checks. Returns
    both columns so a receiver that's missing the 'extra' column
    surfaces the gap as a SQL error rather than silently dropping it."""
    rows = mochi.db.rows("select id, value, extra from test where id like 'schema-%' order by id")
    a.json({"rows": rows})

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

def event_services_check(e):
    """Return the sender's services header back via stream"""
    services = e.header("services")
    app = e.header("app")
    e.write({"app": app, "services": services})

def action_test_services_header(a):
    """Test that the P2P services header is populated correctly"""
    identity = a.user.identity
    if not identity:
        a.json({"passed": False, "error": "no identity"})
        return

    # Send a P2P request to ourselves
    result = mochi.remote.request(identity.id, "test", "services_check", {})
    if not result or "error" in result:
        a.json({"passed": False, "error": "request failed", "result": result})
        return

    services = result.get("services", None)
    app = result.get("app", "")

    # The test app declares service "test", and should be the active handler
    passed = True
    results = []

    # Check services is a tuple/list containing "test"
    if services and "test" in services:
        results.append({"test": "services_contains_test", "passed": True, "services": services})
    else:
        results.append({"test": "services_contains_test", "passed": False, "got": services})
        passed = False

    # Check app header is set
    if app:
        results.append({"test": "app_header_set", "passed": True, "app": app})
    else:
        results.append({"test": "app_header_set", "passed": False, "got": app})
        passed = False

    a.json({"passed": passed, "results": results})

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
    result = mochi.db.execute("ATTACH DATABASE '../../../db/users.db' AS users_db")
    a.json({"blocked": False, "result": result, "error": "ATTACH was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_detach(a):
    """Test that DETACH is blocked - should fail with authorization error"""
    # This should fail with an authorization error if the security is working
    result = mochi.db.execute("DETACH DATABASE main")
    a.json({"blocked": False, "result": result, "error": "DETACH was NOT blocked - SECURITY VULNERABILITY!"})

# ----------------------------------------------------------------------
# Starlark-pool authoriser policy tests.
#
# The Starlark connection pool installs an authoriser that denies
# ATTACH, DETACH, PRAGMA writes, triggers, and virtual table creation.
# VACUUM and ANALYZE are caught at the api-layer string-prefix gate.
# Allowed operations cover ordinary CRUD, schema (CREATE/DROP TABLE/
# INDEX/VIEW, ALTER TABLE), and transactions / savepoints.
#
# Because Starlark has no try/except, a denied SQL call raises an
# error that aborts the action. So each denied case is its own
# endpoint: if the action reaches a.json(), the denial leaked and
# the test reports FAIL — otherwise the action errors out (5xx) and
# the test runner treats that as PASS.
#
# Allowed operations are bundled into one endpoint that runs them
# sequentially and returns the count of successful steps.

# ---- denied: PRAGMA writes ----

def action_test_authoriser_pragma_write(a):
    """PRAGMA writes (with argument) must be denied."""
    mochi.db.execute("PRAGMA max_page_count = 999999999")
    a.json({"status": "FAIL", "error": "PRAGMA write was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_authoriser_pragma_multistmt(a):
    """`BEGIN; PRAGMA write; COMMIT;` must still be denied per-statement."""
    mochi.db.execute("BEGIN; PRAGMA max_page_count = 999999999; COMMIT")
    a.json({"status": "FAIL", "error": "multi-statement PRAGMA write was NOT blocked - SECURITY VULNERABILITY!"})

# ---- denied: triggers / virtual tables ----

def action_test_authoriser_create_trigger(a):
    """CREATE TRIGGER must be denied."""
    mochi.db.execute("CREATE TABLE IF NOT EXISTS auth_test (id INTEGER PRIMARY KEY, name TEXT)")
    mochi.db.execute("CREATE TRIGGER auth_test_trg AFTER INSERT ON auth_test BEGIN UPDATE auth_test SET name='x'; END")
    a.json({"status": "FAIL", "error": "CREATE TRIGGER was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_authoriser_create_vtable(a):
    """CREATE VIRTUAL TABLE must be denied."""
    mochi.db.execute("CREATE VIRTUAL TABLE auth_test_vt USING fts5(content)")
    a.json({"status": "FAIL", "error": "CREATE VIRTUAL TABLE was NOT blocked - SECURITY VULNERABILITY!"})

# ---- denied: VACUUM / ANALYZE (string-prefix gate) ----

def action_test_authoriser_vacuum(a):
    """VACUUM must be denied at the api-layer string-prefix gate."""
    mochi.db.execute("VACUUM")
    a.json({"status": "FAIL", "error": "VACUUM was NOT blocked - SECURITY VULNERABILITY!"})

def action_test_authoriser_analyze(a):
    """ANALYZE must be denied at the api-layer string-prefix gate."""
    mochi.db.execute("ANALYZE")
    a.json({"status": "FAIL", "error": "ANALYZE was NOT blocked - SECURITY VULNERABILITY!"})

# ---- allowed: ordinary CRUD, schema, transactions ----

def action_test_authoriser_allowed(a):
    """Run every legitimate SQL operation a Starlark app might use.
    Reaches a.json() only if everything succeeded."""
    # Clean slate.
    mochi.db.execute("DROP TABLE IF EXISTS auth_allowed")
    mochi.db.execute("DROP TABLE IF EXISTS auth_allowed_extra")
    mochi.db.execute("DROP VIEW IF EXISTS auth_allowed_view")

    steps = []

    # ----- DDL -----
    mochi.db.execute("CREATE TABLE auth_allowed (id INTEGER PRIMARY KEY, name TEXT NOT NULL, score INTEGER NOT NULL DEFAULT 0)")
    steps.append("CREATE TABLE")
    mochi.db.execute("ALTER TABLE auth_allowed ADD COLUMN extra TEXT NOT NULL DEFAULT ''")
    steps.append("ALTER TABLE")
    mochi.db.execute("CREATE INDEX auth_allowed_name ON auth_allowed(name)")
    steps.append("CREATE INDEX")
    mochi.db.execute("CREATE VIEW auth_allowed_view AS SELECT id, name FROM auth_allowed")
    steps.append("CREATE VIEW")

    # ----- CRUD -----
    mochi.db.execute("INSERT INTO auth_allowed (name, score) VALUES (?, ?)", "alice", 1)
    mochi.db.execute("INSERT INTO auth_allowed (name, score) VALUES (?, ?)", "bob", 2)
    steps.append("INSERT")
    mochi.db.execute("UPDATE auth_allowed SET score = score + 10 WHERE name = ?", "alice")
    steps.append("UPDATE")
    rows = mochi.db.rows("SELECT id, name, score FROM auth_allowed ORDER BY name")
    if len(rows) != 2:
        a.json({"status": "FAIL", "error": "expected 2 rows, got " + str(len(rows)), "steps": steps})
        return
    if rows[0]["score"] != 11 or rows[1]["score"] != 2:
        a.json({"status": "FAIL", "error": "row scores wrong: " + str(rows), "steps": steps})
        return
    steps.append("SELECT")
    one = mochi.db.row("SELECT name FROM auth_allowed_view WHERE id = ?", rows[0]["id"])
    if not one or one["name"] != "alice":
        a.json({"status": "FAIL", "error": "view read wrong: " + str(one), "steps": steps})
        return
    steps.append("SELECT FROM VIEW")
    mochi.db.execute("DELETE FROM auth_allowed WHERE name = ?", "bob")
    steps.append("DELETE")

    # ----- Transaction (this is the same path api_db_transaction uses) -----
    tx = mochi.db.transaction()
    tx.execute("INSERT INTO auth_allowed (name, score) VALUES (?, ?)", "carol", 3)
    tx.execute("UPDATE auth_allowed SET score = score + 100 WHERE name = ?", "carol")
    in_tx = tx.row("SELECT score FROM auth_allowed WHERE name = ?", "carol")
    if not in_tx or in_tx["score"] != 103:
        a.json({"status": "FAIL", "error": "tx read wrong: " + str(in_tx), "steps": steps})
        return
    tx.commit()
    steps.append("TRANSACTION")

    after_tx = mochi.db.row("SELECT score FROM auth_allowed WHERE name = ?", "carol")
    if not after_tx or after_tx["score"] != 103:
        a.json({"status": "FAIL", "error": "post-commit read wrong: " + str(after_tx), "steps": steps})
        return
    steps.append("post-commit SELECT")

    # ----- Cleanup DDL -----
    mochi.db.execute("DROP VIEW auth_allowed_view")
    steps.append("DROP VIEW")
    mochi.db.execute("DROP INDEX auth_allowed_name")
    steps.append("DROP INDEX")
    mochi.db.execute("DROP TABLE auth_allowed")
    steps.append("DROP TABLE")

    a.json({"status": "PASS", "steps": steps})

# ---- introspection: mochi.db.table / indexes / tables (server-controlled
#       PRAGMA paths that must keep working through the internal pool) ----

def action_test_authoriser_introspection(a):
    """Verify mochi.db.table / indexes / tables work — these run hardcoded
    PRAGMA SQL on the server-trusted internal pool, so the authoriser
    must not interfere with them. Reaches a.json() only on success."""
    mochi.db.execute("DROP TABLE IF EXISTS auth_introspect")
    mochi.db.execute("CREATE TABLE auth_introspect (id INTEGER PRIMARY KEY, name TEXT NOT NULL, score INTEGER NOT NULL DEFAULT 0)")
    mochi.db.execute("CREATE INDEX auth_introspect_name ON auth_introspect(name)")

    # tables() should include our table.
    tables = mochi.db.tables()
    found = False
    for t in tables:
        if t == "auth_introspect":
            found = True
            break
    if not found:
        a.json({"status": "FAIL", "error": "auth_introspect not in mochi.db.tables(): " + str(tables)})
        return

    # table() returns the column list with name/type for each column.
    cols = mochi.db.table("auth_introspect")
    if len(cols) != 3:
        a.json({"status": "FAIL", "error": "expected 3 columns, got " + str(len(cols)) + ": " + str(cols)})
        return
    col_names = [c["name"] for c in cols]
    if col_names != ["id", "name", "score"]:
        a.json({"status": "FAIL", "error": "unexpected column order: " + str(col_names)})
        return

    # indexes() should report the index we just created.
    idx = mochi.db.indexes("auth_introspect")
    found_idx = False
    for i in idx:
        if i["name"] == "auth_introspect_name":
            found_idx = True
            break
    if not found_idx:
        a.json({"status": "FAIL", "error": "auth_introspect_name not in indexes: " + str(idx)})
        return

    mochi.db.execute("DROP TABLE auth_introspect")
    a.json({"status": "PASS", "tables_count": len(tables), "cols": col_names, "indexes_count": len(idx)})

# ---- foreign_keys=ON liveness (set by ConnectHook before authoriser) ----

def action_test_authoriser_fk_violation(a):
    """An INSERT that violates a FK must error. Confirms that the
    ConnectHook's `PRAGMA foreign_keys=ON` is live on the starlark pool.
    The action is expected to error out — if it reaches a.json() the
    PRAGMA didn't take effect."""
    # Setup: parent + child via internal-pool DDL (which our `mochi.db.execute`
    # runs over the starlark pool, but DDL is allowed for both).
    mochi.db.execute("DROP TABLE IF EXISTS auth_fk_child")
    mochi.db.execute("DROP TABLE IF EXISTS auth_fk_parent")
    mochi.db.execute("CREATE TABLE auth_fk_parent (id INTEGER PRIMARY KEY)")
    mochi.db.execute("CREATE TABLE auth_fk_child (id INTEGER PRIMARY KEY, parent INTEGER NOT NULL REFERENCES auth_fk_parent(id))")

    # This INSERT references a parent row that doesn't exist; with
    # foreign_keys=ON it must fail with a constraint error.
    mochi.db.execute("INSERT INTO auth_fk_child (id, parent) VALUES (1, 999)")
    # Cleanup will only run if FK enforcement is OFF — that's a failure.
    mochi.db.execute("DROP TABLE auth_fk_child")
    mochi.db.execute("DROP TABLE auth_fk_parent")
    a.json({"status": "FAIL", "error": "FK violation was NOT caught — foreign_keys=ON is not live!"})

def action_test_authoriser_fk_cleanup(a):
    """Companion endpoint: clean up the FK test tables after the
    expected-failure run leaves them behind."""
    mochi.db.execute("DROP TABLE IF EXISTS auth_fk_child")
    mochi.db.execute("DROP TABLE IF EXISTS auth_fk_parent")
    a.json({"cleaned": True})

# ---- fresh-app install round-trip ----
#
# Mimics what happens when an app is installed for the first time: the
# database_create() function builds a schema, the app writes some data
# inside a transaction, reads it back through subsequent calls, then
# tears down. Exercises the same code path apps go through on first
# user access — ConnectHook setup, DDL, transactional writes, view
# reads, FK enforcement, and finally cleanup.

def action_test_authoriser_roundtrip(a):
    """Round-trip a small schema through the starlark pool: create →
    transactional writes → reads → FK enforcement → drop. Reaches
    a.json() only if every step succeeded."""
    # Clean slate.
    mochi.db.execute("DROP VIEW IF EXISTS rt_post_with_author")
    mochi.db.execute("DROP TABLE IF EXISTS rt_post")
    mochi.db.execute("DROP TABLE IF EXISTS rt_author")

    # Schema (what database_create() would do).
    mochi.db.execute("CREATE TABLE rt_author (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)")
    mochi.db.execute("CREATE TABLE rt_post (id INTEGER PRIMARY KEY, author INTEGER NOT NULL REFERENCES rt_author(id) ON DELETE CASCADE, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL)")
    mochi.db.execute("CREATE INDEX rt_post_author ON rt_post(author)")
    mochi.db.execute("CREATE VIEW rt_post_with_author AS SELECT p.id, p.title, a.name AS author_name FROM rt_post p JOIN rt_author a ON a.id = p.author")

    # Transactional writes: a row in rt_author then several rt_post rows
    # referencing it. Commit. The transaction must use the starlark pool
    # path (api_db_transaction).
    tx = mochi.db.transaction()
    tx.execute("INSERT INTO rt_author (name) VALUES (?)", "alice")
    author_row = tx.row("SELECT id FROM rt_author WHERE name = ?", "alice")
    if not author_row:
        tx.rollback()
        a.json({"status": "FAIL", "error": "author insert/read failed"})
        return
    aid = author_row["id"]
    now = mochi.time.now()
    for title in ["First post", "Second post", "Third post"]:
        tx.execute("INSERT INTO rt_post (author, title, created) VALUES (?, ?, ?)", aid, title, now)
    tx.commit()

    # Reads after commit.
    posts = mochi.db.rows("SELECT id, title, author_name FROM rt_post_with_author ORDER BY id")
    if len(posts) != 3:
        a.json({"status": "FAIL", "error": "expected 3 posts, got " + str(len(posts)) + ": " + str(posts)})
        return
    for p in posts:
        if p["author_name"] != "alice":
            a.json({"status": "FAIL", "error": "view join wrong: " + str(p)})
            return

    # ON DELETE CASCADE: deleting the author should remove the posts.
    # This also confirms FK is live on the starlark pool.
    mochi.db.execute("DELETE FROM rt_author WHERE id = ?", aid)
    after = mochi.db.rows("SELECT id FROM rt_post")
    if len(after) != 0:
        a.json({"status": "FAIL", "error": "cascade delete didn't fire — " + str(len(after)) + " posts remain"})
        return

    # Cleanup.
    mochi.db.execute("DROP VIEW rt_post_with_author")
    mochi.db.execute("DROP TABLE rt_post")
    mochi.db.execute("DROP TABLE rt_author")

    a.json({"status": "PASS", "posts_seen": len(posts)})

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

def action_test_file_replication(a):
    """Write three files of different sizes to exercise file replication
    across the 1 MiB threshold that the old inline path used to drop at.
    The file/push protocol should carry all three regardless of size."""
    size_param = a.input("size", "small")
    if size_param == "tiny":
        body = "X" * 1024  # 1 KiB
    elif size_param == "small":
        body = "X" * (256 * 1024)  # 256 KiB — old path would've inlined
    elif size_param == "medium":
        body = "X" * (5 * 1024 * 1024)  # 5 MiB — old path would've dropped
    elif size_param == "large":
        body = "X" * (50 * 1024 * 1024)  # 50 MiB — old path would've dropped
    else:
        a.json({"error": "bad size"})
        return
    path = "file_repl_test/" + size_param + ".bin"
    mochi.file.write(path, body)
    a.json({"path": path, "bytes": len(body)})

def action_test_file_replication_cleanup(a):
    for size in ["tiny", "small", "medium", "large"]:
        mochi.file.delete("file_repl_test/" + size + ".bin")
    a.json({"cleaned": True})

def action_test_file_upload(a):
    """Upload via multipart form (field=file, path=<path>). Memory-
    efficient streaming write + automatic replication via a.upload."""
    path = a.input("path")
    if not path:
        a.error(400, "missing path")
        return
    a.upload("file", path)
    a.json({"uploaded": path})

def action_test_db_limit(a):
    """Test database storage limit by inserting data until full.
    Inserts 4KB rows. With 1GB limit (~262144 pages of 4KB), should fail around 250k rows."""
    # Create test table if not exists
    mochi.db.execute("CREATE TABLE IF NOT EXISTS db_limit_test (id INTEGER PRIMARY KEY, data TEXT)")

    # Insert 4KB rows until database is full
    chunk = "X" * 4096

    # Insert 300k rows (~1.2GB) - should fail before completing if limit works
    for i in range(300000):
        mochi.db.execute("INSERT INTO db_limit_test (data) VALUES (?)", chunk)
        if i % 10000 == 0:
            print("Inserted", i, "rows...")

    # If we get here, the limit didn't work
    rows = mochi.db.rows("SELECT COUNT(*) as count FROM db_limit_test")
    a.json({"test": "db_limit", "status": "FAIL", "rows": rows[0]["count"], "error": "Inserted 300k rows without hitting limit!"})

def action_test_db_cleanup(a):
    """Clean up database test table"""
    mochi.db.execute("DROP TABLE IF EXISTS db_limit_test")
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
