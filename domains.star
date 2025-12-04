# Mochi Claude Test app: Domain routing tests
# Tests for mochi.domain.* API functions

def action_test_domains_register(a):
    """Test domain registration"""
    # Clean up first
    mochi.domain.delete("test-domain.example.com")

    # Register a new domain
    d = mochi.domain.register("test-domain.example.com")

    if d == None:
        a.error(500, "domain registration returned None")
        return

    if d["domain"] != "test-domain.example.com":
        a.error(500, "domain mismatch: " + str(d["domain"]))
        return

    if d["tls"] != 1:
        a.error(500, "tls should be 1: " + str(d["tls"]))
        return

    # Clean up
    mochi.domain.delete("test-domain.example.com")

    a.json({"test": "domains_register", "status": "PASS"})

def action_test_domains_get(a):
    """Test domain get"""
    # Clean up and create
    mochi.domain.delete("test-get.example.com")
    mochi.domain.register("test-get.example.com")

    # Get the domain
    d = mochi.domain.get("test-get.example.com")

    if d == None:
        a.error(500, "domain not found")
        return

    if d["domain"] != "test-get.example.com":
        a.error(500, "domain mismatch")
        return

    # Get non-existent domain
    d2 = mochi.domain.get("nonexistent.example.com")
    if d2 != None:
        a.error(500, "should return None for non-existent domain")
        return

    # Clean up
    mochi.domain.delete("test-get.example.com")

    a.json({"test": "domains_get", "status": "PASS"})

def action_test_domains_list(a):
    """Test domain list"""
    # Clean up
    mochi.domain.delete("test-list1.example.com")
    mochi.domain.delete("test-list2.example.com")

    # Register domains
    mochi.domain.register("test-list1.example.com")
    mochi.domain.register("test-list2.example.com")

    # List all domains
    domains = mochi.domain.list()

    if domains == None:
        a.error(500, "list returned None")
        return

    # Find our test domains
    found1 = False
    found2 = False
    for d in domains:
        if d["domain"] == "test-list1.example.com":
            found1 = True
        if d["domain"] == "test-list2.example.com":
            found2 = True

    if not found1 or not found2:
        a.error(500, "test domains not found in list")
        return

    # Clean up
    mochi.domain.delete("test-list1.example.com")
    mochi.domain.delete("test-list2.example.com")

    a.json({"test": "domains_list", "status": "PASS"})

def action_test_domains_update(a):
    """Test domain update"""
    # Clean up and create
    mochi.domain.delete("test-update.example.com")
    mochi.domain.register("test-update.example.com")

    # Update verified
    d = mochi.domain.update("test-update.example.com", verified=True)

    if d == None:
        a.error(500, "update returned None")
        return

    if d["verified"] != 1:
        a.error(500, "verified should be 1: " + str(d["verified"]))
        return

    # Update tls
    d = mochi.domain.update("test-update.example.com", tls=False)

    if d["tls"] != 0:
        a.error(500, "tls should be 0: " + str(d["tls"]))
        return

    # Clean up
    mochi.domain.delete("test-update.example.com")

    a.json({"test": "domains_update", "status": "PASS"})

def action_test_domains_delete(a):
    """Test domain delete"""
    # Create domain
    mochi.domain.register("test-delete.example.com")

    # Verify it exists
    d = mochi.domain.get("test-delete.example.com")
    if d == None:
        a.error(500, "domain should exist before delete")
        return

    # Delete it
    result = mochi.domain.delete("test-delete.example.com")

    if result != True:
        a.error(500, "delete should return True")
        return

    # Verify it's gone
    d = mochi.domain.get("test-delete.example.com")
    if d != None:
        a.error(500, "domain should not exist after delete")
        return

    a.json({"test": "domains_delete", "status": "PASS"})

