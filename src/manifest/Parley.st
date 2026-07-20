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

    Parley class >> define: aBlock [
        "Evaluate aBlock with a fresh ManifestBuilder and answer the
         immutable LibraryManifest built from its declarations. The
         manifest is recorded with ManifestFile before answering — the
         declared Sprint 6 one-send exception (Doc E §3, issue #8)."
        <category: 'manifest authoring'>
        | builder manifest |
        builder := ManifestBuilder new.
        aBlock value: builder.
        manifest := builder build.
        ManifestFile record: manifest.
        ^manifest
    ]
]

Namespace current: Smalltalk.
