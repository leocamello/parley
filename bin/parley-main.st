"Parley — the CLI main script (Doc E §4.3): genuinely thin glue, and
 no longer exempt from laws. It lives in bin/ — NOT src/exec/, whose
 every .st the test harness files in, and a main script executes on
 file-in.

 It does exactly four things and holds no logic of its own:

   1. file in EVERY directory under src/, in load order;
   2. send CommandLine in: <cwd> runner: ProcessRunner new
      environment: CommandLine processEnvironment  run: <argv>
      (the environment keyword is Sprint 22's declared exception, C3 at
      the issue #24 pre-RED round: the shipped seam is OPEN here and
      closed everywhere else — naming a reader is not logic);
   3. print the result's lines;
   4. ObjectMemory quit: the result's exit code.

 Printing and exiting happen HERE alone; CommandLine answers a value.
 The wiring, the flag grammar and the diagnosis boundary all moved
 into that object at Sprint 8, because glue that chooses an exit code
 is not glue — it is the product, and it had shipped a verb that
 answered a backtrace and exited 0.

 The file-in list stays explicit because load order is semantic, and
 it is LAW-GUARDED: a law reads this file's own source and requires
 every existing src/ subdirectory to appear in it, so a new src/
 directory can never again ship unreachable. Per-invocation file-in is
 the honest MVP cost; a prebuilt image is deferred tooling polish."

| root result |

root := (Smalltalk getenv: 'PARLEY_ROOT') ifNil: ['.'].

(Smalltalk includesKey: #Parley) ifFalse: [Smalltalk addSubspace: #Parley].
#('src/compat' 'src/domain' 'src/manifest' 'src/resolver' 'src/source' 'src/install' 'src/exec' 'src/publish')
    do: [:dirName |
        | dir |
        dir := File name: root, '/', dirName.
        (dir exists and: [dir isDirectory]) ifTrue: [
            (dir files collect: [:f | f name]) asSortedCollection do: [:path |
                (path endsWith: '.st') ifTrue: [FileStream fileIn: path]]]].

result := (Parley.CommandLine
    in: Directory workingName
    runner: Parley.ProcessRunner new
    environment: Parley.CommandLine processEnvironment) run: Smalltalk arguments.
result lines do: [:each | Transcript showCr: each].
Transcript flush.
ObjectMemory quit: result exitCode
