"Parley Sprint 22 — the shell-completion generator.
 Spec: docs/design/execution-and-cli.md §4.3; §8 decision 70; issue #24
 S20-S23 and the pre-RED P3 ruling (question flags in).

 THE GENERATOR IS THE DECLARATIONS' FIFTH CONSUMER — after the wiring,
 the usage lines and the drift laws — and it lives on the test side
 deliberately: a production generator would be new public surface on
 CommandLine beyond its declared Sprint 22 bound. The committed files
 under completions/ are written at GREEN byte-identical to the texts
 composed here, and the CompletionTest laws regenerate and compare
 byte-for-byte, so a verb, flag or layout can never ship without its
 completion.

 EVERY WORD LIST DERIVES FROM ITS DECLARATION and none is hand-spelled:
 the verbs from CLI verbRows' name column (first occurrence, in table
 order); the flags from sourceFlagNames, modeFlagNames, the layout
 flag, then the question flags (versionFlag and the dash-shaped
 helpFlags — the P3 amendment; the bare help spelling is a verb-slot
 word and S20 pins that slot to verbRows, so it is deliberately not
 offered); the layout values from publishLayouts; the environment
 header from the source-flag table's variable field. The one hand-kept
 map is the zsh VALUE LABELS (directory, repository, base), keyed by
 flag and defaulting to the word value — labels are template prose, so
 a fourth source flag joins the file with the default label rather
 than being able to drift out of it."

Namespace current: Parley.

