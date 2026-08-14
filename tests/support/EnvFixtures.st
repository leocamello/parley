"Parley Sprint 22 — the environment layer's shared fixtures.
 Spec: docs/design/execution-and-cli.md §4.2; §8 decision 85; issue #24
 S1-S8 and the EnvLayerTest laws.

 THE SEAM'S TEST SIDE. The environment read is one injectable seam in
 CommandLine — a one-argument valuable answering a String or nil — and
 these fixtures build the doubles a law pins its environment with: a
 Dictionary-backed reader, the empty reader, and the composed shipped
 commands that pin the three variables empty (set-empty IS unset,
 probed on 3.2.5, which is why a shell prefix of empty assignments is
 a pin and not a no-op).

 THE VARIABLE NAMES ARE A MIRROR, NOT A SECOND AUTHORITY. Production
 declares each name as the per-row fourth field of the source-flag
 table; variableNames below spells the same three so that RED fixtures
 can compose commands and wordings before the column exists, and the
 EnvLayerTest drift law holds the mirror equal to the table — the
 PathDepFixtures wording-mirror idiom, applied to names.

 THE PINNED WORDING lives here once, consumed by the laws and never
 composed at a refusing site's spelling: the two-variables refusal is
 the configuration file's own two-source rule applied to the second
 supplier of recorded state (Doc B §5.7 mirrored), with a remedy that
 is checked — unsetting always works, and a flag always wins by the
 chain itself, which is S5's contrast half."

Namespace current: Parley.

Object subclass: EnvFixtures [

    <comment: 'Sprint 22 environment-layer fixtures: the seam doubles,
the variable-name mirror tied to the declared table by a drift law, the
pinned two-variables refusal wording, and the shipped-binary command
compositions that pin or export the declared variables.'>

    "---- the variable-name mirror ----"

    EnvFixtures class >> variableNames [
        "The three declared variable names, in the source-flag table''s
         own row order — the test-side mirror of the table''s fourth
         column, held equal to it by the EnvLayerTest drift law."
        <category: 'variables'>
        ^Array with: 'PARLEY_SOURCE' with: 'PARLEY_GIT'
            with: 'PARLEY_INDEX'
    ]

    EnvFixtures class >> variableListText [
        "The names as the sentence lists them, through the settled
         list composer — the amended needs-index sentence''s third
         remedy reads exactly this."
        <category: 'variables'>
        ^CommandLine list: self variableNames conjunction: 'or'
    ]

    "---- the seam doubles ----"

    EnvFixtures class >> emptyEnvironment [
        "The closed seam: every variable is unset. What the settled
         two-argument constructor pins by delegation, and what every
         law that drives no environment passes explicitly."
        <category: 'doubles'>
        ^[:name | nil]
    ]

    EnvFixtures class >> environmentWith: aDictionary [
        "A reader over aDictionary: a set variable answers its string,
         everything else answers nil exactly as Smalltalk getenv: does
         for an unset name (probed on 3.2.5)."
        <category: 'doubles'>
        ^[:name | aDictionary at: name ifAbsent: [nil]]
    ]

    EnvFixtures class >> environmentOf: aName value: aValue [
        <category: 'doubles'>
        | env |
        env := Dictionary new.
        env at: aName put: aValue.
        ^self environmentWith: env
    ]

    EnvFixtures class >> environmentOf: aName value: aValue and: anotherName value: anotherValue [
        <category: 'doubles'>
        | env |
        env := Dictionary new.
        env at: aName put: aValue.
        env at: anotherName put: anotherValue.
        ^self environmentWith: env
    ]

    "---- the pinned wording (issue #24, RED; §8 decision 85) ----"

    EnvFixtures class >> twoVariablesRefusalFor: aName and: anotherName [
        "The declared refusal for two source variables set while the
         argv carries no source flag: one line naming both variables in
         the table''s order, at exit 1 — never the usage block, because
         the argv is legal (decisions 80/83). The remedy is checked
         (decision 58): unsetting one always works, and a source flag
         always wins by the precedence chain itself."
        <category: 'pinned wordings'>
        ^aName, ' and ', anotherName,
            ' are both set - the environment supplies at most one source, unset one or give a source flag'
    ]

    "---- the shipped-binary compositions ----"

    EnvFixtures class >> pinnedEmptyPrefix [
        "Every declared variable assigned empty, as a shell prefix.
         Set-empty is unset (§8 decision 85, probed), so this prefix
         pins the child''s environment closed against whatever the
         harness process has exported — the settled shipped-binary
         composers carry it from Sprint 22 on."
        <category: 'shipped commands'>
        | out |
        out := WriteStream on: String new.
        self variableNames do: [:name |
            out nextPutAll: name; nextPutAll: '= '].
        ^out contents
    ]

    EnvFixtures class >> shippedCommandIn: aWorkDir args: anArgsString exporting: aName value: aValue [
        "The settled shipped-binary command with ONE variable exported
         after the empty pins, so the export is the assignment the
         child actually sees. This is how a law drives an environment
         state through the real binary without mutating the harness
         process (issue #24: the seam is injectable for laws, and the
         shipped default reads the process environment)."
        <category: 'shipped commands'>
        ^'cd ', (CommandLineFixtures absolutePathOf: aWorkDir),
            ' && ', self pinnedEmptyPrefix,
            aName, '=', aValue,
            ' PARLEY_ROOT=', CommandLineFixtures repoRoot,
            ' gst -q ', CommandLineFixtures repoRoot,
            '/bin/parley-main.st -a ', anArgsString
    ]

    EnvFixtures class >> unpinnedCommandIn: aWorkDir args: anArgsString exporting: aName value: aValue [
        "The same command WITHOUT the empty pins — the composition a
         hostile harness environment would reach if the settled
         composers did not pin. The immunity law runs both: the export
         must reach the child here, and must be defeated by the pins
         above, or the pins are decoration."
        <category: 'shipped commands'>
        ^'cd ', (CommandLineFixtures absolutePathOf: aWorkDir),
            ' && ', aName, '=', aValue,
            ' PARLEY_ROOT=', CommandLineFixtures repoRoot,
            ' gst -q ', CommandLineFixtures repoRoot,
            '/bin/parley-main.st -a ', anArgsString
    ]
]

Namespace current: Smalltalk.
