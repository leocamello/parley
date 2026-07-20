"Parley — CliResult: the CLI's answer value.
 Spec: docs/design/execution-and-cli.md §4; issue #8.
 An immutable value carrying lines (an Array of Strings — everything
 the executable wrapper should print) and exitCode (an Integer). The
 CLI never prints and never terminates the image; printing and
 exiting are bin/parley-main.st's job alone. Carries NO value
 equality (=/hash) — the decision-23 precedent."

Namespace current: Parley.

Object subclass: CliResult [
    | lines exitCode |

    <comment: 'The immutable outcome of one CLI run: the lines the
wrapper should print and the process exit code it should exit with.
Class-side construction; no public setters; no value equality.'>

    CliResult class >> lines: anArray exitCode: anInteger [
        "Answer a result carrying anArray of Strings and anInteger."
        <category: 'instance creation'>
        ^self new setLines: anArray exitCode: anInteger
    ]

    setLines: anArray exitCode: anInteger [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        lines := anArray.
        exitCode := anInteger
    ]

    lines [
        "The lines the wrapper should print, an Array of Strings."
        <category: 'accessing'>
        ^lines
    ]

    exitCode [
        <category: 'accessing'>
        ^exitCode
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream
            nextPutAll: 'CliResult(exit ';
            nextPutAll: exitCode printString;
            nextPutAll: ', ';
            nextPutAll: lines size printString;
            nextPutAll: ' line(s))'
    ]
]

Namespace current: Smalltalk.
