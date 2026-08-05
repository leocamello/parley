"Parley — the manifest authoring entry point.
 Spec: docs/design/manifest-and-serialization.md §2.

 On GNU Smalltalk 3.2.5 the global 'Parley' is the namespace object, and
 namespaces treat unknown keyword sends as binding setters — they cannot
 host define: without a kernel extension. This class, named Parley and
 living INSIDE the Parley namespace, shadows the namespace binding
 wherever the Parley namespace is current, so 'Parley define: [:pkg |
 ...]' reads exactly as Doc B §2 writes it. At raw Smalltalk top level
 the token still names the namespace; the author-facing evaluation path
 (Phase 3 tooling) files Package.st in with the Parley namespace current.
 Decision recorded on issue #3."

Namespace current: Parley.

Object subclass: Parley [

    <comment: 'The Package.st authoring entry point: a thin gateway that
creates a fresh ManifestBuilder, evaluates the author''s one-argument
block with it, and answers the built immutable manifest. Shadows the
Parley namespace binding inside the namespace itself (issue #3).'>

    Parley class >> version [
        "THE version of Parley, defined exactly once (issue #17 S13).

         It is the first thing every bug report needs, and a version
         that can drift between the constant and what the tool prints
         drifts precisely when it matters. So parley --version composes
         its line from this method and no law compares that line
         against a second literal.

         It lives on the authoring gateway because that is the one
         class every path already reaches — the wrapper, the CLI and a
         filed-in Package.st alike — and inventing a class to hold one
         string would be a manager object with a single field.

         1.0.0 is the release this sprint completes: v1.0 is the
         complete, honest, local-and-git package manager whose client
         already speaks the registry protocol, and it ships when the
         code is done rather than when a service is."
        <category: 'release'>
        ^'1.0.0'
    ]

    Parley class >> define: aBlock [
        "Evaluate aBlock with a fresh ManifestBuilder and answer the
         immutable LibraryManifest built from its declarations. The
         manifest is recorded with ManifestFile before answering — the
         declared Sprint 6 one-send exception (Doc E §3, issue #8).

         THE AUTHORING-ERROR BOUNDARY (Doc E §3, Sprint 9 — the declared
         settled-class exception on this gateway, granted at the RED
         review; §8 decision 34). An error raised inside a filed-in
         Package.st cannot be caught around the file-in: the doit
         context of a filed-in statement is PARENTLESS (verified against
         3.2.5 — thisContext parentContext answers
         UndefinedObject>>__terminate, not the caller of fileIn:), so a
         handler in ManifestFile is not in the signaling chain and never
         fires. gst prints its own backtrace and abandons the statement,
         after which load: reports 'no manifest defined' about a file
         that did send define: — a confident wrong sentence preceded by
         a dump. This method is the ONE Parley frame a filed-in
         Package.st enters, so the boundary lives here.

         It captures and answers nil; ManifestFile signals from its own
         frame, where a handler is real. Classification is by HANDLING —
         two on:do: handlers, never an isKindOf: chain — so each arm
         carries exactly what its error knows: the vocabulary error's
         message text, or the builder's whole problem batch.

         It captures ONLY while a ManifestFile load is in progress —
         that is the one context whose signaling chain is cut. A live
         Parley define: in an image or a test signals to its own caller
         exactly as it always has (the Sprint 1 laws are that contract),
         so anywhere else the boundary passes the error on untouched."
        <category: 'manifest authoring'>
        ^[[self manifestFrom: aBlock]
            on: ManifestVocabularyError
            do: [:e | self capture: (Array with: e messageText) or: e]]
            on: ManifestError
            do: [:e | self capture: e problems or: e]
    ]

    Parley class >> capture: aCollection or: anError [
        "Private — the authoring boundary's one decision: inside a
         ManifestFile load, hand the problems over and answer nil so the
         filed-in statement ends quietly and load: can signal them from
         a frame that has handlers; anywhere else, PASS the error on
         untouched. Nothing about the error's text changes on either
         path — only who is told about it."
        <category: 'private'>
        ManifestFile isLoading ifFalse: [^anError pass].
        ManifestFile recordAuthoringProblems: aCollection.
        ^nil
    ]

    Parley class >> manifestFrom: aBlock [
        "Private — the settled pipeline: a fresh builder, the author's
         block, build, and the Sprint 6 recording send. Unchanged; it
         moved into its own method only so the boundary above can wrap
         it."
        <category: 'private'>
        | builder manifest |
        builder := ManifestBuilder new.
        aBlock value: builder.
        manifest := builder build.
        ManifestFile record: manifest.
        ^manifest
    ]
]

Namespace current: Smalltalk.
