"Parley Sprint 13 - the manifest editor's own laws (issue #15;
 Doc B §2.1, §8 decision 49).

 IN MEMORY, WITH NO FILE I/O AT ALL. ManifestEditor is given text and
 answers text or a refusal: it opens no file, knows nothing of locks,
 sources or verbs, and mutates nothing - so every law here is a pure
 value assertion and this file touches neither tmp/ nor a process. That
 is not incidental tidiness. Everything about add that is RISKY -
 writing, verifying, rolling back - lives in the CLI, where the
 atomicity contract lives; had the editor also owned the file, the
 rollback law would have had to reach through it.

 BYTE PRESERVATION IS COMPARED, NEVER INFERRED. Every insertion law
 asserts the answered text against a hand-written expected literal AND,
 separately, line by line against the original. The weak forms all pass
 on an editor that silently reflowed the file: `the text got longer`,
 `the text still contains name:`, `the manifest has three
 dependencies`. The line-by-line form is what actually catches a
 re-render, because a re-render changes lines that had no business
 changing.

 THE AUTHORED FILE IS THE POINT (Doc B §2.1). A ManifestBuilder
 round-trip - load the manifest, re-render the file - passes the
 init-template and already-declaring laws and destroys
 testTheAuthorsCommentsBlankLineAndIndentationSurvive. That law is
 written comment by comment and line by line for exactly that reason:
 `the result still parses` and `the result loads to the same manifest`
 are both TRUE of the disqualified design.

 THE REFUSAL IS HALF THE FEATURE. Six shapes are refused here - no
 define:, two of them, an unclosed block, a computed cascade, a clause
 outside the manifest vocabulary, and a dependency whose name is
 computed - and each refusal answers nil rather than a guess. When in
 doubt the editor refuses; the CLI turns that into one line naming the
 text to paste.

 DECLARED PASSES IN RED (issue #15): NONE in this file. Every law sends
 a message to Parley.ManifestEditor, which does not exist against the
 pre-sprint tree, so every one of them errors on the missing class.

 Nothing here writes a file, spawns a process or contacts a network."

Namespace current: Parley.

TestCase subclass: ManifestEditorTest [

    <comment: 'Laws for Parley.ManifestEditor: recognition of the one
Doc B §2 cascade shape, refusal of everything else, byte-preserving
insertion of a single dependency:constraint: clause at the author''s own
indentation, and already-declared detection that reads the file rather
than guessing at it. Pure values: no file I/O, no collaborators, no
mutation.'>

    editorOn: aText [
        ^ManifestEditor on: aText
    ]

    addTo: aText [
        "The one insertion every law performs, so a difference between
         two laws is a difference in the INPUT and never in the ask."
        ^(self editorOn: aText)
            textWithDependency: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures addedConstraint
    ]

    linesOf: aString [
        ^ManifestEditFixtures textLinesOf: aString
    ]

    assertOnlyChange: anEditedText from: anOriginalText at: anIndex [
        "The line-by-line proof, independent of the expected literal:
         every line before anIndex is byte-identical, the line AT
         anIndex is the original's with a semicolon appended, the line
         after it is the inserted clause carrying the original line's
         tail, and there is nothing else. An editor that reflowed the
         file fails at the first untouched line."
        | before after |
        before := self linesOf: anOriginalText.
        after := self linesOf: anEditedText.
        self assert: after size = (before size + 1)
            description: 'the edit changed the line count by ',
                (after size - before size) printString,
                ' rather than by one'.
        1 to: anIndex - 1 do: [:i |
            self assert: (after at: i) = (before at: i)
                description: 'line ', i printString,
                    ' was rewritten: <', (before at: i),
                    '> became <', (after at: i), '>'].
        self assert: (after at: anIndex)
            = (((before at: anIndex)
                copyFrom: 1 to: (before at: anIndex) size - 2), ';')
            description: 'the previous last clause line is not the original plus a semicolon: <',
                (after at: anIndex), '>'.
        self assert: (after at: anIndex + 1)
            = ((ManifestEditFixtures indentOf: (before at: anIndex)),
                ManifestEditFixtures addedClauseText, ' ]')
            description: 'the inserted line is not the clause at the previous line''s indent: <',
                (after at: anIndex + 1), '>'.
        anIndex + 2 to: after size do: [:i |
            self assert: (after at: i) = (before at: i - 1)
                description: 'a line after the insertion was rewritten: <',
                    (after at: i), '>']
    ]

    "---- recognition: the one shape, and only it ----"

    testTheInitTemplateIsRecognized [
        "The skeleton parley init writes is the shape add must always
         handle: it is what every new project starts from."
        self assert: (self editorOn: ManifestEditFixtures initTemplateContents)
            isRecognized
    ]

    testACascadeAlreadyDeclaringDependenciesIsRecognized [
        self assert: (self editorOn: ManifestEditFixtures withDependenciesContents)
            isRecognized
    ]

    testAnAuthorsOwnFormattingIsRecognized [
        "Comments, a blank line and non-standard indentation are the
         author's business, not the recognizer's."
        self assert: (self editorOn: ManifestEditFixtures authoredContents)
            isRecognized
    ]

    "---- refusal: six shapes, six nils, no guesses ----"

    testAFileWithNoDefineSendIsRefused [
        | editor |
        editor := self editorOn: ManifestEditFixtures noDefineContents.
        self deny: editor isRecognized.
        self assert: (self addTo: ManifestEditFixtures noDefineContents) isNil
            description: 'an unrecognized file answered text instead of a refusal'
    ]

    testAFileWithTwoDefineSendsIsRefused [
        "There is no way to choose between two cascades that is not a
         guess, and a package manager that guesses at a manifest is how
         manifests get eaten."
        | editor |
        editor := self editorOn: ManifestEditFixtures twoDefinesContents.
        self deny: editor isRecognized.
        self assert: (self addTo: ManifestEditFixtures twoDefinesContents) isNil
    ]

    testAnUnclosedBlockIsRefused [
        self deny: (self editorOn: ManifestEditFixtures unclosedBlockContents)
            isRecognized
    ]

    testAComputedCascadeIsRefused [
        "A second statement inside the block means the file computes,
         and `insert after the last clause` stops being well defined."
        self deny: (self editorOn: ManifestEditFixtures computedCascadeContents)
            isRecognized
    ]

    testAClauseOutsideTheManifestVocabularyIsRefused [
        "The recognized shape is a cascade of VOCABULARY sends, and the
         vocabulary is the settled ManifestBuilder category - consumed,
         never re-listed here."
        self deny: (self editorOn: ManifestEditFixtures outsideVocabularyContents)
            isRecognized
    ]

    testAComputedDependencyNameIsRefused [
        "The editor cannot tell what is already declared when the name
         is computed, and adding a package twice is worse than refusing."
        self deny: (self editorOn: ManifestEditFixtures computedDependencyContents)
            isRecognized
    ]

    "---- S1: the first dependency, into the settled init template ----"

    testInsertingIntoTheInitTemplatePreservesEveryOtherByte [
        "The answered text is the original with exactly one clause
         inserted - asserted against the hand-written expected literal
         AND line by line against the original."
        | original edited |
        original := ManifestEditFixtures initTemplateContents.
        edited := self addTo: original.
        self assert: edited = ManifestEditFixtures initTemplateEdited
            description: 'the edited init template is not byte-exact'.
        self assertOnlyChange: edited from: original
            at: (self linesOf: original) size
    ]

    testTheInitTemplatesHeaderCommentSurvivesTheInsertion [
        "The template teaches the dependency syntax in its header
         comment. An editor that re-rendered the file would answer a
         manifest-equal program with the lesson deleted."
        | edited originalLines |
        edited := self addTo: ManifestEditFixtures initTemplateContents.
        originalLines := self linesOf: ManifestEditFixtures initTemplateContents.
        1 to: 3 do: [:i |
            self assert: (ManifestEditFixtures contains: edited
                line: (originalLines at: i))
                description: 'header comment line ', i printString,
                    ' did not survive: <', (originalLines at: i), '>']
    ]

    "---- S2: after an existing dependency clause ----"

    testInsertingAfterAnExistingDependencyPreservesOrderAndBytes [
        "The new clause FOLLOWS the existing one and the existing one is
         byte-identical apart from the semicolon it gained. Doc B §6:
         dependency order is not semantic, but stability is a property
         of the file, and sorting them would be re-rendering."
        | original edited lines |
        original := ManifestEditFixtures withDependenciesContents.
        edited := self addTo: original.
        self assert: edited = ManifestEditFixtures withDependenciesEdited
            description: 'the edited cascade is not byte-exact'.
        self assertOnlyChange: edited from: original
            at: (self linesOf: original) size.
        lines := self linesOf: edited.
        self assert: (lines at: lines size - 1)
            = '        dependency: ''tool-b'' constraint: ''^2.0'';'
            description: 'the existing dependency clause moved or changed'.
        self assert: (lines at: lines size)
            = '        dependency: ''tool-a'' constraint: ''^1.0'' ]'
            description: 'the new clause did not land last'
    ]

    "---- S3: the scenario decision 49 exists for ----"

    testTheAuthorsCommentsBlankLineAndIndentationSurvive [
        "COMMENT BY COMMENT AND LINE BY LINE. A ManifestBuilder
         round-trip answers a manifest-equal program and fails every
         assertion below, which is exactly why they are written this
         way rather than as `the result still parses`."
        | original edited |
        original := ManifestEditFixtures authoredContents.
        edited := self addTo: original.
        self assert: edited = ManifestEditFixtures authoredEdited
            description: 'the authored file is not byte-exact after the edit'.
        self assertOnlyChange: edited from: original
            at: (self linesOf: original) size.
        self assert: (ManifestEditFixtures contains: edited
            line: ManifestEditFixtures authoredHeaderCommentLine)
            description: 'the header comment did not survive'.
        self assert: (ManifestEditFixtures contains: edited
            line: ManifestEditFixtures authoredInteriorCommentLine)
            description: 'the interior comment did not survive'.
        self assert: (ManifestEditFixtures blankLineCountIn: edited)
            = (ManifestEditFixtures blankLineCountIn: original)
            description: 'the blank line inside the cascade did not survive'
    ]

    testTheNewClauseAdoptsTheAuthorsIndentation [
        "Six spaces, because the author wrote six - not the template's
         eight. Imposing an indentation is a small re-render."
        | lines |
        lines := self linesOf: (self addTo: ManifestEditFixtures authoredContents).
        self assert: (lines at: lines size)
            = '      dependency: ''tool-a'' constraint: ''^1.0'' ]'
            description: 'the inserted clause is not at the author''s indentation: <',
                (lines at: lines size), '>'
    ]

    "---- already declared: read the file, never guess ----"

    testADeclaredDependencyAnswersItsConstraint [
        self assert: ((self editorOn: ManifestEditFixtures withDependenciesContents)
            constraintFor: 'tool-b') = '^2.0'
    ]

    testAnUndeclaredDependencyAnswersNil [
        self assert: ((self editorOn: ManifestEditFixtures withDependenciesContents)
            constraintFor: 'tool-a') isNil
    ]

    testTheUnconstrainedSugarAnswersTheStar [
        "Doc B §3.2: dependency: with no constraint records '*'.
         Already-declared detection must see it, or add would declare
         the same package twice."
        self assert: ((self editorOn: ManifestEditFixtures sugarDependencyContents)
            constraintFor: 'tool-b') = '*'
    ]

    testAClauseNamedOnlyInACommentIsNotADeclaration [
        "The settled init template's header comment spells a complete
         `dependency: 'name' constraint: '^1.0.0'` clause AND the token
         Parley. A recognizer that scans text without skipping comments
         miscounts the define sends and invents a declaration that is
         not there - so this law is the trap the template has been
         carrying since Sprint 8."
        | editor |
        editor := self editorOn: ManifestEditFixtures initTemplateContents.
        self assert: editor isRecognized
            description: 'the comment''s Parley token was counted as a define send'.
        self assert: (editor constraintFor: 'name') isNil
            description: 'a clause inside a comment was read as a declaration'
    ]

    "---- structural immutability: the editor answers text, holding none ----"

    testTheEditorMutatesNothingAndAnswersTheSameTextTwice [
        "An operation answers a new value and leaves its input alone
         (Architecture §1.5). Two asks of one editor answer equal text,
         and the original string is unchanged by either."
        | original editor first second |
        original := ManifestEditFixtures withDependenciesContents.
        editor := self editorOn: original.
        first := editor
            textWithDependency: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures addedConstraint.
        second := editor
            textWithDependency: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures addedConstraint.
        self assert: first = second.
        self assert: original = ManifestEditFixtures withDependenciesContents
            description: 'the editor mutated the text it was given'.
        self deny: first = original
            description: 'the insertion answered its input unchanged'
    ]
]

Namespace current: Smalltalk.
