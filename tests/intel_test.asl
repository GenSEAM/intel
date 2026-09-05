(module asl-intel/tests/intel_test
  :d "Pure ASL test suite for code intelligence engine and metadata."
  :x [test-intel-version
      test-intel-banner]
  :i [(intel :a int)])

(df test-intel-version [] -> Bool
  :d "Verifies intel version string conforms to semver 0.1.0."
  (string-equals? (int/intel-version) "0.1.0"))

(df test-intel-banner [] -> Bool
  :d "Verifies intel banner contains GenSEAM identifier."
  (string-contains? (int/intel-banner) "GenSEAM ASL-Intel"))
