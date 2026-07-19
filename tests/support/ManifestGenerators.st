"Parley Sprint 1 — seeded random manifest generators for the law suites.

 Extends the Sprint 0 DomainGenerators (same Park-Miller LCG, same
 PARLEY_SEED contract) with random-but-valid package names, optional
 texts (including embedded quotes, parens and hashes to stress the
 micro-format escaping), fileIns lists, dependency sets, and whole
 manifests built through ManifestBuilder."

Namespace current: Parley.

DomainGenerators subclass: ManifestGenerators [

    <comment: 'Seeded pseudo-random generators for manifest test data:
valid package names, optional description texts, fileIns arrays, unique
dependency sets, and complete LibraryManifests built via ManifestBuilder.
Deterministic under a fixed seed.'>

    nextName [
        "A random valid package name: starts with a lowercase letter;
         lowercase letters, digits and hyphens afterwards."
        | first tail out |
        first := 'abcdefghijklmnopqrstuvwxyz'.
        tail := 'abcdefghijklmnopqrstuvwxyz0123456789-'.
        out := WriteStream on: String new.
        out nextPut: (first at: (self nextInteger: first size) + 1).
        1 to: (self nextInteger: 7) do: [:i |
            out nextPut: (tail at: (self nextInteger: tail size) + 1)].
        ^out contents
    ]

    nextText [
        "A random free text (summary/author/license) drawing from an
         alphabet that includes quotes, parens, hashes and spaces so the
         writer's escaping and the reader's string scanning are stressed."
        | chars out |
        chars := 'abcdefgh XYZ()#0123456789-.' , (String with: $').
        out := WriteStream on: String new.
        1 to: (self nextInteger: 20) + 1 do: [:i |
            out nextPut: (chars at: (self nextInteger: chars size) + 1)].
        ^out contents
    ]

    nextFileIns [
        "A random non-empty fileIns array; order is semantic and must be
         preserved by everything downstream."
        | n |
        n := (self nextInteger: 4) + 1.
        ^(1 to: n) asArray collect: [:i |
            'File' , i printString , '-' ,
                (self nextInteger: 10) printString , '.st']
    ]

    nextConstraintString [
        "The wire form of a random constraint from the Sprint 0 algebra
         generator; fromString: accepts everything printOn: emits."
        ^self nextConstraint printString
    ]

    nextDependencyNames: count excluding: aPackageName [
        "Up to count distinct dependency names, none equal to the package
         name. Bounded retry keeps the sequence deterministic."
        | names guard candidate |
        names := OrderedCollection new.
        guard := 0.
        [names size < count and: [guard < 100]] whileTrue: [
            guard := guard + 1.
            candidate := self nextName.
            (candidate = aPackageName or: [names includes: candidate])
                ifFalse: [names add: candidate]].
        ^names
    ]

    nextManifest [
        "A complete random valid LibraryManifest built through
         ManifestBuilder (the same funnel Parley define: uses)."
        | builder pkgName depCount |
        builder := ManifestBuilder new.
        pkgName := self nextName.
        builder name: pkgName.
        builder version: self nextVersion printString.
        self nextBoolean ifTrue: [builder summary: self nextText].
        self nextBoolean ifTrue: [builder author: self nextText].
        self nextBoolean ifTrue: [builder license: self nextText].
        builder fileIns: self nextFileIns.
        depCount := self nextInteger: 4.
        (self nextDependencyNames: depCount excluding: pkgName)
            do: [:depName |
                self nextBoolean
                    ifTrue: [builder dependency: depName
                                constraint: self nextConstraintString]
                    ifFalse: [builder dependency: depName]].
        ^builder build
    ]
]

Namespace current: Smalltalk.
