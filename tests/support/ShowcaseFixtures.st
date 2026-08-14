"Parley Sprint 22 — the self-hosting showcase's shared fixtures.
 Spec: docs/design/publish-and-sources.md §1 step 3; §8 decision 86;
 issue #24 S9-S12.

 TWO FIXTURE FAMILIES. The NESTED family is a small authored package
 whose fileIns carry a relative subdirectory path — the toolchain fact
 decision 86 probed (gst-package builds a star from a nested filein,
 creating the staging directories in its own working area) exercised
 end to end through Parley's own pipeline, small enough that S11 stays
 cheap. The SHOWCASE family is Parley itself: the root manifest loaded
 through the settled ManifestFile, published by a real Publisher from
 the repository root into a transient tmp/ index, consumed by a fresh
 working directory, and proved by a curated child answering the
 gateway's own version — the package manager, packaged by itself.

 THE REPOSITORY TREE IS READ, NEVER WRITTEN: the publish stage is
 destination-confined under tmp/, the consumer directories live under
 tmp/, and no fixture here creates state beside the harness. The
 showcase index is transient in the laws and never committed."

Namespace current: Parley.

Object subclass: ShowcaseFixtures [

    <comment: 'Sprint 22 showcase fixtures: the nested-fileIns package
family (author project, consumer project, child proof script) and the
Parley-consumes-Parley family (the root manifest, the consumer project
and the version-answering proof script).'>

    "---- the nested-fileIns package (S11) ----"

    ShowcaseFixtures class >> nestedName [
        <category: 'nested'>
        ^'kernel-nested'
    ]

    ShowcaseFixtures class >> nestedPackageContents [
        "An authored Package.st whose second fileIn lives two
         directories down — the shape the root Package.st scales up."
        <category: 'nested'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-nested'';
        version: ''1.0.0'';
        fileIns: #(''a.st'' ''sub/inner/b.st'') ]',
            SourceFixtures newline
    ]

    ShowcaseFixtures class >> nestedTopSource [
        <category: 'nested'>
        ^'Object subclass: KernelNestedA [
    KernelNestedA class >> greeting [ ^''top'' ]
]', SourceFixtures newline
    ]

    ShowcaseFixtures class >> nestedInnerSource [
        <category: 'nested'>
        ^'Object subclass: KernelNestedB [
    KernelNestedB class >> greeting [ ^''inner'' ]
]', SourceFixtures newline
    ]

    ShowcaseFixtures class >> writeNestedProjectIn: aWorkDir [
        "The author project: Package.st beside a.st, with b.st two
         levels down. The fixture creates the author's directories —
         the PUBLISHER must create the stage's, which is the change
         S11 proves."
        <category: 'nested'>
        SourceFixtures write: self nestedPackageContents
            toFile: 'Package.st' in: aWorkDir.
        SourceFixtures write: self nestedTopSource
            toFile: 'a.st' in: aWorkDir.
        Directory create: aWorkDir, '/sub'.
        Directory create: aWorkDir, '/sub/inner'.
        SourceFixtures write: self nestedInnerSource
            toFile: 'b.st' in: aWorkDir, '/sub/inner'
    ]

    ShowcaseFixtures class >> nestedConsumerContents [
        <category: 'nested'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-nested'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ShowcaseFixtures class >> nestedProofScriptContentsFor: aProofPath [
        "The child's proof: load the star and require BOTH classes —
         the nested one is the point, and a proof that asked only for
         the top-level class would pass over a stage that dropped the
         subdirectory."
        <category: 'nested'>
        ^'| ok stream |
ok := [PackageLoader fileInPackage: ''kernel-nested''.
    (Smalltalk includesKey: #KernelNestedA)
        and: [Smalltalk includesKey: #KernelNestedB]]
    on: Error do: [:e | false].
stream := (File name: ''', aProofPath, ''') writeStream.
stream nextPutAll: (ok ifTrue: [''present''] ifFalse: [''absent'']).
stream close', SourceFixtures newline
    ]

    "---- the showcase (S9, S10, S12) ----"

    ShowcaseFixtures class >> rootManifestPath [
        "The repository's own Package.st, relative to the process cwd
         the harness runs in — the repository root."
        <category: 'showcase'>
        ^'Package.st'
    ]

    ShowcaseFixtures class >> rootManifest [
        "Parley's own manifest through the settled authoring boundary."
        <category: 'showcase'>
        ^ManifestFile load: self rootManifestPath
    ]

    ShowcaseFixtures class >> repositoryRoot [
        "Where the root manifest's fileIns live — the Publisher's
         working directory for the showcase publish. The process cwd
         is the repository root under the harness."
        <category: 'showcase'>
        ^'.'
    ]

    ShowcaseFixtures class >> showcaseConsumerContents [
        "A consumer that depends on Parley itself."
        <category: 'showcase'>
        ^'Parley define: [:pkg |
    pkg
        name: ''showcase-consumer'';
        version: ''0.1.0'';
        fileIns: #(''App.st'');
        dependency: ''parley'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ShowcaseFixtures class >> showcaseProofScriptContentsFor: aProofPath [
        "The child's proof: load the parley star and make the gateway
         ANSWER — the recorded text is whatever Parley version returns
         in the curated child, so the law's oracle is the constant
         itself and a class that merely loaded without answering
         records the failure word instead."
        <category: 'showcase'>
        ^'| answered stream |
answered := [PackageLoader fileInPackage: ''parley''.
    ((Smalltalk at: #Parley) at: #Parley) version]
    on: Error do: [:e | ''absent''].
stream := (File name: ''', aProofPath, ''') writeStream.
stream nextPutAll: answered.
stream close', SourceFixtures newline
    ]
]

Namespace current: Smalltalk.
