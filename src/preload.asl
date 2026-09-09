(module asl-intel/preload
  :d "Graph-Horizon Paging H(m, k, B) for Scoped Code Intelligence Preloading"
  :x [PreloadTier
      tier-micro-ast
      tier-meso-symbol
      tier-macro-topology
      SymbolStub
      PreloadedHorizon
      preload-tier-to-string
      estimate-tokens
      estimate-stub-tokens
      stub-create
      horizon-create
      horizon-add-stub
      intel-preload-graph
      intel-preload
      format-preload-context]
  :i [(graph :a g)])

(dfe PreloadTier
  (:c tier-micro-ast [] "Target symbol at depth 0: hydrated with full AST / source body")
  (:c tier-meso-symbol [] "Direct caller/callee at depth 1: interface skeletons and signatures, zero bodies")
  (:c tier-macro-topology [] "Transitive boundary at depth 2: symbol name and 1-line docstring"))

(dfs SymbolStub
  (:f symbol Str "Canonical symbol name or identifier")
  (:f tier PreloadTier "Hydration representation tier")
  (:f path Str "Source file path")
  (:f signature Str "Function or type signature")
  (:f docstring Str "Documentation string or comment")
  (:f tokens I64 "Estimated token count for this stub"))

(dfs PreloadedHorizon
  (:f target-symbol Str "Root target symbol or module name")
  (:f max-depth I64 "Traversal depth limit k")
  (:f token-budget I64 "Upper token budget ceiling B")
  (:f total-tokens I64 "Sum of token estimates across all stubs")
  (:f stubs (List SymbolStub) "Paged symbol stubs in traversal order")
  (:f truncated Bool "True if token budget ceiling halted traversal"))

(df preload-tier-to-string [(tier PreloadTier)] -> Str
  :d "Convert PreloadTier enum variant to canonical string representation"
  (mt tier
    ((tier-micro-ast) "micro-ast")
    ((tier-meso-symbol) "meso-symbol")
    ((tier-macro-topology) "macro-topology")))

(df estimate-tokens [(text Str)] -> I64
  :d "Deterministic token count heuristic: max(1, length / 4), or 0 if empty"
  (let [(len (string-length text))]
    (if (<= len 0)
      0
      (let [(q (/ len 4))]
        (if (<= q 0) 1 q)))))

(df estimate-stub-tokens [(stub SymbolStub)] -> I64
  :d "Estimate token consumption for a SymbolStub based on explicit count or character heuristic"
  (if (> (.-tokens stub) 0)
    (.-tokens stub)
    (let [(text (str (.-symbol stub) " " (.-path stub) " " (.-signature stub) " " (.-docstring stub)))
          (toks (estimate-tokens text))]
      (if (<= toks 0) 1 toks))))

(df stub-create [(symbol Str)
                 (tier PreloadTier)
                 (path Str)
                 (signature Str)
                 (docstring Str)
                 (tokens I64)] -> SymbolStub
  :d "Constructs a SymbolStub record with explicit or heuristically estimated tokens"
  (let [(tok (if (> tokens 0)
               tokens
               (let [(text (str symbol " " path " " signature " " docstring))
                     (est (estimate-tokens text))]
                 (if (<= est 0) 1 est))))]
    (SymbolStub
      :symbol symbol
      :tier tier
      :path path
      :signature signature
      :docstring docstring
      :tokens tok)))

(df horizon-create [(target Str) (max-depth I64) (budget I64)] -> PreloadedHorizon
  :d "Initializes an empty PreloadedHorizon with 0 tokens and truncated: false"
  (PreloadedHorizon
    :target-symbol target
    :max-depth max-depth
    :token-budget budget
    :total-tokens 0
    :stubs (list)
    :truncated false))

(df horizon-add-stub [(h PreloadedHorizon) (stub SymbolStub)] -> PreloadedHorizon
  :d "Adds a stub to horizon, halting and setting truncated: true if budget exceeded or already truncated"
  (if (.-truncated h)
    h
    (let [(cost (estimate-stub-tokens stub))
          (new-total (+ (.-total-tokens h) cost))]
      (if (> new-total (.-token-budget h))
        (PreloadedHorizon
          :target-symbol (.-target-symbol h)
          :max-depth (.-max-depth h)
          :token-budget (.-token-budget h)
          :total-tokens (.-total-tokens h)
          :stubs (.-stubs h)
          :truncated true)
        (PreloadedHorizon
          :target-symbol (.-target-symbol h)
          :max-depth (.-max-depth h)
          :token-budget (.-token-budget h)
          :total-tokens new-total
          :stubs (list-append (.-stubs h) (list stub))
          :truncated false)))))

(df find-target-node [(nodes (List g/GraphNode)) (target Str)] -> (Option g/GraphNode)
  :d "Finds a GraphNode by id or name matching target"
  (let [(matches (filter (fn [(n g/GraphNode)] -> Bool (or (= (.-id n) target) (= (.-name n) target))) nodes))]
    (list-head matches)))

(df find-depth1-ids [(root-id Str) (edges (List g/GraphEdge))] -> (List Str)
  :d "Finds direct caller and callee symbol IDs connected to root-id"
  (fold (fn [(acc (List Str)) (e g/GraphEdge)] -> (List Str)
          (let [(neighbor (if (= (.-src e) root-id)
                            (.-dst e)
                            (if (= (.-dst e) root-id)
                              (.-src e)
                              "")))]
            (if (and (not (string-empty? neighbor))
                     (not (= neighbor root-id))
                     (not (list-contains? acc neighbor)))
              (list-append acc (list neighbor))
              acc)))
        (list)
        edges))

