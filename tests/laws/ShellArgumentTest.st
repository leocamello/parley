"Parley Sprint 24 — immutable shell-argument laws (decision 91).

 These laws pin the approved representation and test its observable
 one-argument behavior against a real shell. They do not replace a child
 tool's own filename rules or reinterpret command syntax. All production
 lookups happen when a test runs. DECLARED PASSES IN RED: none."

Namespace current: Parley.

TestCase subclass: ShellArgumentTest [

    <comment: 'Canonical rendering, validation, immutable value semantics
and seeded shell round-trip laws for ShellArgument. No passing-in-RED
regression guards are hidden in this family.'>

    argument: aString [
        ^ShellArgumentFixtures argumentClass fromString: aString
    ]

    rendered: aString [
        ^(self argument: aString) shellString
    ]

    assertRejected: anObject message: aMessage [
        "Assert the declared class and text. Resolve the missing classes
         before installing the handler: missing RED behavior must never
         masquerade as the argument-validation error under test."
        | argumentClass errorClass caught |
        argumentClass := ShellArgumentFixtures argumentClass.
        errorClass := ShellArgumentFixtures errorClass.
        caught := nil.
        [argumentClass fromString: anObject]
            on: Error do: [:error | caught := error. error return: nil].
        self deny: caught isNil description: 'invalid argument was accepted'.
        self assert: caught class = errorClass
            description: 'invalid argument signaled ', caught class name.
        self assert: caught messageText = aMessage
    ]

    testSafeAlphabetAndOrdinaryPathsKeepTheirSpelling [
        "The conservative alphabet is explicit API, preserving settled
         command pins for ordinary paths and source locations."
        | alphabet |
        alphabet := ShellArgumentFixtures safeAlphabet.
        self assert: (self rendered: alphabet) = alphabet.
        alphabet do: [:character |
            | text |
            text := String with: character.
            self assert: (self rendered: text) = text].
        #('/tmp/parley-project/cache-1.star' 'git@example.org:team/index'
            'https://example.org/index/v1.0.0' '../local-source') do: [:text |
                self assert: (self rendered: text) = text]
    ]

    testEmptyStringRendersAsAnExplicitEmptyArgument [
        self assert: (self rendered: '')
            = (ShellArgumentFixtures quote, ShellArgumentFixtures quote)
    ]

    testSpacesAndExpansionSyntaxUseSingleQuotes [
        "Fixed examples contain no apostrophe, so their canonical form is
         exactly one opening quote, the unchanged input and one closing
         quote. The oracle is literal input, not a second encoder."
        | quote |
        quote := ShellArgumentFixtures quote.
        #('hello world.st' '$PARLEY_ARGUMENT_PROBE' '$(printf SUBSTITUTED)'
            'a*b?[c]' '~' '#comment' 'a"b' 'a\b') do: [:text |
                self assert: (self rendered: text) = (quote, text, quote)]
    ]

    testApostropheHasTheDeclaredCloseEscapeReopenSpelling [
        | quote backslash expected |
        quote := ShellArgumentFixtures quote.
        backslash := String with: (Character value: 92).
        expected := quote, 'one', quote, backslash, quote, quote, 'quote', quote.
        self assert: (self rendered: 'one''quote') = expected
    ]

    testTabsNewlinesAndHighBytesAreQuotedWithoutNormalization [
        | quote |
        quote := ShellArgumentFixtures quote.
        (Array with: Character tab with: Character nl
            with: (Character value: 255)) do: [:character |
                | text |
                text := String with: character.
                self assert: (self rendered: text) = (quote, text, quote)]
    ]

    testRejectsNulAtEveryPositionWithTheDeclaredDiagnosis [
        | nul |
        nul := ShellArgumentFixtures nul.
        (Array with: nul with: nul, 'after'
            with: 'before', nul, 'after' with: 'before', nul) do: [:text |
                self assertRejected: text message: 'command argument contains NUL']
    ]

    testRejectsNonStringsWithTheDeclaredDiagnosis [
        (Array with: nil with: true with: 7 with: #symbol with: #())
            do: [:value |
                self assertRejected: value
                    message: 'command argument must be a String']
    ]

    testConstructionCopiesTheCallersMutableString [
        | original argument equalValue initialHash |
        original := 'mutable path' copy.
        argument := self argument: original.
        equalValue := self argument: 'mutable path'.
        initialHash := argument hash.
        original at: 1 put: $X.
        self assert: argument = equalValue.
        self assert: argument hash = initialHash.
        self assert: argument shellString = '''mutable path'''
    ]

    testChangingReturnedSafeRenderingCannotChangeTheValue [
        "The safe-token fast path must not leak the privately copied
         input. A caller may mutate any returned String."
        | argument rendered equalValue |
        argument := self argument: 'ordinary'.
        equalValue := self argument: 'ordinary'.
        rendered := argument shellString.
        rendered at: 1 put: $X.
        self assert: argument shellString = 'ordinary'.
        self assert: argument = equalValue.
        self assert: argument hash = equalValue hash
    ]

    testChangingReturnedQuotedRenderingCannotChangeTheValue [
        | argument rendered equalValue |
        argument := self argument: 'two words'.
        equalValue := self argument: 'two words'.
        rendered := argument shellString.
        rendered at: 2 put: $X.
        self assert: argument shellString = '''two words'''.
        self assert: argument = equalValue.
        self assert: argument hash = equalValue hash
    ]

    testEqualityAndHashSupportValueBasedSetMembership [
        | first second values |
        first := self argument: 'one''quote'.
        second := self argument: 'one''quote' copy.
        self assert: first = second.
        self assert: second = first.
        self assert: first hash = second hash.
        values := Set new.
        values add: first.
        self assert: (values includes: second)
    ]

    testDistinctRawArgumentsAreDistinctValues [
        | empty plain quoted |
        empty := self argument: ''.
        plain := self argument: 'ordinary'.
        quoted := self argument: '''ordinary'''.
        self deny: empty = plain.
        self deny: plain = quoted.
        self deny: quoted = plain
    ]

    testForeignObjectsAreNotArgumentValues [
        | argument |
        argument := self argument: 'ordinary'.
        self deny: argument = 'ordinary'.
        self deny: argument = #ordinary.
        self deny: argument = nil
    ]

    testSeededEqualInputsHaveEqualValuesHashesAndRenderings [
        | samples |
        samples := ShellArgumentFixtures generatedArguments.
        self assert: samples size = 256.
        samples do: [:raw |
            | first second |
            first := self argument: raw.
            second := self argument: raw copy.
            self assert: first = second.
            self assert: first hash = second hash.
            self assert: first shellString = second shellString.
            self assert: first shellString = first shellString]
    ]

    testSeededShellRoundTripPreservesExactlyOneArgument [
        ShellArgumentFixtures assertRoundTripsFor: self
    ]
]

Namespace current: Smalltalk.
