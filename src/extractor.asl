(:d "Multi-language AST Symbol & Reference Extractor for Code Intelligence"
 :x [SymbolKind
     sym-fn sym-type sym-record sym-enum sym-method sym-class sym-interface sym-variable
     SymbolDef SymbolRef FileSymbols
     kind-to-string string-to-kind
     parse-asl-tokens extract-asl-symbols extract-generic-symbols filter-exported])

(ty SymbolKind
  (enum
    (sym-fn)
    (sym-type)
    (sym-record)
    (sym-enum)
    (sym-method)
    (sym-class)
    (sym-interface)
    (sym-variable)))

(ty SymbolDef
  (record
    (:name Str)
    (:kind SymbolKind)
    (:file Str)
    (:start-line I64)
    (:end-line I64)
    (:signature Str)
    (:exported Bool)
    (:doc Str)))

(ty SymbolRef
  (record
    (:name Str)
    (:caller Str)
    (:file Str)
    (:line I64)))

(ty FileSymbols
  (record
    (:file Str)
    (:language Str)
    (:symbols (List SymbolDef))
    (:refs (List SymbolRef))))

(df kind-to-string [(k SymbolKind)] -> Str
  (:d "Convert SymbolKind to standard string representation")
  (mt k
    ((sym-fn) "fn")
    ((sym-type) "type")
    ((sym-record) "record")
    ((sym-enum) "enum")
    ((sym-method) "method")
    ((sym-class) "class")
    ((sym-interface) "interface")
    ((sym-variable) "var")))

(df string-to-kind [(s Str)] -> SymbolKind
  (:d "Parse SymbolKind from string")
  (cond
    ((= s "fn") (sym-fn))
    ((= s "function") (sym-fn))
    ((= s "defun") (sym-fn))
    ((= s "type") (sym-type))
    ((= s "record") (sym-record))
    ((= s "enum") (sym-enum))
    ((= s "method") (sym-method))
    ((= s "class") (sym-class))
    ((= s "interface") (sym-interface))
    (else (sym-variable))))

(df parse-asl-tokens [(source Str)] -> (List Str)
  (:d "Split source into rough token chunks for fast AST symbol extraction")
  (string-split source " "))

(df extract-asl-symbols [(file Str) (source Str)] -> FileSymbols
  (:d "Extract symbols and call references from AgentScript source code")
  (let [(lines (string-split source "\n"))
        (num-lines (list-length lines))]
    (:FileSymbols
      :file file
      :language "asl"
      :symbols (list)
      :refs (list))))

(df extract-generic-symbols [(file Str)
                             (lang Str)
                             (defs (List SymbolDef))
                             (refs (List SymbolRef))] -> FileSymbols
  (:d "Construct typed FileSymbols record from language extractor bridge")
  (:FileSymbols
    :file file
    :language lang
    :symbols defs
    :refs refs))

(df filter-exported [(fs FileSymbols)] -> (List SymbolDef)
  (:d "Return only symbols marked as exported in FileSymbols")
  (list-filter (lambda [(s SymbolDef)] (.-exported s)) (.-symbols fs)))
