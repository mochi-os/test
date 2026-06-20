# Copyright © 2026 Mochi OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# API additions and renames from this session
# Each test returns {"pass": bool, "detail": ...}

# mochi.crypto.hash.sha256 - known vector

def action_test_crypto_hash_sha256(a):
	# echo -n "abc" | sha256sum
	want = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	got = mochi.crypto.hash.sha256("abc")
	a.json({"pass": got == want, "got": got, "want": want})

def action_test_crypto_hash_sha256_bytes(a):
	# Same vector, byte input
	want = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	got = mochi.crypto.hash.sha256(bytes("abc"))
	a.json({"pass": got == want, "got": got})

# mochi.random.* - structural checks

def action_test_random_bytes(a):
	b = mochi.random.bytes(16)
	a.json({"pass": len(b) == 16 and type(b) == "bytes", "len": len(b), "type": type(b)})

def action_test_random_integer(a):
	# Run 100 times, check bounds and that we hit at least 2 distinct values
	seen = {}
	for _ in range(100):
		n = mochi.random.integer(5, 9)
		if n < 5 or n > 9:
			a.json({"pass": False, "out_of_range": n})
			return
		seen[n] = True
	a.json({"pass": len(seen) >= 2, "distinct": len(seen)})

def action_test_random_choice(a):
	options = ["alpha", "beta", "gamma", "delta"]
	for _ in range(20):
		pick = mochi.random.choice(options)
		if pick not in options:
			a.json({"pass": False, "bad": pick})
			return
	a.json({"pass": True})

def action_test_random_unambiguous(a):
	s = mochi.random.unambiguous(20)
	# Confusable chars must not appear
	confusable = "01OIli"
	for c in confusable.elems():
		if c in s:
			a.json({"pass": False, "confusable_found": c, "string": s})
			return
	a.json({"pass": len(s) == 20, "len": len(s), "sample": s})

# mochi.time.parse - round-trip with mochi.time.local

def action_test_time_parse_rfc3339(a):
	# Known: 2026-05-02 12:00:00 UTC = 1777723200
	ts = mochi.time.parse("2026-05-02T12:00:00Z")
	a.json({"pass": ts == 1777723200, "got": ts})

def action_test_time_parse_round_trip(a):
	now = mochi.time.now()
	s = mochi.time.local(now, "rfc3339")
	back = mochi.time.parse(s, "rfc3339")
	a.json({"pass": back == now, "now": now, "formatted": s, "back": back})

def action_test_time_parse_invalid(a):
	# Returns None on parse error, no exception
	got = mochi.time.parse("not-a-date")
	a.json({"pass": got == None, "got": got})

# mochi.db.transaction - commit, rollback, auto-rollback

def action_test_db_transaction_commit(a):
	mochi.db.execute("create table if not exists txn_test ( id text primary key, value text )")
	mochi.db.execute("delete from txn_test")
	t = mochi.db.transaction()
	t.execute("insert into txn_test (id, value) values (?, ?)", "a", "1")
	t.execute("insert into txn_test (id, value) values (?, ?)", "b", "2")
	t.commit()
	rows = mochi.db.rows("select id, value from txn_test order by id")
	a.json({"pass": len(rows) == 2 and rows[0]["id"] == "a" and rows[1]["id"] == "b", "rows": rows})

def action_test_db_transaction_rollback(a):
	mochi.db.execute("create table if not exists txn_test ( id text primary key, value text )")
	mochi.db.execute("delete from txn_test")
	mochi.db.execute("insert into txn_test (id, value) values (?, ?)", "seed", "x")
	t = mochi.db.transaction()
	t.execute("insert into txn_test (id, value) values (?, ?)", "doomed", "y")
	t.rollback()
	rows = mochi.db.rows("select id from txn_test order by id")
	# Only the seed survives
	a.json({"pass": len(rows) == 1 and rows[0]["id"] == "seed", "rows": rows})

