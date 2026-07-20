# Parley Design — Installer & Content-Addressed Cache

> **Scope:** `Sha256`, `ContentStore`, `Installer`, `InstallError`, `InstalledSet`, and the install-time half of the `PackageSource` protocol (`fetch:version:` made real for `DirectorySource`). This is the Phase 3 opener (Sprint 5). All classes in the `Parley` namespace; structural immutability applies throughout (class-side construction; zero public setters; operations answer new values). Registration **execution** — actually running `gst-package` — is deliberately out of this document: process invocation belongs to `ExecutionScope` (Sprint 6), which executes the registration plan this document's values compose.

---

## 1. The Install Pipeline (strictly post-resolution)

Install consumes a `Resolution` — never a manifest, never a snapshot. The metadata/archive split of [resolver.md](resolver.md) §1 holds by construction: resolution finished before install begins, so `fetch:version:` can never be touched mid-resolution.

For each `(package, version, sha256)` triple of the `Resolution`, in **sorted package-name order**:

1. **Cache hit check** — if the `ContentStore` already contains `sha256`, the archive is NOT fetched. The content address is the identity; a hit is proof of possession.
2. **Fetch** — `source fetch: name version: version` answers the archive's raw bytes (a byte string). Archives are **opaque bytes** to Parley: never parsed, never unpacked, never evaluated — `gst-package` owns the archive format.
3. **Verify** — `Sha256 hexDigestOf:` the fetched bytes must equal the triple's `sha256` exactly. This is the **integrity boundary**: a mismatched archive is a batched problem and is **never written to the store** (verify-then-store).
4. **Store** — verified bytes enter the `ContentStore` under their hash.

Every problem found across the whole pass — a fetch failure, a hash mismatch, a triple whose `sha256` is `''` (no published archive; nothing to verify against) — batches into **one `InstallError`** in sorted package-name order (the `ManifestError problems` house style; master plan §8 decision 24 spirit: one error per operation, never an exception per package). A clean pass answers an immutable `InstalledSet`.

### 1.1 `DirectorySource fetch:version:` (the stub becomes real)

The entry's `#archive` field (`#(<file> #sha256 '<hash>')`) names the archive file; it resolves **relative to the source directory** (a flat directory: entries and archives side by side). `fetch:version:` answers the file's complete raw bytes. Problems signal a one-problem `SourceError` (same style as scan problems):

- unknown (package, version) — no entry declares it;
- `#archive #()` — the entry has no published archive;
- the named archive file is missing or unreadable in the directory.

The Sprint 4 install-time-only stub (and its two pinned stub tests) are superseded by this contract — recorded at Sprint 5 staging, issue #7.

## 2. `Sha256` (the integrity primitive)

FIPS 180-4 SHA-256, implemented in **pure Smalltalk** against the 3.2.5 kernel — no external processes, no OS tools, no third-party code (the §2.4 self-containment rule applies to hashing exactly as it does to serialization).

