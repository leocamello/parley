"Parley Sprint 3 — soundness fixtures: the late-edge-vs-decision shapes
 (issue #5 S1/S2) and the seeded random snapshot+root generator behind
 the randomized post-hoc soundness law (amended Doc C §7).

 Late-edge shapes (root 'my-app' -> a '*', b '*'; b {2.0.0} only —
 domain 1, decided first, no deps):
   recoverable    a {2.0.0 -> b '^1.0', 1.0.0 -> b '^2.0'} — the a 2.0.0
                  candidate collapses against the b decision pin and the
                  search backtracks to a 1.0.0.
   unsatisfiable  a {2.0.0 -> b '^1.0', 1.0.0 -> b '^1.0'} — every a
                  candidate collides with the pin. (Posted on issue #5:
                  with a {2.0.0} only, the smallest-domain tie-break
                  decides a BEFORE b and the failure surfaces as a plain
                  #noVersions with no #decision node anywhere in the
                  cause tree; Doc C §7's law needs the late edge to land
                  on an already-decided package, so a's domain must
                  exceed b's.)

 Random cases reuse DomainGenerators (PARLEY_SEED contract): 3..5
 packages from a fixed pool, 1..3 distinct versions each (components
 0..9), 0..2 deduplicated edges per release (never to self),
 constraints drawn from {any, caret of a target version, atLeast of a
 random version, exactly a target version} — mixed solvable and
 unsolvable shapes by construction."

Namespace current: Parley.

Object subclass: SoundnessFixtures [

    <comment: 'Class-side factory for the Sprint 3 soundness scenarios:
the two late-edge-vs-decision snapshots, the seeded random
snapshot+root generator, and the post-hoc soundness checker. Stateless;
every method answers a fresh value.'>

    "---- the fixed late-edge shapes (S1/S2) ----"

    SoundnessFixtures class >> lateEdgeRoot [
        "The root manifest: my-app 1.0.0 -> a '*', b '*'."
        <category: 'roots'>
        ^ResolverFixtures rootWith: #(#('a' '*') #('b' '*'))
    ]

    SoundnessFixtures class >> recoverableLateEdgeSnapshot [
        "b {2.0.0} (domain 1, no deps); a {2.0.0 -> b ^1.0,
         1.0.0 -> b ^2.0}. The a 2.0.0 edge collides with the b pin; the
         a 1.0.0 edge does not."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (ResolverFixtures release: 'b' version: '2.0.0'
            sha256: 'rb20' dependencies: #()).
        rs add: (ResolverFixtures release: 'a' version: '2.0.0'
            sha256: 'ra20' dependencies: #(#('b' '^1.0'))).
        rs add: (ResolverFixtures release: 'a' version: '1.0.0'
            sha256: 'ra10' dependencies: #(#('b' '^2.0'))).
        ^IndexSnapshot releases: rs
    ]

    SoundnessFixtures class >> unsatisfiableLateEdgeSnapshot [
        "b {2.0.0} (domain 1, no deps); a {2.0.0 -> b ^1.0,
         1.0.0 -> b ^1.0}. Every a candidate collides with the b pin."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (ResolverFixtures release: 'b' version: '2.0.0'
            sha256: 'ub20' dependencies: #()).
        rs add: (ResolverFixtures release: 'a' version: '2.0.0'
            sha256: 'ua20' dependencies: #(#('b' '^1.0'))).
        rs add: (ResolverFixtures release: 'a' version: '1.0.0'
            sha256: 'ua10' dependencies: #(#('b' '^1.0'))).
        ^IndexSnapshot releases: rs
    ]

    "---- the seeded random case generator (S5) ----"

    SoundnessFixtures class >> randomCaseWith: aGenerator [
        "Answer an Array of {root LibraryManifest. IndexSnapshot} fully
         determined by aGenerator's sequence."
        <category: 'random cases'>
        | pool versionsByName releases rootTargets count rootDeps |
        pool := self poolOfSize: 3 + (aGenerator nextInteger: 3).
        versionsByName := Dictionary new.
        pool do: [:name |
            versionsByName at: name put:
                (self distinctVersions: 1 + (aGenerator nextInteger: 3)
                    with: aGenerator)].
        releases := OrderedCollection new.
        pool do: [:name |
            (versionsByName at: name) do: [:v |
                releases add: (Array
                    with: name
                    with: v
                    with: 'h-', name, '-', v printString
                    with: (self randomEdgesFrom: name pool: pool
                        versions: versionsByName with: aGenerator))]].
        rootTargets := OrderedCollection new.
        count := 1 + (aGenerator nextInteger: 3).
        count timesRepeat: [
            | target |
            target := self anyOf: pool with: aGenerator.
            (rootTargets includes: target)
                ifFalse: [rootTargets add: target]].
        rootDeps := rootTargets collect: [:target |
            Dependency name: target constraint:
                (self randomConstraintOnto: (versionsByName at: target)
                    with: aGenerator)].
        ^Array
            with: (LibraryManifest
                name: 'gen-root'
                version: (Version major: 1 minor: 0 patch: 0)
                summary: '' author: '' license: ''
                fileIns: #('Root.st')
                dependencies: rootDeps asArray)
            with: (IndexSnapshot releases: releases)
    ]

    SoundnessFixtures class >> poolOfSize: n [
        "Private — the first n names of the fixed package pool."
        <category: 'private'>
        ^#('lib-a' 'lib-b' 'lib-c' 'lib-d' 'lib-e' 'lib-f')
            copyFrom: 1 to: n
    ]

    SoundnessFixtures class >> distinctVersions: count with: aGenerator [
        "Private — up to count distinct random versions (duplicates are
         dropped, so at least one always remains)."
        <category: 'private'>
        | versions |
        versions := OrderedCollection new.
        count timesRepeat: [
            | v |
            v := aGenerator nextVersion.
            (versions includes: v) ifFalse: [versions add: v]].
        ^versions
    ]

    SoundnessFixtures class >> randomEdgesFrom: aName pool: pool versions: versionsByName with: aGenerator [
        "Private — 0..2 dependency edges from one release to other pool
         packages (never to itself, targets deduplicated)."
        <category: 'private'>
        | edges used count target |
        edges := OrderedCollection new.
        used := OrderedCollection new.
        count := aGenerator nextInteger: 3.
        count timesRepeat: [
            target := self anyOf: (pool reject: [:n | n = aName])
                with: aGenerator.
            (used includes: target) ifFalse: [
                used add: target.
                edges add: (Dependency name: target constraint:
                    (self randomConstraintOnto: (versionsByName at: target)
                        with: aGenerator))]].
        ^edges asArray
    ]

    SoundnessFixtures class >> randomConstraintOnto: targetVersions with: aGenerator [
        "Private — a constraint aimed at a target's published versions:
         any, caret of a published version, atLeast of a random version
         (the unsolvable bias), or exactly a published version."
        <category: 'private'>
        | pick |
        pick := aGenerator nextInteger: 4.
        pick = 0 ifTrue: [^VersionConstraint any].
        pick = 1 ifTrue: [^VersionConstraint compatibleWith:
            (self anyOf: targetVersions with: aGenerator)].
        pick = 2 ifTrue: [^VersionConstraint atLeast: aGenerator nextVersion].
        ^VersionConstraint exactly: (self anyOf: targetVersions with: aGenerator)
    ]

    SoundnessFixtures class >> anyOf: aCollection with: aGenerator [
        "Private — one element drawn from aCollection."
        <category: 'private'>
        ^aCollection at: 1 + (aGenerator nextInteger: aCollection size)
    ]

    "---- the post-hoc soundness checker (S5) ----"

    SoundnessFixtures class >> soundnessProblemsOf: aResolution root: aManifest snapshot: aSnapshot [
        "Every violation of the amended Doc C §7 validity law: each root
         dependency and every dependency edge of every selected version
         must be satisfied by the selected version of its target.
         Answers a collection of problem strings; empty when sound."
        <category: 'checking'>
        | problems |
        problems := OrderedCollection new.
        aManifest dependencies do: [:dep |
            self check: dep imposedBy: 'the root manifest'
                in: aResolution into: problems].
        aResolution packageNames do: [:name |
            (aSnapshot dependenciesOf: name
                version: (aResolution versionOf: name)) do: [:dep |
                    self check: dep
                        imposedBy: name, ' ',
                            (aResolution versionOf: name) printString
                        in: aResolution into: problems]].
        ^problems
    ]

    SoundnessFixtures class >> check: aDependency imposedBy: aLabel in: aResolution into: problems [
        "Private — one edge check: the target must be selected and its
         selected version allowed by the edge's constraint."
        <category: 'private'>
        | selected |
        (aResolution packageNames includes: aDependency name) ifFalse: [
            problems add: aLabel, ' depends on ', aDependency name,
                ' but no version of it was selected'.
            ^self].
        selected := aResolution versionOf: aDependency name.
        (aDependency constraint allows: selected) ifFalse: [
            problems add: aLabel, ' depends on ', aDependency name, ' ',
                aDependency constraint printString,
                ' but ', selected printString, ' was selected']
    ]
]

Namespace current: Smalltalk.
