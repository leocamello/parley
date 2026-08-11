"Parley Sprint 17 — fixtures for the PathGuard, boundary-table,
 shipped-wrapper and acceptance suites (issue #19; Doc E §4.1/§4.2/§4.3,
 Doc F §1, §8 decisions 59, 60 and 66).

 THE TEARDOWN RULE COMES FIRST, because it is what makes every other
 fixture here safe. A read-only fixture DIRECTORY survives
 ExecFixtures removeTree: — on POSIX the permission to unlink an entry
 belongs to the containing directory, not to the entry — so the tree
 stays on disk, the next run's directoryNamed: finds it, and failures
 appear in suites this sprint never touched. This bit the Sprint 16
 close-out probe. Every suite in this sprint tears down through
 removeTree: below, which restores owner write permission on every
 directory of the tree BEFORE delegating to the settled recursive
 remover.

 CHMOD IS IN-IMAGE, NOT A PROCESS. 3.2.5's File>>mode: is a real
 chmod(2) (probed), so the hostile states are built without spawning
 anything: makeReadOnly:, makeUnreadable: and unlock: are the whole
 vocabulary. ProcessRunner stays the one process seam, and no fixture
 here composes a shell command for permissions.

 THE SPELLING TRAP, PROBED AT STAGING AND RESTATED HERE BECAUSE IT IS
 THE ONE THIS SPRINT DIES ON: 3.2.5 has File>>isWriteable, with an
 e — File>>isWritable does not exist and raises a DNU. And
 isWriteable answers FALSE for a path that does not exist, exactly as
 isFile does, so absence is not unwritability: a single-predicate
 write check turns every first resolve in a fresh project into a
 permissions error. Two predicates, therefore — overwrite an existing
 file needs isFile and isWriteable; create a new one needs its PARENT
 directory to satisfy isDirectory and isWriteable.

 Pinned wording decisions (posted on issue #19 for confirmation at the
 RED review) live in the methods:
   - the write refusal — unwritableLineFor:;
   - the unreadable index entry — unreadableEntryProblemFor:;
   - the wrapper's missing main script — wrapperMissingScriptLineFor:.

 The I/O census (§8 decision 60) is declared here as ioCensusClassNames,
 in the shape CommandLineFixtures undiagnosedErrorClassNames already
 uses for the closed-set law's exemption list: the exemption list of a
 prohibition law is a declaration a reviewer can read, and the drift
 law's job is to fail the moment a NINTH class starts doing direct
 File I/O.

 Every fixture path is under tmp/, unique per test via a label, and
 removed recursively by the caller's tearDown."

Namespace current: Parley.

