"Parley — IndexEntryWriter: canonical, byte-stable rendering of the
 #'parley-index' 1 literal micro-format.
 Spec: docs/design/manifest-and-serialization.md §5.2, §5.4, §6.
 Fixed key order, all keys always present; dependencies sorted by name;
 fileIns order preserved exactly; constraints and versions rendered via
 their canonical printString; single spaces, no trailing whitespace,
 single trailing newline."

Namespace current: Parley.

Object subclass: IndexEntryWriter [

    <comment: 'Renders a LibraryManifest as one canonical literal array in
the #''parley-index'' format 1 schema. Byte-stable: the same manifest
always yields the identical byte sequence.'>

    IndexEntryWriter class >> write: aManifest on: aStream [
        "Write the canonical index entry for aManifest to aStream,
         applying the §5.4 rendering rules exactly. The unpublished
         form: #archive #() — nothing has been built yet."
        <category: 'writing'>
        self writeHeadOf: aManifest on: aStream.
        aStream nextPutAll: ') #archive #())'.
        aStream nextPut: Character nl
    ]

    IndexEntryWriter class >> write: aManifest archive: aFileName sha256: aHexDigest on: aStream [
        "Write the PUBLISHED index entry for aManifest to aStream
         (Doc F §2): identical §5.2 canonical rendering to write:on:,
         except #archive names the landed archive and carries its
         digest. The digest is opaque here — the Publisher computes it
         through the settled Sha256 over the archive's real bytes."
        <category: 'writing'>
        self writeHeadOf: aManifest on: aStream.
        aStream nextPutAll: ') #archive #('.
        self string: aFileName on: aStream.
        aStream nextPutAll: ' #sha256 '.
        self string: aHexDigest on: aStream.
        aStream nextPutAll: '))'.
        aStream nextPut: Character nl
    ]

    IndexEntryWriter class >> writeHeadOf: aManifest on: aStream [
        "Private — the format tag through the last dependency element:
         everything the two index renderings share, byte for byte. The
         caller appends its #archive field and closes the artifact.
         Extracted so the published and unpublished forms cannot drift
         apart — byte-identity of write:on: is the invariant."
        <category: 'private'>
        aStream nextPutAll: '#(#''parley-index'' 1'.
        self key: #name string: aManifest name on: aStream.
        self key: #version string: aManifest version printString on: aStream.
        self key: #summary string: aManifest summary on: aStream.
        self key: #author string: aManifest author on: aStream.
        self key: #license string: aManifest license on: aStream.
        aStream nextPutAll: ' #fileIns #('.
        aManifest fileIns
            do: [:file | self string: file on: aStream]
            separatedBy: [aStream nextPut: Character space].
        aStream nextPutAll: ') #dependencies #('.
        (aManifest dependencies asSortedCollection: [:a :b | a name <= b name])
            do: [:dep |
                aStream nextPutAll: '#('.
                self string: dep name on: aStream.
                aStream nextPut: Character space.
                self string: dep constraint printString on: aStream.
                aStream nextPut: $)]
            separatedBy: [aStream nextPut: Character space]
    ]

    IndexEntryWriter class >> writeLock: aResolution on: aStream [
        "Write the canonical lockfile for aResolution to aStream:
         #'parley-lock' 1, the root manifest name, then the resolved
         packages sorted by name, each with its three-component version
         and sha256 — single-line, single trailing newline (§5.3-5.4)."
        <category: 'writing'>
        aStream nextPutAll: '#(#''parley-lock'' 1'.
        self key: #root string: aResolution rootName on: aStream.
        aStream nextPutAll: ' #packages #('.
        aResolution packageNames
            do: [:name |
                | declared |
                aStream nextPutAll: '#('.
                self string: name on: aStream.
                aStream nextPut: Character space.
                self string: (aResolution versionOf: name) printString
                    on: aStream.
                "ONE DECLARED ALTERNATIVE FORM BESIDE THE SETTLED ONE
                 (Doc B §5.3, Sprint 21): a pin no index supplied
                 records its PROVENANCE instead of a digest, as
                 #(<name> <version> #path '<declared path>'). The path
                 is the author's declared string byte for byte — a lock
                 travels with its checkout, so it must never carry one
                 machine's expansion — and a resolution with no path
                 pins renders bytes IDENTICAL to what Sprint 20 wrote,
                 because this branch is never taken for one."
                declared := aResolution provenanceOf: name.
                declared isNil
                    ifTrue: [
                        aStream nextPutAll: ' #sha256 '.
                        self string: (aResolution sha256Of: name)
                            on: aStream]
                    ifFalse: [
                        aStream nextPutAll: ' #path '.
                        self string: declared on: aStream].
                aStream nextPut: $)]
            separatedBy: [aStream nextPut: Character space].
        aStream nextPutAll: '))'.
        aStream nextPut: Character nl
    ]

    IndexEntryWriter class >> key: aSymbol string: aString on: aStream [
        "Private — one ' #key ''value''' pair."
        <category: 'private'>
        aStream nextPutAll: ' #'; nextPutAll: aSymbol.
        aStream nextPut: Character space.
        self string: aString on: aStream
    ]

    IndexEntryWriter class >> string: aString on: aStream [
        "Private — a quoted string literal, doubling embedded quotes."
        <category: 'private'>
        aStream nextPut: $'.
        aString do: [:ch |
            ch = $' ifTrue: [aStream nextPut: $'].
            aStream nextPut: ch].
        aStream nextPut: $'
    ]
]

Namespace current: Smalltalk.
