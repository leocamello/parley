"Parley — Dependency: an immutable (name, VersionConstraint) pair.
 Spec: docs/design/manifest-and-serialization.md §4; issue #3 S3.
 Satisfaction delegates to the constraint algebra's allows:."

Namespace current: Parley.

Object subclass: Dependency [
    | name constraint |

    <comment: 'An immutable dependency declaration: a package name and the
VersionConstraint it must satisfy. Class-side construction only;
satisfiedBy: delegates to the constraint algebra.'>

    Dependency class >> name: aName constraint: aConstraint [
        "Answer a dependency on the package named aName under
         aConstraint (a VersionConstraint)."
        <category: 'instance creation'>
        ^self new setName: aName constraint: aConstraint
    ]

    setName: aName constraint: aConstraint [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        name := aName.
        constraint := aConstraint
    ]

    name [
        <category: 'accessing'>
        ^name
    ]

    constraint [
        <category: 'accessing'>
        ^constraint
    ]

    satisfiedBy: aVersion [
        "True when aVersion lies inside the constraint's version set."
        <category: 'testing'>
        ^constraint allows: aVersion
    ]

    = aDependency [
        <category: 'comparing'>
        ^(aDependency isKindOf: Dependency)
            and: [name = aDependency name
                and: [constraint = aDependency constraint]]
    ]

    hash [
        <category: 'comparing'>
        ^name hash * 31 + constraint hash
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream
            nextPutAll: name;
            nextPutAll: ' (';
            print: constraint;
            nextPut: $)
    ]
]

Namespace current: Smalltalk.
