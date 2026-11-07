# Installing Parley

Parley runs from a checkout. It requires **GNU Smalltalk 3.2.5**, including
the bundled `gst-package` command. Check the toolchain before installing the
wrapper:

```sh
gst --version
command -v gst-package
```

The version line must say `GNU Smalltalk version 3.2.5`. Parley adds no
third-party Smalltalk library. Publishing and registration use the archive
tools supplied with the GNU Smalltalk installation, including `zip` and
`unzip`; git sources need `git`, and sparse sources need `curl`.

The [CI workflow](../../.github/workflows/verify.yml) records the pinned
environment used to verify the baseline. It is a reference for reproducing
that environment, not an installer that changes your machine.

## Put the wrapper on your PATH

Choose a checkout location and a directory for your personal commands:

```sh
mkdir -p "$HOME/src" "$HOME/.local/bin"
git clone https://github.com/leocamello/parley.git "$HOME/src/parley"
ln -s "$HOME/src/parley/bin/parley" "$HOME/.local/bin/parley"
export PATH="$HOME/.local/bin:$PATH"
parley --version
```

Add the `PATH` setting to your shell's startup file if it is not already
there. Keep the checkout: the symlink points to its wrapper and source files.
If you already cloned Parley, use that checkout instead of cloning again.

The wrapper resolves its own symlink chain, including a link to another link,
before locating the checkout. You can invoke `parley` from a project outside
the checkout.

You can also identify the checkout explicitly with `PARLEY_ROOT`:

```sh
PARLEY_ROOT="$HOME/src/parley" "$HOME/src/parley/bin/parley" --version
```

`PARLEY_ROOT` locates Parley's implementation. It does not select the project
or its package index. Run package commands from the project directory, and
choose an index with [configuration](configuration.md).

## Shell completion

For Bash, load the supplied completion file in your current shell:

```bash
source "$HOME/src/parley/completions/parley.bash"
```

Add that line to your Bash startup file to load it in future sessions. Adjust
the path if your checkout is elsewhere.

For Zsh, put the checkout's completion directory on `fpath` before initializing
completion:

```zsh
fpath=("$HOME/src/parley/completions" $fpath)
autoload -Uz compinit
compinit
```

Place these settings in `.zshrc`. If your configuration already calls
`compinit`, add the `fpath` assignment before that existing call instead of
adding a second initialization. The supplied `_parley` function completes
verbs, flags and publication layouts from the same declarations as the CLI.

## Check the installation

```sh
parley --help
```

`parley --help`, `parley -h` and `parley help` print the same usage block and
exit `0`. `parley --version` prints the version and exits `0`. These questions
create no project state. An empty invocation or an unknown verb exits `2`
with a usage diagnosis.

If the wrapper cannot find `bin/parley-main.st`, it names the expected path
and exits `70`. Check the symlink and any exported `PARLEY_ROOT`; an incomplete
checkout cannot run Parley correctly.

Next, follow the [sixty-second walk](../../README.md#the-sixty-second-walk)
or the complete [two-package development guide](developing-two-packages.md).

[Guide index](README.md)
