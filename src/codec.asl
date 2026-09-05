(module asl-intel/codec
  :d "Token-Dense ASN S-Expression Codec for Code Intelligence"
  :x [encode-symbol-asn encode-edge-asn encode-impact-asn encode-asn-response])

(df encode-symbol-asn [(name Str)
                       (kind Str)
                       (loc Str)
                       (sig Str)
                       (exported Bool)] -> Str
  (:d "Encode a symbol node into an ultra-dense ASN S-expression frame")
  (str "(:s \"" name "\" :" kind " @" loc (if exported " :x" "") " :sig \"" sig "\")"))

(df encode-edge-asn [(src Str) (dst Str) (kind Str)] -> Str
  (:d "Encode a graph edge into an ultra-dense ASN S-expression frame")
  (str "(:e \"" src "\" :" kind " \"" dst "\")"))

(df encode-impact-asn [(name Str) (file Str) (depth I64)] -> Str
  (:d "Encode an impact entry into a compact ASN frame")
  (str "(:i \"" name "\" @" file " :d " (string-from-int64 depth) ")"))

(df encode-asn-response [(tag Str) (frames (List Str))] -> Str
  (:d "Combine multiple ASN frames into a structured response container")
  (str "(@" tag "\n  " (string-join "\n  " frames) "\n)"))
