"Parley Sprint 2 — hand-built in-memory snapshot fixtures for the pure
 resolution engine (Doc C §2: tests exercise the resolver with hand-built
 snapshots — no filesystem, no network, no process access).

 Shapes: the S9 trivial snapshot, the S11 satisfiable and S12
 unsatisfiable diamonds, the S13 backtracking shape, the S14
 domain-order shape, plus a fetch-signalling snapshot double for S17.

 Construction protocol pinned here (posted on issue #4 for confirmation):
   IndexSnapshot releases: aCollection
 where each release is an Array of
   {name (String). Version. sha256 (String, '' when absent).
    Array of Dependency (constraints pre-parsed)}."

Namespace current: Parley.

Object subclass: ResolverFixtures [

    <comment: 'Class-side factory for the fixed Sprint 2 resolver
scenarios: snapshots, root manifests, the resolver seam, and
derivation-tree walking helpers. Stateless; every method answers a
fresh value.'>

    "---- building blocks ----"

    ResolverFixtures class >> release: aName version: aVersionString sha256: aSha dependencies: depPairs [
        "One snapshot release record. depPairs is an array of
         #('depName' 'constraintString') pairs, parsed here so the
         snapshot holds pre-parsed constraints."
        <category: 'building'>
        | deps |
        deps := depPairs collect: [:pair |
            Dependency
                name: (pair at: 1)
                constraint: (VersionConstraint fromString: (pair at: 2))].
        ^Array
            with: aName
            with: (Version fromString: aVersionString)
            with: aSha
            with: deps asArray
    ]

    ResolverFixtures class >> rootWith: depPairs [
        "The root manifest 'my-app' 1.0.0 depending per depPairs."
        <category: 'building'>
        ^Parley define: [:pkg |
            pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st').
            depPairs do: [:pair |
                pkg dependency: (pair at: 1) constraint: (pair at: 2)]]
    ]

    ResolverFixtures class >> resolve: aManifest against: aSnapshot [
        "The one sanctioned invocation shape: the strategy seam."
        <category: 'resolving'>
        ^(Resolver strategy: BacktrackingStrategy new)
            resolve: aManifest against: aSnapshot
    ]

    "---- S9: trivial ----"

    ResolverFixtures class >> trivialSnapshot [
        "kernel-a {1.0.0, 1.2.0, 2.0.0}, no dependencies."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (self release: 'kernel-a' version: '1.0.0'
            sha256: 'aa10' dependencies: #()).
        rs add: (self release: 'kernel-a' version: '1.2.0'
            sha256: 'aa12' dependencies: #()).
        rs add: (self release: 'kernel-a' version: '2.0.0'
            sha256: 'aa20' dependencies: #()).
        ^IndexSnapshot releases: rs
    ]

    ResolverFixtures class >> trivialRoot [
        <category: 'roots'>
        ^self rootWith: #(#('kernel-a' '^1.0'))
    ]

    "---- S11/S16: satisfiable diamond ----"

    ResolverFixtures class >> satisfiableDiamondSnapshot [
        "a 1.0.0 -> c >=1.0 <3.0; b 1.0.0 -> c ^2.0; c {1.5.0, 2.4.0, 3.0.0}."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (self release: 'a' version: '1.0.0'
            sha256: 'ab12' dependencies: #(#('c' '>=1.0 <3.0'))).
        rs add: (self release: 'b' version: '1.0.0'
            sha256: 'cd34' dependencies: #(#('c' '^2.0'))).
        rs add: (self release: 'c' version: '1.5.0'
            sha256: 'ef15' dependencies: #()).
        rs add: (self release: 'c' version: '2.4.0'
            sha256: 'ef56' dependencies: #()).
        rs add: (self release: 'c' version: '3.0.0'
            sha256: 'ef30' dependencies: #()).
        ^IndexSnapshot releases: rs
    ]

    ResolverFixtures class >> diamondRoot [
        <category: 'roots'>
        ^self rootWith: #(#('a' '^1.0') #('b' '^1.0'))
    ]

    "---- S12/S15: unsatisfiable diamond ----"

    ResolverFixtures class >> unsatisfiableDiamondSnapshot [
        "a 1.0.0 -> c ^1.0; b 1.0.0 -> c ^2.0; c {1.5.0, 2.4.0}."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (self release: 'a' version: '1.0.0'
            sha256: 'ua10' dependencies: #(#('c' '^1.0'))).
        rs add: (self release: 'b' version: '1.0.0'
            sha256: 'ub10' dependencies: #(#('c' '^2.0'))).
        rs add: (self release: 'c' version: '1.5.0'
            sha256: 'uc15' dependencies: #()).
        rs add: (self release: 'c' version: '2.4.0'
            sha256: 'uc24' dependencies: #()).
        ^IndexSnapshot releases: rs
    ]

    "---- S13: backtracking exists ----"

    ResolverFixtures class >> backtrackingSnapshot [
        "a {2.0.0 -> b ^2.0, 1.0.0 -> b ^1.0}; b {1.0.0, 2.0.0}.
         Greedy a 2.0.0 collapses against the root's b ^1.0; a 1.0.0
         succeeds — proving backtracking exists."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (self release: 'a' version: '2.0.0'
            sha256: 'ba20' dependencies: #(#('b' '^2.0'))).
        rs add: (self release: 'a' version: '1.0.0'
            sha256: 'ba10' dependencies: #(#('b' '^1.0'))).
        rs add: (self release: 'b' version: '1.0.0'
            sha256: 'bb10' dependencies: #()).
        rs add: (self release: 'b' version: '2.0.0'
            sha256: 'bb20' dependencies: #()).
        ^IndexSnapshot releases: rs
    ]

    ResolverFixtures class >> backtrackingRoot [
        <category: 'roots'>
        ^self rootWith: #(#('a' '*') #('b' '^1.0'))
    ]

    "---- S14: smallest-domain-first observability ----"

    ResolverFixtures class >> domainOrderSnapshot [
        "a {1.0.0, 2.0.0, 3.0.0} (no deps, domain size 3);
         b {1.0.0} (domain size 1), b 1.0.0 -> a ^9.0.
         Deciding b first records a ^9.0 before a is touched, so the
         #noVersions leaf for a blames both the root and b 1.0.0."
        <category: 'snapshots'>
        | rs |
        rs := OrderedCollection new.
        rs add: (self release: 'a' version: '1.0.0'
            sha256: 'da10' dependencies: #()).
        rs add: (self release: 'a' version: '2.0.0'
            sha256: 'da20' dependencies: #()).
        rs add: (self release: 'a' version: '3.0.0'
            sha256: 'da30' dependencies: #()).
        rs add: (self release: 'b' version: '1.0.0'
            sha256: 'db10' dependencies: #(#('a' '^9.0'))).
        ^IndexSnapshot releases: rs
    ]

    ResolverFixtures class >> domainOrderRoot [
        <category: 'roots'>
        ^self rootWith: #(#('a' '*') #('b' '^1.0'))
    ]

    "---- derivation-tree walking ----"

    ResolverFixtures class >> externalLeavesOf: anIncompatibility [
        "Every external node reachable from anIncompatibility via
         cause links, in depth-first order."
        <category: 'tree walking'>
        | leaves |
        leaves := OrderedCollection new.
        self collectExternalsOf: anIncompatibility into: leaves.
        ^leaves
    ]

    ResolverFixtures class >> collectExternalsOf: anIncompatibility into: aCollection [
        <category: 'tree walking'>
        anIncompatibility isExternal
            ifTrue: [aCollection add: anIncompatibility]
            ifFalse: [anIncompatibility cause do: [:parent |
                self collectExternalsOf: parent into: aCollection]]
    ]

    ResolverFixtures class >> in: aTermCollection findPackage: aName positive: aBoolean constraint: aConstraint [
        "The first term matching all three value fields, or nil."
        <category: 'tree walking'>
        ^aTermCollection
            detect: [:t |
                t package = aName
                    and: [t isPositive = aBoolean
                        and: [t constraint = aConstraint]]]
            ifNone: [nil]
    ]
]

Object subclass: FetchTrapSnapshot [
    | inner |

    <comment: 'S17 snapshot test-double: delegates the three metadata
messages to a real IndexSnapshot but signals an error on any
fetch:version:-shaped access, proving resolution never touches the
archive path (the metadata/archive split).'>

    FetchTrapSnapshot class >> around: aSnapshot [
        <category: 'instance creation'>
        ^self new setInner: aSnapshot
    ]

    setInner: aSnapshot [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        inner := aSnapshot
    ]

    versionsOf: aPackageName [
        <category: 'snapshot protocol'>
        ^inner versionsOf: aPackageName
    ]

    dependenciesOf: aPackageName version: aVersion [
        <category: 'snapshot protocol'>
        ^inner dependenciesOf: aPackageName version: aVersion
    ]

    sha256For: aPackageName version: aVersion [
        <category: 'snapshot protocol'>
        ^inner sha256For: aPackageName version: aVersion
    ]

    fetch: aPackageName version: aVersion [
        <category: 'trap'>
        ^self error: 'metadata/archive split violated: ',
            'resolution touched the fetch path for ', aPackageName
    ]
]

Namespace current: Smalltalk.
