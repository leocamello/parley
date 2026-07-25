"Parley — Publisher: manifest -> archive -> published index entry.
 Spec: docs/design/publish-and-sources.md §1/§1.1; issue #9 S6-S10.
 Publishing closes the authoring loop: the manifest an author wrote
 with the Doc B §2 vocabulary becomes a static index entry plus a
 toolchain-built archive that any PackageSource can serve. The trust
 boundary is untouched — publish runs on the AUTHOR'S OWN machine over
 the AUTHOR'S OWN manifest (already loaded; this class never reads
 Package.st and never evaluates anything), and its product is exactly
 the static, literals-only artifact every other machine consumes.

 Construction is pathname-passive: no I/O, no process. The pipeline is
 refusal-first, then batched pre-flight, then destination-confined
 staging, then the real toolchain build through the ONE process seam,
 then digest-and-land. Parley never zips: gst-package owns the archive
 format and this class only composes package.xml, copies bytes, and
 reads the star the toolchain produced.

 Fail-stop never cleans up behind an error: a failed build leaves the
 stage in place for inspection. A successful publish removes it."

Namespace current: Parley.

Object subclass: Publisher [
    | manifest workingDir destDir runner |

    <comment: 'The publish pipeline over four immutably held
collaborators: the already-loaded LibraryManifest, the working
directory holding its fileIns, the destination index directory, and a
ProcessRunner. publish answers the landed archive''s sha256 hex digest
or signals one PublishError; packageXml answers the composed archive
descriptor as a pure value. Class-side construction; zero public
setters; no value equality.'>

    Publisher class >> manifest: aManifest in: aWorkingDir to: aDestDir runner: aProcessRunner [
        "Answer a publisher of aManifest, whose fileIns live in
         aWorkingDir, into the index directory aDestDir, spawning only
         through aProcessRunner. Pathname-passive: nothing is read,
         written or spawned here."
        <category: 'instance creation'>
        ^self new
            setManifest: aManifest
            workingDir: aWorkingDir
            destDir: aDestDir
            runner: aProcessRunner
    ]

    setManifest: aManifest workingDir: aWorkingDir destDir: aDestDir runner: aProcessRunner [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        manifest := aManifest.
        workingDir := aWorkingDir.
        destDir := aDestDir.
        runner := aProcessRunner
    ]

    "---- the composed archive descriptor (§1.1) ----"

    packageXml [
        "The Doc F §1.1 composition as a pure value: one <filein> per
         manifest fileIn in MANIFEST order (load order is semantic),
         two-space indentation, single trailing newline. The manifest
         is the single source of truth, so decision 26's name equality
         holds by construction. Nothing else of the manifest enters the
         archive — versions, dependencies and prose live in the index
         entry; the archive is a load unit, not a metadata carrier."
        <category: 'composing'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '<package>'; nextPut: Character nl.
        out nextPutAll: '  <name>'; nextPutAll: manifest name;
            nextPutAll: '</name>'; nextPut: Character nl.
        manifest fileIns do: [:each |
            out nextPutAll: '  <filein>'; nextPutAll: each;
                nextPutAll: '</filein>'; nextPut: Character nl].
        out nextPutAll: '</package>'; nextPut: Character nl.
        ^out contents
    ]

    "---- the pipeline (§1) ----"

    publish [
        "Run the §1 pipeline and answer the landed archive's sha256 hex
         digest; signal one PublishError on any problem."
        <category: 'publishing'>
        | destination missing code |
        destination := File name: destDir.
        (destination exists and: [destination isDirectory]) ifFalse: [
            ^PublishError signalProblems:
                (Array with: self missingDestinationProblem)].
        (File name: self entryPath) exists ifTrue: [
            ^PublishError signalProblems:
                (Array with: self refusalProblem)].
        missing := self missingFileInProblems.
        missing isEmpty ifFalse: [^PublishError signalProblems: missing].
        self stage.
        code := runner run: self buildCommand.
        code = 0 ifFalse: [
            ^PublishError signalProblems: (Array with:
                'package build failed with exit code ', code printString,
                ': ', self buildCommand)].
        ^self land
    ]

    missingDestinationProblem [
        "Private — the destination check that precedes everything else
         (Doc F §1, Sprint 8): a destination that does not exist or is
         not a directory is one problem naming it. Publish does NOT
         create it — an author publishing into a directory that is not
         there has made an error worth naming, and creating it silently
         would make a typo indistinguishable from an intent. Nothing is
         checked after this, nothing is written, no process is spawned."
        <category: 'private-problems'>
        ^destDir, ': missing or unreadable destination directory - publish does not create it'
    ]

    refusalProblem [
        "Private — releases are immutable: republishing is a category
         error, not a batch member. Nothing else is checked and nothing
         is written."
        <category: 'private-problems'>
        ^manifest name, ' ', manifest version printString,
            ': already published - releases are immutable (',
            self entryPath, ' exists)'
    ]

    missingFileInProblems [
        "Private — one problem per declared fileIn absent from the
         working directory, in sorted filename order (the house style).
         No process has been spawned when these are answered."
        <category: 'private-problems'>
        | absent |
        absent := OrderedCollection new.
        manifest fileIns do: [:each |
            (File name: workingDir, '/', each) exists ifFalse: [
                absent add: each]].
        ^((absent asSortedCollection: [:a :b | a <= b]) asArray)
            collect: [:each |
                each, ': missing from the working directory ', workingDir]
    ]

    stage [
        "Private — the destination-confined staging directory (the Doc
         D §4 precedent): the composed package.xml and a byte-exact
         copy of every fileIn. A stage left behind by an earlier failed
         build is swept first, so staging is deterministic and publish
         is re-runnable. The stage is a subdirectory, so it is
         invisible to a DirectorySource scan."
        <category: 'private-staging'>
        self removeStage.
        Directory create: self stageDir.
        self write: self packageXml toFile: self stageDir, '/package.xml'.
        manifest fileIns do: [:each |
            self write: (File name: workingDir, '/', each) contents
                toFile: self stageDir, '/', each]
    ]

    land [
        "Private — digest the star the toolchain built, land the
         archive bytes and the published entry under the Doc B §5.2
         storage convention, then remove the stage. Archives are opaque
         bytes: they are copied, never parsed, never unpacked."
        <category: 'private-staging'>
        | bytes digest stream |
        bytes := (File name: self stageDir, '/', manifest name, '.star')
            contents.
        digest := Sha256 hexDigestOf: bytes.
        self write: bytes toFile: self archivePath.
        stream := (File name: self entryPath) writeStream.
        [IndexEntryWriter
            write: manifest
            archive: self archiveFileName
            sha256: digest
            on: stream]
                ensure: [stream close].
        self removeStage.
        ^digest
    ]

    removeStage [
        "Private — remove the flat stage and the directory itself;
         silent when absent."
        <category: 'private-staging'>
        | dir |
        dir := File name: self stageDir.
        dir exists ifFalse: [^self].
        dir files do: [:each | each remove].
        dir remove
    ]

    write: aByteString toFile: aPath [
        "Private — aByteString as the complete contents of aPath."
        <category: 'private-staging'>
        | stream |
        stream := (File name: aPath) writeStream.
        [stream nextPutAll: aByteString] ensure: [stream close]
    ]

    "---- paths and command lines ----"

    stageDir [
        "Private — staging is always inside the destination."
        <category: 'private-paths'>
        ^destDir, '/.parley-publish-stage'
    ]

    buildCommand [
        "Private — the toolchain build: the stage is both the target
         directory and the home of the composed package.xml. It owns
         the archive format; Parley never zips."
        <category: 'private-paths'>
        ^'gst-package --target-directory ', self stageDir, ' ',
            self stageDir, '/package.xml'
    ]

    releaseName [
        "Private — the <name>-<version> stem of the landed release."
        <category: 'private-paths'>
        ^manifest name, '-', manifest version printString
    ]

    archiveFileName [
        "Private — the landed archive's base name, as the published
         entry's #archive field names it. Storage convention only:
         entry identity remains contents-not-filename."
        <category: 'private-paths'>
        ^self releaseName, '.star'
    ]

    archivePath [
        <category: 'private-paths'>
        ^destDir, '/', self archiveFileName
    ]

    entryPath [
        <category: 'private-paths'>
        ^destDir, '/', self releaseName, '.st'
    ]
]

Namespace current: Smalltalk.
