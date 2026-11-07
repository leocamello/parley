"Parley Sprint 24 — shell-argument law fixtures (decision 91).

 The shell is the independent decoding oracle: it receives each rendered
 word, checks that there is exactly one argument, and writes that argument
 with printf's fixed %s format. Files are compared with the ORIGINAL input
 bytes, never with another quoting implementation. A single shell child
 checks the fixed corpus and 256 seeded generated cases. Everything lives
 under one per-test-class tmp/ directory, removed by ensure: even on failure.

 Missing production classes are looked up only when a test runs, so these
 fixtures file in cleanly during RED. No production implementation is here."

Namespace current: Parley.

Object subclass: ShellArgumentFixtures [

    <comment: 'Independent shell round-trip fixtures for the argument
value. The original input bytes and shell argument count are the oracles;
canonical rendering examples are asserted separately by the law suite.'>

    ShellArgumentFixtures class >> argumentClass [
        "Lookup at test execution, never at file-in in RED."
        <category: 'production protocol'>
        ^(Smalltalk at: #Parley) at: #ShellArgument
    ]

    ShellArgumentFixtures class >> errorClass [
        "Lookup at test execution, never at file-in in RED."
        <category: 'production protocol'>
        ^(Smalltalk at: #Parley) at: #CommandArgumentError
    ]

    ShellArgumentFixtures class >> quote [
        <category: 'literal examples'>
        ^String with: (Character value: 39)
    ]

    ShellArgumentFixtures class >> nul [
        <category: 'literal examples'>
        ^String with: (Character value: 0)
    ]

    ShellArgumentFixtures class >> safeAlphabet [
        "The complete approved ASCII alphabet, not a production query."
        <category: 'literal examples'>
        ^'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-'
    ]

    ShellArgumentFixtures class >> fixedArguments [
        "All expansions here are harmless even under a broken encoder.
         The complete non-NUL byte sequence checks control/high bytes;
         literal substitution samples may only print a fixed marker."
        <category: 'round-trip inputs'>
        | cases bytes backtick |
        cases := OrderedCollection new.
        cases addAll: #('' 'ordinary' 'hello world.st' 'one''quote'
            'two  spaces' ' leading' 'trailing ' '$PARLEY_ARGUMENT_PROBE'
            '$(printf SUBSTITUTED)' 'a; printf SUBSTITUTED' 'a*b?[c]'
            '~' '#comment' '-n' '--' 'a=b' 'a\b' 'a"b').
        cases add: (String with: Character tab).
        cases add: (String with: Character nl).
        cases add: 'before', (String with: Character tab), 'after'.
        cases add: 'before', (String with: Character nl), 'after'.
        backtick := String with: (Character value: 96).
        cases add: backtick, 'printf SUBSTITUTED', backtick.
        bytes := WriteStream on: String new.
        1 to: 255 do: [:byte | bytes nextPut: (Character value: byte)].
        cases add: bytes contents.
        ^cases asArray
    ]

    ShellArgumentFixtures class >> generatedArguments [
        "256 deterministic strings, including empty strings and shell
         separators. The deliberately small letter alphabet cannot spell
         destructive command names if a broken encoder exposes a token."
        <category: 'round-trip inputs'>
        | gen alphabet cases |
        gen := DomainGenerators fromEnvironment.
        alphabet := 'abXYZ09 _-@%+=:,./$;|&(){}[]*?~#!',
            self quote, (String with: (Character value: 34)),
            (String with: (Character value: 92)),
            (String with: Character tab), (String with: Character nl).
        cases := OrderedCollection new.
        1 to: 256 do: [:sample |
            | text length |
            text := WriteStream on: String new.
            length := gen nextInteger: 49.
            1 to: length do: [:index |
                text nextPut: (alphabet at: (gen nextInteger: alphabet size) + 1)].
            cases add: text contents].
        ^cases asArray
    ]

    ShellArgumentFixtures class >> assertRoundTripsFor: aTestCase [
        "Assert one-argument preservation over the original bytes. This
         proves the Parley-to-shell boundary, not gst-package's separate
         internal encoding or universal support for filenames in tools."
        <category: 'round-trip assertions'>
        | argumentClass cases dir script nl |
        argumentClass := self argumentClass.
        cases := self fixedArguments, self generatedArguments.
        aTestCase assert: cases size >= 256
            description: 'the round-trip corpus must contain hundreds of cases'.
        dir := SourceFixtures directoryNamed:
            'shell-round-trip-', aTestCase class name asString.
        [
            nl := SourceFixtures newline.
            script := WriteStream on: String new.
            script nextPutAll: 'set -e'; nextPutAll: nl.
            1 to: cases size do: [:index |
                | rendered |
                rendered := (argumentClass fromString: (cases at: index)) shellString.
                script nextPutAll: 'set -- '; nextPutAll: rendered; nextPutAll: nl.
                script nextPutAll: 'test "$#" -eq 1 || exit 81'; nextPutAll: nl.
                script nextPutAll: 'printf ''%s'' "$1" > ';
                    nextPutAll: dir; nextPutAll: '/argument-';
                    nextPutAll: index printString; nextPutAll: nl].
            SourceFixtures write: script contents toFile: 'round-trip.sh' in: dir.
            aTestCase assert: (ProcessRunner new run: '/bin/sh ', dir, '/round-trip.sh') = 0
                description: 'the shell failed or received other than one argument'.
            1 to: cases size do: [:index |
                | path |
                path := dir, '/argument-', index printString.
                aTestCase assert: (File name: path) exists
                    description: 'the shell did not write argument ', index printString.
                aTestCase assert: (File name: path) contents = (cases at: index)
                    description: 'shell argument bytes changed at sample ', index printString]
        ] ensure: [ExecFixtures removeTree: dir]
    ]
]

Namespace current: Smalltalk.
