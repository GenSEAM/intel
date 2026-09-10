(module asl-intel/hotspot-coverage
  :d "Hotspot tracing, planned traversal DAGs, actual coverage recording, and gap analysis engine."
  :x [HotspotTarget
      PlannedTraversal
      ActualVisit
      ActualCoverage
      CoverageGap
      CoverageComparison
      create-hotspot-target
      create-planned-traversal
      plan-add-target
      plan-target-count
      record-visit
      create-actual-coverage
      coverage-add-visit
      coverage-visit-count
      is-target-visited?
      find-gaps
      calculate-drift
      compare-traversal-paths
      format-coverage-report
      render-traversal-graph]
  :i [])

(dfs HotspotTarget
  (:f id Str "Canonical hotspot identifier, e.g. file:symbol")
  (:f file Str "Source file path")
  (:f symbol Str "Target symbol or module identifier")
  (:f fan-in I64 "In-degree fan-in or dependency blast radius score")
  (:f priority I64 "Inspection priority: 1 (critical blocker) to 5 (low)")
  (:f rationale Str "Epistemic motivation for auditing this hotspot")
  (:f planned-depth I64 "Target inspection depth: 0=macro, 1=meso, 2=micro-ast"))

(dfs PlannedTraversal
  (:f plan-id Str "Unique traversal plan identifier")
  (:f title Str "Human-readable purpose of audit exploration")
  (:f targets (List HotspotTarget) "Ordered list of planned hotspot targets")
  (:f total-budget I64 "Total token budget ceiling allocated for traversal"))

(dfs ActualVisit
  (:f target-id Str "Identifier of inspected hotspot target")
  (:f file Str "File visited during exploration")
  (:f actual-depth I64 "Actual inspection depth achieved: 0=macro, 1=meso, 2=micro-ast")
  (:f status Str "Inspection verdict: verified, gap, clean, rejected")
  (:f findings-count I64 "Count of issues or observations recorded")
  (:f tokens-spent I64 "Token consumption recorded during visit"))

(dfs ActualCoverage
  (:f run-id Str "Exploration execution run identifier")
  (:f session-id Str "Active agent session lease identifier")
  (:f visits (List ActualVisit) "Recorded inspection visits")
  (:f total-tokens I64 "Accumulated tokens spent across all visits"))

(dfs CoverageGap
  (:f target-id Str "Planned hotspot target that was missed or degraded")
  (:f file Str "Source file coordinates")
  (:f expected-depth I64 "Planned inspection depth")
  (:f severity Str "Gap severity: blocker, critical, warning")
  (:f reason Str "Diagnostic reason: unvisited, depth-incongruity, findings-unaddressed"))

(dfs CoverageComparison
  (:f plan-id Str "Reference plan identifier")
  (:f total-planned I64 "Total targets planned")
  (:f total-visited I64 "Total visits recorded")
  (:f covered-count I64 "Count of planned targets successfully visited")
  (:f gap-count I64 "Count of unvisited or degraded planned targets")
  (:f drift-count I64 "Count of visited targets not in original plan")
  (:f coverage-pct I64 "Coverage percentage from 0 to 100")
  (:f gaps (List CoverageGap) "List of identified coverage gaps")
  (:f is-complete Bool "True if all planned targets covered without gaps"))

(df create-hotspot-target [(id Str) (file Str) (symbol Str) (fan-in I64) (priority I64) (rationale Str) (depth I64)] -> HotspotTarget
  :d "Constructs a planned HotspotTarget record."
  (HotspotTarget
    :id id
    :file file
    :symbol symbol
    :fan-in fan-in
    :priority priority
    :rationale rationale
    :planned-depth depth))

(df create-planned-traversal [(id Str) (title Str) (budget I64)] -> PlannedTraversal
  :d "Initializes an empty PlannedTraversal record."
  (PlannedTraversal
    :plan-id id
    :title title
    :targets (list)
    :total-budget budget))

(df plan-add-target [(plan PlannedTraversal) (target HotspotTarget)] -> PlannedTraversal
  :d "Appends a target to the PlannedTraversal."
  (PlannedTraversal
    :plan-id (.-plan-id plan)
    :title (.-title plan)
    :targets (list-append (.-targets plan) (list target))
    :total-budget (.-total-budget plan)))

(df plan-target-count [(plan PlannedTraversal)] -> I64
  :d "Returns count of planned hotspot targets."
  (list-length (.-targets plan)))

(df record-visit [(target-id Str) (file Str) (depth I64) (status Str) (findings I64) (tokens I64)] -> ActualVisit
  :d "Constructs an ActualVisit record."
  (ActualVisit
    :target-id target-id
    :file file
    :actual-depth depth
    :status status
    :findings-count findings
    :tokens-spent tokens))

(df create-actual-coverage [(run-id Str) (session-id Str)] -> ActualCoverage
  :d "Initializes an empty ActualCoverage tracking ledger."
  (ActualCoverage
    :run-id run-id
    :session-id session-id
    :visits (list)
    :total-tokens 0))

(df coverage-add-visit [(cov ActualCoverage) (visit ActualVisit)] -> ActualCoverage
  :d "Appends a visit to ActualCoverage."
  (ActualCoverage
    :run-id (.-run-id cov)
    :session-id (.-session-id cov)
    :visits (list-append (.-visits cov) (list visit))
    :total-tokens (+ (.-total-tokens cov) (.-tokens-spent visit))))

(df coverage-visit-count [(cov ActualCoverage)] -> I64
  :d "Returns count of recorded inspection visits."
  (list-length (.-visits cov)))

