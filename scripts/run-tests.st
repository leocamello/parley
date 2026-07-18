"Parley loop harness — axiomatic SUnit runner for GNU Smalltalk 3.2.5.

 Executed ONLY via scripts/verify-sprint.sh (never run gst directly).

 Contract with verify-sprint.sh:
   - Loads src/compat, src/domain, tests/support, tests/laws, tests/acceptance
     (in that order; sorted within each dir). A flat tests/ dir is also loaded
     for backward compatibility.
   - Emits 'PARLEY-TESTFILE: <path>' after each test file loads cleanly, so
     the red-phase gate can verify test code itself is parse-clean.
   - Discovers every TestCase subclass defined by those file-ins.
   - Prints exactly one 'PARLEY-VERIFY: PASS|FAIL ...' sentinel line.
     gst 3.2.5 exits 0 even on parse errors and unhandled fileIn exceptions,
     so the sentinel — not the exit code alone — is the source of truth.
   - Exits via ObjectMemory quit: 0 on full pass, 1 otherwise.

 Determinism: the randomized law suites read their seed from the PARLEY_SEED
 environment variable (injected by verify-sprint.sh); this runner echoes it as
 'PARLEY-SEED:' so audits and SPRINT notes can record it."

| seed knownCases newCases suite result pass |

PackageLoader fileInPackage: 'SUnit'.

seed := (Smalltalk getenv: 'PARLEY_SEED') ifNil: ['20260718'].
Transcript showCr: 'PARLEY-SEED: ', seed.

knownCases := TestCase allSubclasses asSet.

"Ensure the Parley namespace exists even before any src/ file creates it
 (red phase starts with tests only)."
(Smalltalk includesKey: #Parley) ifFalse: [Smalltalk addSubspace: #Parley].

"Load order is semantic: compat polyfills, domain, then test support code,
 law suites, and acceptance scenarios. Within a directory, files load in
 sorted-path order for determinism."
#('src/compat' 'src/domain' 'tests' 'tests/support' 'tests/laws' 'tests/acceptance')
    do: [:dirName |
        | dir isTestDir |
        isTestDir := dirName startsWith: 'tests'.
        dir := File name: dirName.
        (dir exists and: [dir isDirectory]) ifTrue: [
            (dir files collect: [:f | f name]) asSortedCollection do: [:path |
                (path endsWith: '.st') ifTrue: [
                    Transcript showCr: 'PARLEY-LOAD: ', path.
                    FileStream fileIn: path.
                    isTestDir ifTrue: [
                        Transcript showCr: 'PARLEY-TESTFILE: ', path]]]]].

newCases := (TestCase allSubclasses reject: [:c | knownCases includes: c])
    asSortedCollection: [:a :b | a name <= b name].

suite := TestSuite new.
newCases do: [:testClass |
    (testClass selectors asSortedCollection: [:a :b | a <= b]) do: [:sel |
        (sel asString startsWith: 'test') ifTrue: [
            suite addTest: (testClass selector: sel)]]].

suite tests isEmpty ifTrue: [
    Transcript showCr: 'PARLEY-VERIFY: FAIL reason=no-tests-discovered'.
    Transcript showCr: 'No TestCase subclasses with test* selectors were loaded from tests/.'.
    ObjectMemory quit: 1].

result := suite run.

result failures do: [:each | Transcript showCr: 'PARLEY-FAILURE: ', each printString].
result errors do: [:each | Transcript showCr: 'PARLEY-ERROR: ', each printString].

pass := (result runCount > 0)
    and: [(result failureCount = 0) and: [result errorCount = 0]].

Transcript showCr: 'PARLEY-VERIFY: ', (pass ifTrue: ['PASS'] ifFalse: ['FAIL']),
    ' seed=', seed,
    ' run=', result runCount printString,
    ' passed=', result passedCount printString,
    ' failed=', result failureCount printString,
    ' errors=', result errorCount printString.

ObjectMemory quit: (pass ifTrue: [0] ifFalse: [1])
