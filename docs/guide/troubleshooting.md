# Troubleshooting

Start with the path and remedy in Parley's diagnosis. These are its own exit
codes:

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Parley diagnosed a problem with the project, index or invocation environment |
| `2` | Usage: the command's shape or flags are invalid |
| `70` | An internal defect or incomplete Parley installation |

For `exec`, the child's exit code is passed through. An unhandled error in a
GNU Smalltalk 3.2.5 script can still end at `0`; see
[exit codes and CI](running-code.md#exit-codes-and-ci).

## A file cannot be read or written

Parley checks file boundaries and names paths it cannot use. A read-only
checkout, a root-owned lock or an unwritable cache is an environment problem,
not a reason to report an internal defect:

```text
$ parley resolve --source ../index
/srv/app/parley.lock: could not be written - check its permissions and try again
$ echo $?
1
```

Check the named file's permissions and ownership. If the file does not yet
exist, check its parent directory: creating a file requires a writable parent.
The same diagnosis shape covers a missing or unreadable `Package.st`, an
archive that cannot be read, and a publication destination that cannot be
written.

These are prechecks, not filesystem locks. Permissions or files can change
between the check and an operation. Parley still names failures it diagnoses
at the boundary; it does not claim to prevent concurrent filesystem changes.
A refusal before a write leaves existing files unchanged. `add` and `remove`
keep their manifest and lock updates together.

## The manifest is malformed

`Package.st` is your executable authoring file. When a statement fails during
loading, Parley reports its file and line:

```text
$ parley resolve --source ../index
Object: nil
/srv/app/Package.st: line 2 raised an error while the manifest was being read - fix that line and try again
$ echo $?
1
```

Fix the named line, then run the command again. Validation can report several
problems as a single batch:

```text
/srv/app/Package.st: 4 problem(s) in this manifest
missing required field name
invalid version 'nope'
fileIns must declare at least one file to load
invalid constraint 'garbage' for dependency 'demo'
```

Two fragments come from GNU Smalltalk itself and are deliberately retained:

- **`Object: nil` on standard output.** The runtime writes the receiver of a
  failed message send below the Smalltalk-level capture boundary. Parley ends
  that fragment's line so its own diagnosis starts on the next line.
- **A message such as `Package.st:3: parse error, expected ']'` on standard
  error.** The runtime names the unreadable statement's file and line. Parley
  preserves that useful detail. Its own stdout diagnosis is
  `no manifest defined - the file never sent Parley define:` because it cannot
  distinguish a file that would not parse from one that never declared a
  package. The message on standard error tells you which case occurred.

Your own `Transcript` output during a manifest load is captured and discarded
with the toolchain's Smalltalk-level output. Do not use `Package.st` as a
progress-reporting script. Use `parley exec` for a program whose output you
want to see.

## The lock cannot be used

Commands that read existing pins, including `install`, `check`, `tree`, `why`
and `exec`, diagnose a readable but malformed lock. `parley resolve` instead
computes a fresh resolution and can replace malformed lock contents when the
destination is writable. Supply any index the manifest needs and omit
`--locked` when deliberately repairing the file.

`parley update` also resolves afresh, then installs and registers the resolved
packages. Unlike `resolve`, it requires a selected source under the current
CLI grammar. Either fresh resolution can move package versions; review the
new lock. Selective `parley update <pkg>` reads existing pins so it can hold
the other packages, and is not the same repair as an unqualified `update`.

A `parley.lock` path that is a directory or cannot be read as a regular file
is a different problem. Follow its path diagnosis first; `update` cannot
replace a directory with the expected file. Once the obstruction is removed,
`parley resolve` can write a first lock.

If `--locked` refuses a change, either restore the manifest/source state that
matches the lock or deliberately resolve without `--locked`. Do not delete
pins merely to hide a dependency conflict: the conflict report explains the
incompatible requirements.

## The source is unexpected or unavailable

The precedence is flag, then environment, then `parley.config.st`. Inspect
exported `PARLEY_SOURCE`, `PARLEY_GIT` and `PARLEY_INDEX` if a file setting is
not being used. An explicit source flag skips both lower levels. See
[configuration](configuration.md).

`--offline` refuses git and sparse sources before spawning either transport,
including cached git checkouts and sparse `file://` bases. Use a local flat
index with `--source` for an offline invocation.

For a dependency conflict, read the narrated requirements and their package
origins. For an archive hash mismatch, retain the diagnostic and check the
index/archive pair; altering a published archive without updating its metadata
does not produce a valid release.

## Publication is refused

Create the destination directory before publishing. Choose its intended
layout explicitly, and use a new version for a new release: an existing
`(name, version)` is immutable. A manifest that still declares a local path
dependency cannot be published. The [publishing guide](publishing.md) gives
the complete setup and explains the staging directory retained after a failed
build.

## An internal defect is reported

Exit `70` identifies a Parley defect or incomplete installation rather than
a normal project diagnosis. Include `parley --version`, `gst --version`, the
command, and the diagnosis when opening a repository issue. A small manifest
and index that reproduce the problem make it easier to investigate; remove
private credentials and unrelated project content before sharing them.

[Guide index](README.md)
