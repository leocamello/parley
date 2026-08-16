"Parley is itself a Parley package (architecture §8 decision 86): the
 package manager, packaged by itself. This manifest is authored like
 any other — the version is the literal the drift law holds equal to
 Parley version, and the fileIns name every source file under src/
 with its relative subdirectory path, in scripts/run-tests.st's load
 order, held to the tree by the recursive drift law. The showcase
 index the suite publishes this into is transient and never
 committed; no root parley.lock is committed either."

Parley define: [:pkg |
    pkg
        name: 'parley';
        version: '1.0.0';
        summary: 'Smalltalk packages, resolved by conversation.';
        author: 'Leonardo Nascimento';
        license: 'MIT';
        fileIns: #(
            'src/compat/Compat.st'
            'src/compat/PathGuard.st'
            'src/domain/Dependency.st'
            'src/domain/PathDependency.st'
            'src/domain/Version.st'
            'src/domain/VersionConstraint.st'
            'src/domain/VersionRange.st'
            'src/manifest/IndexEntryReader.st'
            'src/manifest/IndexEntryWriter.st'
            'src/manifest/LibraryManifest.st'
            'src/manifest/ManifestBuilder.st'
            'src/manifest/ManifestCapture.st'
            'src/manifest/ManifestEditor.st'
            'src/manifest/ManifestErrors.st'
            'src/manifest/Parley.st'
            'src/manifest/SchemaShape.st'
            'src/resolver/BacktrackingStrategy.st'
            'src/resolver/ConflictReport.st'
            'src/resolver/ConstraintAccumulation.st'
            'src/resolver/ConstraintLedger.st'
            'src/resolver/Incompatibility.st'
            'src/resolver/IndexSnapshot.st'
            'src/resolver/PinVerification.st'
            'src/resolver/Resolution.st'
            'src/resolver/Resolver.st'
            'src/resolver/Term.st'
            'src/source/DirectorySource.st'
            'src/source/GitIndexSource.st'
            'src/source/PathOverlay.st'
            'src/source/SourceError.st'
            'src/source/SparseIndexSource.st'
            'src/install/ContentStore.st'
            'src/install/InstalledSet.st'
            'src/install/Installer.st'
            'src/install/InstallError.st'
            'src/install/Sha256.st'
            'src/exec/CLI.st'
            'src/exec/CliResult.st'
            'src/exec/CommandLine.st'
            'src/exec/Configuration.st'
            'src/exec/ExecutionError.st'
            'src/exec/ExecutionScope.st'
            'src/exec/LockError.st'
            'src/exec/ManifestFile.st'
            'src/exec/ProcessRunner.st'
            'src/publish/Publisher.st'
            'src/publish/PublishError.st'
        ) ]
