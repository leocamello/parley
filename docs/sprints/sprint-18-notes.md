# Sprint 18 — the authoring boundary speaks Parley's voice

**Issue:** [#20](https://github.com/leocamello/parley/issues/20) · **Roadmap §2 item 2**, item 2 of the seven holding the v1.0 tag.
**Specs of record:** Doc B §2.2 → Doc E §3.1 → Doc E §4.1 → §8 decisions **61, 62, 74, 75**.

> **Governing sentence:** the manifest-authoring boundary was the only place in Parley where text reached the user that Parley did not write. After this sprint there is none.

## Audit

```
sprint: 18
date: 2026-08-10T15:23:23Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=876 passed=876 failed=0 errors=0
```

`gst --version` first line, exactly: `GNU Smalltalk version 3.2.5`

Traceability: every scenario `S1`–`S14` in issue #20 has a matching `testSn_*` selector. Red gate: `876 run / 853 passed / 16 failed / 7 errors`, six declared passes, reproduced by the operator.

---

## 1. What changed

| File | Change |
| --- | --- |
| `src/manifest/ManifestCapture.st` | **new class.** Rebinds the global `Transcript` to a collector, evaluates a block its caller supplies, restores the previous binding unconditionally in an `ensure:`, answers the collected text. No file I/O, no policy. |
| `src/exec/ManifestFile.st` | step 2's namespace swap + `FileStream fileIn:` wrapped in a `ManifestCapture` block; the file-and-line anchor mined from the capture; the dangling `Object:` line terminated when an anchor is recovered; the re-voiced anchor diagnosis; the decision-44 batch header prepended to the authoring problems. |
| `src/exec/CommandLine.st` | `ensureDirectory:` distinguishes *exists and is not a directory* from *the parent cannot be written*, in that method, so all four call sites are covered by construction; `wrongTypeStateDirectoryTail` declares the row's second sentence beside `pathBoundaries`. |
| `README.md` | *When your `Package.st` is broken* — both diagnoses and both C-level fragments, with the stream each reaches. |
| tests (RED) | `tests/support/AuthoringFixtures.st`, `tests/support/StateRootFixtures.st`, `tests/laws/ManifestCaptureTest.st`, `tests/laws/AuthoringDiagnosisTest.st`, `tests/laws/BoundaryTableTest.st` (+1 law), `tests/acceptance/Sprint18AcceptanceTest.st` (14 selectors). |
| settled oracles amended | six sites, each **bounded to adding the header** — `LockBoundaryTest` ×3, `Sprint9AcceptanceTest>>testS4_…`, `AddVerbTest` ×2. No settled literal moved by one byte. |

**The census stays at eight.** `ManifestCapture` performs no direct `File`/`FileStream`/`Directory` I/O, asserted over its own source against the settled `PathFixtures directIoSendSources`, so §8 decision 61 is a mechanism rather than a memory. `ManifestFile isLoading` scoping is unchanged.

---

## 2. The defects, as shipped bytes

Captured through `bin/parley-main.st` with **stdout and stderr redirected to separate files**. "Before" is the pre-sprint product tree (`git archive 896e6c3`), "after" is this commit. `<S>` stands in for the fixture root. Note that gst spells a backtrace frame's file *relative to the child's working directory*, so a real installation prints those frames as absolute paths into the checkout.

### Defect 1 — a malformed manifest printed a kernel backtrace

**Before** — exit `1`, stdout **12 lines / 900 bytes**, stderr **0 bytes**. Four lines are paths into Parley's own source tree:

```
Object: nil error: did not understand #foo
Smalltalk.MessageNotUnderstood(Smalltalk.Exception)>>signal (ExcHandling.st:254)
Smalltalk.UndefinedObject(Smalltalk.Object)>>doesNotUnderstand: #foo (SysExcept.st:1448)
optimized [] in Smalltalk.UndefinedObject>>executeStatements (Package.st:2)
Parley class>>manifestFrom: (../../before/src/manifest/Parley.st:105)
[] in Parley class>>define: (../../before/src/manifest/Parley.st:77)
Smalltalk.BlockClosure>>on:do: (BlkClosure.st:193)
[] in Parley class>>define: (../../before/src/manifest/Parley.st:78)
Smalltalk.BlockClosure>>on:do: (BlkClosure.st:193)
Parley class>>define: (../../before/src/manifest/Parley.st:80)
Smalltalk.UndefinedObject>>executeStatements (Package.st:1)
<S>/ev/raise/Package.st: no manifest defined - the file never sent Parley define:
```

**After** — exit `1`, stdout **2 lines / 220 bytes**, stderr **0 bytes**:

```
Object: nil
<S>/ev/raise/Package.st: line 2 raised an error while the manifest was being read - fix that line and try again
```

The line number is mined from the capture's own `UndefinedObject>>executeStatements (<file>:<line>)` frame — a file and a line the tool had been throwing away for the commonest authoring mistake there is. **Only the line is mined, never the file:** gst spells the frame's file relative to the child's cwd, so the diagnosis opens with the path Parley was given.

### Defect 2 — the authoring diagnoses never named the file

**Before** — exit `1`, stdout **4 lines / 149 bytes**, stderr **0 bytes**. Four bare lines, no header, nothing naming the file to open:

```
missing required field name
invalid version 'nope'
fileIns must declare at least one file to load
invalid constraint 'garbage' for dependency 'demo'
```

**After** — exit `1`, stdout **5 lines / 299 bytes**, stderr **0 bytes**:

```
<S>/ev/four/Package.st: 4 problem(s) in this manifest
missing required field name
invalid version 'nope'
fileIns must declare at least one file to load
invalid constraint 'garbage' for dependency 'demo'
```

Every sentence is byte-identical. The path was added *around* them.

### The carried gap — F13 / §8 decision 74

A regular file at `<workdir>/.parley`, working directory writable (`test -w` says so):

| | stdout | exit |
| --- | --- | --- |
| **Before** | `<S>/ev/f1: could not be written - check its permissions and try again` | `1` |
| **After** | `<S>/ev/f1/.parley: not a directory - remove it and try again` | `1` |

A regular file at `<workdir>/.parley/packages`, `.parley` a writable directory:

| | stdout | exit |
| --- | --- | --- |
| **Before** | `<S>/ev/f2/.parley: could not be written - check its permissions and try again` | `1` |
| **After** | `<S>/ev/f2/.parley/packages: not a directory - remove it and try again` | `1` |

And the fourth call site the sprint's own scenarios never reached — a regular file at `<workdir>/.parley/index` under `--index`:

| | stdout | exit |
| --- | --- | --- |
| **Before** | `<S>/ev/f4/.parley: could not be written - check its permissions and try again` | `1` |
| **After** | `<S>/ev/f3/.parley/index: not a directory - remove it and try again` | `1` |

stderr was 0 bytes in all six. The exit code was `1` before and after, which is why no law failed and Sprint 17's headline criterion held: **the defect was a false sentence, not a wrong code.**

### The two kept fragments, and the unparseable manifest

Unparseable `Package.st`, after — exit `1`, stdout **1 line / 180 bytes**, stderr **151 bytes**:

```
stdout: <S>/ev/unparse/Package.st: no manifest defined - the file never sent Parley define:
stderr: <S>/ev/unparse/Package.st:3: parse error, expected ']'
```

The settled literal is **not re-toned** — Parley cannot distinguish an unparseable manifest from one that never sent `define:` (on the parse path `fileIn:` returns normally, nothing is recorded, the capture is empty), and the sentence is true of both. The information separating them is on stderr, unsuppressed.

Success path, after — exit `0`, stdout `no dependencies to resolve - wrote parley.lock` (47 bytes), stderr **0 bytes**. Nothing captured is printed.

---

## 3. Ambiguities hit, and how each resolved

1. **S4's four named literals are not simultaneously reachable.** The settled `ManifestBuilder>>build` reports a version as *missing* **or** as *invalid*, never both, so no manifest yields the set the issue listed. Raised at the RED review; **the issue was amended and two reachable four-problem manifests were approved**, covering all four literals against hand-written oracles.
2. **The batch header breaks settled oracles.** Enumerated four at the RED review and approved bounded to adding the header. **The enumeration was incomplete: two more surfaced at GREEN** (`AddVerbTest>>testAnEditThatWillNotLoadIsRolledBack` and `…UnparseableConstraintIsJudgedByTheSettledBuilderAndRolledBack`). Both are the same bounded change, applied and disclosed. The miss is the lesson, not the fix — see §4.
3. **`Object: <receiver>` fuses with the next line.** Disclosed at RED as a bounded limitation whose *content* was stated but whose *terminator* was not. **Ruled: terminated, not merely stated** (§8 decision 62 amended). `ManifestFile` ends the dangling line **when it recovers an anchor** — never on "the capture is non-empty", because a manifest that merely printed on its own behalf leaves no residue and the weaker predicate emits a stray blank line at exit `0`. S1 strengthened from substring containment to exact captured bytes; S11 strengthened by the operator to assert both streams on the success path.
4. **A reviewed law asserted restoration inside an `on:do:` handler.** Halted mid-GREEN rather than editing it. **Ruled as §8 decision 75:** the measured order is `block, handler, ensure`, so the law now pins *both* halves — still swapped inside the handler, restored once it returns. My halt was right and **my stated ground was wrong**: I reported the assertion "unsatisfiable by construction", and catch-plus-`pass` does restore earlier and swallows nothing. It is refused for wrapping the author's whole program in a broad catch and for disturbing the signalling chain `isLoading` rests on. The wrong ground is corrected in `ManifestCapture`'s own method comment — a sentence asserting a cause it had not checked, in the file the sprint is named for.

---

## 4. Toolchain and method facts worth keeping

- **`Parley define:` without `Namespace current: Parley` silently does nothing.** The global `Parley` is the *namespace*, and 3.2.5 namespaces treat an unknown keyword send as a binding setter — so `Parley define: [...]` sets a binding named `define:`, never evaluates the block, and raises nothing. A capture around it comes back **0 bytes** and looks exactly like a manifest that behaved. Any fixture that files a manifest in outside `ManifestFile load:` must set the namespace first. This cost one probe and would cost somebody a session.
- **`String <=` on 3.2.5 folds case.** `'no define:' <= 'no Package.st'` is **true** — `d` before `p`, not `P` before `d`. A sorted-oracle literal written in ASCII order made a law's *membership* assertion fail first, so its driver loop never ran: in red **and** in green it reported a failure that said nothing about the claim it exists to check. That is method finding **F14**'s blind spot *inside* a law rather than in front of one, and the gate cannot see it because a FAILURE is a FAILURE. Every sorted oracle in this sprint's fixtures is now either computed or commented with the collation.
- **A `TextCollector` buffers, so the collector must be flushed before the binding is put back.** Flushing after the restore flushes the real `Transcript` and loses the tail. The flush is the first statement of the `ensure:` block so it also runs on the non-local-exit path.
- **The frame that carries the anchor is the first `UndefinedObject>>executeStatements (`.** A 3.2.5 dump names innermost frames first, so the first match is the line the author must open (line 2), not the line the `define:` send sits on (line 1). The `doesNotUnderstand:` frame beside it spells `UndefinedObject(...Object)>>` and cannot be mistaken for it. A frame Parley cannot parse answers **no** anchor rather than a wrong one.
- **A completeness list derived from spellings is not a census** (decision 60, one level over). The settled-oracle enumeration was built by grepping the problem *literals*; `AddVerbTest` reaches its problems through `ManifestEditFixtures` and never matched. Deriving it from the *property* — every settled assertion on the lines of an authoring load — found both. This is the same shape as decision 60 and as F12, and it is offered for the relational inventory rather than written into `docs/method/`, which is operator-authored.
- **An unparseable `Package.st` must never be filed in inside the harness.** 3.2.5 reports the syntax error on stderr at C level, `verify-sprint.sh` captures the suite's own stderr, and the red gate refuses any run whose output carries a parser complaint — it cannot tell a fixture's from the suite's. The fixture is driven only as a child process with stderr redirected, and every law that asserts on that fragment builds it from two words and prints a label rather than the phrase.

---

## 5. Scope

Two declared settled-class exceptions used, both in `src/exec/`: `ManifestFile` and `CommandLine`. `Parley.Parley`, `ManifestBuilder`, `ManifestError`, `batchedErrorClasses` and `CLI` are untouched. `scripts/run-tests.st` unchanged; `scope-18` unchanged. No child process output is buffered, no redirect is composed, no flag is added — roadmap §3's *output capture* row stays deferred, and this sprint's capture is the in-image `Transcript` inside Parley's own process with no child involved. Decision 45 untouched.

**Open close-out obligations for the operator:** the cache-root call sites (`.parley/git`, `.parley/index`) are fixed by construction and proven by probe above, but carry **no shape-driver rows** — recorded at the RED review as a close-out obligation rather than scope creep.

**The tag is not cut.** It is held on seven items at the operator's ruling; this is item 2.
