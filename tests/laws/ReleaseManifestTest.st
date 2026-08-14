"Parley Sprint 22 — the release manifest's law suite.
 Spec: docs/design/execution-and-cli.md §4.3; Doc B §4; §8 decisions
 70, 86, 87; issue #24 S9-S10, S14-S19.

 WHAT IS PROVED HERE. The declared release walk (every file
 releaseFiles names exists and is non-empty) with its falsifier
 anchored to the real declaration grown by one absent name — a
 file-exists law that cannot fail is the vacuous-enumeration defect,
 and a falsifier over a free fixture would pass in red undeclared;
 both CHANGELOG laws with falsifiers driven over doctored copies of
 the real text; the root Package.st drift pair — the version constant
 held equal to the manifest's declaration, and the fileIns held equal
 to the RECURSIVE src/ walk in the runner's order, with the
 removed-name half proving the comparison can fail and the directory
 census proving the walk saw what it thinks it saw (an empty
 enumeration makes a for-each law unfalsifiable — the Sprint 8
 lesson); and the deletion's absence law, red while ApplicationManifest
 exists and green the moment the namespace no longer binds it.

 COST DECLARATION: everything here is in-image reads of the checkout
 and tmp/-free — no process is spawned and no fixture directory is
 created."

Namespace current: Parley.

TestCase subclass: ReleaseManifestTest [

    <comment: 'Law suite for the release declaration: the releaseFiles
walk and its falsifier, the CHANGELOG heading laws and their
falsifiers, the root manifest''s version and fileIns drift pairs, and
the ApplicationManifest absence law.'>

    "---- the release walk (§8 decision 70) ----"

    testEveryDeclaredReleaseFileExistsAndIsNonEmpty [
        | missing |
        self deny: Parley releaseFiles isEmpty
            description: 'the release declaration is empty - the walk below would prove nothing'.
        missing := ReleaseFixtures missingReleaseFilesIn:
            Parley releaseFiles.
        self assert: missing isEmpty
            description: 'declared release files are missing or empty: ',
                missing printString
    ]

    testTheReleaseWalkFailsOnAnAbsentName [
        "The falsifier is the REAL declaration grown by one absent
         name, so it re-proves the real set clean in the same breath
         and cannot pass while releaseFiles is missing."
        | grown missing |
        grown := Parley releaseFiles,
            (Array with: 'no-such-release-file.md').
        missing := ReleaseFixtures missingReleaseFilesIn: grown.
        self assert: missing asArray
            = (Array with: 'no-such-release-file.md')
            description: 'the walk did not isolate the absent name: ',
                missing printString
    ]

    "---- the CHANGELOG laws (§8 decision 70) ----"

    testTheNewestChangelogHeadingEqualsTheVersion [
        "Bumping the constant without an entry fails the build - the
         changelog is mechanically current, never hopefully current."
        self assert: (ReleaseFixtures newestVersionHeadingIn:
            ReleaseFixtures changelogText) = Parley version
            description: 'the newest heading is not ', Parley version
    ]

    testTheHeadingSetEqualsTheReleasedSet [
        "At the tag the released set has one member and no Unreleased
         heading exists, so the newest-heading comparison needs no
         skip rule."
        | text |
        text := ReleaseFixtures changelogText.
        self assert: (ReleaseFixtures headingSet: text
            equals: (Array with: Parley version))
            description: 'the heading set is ',
                (ReleaseFixtures versionHeadingsIn: text) printString.
        self deny: (CommandLineFixtures does: text include: '[Unreleased]')
            description: 'the changelog carries an Unreleased heading'
    ]

    testTheChangelogLawsCanFail [
        "Both falsifiers over doctored copies of the REAL text: a
         bumped constant beside the unmoved changelog, and a
         duplicated heading. Anchored to the real artifact so neither
         half can pass while CHANGELOG.md is missing."
        | text bumped doubled |
        text := ReleaseFixtures changelogText.
        bumped := Parley version, '.1'.
        self deny: (ReleaseFixtures newestVersionHeadingIn: text) = bumped
            description: 'the newest-heading comparison cannot see a bumped constant'.
        doubled := text, (String with: Character nl),
            '## [', Parley version, '] - duplicated', (String with: Character nl).
        self deny: (ReleaseFixtures headingSet: doubled
            equals: (Array with: Parley version))
            description: 'the heading-set comparison cannot see a duplicated heading'
    ]

    "---- the root manifest's drift pair (§8 decision 86) ----"

    testTheRootManifestVersionEqualsTheConstant [
        "The literal in Package.st and the constant on the gateway are
         one number in two places, held equal by this law rather than
         by a computed send in a file strangers will copy."
        | manifest |
        manifest := ShowcaseFixtures rootManifest.
        self assert: manifest name = 'parley'
            description: 'the root manifest is named ',
                manifest name printString.
        self assert: manifest version
            = (Version fromString: Parley version)
            description: 'the manifest declares ',
                manifest version printString,
                ' while the constant answers ', Parley version
    ]

    testTheFileInsEqualTheRecursiveWalkAndTheWalkCanFail [
        "The drift law and its falsifier in one breath: the manifest's
         fileIns equal the recursive walk of src/ in the declared
         order, the walk saw the eight declared directories and is
         non-empty (File>>files answers no subdirectory on 3.2.5, so a
         flat enumeration would be vacuous for exactly the nested
         paths the showcase exists to prove), and the comparison fails
         over the walk with one name removed."
        | walk manifest reduced |
        walk := ReleaseFixtures srcFileWalk.
        self deny: walk isEmpty
            description: 'the src walk answered nothing - the comparison below would prove nothing'.
        self assert: ReleaseFixtures srcTopLevelDirectories
            = ReleaseFixtures srcDirectories asSortedCollection asArray
            description: 'src/ holds directories the declared order does not name: ',
                ReleaseFixtures srcTopLevelDirectories printString.
        manifest := ShowcaseFixtures rootManifest.
        self assert: (ReleaseFixtures fileInsMatch: manifest fileIns
            walk: walk)
            description: 'the manifest fileIns and the src walk disagree'.
        reduced := walk copyFrom: 2 to: walk size.
        self deny: (ReleaseFixtures fileInsMatch: manifest fileIns
            walk: reduced)
            description: 'the comparison cannot see a removed name'
    ]

    "---- the deletion's absence law (§8 decision 87) ----"

    testTheNamespaceNoLongerBindsApplicationManifest [
        "Red while the class exists; green the moment the GREEN stage
         deletes the class file - deleted, never commented out. The
         suite loading cleanly with the file gone is the other half,
         and the settled suite itself proves it."
        self deny: ((Smalltalk at: #Parley)
            includesKey: #ApplicationManifest)
            description: 'the Parley namespace still binds ApplicationManifest'
    ]
]

Namespace current: Smalltalk.
