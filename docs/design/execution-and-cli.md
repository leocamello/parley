# Parley Design — Execution Scope & CLI

> **Scope:** `ProcessRunner`, `ExecutionScope`, `ExecutionError`, `ManifestFile`, `CLI`, `CliResult` — the Phase 3 closer (Sprint 6) — plus `CommandLine` and the diagnosis boundary (Sprint 8) and `LockError` (Sprint 9). All classes in the `Parley` namespace, all in `src/exec/`; structural immutability applies throughout (class-side construction; zero public setters). This document is where Parley finally touches the operating system: it defines the ONE process seam, the curated child `gst` invocation, the resolution of the deferred `gst Package.st` caveat (master plan §8 decision 19), and the command-line verbs wired over Sprints 0–5. Every 3.2.5 mechanic pinned here was verified empirically against the toolchain at staging (issue #8).

---

## 1. `ProcessRunner` (the one process seam)

The **only** pathway in all of Parley by which a child process is ever created. Everything above it composes command lines as pure string values; everything at it is one thin, dumb executor.

- `ProcessRunner class >> new` — stateless; exists as an instance so tests can substitute a recording/failing double.
- `run: aCommandString` — executes the command via the 3.2.5 kernel's `Smalltalk system:` and answers the child's **exit code** as an Integer. 3.2.5's `system:` answers the raw wait status (exit code × 256); `run:` normalizes it: `status // 256`. `0` is success; nothing is signaled — the code is an answer, and its meaning belongs to the caller.
- No output capture in MVP: the child's stdout/stderr flow to Parley's own (the CLI is a terminal program). No shell-quoting layer: Parley composes its own command lines from paths it controls.

## 2. `ExecutionScope` (the curated child image)

The honest `bundle exec` for 3.2.5 (§8 decision 16), and the single home of invocation logic. A scope holds three collaborators immutably:

- `ExecutionScope class >> on: anInstalledSet target: aTargetDir runner: aProcessRunner`.

### 2.1 Registration (executing Sprint 5's plan)

- `registrationCommands` — exactly `anInstalledSet registrationCommandsFor: aTargetDir` (the Doc D §4 plan; a pure value).
- `register` — runs each plan line, in the plan's order (sorted package-name order, each package's staging line immediately before its registration line — Doc D §4), through the runner. The first nonzero exit signals one **`ExecutionError`** naming the exact command line and the exit code; later commands are not attempted. **Fail-stop, not batched:** an execution failure is environmental (a broken toolchain, an unwritable disk, a corrupt archive rejected by `gst-package`), unlike install problems, which are per-package data problems — retrying the rest teaches nothing and can half-register an environment. Empirical anchor (issue #8 ruling): 3.2.5's `gst-package` validates the archive (a `.star` is a zip) and exits `1` on a non-archive file (`gst-package: Invalid argument`) — the staging line copies any bytes, so garbage fails precisely on the registration line. Note the flagless mode: 3.2.5's option parser accepts **no** `--install` spelling; install is the default mode, and the `--help` text claiming the flag is stale upstream.
- Registration is (re-)runnable: the staging copy and `gst-package --target-directory` both overwrite identical files harmlessly (verified). Switching or rolling back an environment re-points at a different target — it never mutates one. The `.parley-staging/` directory the plan writes under the target is invisible to the child (`PackageLoader` scans the image directory for `*.star` files only) and is left in place — target-confined residue, not state.

### 2.2 The child invocation

- `childCommandFor: aScriptPath` — the pinned composition, exact:

  ```
  gst -i -I <aTargetDir>/parley.im --no-user-files <aScriptPath>
  ```

  Why each element (verified against 3.2.5; corrected by the issue #8 ruling): `-I <target>/parley.im` places the image in the target directory, and 3.2.5's `PackageLoader` local package registry follows the image directory — every `.star` sitting there is visible to the child **by its filename**: `Kernel.StarPackage` requires the `package.xml` name to equal the filename basename (`kernel/PkgLoader.st`), so a package is loadable iff `<target>/<InternalName>.star` exists. This is why Doc D §4's plan registers each archive under its true name — a content-addressed `<sha256>.star` is invisible to the child. `--no-user-files` excludes `~/.st` customizations. `-i` rebuilds the image from the kernel every run: no state leaks between runs, and the scope needs no image lifecycle management. The platform's system packages remain visible to the child — they are the host runtime, as a language's standard library is under any `bundle exec`.

- `run: aScriptPath` — `runner run: (childCommandFor: aScriptPath)`, answering the child's exit code. A nonzero child is the script's own business — an answer, never an `ExecutionError`.

## 3. `ManifestFile` (decision 19 resolved)

`ManifestFile class >> load: aPath` reads the developer's **own** `Package.st` and answers its `LibraryManifest`:

0. **check the path first** (Sprint 8): if `aPath` does not exist or is not readable, signal a one-problem `ManifestError` naming the path and the verb that writes one (exact wording pinned in RED). This is the sprint's **third declared settled-class exception**, granted at the Sprint 8 RED review. It exists because 3.2.5's `FileStream fileIn:` signals `SystemExceptions.FileError` — a *kernel* error — on a missing file, so without this check the most ordinary user error in the tool (`resolve` before `parley init`) reaches §4.2's boundary as an **undiagnosed** error and is answered with exit `70`: *"this is a defect in Parley, not in your project."* That is the fail-wrong disease in its second form — not a lying exit code, but a lying attribution of blame. A missing `Package.st` is the operator's problem and Parley must say so: exit `1`, one problem, naming the fix.
1. clear the recorded manifest;
2. file the path in with `Namespace current: Parley` — inside the namespace the token `Parley` resolves to the `Parley.Parley` gateway (§8 decision 19), so the Doc B §2 syntax works verbatim;
3. answer the manifest recorded by `define:`; if the file recorded nothing (no `define:` reached), signal a one-problem `ManifestError`-style error naming the path (exact wording pinned in RED).

**The authoring-error boundary** (Sprint 9, closing half of the decision-32 gap): the file-in of step 2 is wrapped so that a **`ManifestVocabularyError`** — the author sending a selector outside the manifest vocabulary — becomes one `ManifestError` problem carrying the vocabulary error's own message text, suggestion included. The error already *reads* as a diagnosis (`Package.st sent #nmae - not part of the manifest vocabulary. Did you mean #name?`); until Sprint 9 it was merely *classified* as an internal defect, so the boundary answered exit `70` and told the author their typo was Parley's bug. Nothing about the message changes — only who is blamed for it. `ManifestVocabularyError` is therefore never signaled out of a verb, and the §4.2 closed set can say so without qualification.

The recording is the sprint's **sole settled-class exception**: `Parley.Parley class >> define:` gains one send — `ManifestFile record: manifest` — before answering. All recording state (the holder, the clear, the read) lives in `ManifestFile`; nothing else in the gateway moves.

**Trust boundary unchanged** (architecture §2.2): only the root application's own manifest is ever loaded this way — the file its author owns and runs. Third-party `Package.st` files are never evaluated by anything (their information enters only as static index entries through the literals-only reader); the hard bans still hold — file-in of the owner's manifest is the authoring path Doc B §2 always specified, and no third-party byte ever reaches it.

## 4. `CLI` and `CliResult`

- `CLI class >> in: aWorkingDir source: aPackageSource store: aContentStore target: aTargetDir runner: aProcessRunner` — every collaborator injected (`source` may be `nil` for verbs that need none); tests pass doubles, the executable wrapper passes the real ones. The CLI reads `Package.st` and `parley.lock` in `aWorkingDir`.
- `run: anArgvArray` — dispatches the verb and answers a **`CliResult`**: an immutable value carrying `lines` (Array of Strings — everything the wrapper should print) and `exitCode` (Integer). The CLI **never** prints, never terminates the image, and never touches a process except through the scope's runner: it is an orchestration answering a value. Argv grammar (MVP): `init` | `resolve` | `install` | `update` | `exec <script>`. An unknown verb, a missing `exec` script, or a source-requiring verb with no source answers usage lines with exit code `2`.

### 4.1 Verbs

- **`init`** — writes the Doc B §2 template `Package.st` in the working directory; refuses (one line, exit `1`) if the file exists.
- **`resolve`** — `ManifestFile load:` → `source snapshot` → `Resolver`. A `Resolution` is written to `parley.lock` via the settled `IndexEntryWriter writeLock:on:` (byte-stable) and reported, exit `0`. A `ConflictReport` answers its narration lines, exit `1` — a conflict is a value, never an exception.
- **`install`** — the lockfile fast path, then the Sprint 5 pipeline, then registration:
  1. **Pin fast path:** if `parley.lock` exists, read it (settled reader), rebuild the `Resolution` (`fromLockEntry:`), and check `PinVerification of: manifest lock: resolution`. **The read is a boundary** (Sprint 9): a lockfile that does not parse, or parses but is not a `#'parley-lock' 1` artifact, signals one **`LockError`** naming the lock path and the reader's own message (wording pinned in RED) — never a raw `IndexEntryParseError`/`IndexEntryFormatError`, which is how a corrupt lock used to reach the §4.2 boundary undiagnosed and be answered with exit `70`. The diagnosis names **`parley update`** as the repair, because `update` is the one verb that ignores the lock entirely and rewrites it — the same shape as `init` in the missing-`Package.st` diagnosis (§8 decision 31). A corrupt lock is the operator's file, not Parley's defect. Valid ⇒ that resolution is used **without consuming the source's snapshot** (mechanically provable: a snapshot-signaling source double). Invalid or absent ⇒ resolve fresh and rewrite the lock.
  2. **Hash-vs-cache:** for every pinned sha256 the store contains, `verifyHash:` must answer `true`. A tampered entry is a **fail-stop corruption report** naming the hash (exact wording pinned in RED), exit `1` — the store never repairs itself (Doc D §3: detection only; repair is an operator action).
  3. **Install:** `Installer install:` (cache hits skip fetch; an `InstallError`'s problems become the lines, exit `1`).
  4. **Register:** `ExecutionScope register` over the installed set (an `ExecutionError`'s message becomes the lines, exit `1`). Exit `0` on success.
- **`update`** — ignores any existing lock: resolve fresh, rewrite `parley.lock`, then install + register as above. (`install` keeps a valid pin; `update` is the verb that moves it.)
- **`exec <script>`** — `ExecutionScope run:` with the script; `CliResult` carries the child's exit code and no lines of its own (the child already streamed to the terminal).

### 4.2 `CommandLine` — the wiring, as an object (Sprint 8)

The wrapper used to hold the wiring *and* the flag grammar *and* the error boundary, and was declared "glue, excluded from SUnit obligations". That declaration was wrong and it cost: the hardcoded file-in list silently missed `src/publish/`, so the shipped `publish` verb answered a `doesNotUnderstand:` backtrace — **and exited `0`**. Untested glue that decides an exit code is not glue; it is the product. Everything the wrapper did except loading, printing and exiting now lives in an object with laws.

- `CommandLine class >> in: aWorkingDir runner: aProcessRunner` — the working directory (`Package.st`, `parley.lock`, and the `.parley/` state beneath it) and the one process seam, held immutably. Construction is **pathname-passive**: no I/O, no process. Class-side construction; zero public setters; no value equality (the decision-23 precedent).
- `run: anArgvArray` — the whole wrapper's logic as a value-answering message: strip a leading `--`, parse the flag grammar out of the argv, wire the real collaborators, send `CLI run:`, and map anything that escapes to a diagnosis. Answers a **`CliResult`** — it never prints and never terminates the image.
  - **Flag grammar (MVP):** `--source <dir>` ⇒ a `DirectorySource` over `<dir>`; `--git <repo>` ⇒ a `GitIndexSource` over `<repo>` (Sprint 9); absent ⇒ `nil` (the verbs that need none still run). The two are **mutually exclusive** — both given is a usage error, exit `2`, because silently preferring one would make a typo look like a working command. The remaining arguments are the verb argv handed to `CLI run:` unchanged.
  - **The source flags are a declared table, not a chain** (Sprint 9): `CommandLine class >> sourceFlags` maps each flag to the source class it builds, and a **drift law** requires every `*Source` class shipped in `src/source/` to appear in it. Sprint 8's `bin/` drift law covers *directories*, and `GitIndexSource` proved a class can sit inside a named directory and still be unreachable because no flag builds it. Directories and flags are two different reachability questions and each needs its own law.
  - **Wiring:** store at `<aWorkingDir>/.parley/store`, target at `<aWorkingDir>/.parley/packages` (created when absent), the git cache at `<aWorkingDir>/.parley/git/<sha256 of the repo location>` (Sprint 9 — the settled `Sha256` keys it, so any repo string becomes one deterministic filesystem-safe name and no escaping layer is invented), the injected runner. Deriving both from the working directory rather than the process's cwd is what makes the wiring law-testable under `tmp/`.

#### The diagnosis boundary

**No Parley command ever answers a backtrace, and no failing command ever exits `0`.** `run:` maps every outcome onto exactly three shapes:

| Outcome | `lines` | `exitCode` |
| --- | --- | --- |
| Success | the verb's own lines | `0` |
| Usage (unknown verb, wrong arity, source-requiring verb with no source) | the pinned usage lines | `2` |
| A **diagnosed** problem — the verb answered it, or a declared Parley error reached the boundary | the problems / the message | `1` |
| An **undiagnosed** error — anything else reaching the boundary | one line naming the error's class and message text (wording pinned in RED) | `70` |

- The **declared Parley errors** are `ManifestError`, `SourceError`, `InstallError`, `ExecutionError`, `PublishError` and — from Sprint 9 — `LockError`. An error carrying `problems` contributes those as the lines; one carrying only a `messageText` contributes that as a single line. Exit `1` — the tool understood what went wrong and is telling the operator.
- Anything else is a **defect in Parley**, not in the operator's project: exit **`70`** (`EX_SOFTWARE`), distinct from `1` so a script can tell "your input is wrong" from "the tool is broken". Still one line, never a backtrace: Parley diagnoses, it does not dump.
- The boundary is a **closed set with a law**: every `Error` subclass defined in the `Parley` namespace is either mapped to exit `1` here, or is **declared undiagnosed with its ground named** — either *provably never signaled out of a verb*, or *reaching exit `70` by a named escape path that is accepted, for now, as fail-stop*. The two lists must partition the enumeration, so a new error class can never drift into the `70` bucket silently: the law fails first, and whoever adds the class must decide which list it belongs to and say why.

  **Sprint 9 restores the strong claim.** The two boundaries above — the lock read (§4.1) and the authoring file-in (§3) — remove all three named escapes, so from Sprint 9 every undiagnosed class is *provably never signaled out of a verb* and the weaker second ground has no members. It stays written down because the law must keep accepting it: the next error class to arrive may legitimately need it, and a partition rule that silently has only one branch is a rule nobody remembers is there.

  The weaker second ground was chosen at the Sprint 8 RED review over a claim the code could not support. Of the five currently undiagnosed classes, `ConstraintFormatError` and `VersionFormatError` meet the strong claim — every caller inside a verb catches them. Three do not, and their escape paths are declared rather than hidden: `IndexEntryParseError` and `IndexEntryFormatError` escape the `CLI`'s `parley.lock` read, and `ManifestVocabularyError` escapes `ManifestFile load:` when the author's own `Package.st` has a typo. All three land on exit `70` — nonzero, one line, no backtrace — so the fail-stop invariant holds and no script is ever lied to about success. What they lack is the *right blame*: they are the operator's problems reported as Parley's. Reclassifying them as exit-`1` diagnoses needs a lock-validation boundary and an authoring-error boundary, which is design and not a fix; it is a **ruled gap carried out of Sprint 8**, not a licence to leave the list vague.
- The mapping is expressed as **`on:do:` handlers**, never an `isKindOf:` chain. Smalltalk's exception system already *is* the taxonomy; re-implementing it as branching would be the kind-branching the architecture bans, and would silently mis-handle a subclass. `CommandLine` classifies by handling, and the one thing it decides is which of the four shapes above the outcome takes.

`CommandLine` is a **composition root**, not a manager: it holds no domain state, makes no domain decision, and answers a value. It exists because the wiring and the boundary are decisions — and decisions belong in objects with laws, not in a script nobody tests.

### 4.3 The executable wrapper (genuinely thin)

`bin/parley` (POSIX sh, ~3 lines) execs `gst -f bin/parley-main.st -- <argv>`; `parley-main.st` lives in `bin/` — NOT `src/exec/`, whose every `.st` the test harness files in, and a main script executes on file-in. It does exactly four things and holds no logic:

1. file in **every** directory under `src/`, in load order;
2. send `CommandLine in: <cwd> runner: ProcessRunner new` `run: <argv>`;
3. print the result's lines;
4. `ObjectMemory quit:` the result's exit code.

Printing and exiting happen **here alone**. The file-in list stays explicit because load order is semantic, and it is **law-guarded**: a law reads the wrapper's own source and requires every existing `src/` subdirectory to appear in it, so a new `src/` directory can never again ship unreachable. (Per-invocation file-in is the honest MVP cost; a prebuilt image is deferred tooling polish.)

## 5. SUnit Requirements for This Doc

- **`ProcessRunner`:** real execution laws — a command exiting `7` answers `7`; success answers `0`.
- **`ExecutionScope`:** the pinned child command composition (pure, exact string); `register` executes the real plan (real `gst-package`, real archive bytes land byte-identical in the target as `<name>.star`); fail-stop on the first failing command (real: staging copies garbage bytes fine, then `gst-package` exits `1` on the non-archive — the `ExecutionError` names that registration command and code; later commands never run); `run:` really launches the curated child (a script leaves a sentinel; the exit code comes back).
- **`ManifestFile`:** loading a written `Package.st` answers the built manifest (round-trips name/version/dependencies); a define-less file signals the pinned error; **an absent path signals the pinned one-problem `ManifestError` before any file-in is attempted** (Sprint 8) — observable at the boundary as exit `1`, never `70`; **a `Package.st` sending an out-of-vocabulary selector signals one `ManifestError` carrying the vocabulary error's message and suggestion** (Sprint 9), and the same input through the shipped binary exits `1` with no backtrace.
- **The lock boundary (Sprint 9):** an unparseable `parley.lock` and a wrong-tag `parley.lock` each signal one `LockError` naming the path and the reader's message, on `install` and on any verb that reads the lock; `update` is unaffected by a corrupt lock and repairs it (it never reads one); the diagnosis names `parley update`. Observable at the §4.2 boundary as exit `1`, never `70`.
- **`CommandLine` source flags (Sprint 9):** `--git <repo>` wires a `GitIndexSource` whose cache is `<workingDir>/.parley/git/<sha256 of repo>` (nothing beside the process cwd); `--source` and `--git` together answer usage, exit `2`; and the **source drift law** — every `*Source` class shipped in `src/source/` appears in `CommandLine class >> sourceFlags`, so a source can never again be lawful and unreachable.
- **`CLI`:** every verb law — init template + refusal; resolve's byte-stable lock oracle and conflict narration; the fast-path skip proof (valid lock + primed store + a source double failing both `snapshot` and `fetch:version:` ⇒ success); stale-lock re-resolution; the corruption fail-stop; update re-pinning what install would keep; exec propagating the child code; usage/exit-2 shapes.
- **`CommandLine` (Sprint 8):** the wiring laws — `publish` reaches a real `Publisher` through the wiring (the shipped defect, closed); `--source <dir>` still wires the settled verbs; the store and target land under the *working directory*, not the process cwd. The boundary laws — a declared Parley error becomes its problems and exit `1`; an undeclared error becomes one pinned line and exit **`70`** (provable with a runner double signaling a plain `Error`); **no failing outcome ever answers exit `0`**. The closed-set law: every `Error` subclass in the `Parley` namespace is accounted for by the boundary.
- **The shipped binary (Sprint 8):** laws that run `bin/parley-main.st` itself as a child process through `ProcessRunner` — success exits `0`, a diagnosed failure exits nonzero, and neither prints a backtrace. Plus the drift law: the wrapper's own source names **every** existing `src/` subdirectory. These are the only laws that test glue, and they exist because glue that chooses an exit code is not glue.
- **End-to-end (the sprint's exit):** entries + a real archive (a toolchain-**built** `.star`: `gst-package --target-directory <dir> <pkgdir>/package.xml` builds `<dir>/<name>.star` from an authored package.xml + `.st` file — lowercase internal name per Doc B §3.4 and the name-equality constraint, Doc D §4) → resolve → lockfile → install → register → a curated child proves the package's class is visible — **a package lands in an image**. System stars are never copied as fixtures: their capitalized internal names violate §3.4 under name equality.
- **Digest discipline (amended for real archives):** authored opaque byte strings keep operator-verifiable pinned digest literals (Doc D style); toolchain-built `.star` bytes vary by machine, so their entry digests are computed at fixture time through the **settled, vector-anchored** `Sha256` — never pinned as literals, and never used to test `Sha256` itself.
- **Hygiene:** every directory (working dirs, stores, targets, child images) lives under `tmp/`, unique per test, removed in tearDown; `tmp/` empty or absent after a clean run. **The developer image is never mutated**: no test files a package into the harness image; real processes appear only where the law under test IS execution, and always confined to `tmp/`.
