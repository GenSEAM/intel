(module asl-intel/xref
  :d "Universal Cross-Reference Engine: Reference URI Parsing, Canonical Formatting, and Docstring Reference Extraction"
  :x [RefTarget
      CrossReference
      strip-ref-prefix
      clean-ref-token
      parse-ref-uri
      format-ref-uri
      ref-target-eq?
      ref-target-to-string
      extract-docstring-refs]
  :i [])

(dfs RefTarget
  (:f kind Str "Target domain kind: task, adr, c, sym, file, chunk, unknown")
  (:f id Str "Target domain-scoped identifier")
  (:f line I64 "Line number anchor for file references or 0"))

(dfs CrossReference
  (:f source Str "Origin entity or file containing the reference")
  (:f target RefTarget "Target reference record")
  (:f raw Str "Raw unparsed reference token")
  (:f context Str "Context or docstring excerpt containing the reference"))

(df strip-ref-prefix [(s Str)] -> Str
  :d "Strips leading @ref: prefix if present"
  (let [(trimmed (string-trim s))]
    (if (string-starts-with? trimmed "@ref:")
        (string-trim (option-or (string-slice trimmed 5 (string-length trimmed)) ""))
        trimmed)))

(df clean-ref-token [(tok Str)] -> Str
  :d "Strips punctuation and delimiters from an extracted reference token"
  (let [(t0 (string-trim tok))
        (t1 (if (string-starts-with? t0 "(") (option-or (string-slice t0 1 (string-length t0)) "") t0))
        (t2 (if (string-starts-with? t1 "\"") (option-or (string-slice t1 1 (string-length t1)) "") t1))
        (t3 (if (string-ends-with? t2 ")") (option-or (string-slice t2 0 (- (string-length t2) 1)) "") t2))
        (t4 (if (string-ends-with? t3 "\"") (option-or (string-slice t3 0 (- (string-length t3) 1)) "") t3))
        (t5 (if (string-ends-with? t4 "]") (option-or (string-slice t4 0 (- (string-length t4) 1)) "") t4))
        (t6 (if (string-ends-with? t5 ",") (option-or (string-slice t5 0 (- (string-length t5) 1)) "") t5))
        (t7 (if (string-ends-with? t6 ";") (option-or (string-slice t6 0 (- (string-length t6) 1)) "") t6))]
    (string-trim t7)))

(df parse-ref-uri [(uri Str)] -> RefTarget
  :d "Parses a canonical reference URI string into a typed RefTarget record"
  (let [(clean (strip-ref-prefix uri))]
    (cond
      ((string-starts-with? clean "task:")
       (let [(id (string-trim (option-or (string-slice clean 5 (string-length clean)) "")))]
         (RefTarget :kind "task" :id id :line 0)))
      ((string-starts-with? clean "adr:")
       (let [(id (string-trim (option-or (string-slice clean 4 (string-length clean)) "")))]
         (RefTarget :kind "adr" :id id :line 0)))
      ((string-starts-with? clean "d:")
       (let [(id (string-trim (option-or (string-slice clean 2 (string-length clean)) "")))]
         (RefTarget :kind "adr" :id id :line 0)))
      ((string-starts-with? clean "c:")
       (let [(id (string-trim (option-or (string-slice clean 2 (string-length clean)) "")))]
         (RefTarget :kind "c" :id id :line 0)))
      ((string-starts-with? clean "sym:")
       (let [(id (string-trim (option-or (string-slice clean 4 (string-length clean)) "")))]
         (RefTarget :kind "sym" :id id :line 0)))
      ((string-starts-with? clean "chunk:")
       (let [(id (string-trim (option-or (string-slice clean 6 (string-length clean)) "")))]
         (RefTarget :kind "chunk" :id id :line 0)))
      ((string-starts-with? clean "file:")
       (let [(rest (string-trim (option-or (string-slice clean 5 (string-length clean)) "")))]
         (if (string-contains? rest "#L")
             (let [(parts (string-split rest "#L"))
                   (path (option-or (list-get parts 0) rest))
                   (l-str (option-or (list-get parts 1) "0"))
                   (l-num (option-or (string-to-int64 l-str) 0))]
               (RefTarget :kind "file" :id path :line l-num))
             (RefTarget :kind "file" :id rest :line 0))))
      (:else
       (if (string-contains? clean ":")
           (let [(parts (string-split clean ":"))
                 (k (option-or (list-get parts 0) "unknown"))
                 (rest (option-or (list-get parts 1) clean))]
             (RefTarget :kind k :id rest :line 0))
           (RefTarget :kind "unknown" :id clean :line 0))))))

(df format-ref-uri [(target RefTarget)] -> Str
  :d "Formats a RefTarget record into its canonical URI string representation"
  (let [(k (.-kind target))
        (id (.-id target))
        (l (.-line target))]
    (cond
      ((= k "file")
       (if (> l 0)
           (str "file:" id "#L" (string-from-int64 l))
           (str "file:" id)))
      (:else
       (str k ":" id)))))

(df ref-target-to-string [(target RefTarget)] -> Str
  :d "Alias for format-ref-uri serializing target to string"
  (format-ref-uri target))

(df ref-target-eq? [(a RefTarget) (b RefTarget)] -> Bool
  :d "Compares two RefTarget records for value equality"
  (and (= (.-kind a) (.-kind b))
       (and (= (.-id a) (.-id b))
            (= (.-line a) (.-line b)))))

(df extract-docstring-refs [(source Str) (docstring Str)] -> (List CrossReference)
  :d "Scans an ASL docstring for @ref: URI annotations and parses them into CrossReference records"
  (let [(s1 (string-replace docstring "\n" " "))
        (s2 (string-replace s1 "\t" " "))
        (tokens (string-split s2 " "))
        (ref-tokens (filter (fn [(tok Str)] -> Bool
                              (string-contains? tok "@ref:"))
                            tokens))]
    (map (fn [(raw-tok Str)] -> CrossReference
           (let [(cleaned (clean-ref-token raw-tok))
                 (target (parse-ref-uri cleaned))]
             (CrossReference
               :source source
               :target target
               :raw cleaned
               :context docstring)))
         ref-tokens)))
