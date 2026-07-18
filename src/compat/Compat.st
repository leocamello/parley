"Parley — compatibility layer for GNU Smalltalk 3.2.5.

 Creates the Parley namespace and adds the minimal kernel polyfills the
 domain code needs. Every extension lives in method category
 '*parley-compat' and matches well-known ANSI/Pharo semantics exactly
 (AGENTS.md §3)."

(Smalltalk includesKey: #Parley) ifFalse: [Smalltalk addSubspace: #Parley].

Collection extend [

    ifEmpty: aBlock [
        "Answer the value of aBlock when the receiver is empty; otherwise
         answer the receiver. Matches ANSI/Pharo semantics."
        <category: '*parley-compat'>
        ^self isEmpty ifTrue: [aBlock value] ifFalse: [self]
    ]

    ifEmpty: emptyBlock ifNotEmpty: notEmptyBlock [
        "Answer the value of emptyBlock when the receiver is empty;
         otherwise the value of notEmptyBlock, which may take the receiver
         as its optional argument. Matches ANSI/Pharo semantics."
        <category: '*parley-compat'>
        self isEmpty ifTrue: [^emptyBlock value].
        ^notEmptyBlock numArgs = 0
            ifTrue: [notEmptyBlock value]
            ifFalse: [notEmptyBlock value: self]
    ]
]
