"Parley — ProcessRunner: the one process seam in all of Parley.
 Spec: docs/design/execution-and-cli.md §1; issue #8 S1/S2.
 Everything above this class composes command lines as pure string
 values; everything at it is one thin, dumb executor. The 3.2.5
 kernel's Smalltalk system: answers the child's raw wait status —
 exit code x 256 (staging-verified: 'exit 7' answers 1792) — so run:
 normalizes with // 256. Zero is success; nothing is signaled: the
 code is an answer whose meaning belongs to the caller. No output
 capture: the child's stdout/stderr flow to Parley's own. Composers
 preserve their dynamic arguments through ShellArgument (decision 91);
 this seam neither parses nor re-quotes the command string."

Namespace current: Parley.

Object subclass: ProcessRunner [

    <comment: 'The ONLY pathway in Parley by which a child process is
ever created: run: executes a command string through the kernel''s
Smalltalk system: and answers the child''s exit code as an Integer,
normalized from the raw wait status (status // 256). Stateless; it
exists as an instance so tests can substitute recording or failing
doubles.'>

    run: aCommandString [
        "Execute aCommandString in a child process and answer the
         child's exit code, normalized from the raw wait status
         answered by Smalltalk system: (exit code x 256)."
        <category: 'running'>
        ^(Smalltalk system: aCommandString) // 256
    ]
]

Namespace current: Smalltalk.
