"Parley — Sha256: the pure FIPS 180-4 integrity primitive.
 Spec: docs/design/installer.md §2; issue #7 S1-S4.
 Pure Smalltalk against the 3.2.5 kernel — no external processes, no
 OS tools, no third-party code. Input is a String treated as raw bytes
 (each character's value is one octet); output is the 64-character
 lowercase hexadecimal digest. All 32-bit modular arithmetic is done
 by masking with 16rFFFFFFFF. Stateless and deterministic: the round
 constants and initial hash are the published FIPS 180-4 values,
 rendered in decimal."

Namespace current: Parley.

Object subclass: Sha256 [

    <comment: 'The pure FIPS 180-4 SHA-256 primitive. One public
message: the class-side hexDigestOf:, answering the 64-character
lowercase hex digest of a byte string. No state, no I/O; correctness
is anchored to the published test vectors.'>

    Sha256 class >> hexDigestOf: aByteString [
        "The 64-character lowercase hexadecimal SHA-256 digest of
         aByteString's byte values."
        <category: 'digesting'>
        ^self hexFrom: (self digestWordsOf: (self pad: aByteString))
    ]

    Sha256 class >> initialHash [
        "The eight FIPS 180-4 §5.3.3 initial hash words (decimal)."
        <category: 'private-constants'>
        ^#(1779033703 3144134277 1013904242 2773480762 1359893119 2600822924 528734635 1541459225)
    ]

    Sha256 class >> roundConstants [
        "The sixty-four FIPS 180-4 §4.2.2 round constants K (decimal)."
        <category: 'private-constants'>
        ^#(1116352408 1899447441 3049323471 3921009573 961987163 1508970993 2453635748 2870763221
           3624381080 310598401 607225278 1426881987 1925078388 2162078206 2614888103 3248222580
           3835390401 4022224774 264347078 604807628 770255983 1249150122 1555081692 1996064986
           2554220882 2821834349 2952996808 3210313671 3336571891 3584528711 113926993 338241895
           666307205 773529912 1294757372 1396182291 1695183700 1986661051 2177026350 2456956037
           2730485921 2820302411 3259730800 3345764771 3516065817 3600352804 4094571909 275423344
           430227734 506948616 659060556 883997877 958139571 1322822218 1537002063 1747873779
           1955562222 2024104815 2227730452 2361852424 2428436474 2756734187 3204031479 3329325298)
    ]

    Sha256 class >> pad: aByteString [
        "FIPS 180-4 §5.1.1 padding: the message bytes, one 128 byte,
         zeros to 56 (mod 64), then the 64-bit big-endian bit length.
         Answers an Array of byte values whose size is a multiple of 64."
        <category: 'private-digesting'>
        | bytes bitLength |
        bytes := OrderedCollection new.
        aByteString do: [:each | bytes add: (each value bitAnd: 255)].
        bitLength := aByteString size * 8.
        bytes add: 128.
        [bytes size \\ 64 = 56] whileFalse: [bytes add: 0].
        7 to: 0 by: -1 do: [:i |
            bytes add: ((bitLength bitShift: (8 * i) negated) bitAnd: 255)].
        ^bytes asArray
    ]

    Sha256 class >> digestWordsOf: paddedBytes [
        "FIPS 180-4 §6.2.2 compression over each 64-byte block; answers
         the eight final 32-bit hash words."
        <category: 'private-digesting'>
        | h k w a b c d e f g hh t1 t2 |
        h := self initialHash copy.
        k := self roundConstants.
        1 to: paddedBytes size by: 64 do: [:blockStart |
            w := Array new: 64.
            1 to: 16 do: [:t |
                | base |
                base := blockStart + ((t - 1) * 4).
                w at: t put:
                    ((((paddedBytes at: base) * 256
                        + (paddedBytes at: base + 1)) * 256
                        + (paddedBytes at: base + 2)) * 256
                        + (paddedBytes at: base + 3))].
            17 to: 64 do: [:t |
                w at: t put:
                    (((self smallSigma1: (w at: t - 2))
                        + (w at: t - 7)
                        + (self smallSigma0: (w at: t - 15))
                        + (w at: t - 16)) bitAnd: 16rFFFFFFFF)].
            a := h at: 1. b := h at: 2. c := h at: 3. d := h at: 4.
            e := h at: 5. f := h at: 6. g := h at: 7. hh := h at: 8.
            1 to: 64 do: [:t |
                t1 := (hh
                    + (self bigSigma1: e)
                    + (self ch: e with: f with: g)
                    + (k at: t)
                    + (w at: t)) bitAnd: 16rFFFFFFFF.
                t2 := ((self bigSigma0: a)
                    + (self maj: a with: b with: c)) bitAnd: 16rFFFFFFFF.
                hh := g. g := f. f := e.
                e := (d + t1) bitAnd: 16rFFFFFFFF.
                d := c. c := b. b := a.
                a := (t1 + t2) bitAnd: 16rFFFFFFFF].
            h at: 1 put: (((h at: 1) + a) bitAnd: 16rFFFFFFFF).
            h at: 2 put: (((h at: 2) + b) bitAnd: 16rFFFFFFFF).
            h at: 3 put: (((h at: 3) + c) bitAnd: 16rFFFFFFFF).
            h at: 4 put: (((h at: 4) + d) bitAnd: 16rFFFFFFFF).
            h at: 5 put: (((h at: 5) + e) bitAnd: 16rFFFFFFFF).
            h at: 6 put: (((h at: 6) + f) bitAnd: 16rFFFFFFFF).
            h at: 7 put: (((h at: 7) + g) bitAnd: 16rFFFFFFFF).
            h at: 8 put: (((h at: 8) + hh) bitAnd: 16rFFFFFFFF)].
        ^h
    ]

    Sha256 class >> hexFrom: hashWords [
        "The eight 32-bit words as 64 lowercase hex characters."
        <category: 'private-digesting'>
        | digits stream |
        digits := '0123456789abcdef'.
        stream := WriteStream on: String new.
        hashWords do: [:word |
            7 to: 0 by: -1 do: [:i |
                stream nextPut: (digits at:
                    ((word bitShift: (4 * i) negated) bitAnd: 15) + 1)]].
        ^stream contents
    ]

    Sha256 class >> rotr: aWord by: n [
        "Rotate the 32-bit word right by n bits."
        <category: 'private-functions'>
        ^(aWord bitShift: 0 - n)
            bitOr: ((aWord bitShift: 32 - n) bitAnd: 16rFFFFFFFF)
    ]

    Sha256 class >> ch: e with: f with: g [
        "FIPS 180-4 §4.1.2 Ch(e, f, g)."
        <category: 'private-functions'>
        ^(e bitAnd: f) bitXor: ((e bitXor: 16rFFFFFFFF) bitAnd: g)
    ]

    Sha256 class >> maj: a with: b with: c [
        "FIPS 180-4 §4.1.2 Maj(a, b, c)."
        <category: 'private-functions'>
        ^((a bitAnd: b) bitXor: (a bitAnd: c)) bitXor: (b bitAnd: c)
    ]

    Sha256 class >> bigSigma0: aWord [
        <category: 'private-functions'>
        ^((self rotr: aWord by: 2)
            bitXor: (self rotr: aWord by: 13))
            bitXor: (self rotr: aWord by: 22)
    ]

    Sha256 class >> bigSigma1: aWord [
        <category: 'private-functions'>
        ^((self rotr: aWord by: 6)
            bitXor: (self rotr: aWord by: 11))
            bitXor: (self rotr: aWord by: 25)
    ]

    Sha256 class >> smallSigma0: aWord [
        <category: 'private-functions'>
        ^((self rotr: aWord by: 7)
            bitXor: (self rotr: aWord by: 18))
            bitXor: (aWord bitShift: -3)
    ]

    Sha256 class >> smallSigma1: aWord [
        <category: 'private-functions'>
        ^((self rotr: aWord by: 17)
            bitXor: (self rotr: aWord by: 19))
            bitXor: (aWord bitShift: -10)
    ]
]

Namespace current: Smalltalk.
