"Parley — ManifestBuilder: the one sanctioned mutable object, an edge
 object (airlock) in front of the immutable domain. Vocabulary messages
 record raw strings only; build performs one batch-validation pass and
 answers an immutable LibraryManifest or signals one ManifestError.
 Spec: docs/design/manifest-and-serialization.md §3."

Namespace current: Parley.

Object subclass: ManifestBuilder [
    | name version summary author license fileIns dependencies
      pathDependencies devDependencies |

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
        dependencies := OrderedCollection new.
        pathDependencies := OrderedCollection new.
        devDependencies := OrderedCollection new
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

    dependency: aName path: aPathString [
        "Declare a PATH dependency on aName, supplied by the directory
         aPathString names relative to this manifest's own directory —
         the package you are developing beside this one (Sprint 21, §8
         decisions 68 and 69).

         Root-manifest-only vocabulary: it is NEVER serialized into an
         index entry, so a published release can never declare one and
         publish refuses a manifest that does. The path is recorded RAW,
         exactly as written: a lock travels with its checkout, so it
         must carry the author's '../kernel-text' and not one machine's
         expansion. Whether the directory exists is not this cascade's
         question — that is diagnosed where the path is used."
        <category: 'manifest vocabulary'>
        pathDependencies add: aName -> aPathString
    ]

    devDependency: aName constraint: aConstraintString [
        "Declare a DEVELOPMENT dependency on aName under the constraint
         grammar in aConstraintString — resolved and installed for THIS
         manifest alone (Sprint 21, §8 decision 69).

         Root-manifest-only vocabulary: it is never serialized into an
         index entry, so a consumer of a published package receives no
         dev dependency of its author's, and a sibling's dev
         dependencies are excluded from its overlay record exactly as
         publish would exclude them. The constraint is parsed at build,
         like every other."
        <category: 'manifest vocabulary'>
        devDependencies add: aName -> aConstraintString
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
        | problems parsedVersion deps paths devs seen |
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
        paths := OrderedCollection new.
        devs := OrderedCollection new.
        "THE DUPLICATE AND SELF RULES QUANTIFY OVER ALL THREE DECLARED
         KINDS TOGETHER (Doc B §3.4 item 5, Sprint 21), which is what
         the ONE shared seen set is: all three end up as pins in one
         lock, so a name claimed twice is a project that cannot say
         which declaration it meant. A rule enforced within each
         collection separately would pass every single-kind fixture."
        seen := Set new.
        dependencies do: [:pair |
            | parsed |
            self checkName: pair key seen: seen problems: problems.
            parsed := self constraintOf: pair problems: problems.
            parsed notNil ifTrue: [
                deps add: (Dependency name: pair key constraint: parsed)]].
        pathDependencies do: [:pair |
            self checkName: pair key seen: seen problems: problems.
            (self isNonEmptyString: pair value)
                ifTrue: [paths add:
                    (PathDependency name: pair key path: pair value)]
                ifFalse: [problems add: 'invalid path ',
                    pair value printString, ' for dependency ',
                    pair key printString]].
        devDependencies do: [:pair |
            | parsed |
            self checkName: pair key seen: seen problems: problems.
            parsed := self constraintOf: pair problems: problems.
            parsed notNil ifTrue: [
                devs add: (Dependency name: pair key constraint: parsed)]].
        problems isEmpty ifFalse: [^ManifestError signalProblems: problems].
        ^LibraryManifest
            name: name
            version: parsedVersion
            summary: summary
            author: author
            license: license
            fileIns: fileIns asArray copy
            dependencies: deps asArray
            paths: paths asArray
            dev: devs asArray
    ]

    checkName: aName seen: aSeenSet problems: aProblemCollection [
        "Private — the duplicate and self-dependency rules, applied to
         one declared name whatever kind declared it. Extracted so the
         three loops consume ONE definition of both sentences: two
         copies of a settled wording is the drift §8 decision 28's rule
         exists to prevent, and the sentences themselves are unchanged."
        <category: 'private'>
        (aSeenSet includes: aName)
            ifTrue: [aProblemCollection add:
                'duplicate dependency ', aName printString]
            ifFalse: [aSeenSet add: aName].
        aName = name ifTrue: [
            aProblemCollection add: 'package ', name printString,
                ' cannot depend on itself']
    ]

    constraintOf: aPair problems: aProblemCollection [
        "Private — the settled constraint parse and its settled problem
         sentence, extracted so index and dev dependencies consume one
         definition (Doc B §3.4 item 4: dev dependencies included).
         Answers nil when the constraint does not parse."
        <category: 'private'>
        ^[VersionConstraint fromString: aPair value]
            on: ConstraintFormatError
            do: [:e |
                aProblemCollection add: 'invalid constraint ',
                    aPair value printString, ' for dependency ',
                    aPair key printString.
                e return: nil]
    ]

    isNonEmptyString: aValue [
        "Private — Doc B §3.4 item 6. Existence is NOT this pass's
         question: a path is recorded raw and a missing or unreadable
         sibling is diagnosed where the path is used, naming it. What
         this asks is only whether the declaration describes anything
         at all."
        <category: 'private'>
        ^(aValue isKindOf: String) and: [aValue isEmpty not]
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