Object subclass: PathFixtures [

    <comment: 'Class-side factory for Sprint 17 fixtures: in-image
chmod, unlocking teardown, the pinned write-refusal wordings, the
direct-File-I/O census and its src/ walk, the boundary-table oracles,
and the hostile working directories each scenario needs. Stateless;
uniqueness comes from per-test labels.'>

    "---- in-image chmod (File>>mode: is a real chmod, probed) ----"

    PathFixtures class >> readOnlyFileMode [
        "r--r--r-- : readable by everyone, writable by nobody. The
         state a root-owned checkout or a bad umask produces."
        <category: 'permissions'>
        ^8r444
    ]

    PathFixtures class >> readOnlyDirectoryMode [
        "r-xr-xr-x : traversable and listable, but nothing may be
         created, renamed or removed inside it."
        <category: 'permissions'>
        ^8r555
    ]

    PathFixtures class >> unreadableFileMode [
        "--------- : the file exists and is not readable. exists
         answers true, which is what makes this the read-side trap."
        <category: 'permissions'>
        ^8r000
    ]

    PathFixtures class >> writableFileMode [
        <category: 'permissions'>
        ^8r644
    ]

    PathFixtures class >> writableDirectoryMode [
        <category: 'permissions'>
        ^8r755
    ]

    PathFixtures class >> makeReadOnly: aPath [
        "Take write permission away from aPath — a file or a directory
         — and answer it, so a fixture reads as one expression."
        <category: 'permissions'>
        | file |
        file := File name: aPath.
        file isDirectory
            ifTrue: [file mode: self readOnlyDirectoryMode]
            ifFalse: [file mode: self readOnlyFileMode].
        ^aPath
    ]

    PathFixtures class >> makeUnreadable: aPath [
        "Take read permission away from aPath and answer it. The file
         still EXISTS, which is why every check written against
         existence waves it through."
        <category: 'permissions'>
        (File name: aPath) mode: self unreadableFileMode.
        ^aPath
    ]

    PathFixtures class >> unlock: aPath [
        "Restore owner read/write (and traversal, for a directory) on
         aPath and every entry beneath it. Answers aPath.

         A SYMBOLIC LINK IS SKIPPED, and that is not tidiness. Every
         File predicate here FOLLOWS a link, so unlocking a fixture
         directory holding the S18 symlink to bin/parley would chmod
         the repository's own wrapper — the teardown would quietly
         strip the executable bit off the shipped binary and the next
         suite would fail somewhere else entirely. The link itself has
         no permissions worth restoring; removing it is an operation on
         its containing directory."
        <category: 'permissions'>
        | file |
        file := File name: aPath.
        file isSymbolicLink ifTrue: [^aPath].
        file exists ifFalse: [^aPath].
        file isDirectory
            ifTrue: [
                file mode: self writableDirectoryMode.
                file namesDo: [:each |
                    (#('.' '..') includes: each)
                        ifFalse: [self unlock: aPath, '/', each]]]
            ifFalse: [file mode: self writableFileMode].
        ^aPath
    ]

    PathFixtures class >> removeTree: aPath [
        "THE TEARDOWN RULE (issue #19, Architecture impact). Unlock the
         whole tree, THEN delegate to the settled recursive remover.
         Without the unlock a read-only fixture directory survives the
         run, poisons the next one through directoryNamed:, and
         produces failures in suites this sprint never touched."
        <category: 'permissions'>
        self unlock: aPath.
        ExecFixtures removeTree: aPath
    ]

    "---- pinned wordings (posted on issue #19) ----"

    PathFixtures class >> unwritableLineFor: aPath [
        "THE WRITE-SIDE REFUSAL, in the settled '<path>: ...' grammar
         every other file diagnosis uses (Doc E §4.1, §8 decision 59).

         ONE SENTENCE SERVES THE PRECHECK AND THE TRANSLATION, and that
         is why it names the OUTCOME rather than the state. The
         precheck knows the path failed isWriteable; the translation
         path — the TOCTOU window, a read-only mount, a full disk, an
         immutable flag — knows only that the write did not happen.
         A sentence saying the path is not writable would be a claim
         the translation path has not checked, which is §8 decision
         58's standard broken inside the sprint that makes it a law.
         could not be written is true in both, and is the same sentence
         decision 59 promises every unlisted failure mode answers.

         The remedy directs the reader where to look; it does not
         assert that permissions ARE the cause. Naming a cause is the
         claim decision 58 governs, and this line makes none."
        <category: 'pinned wordings'>
        ^aPath, ': could not be written - check its permissions and try again'
    ]

    PathFixtures class >> unreadableEntryProblemFor: aBaseName [
        "The index-entry read refusal, in the grammar DirectorySource
         already carries for the archive beside it (Doc F §4). No
         remedy: the file belongs to whoever publishes the index, and
         the reader of this line cannot repair it — decision 58 again,
         which forbids inventing one."
        <category: 'pinned wordings'>
        ^aBaseName, ': missing or unreadable entry file'
    ]

    PathFixtures class >> unreadableArchiveProblemFor: aFileName [
        "The settled DirectorySource archive sentence, restated so the
         laws that now reach it through an UNREADABLE (rather than
         absent) archive assert the same bytes. The wording does not
         move: it was already telling the truth about what the check
         was supposed to do."
        <category: 'pinned wordings'>
        ^aFileName, ': missing or unreadable archive file'
    ]

    PathFixtures class >> missingDirectoryProblemFor: aPath [
        "The settled DirectorySource scan sentence, restated here so a
         row can declare it. The wording does not move — Sprint 17 only
         puts the predicate behind it."
        <category: 'pinned wordings'>
        ^aPath, ': missing or unreadable directory'
    ]

    PathFixtures class >> wrapperMissingScriptLineFor: aPath [
        "What bin/parley prints when its own main script is not where
         it looked (§8 decision 66, Doc E §4.3). Exit 70 accompanies
         it: an installation missing its own main script is a defect in
         Parley, which is what 70 means in the §4.2 taxonomy."
        <category: 'pinned wordings'>
        ^'parley: cannot find ', aPath, ' - this Parley installation is incomplete'
    ]

    PathFixtures class >> wrapperExitCode [
        "70, and not 1 (§8 decision 66)."
        <category: 'pinned wordings'>
        ^70
    ]

    PathFixtures class >> permissionDocumentationMarkers [
        "What the README must say about the permission diagnostics
         (S17). The tool now refuses an unwritable path by name, and a
         README that describes a tool answering 'internal error' for a
         read-only checkout describes a tool that no longer exists."
        <category: 'pinned wordings'>
        ^#('could not be written' 'check its permissions')
    ]

    PathFixtures class >> installationDocumentationMarkers [
        "What the README must say about the installation route (S17):
         the symlink-onto-PATH install that §8 decision 66 finally
         makes work, and the environment variable an operator may set
         instead. Documenting the route was pointless while it was
         broken, which is why the roadmap deferred packaging behind
         it — do the route first, measure demand second."
        <category: 'pinned wordings'>
        ^#('ln -s' 'PARLEY_ROOT')
    ]

    "---- the direct-File-I/O census (§8 decision 60) ----"

    PathFixtures class >> directIoSendSources [
        "The send shapes that ARE direct file I/O, and the whole of
         what the prohibition law searches for. They are the four the
         Gate C census was taken with, so the law and the census that
         sized it look for the same thing.

         FileStream is matched with its trailing space so every
         class-side send counts (fileIn:, open:mode:, read:), rather
         than an enumeration of selectors that would be the very trap
         this sprint exists to abolish."
        <category: 'io census'>
        ^#('File name:' 'FileStream ' 'Directory create:'
           'Directory workingName')
    ]

    PathFixtures class >> guardClassName [
        "The one class the prohibition exempts unconditionally: the
         chokepoint itself."
        <category: 'io census'>
        ^'PathGuard'
    ]

    PathFixtures class >> ioCensusClassNames [
        "THE EXEMPTION LIST OF THE PROHIBITION, DERIVED BY ENUMERATING
         THE PROPERTY THE PROHIBITION FORBIDS (§8 decision 60) — never
         from the set of sites that motivated the rule. These are every
         class in src/ that performed direct File / FileStream /
         Directory I/O when the sprint opened, taken at the Gate C
         amendment.

         THE SET IS THE LAW; THE PER-CLASS SITE COUNTS ARE NOT, and the
         difference is recorded here because two of the published
         counts are wrong. The issue annotates CLI with 11 sites and
         Publisher with 13; the census command published in the issue's
         own Gate C comment yields 10 and 12 (re-derived at the RED
         review with a wider regex, which found no ninth class either).
         The other six — SparseIndexSource 9, ContentStore 4,
         ManifestFile 3, DirectorySource 2, GitIndexSource 1,
         CommandLine 1 — reproduce exactly. Nothing here or in any law
         asserts a count, so finding ten sites in CLI rather than
         eleven at GREEN is expected and is not a missing site to hunt.

         An earlier draft of the issue listed six, of which two —
         ManifestEditor and ManifestBuilder — perform NO file I/O at
         all, and four that do fifteen sites between them were absent.
         The law as written could not have passed, and the two
         available escapes were a mid-sprint halt or a quiet narrowing
         at GREEN. That is inventory row 22: two artifacts each correct
         alone and wrong with respect to each other, with nothing
         comparing them.

         THE BOUND, STATED (decision 43's standard). Naming the eight
         here means the law's live claim is that a NINTH class never
         starts doing direct File I/O — it is not a claim that these
         eight have none left. What holds the eight to the chokepoint
         is the behaviour half of the sprint: every row of the boundary
         table driven through a hostile state, answering its own error
         and never exit 70, which no class can satisfy while raising a
         kernel FileError of its own."
        <category: 'io census'>
        ^#('CLI' 'CommandLine' 'ContentStore' 'DirectorySource'
           'GitIndexSource' 'ManifestFile' 'Publisher'
           'SparseIndexSource')
    ]

    PathFixtures class >> ioSiteFileNamesUnder: aRootPath subdirectories: someDirNames [
        "Every .st file under aRootPath/<dir> for each of someDirNames
         whose source text performs one of the directIoSendSources, as
         '<dir>/<file>', sorted.

         The walk, the namesDo: idiom and the normalized-code search
         are the settled ones (LockSchemaFixtures), reused rather than
         rewritten: 3.2.5's File>>files answers regular files only and
         never recurses, so a walk written the obvious way sees NOTHING
         and the law passes vacuously — the trap that bit Sprint 8's
         bin/ law, and the reason the non-empty guard below is
         mandatory rather than decorative.

         BOUNDED CLAIM, exactly as the settled deserialization drift
         law states its own (§8 decisions 38 and 43): this is a TEXTUAL
         search over comment-stripped, whitespace-normalized source.
         3.2.5 offers no reflective alternative — whichSelectorsReferTo:
         searches a method's literals rather than its sends, and
         allCallsOn: does not exist — so I/O reached through a
         temporary, or assembled by perform:, stays invisible. The law
         claims what it can prove and says so."
        <category: 'io census'>
        | names |
        names := OrderedCollection new.
        someDirNames do: [:dirName |
            (File name: aRootPath, '/', dirName) namesDo: [:fileName |
                | code |
                (fileName endsWith: '.st') ifTrue: [
                    code := LockSchemaFixtures normalizedCodeOf:
                        (File name: aRootPath, '/', dirName, '/',
                            fileName) contents.
                    (self directIoSendSources anySatisfy: [:each |
                        LockSchemaFixtures does: code include: each])
                        ifTrue: [names add: dirName, '/', fileName]]]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    PathFixtures class >> ioSiteFileNames [
        "The census walk over the real src/ tree."
        <category: 'io census'>
        ^self ioSiteFileNamesUnder: 'src'
            subdirectories: CommandLineFixtures srcSubdirectoryNames
    ]

    PathFixtures class >> ioSiteClassNames [
        "The census as class names: a src/ file is named for the class
         it defines. Sorted, as Strings."
        <category: 'io census'>
        ^self classNamesOf: self ioSiteFileNames
    ]

    PathFixtures class >> classesDoingIoIn: someClassNames outside: someExemptNames [
        "Every class of someClassNames that neither IS the chokepoint
         nor appears in someExemptNames — the prohibition's comparison,
         extracted so a law can run it TWICE: once over the real src/
         tree with the real census (must be empty) and once over a
         fabricated tree holding a ninth class (must name it). A drift
         law that has never failed on purpose is a law about nothing."
        <category: 'io census'>
        ^someClassNames
            reject: [:each |
                each = self guardClassName
                    or: [someExemptNames includes: each]]
    ]

    PathFixtures class >> classNamesOf: someFileNames [
        "'<dir>/<Name>.st' -> 'Name', sorted: a src/ file is named for
         the class it defines."
        <category: 'io census'>
        ^((someFileNames collect: [:each |
            | base |
            base := each copyFrom: (each indexOf: $/) + 1 to: each size.
            base copyFrom: 1 to: base size - 3])
                asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- the fabricated tree the enumeration is proved against ----"

    PathFixtures class >> ioProbeSubdirectoryNames [
        <category: 'io probe tree'>
        ^#('domain' 'exec')
    ]

    PathFixtures class >> populateIoProbeTreeIn: aRootPath [
        "A two-file src/-shaped tree under tmp/: one class that really
         performs File I/O, and one that merely NAMES the send in its
         comment. Walking it through the same code path as the real
         enumeration proves two things the live tree cannot prove on
         its own — that the walk sees a real site at all (3.2.5's
         File>>files answers regular files only and never recurses, so a
         walk written the obvious way sees nothing and every law over it
         passes vacuously), and that prose naming a send is not a site."
        <category: 'io probe tree'>
        Directory create: aRootPath, '/domain'.
        Directory create: aRootPath, '/exec'.
        SourceFixtures write: self quietProbeSource
            toFile: 'Quiet.st' in: aRootPath, '/domain'.
        SourceFixtures write: self noisyProbeSource
            toFile: 'Noisy.st' in: aRootPath, '/exec'
    ]

    PathFixtures class >> addNinthClassTo: aRootPath [
        "A ninth class performing direct File I/O, dropped into the
         fabricated tree so the prohibition can be shown to DETECT one.
         Named for what it is."
        <category: 'io probe tree'>
        SourceFixtures write: self ninthProbeSource
            toFile: 'Ninth.st' in: aRootPath, '/domain'
    ]

    PathFixtures class >> quietProbeSource [
        "A class that performs no I/O and whose comment NAMES the send.
         It must not be found: the walk searches comment-stripped
         source, because prose naming a send is not a sender (§8
         decision 38)."
        <category: 'io probe tree'>
        ^'"This class never sends File name: and never opens a stream."
Object subclass: Quiet [
    Quiet class >> answer [ ^42 ]
]
', SourceFixtures newline
    ]

    PathFixtures class >> noisyProbeSource [
        <category: 'io probe tree'>
        ^'Object subclass: Noisy [
    Noisy class >> peek: aPath [ ^(File name: aPath) exists ]
]
', SourceFixtures newline
    ]

    PathFixtures class >> ninthProbeSource [
        <category: 'io probe tree'>
        ^'Object subclass: Ninth [
    Ninth class >> hoard: aPath [ Directory create: aPath ]
]
', SourceFixtures newline
    ]

    PathFixtures class >> probeIoSiteFileNames [
        "What the walk answers over the fabricated tree: the noisy class
         alone. The quiet one is the comment-stripping half."
        <category: 'io probe tree'>
        ^#('exec/Noisy.st')
    ]

    "---- the boundary table's oracles (Doc E §4.1) ----"

    PathFixtures class >> boundaryRoleNames [
        "Every path role the table declares, sorted. A role is what the
         OPERATOR calls the path — the column that makes a row a
         boundary rather than a call site.

         NINE rows an operator reaches by running a verb, and THREE the
         tool reaches on its own behalf. Doc E §4.1 keeps both in the
         table and separates them by a different property: the wiring
         state directory, the archive cache and the index cache are not
         VERB-LEVEL boundaries with a remedy sentence of their own,
         because an operator does not choose where the content store
         lives — but every one of them is a row like any other, driven
         by the same laws.

         THE WIRING STATE DIRECTORY ROW NAMES ITSELF HONESTLY, and the
         name is the ruling (§8 decision 72, ruled at the RED review).
         It is state-directory creation at the WIRING boundary —
         CommandLine creating <workdir>/.parley and
         <workdir>/.parley/packages before any verb runs — and it is
         what an operator meets FIRST in a read-only project directory,
         for every verb including init. Its declared error is
         ExecutionError because .parley/packages is literally
         ExecutionScope's target and because Sprint 16 already
         established ExecutionError carrying a '<path>: ...' filesystem
         precondition, so the line grammar is settled rather than
         invented. That is a statement about the CARRIER, not a claim
         that the failure has anything to do with executing something —
         decision 43's standard applied to a table a future maintainer
         will read to find the eighth boundary. The operator never sees
         the class name; they see one line naming the directory with a
         remedy.

         The publish STAGE is deliberately not a row. It is created
         inside the publish destination and only after that
         destination's own precheck has passed, so it has no reachable
         hostile state of its own — and a row nothing can drive is
         documentation, which is the shape this table exists to
         replace (Doc F §1: the destination check is the precheck that
         makes the stage unreachable).

         SPRINT 19 ADDS THE THIRTEENTH ROW (§8 decision 65):
         parley.config.st (read), a new operator-editable file at the
         project root. It arrives with the table's full discipline
         rather than after failing once — held to the settled shape from
         the day it exists, which is the only moment when nothing has
         shipped depending on the wrong behaviour. Its carrier is
         ExecutionError by decision 72's precedent: the composition
         root's settled carrier for a filesystem precondition, a carrier
         and not an attribution.

         SORTED THE WAY 3.2.5 SORTS IT, WHICH PUTS THE NEW ROW BETWEEN
         Package.st (write) AND parley.lock (read) — String <= folds
         case, and the order here was taken from the toolchain rather
         than read off the page (finding F15)."
        <category: 'boundary table'>
        ^#('Package.st (read)' 'Package.st (write)'
           'parley.config.st (read)'
           'parley.lock (read)' 'parley.lock (write)'
           'the archive cache (write)' 'the exec script (read)'
           'the index cache (write)' 'the index entry (read)'
           'the publish destination (write)'
           'the source directory (read)' 'the star archive (read)'
           'the wiring state directory (write)')
    ]

    PathFixtures class >> namesOfBoundaryRolesIn: aTable [
        "The role column of the declared table, sorted."
        <category: 'boundary table'>
        ^((aTable collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    PathFixtures class >> directionsIn: aTable [
        "The direction column, paired with its role so a law asserts
         the PAIRING and not only the names."
        <category: 'boundary table'>
        ^((aTable collect: [:row |
            (row at: 1), ' -> ', (row at: 2) asString])
                asSortedCollection: [:a :b | a <= b]) asArray
    ]

    PathFixtures class >> declaredDirections [
        "The two directions, and the whole of them. A third would mean
         somebody invented a kind of file access."
        <category: 'boundary table'>
        ^#(#read #write)
    ]

    PathFixtures class >> declaredGuardings [
        "The two ways a row may be guarded, and the whole of them (§8
         decision 73). #guarded is precheck AND translate — the normal
         case and every row but one. #prechecked is precheck WITHOUT
         translation, which is a deliberate ruling rather than an
         omission and therefore has to be declared where a reviewer
         reads the table."
        <category: 'boundary table'>
        ^#(#guarded #prechecked)
    ]

    PathFixtures class >> precheckOnlyRoles [
        "The rows that precheck without translating, in table order.
         One: ManifestFile files the AUTHOR'S OWN PROGRAM in, and a
         broad translation around that would relabel a vocabulary typo
         or a division by zero as an I/O failure — decision 52's
         discriminator, in the one place this project has been most
         careful about blame. Sprint 18 owns that boundary.

         It is an oracle rather than a comment because Sprint 8's
         ManifestFile defect was a right sentence over a missing
         predicate that survived eight sprints, and it survived because
         the reasoning lived where nothing could compare it to code."
        <category: 'boundary table'>
        ^#('Package.st (read)')
    ]

    PathFixtures class >> tableWithoutRole: aRoleName in: aTable [
        "aTable with one row removed — the mutant a drift law is run
         against so it demonstrates that it detects drift."
        <category: 'boundary table'>
        ^aTable reject: [:row | (row at: 1) = aRoleName]
    ]

    "---- diagnosis structure (S15) ----"

    PathFixtures class >> pathPartOf: aLine [
        "The text before the first ': ' — the path a diagnosis names.
         Empty when the line names none, which is the whole failure S15
         exists to catch."
        <category: 'diagnosis structure'>
        | i |
        i := aLine indexOfSubCollection: ': '.
        i = 0 ifTrue: [^''].
        ^aLine copyFrom: 1 to: i - 1
    ]

    PathFixtures class >> causePartOf: aLine [
        "The text between ': ' and ' - ' (or to the end when the line
         carries no remedy)."
        <category: 'diagnosis structure'>
        | rest j |
        rest := self tailOf: aLine.
        j := rest indexOfSubCollection: ' - '.
        j = 0 ifTrue: [^rest].
        ^rest copyFrom: 1 to: j - 1
    ]

    PathFixtures class >> remedyPartOf: aLine [
        "The text after the first ' - '; empty when the line offers no
         remedy, which some rows legitimately do not (§8 decision 58 —
         a remedy is asserted only when it has been checked, and a row
         reporting on somebody else's index has none to offer)."
        <category: 'diagnosis structure'>
        | rest j |
        rest := self tailOf: aLine.
        j := rest indexOfSubCollection: ' - '.
        j = 0 ifTrue: [^''].
        ^rest copyFrom: j + 3 to: rest size
    ]

    PathFixtures class >> tailOf: aLine [
        "Private — everything after the first ': '."
        <category: 'diagnosis structure'>
        | i |
        i := aLine indexOfSubCollection: ': '.
        i = 0 ifTrue: [^''].
        ^aLine copyFrom: i + 2 to: aLine size
    ]

    "---- hostile working directories, one per scenario shape ----"

    PathFixtures class >> lockPathIn: aWorkDir [
        <category: 'working dirs'>
        ^aWorkDir, '/parley.lock'
    ]

    PathFixtures class >> packagePathIn: aWorkDir [
        <category: 'working dirs'>
        ^aWorkDir, '/Package.st'
    ]

    PathFixtures class >> parleyDirIn: aWorkDir [
        <category: 'working dirs'>
        ^aWorkDir, '/.parley'
    ]

    PathFixtures class >> contentsOf: aPath [
        <category: 'inspection'>
        ^(File name: aPath) contents
    ]

    PathFixtures class >> exists: aPath [
        <category: 'inspection'>
        ^(File name: aPath) exists
    ]

    "---- the boundary drivers, one per declared row ----"

    PathFixtures class >> freshDirTracking: track named: aLabel [
        <category: 'boundary drivers'>
        ^track value: (SourceFixtures directoryNamed: aLabel)
    ]

    PathFixtures class >> resolvableWorkDirTracking: track named: aLabel [
        <category: 'boundary drivers'>
        ^track value:
            (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    PathFixtures class >> diamondIndexTracking: track named: aLabel [
        "The settled diamond index WITH its archives — the pairing
         CliTest has used since Sprint 6, and the one whose resolution
         is ExecFixtures diamondLockString. The archive-less
         SourceFixtures diamond carries different digests and would
         make every lock oracle here a different file; add and install
         would also fail on the fetch, which is a refusal these
         scenarios must never be able to confuse with their own."
        <category: 'boundary drivers'>
        | path |
        path := self freshDirTracking: track named: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    PathFixtures class >> resultOf: anArgvArray in: aWorkDir [
        <category: 'boundary drivers'>
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    PathFixtures class >> resolveArgvOn: anIndexDir [
        <category: 'boundary drivers'>
        ^Array with: 'resolve' with: '--source' with: anIndexDir
    ]

    PathFixtures class >> installArgvOn: anIndexDir [
        <category: 'boundary drivers'>
        ^Array with: 'install' with: '--source' with: anIndexDir
    ]

    PathFixtures class >> makeStateDir: aName in: aWorkDir [
        "Create <aWorkDir>/.parley/<aName> and answer it — the state
         paths the wiring would otherwise create itself, made in
         advance so a law can take write permission away from ONE of
         them without taking it away from the working directory."
        <category: 'boundary drivers'>
        | parley path |
        parley := aWorkDir, '/.parley'.
        (File name: parley) exists ifFalse: [Directory create: parley].
        path := parley, '/', aName.
        (File name: path) exists ifFalse: [Directory create: path].
        ^path
    ]

    "---- the rows, and the hostile state each one is driven through ----"

    PathFixtures class >> readRowDriversTracking: track [
        "One driver per READ row, each over a path that exists and
         cannot be read. Every state is an ordinary operator state — a
         bad umask, a root-owned checkout, a chmod -R a-r cache."
        <category: 'boundary drivers'>
        ^self readRowDriversTracking: track
            labelled: 'row-read'
            hostile: [:path | self makeUnreadable: path]
    ]

    PathFixtures class >> readRowMirrorDriversTracking: track [
        "THE SAME READ ROWS UNDER THE MIRROR STATE — readable, and NOT
         writable. Nothing is refused here and nothing should be: a read
         boundary over a read-only file reads it perfectly well, which
         is why the law that drives these asserts ONLY that no row
         answers exit 70, a backtrace or kernel text, and never that a
         path is named or a code is 1.

         This is where an UNROUTED site still blows up. A read row whose
         verb goes on to write something — resolve reads Package.st and
         then writes parley.lock — meets its write boundary here with
         the read boundary satisfied, and that is exactly the crossing
         no single-direction driver exercises."
        <category: 'boundary drivers'>
        ^self readRowDriversTracking: track
            labelled: 'row-read-mirror'
            hostile: [:path | self makeReadOnly: path]
    ]

    PathFixtures class >> readRowDriversTracking: track labelled: aPrefix hostile: hostile [
        "The read rows, parameterized by the state applied to each
         row's path — so the primary drive and its mirror are ONE
         enumeration and cannot drift apart. Two enumerations of the
         same table is inventory row 22, one sprint after it was ruled."
        <category: 'boundary drivers'>
        | work index script srcIndex entryIndex starIndex lockWork lockIndex configWork configIndex configPath |
        work := self resolvableWorkDirTracking: track named: aPrefix, '-manifest-read-work'.
        index := self diamondIndexTracking: track named: aPrefix, '-manifest-read-index'.
        hostile value: (self packagePathIn: work).

        lockWork := self resolvableWorkDirTracking: track named: aPrefix, '-lock-read-work'.
        lockIndex := self diamondIndexTracking: track named: aPrefix, '-lock-read-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: lockWork.
        hostile value: (self lockPathIn: lockWork).

        script := self resolvableWorkDirTracking: track named: aPrefix, '-script-read-work'.
        SourceFixtures write: 'ObjectMemory quit: 0'
            toFile: 'run.st' in: script.
        hostile value: (script, '/run.st').

        srcIndex := self diamondIndexTracking: track named: aPrefix, '-directory-read-index'.
        hostile value: srcIndex.

        entryIndex := self diamondIndexTracking: track named: aPrefix, '-entry-read-index'.
        hostile value: (entryIndex, '/c-2.4.0.st').

        starIndex := self diamondIndexTracking: track named: aPrefix, '-archive-read-index'.
        hostile value: (starIndex, '/a-1.0.0.star').

        "The thirteenth row (Sprint 19). The project records a REAL
         index, so under the mirror state — readable and not writable —
         the config is read and the verb resolves exactly as it would
         have with the flag; only the hostile state refuses. A config
         naming nothing would make the mirror pass for the wrong
         reason."
        configWork := self resolvableWorkDirTracking: track named: aPrefix, '-config-read-work'.
        configIndex := self diamondIndexTracking: track named: aPrefix, '-config-read-index'.
        configPath := ConfigFixtures pathIn: configWork.
        ConfigFixtures write: (ConfigFixtures contentsDeclaring: '--source'
            value: (CommandLineFixtures absolutePathOf: configIndex))
            in: configWork.
        hostile value: configPath.

        ^(Array
            with: (Array with: 'Package.st (read)'
                with: (self packagePathIn: work)
                with: [self resultOf: (self resolveArgvOn: index) in: work]
                with: (CommandLineFixtures missingManifestProblemFor:
                    (self packagePathIn: work)))
            with: (Array with: 'parley.lock (read)'
                with: (self lockPathIn: lockWork)
                with: [self resultOf: (Array with: 'check'
                        with: '--source' with: lockIndex)
                    in: lockWork]
                with: (ReadinessFixtures unreadableLockProblemFor:
                    (self lockPathIn: lockWork)))
            with: (Array with: 'the exec script (read)'
                with: script, '/run.st'
                with: [self resultOf:
                    (Array with: 'exec' with: script, '/run.st')
                    in: script]
                with: (ReadinessFixtures execRefusalLineFor: script, '/run.st'))
            with: (Array with: 'the source directory (read)'
                with: srcIndex
                with: [self resultOf: (self resolveArgvOn: srcIndex)
                    in: (self resolvableWorkDirTracking: track named: aPrefix, '-directory-read-work')]
                with: (self missingDirectoryProblemFor: srcIndex))),
            (Array
                with: (Array with: 'the index entry (read)'
                    with: 'c-2.4.0.st'
                    with: [self resultOf: (self resolveArgvOn: entryIndex)
                        in: (self resolvableWorkDirTracking: track named: aPrefix, '-entry-read-work')]
                    with: (self unreadableEntryProblemFor: 'c-2.4.0.st'))
                with: (Array with: 'the star archive (read)'
                    with: 'a-1.0.0.star'
                    with: [self resultOf: (self installArgvOn: starIndex)
                        in: (self resolvableWorkDirTracking: track named: aPrefix, '-archive-read-work')]
                    with: (self unreadableArchiveProblemFor: 'a-1.0.0.star'))
                with: (Array with: 'parley.config.st (read)'
                    with: configPath
                    with: [self resultOf: (Array with: 'resolve')
                        in: configWork]
                    with: (ConfigFixtures unreadableLineFor: configPath)))
    ]

    PathFixtures class >> writeRowDriversTracking: track [
        "One driver per WRITE row, each over a path that exists and
         cannot be written. The three that are not verb-level
         boundaries — the wiring state directory, the archive cache and
         the index cache — are driven exactly like the rest (Doc E
         §4.1: they are rows like any other; what they lack is a remedy
         sentence of their own, because an operator does not choose
         where the content store lives)."
        <category: 'boundary drivers'>
        ^self writeRowDriversTracking: track
            labelled: 'row-write'
            hostile: [:path | self makeReadOnly: path]
    ]

    PathFixtures class >> writeRowMirrorDriversTracking: track [
        "THE SAME WRITE ROWS UNDER THE MIRROR STATE — unreadable. Some
         of these ARE refused, by their row's read sibling or by a
         boundary upstream of them, and some are not; which one happens
         is not the claim. The claim is the sprint's exit criterion,
         applied where an unrouted site is most likely to survive: no
         operator filesystem state answers the wrong exit code
         ANYWHERE, so the law that drives these asserts only never-70,
         no backtrace and no kernel text."
        <category: 'boundary drivers'>
        ^self writeRowDriversTracking: track
            labelled: 'row-write-mirror'
            hostile: [:path | self makeUnreadable: path]
    ]

    PathFixtures class >> writeRowDriversTracking: track labelled: aPrefix hostile: hostile [
        "The write rows, parameterized by the state applied to each
         row's path — one enumeration for the primary drive and its
         mirror, for the same reason the read rows are."
        <category: 'boundary drivers'>
        | manifestWork manifestIndex lockWork lockIndex publishWork publishDest stateWork stateIndex storeWork storeIndex store indexWork cacheRoot |
        manifestWork := self resolvableWorkDirTracking: track named: aPrefix, '-manifest-write-work'.
        manifestIndex := self diamondIndexTracking: track named: aPrefix, '-manifest-write-index'.
        hostile value: (self packagePathIn: manifestWork).

        lockWork := self resolvableWorkDirTracking: track named: aPrefix, '-lock-write-work'.
        lockIndex := self diamondIndexTracking: track named: aPrefix, '-lock-write-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: lockWork.
        hostile value: (self lockPathIn: lockWork).

        publishWork := self freshDirTracking: track named: aPrefix, '-publish-write-work'.
        PublishFixtures populateGreetingWorkDirIn: publishWork.
        publishDest := self freshDirTracking: track named: aPrefix, '-publish-write-dest'.
        hostile value: publishDest.

        stateWork := self resolvableWorkDirTracking: track named: aPrefix, '-state-write-work'.
        stateIndex := self diamondIndexTracking: track named: aPrefix, '-state-write-index'.
        hostile value: stateWork.

        storeWork := self resolvableWorkDirTracking: track named: aPrefix, '-store-write-work'.
        storeIndex := self diamondIndexTracking: track named: aPrefix, '-store-write-index'.
        store := self makeStateDir: 'store' in: storeWork.
        hostile value: store.

        indexWork := self resolvableWorkDirTracking: track named: aPrefix, '-cache-write-work'.
        cacheRoot := self makeStateDir: 'index' in: indexWork.
        hostile value: cacheRoot.

        ^(Array
            with: (Array with: 'Package.st (write)'
                with: (self packagePathIn: manifestWork)
                with: [self resultOf: (Array with: 'add' with: 'c'
                        with: '^2.0' with: '--source' with: manifestIndex)
                    in: manifestWork]
                with: (self unwritableLineFor: (self packagePathIn: manifestWork)))
            with: (Array with: 'parley.lock (write)'
                with: (self lockPathIn: lockWork)
                with: [self resultOf: (self resolveArgvOn: lockIndex)
                    in: lockWork]
                with: (self unwritableLineFor: (self lockPathIn: lockWork)))
            with: (Array with: 'the publish destination (write)'
                with: publishDest
                with: [self resultOf:
                    (Array with: 'publish' with: publishDest)
                    in: publishWork]
                with: (self unwritableLineFor: publishDest))
            with: (Array with: 'the wiring state directory (write)'
                with: stateWork
                with: [self resultOf: (self resolveArgvOn: stateIndex)
                    in: stateWork]
                with: (self unwritableLineFor: stateWork))),
            (Array
                with: (Array with: 'the archive cache (write)'
                    with: store
                    with: [self resultOf: (self installArgvOn: storeIndex)
                        in: storeWork]
                    with: (self unwritableLineFor:
                        store, '/', InstallFixtures digestA, '.star'))
                with: (Array with: 'the index cache (write)'
                    with: cacheRoot
                    with: [self resultOf: (Array with: 'resolve'
                            with: '--index' with: 'file:///nowhere')
                        in: indexWork]
                    with: (self unwritableLineFor: cacheRoot)))
    ]

    "---- the shipped wrapper (S18-S20) ----"

    PathFixtures class >> wrapperPath [
        "bin/parley — the command a user types, and the file §8
         decision 66 rewrites."
        <category: 'wrapper'>
        ^'bin/parley'
    ]

    PathFixtures class >> mainScriptRelativePath [
        "What the wrapper must find under PARLEY_ROOT."
        <category: 'wrapper'>
        ^'bin/parley-main.st'
    ]

    PathFixtures class >> symlinkAt: aLinkPath to: aTargetPath [
        "A symlink at aLinkPath pointing at aTargetPath, through
         3.2.5's own symlink primitive rather than a spawned ln — the
         fixture builds state, and ProcessRunner stays the one process
         seam. Answers the link path."
        <category: 'wrapper'>
        (File name: aLinkPath) exists ifTrue: [(File name: aLinkPath) remove].
        (File name: aTargetPath) symlinkAs: aLinkPath.
        ^aLinkPath
    ]

    PathFixtures class >> wrapperCommandAt: aWrapperPath in: aWorkDir args: anArgsString [
        "The shipped-wrapper command composed around an ARBITRARY
         wrapper path, so the laws can run bin/parley through a symlink
         without a second composition drifting from the settled
         shellWrapperCommandIn:args:."
        <category: 'wrapper'>
        ^'cd ', (CommandLineFixtures absolutePathOf: aWorkDir),
            ' && ', aWrapperPath, ' ', anArgsString
    ]

    PathFixtures class >> wrapperCommandAt: aWrapperPath in: aWorkDir args: anArgsString outputTo: anOutputPath [
        "The same command with the child's whole output captured, so a
         law can read exactly what the operator would see — including
         anything gst printed on its own behalf. The redirect is a
         test-composed shell tail; ProcessRunner still captures nothing
         (output capture stays deferred)."
        <category: 'wrapper'>
        ^(self wrapperCommandAt: aWrapperPath in: aWorkDir
            args: anArgsString), ' > ', anOutputPath, ' 2>&1'
    ]

    PathFixtures class >> wrapperCommandAt: aWrapperPath in: aWorkDir args: anArgsString root: aRootPath outputTo: anOutputPath [
        "The same command with PARLEY_ROOT pre-set and the child's whole
         output captured. The pre-set root is what makes S19's Given
         constructible at all: a wrapper that overwrites the variable
         cannot be pointed at an installation that is missing its main
         script."
        <category: 'wrapper'>
        ^'cd ', (CommandLineFixtures absolutePathOf: aWorkDir),
            ' && PARLEY_ROOT=', aRootPath, ' ', aWrapperPath, ' ',
            anArgsString, ' > ', anOutputPath, ' 2>&1'
    ]

    PathFixtures class >> relativeWrapperCommandWithArgs: anArgsString outputTo: anOutputPath [
        "./bin/parley — the wrapper invoked by a RELATIVE path from the
         checkout, which is the other half of S20's ordinary path and
         the one a contributor types. The cwd is the checkout itself;
         --version is answered before any state directory is created
         (§8 decision 57), so the run leaves nothing behind in it."
        <category: 'wrapper'>
        ^'cd ', CommandLineFixtures repoRoot, ' && ./', self wrapperPath,
            ' ', anArgsString, ' > ', anOutputPath, ' 2>&1'
    ]

    PathFixtures class >> gstMissingFileMarker [
        "The text gst prints for a main script it cannot open, and
         which S19 requires the operator NEVER to see: the wrapper
         checks rather than delegates, because gst -f <missing file>
         exits 0 (probed, 3.2.5 — the behaviour §8 decision 45 records
         for exec, reached here by the wrapper)."
        <category: 'wrapper'>
        ^'Couldn''t open file'
    ]
]

ExecutionError subclass: InventedIoError [

    <comment: 'An error class that exists only inside the test suite,
signaled from inside the block PathGuard guards. It is the S14a
driver, and it is deliberately NOT a SystemExceptions.FileError and
not a kernel error at all: a guard that enumerated error classes would
let it through, and the caller would receive an exit-70 sentence
blaming Parley for the operator''s filesystem.

Nothing in src/ knows this class exists, which is the point — the
claim under test is that the translation is TOTAL, and a translation
proved only against errors the implementer thought of proves the
enumeration rather than the totality.

It subclasses a DECLARED Parley error for the same reason
DerivedSourceError does: every Error subclass in the Parley namespace
must be accounted for by the §4.2 closed-set law, and a test double
that is accounted for by COVERAGE adds no name to any list. Coverage
is irrelevant to what this class is for — the guard never sees a class
name at all.'>
]

ExecutionError subclass: PathRefusal [

    <comment: 'The refusal double the PathGuard unit laws hand the
guard in place of a real boundary error. It carries the path the guard
named and nothing else, so a law can assert WHICH path was refused
without depending on any boundary''s wording — the wordings are
asserted where the boundaries are, in BoundaryTableTest and the
acceptance suite. Covered by the closed set through its superclass,
exactly as InventedIoError is.'>
]

Namespace current: Smalltalk.
