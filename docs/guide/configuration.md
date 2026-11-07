# Choosing and configuring an index

An index supplies release metadata and archives. Parley accepts three source
kinds:

| Flag | Environment variable | Source |
| --- | --- | --- |
| `--source <dir>` | `PARLEY_SOURCE` | A local directory containing a flat index |
| `--git <repo>` | `PARLEY_GIT` | A git repository containing a flat index |
| `--index <base>` | `PARLEY_INDEX` | A sparse index at a `file://` or HTTP base |

Choose at most one source. The [publishing guide](publishing.md) explains the
two index layouts and creates an index you can use locally.

## Precedence

The selection order is **flag > environment > file**. A flag on the command
line **always wins**: both lower levels are skipped entirely, including
malformed configuration they might contain. With no source flag, a nonempty
source environment variable skips the file. Only when neither supplies a
source does Parley read `parley.config.st`.

```sh
parley resolve --source ../my-index
PARLEY_SOURCE=../my-index parley resolve
```

The first command uses its flag. The second supplies the same source through
the environment. Combining them still chooses the flag:

```sh
PARLEY_SOURCE=../my-index parley resolve --source ../another-index
```

Two source flags are a usage error at exit `2`. With no source flag, two
nonempty source variables are refused at exit `1`, naming both variables.
Parley does not guess which source you meant.

## Record a source in the project

Put `parley.config.st` at the **project root**, beside `Package.st` and
`parley.lock`:

```smalltalk
#(#'parley-config' 1 #source '../my-index' #git '' #index '')
```

This is static data, not executable Smalltalk. Include all three keys in
exactly that order, with string values. The empty string means unset, and at
most one value may be nonempty. For example, a sparse source uses:

```smalltalk
#(#'parley-config' 1 #source '' #git '' #index 'https://example.org/packages')
```

The HTTPS address is illustrative; it must point to an index you can access.
Parley does not provide a hosted registry.

After writing the local-source example, run:

```sh
parley resolve
```

Configuration lives outside `.parley/` because it is authored project input.
Deleting regenerable state under `.parley/` does not remove the source you
chose. No Parley command rewrites `parley.config.st`.

An empty environment variable is unset:

```sh
PARLEY_SOURCE= parley resolve
```

That command reaches the file if no other source variable is set. To return
to file-based configuration, unset any exported `PARLEY_SOURCE`, `PARLEY_GIT`
and `PARLEY_INDEX` values in your shell.

## Offline and locked invocations

`--offline` means this invocation spawns neither git nor curl. It refuses a
selected `--git` or `--index` source at exit `1`, even if a local cache exists
or the sparse base is a `file://` URL. A local `--source` directory works:

```sh
parley resolve --source ../my-index --offline
```

`--locked` guards the selected version pins. A command that would move, add
or remove a version pin refuses at exit `1` and names a differing pin.
It does not compare changes to path or digest provenance when versions stay
the same. Existing lock bytes remain untouched on success. An already-current
lock succeeds. The guard
also applies to `add` and `remove`; refusal leaves both manifest and lock
unchanged.

After changing a dependency's path, run `parley resolve` without `--locked`
and review the refreshed lock before executing the project. Otherwise, a
same-version path change can succeed while the old path remains pinned.
This observed limitation is tracked in [issue #27](https://github.com/leocamello/parley/issues/27).

```sh
parley install --source ../my-index --locked
```

The two flags are independent and can be combined. Neither selects a source.

## When no index is needed

`resolve`, `check`, `tree` and `why` work without an index when the manifest
has no index-supplied dependencies. A project using only local path
dependencies can therefore use those commands without configuration.
Commands that ask the index what it publishes, such as `search` and `info`,
still require one. `install` also requires a source under the current CLI
grammar; path-only execution uses `resolve` followed by `exec`.

An unreadable or malformed configuration file produces a diagnosis at exit
`1`, naming the file and the repair: fix it or remove it and try again. See
[troubleshooting](troubleshooting.md) for the distinction between usage,
project diagnoses and internal defects.

[Guide index](README.md)
