---
name: Bug report
about: Something Parley did wrong — a wrong answer, a wrong exit code, or a diagnosis that blames the wrong party
title: ''
labels: bug
assignees: ''
---

## What happened

<!-- The command you ran, what Parley answered, and what you expected.
     Paste output verbatim — the wording of a diagnosis is load-bearing
     in this project, so the exact bytes matter. -->

## The three facts every report needs

- `parley --version`:
- `gst --version` (first line):
- The exit code (`echo $?` immediately after the failing command):

## To reproduce

<!-- The smallest project that shows it: the Package.st, the parley.lock
     if one exists, the index layout if one is involved, and the exact
     command line. A parley.config.st or exported PARLEY_* variables are
     part of the reproduction — say so if either is present. -->

## Anything else

<!-- A directory listing, permissions, a symlinked installation — the
     ordinary filesystem facts that turned out to matter in most of this
     project's own bug hunts. -->
