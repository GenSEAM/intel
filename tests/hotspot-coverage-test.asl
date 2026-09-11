(module asl-intel/tests/hotspot-coverage-test
  :d "Pure ASL test suite for Hotspot Tracing and Traversal Coverage Engine."
  :x [test-plan-creation
      test-coverage-recording
      test-gap-analysis-and-comparison
      test-report-formatting
      run-tests]
  :i [(hotspot-coverage :a hc)])

(df test-plan-creation [] -> Bool
  :d "Verifies planned traversal DAG construction and target counting."
  (let [(p0 (hc/create-planned-traversal "plan-audit" "Remediation Audit Plan" 2000))
        (t1 (hc/create-hotspot-target "asl-engine:q" "asl/bin/asl-engine" "OP: q" 12 1 "Broken RPC redirect" 2))
        (t2 (hc/create-hotspot-target "asl-engine:engine" "asl/bin/asl-engine" "OP: engine" 15 1 "Mock responses in engine tiers" 2))
        (t3 (hc/create-hotspot-target "asl-engine:patch" "asl/bin/asl-engine" "OP: patch" 8 1 "Regex truncation bug" 2))
        (p1 (hc/plan-add-target p0 t1))
        (p2 (hc/plan-add-target p1 t2))
        (p3 (hc/plan-add-target p2 t3))]
    (assert (= (hc/plan-target-count p3) 3) "Planned targets count must be 3")
    (assert (= (.-total-budget p3) 2000) "Token budget must be 2000")
    (assert (string-contains? (.-title p3) "Remediation") "Plan title must contain Remediation")
    true))

(df test-coverage-recording [] -> Bool
  :d "Verifies actual inspection visit recording and token accumulation."
  (let [(c0 (hc/create-actual-coverage "run-01" "session-test"))
        (v1 (hc/record-visit "asl-engine:q" "asl/bin/asl-engine" 2 "verified" 1 150))
        (v2 (hc/record-visit "asl-engine:engine" "asl/bin/asl-engine" 2 "verified" 2 250))
        (c1 (hc/coverage-add-visit c0 v1))
        (c2 (hc/coverage-add-visit c1 v2))]
    (assert (= (hc/coverage-visit-count c2) 2) "Coverage visits count must be 2")
    (assert (= (.-total-tokens c2) 400) "Total tokens must be 400")
    (assert (hc/is-target-visited? "asl-engine:q" (.-visits c2)) "Target asl-engine:q must be visited")
    (assert (not (hc/is-target-visited? "asl-engine:patch" (.-visits c2))) "Target asl-engine:patch must not be visited")
    true))

(df test-gap-analysis-and-comparison [] -> Bool
  :d "Verifies planned versus actual traversal path gap and drift detection."
  (let [(p0 (hc/create-planned-traversal "plan-audit" "Full Remediation Audit" 5000))
        (t1 (hc/create-hotspot-target "asl-engine:q" "asl/bin/asl-engine" "q" 12 1 "Fix redirect" 2))
        (t2 (hc/create-hotspot-target "asl-engine:engine" "asl/bin/asl-engine" "engine" 15 1 "Fix mocks" 2))
        (t3 (hc/create-hotspot-target "asl-engine:patch" "asl/bin/asl-engine" "patch" 8 1 "Fix regex" 2))
        (t4 (hc/create-hotspot-target "intel:sym" "asl/bin/asl-engine" "sym" 20 1 "Real graph" 2))
        (t5 (hc/create-hotspot-target "agent:horizon" "agent/src/horizon.asl" "horizon" 5 2 "Cleanup stubs" 1))
        (plan (hc/plan-add-target (hc/plan-add-target (hc/plan-add-target (hc/plan-add-target (hc/plan-add-target p0 t1) t2) t3) t4) t5))
        (c0 (hc/create-actual-coverage "run-01" "session-test"))
        (v1 (hc/record-visit "asl-engine:q" "asl/bin/asl-engine" 2 "verified" 1 150))
        (v2 (hc/record-visit "asl-engine:engine" "asl/bin/asl-engine" 2 "verified" 2 200))
        (v3 (hc/record-visit "asl-engine:patch" "asl/bin/asl-engine" 1 "gap" 1 100))
        (v4 (hc/record-visit "unplanned:drift" "scratch/temp.asl" 1 "clean" 0 50))
        (cov (hc/coverage-add-visit (hc/coverage-add-visit (hc/coverage-add-visit (hc/coverage-add-visit c0 v1) v2) v3) v4))
        (comp (hc/compare-traversal-paths plan cov))]
    (assert (= (.-total-planned comp) 5) "Total planned targets must be 5")
    (assert (= (.-total-visited comp) 4) "Total visits recorded must be 4")
    (assert (= (.-covered-count comp) 2) "Fully covered targets must be 2")
    (assert (= (.-gap-count comp) 3) "Gap count must be 3 (1 degraded depth, 2 unvisited)")
    (assert (= (.-drift-count comp) 1) "Drift count must be 1 for unplanned visit")
    (assert (= (.-coverage-pct comp) 40) "Coverage percentage must be 40%")
    (assert (not (.-is-complete comp)) "Audit must not be complete while gaps remain")
    true))

(df test-report-formatting [] -> Bool
  :d "Verifies structured ASN report generation and Adjacency DSL graph rendering."
  (let [(p0 (hc/create-planned-traversal "plan-01" "Test Plan" 1000))
        (t1 (hc/create-hotspot-target "target-a" "fileA.asl" "symA" 5 1 "Test A" 2))
        (t2 (hc/create-hotspot-target "target-b" "fileB.asl" "symB" 10 1 "Test B" 2))
        (plan (hc/plan-add-target (hc/plan-add-target p0 t1) t2))
        (c0 (hc/create-actual-coverage "run-test" "session-test"))
        (v1 (hc/record-visit "target-a" "fileA.asl" 2 "verified" 0 100))
        (cov (hc/coverage-add-visit c0 v1))
        (comp (hc/compare-traversal-paths plan cov))
        (rep (hc/format-coverage-report comp))
        (graph (hc/render-traversal-graph plan cov))]
    (assert (string-contains? rep ":coverage-report") "Report must have :coverage-report header")
    (assert (string-contains? rep ":coverage-pct 50") "Report must reflect 50% coverage")
    (assert (string-contains? rep "target-b") "Report must cite unvisited target-b in gaps")
    (assert (string-contains? graph ":traversal-graph (plan-01 > target-a:covered target-b:gap)") "Graph must render Adjacency DSL with covered/gap status")
    true))

(df run-tests [] -> Bool
  :d "Runs all hotspot coverage test suites."
  (let [(_t1 (test-plan-creation))
        (_t2 (test-coverage-recording))
        (_t3 (test-gap-analysis-and-comparison))
        (_t4 (test-report-formatting))]
    true))
