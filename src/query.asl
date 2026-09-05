(module asl-intel/query
  :d "Transitive Reachability & Impact Query Engine for Code Intelligence"
  :x [QueryKind
      q-search q-callers q-callees q-impact q-affected q-context
      ImpactItem QueryResult
      format-query-kind filter-by-depth make-query-result])

(ty QueryKind
  (enum
    (q-search)
    (q-callers)
    (q-callees)
    (q-impact)
    (q-affected)
    (q-context)))

(ty ImpactItem
  (record
    (:symbol-id Str)
    (:name Str)
    (:file Str)
    (:depth I64)))

(ty QueryResult
  (record
    (:query Str)
    (:kind QueryKind)
    (:items (List ImpactItem))
    (:total I64)))

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
  (list-filter (lambda [(item ImpactItem)] (<= (.-depth item) max-d)) items))

(df make-query-result [(q Str) (k QueryKind) (items (List ImpactItem))] -> QueryResult
  (:d "Create a QueryResult record")
  (:QueryResult
    :query q
    :kind k
    :items items
    :total (list-length items)))
