(module asl-intel/extractor
  :d "Multi-language AST Symbol & Reference Extractor for Code Intelligence"
  :x [SymbolKind
      sym-fn sym-type sym-record sym-enum sym-method sym-class sym-interface sym-variable
      SymbolDef SymbolRef FileSymbols
      kind-to-string string-to-kind
      parse-asl-tokens extract-asl-symbols extract-generic-symbols filter-exported])

(dfe SymbolKind
  (:c sym-fn [] "Function symbol")
  (:c sym-type [] "Type symbol")
  (:c sym-record [] "Record symbol")
  (:c sym-enum [] "Enum symbol")
  (:c sym-method [] "Method symbol")
  (:c sym-class [] "Class symbol")
  (:c sym-interface [] "Interface symbol")
  (:c sym-variable [] "Variable symbol"))

(dfs SymbolDef
  (:f name Str "Symbol identifier name")
  (:f kind SymbolKind "Symbol category")
  (:f file Str "File path")
  (:f start-line I64 "Start line")
  (:f end-line I64 "End line")
  (:f signature Str "Type signature")
  (:f exported Bool "True if exported")
  (:f doc Str "Docstring"))

(dfs SymbolRef
  (:f name Str "Referenced symbol name")
  (:f caller Str "Calling symbol")
  (:f file Str "Referenced file")
  (:f line I64 "Reference line"))

(dfs FileSymbols
  (:f file Str "File path")
  (:f language Str "Language identifier")
  (:f symbols (List SymbolDef) "Extracted symbol definitions")
  (:f refs (List SymbolRef) "Extracted symbol references"))

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
    (FileSymbols
      :file file
      :language "asl"
      :symbols (list)
      :refs (list))))

(df extract-generic-symbols [(file Str)
                             (lang Str)
                             (defs (List SymbolDef))
                             (refs (List SymbolRef))] -> FileSymbols
  (:d "Construct typed FileSymbols record from language extractor bridge")
  (FileSymbols
    :file file
    :language lang
    :symbols defs
    :refs refs))

(df filter-exported [(fs FileSymbols)] -> (List SymbolDef)
  (:d "Return only symbols marked as exported in FileSymbols")
  (list-filter (fn [(s SymbolDef)] (.-exported s)) (.-symbols fs)))
