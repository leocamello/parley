"Parley — the CLI main script (Doc E §4.2): glue only, excluded from
 SUnit obligations. Lives in bin/ — NOT src/exec/, whose every .st the
 test harness files in, and a main script executes on file-in.

 Files the src/ directories in (run-tests order, sorted within each),
 wires the real collaborators — DirectorySource from '--source <dir>'
 when given (nil otherwise), store at <cwd>/.parley/store, target at
 <cwd>/.parley/packages, a real ProcessRunner — sends CLI run:,
 prints the lines, and exits with the code. Printing and exiting
 happen HERE alone; the CLI answers a value. Per-invocation file-in
 is the honest MVP cost; a prebuilt image is deferred tooling polish."

| root args sourceDir argv i source cli result |

root := (Smalltalk getenv: 'PARLEY_ROOT') ifNil: ['.'].

(Smalltalk includesKey: #Parley) ifFalse: [Smalltalk addSubspace: #Parley].
#('src/compat' 'src/domain' 'src/manifest' 'src/resolver' 'src/source' 'src/install' 'src/exec')
    do: [:dirName |
        | dir |
        dir := File name: root, '/', dirName.
        (dir exists and: [dir isDirectory]) ifTrue: [
            (dir files collect: [:f | f name]) asSortedCollection do: [:path |
                (path endsWith: '.st') ifTrue: [FileStream fileIn: path]]]].

args := Smalltalk arguments.
(args isEmpty not and: [(args at: 1) = '--'])
    ifTrue: [args := args copyFrom: 2 to: args size].
sourceDir := nil.
argv := OrderedCollection new.
i := 1.
[i <= args size] whileTrue: [
    | each |
    each := args at: i.
    (each = '--source' and: [i < args size])
        ifTrue: [sourceDir := args at: i + 1. i := i + 2]
        ifFalse: [argv add: each. i := i + 1]].

(File name: '.parley') exists ifFalse: [Directory create: '.parley'].
(File name: '.parley/packages') exists
    ifFalse: [Directory create: '.parley/packages'].

source := sourceDir isNil
    ifTrue: [nil]
    ifFalse: [Parley.DirectorySource on: sourceDir].
cli := Parley.CLI
    in: '.'
    source: source
    store: (Parley.ContentStore on: '.parley/store')
    target: '.parley/packages'
    runner: Parley.ProcessRunner new.
result := cli run: argv asArray.
result lines do: [:each | Transcript showCr: each].
ObjectMemory quit: result exitCode
