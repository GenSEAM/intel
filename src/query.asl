(module asl-intel/query
  :d "Transitive Reachability & Impact Query Engine for Code Intelligence"
  :x [QueryKind
      q-search q-callers q-callees q-impact q-affected q-context
      ImpactItem QueryResult
      format-query-kind filter-by-depth make-query-result])

(dfe QueryKind
  (:c q-search [] "Search query")
  (:c q-callers [] "Callers query")
  (:c q-callees [] "Callees query")
  (:c q-impact [] "Impact query")
  (:c q-affected [] "Affected query")
  (:c q-context [] "Context query"))

(dfs ImpactItem
  (:f symbol-id Str "Symbol identifier")
  (:f name Str "Symbol name")
  (:f file Str "File path")
  (:f depth I64 "Transitive reachability depth"))

(dfs QueryResult
  (:f query Str "Query string")
  (:f kind QueryKind "Query category")
  (:f items (List ImpactItem) "Impact items list")
  (:f total I64 "Total matching items count"))

(df format-query-kind [(k QueryKind)] -> Str
  (:d "Format QueryKind to string representation")
  (mt k
    ((q-search) "search")
    ((q-callers) "callers")
    ((q-callees) "callees")
    ((q-impact) "impact")
    ((q-affected) "affected")
    ((q-context) "context")))

(df filter-by-depth [(items (List ImpactItem)) (max-d I64)] -> (List ImpactItem)
  (:d "Filter ImpactItem list by maximum reachability depth")
  (list-filter (fn [(item ImpactItem)] (<= (.-depth item) max-d)) items))

(df make-query-result [(q Str) (k QueryKind) (items (List ImpactItem))] -> QueryResult
  (:d "Create a QueryResult record")
  (QueryResult
    :query q
    :kind k
    :items items
    :total (list-length items)))