- `Sha256 class >> hexDigestOf: aByteString` — the single public message. Input: a String treated as raw bytes (3.2.5 Strings are byte strings; each character's `value` is one octet). Output: the 64-character **lowercase** hexadecimal digest.
- Pure and deterministic: same bytes ⇒ same digest, no state, no I/O.
- 32-bit modular arithmetic via masking (`bitAnd: 16rFFFFFFFF`); performance is irrelevant at MVP archive sizes.
- Correctness is anchored to published vectors (§5) — including both padding edge shapes: a message length ≡ 56 (mod 64) (padding overflows into an extra block) and an exact 64-byte block boundary.

## 3. `ContentStore` (the content-addressed cache)

A flat directory whose filenames ARE the content hashes: `<sha256>.star`. Integrity for free — the name is the claim, re-hashing is the audit.

- `ContentStore class >> on: aRootPath` — the store over a directory path, held immutably. The root is created lazily on first `store:`.
- `store: aByteString` — hashes the bytes, writes `<hash>.star` if absent, answers the hex hash. **Idempotent**: re-storing identical bytes writes nothing new and answers the same hash. (A store can never contain a mismatch by construction — the name is computed from the bytes at write time.)
- `containsHash: aHexString` — whether `<hash>.star` exists.
- `pathForHash: aHexString` — the file's path when present, `nil` when absent.
- `verifyHash: aHexString` — re-hashes the file's bytes and answers whether they still match the name; `false` for a tampered/corrupted file (and for an absent one). Detection only — the store never deletes; repair is an operator action.
- The empty hash `''` (a no-archive release) is never a valid store key: `store:` of any bytes answers a real digest, and `containsHash: ''` is `false`.

## 4. `Installer`, `InstallError`, `InstalledSet`

- `Installer class >> source: aPackageSource store: aContentStore` — the orchestrator, holding both collaborators immutably.
- `install: aResolution` — runs the §1 pipeline. Answers an `InstalledSet` on a clean pass; signals one `InstallError` otherwise. Re-running `install:` with the same arguments is a **no-op that answers an equal-content set** (every hash already present ⇒ zero fetches — mechanically testable with a source whose `fetch:version:` always fails).
- `InstallError` — the `problems` array of human-readable strings in sorted package-name order; `messageText` is `'Install has <n> problem(s): '` with problems joined by `'; '` (the house style). Problem kinds: no published archive (`sha256` `''`), fetch failure (carrying the source's message), hash mismatch (naming the package, the expected and the actual digest).
- `InstalledSet` — the immutable product: one `(package name, Version, sha256, store path)` tuple per resolved package, in sorted package-name order. Carries **no value equality** (`=`/`hash`) — the decision-23 precedent; tests compare tuple fields. Protocol: `packageNames`, `versionOf:`, `sha256For:`, `pathFor:`, and:
- `registrationCommandsFor: aTargetDir` — the **registration plan**: two command lines per tuple, in sorted package-name order (each package's pair adjacent, staging first), each pair exactly

  ```
  install -D -m 644 <store path> <aTargetDir>/.parley-staging/<name>.star
  gst-package --target-directory <aTargetDir> <aTargetDir>/.parley-staging/<name>.star
  ```

  A pure formatting value — composed here, **executed by Sprint 6's `ExecutionScope`**, which owns all child-process invocation. Nothing in this document runs a process.

  Why two lines (issue #8 ruling): 3.2.5's toolchain enforces filename/internal-name equality (`Kernel.StarPackage` rejects any star whose filename basename differs from its `package.xml` name), so the content-addressed `<sha256>.star` store path can never be registered directly — the archive is first staged under its true name inside the target (`install -D` creates `.parley-staging/`; writes stay target-confined), then registered by `gst-package` (flagless: 3.2.5's parser accepts no `--install` spelling; install is the default mode). **Name-equality MVP constraint:** a Parley package's entry name IS its star's internal package name — lowercase per Doc B §3.4, which the toolchain accepts (its name check is pure string equality). Archives remain opaque bytes to Parley: the true name comes from the tuple, never from reading the archive.

## 5. SUnit Requirements for This Doc

- **`Sha256` vectors:** the empty string, `'abc'`, the 56-byte NIST two-block message `'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'` (length ≡ 56 mod 64 — padding overflows into a second block), and a 64-byte block-boundary message — each pinned to its published digest byte-for-byte. Laws: determinism (same input twice ⇒ identical digest); every digest is 64 lowercase hex characters; distinct short inputs answer distinct digests.
- **`ContentStore`:** store answers the true digest and the file lands byte-identical under `<hash>.star`; idempotent re-store; `verifyHash:` true on intact, false on tampered and on absent; `containsHash: ''` false.
- **Fetch:** archive bytes round-trip exactly; each of the three §1.1 problem shapes signals its one-problem `SourceError`.
- **`Installer`:** the happy diamond installs (set contents, cache contents); one hash mismatch batches with other problems into ONE `InstallError` in package-name order and the mismatched bytes are NOT in the store; the cache-hit law (pre-populated store + always-failing source ⇒ successful install, proving hits skip fetch); re-install no-op.
- **End-to-end (extends Doc C §7):** a real directory of entries **with real archives and true `Sha256` hashes** → resolve → `writeLock:on:` a lockfile to disk (byte-stable across runs) → install → the store contains exactly the resolved hashes; the registration plan renders the pinned command lines.
- **Hygiene:** every fixture directory (entries, archives, stores, targets) lives under `tmp/`, is unique per test, and is removed in tearDown; `tmp/` is empty or absent after a clean run.
