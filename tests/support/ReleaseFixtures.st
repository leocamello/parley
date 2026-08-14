"Parley Sprint 22 — the release machinery's shared fixtures.
 Spec: docs/design/execution-and-cli.md §4.3; §8 decisions 70, 71, 86;
 issue #24 S9-S10, S15-S19, S24-S30.

 WHAT LIVES HERE. The recursive src/ walk the fileIns drift law reads
 (recursive because 3.2.5's File>>files silently skips subdirectories,
 so a flat enumeration is vacuous for exactly the nested paths the
 showcase exists to prove — the Sprint 8 lesson); the release-walk and
 CHANGELOG comparers with their falsifier halves anchored to the real
 artifacts; the three pass-in-red checkers (the CI one-gate bound, the
 wrap-staging-versus-scope bound, the sprints-index bound), each a
 TEXTUAL claim whose limits are stated in its comment per decision 43;
 and the README slot markers and tally parser.

 EVERY COMPARER IS A FUNCTION A LAW CAN DRIVE OVER A DOCTORED INPUT,
 because a release law that cannot fail is the vacuous-enumeration
 defect. The falsifier fixtures are anchored to the real declarations
 and artifacts — a doctored copy of the real thing, never a free
 fixture — so no falsifier half can pass while the production surface
 it proves is missing (the declared red passes stay exactly three)."

Namespace current: Parley.

