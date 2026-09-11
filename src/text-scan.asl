(module asl-intel/text-scan
  :d "Dense Text & Markdown Document Intelligence: Header Outlining, Targeted Section Extraction, and Snippet Search without Context Drowning."
  :x [TextSection
      TextDocOutline
      TextMatchSlice
      scan-doc-outline
      extract-doc-section
      search-doc-snippets
      format-doc-outline-asn
      format-section-asn]
  :i [])

(dfs TextSection
  (:f title Str "Section header title")
  (:f level I64 "Header nesting level: 1 for #, 2 for ##, 3 for ###")
  (:f start-line I64 "Starting 1-indexed line number")
  (:f end-line I64 "Ending 1-indexed line number")
  (:f lines-count I64 "Number of lines spanned by this section"))

(dfs TextDocOutline
  (:f file-path Str "Relative or absolute document path")
  (:f total-lines I64 "Total line count in source document")
  (:f sections (List TextSection) "List of discovered section headers"))

(dfs TextMatchSlice
  (:f line-number I64 "1-indexed line number of match")
  (:f preview Str "Trimmed snippet content of matching line"))

(df parse-header-level [(line Str)] -> I64
  :d "Detects markdown header depth: 1 for #, 2 for ##, 3 for ###, 0 if not a header."
  (let [(trimmed (string-trim line))]
    (cond
      ((string-starts-with? trimmed "#### ") 4)
      ((string-starts-with? trimmed "### ") 3)
      ((string-starts-with? trimmed "## ") 2)
      ((string-starts-with? trimmed "# ") 1)
      (:else 0))))

(df extract-header-title [(line Str) (lvl I64)] -> Str
  :d "Extracts the header text after leading hash symbols."
  (let [(trimmed (string-trim line))]
    (cond
      ((= lvl 1) (string-trim (option-or (string-slice trimmed 2 (string-length trimmed)) "")))
      ((= lvl 2) (string-trim (option-or (string-slice trimmed 3 (string-length trimmed)) "")))
      ((= lvl 3) (string-trim (option-or (string-slice trimmed 4 (string-length trimmed)) "")))
      ((= lvl 4) (string-trim (option-or (string-slice trimmed 5 (string-length trimmed)) "")))
      (:else trimmed))))

(df scan-doc-outline [(content Str) (file-path Str)] -> TextDocOutline
  :d "Scans markdown text line by line to build a compact structural section outline."
  (let [(lines (string-split content "\n"))
        (tot-lines (list-length lines))]
    (if (<= tot-lines 0)
        (TextDocOutline :file-path file-path :total-lines 0 :sections (list))
        (let [(secs0 (list))
              (indexed-lines (list-indexed lines))
              (found-secs (foldl (fn [(acc (List TextSection)) (pair (Tuple I64 Str))] -> (List TextSection)
                                   (let [(idx (tuple-first pair))
                                         (line (tuple-second pair))
                                         (lvl (parse-header-level line))]
                                     (if (> lvl 0)
                                         (let [(title (extract-header-title line lvl))
                                               (line-no (+ idx 1))]
                                           (append-item acc (TextSection
                                                              :title title
                                                              :level lvl
                                                              :start-line line-no
                                                              :end-line tot-lines
                                                              :lines-count 1)))
                                         acc)))
                                 secs0
                                 indexed-lines))]
          (TextDocOutline
            :file-path file-path
            :total-lines tot-lines
            :sections found-secs)))))

(df extract-doc-section [(content Str) (section-title Str)] -> (Option Str)
  :d "Extracts only the specified section text from the document, stopping at the next header."
  (let [(lines (string-split content "\n"))
        (in-section false)
        (captured (list))
        (target-low (string-to-lower section-title))
        (res (foldl (fn [(acc (Tuple Bool (List Str))) (line Str)] -> (Tuple Bool (List Str))
                      (let [(active (tuple-first acc))
                            (items (tuple-second acc))
                            (lvl (parse-header-level line))]
                        (if active
                            (if (> lvl 0)
                                (tuple false items)
                                (tuple true (append-item items line)))
                            (if (> lvl 0)
                                (let [(title (string-to-lower (extract-header-title line lvl)))]
                                  (if (string-contains? title target-low)
                                      (tuple true (append-item items line))
                                      (tuple false items)))
                                (tuple false items)))))
                    (tuple in-section captured)
                    lines))]
    (let [(final-items (tuple-second res))]
      (if (list-empty? final-items)
          (none)
          (some (string-join final-items "\n"))))))

(df search-doc-snippets [(content Str) (query Str)] -> (List TextMatchSlice)
  :d "Finds all occurrences of query in document text, returning line numbers and compact snippets."
  (let [(lines (string-split content "\n"))
        (query-low (string-to-lower query))
        (indexed (list-indexed lines))]
    (foldl (fn [(acc (List TextMatchSlice)) (pair (Tuple I64 Str))] -> (List TextMatchSlice)
             (let [(idx (tuple-first pair))
                   (line (tuple-second pair))
                   (line-low (string-to-lower line))]
               (if (string-contains? line-low query-low)
                   (append-item acc (TextMatchSlice
                                      :line-number (+ idx 1)
                                      :preview (string-trim line)))
                   acc)))
           (list)
           indexed)))

(df format-doc-outline-asn [(outline TextDocOutline)] -> Str
  :d "Serializes a document outline into compact ASN S-expression representation."
  (let [(base (str "(:doc-outline :path \"" (.-file-path outline) "\" :lines " (int-to-string (.-total-lines outline)) " :sections ["))
        (sec-str (foldl (fn [(acc Str) (sec TextSection)] -> Str
                          (str acc "(:h" (int-to-string (.-level sec))
                               " :title \"" (.-title sec) "\""
                               " :line " (int-to-string (.-start-line sec)) ") "))
                        base
                        (.-sections outline)))]
    (str (string-trim sec-str) "])")))

(df format-section-asn [(file-path Str) (section-title Str) (section-body Str)] -> Str
  :d "Serializes a targeted document section slice into compact ASN representation."
  (str "(:doc-section :path \"" file-path "\" :title \"" section-title "\" :body \"" section-body "\")"))
