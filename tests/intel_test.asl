(module asl-intel/tests/intel_test
  :d "Pure ASL test suite for code intelligence engine and metadata."
  :x [test-intel-version
      test-intel-banner
      run-tests]
  :i [(intel :a int)])

(df test-intel-version [] -> Bool
  :d "Verifies intel version string conforms to semver 0.1.0."
  (let [(v (int/intel-version))]
    (assert (string-equals? v "0.1.0") "Intel version must be 0.1.0")
    true))

(df test-intel-banner [] -> Bool
  :d "Verifies intel banner contains GenSEAM identifier."
  (let [(b (int/intel-banner))]
    (assert (string-contains? b "GenSEAM ASL-Intel") "Intel banner must contain GenSEAM ASL-Intel")
    (assert (string-contains? b "0.1.0") "Intel banner must contain version 0.1.0")
    true))

(df run-tests [] -> Bool
  :d "Runs all intel unit tests."
  (let [(_t1 (test-intel-version))
        (_t2 (test-intel-banner))]
    true))
