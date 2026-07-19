"Parley — ManifestBuilder: the one sanctioned mutable object, an edge
 object (airlock) in front of the immutable domain. Vocabulary messages
 record raw strings only; build performs one batch-validation pass and
 answers an immutable LibraryManifest or signals one ManifestError.
 Spec: docs/design/manifest-and-serialization.md §3."

Namespace current: Parley.

Object subclass: ManifestBuilder [
    | name version summary author license fileIns dependencies |

    <comment: 'Accumulates raw Package.st declarations for the duration of
one Parley define: evaluation. The DSL vocabulary is the set of explicit
methods in the manifest vocabulary category; doesNotUnderstand: is the
error path only. All parsing and validation happens in build.'>

    ManifestBuilder class >> new [
        <category: 'instance creation'>
        ^super new initBuilder
    ]

    ManifestBuilder class >> vocabulary [
        "The DSL vocabulary, reflected from the actual methods in the
         'manifest vocabulary' category so the list cannot drift."
        <category: 'accessing'>
        ^(self selectors select: [:sel |
            (self compiledMethodAt: sel) methodCategory asString
                = 'manifest vocabulary'])
            asSortedCollection asArray
    ]

    initBuilder [
        "Private — fresh accumulation state."
        <category: 'private'>
        summary := ''.
        author := ''.
        license := ''.
        dependencies := OrderedCollection new
    ]

    "---- the manifest vocabulary (explicit methods; never DNU) ----"

    name: aString [
        "Declare the package name (required): lowercase letters, digits
         and hyphens, starting with a letter. Validated at build."
        <category: 'manifest vocabulary'>
        name := aString
    ]

    version: aString [
        "Declare the package version (required); parsed via
         Version fromString: at build."
        <category: 'manifest vocabulary'>
        version := aString
    ]

    summary: aString [
        "Declare a one-line description (optional)."
        <category: 'manifest vocabulary'>
        summary := aString
    ]

    author: aString [
        "Declare the author (optional)."
        <category: 'manifest vocabulary'>
        author := aString
    ]

    license: aString [
        "Declare the license identifier (optional)."
        <category: 'manifest vocabulary'>
        license := aString
    ]

    fileIns: anArray [
        "Declare the .st files to load (required, non-empty). Order is
         semantic: it is the gst-package load order and is preserved
         exactly, never sorted."
        <category: 'manifest vocabulary'>
        fileIns := anArray
    ]

    dependency: aName constraint: aConstraintString [
        "Declare a dependency on aName under the constraint grammar in
         aConstraintString; parsed via VersionConstraint fromString: at
         build."
        <category: 'manifest vocabulary'>
        dependencies add: aName -> aConstraintString
    ]

    dependency: aName [
        "Declare an unconstrained dependency on aName — sugar for the
         constraint '*'."
        <category: 'manifest vocabulary'>
        dependencies add: aName -> '*'
    ]

    "---- the error path ----"

    doesNotUnderstand: aMessage [
        "Unknown DSL words answer a rich, inspectable vocabulary error;
         vocabulary itself is never implemented here."
        <category: 'error handling'>
        ^ManifestVocabularyError
            signalUnknown: aMessage selector
            vocabulary: self class vocabulary
    ]

    "---- build: one batch-validation pass ----"

    build [
        "Validate every declaration in one pass; signal a single
         ManifestError carrying ALL problems, or answer an immutable
         LibraryManifest."
        <category: 'building'>
        | problems parsedVersion deps seen |
        problems := OrderedCollection new.
        name isNil
            ifTrue: [problems add: 'missing required field name']
            ifFalse: [
                (self isValidPackageName: name) ifFalse: [
                    problems add: 'invalid package name ', name printString,
                        ': expected lowercase letters, digits and hyphens,',
                        ' starting with a letter']].
        version isNil
            ifTrue: [problems add: 'missing required field version']
            ifFalse: [
                [parsedVersion := Version fromString: version]
                    on: VersionFormatError
                    do: [:e |
                        problems add: 'invalid version ', version printString.
                        e return: nil]].
        (fileIns isNil or: [fileIns isEmpty])
            ifTrue: [problems add:
                'fileIns must declare at least one file to load'].
        deps := OrderedCollection new.
        seen := Set new.
        dependencies do: [:pair |
            | depName parsed |
            depName := pair key.
            (seen includes: depName)
                ifTrue: [problems add:
                    'duplicate dependency ', depName printString]
                ifFalse: [seen add: depName].
            depName = name ifTrue: [
                problems add: 'package ', name printString,
                    ' cannot depend on itself'].
            [parsed := VersionConstraint fromString: pair value]
                on: ConstraintFormatError
                do: [:e |
                    problems add: 'invalid constraint ',
                        pair value printString, ' for dependency ',
                        depName printString.
                    e return: nil].
            parsed notNil ifTrue: [
                deps add: (Dependency name: depName constraint: parsed)]].
        problems isEmpty ifFalse: [^ManifestError signalProblems: problems].
        ^LibraryManifest
            name: name
            version: parsedVersion
            summary: summary
            author: author
            license: license
            fileIns: fileIns asArray copy
            dependencies: deps asArray
    ]

    isValidPackageName: aString [
        "Private — lowercase letters, digits, hyphens; starts with a
         letter."
        <category: 'private'>
        aString isEmpty ifTrue: [^false].
        ((aString at: 1) between: $a and: $z) ifFalse: [^false].
        aString do: [:ch |
            ((ch between: $a and: $z)
                or: [ch isDigit or: [ch = $-]]) ifFalse: [^false]].
        ^true
    ]
]

Namespace current: Smalltalk.
