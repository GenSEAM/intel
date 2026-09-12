(module asl-intel/xref-test
  :d "Falsifiable Unit Verification Test Suite for Universal Cross-References, Dependency Graph, and Integrity Linter"
  :x [TestParseRefUriTask
      TestParseRefUriAdrAndC
      TestParseRefUriSymAndChunk
      TestParseRefUriFileAndFormat
      TestExtractDocstringRefs
      TestXrefGraphBidirectionalAndProvenance
      TestHealthIntegrityAndCycleDetection
      RunTests]
  :i [(xref :a xr)
      (health :a h)
      (asl-mem/xref :a mxr)])

(df TestParseRefUriTask [] -> Bool
  :d "Tests parsing of task shortcode reference URIs"
  (let [(t1 (xr/parse-ref-uri "task:task-325-1"))
        (t2 (xr/parse-ref-uri "ref:task:task-325-1"))]
    (assert (= (.-kind t1) "task") "Task URI kind must equal 'task'")
    (assert (= (.-id t1) "task-325-1") "Task URI id must equal 'task-325-1'")
    (assert (= (.-line t1) 0) "Task URI line must be 0")
    (assert (= (.-kind t2) "task") "ref: prefixed task kind must equal 'task'")
    (assert (= (.-id t2) "task-325-1") "ref: prefixed task id must equal 'task-325-1'")
    true))

(df TestParseRefUriAdrAndC [] -> Bool
  :d "Tests parsing of ADR and constraint invariant reference URIs"
  (let [(t-adr (xr/parse-ref-uri "adr:D0012"))
        (t-d (xr/parse-ref-uri "d:D0012"))
        (t-c (xr/parse-ref-uri "c:C0001"))]
    (assert (= (.-kind t-adr) "adr") "ADR URI kind must equal 'adr'")
    (assert (= (.-id t-adr) "D0012") "ADR URI id must equal 'D0012'")
    (assert (= (.-kind t-d) "adr") "d: shortcode URI kind must equal 'adr'")
    (assert (= (.-id t-d) "D0012") "d: shortcode URI id must equal 'D0012'")
    (assert (= (.-kind t-c) "c") "c: constraint URI kind must equal 'c'")
    (assert (= (.-id t-c) "C0001") "c: constraint URI id must equal 'C0001'")
    true))

(df TestParseRefUriSymAndChunk [] -> Bool
  :d "Tests parsing of exported symbol and memory chunk reference URIs"
  (let [(t-sym (xr/parse-ref-uri "sym:asl-harness/ModelOptions"))
        (t-chunk (xr/parse-ref-uri "chunk:chk-001"))]
    (assert (= (.-kind t-sym) "sym") "Symbol URI kind must equal 'sym'")
    (assert (= (.-id t-sym) "asl-harness/ModelOptions") "Symbol URI id must match package/symbol")
    (assert (= (.-kind t-chunk) "chunk") "Chunk URI kind must equal 'chunk'")
    (assert (= (.-id t-chunk) "chk-001") "Chunk URI id must equal 'chk-001'")
    true))

(df TestParseRefUriFileAndFormat [] -> Bool
  :d "Tests parsing file anchors, canonical formatting, and record value equality"
  (let [(t-file (xr/parse-ref-uri "file:intel/src/xref.asl:L42"))
        (fmt-file (xr/format-ref-uri t-file))
        (t-task (xr/parse-ref-uri "task:task-325-1"))
        (fmt-task (xr/format-ref-uri t-task))
        (t-task-copy (xr/parse-ref-uri "task:task-325-1"))
        (t-task-other (xr/parse-ref-uri "task:task-325-2"))]
    (assert (= (.-kind t-file) "file") "File URI kind must equal 'file'")
    (assert (= (.-id t-file) "intel/src/xref.asl") "File URI id must match file path")
    (assert (= (.-line t-file) 42) "File URI line anchor must equal 42")
    (assert (= fmt-file "file:intel/src/xref.asl:L42") "Formatted file URI must preserve line anchor")
    (assert (= fmt-task "task:task-325-1") "Formatted task URI must match canonical string")
    (assert (xr/ref-target-eq? t-task t-task-copy) "Identical RefTarget records must compare equal")
    (assert (not (xr/ref-target-eq? t-task t-task-other)) "Distinct RefTarget records must not compare equal")
    true))

(df TestExtractDocstringRefs [] -> Bool
  :d "Tests extraction of ref: annotations embedded in ASL docstrings"
  (let [(doc "Formats model request payload. ref:task:task-325-1 ref:adr:D0012 ref:c:C0001")
        (refs (xr/extract-docstring-refs "sym:asl-harness/format-request" doc))
        (r1 (first refs))
        (r2 (first (rest refs)))
        (r3 (first (rest (rest refs))))]
    (assert (= (list-length refs) 3) "Docstring must extract exactly 3 reference records")
    (assert (= (.-raw r1) "ref:task:task-325-1") "First ref raw token must match ref:task:task-325-1")
    (assert (= (.-kind (.-target r1)) "task") "First ref target kind must equal 'task'")
    (assert (= (.-id (.-target r1)) "task-325-1") "First ref target id must equal 'task-325-1'")
    (assert (= (.-kind (.-target r2)) "adr") "Second ref target kind must equal 'adr'")
    (assert (= (.-id (.-target r2)) "D0012") "Second ref target id must equal 'D0012'")
    (assert (= (.-kind (.-target r3)) "c") "Third ref target kind must equal 'c'")
    (assert (= (.-id (.-target r3)) "C0001") "Third ref target id must equal 'C0001'")
    true))

