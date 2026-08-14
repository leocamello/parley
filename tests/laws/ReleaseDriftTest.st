"Parley Sprint 22 — the README's release drift laws.
 Spec: issue #24 S27-S30; §8 decision 86 (the showcase's README seat,
 decisions.md C-1); the Sprint 15/17/19/20 README-law families this
 sprint's restructure must keep green.

 THREE DRIFT PAIRS OVER ONE DOCUMENT. The tally: the README quotes
 docs/method/findings.md's own tally table and is held equal to it by
 label, so the Gate B close-out that moves the tally cannot leave the
 README stale — quote what the file says, never invent numbers. The
 law count: the README's sentence is held to the suite counted exactly
 as the runner counts run= (every Parley-namespace TestCase's local
 test selectors), written at GREEN's end against the final count. The
 slots: the badge, the installation section, the sixty-second hero
 carrying the path-dependency walk, the how-built section linking the
 six specs, the delivery record and the findings file, and the
 showcase section BESIDE how-built — never the hero slot, with no
 other section between the pair.

 The S24/S25/S26 checkers live in the acceptance suite alone — they
 are the sprint's three declared red-phase passes, and a second
 selector over the same artifacts would be an undeclared fourth.

 COST DECLARATION: in-image reads of README.md and findings.md; no
 process, no fixture directory."

Namespace current: Parley.

TestCase subclass: ReleaseDriftTest [

    <comment: 'Law suite for the restructured README: the tally drift
pair against findings.md, the law-count sentence against the
discovered suite, and the ruled slots — badge, hero, how-built links,
and the showcase section beside it.'>

    testTheReadmeTallyEqualsTheFindingsTally [
        "Four labeled counts, read from both documents by one parser -
         a README quoting numbers findings.md no longer says is the
         staleness this law exists to make impossible."
        | readme findings |
        readme := ReleaseFixtures readmeText.
        findings := (File name: ReleaseFixtures findingsPath) contents.
        ReleaseFixtures tallyLabels do: [:label |
            | expected quoted |
            expected := ReleaseFixtures tallyCountFor: label in: findings.
            quoted := ReleaseFixtures tallyCountFor: label in: readme.
            self assert: expected >= 0
                description: 'findings.md has no tally row labelled ', label.
            self assert: quoted = expected
                description: 'the README quotes ', quoted printString,
                    ' for ', label, ' while findings.md says ',
                    expected printString]
    ]

    testTheReadmeLawCountMatchesTheDiscoveredSuite [
        "Counted exactly as the runner counts run=, compared against
         the sentence's strong-emphasis number - written at GREEN's
         end against the final Sprint 22 count, never a stale one."
        | count |
        count := ReleaseFixtures discoveredLawCount.
        self assert: count > 0
            description: 'the discovery counted nothing - the comparison below would prove nothing'.
        self assert: (CommandLineFixtures does: ReleaseFixtures readmeText
            include: (ReleaseFixtures lawCountMarkerFor: count))
            description: 'the README does not state the discovered count of ',
                count printString
    ]

    testTheReadmeCarriesTheRuledSlotsInTheRuledOrder [
        "The restructure's shape: badge, then installation, then the
         sixty-second hero carrying the path-dependency walk, then the
         depth; how-built linking the six specs, the delivery record
         and findings.md; and the showcase section directly beside
         how-built — never in the hero slot."
        | readme badgeIdx installIdx heroIdx howIdx showcaseIdx afterHow nextIdx nextHeading heroSection howSection |
        readme := ReleaseFixtures readmeText.
        badgeIdx := readme indexOfSubCollection:
            ReleaseFixtures badgeMarker.
        installIdx := readme indexOfSubCollection:
            ReleaseFixtures installingHeading.
        heroIdx := readme indexOfSubCollection:
            ReleaseFixtures heroHeading.
        howIdx := readme indexOfSubCollection:
            ReleaseFixtures howBuiltHeading.
        showcaseIdx := readme indexOfSubCollection:
            ReleaseFixtures showcaseHeading.
        self assert: badgeIdx > 0
            description: 'the README carries no CI badge'.
        self assert: installIdx > 0
            description: 'the README has no Installing section'.
        self assert: heroIdx > 0
            description: 'the README has no sixty-second hero section'.
        self assert: howIdx > 0
            description: 'the README has no how-built section'.
        self assert: showcaseIdx > 0
            description: 'the README has no showcase section'.
        self assert: badgeIdx < installIdx
            description: 'the badge does not open the document'.
        self assert: installIdx < heroIdx
            description: 'installation does not precede the hero walk'.
        self assert: heroIdx < howIdx
            description: 'the hero slot sits below the record'.
        self assert: howIdx < showcaseIdx
            description: 'the showcase precedes how-built'.
        afterHow := readme copyFrom:
            howIdx + ReleaseFixtures howBuiltHeading size
            to: readme size.
        nextIdx := afterHow indexOfSubCollection:
            (String with: Character nl), '## '.
        self assert: nextIdx > 0
            description: 'no section follows how-built'.
        nextHeading := afterHow copyFrom: nextIdx + 1
            to: (afterHow size min:
                nextIdx + ReleaseFixtures showcaseHeading size).
        self assert: nextHeading = ReleaseFixtures showcaseHeading
            description: 'the section beside how-built is ',
                nextHeading printString, ', not the showcase'.
        heroSection := ReleaseFixtures sectionOf:
            ReleaseFixtures heroHeading in: readme.
        self assert: (CommandLineFixtures does: heroSection
            include: ReleaseFixtures heroContentMarker)
            description: 'the hero slot does not carry the path-dependency walk'.
        self deny: (CommandLineFixtures does: heroSection
            include: ReleaseFixtures showcaseHeading)
            description: 'the showcase took the hero slot'.
        howSection := ReleaseFixtures sectionOf:
            ReleaseFixtures howBuiltHeading in: readme.
        ReleaseFixtures specFileNames do: [:each |
            self assert: (CommandLineFixtures does: howSection
                include: each)
                description: 'how-built does not link ', each].
        self assert: (CommandLineFixtures does: howSection
            include: 'docs/sprints/')
            description: 'how-built does not link the delivery record'.
        self assert: (CommandLineFixtures does: howSection
            include: ReleaseFixtures findingsPath)
            description: 'how-built does not link the findings file'
    ]
]

Namespace current: Smalltalk.
