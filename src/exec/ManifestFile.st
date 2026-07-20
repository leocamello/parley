"Parley — ManifestFile: loading the developer's OWN Package.st.
 Spec: docs/design/execution-and-cli.md §3; §8 decision 19; issue #8
 S8/S9.
 load: clears the recorded manifest, files the path in with the
 Parley namespace current — inside the namespace the token Parley
 resolves to the Parley.Parley gateway (issue #3), so the Doc B §2
 authoring syntax works verbatim — and answers the manifest recorded
 by define:. A file that recorded nothing signals one ManifestError
 whose single problem names the path (wording pinned in RED).
 All recording state lives here; the gateway's sole change is the
 declared one-send exception (ManifestFile record: before answering).
 Trust boundary unchanged (architecture §2.2): only the root
 application's own manifest — the file its author owns and runs — is
 ever loaded this way; third-party Package.st files are never
 evaluated by anything, and third-party bytes never reach this class."

Namespace current: Parley.

Object subclass: ManifestFile [

    <comment: 'The decision-19 resolution: files the owner''s own
Package.st in with the Parley namespace current and answers the
LibraryManifest the file''s define: recorded. Holds the recording as
class-side state, cleared per load; a define-less file is a
one-problem ManifestError naming the path.'>

    ManifestFile class [ | recorded | ]

    ManifestFile class >> record: aManifest [
        "Remember the manifest a define: just built — the one send the
         Parley.Parley gateway makes before answering (the declared
         settled-class exception, Doc E §3)."
        <category: 'recording'>
        recorded := aManifest
    ]

    ManifestFile class >> load: aPath [
        "File the developer's own Package.st at aPath in with the
         Parley namespace current and answer the recorded manifest.
         Signals one ManifestError naming the path when the file never
         sent define:."
        <category: 'loading'>
        | previous |
        recorded := nil.
        previous := Namespace current.
        [Namespace current: (Smalltalk at: #Parley).
         FileStream fileIn: aPath]
            ensure: [Namespace current: previous].
        recorded isNil ifTrue: [
            ^ManifestError signalProblems: (Array with:
                aPath, ': no manifest defined - the file never sent Parley define:')].
        ^recorded
    ]
]

Namespace current: Smalltalk.