(df TestXrefGraphBidirectionalAndProvenance [] -> Bool
  :d "Tests universal bipartite dependency graph, prerequisites, and provenance resolution"
  (let [(g0 (mxr/make-xref-graph))
        (g1 (mxr/xref-add-edge g0 "task:task-325-2" "sym:asl-harness/ModelOptions" "depends-on"))
        (g2 (mxr/xref-add-edge g1 "task:task-325-3" "sym:asl-harness/ModelOptions" "depends-on"))
        (g3 (mxr/xref-add-edge g2 "file:harness/src/trace_recorder.asl" "sym:asl-harness/ModelOptions" "depends-on"))
        (g4 (mxr/xref-add-edge g3 "task:task-325-3" "task:task-325-1" "prerequisite"))
        (g5 (mxr/xref-add-edge g4 "task:task-325-3" "task:task-325-2" "prerequisite"))
        (g6 (mxr/xref-add-edge g5 "sym:asl-harness/ModelOptions" "task:task-325-1" "provenance"))
        (g7 (mxr/xref-add-edge g6 "sym:asl-harness/ModelOptions" "adr:D0012" "provenance"))
        (g8 (mxr/xref-add-edge g7 "sym:asl-harness/ModelOptions" "c:C0001" "provenance"))
        (deps (mxr/find-dependents g8 "sym:asl-harness/ModelOptions"))
        (prereqs (mxr/find-prerequisites g8 "task:task-325-3"))
        (prov (mxr/find-provenance g8 "sym:asl-harness/ModelOptions"))]
    (assert (= (list-length deps) 3) "ModelOptions must have exactly 3 downstream dependents")
    (assert (list-contains? deps "task:task-325-2") "Dependents must include task:task-325-2")
    (assert (list-contains? deps "task:task-325-3") "Dependents must include task:task-325-3")
    (assert (list-contains? deps "file:harness/src/trace_recorder.asl") "Dependents must include trace recorder")
    (assert (= (list-length prereqs) 2) "task-325-3 must have exactly 2 prerequisites")
    (assert (list-contains? prereqs "task:task-325-1") "Prerequisites must include task:task-325-1")
    (assert (list-contains? prereqs "task:task-325-2") "Prerequisites must include task:task-325-2")
    (assert (= (list-length prov) 3) "ModelOptions must have exactly 3 provenance records")
    (assert (list-contains? prov "task:task-325-1") "Provenance must include task:task-325-1")
    (assert (list-contains? prov "adr:D0012") "Provenance must include adr:D0012")
    (assert (list-contains? prov "c:C0001") "Provenance must include c:C0001")
    true))

(df TestHealthIntegrityAndCycleDetection [] -> Bool
  :d "Tests health integrity linter flagging broken references, dead pointers, and circular dependencies"
  (let [(doc-broken "ref:task:task-ghost-999")
        (refs-broken (xr/extract-docstring-refs "sym:test-func" doc-broken))
        (valid-targets (list "task:task-325-1" "task:task-325-2" "adr:D0012"))
        (broken-anoms (h/detect-broken-references refs-broken valid-targets))
        (ptrs (list "chk-valid-01" "chk-dangling-99"))
        (valid-bufs (list "chk-valid-01"))
        (ptr-anoms (h/detect-dangling-pointers ptrs valid-bufs))
        (edges-cyclic (list (h/RefEdge :source "task:task-A" :target "task:task-B")
                            (h/RefEdge :source "task:task-B" :target "task:task-A")))
        (cycle-anoms (h/detect-cyclic-references edges-cyclic))
        (doc-clean "ref:task:task-325-1")
        (refs-clean (xr/extract-docstring-refs "sym:clean-func" doc-clean))
        (clean-anoms (h/audit-reference-integrity refs-clean valid-targets))]
    (assert (= (list-length broken-anoms) 1) "Broken reference must produce exactly 1 anomaly")
    (assert (= (.-severity (first broken-anoms)) "error") "Broken reference severity must be error")
    (assert (= (.-symbol (first broken-anoms)) "task:task-ghost-999") "Broken anomaly symbol must match target")
    (assert (= (list-length ptr-anoms) 1) "Dangling pointer must produce exactly 1 anomaly")
    (assert (= (.-symbol (first ptr-anoms)) "chk-dangling-99") "Dangling pointer symbol must match target")
    (assert (> (list-length cycle-anoms) 0) "Cyclic cross-references must produce cycle anomaly")
    (assert (= (.-severity (first cycle-anoms)) "blocker") "Cyclic dependency must be blocker severity")
    (assert (= (list-length clean-anoms) 0) "Clean reference audit must produce zero anomalies")
    true))

(df RunTests [] -> Bool
  :d "Master test runner executing all Phase 333 verification suites"
  (let [(t1 (TestParseRefUriTask))
        (t2 (TestParseRefUriAdrAndC))
        (t3 (TestParseRefUriSymAndChunk))
        (t4 (TestParseRefUriFileAndFormat))
        (t5 (TestExtractDocstringRefs))
        (t6 (TestXrefGraphBidirectionalAndProvenance))
        (t7 (TestHealthIntegrityAndCycleDetection))] (and t1 (and t2 (and t3 (and t4 (and t5 (and t6 t7))))))))

(RunTests)

