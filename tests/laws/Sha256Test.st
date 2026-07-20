"Parley Sprint 5 — Sha256 laws (Doc D §2/§5; issue #7 S1-S4).

 Protocol decisions pinned here (posted on issue #7 for confirmation):
   - the whole public surface is ONE class-side message:
       Sha256 hexDigestOf: aByteString
     answering a String of exactly 64 lowercase hexadecimal characters
     (the FIPS 180-4 digest of the string's byte values);
   - no instance-side protocol, no incremental/update API, no other
     class-side messages are pinned;
   - pure and deterministic: no state, no I/O, no external processes.

 Digest discipline (issue #7): the four vectors are the issue-pinned,
 operator-verified published FIPS 180-4 values; this suite never
 computes an expected value through Parley.Sha256 itself — vectors
 anchor the primitive. The determinism/shape laws inspect outputs
 without asserting any digest value not pinned above."

Namespace current: Parley.

TestCase subclass: Sha256Test [

    <comment: 'Laws for the pure FIPS 180-4 Sha256 primitive per
Doc D §2/§5: the four pinned vectors (both padding edges included),
determinism, the 64-lowercase-hex output shape, and distinctness of
digests over distinct inputs. No filesystem, no fixtures.'>

    sixtyFourAs [
        "The S4 block-boundary message: 64 $a characters."
        ^String new: 64 withAll: $a
    ]

    nistTwoBlockMessage [
        "The S3 56-byte message - length = 56 (mod 64), so padding
         overflows into a second block."
        ^'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'
    ]

    hexAlphabet [
        ^'0123456789abcdef'
    ]

    assertIs64LowercaseHex: aString [
        self assert: aString size = 64.
        aString do: [:each |
            self assert: (self hexAlphabet includes: each)
                description: 'digest character outside 0-9a-f: ',
                    (String with: each)]
    ]

    "---- the four pinned vectors (issue #7 S1-S4, operator-verified) ----"

    testEmptyStringVector [
        self assert: (Sha256 hexDigestOf: '')
            = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    ]

    testAbcVector [
        self assert: (Sha256 hexDigestOf: 'abc')
            = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    ]

    testTwoBlockPaddingOverflowVector [
        "56 bytes: the padding cannot fit the length field in the same
         block - the message digests over two blocks."
        self assert: self nistTwoBlockMessage size = 56.
        self assert: (Sha256 hexDigestOf: self nistTwoBlockMessage)
            = '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1'
    ]

    testExactBlockBoundaryVector [
        "64 bytes: exactly one full block; all padding lands in a
         second block."
        self assert: self sixtyFourAs size = 64.
        self assert: (Sha256 hexDigestOf: self sixtyFourAs)
            = 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb'
    ]

    "---- determinism ----"

    testSameInputTwiceAnswersIdenticalDigests [
        self assert: (Sha256 hexDigestOf: 'abc')
            = (Sha256 hexDigestOf: 'abc').
        self assert: (Sha256 hexDigestOf: '')
            = (Sha256 hexDigestOf: '').
        self assert: (Sha256 hexDigestOf: self nistTwoBlockMessage)
            = (Sha256 hexDigestOf: self nistTwoBlockMessage).
        self assert: (Sha256 hexDigestOf: InstallFixtures archiveBytesA)
            = (Sha256 hexDigestOf: InstallFixtures archiveBytesA)
    ]

    "---- every digest is 64 lowercase hex characters ----"

    testDigestsAre64LowercaseHexCharacters [
        self assertIs64LowercaseHex: (Sha256 hexDigestOf: '').
        self assertIs64LowercaseHex: (Sha256 hexDigestOf: 'abc').
        self assertIs64LowercaseHex:
            (Sha256 hexDigestOf: self nistTwoBlockMessage).
        self assertIs64LowercaseHex: (Sha256 hexDigestOf: self sixtyFourAs).
        self assertIs64LowercaseHex:
            (Sha256 hexDigestOf: InstallFixtures archiveBytesA).
        self assertIs64LowercaseHex:
            (Sha256 hexDigestOf: (String new: 200 withAll: $z))
    ]

    "---- distinct inputs answer distinct digests ----"

    testDistinctShortInputsAnswerDistinctDigests [
        | inputs digests |
        inputs := Array with: '' with: 'a' with: 'b' with: 'ab'.
        inputs := inputs, (Array with: 'ba' with: 'abc' with: 'abd').
        digests := Set new.
        inputs do: [:each | digests add: (Sha256 hexDigestOf: each)].
        self assert: digests size = inputs size
    ]
]

Namespace current: Smalltalk.
