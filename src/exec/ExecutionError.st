"Parley — ExecutionError: the fail-stop signal of plan execution.
 Spec: docs/design/execution-and-cli.md §2.1; issue #8 S5.
 An execution failure is environmental (a broken toolchain, an
 unwritable disk, a corrupt archive rejected by gst-package) — unlike
 install problems, which are per-package data problems and batch.
 One error, naming the exact command line and the exit code; wording
 pinned in RED (issue #8)."

Namespace current: Parley.

Error subclass: ExecutionError [
    | command exitCode |

    <comment: 'Signaled by ExecutionScope>>register on the first plan
line whose exit code is nonzero: carries the exact command line and
the child''s exit code. Later commands are never attempted.'>

    ExecutionError class >> signalCommand: aCommandString exitCode: anInteger [
        "Signal one error naming the failing command line and its
         exit code (the pinned wording)."
        <category: 'instance creation'>
        ^self new
            setCommand: aCommandString exitCode: anInteger;
            signal: 'Execution failed with exit code ',
                anInteger printString, ': ', aCommandString
    ]

    setCommand: aCommandString exitCode: anInteger [
        "Private — initialization before signaling."
        <category: 'private'>
        command := aCommandString.
        exitCode := anInteger
    ]

    command [
        "The exact command line that failed."
        <category: 'accessing'>
        ^command
    ]

    exitCode [
        "The failing command's exit code."
        <category: 'accessing'>
        ^exitCode
    ]
]

Namespace current: Smalltalk.
