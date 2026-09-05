(module asl-intel/tests/preload-test
  :d "Pure ASL test suite for Graph-Horizon Paging H(m, k, B) and Scoped Preload Engine."
  :x [test-stub-token-estimation
      test-preload-tier-conversion
      test-horizon-budget-enforcement
      test-horizon-add-stub-budget
      test-horizon-zero-budget
      test-intel-preload-graph-multi-tier
      test-intel-preload-depth-scoping
      test-intel-preload-empty-target
      test-intel-preload-missing-target
      test-intel-preload-zero-depth
      test-format-preload-context
      run-tests]
  :i [(preload :a pr)
      (graph :a g)])

(df build-test-graph [] -> g/SymbolGraph
  :d "Constructs an in-memory SymbolGraph fixture for testing"
  (let [(n0 (:GraphNode :id "app/main" :name "main" :kind "function" :file "src/main.asl" :start-line 1 :end-line 20 :signature "(df main [] -> I64)" :exported true))
        (n1 (:GraphNode :id "app/caller" :name "caller" :kind "function" :file "src/caller.asl" :start-line 1 :end-line 15 :signature "(df caller [] -> I64)" :exported true))
        (n2 (:GraphNode :id "app/callee" :name "callee" :kind "function" :file "src/callee.asl" :start-line 1 :end-line 10 :signature "(df callee [] -> I64)" :exported true))
        (n3 (:GraphNode :id "app/transitive" :name "transitive" :kind "function" :file "src/trans.asl" :start-line 1 :end-line 8 :signature "(df transitive [] -> I64)" :exported false))
        (e1 (:GraphEdge :src "app/caller" :dst "app/main" :kind (g/edge-calls) :file "src/caller.asl" :line 5))
        (e2 (:GraphEdge :src "app/main" :dst "app/callee" :kind (g/edge-calls) :file "src/main.asl" :line 10))
        (e3 (:GraphEdge :src "app/callee" :dst "app/transitive" :kind (g/edge-calls) :file "src/callee.asl" :line 8))
        (g0 (g/graph-create))
        (g1 (g/graph-add-node g0 n0))
        (g2 (g/graph-add-node g1 n1))
        (g3 (g/graph-add-node g2 n2))
        (g4 (g/graph-add-node g3 n3))
        (g5 (g/graph-add-edge g4 e1))
        (g6 (g/graph-add-edge g5 e2))
        (g7 (g/graph-add-edge g6 e3))]
    g7))

(df test-stub-token-estimation [] -> Bool
  :d "Verifies deterministic token estimation for stubs and raw text"
  (let [(stub-explicit (pr/stub-create "sym-a" (pr/tier-micro-ast) "src/a.asl" "(df sym-a [] -> I64)" "doc" 42))
        (stub-calc (pr/stub-create "sym-b" (pr/tier-meso-symbol) "src/b.asl" "(df sym-b [] -> Str)" "" 0))]
    (and (= (pr/estimate-tokens "12345678") 2)
         (= (pr/estimate-tokens "") 0)
         (= (pr/estimate-stub-tokens stub-explicit) 42)
         (> (pr/estimate-stub-tokens stub-calc) 0))))

(df test-preload-tier-conversion [] -> Bool
  :d "Verifies string conversion across all 3 tiers"
  (and (string-equals? (pr/preload-tier-to-string (pr/tier-micro-ast)) "micro-ast")
       (string-equals? (pr/preload-tier-to-string (pr/tier-meso-symbol)) "meso-symbol")
       (string-equals? (pr/preload-tier-to-string (pr/tier-macro-topology)) "macro-topology")))

(df test-horizon-budget-enforcement [] -> Bool
  :d "Verifies that adding stubs halts when token budget is exceeded and marks truncated: true"
  (let [(h0 (pr/horizon-create "app/main" 2 100))
        (s1 (pr/stub-create "s1" (pr/tier-meso-symbol) "f1.asl" "sig1" "" 60))
        (s2 (pr/stub-create "s2" (pr/tier-meso-symbol) "f2.asl" "sig2" "" 50))
        (h1 (pr/horizon-add-stub h0 s1))
        (h2 (pr/horizon-add-stub h1 s2))]
    (and (= (.-total-tokens h1) 60)
         (not (.-truncated h1))
         (= (list-length (.-stubs h1)) 1)
         (= (.-total-tokens h2) 60)
         (.-truncated h2)
         (= (list-length (.-stubs h2)) 1))))

