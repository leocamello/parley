"Parley — ApplicationManifest: the immutable manifest+lock association.
 Spec: docs/design/manifest-and-serialization.md §4; issue #5 S7.
 A LibraryManifest plus the application's lockfile association (a
 Resolution) — the Bundler Gemfile/gemspec lesson: applications commit
 lockfiles; libraries never ship pins as constraints. Read-only manifest
 accessors delegate to the underlying LibraryManifest."

Namespace current: Parley.

Object subclass: ApplicationManifest [
    | manifest lock |

    <comment: 'An immutable value associating a LibraryManifest with its
lock (a Resolution), or with no lock yet. Class-side construction only;
the manifest read surface delegates to the underlying LibraryManifest.'>

    ApplicationManifest class >> manifest: aLibraryManifest lock: aResolution [
        "An application manifest whose lock is aResolution."
        <category: 'instance creation'>
        ^self new setManifest: aLibraryManifest lock: aResolution
    ]

    ApplicationManifest class >> manifest: aLibraryManifest [
        "An application manifest with no lock yet."
        <category: 'instance creation'>
        ^self new setManifest: aLibraryManifest lock: nil
    ]

    setManifest: aLibraryManifest lock: aResolutionOrNil [
        "Private — initialization from the class-side constructors."
        <category: 'private'>
        manifest := aLibraryManifest.
        lock := aResolutionOrNil
    ]

    manifest [
        "The underlying LibraryManifest."
        <category: 'accessing'>
        ^manifest
    ]

    lock [
        "The application's lock Resolution, or nil when none."
        <category: 'accessing'>
        ^lock
    ]

    hasLock [
        <category: 'testing'>
        ^lock notNil
    ]

    "---- delegating read-only manifest accessors ----"

    name [
        <category: 'accessing'>
        ^manifest name
    ]

    version [
        <category: 'accessing'>
        ^manifest version
    ]

    summary [
        <category: 'accessing'>
        ^manifest summary
    ]

    author [
        <category: 'accessing'>
        ^manifest author
    ]

    license [
        <category: 'accessing'>
        ^manifest license
    ]

    fileIns [
        "The declared load order, preserved exactly — never sorted."
        <category: 'accessing'>
        ^manifest fileIns
    ]

    dependencies [
        <category: 'accessing'>
        ^manifest dependencies
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream
            nextPutAll: 'ApplicationManifest(';
            nextPutAll: manifest name;
            nextPut: Character space;
            print: manifest version;
            nextPutAll: (self hasLock ifTrue: [', locked'] ifFalse: [', no lock']);
            nextPut: $)
    ]
]

Namespace current: Smalltalk.
