# Copyright © 2026 Mochisoft OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

# Stage 5: Integration tests for mochi.ai and mochi.qid APIs

def action_test_qid_lookup_single(a):
    """Test mochi.qid.lookup with a single QID"""
    label = mochi.qid.lookup("Q183", "en")
    a.json({"qid": "Q183", "label": label, "pass": label == "Germany"})

def action_test_qid_lookup_batch(a):
    """Test mochi.qid.lookup with multiple QIDs"""
    labels = mochi.qid.lookup(["Q183", "Q11424", "Q5"], "en")
    a.json({
        "labels": labels,
        "pass": labels["Q183"] == "Germany" and labels["Q5"] == "human"
    })

def action_test_qid_lookup_japanese(a):
    """Test mochi.qid.lookup with Japanese language"""
    label = mochi.qid.lookup("Q183", "ja")
    a.json({"qid": "Q183", "label": label, "pass": label != ""})

def action_test_qid_lookup_invalid(a):
    """Test mochi.qid.lookup with invalid QID format"""
    label = mochi.qid.lookup("INVALID", "en")
    # Should error - this tests error handling
    a.json({"label": label, "pass": False})

def action_test_qid_search(a):
    """Test mochi.qid.search"""
    results = mochi.qid.search("Germany", "en")
    first_qid = results[0]["qid"] if len(results) > 0 else ""
    a.json({
        "count": len(results),
        "first": results[0] if len(results) > 0 else None,
        "pass": len(results) > 0 and first_qid == "Q183"
    })

def action_test_ai_prompt(a):
    """Test mochi.ai.prompt"""
    account = a.input("account")
    if account != None:
        result = mochi.ai.prompt("Reply with exactly one word: hello", account=account)
    else:
        result = mochi.ai.prompt("Reply with exactly one word: hello")
    a.json({
        "status": result["status"],
        "text": result["text"],
        "pass": result["status"] == 200 and len(result["text"]) > 0
    })

def action_test_ai_prompt_no_account(a):
    """Test mochi.ai.prompt returns status 0 with invalid account"""
    result = mochi.ai.prompt("hello", account=99999)
    a.json({
        "status": result["status"],
        "text": result["text"],
        "pass": result["status"] == 0
    })

def action_test_stage5_suite(a):
    """Run all stage 5 tests"""
    results = []

    # QID lookup single
    label = mochi.qid.lookup("Q183", "en")
    results.append({"test": "qid_lookup_single", "pass": label == "Germany", "detail": label})

    # QID lookup batch
    labels = mochi.qid.lookup(["Q183", "Q11424", "Q5"], "en")
    results.append({"test": "qid_lookup_batch", "pass": labels["Q183"] == "Germany", "detail": labels})

    # QID lookup cached (second call should hit cache)
    label2 = mochi.qid.lookup("Q183", "en")
    results.append({"test": "qid_lookup_cached", "pass": label2 == "Germany", "detail": label2})

    # QID search
    search = mochi.qid.search("Germany", "en")
    results.append({"test": "qid_search", "pass": len(search) > 0, "detail": search[0] if len(search) > 0 else None})

    # AI prompt
    ai = mochi.ai.prompt("Reply with exactly one word: hello")
    results.append({"test": "ai_prompt", "pass": ai["status"] == 200, "detail": {"status": ai["status"], "text": ai["text"][:100] if ai["text"] else ""}})

    # AI prompt with bad account
    ai2 = mochi.ai.prompt("hello", account=99999)
    results.append({"test": "ai_prompt_bad_account", "pass": ai2["status"] == 0, "detail": {"status": ai2["status"]}})

    passed = len([r for r in results if r["pass"]])
    a.json({"passed": passed, "total": len(results), "results": results})
