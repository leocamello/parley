"Sprint 25 / issue #27: independent lock-guard data and wording oracles.
 The tuples supplied here are trusted test values, never third-party code.
 File setup reuses the settled helpers; no fixture spawns a process."

Namespace current: Parley.

Object subclass: LockedPinFixtures [

    <comment: 'Trusted Resolution builders and literal refusal oracles
for the complete persisted-lock comparison. No production comparator or
writer constructs the expected diagnosis.'>

    LockedPinFixtures class >> digestA [
        <category: 'data'>
        ^'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ]

    LockedPinFixtures class >> digestB [
        <category: 'data'>
        ^'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    ]

    LockedPinFixtures class >> resolutionRoot: aRootName tuples: someTuples [
        "Each trusted row is (name version provenance-kind payload).
         This builds inputs, not expected output: lock-byte oracles are
         literal strings and refusal oracles are independent below."
        <category: 'values'>
        | triples paths |
        triples := Dictionary new.
        paths := Dictionary new.
        someTuples do: [:row |
            (row at: 3) = #path
                ifTrue: [
                    triples at: (row at: 1) put: (Array
                        with: (Version fromString: (row at: 2)) with: '').
                    paths at: (row at: 1) put: (row at: 4)]
                ifFalse: [
                    triples at: (row at: 1) put: (Array
                        with: (Version fromString: (row at: 2))
                        with: (row at: 4))]].
        ^(Resolution root: aRootName triples: triples) withPaths: paths
    ]

    LockedPinFixtures class >> lockTextRoot: aName packages: aTupleText [
        <category: 'lock oracles'>
        ^PathDepFixtures lockTextRoot: aName packages: aTupleText
    ]

    LockedPinFixtures class >> provenanceRefusalFor: aName pinned: aPinnedDescription would: aWouldDescription [
        <category: 'wording oracles'>
        ^'--locked forbids changing parley.lock - ', aName printString,
            ' changes provenance from ', aPinnedDescription,
            ' to ', aWouldDescription, ', and nothing was written'
    ]

    LockedPinFixtures class >> rootRefusalFrom: anOldName to: aNewName [
        <category: 'wording oracles'>
        ^'--locked forbids changing parley.lock - root would change from ',
            anOldName printString, ' to ', aNewName printString,
            ', and nothing was written'
    ]

    LockedPinFixtures class >> missingLockedFileText [
        <category: 'wording oracles'>
        ^'--locked requires an existing parley.lock - run parley resolve without --locked to create it'
    ]
]

Namespace current: Smalltalk.