def action_test_db_transaction_handle_methods(a):
	# Verify exists/row/rows route through the transaction
	mochi.db.execute("create table if not exists txn_test ( id text primary key, value text )")
	mochi.db.execute("delete from txn_test")
	t = mochi.db.transaction()
	t.execute("insert into txn_test (id, value) values (?, ?)", "k", "v")
	exists = t.exists("select 1 from txn_test where id=?", "k")
	row = t.row("select value from txn_test where id=?", "k")
	rows = t.rows("select id, value from txn_test")
	t.rollback()
	a.json({
		"pass": exists == True and row != None and row["value"] == "v" and len(rows) == 1,
		"exists": exists, "row": row, "rows": rows
	})

# mochi.schedule.cancel - schedule then cancel

def action_test_schedule_cancel(a):
	se = mochi.schedule.after("test_cancel_event", {"x": 1}, 60)
	cancelled = mochi.schedule.cancel(se.id)
	# Second cancel returns False (already gone)
	cancelled_again = mochi.schedule.cancel(se.id)
	a.json({"pass": cancelled == True and cancelled_again == False, "first": cancelled, "second": cancelled_again})

def action_test_schedule_cancel_unknown(a):
	# Cancelling a definitely-nonexistent ID returns False, not an error
	got = mochi.schedule.cancel(999999999)
	a.json({"pass": got == False, "got": got})

# mochi.server.* - id, started, uptime

def action_test_server_id(a):
	id = mochi.server.id()
	a.json({"pass": type(id) == "string" and len(id) > 0, "id": id})

def action_test_server_started(a):
	started = mochi.server.started()
	now = mochi.time.now()
	a.json({"pass": started > 0 and started <= now, "started": started, "now": now})

def action_test_server_uptime(a):
	up = mochi.server.uptime()
	a.json({"pass": up >= 0, "uptime": up})

def action_test_server_version(a):
	v = mochi.server.version()
	a.json({"pass": type(v) == "string" and len(v) > 0, "version": v})

# mochi.service.exists

def action_test_service_exists_true(a):
	# This app declares the "test" service in app.json
	got = mochi.service.exists("test")
	a.json({"pass": got == True, "got": got})

def action_test_service_exists_false(a):
	got = mochi.service.exists("nonexistent-service-xyz-12345")
	a.json({"pass": got == False, "got": got})

# mochi.permission.level - returns string

def action_test_permission_level(a):
	# url:* is restricted, users/read is administrator-only
	url = mochi.permission.level("url:*")
	admin = mochi.permission.level("users/read")
	standard = mochi.permission.level("accounts/read")
	a.json({
		"pass": url == "restricted" and admin == "administrator" and standard == "standard",
		"url": url, "users/read": admin, "accounts/read": standard,
	})

# mochi.entity.fingerprint - 9 chars, no hyphens

def action_test_entity_fingerprint(a):
	fp = mochi.entity.fingerprint(a.user.identity.id)
	a.json({"pass": len(fp) == 9 and "-" not in fp, "fingerprint": fp})

# mochi.entity.{info, name, update, delete} - accept fingerprints
# (light check: info works for the calling identity by both ID and fingerprint)

def action_test_entity_info_by_fingerprint(a):
	id = a.user.identity.id
	fp = mochi.entity.fingerprint(id)
	by_id = mochi.entity.info(id)
	by_fp = mochi.entity.info(fp)
	a.json({
		"pass": by_id != None and by_fp != None and by_id["id"] == by_fp["id"],
		"by_id": by_id, "by_fp": by_fp,
	})

def action_test_entity_name_by_fingerprint(a):
	id = a.user.identity.id
	fp = mochi.entity.fingerprint(id)
	by_id = mochi.entity.name(id)
	by_fp = mochi.entity.name(fp)
	a.json({
		"pass": by_id != "" and by_id == by_fp,
		"by_id": by_id, "by_fp": by_fp,
	})

# mochi.text.markdown / mochi.text.valid - renamed targets

