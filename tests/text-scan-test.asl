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
    (and (= (.-file-path outline) "README.md")
         (and (> (.-total-lines outline) 10)
              (= (list-length (.-sections outline)) 4)))))

(df test-extract-doc-section [] -> Bool
  :d "Tests selective extraction of targeted markdown chapter"
  (let [(md (sample-markdown))
        (sec (ts/extract-doc-section md "Architecture Principles"))]
    (mt sec
      ((none) false)
      ((some body)
       (and (string-contains? body "Effective Decision Mode")
            (not (string-contains? body "Tool Reference")))))))

(df test-search-doc-snippets [] -> Bool
  :d "Tests keyword snippet search with line numbers"
  (let [(md (sample-markdown))
        (matches (ts/search-doc-snippets md "asl-mem"))]
    (and (= (list-length matches) 1)
         (= (.-line-number (first matches)) 14))))

(df test-format-doc-outline-asn [] -> Bool
  :d "Tests ASN outline formatting"
  (let [(md (sample-markdown))
        (outline (ts/scan-doc-outline md "TEST.md"))
        (asn-str (ts/format-doc-outline-asn outline))]
    (and (string-contains? asn-str "(:doc-outline :path \"TEST.md\"")
         (string-contains? asn-str "(:h1 :title \"Document Title\""))))

(df test-format-section-asn [] -> Bool
  :d "Tests ASN section slice formatting"
  (let [(res (ts/format-section-asn "DOC.md" "Header" "Content body"))]
    (and (string-contains? res "(:doc-section :path \"DOC.md\"")
         (string-contains? res ":title \"Header\""))))

(df run-tests [] -> Bool
  :d "Runs all text scan tests"
  (and (test-scan-doc-outline)
       (and (test-extract-doc-section)
            (and (test-search-doc-snippets)
                 (and (test-format-doc-outline-asn)
                      (test-format-section-asn))))))
