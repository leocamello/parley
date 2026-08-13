"Parley — PathDependency: an immutable (name, declared path) pair.
 Spec: docs/design/manifest-and-serialization.md §2/§3.2/§4;
 docs/design/resolver.md §1.3; §8 decisions 68 and 69. Sprint 21.

 THE PATH IS THE AUTHOR'S DECLARED STRING AND IS NEVER EXPANDED HERE.
 A lock travels with its checkout, so it must carry '../kernel-text'
 and not one machine's absolute expansion (§8 decision 69), and the
 declared string is what every diagnosis names. Resolution against the
 manifest's directory happens where the path is USED — never at
 construction, and never at build (Doc B §3.4 records it raw).

 IT IS A VALUE WITH NO VALUE EQUALITY, the decision-23 precedent: no
 law compares two of these, and adding =/hash would be API nobody
 asked for. Sibling of Dependency, deliberately NOT a subclass of it:
 a path dependency has no VersionConstraint at all — its version is
 whatever the sibling declares — so satisfiedBy: would have no honest
 answer, and inheriting it would be a kind-check waiting to happen."

Namespace current: Parley.

Object subclass: PathDependency [
    | name path |

    <comment: 'An immutable path-dependency declaration: a package name
and the path string its author wrote, byte for byte. Class-side
construction only; read-only accessors; no value equality.'>

    PathDependency class >> name: aName path: aPathString [
        "Answer a path dependency on the package named aName supplied by
         the directory aPathString names, relative to the declaring
         manifest's own directory."
        <category: 'instance creation'>
        ^self new setName: aName path: aPathString
    ]

    setName: aName path: aPathString [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        name := aName.
        path := aPathString
    ]

    name [
        <category: 'accessing'>
        ^name
    ]

    path [
        "The author's declared path string, exactly as written."
        <category: 'accessing'>
        ^path
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream
            nextPutAll: 'PathDependency(';
            nextPutAll: name;
            nextPutAll: ' -> ';
            print: path;
            nextPut: $)
    ]
]

Namespace current: Smalltalk.