def action_test_domains_lookup(a):
    """Test domain lookup with exact and wildcard matching"""
    # Clean up
    mochi.domain.delete("test-lookup.example.com")
    mochi.domain.delete("*.lookup.example.com")

    # Register exact domain
    mochi.domain.register("test-lookup.example.com")

    # Lookup exact match
    d = mochi.domain.lookup("test-lookup.example.com")
    if d == None:
        a.error(500, "exact lookup failed")
        return

    if d["domain"] != "test-lookup.example.com":
        a.error(500, "domain mismatch on exact lookup")
        return

    # Register wildcard domain
    mochi.domain.register("*.lookup.example.com")

    # Lookup via wildcard
    d = mochi.domain.lookup("sub.lookup.example.com")
    if d == None:
        a.error(500, "wildcard lookup failed")
        return

    if d["domain"] != "*.lookup.example.com":
        a.error(500, "domain mismatch on wildcard lookup: " + str(d["domain"]))
        return

    # Lookup unknown domain
    d = mochi.domain.lookup("unknown.test.com")
    if d != None:
        a.error(500, "should return None for unknown domain")
        return

    # Clean up
    mochi.domain.delete("test-lookup.example.com")
    mochi.domain.delete("*.lookup.example.com")

    a.json({"test": "domains_lookup", "status": "PASS"})

def action_test_domains_route_crud(a):
    """Test route create, read, update, delete"""
    # Clean up and create domain
    mochi.domain.delete("test-routes.example.com")
    mochi.domain.register("test-routes.example.com")

    # Create route
    r = mochi.domain.route.create("test-routes.example.com", "/blog", "entity123", 10)

    if r == None:
        a.error(500, "route creation returned None")
        return

    if r["domain"] != "test-routes.example.com":
        a.error(500, "route domain mismatch")
        return

    if r["path"] != "/blog":
        a.error(500, "route path mismatch")
        return

    if r["entity"] != "entity123":
        a.error(500, "route entity mismatch")
        return

    if r["priority"] != 10:
        a.error(500, "route priority mismatch: " + str(r["priority"]))
        return

    # Get route
    r = mochi.domain.route.get("test-routes.example.com", "/blog")
    if r == None:
        a.error(500, "route get returned None")
        return

    # Update route
    r = mochi.domain.route.update("test-routes.example.com", "/blog", priority=20, enabled=False)

    if r["priority"] != 20:
        a.error(500, "route priority not updated: " + str(r["priority"]))
        return

    if r["enabled"] != 0:
        a.error(500, "route enabled not updated: " + str(r["enabled"]))
        return

    # List routes
    routes = mochi.domain.route.list("test-routes.example.com")
    if len(routes) != 1:
        a.error(500, "should have 1 route: " + str(len(routes)))
        return

    # Delete route
    result = mochi.domain.route.delete("test-routes.example.com", "/blog")
    if result != True:
        a.error(500, "route delete should return True")
        return

    # Verify deleted
    r = mochi.domain.route.get("test-routes.example.com", "/blog")
    if r != None:
        a.error(500, "route should not exist after delete")
        return

    # Clean up
    mochi.domain.delete("test-routes.example.com")

    a.json({"test": "domains_route_crud", "status": "PASS"})

def action_test_domains_cascade_delete(a):
    """Test that deleting a domain deletes its routes"""
    # Clean up and create domain
    mochi.domain.delete("test-cascade.example.com")
    mochi.domain.register("test-cascade.example.com")

    # Create routes
    mochi.domain.route.create("test-cascade.example.com", "/a", "entity-a", 0)
    mochi.domain.route.create("test-cascade.example.com", "/b", "entity-b", 0)

    # Verify routes exist
    routes = mochi.domain.route.list("test-cascade.example.com")
    if len(routes) != 2:
        a.error(500, "should have 2 routes before delete")
        return

    # Delete domain
    mochi.domain.delete("test-cascade.example.com")

    # Verify routes are gone
    routes = mochi.domain.route.list("test-cascade.example.com")
    if len(routes) != 0:
        a.error(500, "routes should be deleted with domain: " + str(len(routes)))
        return

    a.json({"test": "domains_cascade_delete", "status": "PASS"})

