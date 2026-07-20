"Parley Sprint 6 — ManifestFile laws (issue #8 S8/S9; Doc E §3).

 ManifestFile load: resolves master-plan decision 19: it files the
 developer's OWN Package.st in with the Parley namespace current — so
 the token Parley resolves to the Parley.Parley gateway and the Doc B
 §2 syntax works verbatim — and answers the manifest recorded by
 define:. A file that never sends define: signals one ManifestError
 whose single problem names the path (wording pinned here, posted on
 issue #8). The recording is cleared per load, so a stale manifest can
 never leak into a later load.

 Trust boundary unchanged: only the owner's manifest is ever loaded
 this way; these fixtures author their own files under tmp/."

Namespace current: Parley.

TestCase subclass: ManifestFileTest [
    | fixtureDirs |

    <comment: 'Laws for ManifestFile: the load round-trip against the
Doc B §2 authoring syntax, the pinned define-less error, and the
cleared recording between loads.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    "---- S8: load answers the defined manifest ----"

    testLoadAnswersTheDefinedManifest [
        | dir manifest dep |
        dir := self freshDir: 'mf-load'.
        ExecFixtures writePackage: ExecFixtures minimalManifestContents
            in: dir.
        manifest := ManifestFile load: dir, '/Package.st'.
        self assert: manifest name = 'kernel-json'.
        self assert: manifest version = (self version: '0.3.1').
        self assert: manifest fileIns = #('Reader.st').
        self assert: manifest summary = ''.
        self assert: manifest author = ''.
        self assert: manifest license = ''.
        self assert: manifest dependencies size = 1.
        dep := manifest dependencies at: 1.
        self assert: dep name = 'kernel-streams'.
        self assert: dep constraint
            = (VersionConstraint fromString: '>=1.0 <2.0')
    ]

    testLoadRoundTripsTheFullDocBTemplate [
        | dir manifest |
        dir := self freshDir: 'mf-template'.
        ExecFixtures writePackage: ExecFixtures initTemplateContents
            in: dir.
        manifest := ManifestFile load: dir, '/Package.st'.
        self assert: manifest name = 'kernel-json'.
        self assert: manifest version = (self version: '0.3.1').
        self assert: manifest summary
            = 'A JSON reader/writer speaking pure message sends'.
        self assert: manifest author = 'Leonardo'.
        self assert: manifest license = 'MIT'.
        self assert: manifest fileIns
            = #('Reader.st' 'Writer.st' 'Extensions.st').
        self assert: manifest dependencies size = 2.
        self assert: (manifest dependencies at: 1) name = 'kernel-streams'.
        self assert: (manifest dependencies at: 1) constraint
            = (VersionConstraint fromString: '>=1.0 <2.0').
        self assert: (manifest dependencies at: 2) name = 'kernel-strings'.
        self assert: (manifest dependencies at: 2) constraint
            = (VersionConstraint fromString: '^0.4.2')
    ]

    "---- S9: a define-less file is a one-problem error ----"

    testADefineLessFileIsAOneProblemError [
        | dir path error |
        dir := self freshDir: 'mf-defineless'.
        path := dir, '/Package.st'.
        ExecFixtures writePackage: ExecFixtures definelessContents
            in: dir.
        error := nil.
        [ManifestFile load: path.
         self assert: false description: 'expected a ManifestError']
            on: ManifestError
            do: [:e | error := e].
        self assert: error problems size = 1.
        self assert: (error problems at: 1)
            = (ExecFixtures defineLessProblemFor: path).
        self assert: error messageText
            = ('Manifest has 1 problem(s): ',
                (ExecFixtures defineLessProblemFor: path))
    ]

    testTheRecordingIsClearedBetweenLoads [
        | goodDir badDir caught |
        goodDir := self freshDir: 'mf-clear-good'.
        badDir := self freshDir: 'mf-clear-bad'.
        ExecFixtures writePackage: ExecFixtures minimalManifestContents
            in: goodDir.
        ExecFixtures writePackage: ExecFixtures definelessContents
            in: badDir.
        self assert: (ManifestFile load: goodDir, '/Package.st') name
            = 'kernel-json'.
        caught := false.
        [ManifestFile load: badDir, '/Package.st']
            on: ManifestError
            do: [:e | caught := true].
        self assert: caught
            description: 'a define-less load after a successful one must still fail - the recording was not cleared'
    ]
]

Namespace current: Smalltalk.
