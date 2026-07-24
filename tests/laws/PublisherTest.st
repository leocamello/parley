"Parley Sprint 7 — Publisher and PublishError laws (issue #9 S6-S10;
 Doc F §1/§1.1).

 Publishing closes the authoring loop: the manifest an author wrote
 with the Doc B §2 vocabulary becomes a static index entry plus a
 toolchain-built archive that any PackageSource can serve. The trust
 boundary is untouched — publish runs on the author's OWN machine over
 the author's OWN manifest (the manifest arrives already loaded; the
 Publisher never reads Package.st itself), and its product is exactly
 the static, literals-only artifact every other machine consumes.

 Protocol decisions pinned here (posted on issue #9 for confirmation):
   - constructor: Publisher manifest: aManifest in: aWorkingDir
     to: aDestDir runner: aProcessRunner — four collaborators held
     immutably, class-side construction, zero public setters, no value
     equality (the decision-23 precedent);
   - publish answers the landed archive's sha256 hex digest; on any
     problem it signals ONE PublishError;
   - packageXml — a pure value message answering the Doc F §1.1
     composition, so the composition is byte-pinnable without reading
     a stage that a successful publish removes (test-defined: Doc F
     §1.1 requires the bytes be pinned in RED, and this is the
     object-shaped way to observe a value);
   - PublishError problems / messageText follow the ManifestError
     house style: 'Publish has <n> problem(s): ' with problems joined
     by '; ';
   - the pinned wordings live in PublishFixtures: refusalProblemFor:
     version:in:, missingFileInProblemFor:in:, buildFailureProblemFor:
     code:; the build command line is buildCommandFor:;
   - the staging directory is <dest>/.parley-publish-stage — always
     destination-confined, removed on success, LEFT IN PLACE after a
     failed build (fail-stop never cleans up behind an error).

 Real processes appear only where the law under test IS the toolchain
 build; every such law touches the missing Publisher class before
 anything could spawn, so the red phase spawns nothing. Star digests
 are computed per test through the settled Sha256 — never pinned.
 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown."

Namespace current: Parley.

TestCase subclass: PublisherTest [
    | fixtureDirs |

    <comment: 'Laws for Publisher and PublishError: the composed
package.xml byte oracle, the real toolchain build and the landed
release, refusal-first, batched pre-flight, build fail-stop, and the
destination-confined stage.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    greetingWorkDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: path.
        ^path
    ]

    publisherFor: aManifest in: aWorkDir to: aDestDir runner: aRunner [
        ^Publisher
            manifest: aManifest
            in: aWorkDir
            to: aDestDir
            runner: aRunner
    ]

    problemsFrom: aBlock [
        "The problems array of the PublishError aBlock signals; fails
         when no error, or a non-PublishError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a PublishError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: PublishError)
                    description: 'expected a PublishError, got ', e class name.
                ^e problems].
        ^#()
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    "---- the composed package.xml (Doc F §1.1) ----"

    testTheComposedPackageXmlMatchesTheByteOracle [
        "The manifest is the single source of truth: one <filein> per
         fileIn in MANIFEST order, and nothing else of the manifest
         enters the archive. No process is involved — the composition
         is a pure value."
        | publisher |
        publisher := self publisherFor: PublishFixtures greetingManifest
            in: 'tmp/parley-xml-work'
            to: 'tmp/parley-xml-dest'
            runner: RecordingRunner new.
        self assert: publisher packageXml
            = PublishFixtures greetingPackageXml
    ]

    "---- S6: the real build lands the release ----"

    testPublishBuildsTheArchiveAndLandsTheRelease [
        | work dest publisher digest starBytes |
        work := self greetingWorkDir: 'pub-build-work'.
        dest := self freshDir: 'pub-build-dest'.
        publisher := self publisherFor: PublishFixtures greetingManifest
            in: work
            to: dest
            runner: ProcessRunner new.
        digest := publisher publish.
        starBytes := self contentsOf: dest, '/',
            PublishFixtures archiveFileName.
        self assert: digest = (Sha256 hexDigestOf: starBytes).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest).
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName)
    ]

    testTheStageIsRemovedOnSuccessAndTheWorkingDirIsUntouched [
        | work dest before publisher |
        work := self greetingWorkDir: 'pub-stage-work'.
        dest := self freshDir: 'pub-stage-dest'.
        before := PublishFixtures fileNamesIn: work.
        publisher := self publisherFor: PublishFixtures greetingManifest
            in: work
            to: dest
            runner: ProcessRunner new.
        publisher publish.
        self deny: (File name: (PublishFixtures stageDirIn: dest)) exists.
        self assert: (PublishFixtures fileNamesIn: work) = before.
        self assert: (self contentsOf: work, '/Greeting.st')
            = PublishFixtures greetingSource
    ]

    "---- S8: refusal first — releases are immutable ----"

    testRepublishingRefusesBeforeAnythingElseIsChecked [
        "The destination already holds the release, and the working
         directory holds NONE of the declared fileIns: the refusal is
         still the only problem — nothing else is checked, nothing is
         written, no process is spawned."
        | work dest runner problems before |
        work := self freshDir: 'pub-refuse-work'.
        dest := self freshDir: 'pub-refuse-dest'.
        SourceFixtures write: 'already published'
            toFile: PublishFixtures entryFileName in: dest.
        before := PublishFixtures fileNamesIn: dest.
        runner := RecordingRunner new.
        problems := self problemsFrom: [
            (self publisherFor: PublishFixtures greetingManifest
                in: work to: dest runner: runner) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures refusalProblemFor: 'kernel-greeting'
                version: '1.0.0' in: dest).
        self assert: runner commands = #().
        self assert: (PublishFixtures fileNamesIn: dest) = before.
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = 'already published'
    ]

    "---- S9: batched pre-flight, before any process ----"

    testMissingFileInsBatchInSortedFilenameOrder [
        | work dest runner problems |
        work := self freshDir: 'pub-preflight-work'.
        dest := self freshDir: 'pub-preflight-dest'.
        runner := RecordingRunner new.
        problems := self problemsFrom: [
            (self publisherFor: PublishFixtures absentFileInsManifest
                in: work to: dest runner: runner) publish].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = (PublishFixtures missingFileInProblemFor: 'Alpha.st' in: work).
        self assert: (problems at: 2)
            = (PublishFixtures missingFileInProblemFor: 'Zebra.st' in: work).
        self assert: runner commands = #().
        self assert: (PublishFixtures fileNamesIn: dest) = #()
    ]

    testPublishErrorMessageTextIsTheBatchedHouseStyle [
        | work dest expected |
        work := self freshDir: 'pub-message-work'.
        dest := self freshDir: 'pub-message-dest'.
        expected := PublishFixtures publishErrorMessageFor: (Array
            with: (PublishFixtures missingFileInProblemFor: 'Alpha.st' in: work)
            with: (PublishFixtures missingFileInProblemFor: 'Zebra.st' in: work)).
        [(self publisherFor: PublishFixtures absentFileInsManifest
            in: work to: dest runner: RecordingRunner new) publish.
         self assert: false description: 'expected a PublishError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: PublishError).
                self assert: e messageText = expected]
    ]

    testOnlyTheAbsentFileInsAreReported [
        "A present fileIn contributes no problem — the pre-flight
         reports what is missing, not what it inspected."
        | work dest problems |
        work := self freshDir: 'pub-partial-work'.
        dest := self freshDir: 'pub-partial-dest'.
        SourceFixtures write: PublishFixtures greetingSource
            toFile: 'Greeting.st' in: work.
        problems := self problemsFrom: [
            (self publisherFor: PublishFixtures greetingManifest
                in: work to: dest runner: RecordingRunner new) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures missingFileInProblemFor: 'Extra.st' in: work)
    ]

    "---- S10: a failed build is fail-stop ----"

    testAFailedBuildIsFailStopAndLandsNothing [
        | work dest runner problems stage |
        work := self greetingWorkDir: 'pub-failstop-work'.
        dest := self freshDir: 'pub-failstop-dest'.
        runner := RecordingRunner answering: 2.
        problems := self problemsFrom: [
            (self publisherFor: PublishFixtures greetingManifest
                in: work to: dest runner: runner) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures buildFailureProblemFor:
                (PublishFixtures buildCommandFor: dest) code: 2).
        self assert: runner commands
            = (Array with: (PublishFixtures buildCommandFor: dest)).
        self deny: (File name: dest, '/', PublishFixtures archiveFileName)
            exists.
        self deny: (File name: dest, '/', PublishFixtures entryFileName)
            exists.
        "fail-stop never cleans up behind an error: the stage stays for
         inspection, and it holds exactly the composed package.xml and
         byte-exact copies of the declared fileIns"
        stage := PublishFixtures stageDirIn: dest.
        self assert: (PublishFixtures fileNamesIn: stage)
            = #('Extra.st' 'Greeting.st' 'package.xml').
        self assert: (self contentsOf: stage, '/package.xml')
            = PublishFixtures greetingPackageXml.
        self assert: (self contentsOf: stage, '/Greeting.st')
            = PublishFixtures greetingSource.
        self assert: (self contentsOf: stage, '/Extra.st')
            = PublishFixtures greetingExtraSource.
        self assert: (PublishFixtures fileNamesIn: dest)
            = #('.parley-publish-stage')
    ]
]

Namespace current: Smalltalk.
