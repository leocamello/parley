"Parley — PathOverlay: a source is composed, never taught.
 Spec: docs/design/resolver.md §1.2/§1.3/§2; §8 decisions 50, 51, 68.
 Sprint 21.

 THE FIFTH PUT-IT-IN-THE-SOURCE APPLICATION (after decisions 37, 46,
 50, 51). A path dependency enters resolution as an OVERLAY computed by
 the source layer: this class implements the full PackageSource
 protocol as a DECORATOR around the wired source — or around nothing,
 for a manifest whose only dependencies are paths — and no settled
 source class changes. Resolver, both strategies and ConstraintLedger
 are untouched, so a future PubGrubStrategy inherits path dependencies
 for free.

 snapshot IS THE ONE I/O MOMENT (decision 50's shape). It reads each
 sibling's own Package.st through the settled ManifestFile — the
 authoring boundary reused whole, so a malformed sibling answers the
 settled authoring diagnosis naming the SIBLING's path — walks the
 siblings' own path dependencies to fixpoint, refuses one name supplied
 by two textually distinct directories, re-seeds the base through the
 settled seededWith:, takes the base snapshot, and answers the
 composition. After it answers, nothing here is consulted again: the
 resolver runs against a sealed value.

 THE VISITED SET IS KEYED BY TEXTUAL CANONICALISATION OF THE DECLARED
 STRING (decision 68 as amended at Sprint 21's Gate A). Read literally,
 `resolved absolute path` names a FILESYSTEM question — File name: ...
 fullName — and asking it would make this class a NINTH direct-I/O site
 and fail decision 60's eight-class census by construction. So ./
 segments and <segment>/.. pairs collapse by STRING ARITHMETIC, no
 filesystem is consulted, and '../a' and '../x/../a' are ONE supplier:
 one visit, no refusal, so a legitimate diamond of local checkouts
 spelled two ways resolves instead of being falsely refused.

 THE CANONICAL FORM IS FOR KEYING ONLY. Every file this class opens is
 opened through the DECLARED string and every diagnosis names the
 declared string, byte for byte — which is what lets the settled
 ManifestFile diagnosis name the author's own path with no re-voicing
 (the read strategy approved at Sprint 21's Gate A ruling; decision 68
 is deliberately silent on which spelling opens the file).

 SYMLINK ALIASING IS A STATED BOUND OUTSIDE THE CLAIM (decision 43's
 standard). Two declared strings that differ textually and reach one
 directory THROUGH A SYMLINK are two suppliers to this walk and trip
 the two-paths refusal. Resolving that needs exactly the File I/O the
 census forbids, so it is FAIL-STOP, NOT FAIL-WRONG: the operator gets
 one diagnosis naming both declared paths and can spell them alike.

 NO DIRECT FILE I/O LIVES HERE. Siblings are read through ManifestFile,
 which already holds its census seat; the census stays at eight."

Namespace current: Parley.

Object subclass: PathOverlay [
    | base paths workingDir seeds |

    <comment: 'A PackageSource decorator that overlays the packages a
root manifest declares by path. Holds the wired source (possibly nil),
the declared PathDependency values, the directory their paths resolve
against, and the decision-51 seeds. Class-side construction; zero
public setters; every operation answers a new instance.'>

    PathOverlay class >> over: aPackageSource paths: somePathDependencies in: aWorkingDir [
        "Answer an overlay of somePathDependencies — PathDependency
         values whose declared paths resolve against aWorkingDir —
         around aPackageSource, which may be nil when the manifest
         declares nothing an index could supply (decision 83's second
         state). Construction is pathname-passive: no I/O, no process."
        <category: 'instance creation'>
        ^self new
            setBase: aPackageSource
            paths: somePathDependencies
            workingDir: aWorkingDir
            seeds: Set new
    ]

    setBase: aPackageSource paths: somePathDependencies workingDir: aWorkingDir seeds: someSeeds [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        base := aPackageSource.
        paths := somePathDependencies.
        workingDir := aWorkingDir.
        seeds := someSeeds
    ]

    "---- the PackageSource protocol ----"

    seededWith: someNames [
        "Answer an overlay told that someNames matter (Doc C §1.2's
         contract verbatim): a NEW decorator holding the seeds,
         performing no I/O — it has not read anything yet, and the
         receiver is unchanged.
         The base is NOT seeded here. Seeding it is snapshot's business,
         because only then are the siblings' own declared names known,
         and those are half of what the base must be told (Doc C §1.3)."
        <category: 'source protocol'>
        ^self class new
            setBase: base
            paths: paths
            workingDir: workingDir
            seeds: someNames
    ]

    versionsOf: aPackageName [
        "Delegated to the base UNTOUCHED: this is an index question, and
         §2's provenance split governs the protocol exactly as it
         governs the snapshot. With no base wired there is no index, and
         decision 24's rule applies — an unknown is an ordinary empty
         collection, never an error."
        <category: 'source protocol'>
        ^base isNil ifTrue: [#()] ifFalse: [base versionsOf: aPackageName]
    ]

    manifestFor: aPackageName version: aVersion [
        "Delegated to the base untouched; nil for an unknown (package,
         version), decision 24's settled convention."
        <category: 'source protocol'>
        ^base isNil
            ifTrue: [nil]
            ifFalse: [base manifestFor: aPackageName version: aVersion]
    ]

    fetch: aPackageName version: aVersion [
        "Delegated to the base untouched. A #path pin NEVER reaches here
         — the CLI hands the Installer the path-free view (§8 decision
         69) — so with no base wired this is an index fetch in a project
         that has no index, which is a source problem like any other."
        <category: 'source protocol'>
        base isNil ifTrue: [
            ^SourceError signalProblems: (Array with:
                aPackageName, ' ', aVersion printString,
                ': no index source is wired')].
        ^base fetch: aPackageName version: aVersion
    ]

    snapshot [
        "THE ONE I/O MOMENT. Read the siblings to fixpoint, re-seed the
         base with the caller's seeds union the siblings' own declared
         dependency names, take the base's snapshot, and answer the
         composition (Doc C §2).
         The order is the ruling: the walk happens FIRST because its
         result is what the base must be told, which is what lets a
         sparse closure fetch what a sibling needs with no new protocol
         and no source change."
        <category: 'source protocol'>
        | records |
        records := self walkSiblings.
        ^(self baseSnapshotSeededFor: records) overlaying: records
    ]

    "---- the walk ----"

    walkSiblings [
        "Private — every sibling reachable from the declared paths, as
         name -> {Version. edges. declared path}, read to fixpoint.

         The visited set is keyed by the CANONICAL form and the record
         carries the DECLARED string: a re-visit is a no-op, so a cycle
         terminates and an aliased pair is one supplier, while every
         byte the operator ever sees is one they wrote."
        <category: 'private-walk'>
        | records visited pending declared |
        records := Dictionary new.
        visited := Dictionary new.
        pending := OrderedCollection new.
        paths do: [:each |
            pending addLast: (Array with: each with: workingDir)].
        [pending isEmpty] whileFalse: [
            | entry dependency parent key |
            entry := pending removeFirst.
            dependency := entry at: 1.
            parent := entry at: 2.
            declared := dependency path.
            key := self canonical: parent, '/', declared.
            (visited includesKey: dependency name)
                ifTrue: [
                    "A name already supplied. The same directory reached
                     twice — by a cycle, by a diamond, or by two
                     spellings that canonicalise alike — is a NO-OP; two
                     textually distinct directories are the refusal, and
                     it names both paths AS DECLARED."
                    (visited at: dependency name) = key ifFalse: [
                        ^SourceError signalProblems: (Array with:
                            (self twoPathsLineFor: dependency name
                                first: ((records at: dependency name) at: 3)
                                second: declared))]]
                ifFalse: [
                    visited at: dependency name put: key.
                    self record: dependency
                        under: parent
                        into: records
                        pending: pending]].
        ^self edgesResolvedIn: records
    ]

    record: aPathDependency under: aParentDir into: aRecordDictionary pending: aPendingQueue [
        "Private — read one sibling through the settled ManifestFile and
         file its declaration, queueing its OWN path dependencies for
         the walk with the sibling's directory as their parent: a path
         a sibling declares is relative to that sibling, not to the
         root.

         THE FILE IS OPENED THROUGH THE DECLARED STRING (the Gate A read
         strategy), so a missing or malformed sibling answers the
         settled authoring diagnosis naming the author's own path and
         nothing here re-voices it.

         A SIBLING'S DEV DEPENDENCIES ARE EXCLUDED, exactly as publish
         would exclude them (§8 decision 69): the overlay is the
         development-time reading of the same projection publish makes
         at release time — which is also why it FOLLOWS a sibling's path
         dependencies while publish REFUSES them."
        <category: 'private-walk'>
        | dir manifest |
        dir := aParentDir, '/', aPathDependency path.
        manifest := ManifestFile load: dir, '/Package.st'.
        aRecordDictionary at: aPathDependency name put: (Array
            with: manifest version
            with: manifest
            with: aPathDependency path).
        manifest pathDependencies do: [:each |
            aPendingQueue addLast: (Array with: each with: dir)]
    ]

    edgesResolvedIn: aRecordDictionary [
        "Private — turn each sibling's manifest into the edge list the
         snapshot answers: its INDEX dependencies verbatim, plus one
         edge per path dependency of its own.

         A PATH EDGE IS UNCONSTRAINED, and that is exact rather than
         lax: the overlay offers exactly one version for an overlaid
         name — the whole name, because a path dependency always wins
         over an index release — so the only candidate is the sibling's
         own declaration, and any constraint that admits it admits
         nothing else. Inventing a version-shaped constraint here would
         spell a pin the author never wrote."
        <category: 'private-walk'>
        | out |
        out := Dictionary new.
        aRecordDictionary keysAndValuesDo: [:name :record |
            | manifest edges |
            manifest := record at: 2.
            edges := OrderedCollection new.
            edges addAll: manifest dependencies.
            manifest pathDependencies do: [:each |
                edges add: (Dependency name: each name
                    constraint: VersionConstraint any)].
            out at: name put: (Array
                with: (record at: 1)
                with: edges asArray
                with: (record at: 3))].
        ^out
    ]

    "---- textual canonicalisation (keying only; no filesystem) ----"

    canonical: aPathString [
        "Private — aPathString with ./ segments dropped and
         <segment>/.. pairs collapsed, BY STRING ARITHMETIC. No
         filesystem is consulted: asking one would make this class a
         ninth direct-I/O site and fail §8 decision 60's census, which
         is the whole reason decision 68's original wording was amended.

         A leading .. that cannot be collapsed is KEPT, because dropping
         it would make two genuinely different directories share a key —
         a false no-op, which is worse than the false refusal this
         method exists to prevent."
        <category: 'private-canonical'>
        | out |
        out := OrderedCollection new.
        (self segmentsOf: aPathString) do: [:segment |
            segment = '.'
                ifFalse: [
                    (segment = '..'
                        and: [out isEmpty not
                        and: [out last ~= '..']])
                        ifTrue: [out removeLast]
                        ifFalse: [out addLast: segment]]].
        ^self join: out
    ]

    segmentsOf: aPathString [
        "Private — aPathString split on / with empty segments dropped,
         so a doubled or trailing separator cannot make two spellings of
         one path differ."
        <category: 'private-canonical'>
        | out current |
        out := OrderedCollection new.
        current := WriteStream on: String new.
        aPathString do: [:ch |
            ch = $/
                ifTrue: [
                    current contents isEmpty
                        ifFalse: [out addLast: current contents].
                    current := WriteStream on: String new]
                ifFalse: [current nextPut: ch]].
        current contents isEmpty ifFalse: [out addLast: current contents].
        ^out
    ]

    join: someSegments [
        "Private — segments rejoined with single separators."
        <category: 'private-canonical'>
        | out |
        out := WriteStream on: String new.
        someSegments
            do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: $/].
        ^out contents
    ]

    "---- the re-seed and the base ----"

    baseSnapshotSeededFor: aRecordDictionary [
        "Private — the base's snapshot, taken AFTER it is told what
         matters: the caller's decision-51 seeds UNION the siblings'
         declared dependency names, through the settled seededWith:.
         That union is what lets a sparse closure fetch what a sibling
         needs — with no new protocol, and no change to any source
         class. A scanning source answers self and reads its whole index
         either way.
         With no base wired the composition is over an empty index,
         which is decision 83's second state and not a special case:
         a manifest whose only dependencies are paths needs no index."
        <category: 'private-walk'>
        | wanted |
        base isNil ifTrue: [^IndexSnapshot releases: #()].
        wanted := Set new.
        wanted addAll: seeds.
        aRecordDictionary do: [:record |
            (record at: 2) do: [:edge | wanted add: edge name]].
        ^(base seededWith: wanted) snapshot
    ]

    "---- the declared wording (§8 decision 81: consumed twice) ----"

    twoPathsLineFor: aName first: aFirstPath second: aSecondPath [
        "Private — one name supplied by two textually distinct
         directories (pinned in RED, issue #23). ONE diagnosis naming
         BOTH paths as the author declared them: naming one would leave
         the operator to find the other, and naming the canonical form
         would name bytes nobody wrote."
        <category: 'private-walk'>
        ^aName printString, ' is declared by two path dependencies - ',
            aFirstPath printString, ' and ', aSecondPath printString,
            ' - a name may be supplied by only one directory'
    ]
]

Namespace current: Smalltalk.
