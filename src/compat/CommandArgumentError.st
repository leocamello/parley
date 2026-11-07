"Parley — an argument that cannot cross the process boundary.
 Spec: Doc E section 6; architecture decision 91; issue #26.
 This file sorts before Compat.st, including in the packaged fileIns,
 so it must also support loading into a fresh child image."

(Smalltalk includesKey: #Parley) ifFalse: [Smalltalk addSubspace: #Parley].

Namespace current: Parley.

Error subclass: CommandArgumentError [
    <comment: 'An invalid process argument, diagnosed before spawning.
Carries one messageText; the CLI reports it at exit 1.'>
]

Namespace current: Smalltalk.
