(module asl-intel/text-scan-test
  :d "Unit tests for dense text and markdown document intelligence"
  :x [test-scan-doc-outline
      test-extract-doc-section
      test-search-doc-snippets
      test-format-doc-outline-asn
      test-format-section-asn
      run-tests]
  :i [(text-scan :a ts)])

(df sample-markdown [] -> Str
  (str "# Document Title\n\n"
       "Intro paragraph explaining the system.\n\n"
       "## Architecture Principles\n"
       "We operate under Effective Decision Mode.\n"
       "Always minimize code diffs.\n\n"
       "### Sub-Section A\n"
       "Detail on memory model.\n\n"
       "## Tool Reference\n"
       "- Tool 1: asl-intel\n"
       "- Tool 2: asl-mem\n"))

(df test-scan-doc-outline [] -> Bool
  :d "Tests header extraction and line calculation"
  (let [(md (sample-markdown))
        (outline (ts/scan-doc-outline md "README.md"))]
    (assert (= (.-file-path outline) "README.md") "Outline file-path must match README.md")
    (assert (> (.-total-lines outline) 10) "Outline total lines must exceed 10")
    (assert (= (list-length (.-sections outline)) 4) "Outline sections count must be 4")
    true))

(df test-extract-doc-section [] -> Bool
  :d "Tests selective extraction of targeted markdown chapter"
  (let [(md (sample-markdown))
        (sec (ts/extract-doc-section md "Architecture Principles"))
        (missing (ts/extract-doc-section md "Nonexistent Section"))]
    (assert (mt sec
              ((none) false)
              ((some body)
               (and (string-contains? body "Effective Decision Mode")
                    (not (string-contains? body "Tool Reference"))))) "Section extraction must contain targeted content without trailing chapter")
    (assert (option-none? missing) "Missing section must return none")
    true))

(df test-search-doc-snippets [] -> Bool
  :d "Tests keyword snippet search with line numbers"
  (let [(md (sample-markdown))
        (matches (ts/search-doc-snippets md "asl-mem"))]
    (assert (= (list-length matches) 1) "Snippet search must match exactly 1 line")
    (assert (= (.-line-number (first matches)) 14) "Snippet line number must be 14")
    true))

(df test-format-doc-outline-asn [] -> Bool
  :d "Tests ASN outline formatting"
  (let [(md (sample-markdown))
        (outline (ts/scan-doc-outline md "TEST.md"))
        (asn-str (ts/format-doc-outline-asn outline))]
    (assert (string-contains? asn-str "(:doc-outline :path \"TEST.md\"") "ASN outline must format :doc-outline path")
    (assert (string-contains? asn-str "(:h1 :title \"Document Title\"") "ASN outline must format :h1 title")
    true))

(df test-format-section-asn [] -> Bool
  :d "Tests ASN section slice formatting"
  (let [(res (ts/format-section-asn "DOC.md" "Header" "Content body"))]
    (assert (string-contains? res "(:doc-section :path \"DOC.md\"") "ASN section must format :doc-section path")
    (assert (string-contains? res ":title \"Header\"") "ASN section must format :title Header")
    true))

(df run-tests [] -> Bool
  :d "Runs all text scan tests"
  (let [(t1 (test-scan-doc-outline))
        (t2 (test-extract-doc-section))
        (t3 (test-search-doc-snippets))
        (t4 (test-format-doc-outline-asn))
        (t5 (test-format-section-asn))] (and t1 (and t2 (and t3 (and t4 t5))))))
