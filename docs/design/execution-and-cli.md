# Parley Design — Execution Scope & CLI

> **Scope:** `ProcessRunner`, `ExecutionScope`, `ExecutionError`, `ManifestFile`, `CLI`, `CliResult` — the Phase 3 closer (Sprint 6). All classes in the `Parley` namespace, all in `src/exec/`; structural immutability applies throughout (class-side construction; zero public setters). This document is where Parley finally touches the operating system: it defines the ONE process seam, the curated child `gst` invocation, the resolution of the deferred `gst Package.st` caveat (master plan §8 decision 19), and the command-line verbs wired over Sprints 0–5. Every 3.2.5 mechanic pinned here was verified empirically against the toolchain at staging (issue #8).

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
- `register` — runs each plan line, in the plan's sorted package-name order, through the runner. The first nonzero exit signals one **`ExecutionError`** naming the exact command line and the exit code; later commands are not attempted. **Fail-stop, not batched:** an execution failure is environmental (a broken toolchain, an unwritable disk, a corrupt archive rejected by `gst-package`), unlike install problems, which are per-package data problems — retrying the rest teaches nothing and can half-register an environment. Empirical anchor: 3.2.5's `gst-package --install` validates the archive (a `.star` is a zip) and exits `1` on a non-archive file.
- Registration is (re-)runnable: `gst-package --install --target-directory` copies the archive into the target, and re-copying an identical file is harmless. Switching or rolling back an environment re-points at a different target — it never mutates one.

### 2.2 The child invocation

- `childCommandFor: aScriptPath` — the pinned composition, exact:

  ```
  gst -i -I <aTargetDir>/parley.im --no-user-files <aScriptPath>
  ```

  Why each element (verified against 3.2.5): `-I <target>/parley.im` places the image in the target directory, and 3.2.5's `PackageLoader` local package registry follows the image directory — every `.star` sitting there is visible to the child **by the package name inside its `package.xml`, independent of filename**, which is exactly what makes content-addressed `<sha256>.star` names work verbatim. `--no-user-files` excludes `~/.st` customizations. `-i` rebuilds the image from the kernel every run: no state leaks between runs, and the scope needs no image lifecycle management. The platform's system packages remain visible to the child — they are the host runtime, as a language's standard library is under any `bundle exec`.

- `run: aScriptPath` — `runner run: (childCommandFor: aScriptPath)`, answering the child's exit code. A nonzero child is the script's own business — an answer, never an `ExecutionError`.

## 3. `ManifestFile` (decision 19 resolved)

`ManifestFile class >> load: aPath` reads the developer's **own** `Package.st` and answers its `LibraryManifest`:

1. clear the recorded manifest;
2. file the path in with `Namespace current: Parley` — inside the namespace the token `Parley` resolves to the `Parley.Parley` gateway (§8 decision 19), so the Doc B §2 syntax works verbatim;
3. answer the manifest recorded by `define:`; if the file recorded nothing (no `define:` reached), signal a one-problem `ManifestError`-style error naming the path (exact wording pinned in RED).

The recording is the sprint's **sole settled-class exception**: `Parley.Parley class >> define:` gains one send — `ManifestFile record: manifest` — before answering. All recording state (the holder, the clear, the read) lives in `ManifestFile`; nothing else in the gateway moves.

**Trust boundary unchanged** (architecture §2.2): only the root application's own manifest is ever loaded this way — the file its author owns and runs. Third-party `Package.st` files are never evaluated by anything (their information enters only as static index entries through the literals-only reader); the hard bans still hold — file-in of the owner's manifest is the authoring path Doc B §2 always specified, and no third-party byte ever reaches it.

## 4. `CLI` and `CliResult`

- `CLI class >> in: aWorkingDir source: aPackageSource store: aContentStore target: aTargetDir runner: aProcessRunner` — every collaborator injected (`source` may be `nil` for verbs that need none); tests pass doubles, the executable wrapper passes the real ones. The CLI reads `Package.st` and `parley.lock` in `aWorkingDir`.
- `run: anArgvArray` — dispatches the verb and answers a **`CliResult`**: an immutable value carrying `lines` (Array of Strings — everything the wrapper should print) and `exitCode` (Integer). The CLI **never** prints, never terminates the image, and never touches a process except through the scope's runner: it is an orchestration answering a value. Argv grammar (MVP): `init` | `resolve` | `install` | `update` | `exec <script>`. An unknown verb, a missing `exec` script, or a source-requiring verb with no source answers usage lines with exit code `2`.

### 4.1 Verbs

- **`init`** — writes the Doc B §2 template `Package.st` in the working directory; refuses (one line, exit `1`) if the file exists.
- **`resolve`** — `ManifestFile load:` → `source snapshot` → `Resolver`. A `Resolution` is written to `parley.lock` via the settled `IndexEntryWriter writeLock:on:` (byte-stable) and reported, exit `0`. A `ConflictReport` answers its narration lines, exit `1` — a conflict is a value, never an exception.
- **`install`** — the lockfile fast path, then the Sprint 5 pipeline, then registration:
  1. **Pin fast path:** if `parley.lock` exists, read it (settled reader), rebuild the `Resolution` (`fromLockEntry:`), and check `PinVerification of: manifest lock: resolution`. Valid ⇒ that resolution is used **without consuming the source's snapshot** (mechanically provable: a snapshot-signaling source double). Invalid or absent ⇒ resolve fresh and rewrite the lock.
  2. **Hash-vs-cache:** for every pinned sha256 the store contains, `verifyHash:` must answer `true`. A tampered entry is a **fail-stop corruption report** naming the hash (exact wording pinned in RED), exit `1` — the store never repairs itself (Doc D §3: detection only; repair is an operator action).
  3. **Install:** `Installer install:` (cache hits skip fetch; an `InstallError`'s problems become the lines, exit `1`).
  4. **Register:** `ExecutionScope register` over the installed set (an `ExecutionError`'s message becomes the lines, exit `1`). Exit `0` on success.
- **`update`** — ignores any existing lock: resolve fresh, rewrite `parley.lock`, then install + register as above. (`install` keeps a valid pin; `update` is the verb that moves it.)
- **`exec <script>`** — `ExecutionScope run:` with the script; `CliResult` carries the child's exit code and no lines of its own (the child already streamed to the terminal).

### 4.2 The executable wrapper (thin, untested)

`bin/parley` (POSIX sh, ~3 lines) execs `gst -f bin/parley-main.st -- <argv>`; `parley-main.st` lives in `bin/` — NOT `src/exec/`, whose every `.st` the test harness files in, and a main script executes on file-in — files in the `src/` directories (run-tests order), wires the real collaborators (`DirectorySource` from `--source <dir>` when given, store at `<cwd>/.parley/store`, target at `<cwd>/.parley/packages`, a real `ProcessRunner`), sends `CLI run:`, prints the lines, exits with the code. The wrapper is glue, not logic: everything it wires is law-tested beneath it; the wrapper itself carries none and is excluded from SUnit obligations. (Per-invocation file-in is the honest MVP cost; a prebuilt image is deferred tooling polish.)

## 5. SUnit Requirements for This Doc

- **`ProcessRunner`:** real execution laws — a command exiting `7` answers `7`; success answers `0`.
- **`ExecutionScope`:** the pinned child command composition (pure, exact string); `register` executes the real plan (real `gst-package`, real archive bytes land byte-identical in the target); fail-stop on the first failing command (real: a non-archive `.star` makes `gst-package` exit `1`; the `ExecutionError` names the command and code; later commands never run); `run:` really launches the curated child (a script leaves a sentinel; the exit code comes back).
- **`ManifestFile`:** loading a written `Package.st` answers the built manifest (round-trips name/version/dependencies); a define-less file signals the pinned error.
- **`CLI`:** every verb law — init template + refusal; resolve's byte-stable lock oracle and conflict narration; the fast-path skip proof (valid lock + primed store + a source double failing both `snapshot` and `fetch:version:` ⇒ success); stale-lock re-resolution; the corruption fail-stop; update re-pinning what install would keep; exec propagating the child code; usage/exit-2 shapes.
- **End-to-end (the sprint's exit):** entries + a real archive (toolchain-copied `.star` bytes) → resolve → lockfile → install → register → a curated child proves the package's class is visible — **a package lands in an image**.
- **Digest discipline (amended for real archives):** authored opaque byte strings keep operator-verifiable pinned digest literals (Doc D style); toolchain-copied `.star` bytes vary by machine, so their entry digests are computed at fixture time through the **settled, vector-anchored** `Sha256` — never pinned as literals, and never used to test `Sha256` itself.
- **Hygiene:** every directory (working dirs, stores, targets, child images) lives under `tmp/`, unique per test, removed in tearDown; `tmp/` empty or absent after a clean run. **The developer image is never mutated**: no test files a package into the harness image; real processes appear only where the law under test IS execution, and always confined to `tmp/`.