def action_test_domains_delegation_full(a):
    """Test full domain delegation via delegations table"""
    if a.user.role != "administrator":
        a.json({"test": "domains_delegation_full", "status": "SKIP", "reason": "Requires administrator role"})
        return

    my_id = a.user.id

    # Clean up and create domain
    mochi.domain.delete("full-delegation.example.com")
    mochi.domain.register("full-delegation.example.com")

    # Create full domain delegation (path = "")
    d = mochi.domain.delegation.create("full-delegation.example.com", "", my_id)
    if d == None:
        a.error(500, "delegation creation returned None")
        return

    if d["path"] != "":
        a.error(500, "delegation path should be empty for full domain: " + str(d["path"]))
        return

    # User should be able to create routes anywhere on the domain
    r = mochi.domain.route.create("full-delegation.example.com", "/blog", "entity123", 0)
    if r == None:
        a.error(500, "user with full delegation should be able to create route")
        return

    r = mochi.domain.route.create("full-delegation.example.com", "/shop", "entity456", 0)
    if r == None:
        a.error(500, "user with full delegation should be able to create any route")
        return

    # Clean up
    mochi.domain.delegation.delete("full-delegation.example.com", "", my_id)
    mochi.domain.delete("full-delegation.example.com")

    a.json({"test": "domains_delegation_full", "status": "PASS"})

def action_test_domains_delegate_path_scope(a):
    """Test path-scoped delegation using the delegations table"""
    if a.user.role != "administrator":
        a.json({"test": "domains_delegate_path_scope", "status": "SKIP", "reason": "Requires administrator role"})
        return

    my_id = a.user.id

    # Clean up and create domain
    mochi.domain.delete("path-scope.example.com")
    mochi.domain.register("path-scope.example.com")

    # Create path delegation for /blog
    d = mochi.domain.delegation.create("path-scope.example.com", "/blog", my_id)
    if d == None:
        a.error(500, "delegation creation returned None")
        return

    if d["domain"] != "path-scope.example.com":
        a.error(500, "delegation domain mismatch: " + str(d["domain"]))
        return

    if d["path"] != "/blog":
        a.error(500, "delegation path mismatch: " + str(d["path"]))
        return

    if int(d["owner"]) != my_id:
        a.error(500, "delegation owner mismatch: " + str(d["owner"]))
        return

    # List delegations
    delegations = mochi.domain.delegation.list("path-scope.example.com")
    if len(delegations) != 1:
        a.error(500, "should have 1 delegation: " + str(len(delegations)))
        return

    # Clean up
    mochi.domain.delegation.delete("path-scope.example.com", "/blog", my_id)
    mochi.domain.delete("path-scope.example.com")

    a.json({"test": "domains_delegate_path_scope", "status": "PASS"})

def action_test_domains_route_context(a):
    """Test route context field"""
    # Clean up and create domain
    mochi.domain.delete("test-context.example.com")
    mochi.domain.register("test-context.example.com")

    # Create route with context
    r = mochi.domain.route.create("test-context.example.com", "/mypath", "entity123", 0, context="my-custom-context")

    if r == None:
        a.error(500, "route creation returned None")
        return

    if r["context"] != "my-custom-context":
        a.error(500, "route context mismatch: " + str(r["context"]))
        return

    # Get route and verify context
    r = mochi.domain.route.get("test-context.example.com", "/mypath")
    if r["context"] != "my-custom-context":
        a.error(500, "route get context mismatch: " + str(r["context"]))
        return

    # Update context
    r = mochi.domain.route.update("test-context.example.com", "/mypath", context="updated-context")
    if r["context"] != "updated-context":
        a.error(500, "route update context mismatch: " + str(r["context"]))
        return

    # Clean up
    mochi.domain.delete("test-context.example.com")

    a.json({"test": "domains_route_context", "status": "PASS"})

def action_test_domains_action_context(a):
    """Return the current a.context value for verification"""
    a.json({"context": a.context})

def action_test_domains_suite(a):
    """Run all domain tests"""
    tests = [
        "test_domains_register",
        "test_domains_get",
        "test_domains_list",
        "test_domains_update",
        "test_domains_delete",
        "test_domains_lookup",
        "test_domains_route_crud",
        "test_domains_route_context",
        "test_domains_cascade_delete",
        "test_domains_delegation_full",
        "test_domains_delegate_path_scope"
    ]

    results = []
    for test in tests:
        # Note: We can't actually call actions from Starlark
        # This just documents the test suite
        results.append({"test": test, "status": "pending"})

    a.json({
        "suite": "domains",
        "tests": tests,
        "note": "Run each test individually via /claude-test/<test_name>"
    })
