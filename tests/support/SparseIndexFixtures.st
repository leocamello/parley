"Parley — Sprint 14 test fixtures (issue #16): the sparse-index base
 trees served over file://, the #'parley-listing' 1 texts (well-formed
 and each malformed kind), the pinned curl command lines and failure
 wordings, the pinned cache layout, the seed-carrying work dirs and
 locks, the usage-line additions, and the curl-counting helpers.

 Every base tree is a directory under tmp/ holding one subdirectory
 per package (Doc F §7.1): <base>/<name>/versions.st beside the
 settled entries and archives. The trees are metadata-only (#archive
 #()) except where a scenario installs — those carry real bytes and
 true digests.

 CountingProcessRunner is the recording seam the fetch-counting laws
 (S2, S3, S11, S15) read: it records every command line AND delegates
 to the settled ProcessRunner, which stays the only class that spawns.

 Stateless class-side factory; uniqueness comes from per-test labels.
 Base trees are NESTED, so teardown uses ExecFixtures removeTree:
 (recursive), never SourceFixtures removeTree: (flat)."

Namespace current: Parley.

Object subclass: SparseIndexFixtures [

    <comment: 'Class-side factory for Sprint 14 fixtures: file:// base
trees (two-level, cycle, absent-entry, grown, probe), malformed
listing variants with their pinned problem wordings, the pinned curl
command lines and grounds, the pinned cache layout, work dirs, lock
builders and curl-counting helpers. Stateless.'>

    "---- the listing text (Doc B §5.6) ----"

    SparseIndexFixtures class >> listingFileName [
        "The one artifact located by constructed URL rather than by
         scan: <base>/<name>/versions.st."
        <category: 'listing texts'>
        ^'versions.st'
    ]

    SparseIndexFixtures class >> listingFor: someVersionStrings [
        "The well-formed #'parley-listing' 1 text for the given
         version strings, ascending, deterministic whitespace, single
         trailing newline (Doc B §5.6)."
        <category: 'listing texts'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-listing'' 1 #versions #('.
        someVersionStrings
            do: [:each | out nextPutAll: ''''; nextPutAll: each;
                nextPutAll: '''']
            separatedBy: [out nextPutAll: ' '].
        out nextPutAll: '))'.
        ^out contents, SourceFixtures newline
    ]

    "---- malformed listing texts (S5), one per ground ----"

    SparseIndexFixtures class >> unreadableListingText [
        "Not a literal artifact at all — rejected by the settled
         reader at position 1."
        <category: 'malformed listings'>
        ^'frobnicate 1', SourceFixtures newline
    ]

    SparseIndexFixtures class >> wrongTagListingText [
        "A well-formed artifact of the WRONG schema where a listing
         must stand."
        <category: 'malformed listings'>
        ^'#(#''parley-lock'' 1 #root ''x'' #packages #())',
            SourceFixtures newline
    ]

    SparseIndexFixtures class >> missingVersionsListingText [
        "The right tag with the one schema key absent."
        <category: 'malformed listings'>
        ^'#(#''parley-listing'' 1)', SourceFixtures newline
    ]

    SparseIndexFixtures class >> nonStringMemberListingText [
        "A #versions member that is a legal micro-format literal but
         not a version String."
        <category: 'malformed listings'>
        ^'#(#''parley-listing'' 1 #versions #(42))',
            SourceFixtures newline
    ]

    SparseIndexFixtures class >> unparseableVersionListingText [
        "A String member that does not parse through the settled
         Version fromString:."
        <category: 'malformed listings'>
        ^'#(#''parley-listing'' 1 #versions #(''abc''))',
            SourceFixtures newline
    ]

    "---- the pinned listing problem wordings (S5, Doc F §7.2) ----"

    SparseIndexFixtures class >> listingLabelFor: aName [
        "How a problem names a listing file: relative to the base,
         the constructed-URL path — the only spelling of the file the
         operator and the index owner share."
        <category: 'pinned wordings'>
        ^aName, '/', self listingFileName
    ]

    SparseIndexFixtures class >> unreadableListingProblemFor: aName [
        "The settled reader's positioned parse error, prefixed with
         the file it struck — the DirectorySource malformed-entry
         grammar applied to the fourth boundary."
        <category: 'pinned wordings'>
        ^(self listingLabelFor: aName),
            ': Parse error at position 1: artifact must open with a literal array - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    SparseIndexFixtures class >> wrongTagListingProblemFor: aName tag: aTagPrintString [
        <category: 'pinned wordings'>
        ^(self listingLabelFor: aName),
            ': wrong artifact tag ', aTagPrintString,
            ' - a version listing holds #''parley-listing'' 1 artifacts'
    ]

    SparseIndexFixtures class >> missingVersionsKeyProblemFor: aName [
        <category: 'pinned wordings'>
        ^(self listingLabelFor: aName),
            ': missing schema key #versions'
    ]

    SparseIndexFixtures class >> nonStringMemberProblemFor: aName value: aValuePrintString [
        <category: 'pinned wordings'>
        ^(self listingLabelFor: aName),
            ': #versions member ', aValuePrintString,
            ' is not a version string'
    ]

    SparseIndexFixtures class >> unparseableVersionProblemFor: aName value: aString [
        "The value-shape grammar of Doc F §4.1, applied to the
         listing's one key."
        <category: 'pinned wordings'>
        ^(self listingLabelFor: aName),
            ': #versions ', aString printString,
            ' does not parse as a version'
    ]

    SparseIndexFixtures class >> missingEntryProblemFor: aName version: aVersionString [
        "The S8 index defect: an entry a listing NAMES and the index
         does not have — one problem naming both files, because the
         index made a claim it did not keep."
        <category: 'pinned wordings'>
        ^aName, '/', aName, '-', aVersionString, '.st: named by ',
            (self listingLabelFor: aName),
            ' but absent from the index'
    ]

    "---- the curl transport (Doc F §7, grounds declared closed) ----"

    SparseIndexFixtures class >> curlCommandFor: aUrl to: aFilePath [
        "The one transport command line, pinned."
        <category: 'pinned wordings'>
        ^'curl -sfS ', aUrl, ' -o ', aFilePath
    ]

    SparseIndexFixtures class >> curlFailureProblemFor: aCommandString code: anInteger [
        "An undeclared curl exit: one problem carrying the exact
         command line and exit code — the GitIndexSource
         transport-failure precedent verbatim."
        <category: 'pinned wordings'>
        ^'curl command failed with exit code ', anInteger printString,
            ': ', aCommandString
    ]

    "---- constructed URLs (Doc F §7.1) ----"

    SparseIndexFixtures class >> baseUrlFor: aDirPath [
        "The file:// base URL of a fixture tree — an absolute path,
         because the laws never depend on the process cwd."
        <category: 'urls'>
        ^'file://', (CommandLineFixtures absolutePathOf: aDirPath)
    ]

    SparseIndexFixtures class >> listingUrlFor: aBaseUrl name: aName [
        <category: 'urls'>
        ^aBaseUrl, '/', aName, '/', self listingFileName
    ]

    SparseIndexFixtures class >> entryUrlFor: aBaseUrl name: aName version: aVersionString [
        <category: 'urls'>
        ^aBaseUrl, '/', aName, '/', aName, '-', aVersionString, '.st'
    ]

    SparseIndexFixtures class >> archiveUrlFor: aBaseUrl name: aName version: aVersionString [
        <category: 'urls'>
        ^aBaseUrl, '/', aName, '/', aName, '-', aVersionString, '.star'
    ]

    "---- the pinned cache layout (Doc F §7.4) ----"

    SparseIndexFixtures class >> entriesDirIn: aCacheDir [
        "The flat directory the inner DirectorySource scans. Fetched
         entries land here; fetched archives land BESIDE them (the
         scan reads only .st files); listings NEVER do."
        <category: 'cache layout'>
        ^aCacheDir, '/entries'
    ]

    SparseIndexFixtures class >> listingsDirIn: aCacheDir [
        "Where fetched listings are cached: beside the entries
         directory, never in it (Doc F §7.3 — a prohibition, not an
         implication)."
        <category: 'cache layout'>
        ^aCacheDir, '/listings'
    ]

    SparseIndexFixtures class >> cachedListingPathIn: aCacheDir for: aName [
        <category: 'cache layout'>
        ^(self listingsDirIn: aCacheDir), '/', aName, '.st'
    ]

    SparseIndexFixtures class >> cachedEntryPathIn: aCacheDir for: aName version: aVersionString [
        <category: 'cache layout'>
        ^(self entriesDirIn: aCacheDir), '/', aName, '-',
            aVersionString, '.st'
    ]

    SparseIndexFixtures class >> cachedArchivePathIn: aCacheDir for: aName version: aVersionString [
        <category: 'cache layout'>
        ^(self entriesDirIn: aCacheDir), '/', aName, '-',
            aVersionString, '.star'
    ]

    SparseIndexFixtures class >> indexCacheRootIn: aWorkDir [
        "The --index cache root under the WORKING directory — the
         --git convention applied to the second remote source."
        <category: 'cache layout'>
        ^(CommandLineFixtures parleyDirIn: aWorkDir), '/index'
    ]

    SparseIndexFixtures class >> indexCachePathIn: aWorkDir forBase: aBaseUrl [
        "One base URL's cache: keyed through the settled Sha256, so
         any URL becomes one deterministic filesystem-safe name."
        <category: 'cache layout'>
        ^(self indexCacheRootIn: aWorkDir), '/',
            (Sha256 hexDigestOf: aBaseUrl)
    ]

    SparseIndexFixtures class >> cwdIndexCacheRoot [
        "The path a cwd-derived wiring would create beside the process
         cwd — asserted ABSENT, never .parley/ itself (the Sprint 8
         precedent)."
        <category: 'cache layout'>
        ^'.parley/index'
    ]

    "---- usage-line additions (pinned here; ExecFixtures usageLines
          is re-pinned in GREEN with the CommandLine change, the
          Sprint 11/12/13 precedent) ----"

    SparseIndexFixtures class >> usageHeaderLine [
        <category: 'usage pins'>
        ^'usage: parley <verb> [--source <dir> | --git <repo> | --index <base>]'
    ]

    SparseIndexFixtures class >> indexFlagUsageLine [
        <category: 'usage pins'>
        ^'       --index <base>  index entries fetched per package from a sparse index'
    ]

    "---- building base trees ----"

    SparseIndexFixtures class >> baseTreeNamed: aLabel [
        "A fresh, empty base tree under tmp/. The caller tracks it for
         RECURSIVE teardown (ExecFixtures removeTree:) — base trees
         hold per-package subdirectories."
        <category: 'base trees'>
        ^SourceFixtures directoryNamed: aLabel
    ]

    SparseIndexFixtures class >> packageDirFor: aName in: aBasePath [
        "Ensure and answer <base>/<name>."
        <category: 'base trees'>
        | path |
        path := aBasePath, '/', aName.
        (File name: path) exists ifFalse: [Directory create: path].
        ^path
    ]

    SparseIndexFixtures class >> writeListing: aText for: aName in: aBasePath [
        "Place aText where the constructed listing URL points."
        <category: 'base trees'>
        SourceFixtures write: aText
            toFile: self listingFileName
            in: (self packageDirFor: aName in: aBasePath)
    ]

    SparseIndexFixtures class >> writeEntry: aText for: aName version: aVersionString in: aBasePath [
        <category: 'base trees'>
        SourceFixtures write: aText
            toFile: aName, '-', aVersionString, '.st'
            in: (self packageDirFor: aName in: aBasePath)
    ]

    SparseIndexFixtures class >> entryFor: aName version: aVersionString dependencies: someDepPairs [
        "A Doc B §5.2 schema-exact metadata-only entry (#archive #()).
         someDepPairs is an Array of two-element Arrays
         (name, constraint string), already sorted by name."
        <category: 'base trees'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-index'' 1 #name ''';
            nextPutAll: aName;
            nextPutAll: ''' #version ''';
            nextPutAll: aVersionString;
            nextPutAll: ''' #summary '''' #author '''' #license '''' #fileIns #(''Lib.st'') #dependencies #('.
        someDepPairs
            do: [:pair | out nextPutAll: '#(''';
                nextPutAll: (pair at: 1);
                nextPutAll: ''' ''';
                nextPutAll: (pair at: 2);
                nextPutAll: ''')']
            separatedBy: [out nextPutAll: ' '].
        out nextPutAll: ') #archive #())'.
        ^out contents, SourceFixtures newline
    ]

    SparseIndexFixtures class >> entryFor: aName version: aVersionString dependencies: someDepPairs archive: aDigest [
        "The same, carrying a published archive with its true digest."
        <category: 'base trees'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-index'' 1 #name ''';
            nextPutAll: aName;
            nextPutAll: ''' #version ''';
            nextPutAll: aVersionString;
            nextPutAll: ''' #summary '''' #author '''' #license '''' #fileIns #(''Lib.st'') #dependencies #('.
        someDepPairs
            do: [:pair | out nextPutAll: '#(''';
                nextPutAll: (pair at: 1);
                nextPutAll: ''' ''';
                nextPutAll: (pair at: 2);
                nextPutAll: ''')']
            separatedBy: [out nextPutAll: ' '].
        out nextPutAll: ') #archive #('''; nextPutAll: aName;
            nextPutAll: '-'; nextPutAll: aVersionString;
            nextPutAll: '.star'' #sha256 ''';
            nextPutAll: aDigest;
            nextPutAll: '''))'.
        ^out contents, SourceFixtures newline
    ]

    SparseIndexFixtures class >> publish: aName version: aVersionString dependencies: someDepPairs in: aBasePath [
        "One metadata-only release: a fresh single-version listing and
         its entry."
        <category: 'base trees'>
        self writeListing: (self listingFor: (Array with: aVersionString))
            for: aName in: aBasePath.
        self writeEntry: (self entryFor: aName
                version: aVersionString
                dependencies: someDepPairs)
            for: aName version: aVersionString in: aBasePath
    ]

    SparseIndexFixtures class >> publish: aName version: aVersionString dependencies: someDepPairs archiveBytes: someBytes in: aBasePath [
        "One installable release: listing, entry with the bytes' true
         digest, and the archive itself."
        <category: 'base trees'>
        | digest |
        digest := Sha256 hexDigestOf: someBytes.
        self writeListing: (self listingFor: (Array with: aVersionString))
            for: aName in: aBasePath.
        self writeEntry: (self entryFor: aName
                version: aVersionString
                dependencies: someDepPairs
                archive: digest)
            for: aName version: aVersionString in: aBasePath.
        SourceFixtures write: someBytes
            toFile: aName, '-', aVersionString, '.star'
            in: (self packageDirFor: aName in: aBasePath)
    ]

    "---- the canonical trees ----"

    SparseIndexFixtures class >> populateTwoLevelTreeIn: aBasePath [
        "S1/S2: root-dep 1.0.0 -> deep ^1.0; deep 1.0.0. The operator
         names root-dep; the closure must reach deep."
        <category: 'canonical trees'>
        self publish: 'root-dep' version: '1.0.0'
            dependencies: (Array with: #('deep' '^1.0'))
            in: aBasePath.
        self publish: 'deep' version: '1.0.0'
            dependencies: #()
            in: aBasePath
    ]

    SparseIndexFixtures class >> addUnrelatedTo: aBasePath [
        "S2: a package no manifest reaches — the one the counting law
         proves was never fetched."
        <category: 'canonical trees'>
        self publish: 'unrelated' version: '1.0.0'
            dependencies: #()
            in: aBasePath
    ]

    SparseIndexFixtures class >> populateCycleTreeIn: aBasePath [
        "S3: cyc-a 1.0.0 <-> cyc-b 1.0.0 — the fixpoint-termination
         fixture."
        <category: 'canonical trees'>
        self publish: 'cyc-a' version: '1.0.0'
            dependencies: (Array with: #('cyc-b' '^1.0'))
            in: aBasePath.
        self publish: 'cyc-b' version: '1.0.0'
            dependencies: (Array with: #('cyc-a' '^1.0'))
            in: aBasePath
    ]

    SparseIndexFixtures class >> addLegacyTo: aBasePath [
        "S4: the package only a lock still pins."
        <category: 'canonical trees'>
        self publish: 'legacy' version: '1.0.0'
            dependencies: #()
            in: aBasePath
    ]

    SparseIndexFixtures class >> populateAbsentEntryTreeIn: aBasePath [
        "S8: holey's listing names 1.0.0 and 2.0.0; only the 1.0.0
         entry exists — the index made a claim it did not keep."
        <category: 'canonical trees'>
        self writeListing: (self listingFor: #('1.0.0' '2.0.0'))
            for: 'holey' in: aBasePath.
        self writeEntry: (self entryFor: 'holey'
                version: '1.0.0' dependencies: #())
            for: 'holey' version: '1.0.0' in: aBasePath
    ]

    SparseIndexFixtures class >> growDeepIn: aBasePath [
        "S15: the upstream publish after a first snapshot — deep's
         listing gains 1.1.0 and the new entry appears; every
         already-cached artifact is byte-identical."
        <category: 'canonical trees'>
        self writeListing: (self listingFor: #('1.0.0' '1.1.0'))
            for: 'deep' in: aBasePath.
        self writeEntry: (self entryFor: 'deep'
                version: '1.1.0' dependencies: #())
            for: 'deep' version: '1.1.0' in: aBasePath
    ]

    SparseIndexFixtures class >> populateProbeTreeIn: aBasePath bytes: starBytes [
        "S11/S14: parley-probe 1.0.0 with the real toolchain-built
         star and its true digest, in the sparse layout."
        <category: 'canonical trees'>
        | digest |
        digest := Sha256 hexDigestOf: starBytes.
        self writeListing: (self listingFor: #('1.0.0'))
            for: 'parley-probe' in: aBasePath.
        self writeEntry: (ExecFixtures probeEntryWithDigest: digest)
            for: 'parley-probe' version: '1.0.0' in: aBasePath.
        SourceFixtures write: starBytes
            toFile: 'parley-probe-1.0.0.star'
            in: (self packageDirFor: 'parley-probe' in: aBasePath)
    ]

    "---- work dirs and locks ----"

    SparseIndexFixtures class >> packageContentsDeclaring: aName constraint: aConstraintString [
        "A my-app Package.st declaring exactly one dependency — the
         settled diamond-root shape with one clause."
        <category: 'work dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''', aName, ''' constraint: ''',
            aConstraintString, ''' ]', SourceFixtures newline
    ]

    SparseIndexFixtures class >> workDirNamed: aLabel declaring: aName constraint: aConstraintString [
        "A working directory whose Package.st declares exactly one
         dependency. The caller tracks it for teardown."
        <category: 'work dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage:
            (self packageContentsDeclaring: aName
                constraint: aConstraintString)
            in: path.
        ^path
    ]

    SparseIndexFixtures class >> lockPinning: someNameVersionPairs [
        "A byte-stable #'parley-lock' 1 text pinning the given
         (name, version string) pairs for root my-app, each with the
         empty digest of a metadata-only release. The pairs arrive
         sorted by name — the serialization rule, the caller's duty."
        <category: 'work dirs'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-lock'' 1 #root ''my-app'' #packages #('.
        someNameVersionPairs
            do: [:pair | out nextPutAll: '#(''';
                nextPutAll: (pair at: 1);
                nextPutAll: ''' ''';
                nextPutAll: (pair at: 2);
                nextPutAll: ''' #sha256 '''')']
            separatedBy: [out nextPutAll: ' '].
        out nextPutAll: '))'.
        ^out contents, SourceFixtures newline
    ]

    SparseIndexFixtures class >> writeLock: aLockText in: aWorkDir [
        <category: 'work dirs'>
        SourceFixtures write: aLockText toFile: 'parley.lock' in: aWorkDir
    ]

    "---- curl counting over recorded command lines ----"

    SparseIndexFixtures class >> commands: someCommandStrings naming: aSubstring [
        "Every recorded command line that mentions aSubstring — the
         counting primitive of S2, S3, S11 and S15. Counted, never
         inferred from timing, the lock, or the cache's contents."
        <category: 'curl counting'>
        ^someCommandStrings select: [:each |
            CommandLineFixtures does: each include: aSubstring]
    ]

    SparseIndexFixtures class >> count: aSubstring in: someCommandStrings [
        <category: 'curl counting'>
        ^(self commands: someCommandStrings naming: aSubstring) size
    ]

    SparseIndexFixtures class >> curlCommandsIn: someCommandStrings [
        <category: 'curl counting'>
        ^self commands: someCommandStrings naming: 'curl '
    ]
]

Object subclass: CountingProcessRunner [
    | inner commands |

    <comment: 'The recording seam of the fetch-counting laws: records
every command line it is asked to run AND delegates to the settled
ProcessRunner, which stays the only class that spawns. The mutable
recording makes it an edge object like the settled fixture doubles —
never domain.'>

    CountingProcessRunner class >> new [
        <category: 'instance creation'>
        ^self basicNew init
    ]

    init [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        inner := ProcessRunner new.
        commands := OrderedCollection new
    ]

    run: aCommandString [
        <category: 'runner protocol'>
        commands add: aCommandString.
        ^inner run: aCommandString
    ]

    commands [
        "Every recorded command line, in run order, as an Array."
        <category: 'accessing'>
        ^commands asArray
    ]
]

Namespace current: Smalltalk.
