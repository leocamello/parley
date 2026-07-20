"Parley — InstalledSet: the immutable product of a clean install pass.
 Spec: docs/design/installer.md §4; issue #7 S12, S15.
 One (package name, Version, sha256, store path) tuple per resolved
 package, in sorted package-name order. Carries NO value equality
 (=/hash) — the decision-23 precedent; consumers compare tuple fields.
 registrationCommandsFor: composes the registration plan as pure
 string values — executed only by Sprint 6's ExecutionScope; nothing
 here touches the filesystem or spawns a process."

Namespace current: Parley.

Object subclass: InstalledSet [
    | tuples |

    <comment: 'The immutable install product: package name -> (Version,
sha256, store path). Answers the tuple fields and the registration
plan — one gst-package command line per package, in sorted name order,
as pure values. Class-side construction; no value equality.'>

    InstalledSet class >> tuples: aDictionary [
        "aDictionary maps a package name to an Array of
         {Version. sha256 String. store path String}."
        <category: 'instance creation'>
        ^self new setTuples: aDictionary
    ]

    setTuples: aDictionary [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        tuples := aDictionary
    ]

    packageNames [
        "All installed package names, sorted by name."
        <category: 'accessing'>
        ^tuples keys asSortedCollection asArray
    ]

    versionOf: aName [
        <category: 'accessing'>
        ^(tuples at: aName) at: 1
    ]

    sha256For: aName [
        <category: 'accessing'>
        ^(tuples at: aName) at: 2
    ]

    pathFor: aName [
        "The package archive's content-addressed store path."
        <category: 'accessing'>
        ^(tuples at: aName) at: 3
    ]

    registrationCommandsFor: aTargetDir [
        "The registration plan: one command line per package in sorted
         name order, each exactly
         'gst-package --install --target-directory <aTargetDir> <store
         path>' — a pure formatting value, executed by Sprint 6's
         ExecutionScope, never here."
        <category: 'registration plan'>
        ^self packageNames collect: [:name |
            'gst-package --install --target-directory ', aTargetDir,
                ' ', (self pathFor: name)]
    ]
]

Namespace current: Smalltalk.