Object subclass: ReleaseFixtures [

    <comment: 'Sprint 22 release fixtures: the recursive src/ walk in
the runner''s declared order, the release-file and CHANGELOG comparers
with falsifier support, the textual checkers behind the three declared
red-phase passes, and the README structure markers.'>

    "---- the src/ walk (§8 decision 86; the fileIns drift law) ----"

    ReleaseFixtures class >> srcDirectories [
        "The eight src/ directories in scripts/run-tests.st''s load
         order — the one authority on load order, which only the
         operator edits. Declared here as a mirror; the census half of
         the fileIns law holds it equal to the directories src/
         actually contains, so a ninth directory fails the law rather
         than shipping unwalked."
        <category: 'src walk'>
        ^(Array with: 'src/compat' with: 'src/domain'
            with: 'src/manifest' with: 'src/resolver'
            with: 'src/source'),
            (Array with: 'src/install' with: 'src/exec'
                with: 'src/publish')
    ]

    ReleaseFixtures class >> srcTopLevelDirectories [
        "The directories src/ actually contains, discovered — the
         census the declared list above is held against."
        <category: 'src walk'>
        | names |
        names := OrderedCollection new.
        (File name: 'src') namesDo: [:each |
            ((#('.' '..') includes: each) not
                and: [(File name: 'src/', each) isDirectory])
                    ifTrue: [names add: 'src/', each]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    ReleaseFixtures class >> srcFileWalk [
        "Every .st file under src/, recursively, with its relative
         subdirectory path, in the declared directory order and
         sorted-path order within each directory — the exact order
         scripts/run-tests.st loads and the root Package.st must
         declare. The within-directory sort is the runner''s own
         default asSortedCollection, so the two cannot disagree about
         case folding (the Sprint 18 String-comparison lesson)."
        <category: 'src walk'>
        | out |
        out := OrderedCollection new.
        self srcDirectories do: [:dir |
            out addAll: (self stFilesUnder: dir)].
        ^out asArray
    ]

    ReleaseFixtures class >> stFilesUnder: aDirPath [
        "The recursive descent: files at this level in sorted order,
         descending into each subdirectory in sorted order. namesDo:
         is the only enumeration that sees subdirectories on 3.2.5 —
         File>>files answers regular files alone."
        <category: 'src walk'>
        | entries files dirs out |
        entries := OrderedCollection new.
        (File name: aDirPath) namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [entries add: each]].
        entries := entries asSortedCollection asArray.
        files := entries select: [:each |
            ((File name: aDirPath, '/', each) isDirectory) not
                and: [each endsWith: '.st']].
        dirs := entries select: [:each |
            (File name: aDirPath, '/', each) isDirectory].
        out := OrderedCollection new.
        files do: [:each | out add: aDirPath, '/', each].
        dirs do: [:each | out addAll: (self stFilesUnder: aDirPath, '/', each)].
        ^out asArray
    ]

    ReleaseFixtures class >> fileInsMatch: someFileIns walk: aWalkArray [
        "Whether the manifest''s declaration and the walk agree exactly,
         order included — the comparison the drift law asserts true on
         the real pair and false on a pair with one name removed."
        <category: 'src walk'>
        ^someFileIns asArray = aWalkArray asArray
    ]

    "---- the release walk (§8 decision 70) ----"

    ReleaseFixtures class >> missingReleaseFilesIn: someRelativePaths [
        "The subset of someRelativePaths that is not an existing,
         non-empty regular file — empty when the declaration is whole.
         The walk a release stands on, and the function the falsifier
         drives over the real declaration grown by one absent name."
        <category: 'release walk'>
        ^someRelativePaths select: [:path |
            | file |
            file := File name: path.
            (file exists and: [file isDirectory not
                and: [file contents isEmpty not]]) not]
    ]

    "---- the CHANGELOG comparers (§8 decision 70) ----"

    ReleaseFixtures class >> changelogPath [
        <category: 'changelog'>
        ^'CHANGELOG.md'
    ]

    ReleaseFixtures class >> changelogText [
        <category: 'changelog'>
        ^(File name: self changelogPath) contents
    ]

    ReleaseFixtures class >> versionHeadingsIn: aText [
        "The bracketed token of every Keep-a-Changelog version heading
         line — a line opening with the literal four characters
         hash hash space bracket — in document order. The newest is
         first by that format''s own convention."
        <category: 'changelog'>
        | out |
        out := OrderedCollection new.
        (ExecFixtures linesOf: aText) do: [:line |
            (line startsWith: '## [') ifTrue: [
                | close |
                close := line indexOf: $].
                close > 4 ifTrue: [
                    out add: (line copyFrom: 5 to: close - 1)]]].
        ^out asArray
    ]

    ReleaseFixtures class >> newestVersionHeadingIn: aText [
        "The first version heading''s token, or an empty string when
         the text has none — never an error, so the comparer can be
         driven over doctored texts."
        <category: 'changelog'>
        | headings |
        headings := self versionHeadingsIn: aText.
        ^headings isEmpty ifTrue: [''] ifFalse: [headings first]
    ]

    ReleaseFixtures class >> headingSet: aText equals: someVersionStrings [
        "Whether the heading tokens are exactly someVersionStrings —
         set equality over sorted copies, so a duplicated heading
         fails on count and an Unreleased heading fails on membership."
        <category: 'changelog'>
        ^(self versionHeadingsIn: aText) asSortedCollection asArray
            = someVersionStrings asSortedCollection asArray
    ]

    "---- the CI one-gate checker (S24; §8 decision 71) ----"

    ReleaseFixtures class >> verifyWorkflowPath [
        <category: 'ci gate'>
        ^'.github/workflows/verify.yml'
    ]

    ReleaseFixtures class >> nonCommentLinesOf: aText [
        "The workflow''s lines with YAML comment lines removed — a
         line whose first non-blank character is the hash mark. The
         textual bound: an inline trailing comment on a command line
         is NOT stripped, and does not need to be, because the claims
         below are about which commands appear at all."
        <category: 'ci gate'>
        ^(ExecFixtures linesOf: aText) reject: [:line |
            | trimmed |
            trimmed := line trimSeparators.
            trimmed isEmpty or: [trimmed first = $#]]
    ]

    ReleaseFixtures class >> workflowRunsTheOneGate: aText [
        "TRUE exactly when the workflow names the one gate and nothing
         else that runs tests. The bound is textual and stated
         (decision 43, decision 71): it proves the workflow NAMES
         scripts/verify-sprint.sh with an explicit --phase green
         twice — the second carrying an explicit non-default seed —
         and that no non-comment line names run-tests.st or any other
         verify entry point. What a YAML engine does with the text is
         outside the claim."
        <category: 'ci gate'>
        | lines gateLines |
        lines := self nonCommentLinesOf: aText.
        (lines anySatisfy: [:line |
            CommandLineFixtures does: line include: 'run-tests.st'])
                ifTrue: [^false].
        gateLines := lines select: [:line |
            CommandLineFixtures does: line include: 'verify-sprint.sh'].
        gateLines size = 2 ifFalse: [^false].
        (gateLines allSatisfy: [:line |
            CommandLineFixtures does: line
                include: './scripts/verify-sprint.sh --phase green'])
                    ifFalse: [^false].
        (CommandLineFixtures does: (gateLines at: 1) include: '--seed')
            ifTrue: [^false].
        ((CommandLineFixtures does: (gateLines at: 2) include: '--seed')
            and: [(CommandLineFixtures does: (gateLines at: 2)
                include: '--seed 20260718') not])
                    ifFalse: [^false].
        ^true
    ]

    "---- the wrap-staging-versus-scope checker (S25) ----"

    ReleaseFixtures class >> wrapScriptPath [
        <category: 'wrap staging'>
        ^'scripts/wrap-sprint.sh'
    ]

    ReleaseFixtures class >> scopePath [
        <category: 'wrap staging'>
        ^'.parley/scope'
    ]

    ReleaseFixtures class >> stagedTokensIn: aWrapText [
        "The path tokens of the wrap script''s one git add line, shell
         noise dropped. Textual bound: the line recognized is the one
         opening with git add; the notes-file add is covered by the
         checker composing the sprint-notes path itself."
        <category: 'wrap staging'>
        | tokens |
        (ExecFixtures linesOf: aWrapText) do: [:line |
            | trimmed |
            trimmed := line trimSeparators.
            (trimmed startsWith: 'git add ') ifTrue: [
                tokens := (trimmed substrings: ' ')
                    reject: [:each |
                        (#('git' 'add' '2>/dev/null' '||' 'true')
                            includes: each)].
                ^tokens asArray]].
        ^#()
    ]

    ReleaseFixtures class >> activeScopeAlternativesIn: aScopeText [
        "The active sprint''s scope regex, split into its alternatives
         with the anchors and escapes unspelled. The regex''s declared
         shape — every alternative a directory prefix ending in a
         slash, or an escaped literal ending in a dollar — is asserted
         by the caller, which is what keeps this mini-matcher honest
         rather than a regex engine nobody wrote."
        <category: 'wrap staging'>
        | lines sprint regexLine body |
        lines := ExecFixtures linesOf: aScopeText.
        sprint := nil.
        lines do: [:line |
            (line startsWith: 'sprint: ') ifTrue: [
                sprint := (line copyFrom: 9 to: line size) trimSeparators]].
        sprint isNil ifTrue: [^#()].
        regexLine := nil.
        lines do: [:line |
            (line startsWith: 'scope-', sprint, ':') ifTrue: [
                regexLine := line]].
        regexLine isNil ifTrue: [^#()].
        body := (regexLine copyFrom: (regexLine indexOf: $:) + 1
            to: regexLine size) trimSeparators.
        (body startsWith: '^(') ifTrue: [
            body := body copyFrom: 3 to: body size].
        (body endsWith: ')') ifTrue: [
            body := body copyFrom: 1 to: body size - 1].
        ^((body substrings: '|') collect: [:each |
            self unescaped: each]) asArray
    ]

    ReleaseFixtures class >> unescaped: anAlternative [
        "Backslash-dot becomes dot; nothing else in the scope regex is
         escaped, and the shape guard in the checker would fail loudly
         on an alternative this cannot represent."
        <category: 'wrap staging'>
        | out i |
        out := WriteStream on: String new.
        i := 1.
        [i <= anAlternative size] whileTrue: [
            ((anAlternative at: i) = $\
                and: [i < anAlternative size])
                    ifTrue: [
                        out nextPut: (anAlternative at: i + 1).
                        i := i + 2]
                    ifFalse: [
                        out nextPut: (anAlternative at: i).
                        i := i + 1]].
        ^out contents
    ]

    ReleaseFixtures class >> alternativesAreWellShaped: someAlternatives [
        "The mini-matcher''s honesty guard: every alternative is a
         prefix ending in a slash or a literal ending in a dollar. An
         alternative in any other shape means the scope regex grew a
         construct this checker cannot represent, and the law fails
         loudly instead of matching wrongly."
        <category: 'wrap staging'>
        ^someAlternatives allSatisfy: [:each |
            (each endsWith: '/') or: [each endsWith: '$']]
    ]

    ReleaseFixtures class >> path: aPath admittedBy: someAlternatives [
        "A dollar-anchored alternative admits exactly its literal: the
         scope regex opens with a caret, so README\.md$ matches the
         root file alone and an endsWith would over-admit nested
         spellings the sentinel rejects (Sprint 22 Gate A amendment)."
        <category: 'wrap staging'>
        ^someAlternatives anySatisfy: [:each |
            (each endsWith: '$')
                ifTrue: [aPath = (each copyFrom: 1 to: each size - 1)]
                ifFalse: [aPath startsWith: each]]
    ]

    ReleaseFixtures class >> filesUnder: aDirPath [
        "Every file under aDirPath recursively, with its path — #()
         for an absent directory, because the staging list stages over
         existing files and a path that is not there stages nothing."
        <category: 'wrap staging'>
        | dir entries out |
        dir := File name: aDirPath.
        (dir exists and: [dir isDirectory]) ifFalse: [^#()].
        entries := OrderedCollection new.
        dir namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [entries add: each]].
        out := OrderedCollection new.
        entries asSortedCollection do: [:each |
            | full |
            full := aDirPath, '/', each.
            (File name: full) isDirectory
                ifTrue: [out addAll: (self filesUnder: full)]
                ifFalse: [out add: full]].
        ^out asArray
    ]

    "---- the sprints-index checker (S26) ----"

    ReleaseFixtures class >> sprintsIndexPath [
        <category: 'sprints index'>
        ^'docs/sprints/README.md'
    ]

    ReleaseFixtures class >> notesFilesNamedIn: aText [
        "Every sprint-NN-notes.md target an index row links, in sorted
         order — recognized by the link form the index has carried
         since the reorganization."
        <category: 'sprints index'>
        | out |
        out := OrderedCollection new.
        (ExecFixtures linesOf: aText) do: [:line |
            | start |
            start := line indexOfSubCollection: '](sprint-'.
            start > 0 ifTrue: [
                | close target |
                close := line indexOf: $) ifAbsent: [0].
                close > start ifTrue: [
                    target := line copyFrom: start + 2 to: close - 1.
                    (target endsWith: '-notes.md') ifTrue: [
                        out add: target]]]].
        ^out asSortedCollection asArray
    ]

    ReleaseFixtures class >> notesFilesOnDisk [
        "Every sprint notes file docs/sprints actually holds, sorted."
        <category: 'sprints index'>
        | out |
        out := OrderedCollection new.
        (File name: 'docs/sprints') namesDo: [:each |
            ((each startsWith: 'sprint-')
                and: [each endsWith: '-notes.md'])
                    ifTrue: [out add: each]].
        ^out asSortedCollection asArray
    ]

    "---- the README slots and drift oracles (S27-S30) ----"

    ReleaseFixtures class >> readmeText [
        <category: 'readme'>
        ^PublishLayoutFixtures readmeSource
    ]

    ReleaseFixtures class >> badgeMarker [
        "The CI badge''s one distinctive path fragment."
        <category: 'readme'>
        ^'workflows/verify.yml/badge.svg'
    ]

    ReleaseFixtures class >> heroHeading [
        "The 60-second slot''s pinned heading. Its content is the
         path-dependency walk (decisions.md C-1) — the showcase never
         takes this slot."
        <category: 'readme'>
        ^'## The sixty-second walk'
    ]

    ReleaseFixtures class >> heroContentMarker [
        "The walk''s distinctive byte: a declared path dependency."
        <category: 'readme'>
        ^'path: ''../'
    ]

    ReleaseFixtures class >> installingHeading [
        <category: 'readme'>
        ^'## Installing'
    ]

    ReleaseFixtures class >> howBuiltHeading [
        <category: 'readme'>
        ^'## How this was built'
    ]

    ReleaseFixtures class >> showcaseHeading [
        "The self-hosting section''s pinned heading — its own section
         beside the how-built record, never the hero slot."
        <category: 'readme'>
        ^'## Parley, packaged by Parley'
    ]

    ReleaseFixtures class >> specFileNames [
        "The six lettered specs the how-built section links."
        <category: 'readme'>
        ^(Array with: 'domain-model.md'
            with: 'manifest-and-serialization.md'
            with: 'resolver.md'
            with: 'installer.md'
            with: 'execution-and-cli.md'),
            (Array with: 'publish-and-sources.md')
    ]

    ReleaseFixtures class >> findingsPath [
        <category: 'readme'>
        ^'docs/method/findings.md'
    ]

    ReleaseFixtures class >> tallyLabels [
        "The findings tally''s four row labels, exactly as its table
         spells them — the README quotes what the file says, never
         invents numbers, and this parser reads both files by the same
         labels."
        <category: 'readme'>
        ^Array with: 'Defect-findings'
            with: 'caught by a mechanism'
            with: 'caught by luck'
            with: 'Confirmation-findings'
    ]

    ReleaseFixtures class >> tallyCountFor: aLabel in: aText [
        "The first integer on the first table row carrying aLabel, or
         -1 when no row does — a value comparison never errors, so the
         drift law reports a missing row as inequality."
        <category: 'readme'>
        (ExecFixtures linesOf: aText) do: [:line |
            ((line startsWith: '|')
                and: [CommandLineFixtures does: line include: aLabel])
                    ifTrue: [^self firstIntegerIn: line]].
        ^-1
    ]

    ReleaseFixtures class >> firstIntegerIn: aLine [
        <category: 'readme'>
        | digits started |
        digits := WriteStream on: String new.
        started := false.
        aLine do: [:ch |
            ch isDigit
                ifTrue: [digits nextPut: ch. started := true]
                ifFalse: [started ifTrue: [
                    ^digits contents asNumber]]].
        ^started ifTrue: [digits contents asNumber] ifFalse: [-1]
    ]

    ReleaseFixtures class >> lawCountMarkerFor: aCount [
        "The law-count sentence''s load-bearing bytes: the number in
         strong emphasis beside the words axiomatic laws. Written at
         GREEN''s end against the final count, held by the law that
         counts the discovered suite the way the runner counts run=."
        <category: 'readme'>
        ^'**', aCount printString, '** axiomatic laws'
    ]

    ReleaseFixtures class >> discoveredLawCount [
        "The suite''s test selectors, counted exactly as the runner
         counts run=: every TestCase subclass in the Parley namespace,
         its local selectors opening with test, one law per selector."
        <category: 'readme'>
        | count parleySpace |
        parleySpace := Smalltalk at: #Parley.
        count := 0.
        TestCase allSubclasses do: [:each |
            each environment == parleySpace ifTrue: [
                each selectors do: [:sel |
                    (sel asString startsWith: 'test')
                        ifTrue: [count := count + 1]]]].
        ^count
    ]

    ReleaseFixtures class >> sectionOf: aHeading in: aText [
        "The text from aHeading''s line to the next section heading —
         empty when the heading is absent."
        <category: 'readme'>
        | start rest nextIdx |
        start := aText indexOfSubCollection: aHeading.
        start = 0 ifTrue: [^''].
        rest := aText copyFrom: start + aHeading size to: aText size.
        nextIdx := rest indexOfSubCollection: (String with: Character nl), '## '.
        nextIdx = 0 ifTrue: [^rest].
        ^rest copyFrom: 1 to: nextIdx - 1
    ]
]

Namespace current: Smalltalk.
