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
    | manifest workingDir destDir layout runner |

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
         written or spawned here.

         The settled four-collaborator constructor, unchanged in
         meaning: it publishes into the FLAT layout, which is what it
         always did and what publish still writes when no --layout is
         stated (§8 decision 53)."
        <category: 'instance creation'>
        ^self
            manifest: aManifest
            in: aWorkingDir
            to: aDestDir
            layout: self flatLayout
            runner: aProcessRunner
    ]

    Publisher class >> manifest: aManifest in: aWorkingDir to: aDestDir layout: aLayout runner: aProcessRunner [
        "The same publisher over a stated destination LAYOUT (Doc F
         §8): aLayout is one of the specs below, and the destination
         shape is a PARAMETER of one pipeline — never a subclass and
         never a kind-check. Pathname-passive as always."
        <category: 'instance creation'>
        ^self new
            setManifest: aManifest
            workingDir: aWorkingDir
            destDir: aDestDir
            layout: aLayout
            runner: aProcessRunner
    ]

    "---- the layout specs (Doc F §8.1) ----"

    Publisher class >> flatLayout [
        "The settled layout a DirectorySource scans: releases land
         directly in the destination and no listing is maintained.

         A LAYOUT IS THREE MESSAGES, and they are the three questions
         a destination shape actually answers: where the release
         lands, what must be sound before anything is built, and what
         else the layout maintains once the release is down. The
         Publisher performs them — a table lookup, never a branch on
         which layout it holds.

         The names live HERE, where the methods live, and
         CommandLine class >> publishLayouts declares which layouts
         exist by asking for them: one definition, consumed twice."
        <category: 'layouts'>
        ^#(#flatReleaseDir #noListingProblems #writeNoListing)
    ]

    Publisher class >> sparseLayout [
        "The per-package layout a SparseIndexSource reads (Doc F
         §7.1): the release lands in <dest>/<name>/ beside a
         versions.st listing, which is read before the build and
         rewritten LAST, after the entry and the archive are down."
        <category: 'layouts'>
        ^#(#sparseReleaseDir #sparseListingProblems #writeSparseListing)
    ]

    setManifest: aManifest workingDir: aWorkingDir destDir: aDestDir layout: aLayout runner: aProcessRunner [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        manifest := aManifest.
        workingDir := aWorkingDir.
        destDir := aDestDir.
        layout := aLayout.
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
        | destination missing listing code |
        destination := File name: destDir.
        (destination exists and: [destination isDirectory]) ifFalse: [
            ^PublishError signalProblems:
                (Array with: self missingDestinationProblem)].
        (File name: self entryPath) exists ifTrue: [
            ^PublishError signalProblems:
                (Array with: self refusalProblem)].
        missing := self missingFileInProblems.
        missing isEmpty ifFalse: [^PublishError signalProblems: missing].
        "The layout's own pre-flight, BEFORE anything is staged: a
         malformed existing listing costs the author a message and
         nothing else, so the destination is byte-identical after the
         refusal (Doc F §8.2)."
        listing := self perform: (layout at: 2).
        listing isEmpty ifFalse: [^PublishError signalProblems: listing].
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
         storage convention, then whatever else the layout maintains,
         then remove the stage. Archives are opaque bytes: they are
         copied, never parsed, never unpacked.

         THE ORDER IS THE MECHANISM (Doc F §8.3). Doc F §7.5 rules
         that a listing naming an entry the index does not hold is an
         INDEX DEFECT, and the client diagnoses it. So the archive and
         the entry land FIRST and the listing is written LAST: an
         interrupted publish leaves an index that is merely missing a
         release rather than one that lies about holding it. The
         producer must not be able to manufacture the state its own
         consumer reports."
        <category: 'private-staging'>
        | bytes digest stream |
        bytes := (File name: self stageDir, '/', manifest name, '.star')
            contents.
        digest := Sha256 hexDigestOf: bytes.
        self ensureReleaseDir.
        self write: bytes toFile: self archivePath.
        stream := (File name: self entryPath) writeStream.
        [IndexEntryWriter
            write: manifest
            archive: self archiveFileName
            sha256: digest
            on: stream]
                ensure: [stream close].
        self perform: (layout at: 3).
        self removeStage.
        ^digest
    ]

    ensureReleaseDir [
        "Private — the directory the layout lands releases in, created
         only now: a refusal earlier in the pipeline must leave the
         destination exactly as it found it, and a package directory
         created before the build would be published state a failure
         left behind."
        <category: 'private-staging'>
        (File name: self releaseDir) exists
            ifFalse: [Directory create: self releaseDir]
    ]

    "---- the listing (Doc B §5.6, written here for the first time) ----"

    noListingProblems [
        "Private — the flat layout maintains no listing, so it has
         nothing to read and nothing to complain about."
        <category: 'private-listing'>
        ^#()
    ]

    writeNoListing [
        "Private — and nothing to write. A layout answers all three
         questions; answering one of them with silence is what makes
         the flat layout a row in the table rather than a special
         case in the pipeline."
        <category: 'private-listing'>
        ^self
    ]

    sparseListingProblems [
        "Private — THE FIFTH DESERIALIZATION BOUNDARY (Doc E §4.2,
         §8 decisions 35/38/43): publishing into an index that already
         holds the package means READING its versions.st, which makes
         this class a sender of IndexEntryReader readFrom: and
         therefore a declared row of
         CommandLine class >> deserializationBoundaries. A malformed
         existing listing is ONE problem naming the file and the
         defect, and nothing is written."
        <category: 'private-listing'>
        | problems |
        problems := OrderedCollection new.
        self listingVersionsInto: problems.
        ^problems asArray
    ]

    writeSparseListing [
        "Private — the read-modify-write: the existing listing is
         loaded, this release's version added, and the whole
         re-rendered. It runs LAST in land, after the entry and the
         archive are down. The listing is already known sound — the
         same read refused the publish before anything was staged."
        <category: 'private-listing'>
        | versions |
        versions := Set new.
        (self listingVersionsInto: OrderedCollection new)
            do: [:each | versions add: each].
        versions add: manifest version.
        self write: (self renderListing: versions) toFile: self listingPath
    ]

    renderListing: someVersions [
        "Private — the Doc B §5.6 artifact through the §5.1 grammar and
         the §5.4 rendering rules: sorted by VERSION comparison, so
         1.9.0 precedes 1.10.0 and the same set of versions renders
         identically whatever order it was published in. Sorting the
         strings is the obvious implementation and the wrong one:
         '1.10.0' precedes '1.9.0' lexically. Versions render through
         Version printString, always three components (§5.4 rule 4)."
        <category: 'private-listing'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-listing'' 1 #versions #('.
        ((someVersions asSortedCollection: [:a :b | a <= b]) asArray)
            do: [:each |
                out nextPut: $'; nextPutAll: each printString; nextPut: $']
            separatedBy: [out nextPut: $ ].
        out nextPutAll: '))'; nextPut: Character nl.
        ^out contents
    ]

    listingVersionsInto: problems [
        "Private — the listing read, validated ground by ground and
         answering the Versions it names. An absent listing is the
         ordinary first publish of a package: no listing, no versions,
         no problem. Every defect is one problem naming the file and
         the defect, in the grammar the settled SparseIndexSource uses
         for the same file — same reader, same sentences, each boundary
         naming the file the way ITS operator can act on it.

         The settled Version fromString: and SchemaShape are consumed,
         never re-implemented: they stay the single definition of what
         parses and what a schema string is."
        <category: 'private-listing'>
        | file entry versions |
        versions := OrderedCollection new.
        file := File name: self listingPath.
        file exists ifFalse: [^versions].
        entry := [IndexEntryReader readFrom: (ReadStream on: file contents)]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e |
                problems add: self listingLabel, ': ', e messageText.
                ^OrderedCollection new].
        (entry at: 1) = #'parley-listing' ifFalse: [
            problems add: self listingLabel, ': wrong artifact tag ',
                (entry at: 1) printString,
                ' - a version listing holds #''parley-listing'' 1 artifacts'.
            ^OrderedCollection new].
        (entry size >= 4 and: [(entry at: 3) = #versions]) ifFalse: [
            problems add: self listingLabel, ': missing schema key #versions'.
            ^OrderedCollection new].
        (entry at: 4) do: [:each |
            (SchemaShape isString: each) ifFalse: [
                problems add: self listingLabel, ': #versions member ',
                    each printString, ' is not a version string'.
                ^OrderedCollection new].
            [versions add: (Version fromString: each)]
                on: VersionFormatError
                do: [:e |
                    problems add: self listingLabel, ': #versions ',
                        each printString, ' does not parse as a version'.
                    ^OrderedCollection new]].
        ^versions
    ]

    listingLabel [
        "Private — how a PublishError names the listing: by the
         destination path the AUTHOR typed, which is the spelling they
         can act on. The client names the same file by its
         base-relative URL path, for the same reason."
        <category: 'private-listing'>
        ^self listingPath
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

    releaseDir [
        "Private — where this layout lands a release. A table lookup:
         the layout says which message answers it, and this class never
         branches on which layout it is holding."
        <category: 'private-paths'>
        ^self perform: (layout at: 1)
    ]

    flatReleaseDir [
        "Private — the settled layout lands releases directly in the
         destination, which is what a DirectorySource scans."
        <category: 'private-paths'>
        ^destDir
    ]

    sparseReleaseDir [
        "Private — the sparse layout lands them in <dest>/<name>/,
         which is what a client addresses by constructed URL (Doc F
         §7.1). The name comes from the manifest, so decision 26's
         name equality holds here exactly as it does in package.xml."
        <category: 'private-paths'>
        ^destDir, '/', manifest name
    ]

    archivePath [
        <category: 'private-paths'>
        ^self releaseDir, '/', self archiveFileName
    ]

    entryPath [
        <category: 'private-paths'>
        ^self releaseDir, '/', self releaseName, '.st'
    ]

    listingPath [
        <category: 'private-paths'>
        ^self releaseDir, '/versions.st'
    ]
]

Namespace current: Smalltalk.