(df test-horizon-add-stub-budget [] -> Bool
  :d "Verifies that horizon-add-stub short-circuits when horizon is already truncated"
  (let [(h0 (pr/horizon-create "app/main" 2 100))
        (s1 (pr/stub-create "s1" (pr/tier-meso-symbol) "f1.asl" "sig1" "" 60))
        (s2 (pr/stub-create "s2" (pr/tier-meso-symbol) "f2.asl" "sig2" "" 50))
        (s3 (pr/stub-create "s3" (pr/tier-macro-topology) "f3.asl" "" "doc" 5))
        (h1 (pr/horizon-add-stub h0 s1))
        (h2 (pr/horizon-add-stub h1 s2))
        (h3 (pr/horizon-add-stub h2 s3))]
    (and (.-truncated h2)
         (= (list-length (.-stubs h2)) 1)
         (.-truncated h3)
         (= (list-length (.-stubs h3)) 1)
         (= (.-total-tokens h3) 60))))

(df test-horizon-zero-budget [] -> Bool
  :d "Verifies that zero budget immediately truncates on stub addition"
  (let [(hz (pr/horizon-create "app/main" 2 0))
        (s1 (pr/stub-create "s1" (pr/tier-micro-ast) "f1.asl" "sig" "doc" 10))
        (hz-res (pr/horizon-add-stub hz s1))]
    (and (= (list-length (.-stubs hz-res)) 0)
         (.-truncated hz-res))))

(df test-intel-preload-graph-multi-tier [] -> Bool
  :d "Verifies 3-tier hydration: Depth 0 (micro-ast), Depth 1 (meso-symbol), Depth 2 (macro-topology)"
  (let [(g (build-test-graph))
        (h (pr/intel-preload-graph g "app/main" 2 10000))
        (stubs (.-stubs h))]
    (and (= (list-length stubs) 4)
         (not (.-truncated h))
         (string-equals? (.-target-symbol h) "app/main"))))

(df test-intel-preload-depth-scoping [] -> Bool
  :d "Verifies depth limit k bounds graph traversal properly"
  (let [(g (build-test-graph))
        (h-d1 (pr/intel-preload-graph g "app/main" 1 10000))
        (h-name (pr/intel-preload-graph g "main" 0 10000))]
    (and (= (list-length (.-stubs h-d1)) 3)
         (not (.-truncated h-d1))
         (= (list-length (.-stubs h-name)) 1)
         (not (.-truncated h-name)))))

(df test-intel-preload-empty-target [] -> Bool
  :d "Verifies empty target symbol returns empty horizon without truncation"
  (let [(g (build-test-graph))
        (h1 (pr/intel-preload-graph g "" 2 1000))
        (h2 (pr/intel-preload-graph g "   " 2 1000))]
    (and (= (list-length (.-stubs h1)) 0)
         (not (.-truncated h1))
         (= (.-total-tokens h1) 0)
         (= (list-length (.-stubs h2)) 0)
         (not (.-truncated h2))
         (= (.-total-tokens h2) 0))))

(df test-intel-preload-missing-target [] -> Bool
  :d "Verifies unknown symbol returns empty horizon without truncation"
  (let [(g (build-test-graph))
        (h (pr/intel-preload-graph g "nonexistent/symbol" 2 1000))]
    (and (= (list-length (.-stubs h)) 0)
         (not (.-truncated h))
         (= (.-total-tokens h) 0))))

(df test-intel-preload-zero-depth [] -> Bool
  :d "Verifies depth <= 0 bounds strictly to root target node at Depth 0"
  (let [(g (build-test-graph))
        (h0 (pr/intel-preload-graph g "app/main" 0 1000))
        (h-neg (pr/intel-preload-graph g "app/main" -1 1000))]
    (and (= (list-length (.-stubs h0)) 1)
         (not (.-truncated h0))
         (= (list-length (.-stubs h-neg)) 1)
         (not (.-truncated h-neg)))))

(df test-format-preload-context [] -> Bool
  :d "Verifies serialization of PreloadedHorizon into dense ASN context"
  (let [(g (build-test-graph))
        (h (pr/intel-preload-graph g "app/main" 2 10000))
        (ctx (pr/format-preload-context h))]
    (and (string-contains? ctx "@horizon")
         (string-contains? ctx ":target \"app/main\"")
         (string-contains? ctx ":budget 10000")
         (string-contains? ctx ":tokens")
         (string-contains? ctx ":stub :symbol \"app/main\"")
         (string-contains? ctx ":tier \"micro-ast\""))))

(df run-tests [] -> Bool
  :d "Executes complete test suite for scoped graph-horizon preloading"
  (and (test-stub-token-estimation)
       (test-preload-tier-conversion)
       (test-horizon-budget-enforcement)
       (test-horizon-add-stub-budget)
       (test-horizon-zero-budget)
       (test-intel-preload-graph-multi-tier)
       (test-intel-preload-depth-scoping)
       (test-intel-preload-empty-target)
       (test-intel-preload-missing-target)
       (test-intel-preload-zero-depth)
       (test-format-preload-context)))