(df is-target-visited? [(target-id Str) (visits (List ActualVisit))] -> Bool
  :d "Checks if a target has been visited."
  (fold (fn [(found Bool) (v ActualVisit)] -> Bool
          (if found true (= (.-target-id v) target-id)))
        false
        visits))

(df find-visit-depth [(target-id Str) (visits (List ActualVisit))] -> I64
  :d "Returns achieved depth for a visited target, or -1 if unvisited."
  (fold (fn [(d I64) (v ActualVisit)] -> I64
          (if (>= d 0) d (if (= (.-target-id v) target-id) (.-actual-depth v) -1)))
        -1
        visits))

(df find-gaps [(targets (List HotspotTarget)) (visits (List ActualVisit))] -> (List CoverageGap)
  :d "Identifies missing or depth-degraded hotspots by comparing planned targets against visits."
  (fold (fn [(gaps (List CoverageGap)) (t HotspotTarget)] -> (List CoverageGap)
          (let [(tid (.-id t))
                (actual-d (find-visit-depth tid visits))]
            (cond
              ((< actual-d 0)
               (let [(gap (CoverageGap
                            :target-id tid
                            :file (.-file t)
                            :expected-depth (.-planned-depth t)
                            :severity (if (<= (.-priority t) 2) "critical" "warning")
                            :reason "unvisited"))]
                 (list-append gaps (list gap))))
              ((< actual-d (.-planned-depth t))
               (let [(gap (CoverageGap
                            :target-id tid
                            :file (.-file t)
                            :expected-depth (.-planned-depth t)
                            :severity "warning"
                            :reason "depth-incongruity"))]
                 (list-append gaps (list gap))))
              (true gaps))))
        (list)
        targets))

(df is-target-in-plan? [(tid Str) (targets (List HotspotTarget))] -> Bool
  :d "Checks if visited target was declared in plan."
  (fold (fn [(in-plan Bool) (t HotspotTarget)] -> Bool
          (if in-plan true (= (.-id t) tid)))
        false
        targets))

(df calculate-drift [(visits (List ActualVisit)) (targets (List HotspotTarget))] -> I64
  :d "Counts visits to targets not declared in original traversal plan."
  (fold (fn [(acc I64) (v ActualVisit)] -> I64
          (if (is-target-in-plan? (.-target-id v) targets) acc (+ acc 1)))
        0
        visits))

(df count-covered [(targets (List HotspotTarget)) (visits (List ActualVisit))] -> I64
  :d "Counts planned targets that were visited with sufficient depth."
  (fold (fn [(acc I64) (t HotspotTarget)] -> I64
          (let [(d (find-visit-depth (.-id t) visits))]
            (if (>= d (.-planned-depth t)) (+ acc 1) acc)))
        0
        targets))

(df compare-traversal-paths [(plan PlannedTraversal) (actual ActualCoverage)] -> CoverageComparison
  :d "Compares planned traversal DAG against actual coverage."
  (let [(targets (.-targets plan))
        (visits (.-visits actual))
        (tot-plan (list-length targets))
        (tot-vis (list-length visits))
        (gaps (find-gaps targets visits))
        (gap-cnt (list-length gaps))
        (cov-cnt (count-covered targets visits))
        (drift (calculate-drift visits targets))
        (pct (if (> tot-plan 0) (/ (* cov-cnt 100) tot-plan) 100))]
    (CoverageComparison
      :plan-id (.-plan-id plan)
      :total-planned tot-plan
      :total-visited tot-vis
      :covered-count cov-cnt
      :gap-count gap-cnt
      :drift-count drift
      :coverage-pct pct
      :gaps gaps
      :is-complete (= gap-cnt 0))))

(df format-gap-item [(g CoverageGap)] -> Str
  :d "Formats a single CoverageGap S-expression item."
  (str "(:gap :target "" (.-target-id g) "" :file "" (.-file g) "" :severity "" (.-severity g) "" :reason "" (.-reason g) "")"))

(df format-coverage-report [(comp CoverageComparison)] -> Str
  :d "Formats a structured S-expression coverage report."
  (let [(gaps-str (string-join (fold (fn [(acc (List Str)) (g CoverageGap)] -> (List Str)
                                       (list-append acc (list (format-gap-item g))))
                                     (list)
                                     (.-gaps comp))
                               " "))]
    (str "(:coverage-report"
         " :plan-id "" (.-plan-id comp) """
         " :planned " (string-from-int64 (.-total-planned comp))
         " :visited " (string-from-int64 (.-total-visited comp))
         " :covered " (string-from-int64 (.-covered-count comp))
         " :gaps-count " (string-from-int64 (.-gap-count comp))
         " :drift " (string-from-int64 (.-drift-count comp))
         " :coverage-pct " (string-from-int64 (.-coverage-pct comp))
         " :is-complete " (if (.-is-complete comp) "true" "false")
         " :gaps [ " gaps-str " ])")))

(df render-traversal-graph [(plan PlannedTraversal) (actual ActualCoverage)] -> Str
  :d "Renders Adjacency DSL graph representation of planned versus actual traversal."
  (let [(targets (.-targets plan))
        (visits (.-visits actual))
        (edges (fold (fn [(acc (List Str)) (t HotspotTarget)] -> (List Str)
                       (let [(tid (.-id t))
                             (is-vis (is-target-visited? tid visits))
                             (status (if is-vis "covered" "gap"))]
                         (list-append acc (list (str tid ":" status)))))
                     (list)
                     targets))
        (edges-str (string-join edges " "))]
    (str "(:traversal-graph (" (.-plan-id plan) " > " edges-str "))")))
