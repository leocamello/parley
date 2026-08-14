"Parley Sprint 22 — the shell completions' law suite.
 Spec: docs/design/execution-and-cli.md §4.3; §8 decision 70; issue #24
 S20-S23 and the P3 pre-RED ruling.

 GENERATE AND COMPARE, BYTE FOR BYTE. The committed files under
 completions/ are never hand-maintained: the laws regenerate both from
 the declared tables — verbRows' name column, the source flags with
 their variable field, the mode flags, the layouts, the question flags
 — and hold the committed bytes equal to the generation, so a verb,
 flag or layout can never ship without its completion. The falsifier
 regenerates over a verb table grown by one name and proves the
 comparison fails, anchored to the committed files so it cannot pass
 while they are missing.

 COST DECLARATION: in-image reads of the two committed files; no
 process, no fixture directory."

Namespace current: Parley.

TestCase subclass: CompletionTest [

    <comment: 'Law suite for the generated completions: byte-identity
of both committed files with the declaration-derived generation, and
the grown-table falsifier.'>

    testTheBashCompletionIsExactlyTheGeneratedText [
        self assert: CompletionFixtures committedBashText
            = CompletionFixtures bashText
            description: 'completions/parley.bash differs from the generated text'
    ]

    testTheZshCompletionIsExactlyTheGeneratedText [
        self assert: CompletionFixtures committedZshText
            = CompletionFixtures zshText
            description: 'completions/_parley differs from the generated text'
    ]

    testTheComparisonFailsOverAGrownVerbTable [
        "One extra verb in the generation makes both comparisons fail
         - the byte-identity is sensitive to the verb list, not merely
         to the files existing."
        self deny: CompletionFixtures committedBashText
            = (CompletionFixtures bashTextOverVerbWords:
                CompletionFixtures grownVerbWords)
            description: 'the bash comparison cannot see a grown verb table'.
        self deny: CompletionFixtures committedZshText
            = (CompletionFixtures zshTextOverVerbWords:
                CompletionFixtures grownVerbWords)
            description: 'the zsh comparison cannot see a grown verb table'
    ]
]

Namespace current: Smalltalk.