def action_test_text_markdown(a):
	html = mochi.text.markdown("# hi")
	a.json({"pass": "<h1>" in html and "hi" in html, "html": html})

def action_test_text_valid(a):
	ok = mochi.text.valid("abc-123", "constant")
	bad = mochi.text.valid("contains spaces", "constant")
	a.json({"pass": ok == True and bad == False, "ok": ok, "bad": bad})

def action_test_text_slug(a):
	cases = [
		("Hello, World!", "hello-world"),
		("Café Olé", "cafe-ole"),
		("  spaces   here  ", "spaces-here"),
		("---", ""),
		("", ""),
		("Sprint 10", "sprint-10"),
	]
	results = []
	all_ok = True
	for input, expected in cases:
		got = mochi.text.slug(input)
		ok = got == expected
		all_ok = all_ok and ok
		results.append({"input": input, "expected": expected, "got": got, "pass": ok})
	a.json({"pass": all_ok, "cases": results})

# Suite - run them all and tally

def action_test_apis_suite(a):
	results = []
	fp = mochi.entity.fingerprint(a.user.identity.id)

	results.append({"test": "crypto_hash_sha256", "pass": mochi.crypto.hash.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"})
	results.append({"test": "crypto_hash_sha256_bytes", "pass": mochi.crypto.hash.sha256(bytes("abc")) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"})
	results.append({"test": "random_bytes", "pass": len(mochi.random.bytes(16)) == 16})
	n = mochi.random.integer(5, 9)
	results.append({"test": "random_integer", "pass": 5 <= n and n <= 9})
	results.append({"test": "random_choice", "pass": mochi.random.choice(["a", "b", "c"]) in ["a", "b", "c"]})
	results.append({"test": "random_unambiguous", "pass": len(mochi.random.unambiguous(10)) == 10})
	results.append({"test": "time_parse_rfc3339", "pass": mochi.time.parse("2026-05-02T12:00:00Z") == 1777723200})
	results.append({"test": "time_parse_invalid", "pass": mochi.time.parse("not-a-date") == None})
	results.append({"test": "schedule_cancel_unknown", "pass": mochi.schedule.cancel(999999999) == False})
	id = mochi.server.id()
	results.append({"test": "server_id", "pass": type(id) == "string" and len(id) > 0})
	results.append({"test": "server_started", "pass": mochi.server.started() > 0})
	results.append({"test": "server_uptime", "pass": mochi.server.uptime() >= 0})
	results.append({"test": "server_version", "pass": type(mochi.server.version()) == "string"})
	results.append({"test": "service_exists_true", "pass": mochi.service.exists("test") == True})
	results.append({"test": "service_exists_false", "pass": mochi.service.exists("nonexistent-service-xyz") == False})
	results.append({"test": "permission_level_restricted", "pass": mochi.permission.level("url:*") == "restricted"})
	results.append({"test": "permission_level_admin", "pass": mochi.permission.level("users/read") == "administrator"})
	results.append({"test": "permission_level_standard", "pass": mochi.permission.level("accounts/read") == "standard"})
	results.append({"test": "entity_fingerprint_length", "pass": len(fp) == 9})
	results.append({"test": "entity_fingerprint_no_hyphens", "pass": "-" not in fp})
	results.append({"test": "text_markdown", "pass": "<h1>" in mochi.text.markdown("# hi")})
	results.append({"test": "text_valid_ok", "pass": mochi.text.valid("abc-123", "constant") == True})
	results.append({"test": "text_valid_bad", "pass": mochi.text.valid("has spaces", "constant") == False})
	results.append({"test": "text_slug_basic", "pass": mochi.text.slug("Hello, World!") == "hello-world"})
	results.append({"test": "text_slug_accents", "pass": mochi.text.slug("Café Olé") == "cafe-ole"})
	results.append({"test": "text_slug_empty", "pass": mochi.text.slug("---") == ""})

	passed = len([r for r in results if r["pass"]])
	a.json({"passed": passed, "total": len(results), "results": results})