Object subclass: CompletionFixtures [

    <comment: 'Sprint 22 completion fixtures: the byte-exact generator
for completions/parley.bash and completions/_parley, composed from the
declared tables, plus the grown-table variant the S23 falsifier
drives.'>

    CompletionFixtures class >> bashPath [
        <category: 'paths'>
        ^'completions/parley.bash'
    ]

    CompletionFixtures class >> zshPath [
        <category: 'paths'>
        ^'completions/_parley'
    ]

    CompletionFixtures class >> nl [
        <category: 'private'>
        ^String with: Character nl
    ]

    "---- the derived word lists ----"

    CompletionFixtures class >> verbWords [
        "The verb-name column of CLI verbRows, first occurrence, in
         table order — publish and update each declare two rows and
         complete as one word."
        <category: 'derivations'>
        | seen out |
        seen := Set new.
        out := OrderedCollection new.
        CLI verbRows do: [:row |
            | name |
            name := row at: 4.
            (seen includes: name) ifFalse: [
                seen add: name.
                out add: name]].
        ^out asArray
    ]

    CompletionFixtures class >> flagWords [
        "Every flag both completions offer: the source flags, the mode
         flags, the layout flag, then the question flags (P3 — the
         dash-shaped spellings only)."
        <category: 'derivations'>
        ^CommandLine sourceFlagNames,
            CommandLine modeFlagNames,
            (Array with: CommandLine publishLayoutFlag),
            (Array with: CommandLine versionFlag),
            (CommandLine helpFlags select: [:each | each first = $-])
    ]

    CompletionFixtures class >> layoutWords [
        <category: 'derivations'>
        ^CommandLine publishLayoutNames
    ]

    CompletionFixtures class >> spaceJoined: someWords [
        <category: 'private'>
        | out |
        out := WriteStream on: String new.
        someWords do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: Character space].
        ^out contents
    ]

    CompletionFixtures class >> barJoined: someWords [
        <category: 'private'>
        | out |
        out := WriteStream on: String new.
        someWords do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: $|].
        ^out contents
    ]

    CompletionFixtures class >> commaJoined: someWords [
        <category: 'private'>
        | out |
        out := WriteStream on: String new.
        someWords do: [:each | out nextPutAll: each]
            separatedBy: [out nextPutAll: ', '].
        ^out contents
    ]

    CompletionFixtures class >> headerLinesTagged: aShellName [
        "The two-line provenance header plus the environment line,
         shared by both files — the variable names read from the
         declared table's own field."
        <category: 'derivations'>
        ^'# parley ', aShellName,
            ' completion - generated from the declared tables (CLI verbRows,',
            self nl,
            '# CommandLine sourceFlags, modeFlags, publishLayouts, the question flags); do not edit by hand.',
            self nl,
            '# environment: ',
            (self commaJoined: CommandLine environmentVariableNames),
            ' (flag > environment > parley.config.st)',
            self nl
    ]

    "---- the two file texts ----"

    CompletionFixtures class >> bashText [
        <category: 'generation'>
        ^self bashTextOverVerbWords: (self spaceJoined: self verbWords)
    ]

    CompletionFixtures class >> bashTextOverVerbWords: aVerbWordsString [
        "The whole bash file over an injected verb word list — the real
         text uses the derived words; the S23 falsifier injects a list
         with one extra verb and the comparison against the committed
         bytes must fail."
        <category: 'generation'>
        | n |
        n := self nl.
        ^(self headerLinesTagged: 'bash'),
            '_parley() {', n,
            '    local cur prev', n,
            '    cur="${COMP_WORDS[COMP_CWORD]}"', n,
            '    prev="${COMP_WORDS[COMP_CWORD-1]}"', n,
            '    case "$prev" in', n,
            '        ', (self barJoined: CommandLine sourceFlagNames), ')', n,
            '            COMPREPLY=( $(compgen -o default -- "$cur") )', n,
            '            return', n,
            '            ;;', n,
            '        ', CommandLine publishLayoutFlag, ')', n,
            '            COMPREPLY=( $(compgen -W "',
                (self spaceJoined: self layoutWords), '" -- "$cur") )', n,
            '            return', n,
            '            ;;', n,
            '    esac', n,
            '    case "$cur" in', n,
            '        -*)', n,
            '            COMPREPLY=( $(compgen -W "',
                (self spaceJoined: self flagWords), '" -- "$cur") )', n,
            '            return', n,
            '            ;;', n,
            '    esac', n,
            '    COMPREPLY=( $(compgen -W "', aVerbWordsString,
                '" -- "$cur") )', n,
            '}', n,
            'complete -F _parley parley', n
    ]

    CompletionFixtures class >> zshText [
        <category: 'generation'>
        ^self zshTextOverVerbWords: (self spaceJoined: self verbWords)
    ]

    CompletionFixtures class >> zshTextOverVerbWords: aVerbWordsString [
        <category: 'generation'>
        | n out |
        n := self nl.
        out := WriteStream on: String new.
        out nextPutAll: '#compdef parley'; nextPutAll: n.
        out nextPutAll: (self headerLinesTagged: 'zsh').
        out nextPutAll: '_arguments \'; nextPutAll: n.
        CommandLine sourceFlagNames do: [:flag |
            out nextPutAll: '    ''', flag, ':',
                (self zshValueLabelFor: flag), ':_files'' \'; nextPutAll: n].
        CommandLine modeFlagNames do: [:flag |
            out nextPutAll: '    ''', flag, ''' \'; nextPutAll: n].
        out nextPutAll: '    ''', CommandLine publishLayoutFlag,
            ':layout:(', (self spaceJoined: self layoutWords), ')'' \';
            nextPutAll: n.
        out nextPutAll: '    ''', CommandLine versionFlag, ''' \';
            nextPutAll: n.
        (CommandLine helpFlags select: [:each | each first = $-])
            do: [:flag |
                out nextPutAll: '    ''', flag, ''' \'; nextPutAll: n].
        out nextPutAll: '    ''1:verb:(', aVerbWordsString, ')'' \';
            nextPutAll: n.
        out nextPutAll: '    ''*::arguments:_files'''; nextPutAll: n.
        ^out contents
    ]

    CompletionFixtures class >> zshValueLabelFor: aFlag [
        "Template prose per known flag; the word value for any flag
         the map does not know, so a new source flag cannot drift out
         of the file — it arrives with the default label."
        <category: 'generation'>
        aFlag = '--source' ifTrue: [^'directory'].
        aFlag = '--git' ifTrue: [^'repository'].
        aFlag = '--index' ifTrue: [^'base'].
        ^'value'
    ]

    "---- the committed bytes ----"

    CompletionFixtures class >> committedBashText [
        <category: 'committed'>
        ^(File name: self bashPath) contents
    ]

    CompletionFixtures class >> committedZshText [
        <category: 'committed'>
        ^(File name: self zshPath) contents
    ]

    CompletionFixtures class >> grownVerbWords [
        "The real verb words plus one verb the grammar does not have —
         the S23 falsifier's input."
        <category: 'falsifier'>
        ^self spaceJoined: (self verbWords, (Array with: 'conjure'))
    ]
]

Namespace current: Smalltalk.