(df find-depth2-ids [(root-id Str) (d1-ids (List Str)) (edges (List g/GraphEdge))] -> (List Str)
  :d "Finds transitive neighbor symbol IDs connected to Depth 1 nodes excluding root and Depth 1"
  (fold (fn [(acc (List Str)) (e g/GraphEdge)] -> (List Str)
          (let [(src (.-src e))
                (dst (.-dst e))
                (acc1 (if (and (list-contains? d1-ids src)
                               (not (= dst root-id))
                               (not (list-contains? d1-ids dst))
                               (not (list-contains? acc dst)))
                        (list-append acc (list dst))
                        acc))]
            (if (and (list-contains? d1-ids dst)
                     (not (= src root-id))
                     (not (list-contains? d1-ids src))
                     (not (list-contains? acc1 src)))
              (list-append acc1 (list src))
              acc1)))
        (list)
        edges))

(df find-nodes-by-ids [(ids (List Str)) (all-nodes (List g/GraphNode))] -> (List g/GraphNode)
  :d "Resolves a list of symbol IDs to GraphNodes in order"
  (fold (fn [(acc (List g/GraphNode)) (id Str)] -> (List g/GraphNode)
          (let [(matched (find-target-node all-nodes id))]
            (mt matched
              ((some n) (list-append acc (list n)))
              ((none) acc))))
        (list)
        ids))

(df intel-preload-graph [(g g/SymbolGraph) (target Str) (depth I64) (token-budget I64)] -> PreloadedHorizon
  :d "Traverses SymbolGraph g up to depth k hydrated across 3 tiers subject to token budget B"
  (cond
    ((string-empty? (string-trim target))
     (horizon-create target depth token-budget))
    ((<= token-budget 0)
     (PreloadedHorizon
       :target-symbol target
       :max-depth depth
       :token-budget token-budget
       :total-tokens 0
       :stubs (list)
       :truncated true))
    (true
     (let [(nodes (.-nodes g))
           (edges (.-edges g))
           (matched (find-target-node nodes target))]
       (mt matched
         ((none)
          (horizon-create target depth token-budget))
         ((some root-n)
          (let [(root-stub (stub-create (.-id root-n)
                                        (tier-micro-ast)
                                        (.-file root-n)
                                        (.-signature root-n)
                                        (str "Full AST for " (.-name root-n))
                                        0))
                (h0 (horizon-create (.-id root-n) depth token-budget))
                (h1 (horizon-add-stub h0 root-stub))]
            (if (or (.-truncated h1) (<= depth 0))
              h1
              (let [(d1-ids (find-depth1-ids (.-id root-n) edges))
                    (d1-nodes (find-nodes-by-ids d1-ids nodes))
                    (h2 (fold (fn [(acc PreloadedHorizon) (n g/GraphNode)] -> PreloadedHorizon
                                (if (.-truncated acc)
                                  acc
                                  (horizon-add-stub acc (stub-create (.-id n)
                                                                     (tier-meso-symbol)
                                                                     (.-file n)
                                                                     (.-signature n)
                                                                     ""
                                                                     0))))
                              h1
                              d1-nodes))]
                (if (or (.-truncated h2) (<= depth 1))
                  h2
                  (let [(d2-ids (find-depth2-ids (.-id root-n) d1-ids edges))
                        (d2-nodes (find-nodes-by-ids d2-ids nodes))
                        (h3 (fold (fn [(acc PreloadedHorizon) (n g/GraphNode)] -> PreloadedHorizon
                                    (if (.-truncated acc)
                                      acc
                                      (horizon-add-stub acc (stub-create (.-id n)
                                                                         (tier-macro-topology)
                                                                         (.-file n)
                                                                         ""
                                                                         (str "Module/symbol: " (.-name n))
                                                                         0))))
                                  h2
                                  d2-nodes))]
                    h3)))))))))))

(df intel-preload [(target Str) (depth I64) (token-budget I64)] -> PreloadedHorizon
  :d "Top-level convenience entry point for graph horizon preloading"
  (intel-preload-graph (g/graph-create) target depth token-budget))

(df format-stub-asn [(stub SymbolStub)] -> Str
  :d "Serializes a SymbolStub into an ultra-dense ASN S-expression frame"
  (str "(:stub :symbol \"" (.-symbol stub)
       "\" :tier \"" (preload-tier-to-string (.-tier stub))
       "\" :path \"" (.-path stub)
       "\" :signature \"" (.-signature stub)
       "\" :docstring \"" (.-docstring stub)
       "\" :tokens " (string-from-int64 (.-tokens stub)) ")"))

(df format-preload-context [(horizon PreloadedHorizon)] -> Str
  :d "Serializes a PreloadedHorizon into an ultra-dense ASN context payload ready for LLM prompt injection"
  (let [(stubs (.-stubs horizon))
        (header (str "(:horizon :target \"" (.-target-symbol horizon)
                     "\" :budget " (string-from-int64 (.-token-budget horizon))
                     " :tokens " (string-from-int64 (.-total-tokens horizon))
                     " :truncated " (if (.-truncated horizon) "true" "false")))]
    (if (= (list-length stubs) 0)
      (str header "\n)")
      (let [(stub-frames (map (fn [(s SymbolStub)] -> Str (format-stub-asn s)) stubs))]
        (str header "\n  " (string-join "\n  " stub-frames) "\n)")))))
