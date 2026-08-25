@echo off
rem GENERATED FILE: contributors should edit the source files in src.
rem Rebuild the ready-to-run batch with build\Build-Release.ps1.
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "TRCF_SELF=%~f0"
set "TRCF_ARG_COUNT=0"
set "TRCF_HAD_ARGS=0"
set "TRCF_WAIT_ON_ERROR=0"

:trcf_collect_args
if "%~1"=="" goto trcf_launch
set "TRCF_HAD_ARGS=1"
set /a TRCF_ARG_COUNT+=1 >nul
set "TRCF_ARG_%TRCF_ARG_COUNT%=%~1"
shift
goto trcf_collect_args

:trcf_launch
if "%TRCF_ELEVATED_LAUNCH%"=="1" set "TRCF_HAD_ARGS=1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:TRCF_SELF;$m='#'+'__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__';$t=[IO.File]::ReadAllText($p);$i=$t.IndexOf($m,[StringComparison]::Ordinal);if($i -lt 0){throw 'The embedded PowerShell marker is missing.'};$c=$t.Substring($i+$m.Length);$h=@{StandaloneBatchPath=$p};if($env:TRCF_ELEVATED_LAUNCH -eq '1'){$h.ExePath=$env:TRCF_ELEVATED_EXE;$h.Action=$env:TRCF_ELEVATED_ACTION;$h.PauseAfterAction=$true;if($h.Action -eq 'Apply'){$h.ApplyConfirmed=$true};if($env:TRCF_ELEVATED_FAILURE){$h.TestFailurePoint=$env:TRCF_ELEVATED_FAILURE}}else{$n=[int]$env:TRCF_ARG_COUNT;for($j=1;$j -le $n;$j++){$v=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');if($v -ieq '-Action'){if($j -ge $n){throw '-Action requires a value.'};$j++;$h.Action=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');continue};if($v -ieq '-ApplyConfirmed'){$h.ApplyConfirmed=$true;continue};if($v -ieq '-PauseAfterAction'){$h.PauseAfterAction=$true;continue};if($v -ieq '-TestFailurePoint'){if($j -ge $n){throw '-TestFailurePoint requires a value.'};$j++;$h.TestFailurePoint=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');continue};if($h.ContainsKey('ExePath')){throw ('Unknown extra argument: '+$v)};$h.ExePath=$v}};& ([ScriptBlock]::Create($c)) @h"
set "TRCF_EXIT=%ERRORLEVEL%"
if "%TRCF_EXIT%"=="0" goto trcf_return
echo.
echo Tomb Raider Complete Camera Fix stopped with an error. Exit code: %TRCF_EXIT%
if "%TRCF_HAD_ARGS%"=="0" set "TRCF_WAIT_ON_ERROR=1"
if "%TRCF_FORCE_WAIT_ON_ERROR%"=="1" set "TRCF_WAIT_ON_ERROR=1"
if not "%TRCF_WAIT_ON_ERROR%"=="1" goto trcf_return
echo Press any key to close this window...
pause >nul

:trcf_return
endlocal & exit /b %TRCF_EXIT%

#__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ExePath,

    [ValidateSet('Menu', 'Status', 'Apply', 'Restore')]
    [string]$Action = 'Menu',

    [switch]$ApplyConfirmed,

    [switch]$PauseAfterAction,

    [switch]$LibraryMode,

    # Set only by the self-reading hybrid BAT. Kept as a normal string so the
    # embedded source stays transparent and testable.
    [string]$StandaloneBatchPath,

    # Safe failure injection used by the disposable-fixture test suites.
    [ValidateSet('None', 'AfterBackup', 'AfterTempWrite', 'BeforeReplace', 'AfterReplace')]
    [string]$TestFailurePoint = 'None',

    [switch]$ElevatedFromEnvironment
)
# BEGIN GENERATED SOURCE: src/CameraFixEngine.ps1
# Tomb Raider Complete Camera Fix - testable patching engine
# This file contains no interactive UI and never searches a Steam installation.

$script:CameraFixToolName = 'Tomb Raider Complete Camera Fix'
$script:CameraFixManifestSchema = 1

function ConvertFrom-CameraFixHex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hex
    )

    $compact = $Hex -replace '\s', ''
    if (($compact.Length -eq 0) -or (($compact.Length % 2) -ne 0) -or ($compact -notmatch '\A[0-9A-Fa-f]+\z')) {
        throw "Invalid hexadecimal byte string: '$Hex'"
    }

    $bytes = New-Object byte[] ($compact.Length / 2)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        $bytes[$index] = [Convert]::ToByte($compact.Substring($index * 2, 2), 16)
    }
    return [byte[]]$bytes
}

$script:CameraFixDefinitions = @(
    [pscustomobject]@{
        Key = 'Wobble'
        Name = 'Gameplay camera wobble / head-bob'
        Original = [byte[]](ConvertFrom-CameraFixHex '8B CF E8 DB FD 41 00 84 C0 74 14 56')
        Patched = [byte[]](ConvertFrom-CameraFixHex '8B CF E8 DB FD 41 00 84 C0 EB 14 56')
    },
    [pscustomobject]@{
        Key = 'Horizontal'
        Name = 'Horizontal auto-centering'
        Original = [byte[]](ConvertFrom-CameraFixHex '08 B0 01 D9 9E A0 0F 00 00')
        Patched = [byte[]](ConvertFrom-CameraFixHex '08 B0 01 90 90 90 90 90 90')
    },
    [pscustomobject]@{
        Key = 'Vertical'
        Name = 'Vertical auto-centering'
        Original = [byte[]](ConvertFrom-CameraFixHex 'D9 5E 04 D9 44 24 0C D9 5E 0C D9 44 24 18 D9 5E 10 C6 87 C4 0F 00 00 01 E9 A2 FE FF FF DD D8 6A 00 D9 87 40 06 00 00 83 EC 0C D9 5C 24')
        Patched = [byte[]](ConvertFrom-CameraFixHex 'D9 5E 20 D9 44 24 0C D9 5E 0C D9 44 24 18 D9 5E 10 C6 87 C4 0F 00 00 01 E9 A2 FE FF FF DD D8 6A 00 D9 87 40 06 00 00 83 EC 0C D9 5C 24')
    }
)

function Get-CameraFixDefinitions {
    [CmdletBinding()]
    param()

    return @($script:CameraFixDefinitions)
}

function Get-CameraFixSha256FromBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash($Bytes)
        return (($hashBytes | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-CameraFixFileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash($stream)
        return (($hashBytes | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Find-CameraFixBytePattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BinaryText,

        [Parameter(Mandatory = $true)]
        [byte[]]$Pattern
    )

    # ISO-8859-1 maps every byte to exactly one character, allowing the native
    # .NET ordinal IndexOf implementation to search a binary safely and quickly.
    $patternText = [Text.Encoding]::GetEncoding(28591).GetString($Pattern)
    $offsets = New-Object 'System.Collections.Generic.List[long]'
    $start = 0
    while ($start -le ($BinaryText.Length - $patternText.Length)) {
        $found = $BinaryText.IndexOf($patternText, $start, [StringComparison]::Ordinal)
        if ($found -lt 0) {
            break
        }
        $offsets.Add([long]$found)
        $start = $found + 1
    }
    return @($offsets.ToArray())
}

function Get-CameraFixPatternAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $binaryText = [Text.Encoding]::GetEncoding(28591).GetString($Bytes)
    $analysis = foreach ($definition in $script:CameraFixDefinitions) {
        $originalOffsets = @(Find-CameraFixBytePattern -BinaryText $binaryText -Pattern $definition.Original)
        $patchedOffsets = @(Find-CameraFixBytePattern -BinaryText $binaryText -Pattern $definition.Patched)

        $classification = 'Ambiguous'
        $explanation = $null
        if (($originalOffsets.Count -eq 1) -and ($patchedOffsets.Count -eq 0)) {
            $classification = 'Unpatched'
        }
        elseif (($originalOffsets.Count -eq 0) -and ($patchedOffsets.Count -eq 1)) {
            $classification = 'Patched'
        }
        elseif (($originalOffsets.Count -eq 0) -and ($patchedOffsets.Count -eq 0)) {
            $classification = 'Missing'
            $explanation = 'Neither the complete original sequence nor the complete patched sequence was found.'
        }
        elseif (($originalOffsets.Count -gt 1) -or ($patchedOffsets.Count -gt 1)) {
            $classification = 'Duplicated'
            $explanation = 'A complete sequence occurs more than once, so there is no unique patch location.'
        }
        else {
            $classification = 'Conflicting'
            $explanation = 'Original and patched sequences are both present, so the intended location is not unambiguous.'
        }

        [pscustomobject]@{
            Key = $definition.Key
            Name = $definition.Name
            Classification = $classification
            Explanation = $explanation
            OriginalCount = $originalOffsets.Count
            PatchedCount = $patchedOffsets.Count
            OriginalOffsets = @($originalOffsets)
            PatchedOffsets = @($patchedOffsets)
            OriginalBytes = [byte[]]$definition.Original
            PatchedBytes = [byte[]]$definition.Patched
        }
    }
    return @($analysis)
}

function Get-CameraFixPeMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Bytes.Length -lt 256) {
        throw 'The file is too small to be a valid Windows PE executable.'
    }
    if (($Bytes[0] -ne 0x4D) -or ($Bytes[1] -ne 0x5A)) {
        throw 'The DOS MZ signature is missing.'
    }

    $peOffset = [BitConverter]::ToInt32($Bytes, 0x3C)
    if (($peOffset -lt 0x40) -or ($peOffset -gt ($Bytes.Length - 96))) {
        throw 'The PE header offset is outside the file.'
    }
    if ([Text.Encoding]::ASCII.GetString($Bytes, $peOffset, 4) -ne "PE`0`0") {
        throw 'The Windows PE signature is missing or corrupt.'
    }

    $machine = [BitConverter]::ToUInt16($Bytes, $peOffset + 4)
    $sectionCount = [BitConverter]::ToUInt16($Bytes, $peOffset + 6)
    $optionalHeaderSize = [BitConverter]::ToUInt16($Bytes, $peOffset + 20)
    $characteristics = [BitConverter]::ToUInt16($Bytes, $peOffset + 22)
    $optionalOffset = $peOffset + 24

    if (($sectionCount -lt 1) -or ($sectionCount -gt 96)) {
        throw 'The PE section count is invalid.'
    }
    if ($optionalHeaderSize -lt 72) {
        throw 'The PE optional header is missing or too small.'
    }
    if (($optionalOffset + $optionalHeaderSize + ($sectionCount * 40)) -gt $Bytes.Length) {
        throw 'The PE headers extend beyond the end of the file.'
    }
    if (($characteristics -band 0x0002) -eq 0) {
        throw 'The PE file is not marked as an executable image.'
    }

    $optionalMagic = [BitConverter]::ToUInt16($Bytes, $optionalOffset)
    $checksumOffset = $optionalOffset + 64
    $subsystem = [BitConverter]::ToUInt16($Bytes, $optionalOffset + 68)
    $dllCharacteristics = [BitConverter]::ToUInt16($Bytes, $optionalOffset + 70)
    $storedChecksum = [BitConverter]::ToUInt32($Bytes, $checksumOffset)

    $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    $versionTuple = '{0}.{1}.{2}.{3}' -f $versionInfo.FileMajorPart, $versionInfo.FileMinorPart, $versionInfo.FileBuildPart, $versionInfo.FilePrivatePart

    return [pscustomobject]@{
        IsValidPe = $true
        Machine = $machine
        MachineHex = ('0x{0:X4}' -f $machine)
        SectionCount = $sectionCount
        Characteristics = $characteristics
        OptionalMagic = $optionalMagic
        OptionalMagicHex = ('0x{0:X4}' -f $optionalMagic)
        Subsystem = $subsystem
        DllCharacteristics = $dllCharacteristics
        StoredChecksum = $storedChecksum
        ChecksumFileOffset = $checksumOffset
        FileVersion = $versionTuple
        DisplayFileVersion = $versionInfo.FileVersion
        ProductVersion = $versionInfo.ProductVersion
        FileMajorPart = $versionInfo.FileMajorPart
        FileMinorPart = $versionInfo.FileMinorPart
        FileBuildPart = $versionInfo.FileBuildPart
        FilePrivatePart = $versionInfo.FilePrivatePart
        IsBuild743 = (($versionInfo.FileMajorPart -eq 1) -and
                      ($versionInfo.FileMinorPart -eq 1) -and
                      ($versionInfo.FileBuildPart -eq 743) -and
                      ($versionInfo.FilePrivatePart -eq 0))
        IsExpectedArchitecture = (($machine -eq 0x014C) -and ($optionalMagic -eq 0x010B))
        IsGuiExecutable = ($subsystem -eq 2)
    }
}

function Get-CameraFixInspection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$RequireTargetName
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($fullPath)) {
        throw "The selected file does not exist: $fullPath"
    }
    if ($RequireTargetName -and ([IO.Path]::GetFileName($fullPath) -ine 'TombRaider.exe')) {
        throw "The selected file must be named TombRaider.exe. Selected name: $([IO.Path]::GetFileName($fullPath))"
    }

    $bytes = [IO.File]::ReadAllBytes($fullPath)
    $pe = Get-CameraFixPeMetadata -Bytes $bytes -Path $fullPath
    $patterns = @(Get-CameraFixPatternAnalysis -Bytes $bytes)
    $sha256 = Get-CameraFixSha256FromBytes -Bytes $bytes

    $patternsAreUnique = (@($patterns | Where-Object { $_.Classification -notin @('Unpatched', 'Patched') }).Count -eq 0)
    $isCompatible = ($pe.IsBuild743 -and $pe.IsExpectedArchitecture -and $pe.IsGuiExecutable -and $patternsAreUnique)

    return [pscustomobject]@{
        Path = $fullPath
        Filename = [IO.Path]::GetFileName($fullPath)
        Size = [int64]$bytes.Length
        SHA256 = $sha256
        Pe = $pe
        Patterns = @($patterns)
        PatternsAreUnique = $patternsAreUnique
        IsCompatible = $isCompatible
        Bytes = [byte[]]$bytes
    }
}

function Get-CameraFixStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $fullPath = $Path
    try {
        $fullPath = [IO.Path]::GetFullPath($Path)
        $inspection = Get-CameraFixInspection -Path $fullPath -RequireTargetName
    }
    catch {
        return [pscustomobject]@{
            Path = $fullPath
            Filename = [IO.Path]::GetFileName($fullPath)
            Size = $null
            SHA256 = $null
            FileVersion = $null
            State = 'Unsupported'
            IsCompatible = $false
            Reason = $_.Exception.Message
            Pe = $null
            Patterns = @()
        }
    }

    $state = 'Unsupported'
    $reason = $null
    if (-not $inspection.Pe.IsExpectedArchitecture) {
        $reason = "This is not the expected 32-bit x86 Tomb Raider executable (machine $($inspection.Pe.MachineHex), optional header $($inspection.Pe.OptionalMagicHex))."
    }
    elseif (-not $inspection.Pe.IsGuiExecutable) {
        $reason = 'This PE file is not a normal Windows GUI executable.'
    }
    elseif (-not $inspection.Pe.IsBuild743) {
        $reason = "File version $($inspection.Pe.FileVersion) is not supported. Steam build 743.0 must report file version 1.1.743.0."
    }
    elseif (-not $inspection.PatternsAreUnique) {
        $bad = @($inspection.Patterns | Where-Object { $_.Classification -notin @('Unpatched', 'Patched') })
        $reason = (($bad | ForEach-Object { "$($_.Name): $($_.Classification) - $($_.Explanation)" }) -join ' ')
    }
    else {
        $patchedCount = @($inspection.Patterns | Where-Object { $_.Classification -eq 'Patched' }).Count
        if ($patchedCount -eq 0) {
            $state = 'Unpatched'
        }
        elseif ($patchedCount -eq $script:CameraFixDefinitions.Count) {
            $state = 'CompletelyPatched'
        }
        else {
            $state = 'PartiallyPatched'
        }
    }

    return [pscustomobject]@{
        Path = $inspection.Path
        Filename = $inspection.Filename
        Size = $inspection.Size
        SHA256 = $inspection.SHA256
        FileVersion = $inspection.Pe.FileVersion
        State = $state
        IsCompatible = ($state -ne 'Unsupported')
        Reason = $reason
        Pe = $inspection.Pe
        Patterns = @($inspection.Patterns)
    }
}

function Get-CameraFixSidecarPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath
    )

    $fullPath = [IO.Path]::GetFullPath($ExePath)
    return [pscustomobject]@{
        BackupPath = $fullPath + '.trcamera-original.bak'
        ManifestPath = $fullPath + '.trcamera-original.json'
    }
}

function Copy-CameraFixFileCreateNew {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $inputStream = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $inputStream.CopyTo($outputStream)
            $outputStream.Flush()
        }
        finally {
            $outputStream.Dispose()
        }
    }
    finally {
        $inputStream.Dispose()
    }
}

function Test-CameraFixOriginalBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath
    )

    $sidecars = Get-CameraFixSidecarPaths -ExePath $ExePath
    $backupExists = [IO.File]::Exists($sidecars.BackupPath)
    $manifestExists = [IO.File]::Exists($sidecars.ManifestPath)
    if (-not $backupExists -and -not $manifestExists) {
        return [pscustomobject]@{ Valid = $false; Exists = $false; Reason = 'No original backup and manifest exist yet.'; Sidecars = $sidecars; Manifest = $null; Inspection = $null }
    }
    if (-not $backupExists -or -not $manifestExists) {
        return [pscustomobject]@{ Valid = $false; Exists = $true; Reason = 'The backup set is incomplete. The tool will not replace or trust either sidecar file.'; Sidecars = $sidecars; Manifest = $null; Inspection = $null }
    }

    try {
        $manifestText = [IO.File]::ReadAllText($sidecars.ManifestPath)
        $manifest = $manifestText | ConvertFrom-Json
        if ([int]$manifest.SchemaVersion -ne $script:CameraFixManifestSchema) {
            throw "Unsupported manifest schema: $($manifest.SchemaVersion)"
        }
        if ([string]$manifest.OriginalFilename -ine 'TombRaider.exe') {
            throw 'The manifest does not identify TombRaider.exe.'
        }

        $inspection = Get-CameraFixInspection -Path $sidecars.BackupPath
        if (-not $inspection.Pe.IsBuild743 -or -not $inspection.Pe.IsExpectedArchitecture -or -not $inspection.Pe.IsGuiExecutable) {
            throw 'The backup is not a compatible build-743 PE executable.'
        }
        if (@($inspection.Patterns | Where-Object { $_.Classification -ne 'Unpatched' }).Count -ne 0) {
            throw 'The backup is not completely unpatched and cannot be trusted as the original.'
        }
        if ([int64]$manifest.Size -ne $inspection.Size) {
            throw "Backup size $($inspection.Size) does not match manifest size $($manifest.Size)."
        }
        if ([string]$manifest.FileVersion -ne $inspection.Pe.FileVersion) {
            throw "Backup version $($inspection.Pe.FileVersion) does not match manifest version $($manifest.FileVersion)."
        }
        if ([string]$manifest.SHA256 -ine $inspection.SHA256) {
            throw 'Backup SHA-256 does not match the manifest.'
        }

        return [pscustomobject]@{ Valid = $true; Exists = $true; Reason = $null; Sidecars = $sidecars; Manifest = $manifest; Inspection = $inspection }
    }
    catch {
        return [pscustomobject]@{ Valid = $false; Exists = $true; Reason = $_.Exception.Message; Sidecars = $sidecars; Manifest = $null; Inspection = $null }
    }
}

function New-CameraFixOriginalBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath
    )

    $status = Get-CameraFixStatus -Path $ExePath
    if ($status.State -ne 'Unpatched') {
        throw "A new original backup may be created only from a completely unpatched, compatible build-743 executable. Current state: $($status.State)."
    }

    $existing = Test-CameraFixOriginalBackup -ExePath $ExePath
    if ($existing.Exists) {
        if ($existing.Valid) {
            if ($existing.Inspection.SHA256 -ine $status.SHA256) {
                throw 'A valid backup already exists, but it does not match the selected unpatched EXE. The known-good backup will not be overwritten.'
            }
            return [pscustomobject]@{ Created = $false; Validation = $existing }
        }
        throw "Backup sidecar files already exist but are not trustworthy: $($existing.Reason) They will not be overwritten."
    }

    $sidecars = $existing.Sidecars
    $manifestTemp = $sidecars.ManifestPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $backupCreated = $false
    $manifestCreated = $false
    try {
        Copy-CameraFixFileCreateNew -Source $status.Path -Destination $sidecars.BackupPath
        $backupCreated = $true

        $backupHash = Get-CameraFixFileSha256 -Path $sidecars.BackupPath
        if ($backupHash -ine $status.SHA256) {
            throw 'The new backup failed its byte-for-byte SHA-256 verification.'
        }

        $manifestObject = [ordered]@{
            SchemaVersion = $script:CameraFixManifestSchema
            Tool = $script:CameraFixToolName
            OriginalFilename = 'TombRaider.exe'
            FileVersion = [string]$status.FileVersion
            Size = [int64]$status.Size
            SHA256 = [string]$status.SHA256
            StoredPEChecksum = ('0x{0:X8}' -f $status.Pe.StoredChecksum)
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
        }
        $json = $manifestObject | ConvertTo-Json -Depth 4
        [IO.File]::WriteAllText($manifestTemp, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        [IO.File]::Move($manifestTemp, $sidecars.ManifestPath)
        $manifestCreated = $true

        $validation = Test-CameraFixOriginalBackup -ExePath $ExePath
        if (-not $validation.Valid) {
            throw "The new backup set failed validation: $($validation.Reason)"
        }
        return [pscustomobject]@{ Created = $true; Validation = $validation }
    }
    catch {
        if ([IO.File]::Exists($manifestTemp)) {
            Remove-Item -LiteralPath $manifestTemp -Force -ErrorAction SilentlyContinue
        }
        if ($backupCreated -and -not $manifestCreated -and [IO.File]::Exists($sidecars.BackupPath)) {
            Remove-Item -LiteralPath $sidecars.BackupPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Get-CameraFixRegionsFromUnpatchedInspection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Inspection
    )

    $regions = foreach ($pattern in $Inspection.Patterns) {
        if (($pattern.Classification -ne 'Unpatched') -or ($pattern.OriginalOffsets.Count -ne 1)) {
            throw "Cannot create a patch region for $($pattern.Name): $($pattern.Classification)."
        }
        [pscustomobject]@{
            Key = $pattern.Key
            Name = $pattern.Name
            Offset = [long]$pattern.OriginalOffsets[0]
            Length = [int]$pattern.OriginalBytes.Length
            OriginalBytes = [byte[]]$pattern.OriginalBytes
            PatchedBytes = [byte[]]$pattern.PatchedBytes
        }
    }
    return @($regions | Sort-Object Offset)
}

function Test-CameraFixBytesAtOffset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [long]$Offset,

        [Parameter(Mandatory = $true)]
        [byte[]]$Expected
    )

    if (($Offset -lt 0) -or (($Offset + $Expected.Length) -gt $Bytes.Length)) {
        return $false
    }
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        if ($Bytes[$Offset + $index] -ne $Expected[$index]) {
            return $false
        }
    }
    return $true
}

function Get-CameraFixOutsideRegionSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [object[]]$Regions
    )

    $algorithm = [Security.Cryptography.SHA256]::Create()
    $cryptoStream = New-Object Security.Cryptography.CryptoStream([IO.Stream]::Null, $algorithm, [Security.Cryptography.CryptoStreamMode]::Write)
    try {
        $cursor = 0L
        foreach ($region in @($Regions | Sort-Object Offset)) {
            if (($region.Offset -lt $cursor) -or (($region.Offset + $region.Length) -gt $Bytes.Length)) {
                throw 'Patch regions overlap or lie outside the file.'
            }
            $count = [int]($region.Offset - $cursor)
            if ($count -gt 0) {
                $cryptoStream.Write($Bytes, [int]$cursor, $count)
            }
            $cursor = [long]$region.Offset + [long]$region.Length
        }
        $tailCount = [int]($Bytes.Length - $cursor)
        if ($tailCount -gt 0) {
            $cryptoStream.Write($Bytes, [int]$cursor, $tailCount)
        }
        $cryptoStream.FlushFinalBlock()
        return (($algorithm.Hash | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    finally {
        $cryptoStream.Dispose()
        $algorithm.Dispose()
    }
}

function Test-CameraFixExpectedChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Original,

        [Parameter(Mandatory = $true)]
        [byte[]]$Modified,

        [Parameter(Mandatory = $true)]
        [object[]]$Regions
    )

    if ($Original.Length -ne $Modified.Length) {
        return [pscustomobject]@{ Valid = $false; Reason = 'File size changed.' }
    }
    foreach ($region in $Regions) {
        if (-not (Test-CameraFixBytesAtOffset -Bytes $Original -Offset $region.Offset -Expected $region.OriginalBytes)) {
            return [pscustomobject]@{ Valid = $false; Reason = "Original bytes are wrong at the $($region.Name) region." }
        }
        if (-not (Test-CameraFixBytesAtOffset -Bytes $Modified -Offset $region.Offset -Expected $region.PatchedBytes)) {
            return [pscustomobject]@{ Valid = $false; Reason = "Patched bytes are wrong at the $($region.Name) region." }
        }
    }

    $originalOutsideHash = Get-CameraFixOutsideRegionSha256 -Bytes $Original -Regions $Regions
    $modifiedOutsideHash = Get-CameraFixOutsideRegionSha256 -Bytes $Modified -Regions $Regions
    if ($originalOutsideHash -ine $modifiedOutsideHash) {
        return [pscustomobject]@{ Valid = $false; Reason = 'Bytes outside the three expected patch regions changed.' }
    }
    return [pscustomobject]@{ Valid = $true; Reason = $null; OutsideRegionSHA256 = $originalOutsideHash }
}

function Test-CameraFixPartialAgainstBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $LiveInspection,

        [Parameter(Mandatory = $true)]
        $BackupInspection
    )

    if ($LiveInspection.Size -ne $BackupInspection.Size) {
        return [pscustomobject]@{ Valid = $false; Reason = 'The partial EXE size differs from the original backup.' }
    }
    $regions = @(Get-CameraFixRegionsFromUnpatchedInspection -Inspection $BackupInspection)
    foreach ($region in $regions) {
        $livePattern = @($LiveInspection.Patterns | Where-Object { $_.Key -eq $region.Key })[0]
        if ($livePattern.Classification -notin @('Unpatched', 'Patched')) {
            return [pscustomobject]@{ Valid = $false; Reason = "$($region.Name) is ambiguous in the partial EXE." }
        }
        $liveOffset = if ($livePattern.Classification -eq 'Unpatched') { [long]$livePattern.OriginalOffsets[0] } else { [long]$livePattern.PatchedOffsets[0] }
        if ($liveOffset -ne $region.Offset) {
            return [pscustomobject]@{ Valid = $false; Reason = "$($region.Name) moved relative to the original backup." }
        }
    }

    $liveOutsideHash = Get-CameraFixOutsideRegionSha256 -Bytes $LiveInspection.Bytes -Regions $regions
    $backupOutsideHash = Get-CameraFixOutsideRegionSha256 -Bytes $BackupInspection.Bytes -Regions $regions
    if ($liveOutsideHash -ine $backupOutsideHash) {
        return [pscustomobject]@{ Valid = $false; Reason = 'The partial EXE contains changes outside the three expected camera-fix regions.' }
    }
    return [pscustomobject]@{ Valid = $true; Reason = $null; Regions = $regions }
}

function Invoke-CameraFixAtomicReplace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PreparedPath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [string]$RollbackPath,

        [ValidateSet('None', 'AfterReplace')]
        [string]$FailurePoint = 'None'
    )

    $replaced = $false
    try {
        [IO.File]::Replace($PreparedPath, $DestinationPath, $RollbackPath, $true)
        $replaced = $true
        if ($FailurePoint -eq 'AfterReplace') {
            throw 'Simulated failure after atomic replacement.'
        }
        return [pscustomobject]@{ Replaced = $true; RollbackPath = $RollbackPath }
    }
    catch {
        $originalError = $_.Exception.Message
        if ($replaced -and [IO.File]::Exists($RollbackPath)) {
            try {
                Restore-CameraFixRollback -RollbackPath $RollbackPath -DestinationPath $DestinationPath
                $replaced = $false
            }
            catch {
                throw "Operation failed: $originalError Automatic rollback also failed: $($_.Exception.Message). The verified original backup sidecar has been preserved."
            }
        }
        throw $originalError
    }
}

function Restore-CameraFixRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RollbackPath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    # File.Replace does not reliably accept a null backup path through the
    # Windows PowerShell 5.1 overload binder. Supply a real, unique displacement
    # path so rollback itself remains atomic, then discard the failed version.
    $displacedPath = $RollbackPath + '.displaced-' + [guid]::NewGuid().ToString('N')
    [IO.File]::Replace($RollbackPath, $DestinationPath, $displacedPath, $true)
    if ([IO.File]::Exists($displacedPath)) {
        Remove-Item -LiteralPath $displacedPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-CameraFixApply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [ValidateSet('None', 'AfterBackup', 'AfterTempWrite', 'BeforeReplace', 'AfterReplace')]
        [string]$FailurePoint = 'None'
    )

    $status = Get-CameraFixStatus -Path $ExePath
    if ($status.State -eq 'Unsupported') {
        throw "Refusing to patch an unsupported executable. $($status.Reason)"
    }
    if ($status.State -eq 'CompletelyPatched') {
        return [pscustomobject]@{ Changed = $false; State = 'CompletelyPatched'; OriginalSHA256 = $null; PatchedSHA256 = $status.SHA256; BackupCreated = $false; Message = 'All three fixes are already applied.' }
    }

    $liveInspection = Get-CameraFixInspection -Path $status.Path -RequireTargetName
    $liveHashBefore = $liveInspection.SHA256
    $backupCreated = $false
    $sourceInspection = $liveInspection

    if ($status.State -eq 'PartiallyPatched') {
        $backupValidation = Test-CameraFixOriginalBackup -ExePath $status.Path
        if (-not $backupValidation.Valid) {
            throw "The EXE is only partly patched, and no trustworthy original backup is available. Refusing to create a backup from a partly patched file. $($backupValidation.Reason)"
        }
        $partialCheck = Test-CameraFixPartialAgainstBackup -LiveInspection $liveInspection -BackupInspection $backupValidation.Inspection
        if (-not $partialCheck.Valid) {
            throw "The partial EXE cannot be safely rebuilt from the original backup. $($partialCheck.Reason)"
        }
        $sourceInspection = $backupValidation.Inspection
    }
    else {
        $backupResult = New-CameraFixOriginalBackup -ExePath $status.Path
        $backupCreated = $backupResult.Created
        $backupValidation = $backupResult.Validation
        $sourceInspection = $backupValidation.Inspection
    }

    if ($FailurePoint -eq 'AfterBackup') {
        throw 'Simulated failure after backup creation.'
    }

    $regions = @(Get-CameraFixRegionsFromUnpatchedInspection -Inspection $sourceInspection)
    $patchedBytes = New-Object byte[] $sourceInspection.Bytes.Length
    [Array]::Copy($sourceInspection.Bytes, $patchedBytes, $sourceInspection.Bytes.Length)
    foreach ($region in $regions) {
        [Array]::Copy($region.PatchedBytes, 0, $patchedBytes, [int]$region.Offset, $region.PatchedBytes.Length)
    }

    $memoryVerification = Test-CameraFixExpectedChanges -Original $sourceInspection.Bytes -Modified $patchedBytes -Regions $regions
    if (-not $memoryVerification.Valid) {
        throw "Prepared patch failed in-memory verification: $($memoryVerification.Reason)"
    }
    $patchedAnalysis = @(Get-CameraFixPatternAnalysis -Bytes $patchedBytes)
    if (@($patchedAnalysis | Where-Object { $_.Classification -ne 'Patched' }).Count -ne 0) {
        throw 'Prepared patch did not produce exactly one complete patched sequence for every fix.'
    }

    $directory = [IO.Path]::GetDirectoryName($status.Path)
    $tempPath = Join-Path $directory ('.TombRaiderCameraFix-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $rollbackPath = Join-Path $directory ('.TombRaiderCameraFix-' + [guid]::NewGuid().ToString('N') + '.rollback')
    $replacementSucceeded = $false
    try {
        $output = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $output.Write($patchedBytes, 0, $patchedBytes.Length)
            $output.Flush()
        }
        finally {
            $output.Dispose()
        }

        $tempBytes = [IO.File]::ReadAllBytes($tempPath)
        $diskVerification = Test-CameraFixExpectedChanges -Original $sourceInspection.Bytes -Modified $tempBytes -Regions $regions
        if (-not $diskVerification.Valid) {
            throw "Temporary patched copy failed verification: $($diskVerification.Reason)"
        }
        if ($tempBytes.Length -ne $sourceInspection.Size) {
            throw 'Temporary patched copy changed the file size.'
        }
        $tempAnalysis = @(Get-CameraFixPatternAnalysis -Bytes $tempBytes)
        if (@($tempAnalysis | Where-Object { $_.Classification -ne 'Patched' }).Count -ne 0) {
            throw 'Temporary patched copy does not contain exactly one unambiguous patched sequence for every fix.'
        }
        $expectedPatchedHash = Get-CameraFixSha256FromBytes -Bytes $tempBytes

        if ($FailurePoint -eq 'AfterTempWrite') {
            throw 'Simulated failure after temporary patch creation.'
        }
        if ((Get-CameraFixFileSha256 -Path $status.Path) -ine $liveHashBefore) {
            throw 'TombRaider.exe changed after inspection. Refusing to replace it.'
        }
        if ($FailurePoint -eq 'BeforeReplace') {
            throw 'Simulated failure before atomic replacement.'
        }

        $atomicFailure = if ($FailurePoint -eq 'AfterReplace') { 'AfterReplace' } else { 'None' }
        $null = Invoke-CameraFixAtomicReplace -PreparedPath $tempPath -DestinationPath $status.Path -RollbackPath $rollbackPath -FailurePoint $atomicFailure
        $replacementSucceeded = $true

        $finalStatus = Get-CameraFixStatus -Path $status.Path
        if (($finalStatus.State -ne 'CompletelyPatched') -or ($finalStatus.Size -ne $sourceInspection.Size) -or ($finalStatus.SHA256 -ine $expectedPatchedHash)) {
            throw 'The live EXE failed final post-replacement verification.'
        }

        if ([IO.File]::Exists($rollbackPath)) {
            Remove-Item -LiteralPath $rollbackPath -Force -ErrorAction SilentlyContinue
        }
        return [pscustomobject]@{
            Changed = $true
            State = $finalStatus.State
            OriginalSHA256 = $sourceInspection.SHA256
            PatchedSHA256 = $finalStatus.SHA256
            BackupCreated = $backupCreated
            OutsideRegionSHA256 = $memoryVerification.OutsideRegionSHA256
            Message = 'All three camera fixes were applied and verified.'
        }
    }
    catch {
        if ($replacementSucceeded -and [IO.File]::Exists($rollbackPath)) {
            try {
                Restore-CameraFixRollback -RollbackPath $rollbackPath -DestinationPath $status.Path
            }
            catch {
                throw "Patch verification failed and rollback also failed: $($_.Exception.Message). The verified original backup sidecar remains available."
            }
        }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if ([IO.File]::Exists($rollbackPath) -and -not $replacementSucceeded) {
            Remove-Item -LiteralPath $rollbackPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-CameraFixRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [ValidateSet('None', 'AfterTempWrite', 'BeforeReplace', 'AfterReplace')]
        [string]$FailurePoint = 'None'
    )

    $fullPath = [IO.Path]::GetFullPath($ExePath)
    if ([IO.Path]::GetFileName($fullPath) -ine 'TombRaider.exe') {
        throw 'Restoration target must be named TombRaider.exe.'
    }
    if (-not [IO.File]::Exists($fullPath)) {
        throw "Restoration target does not exist: $fullPath"
    }

    $backupValidation = Test-CameraFixOriginalBackup -ExePath $fullPath
    if (-not $backupValidation.Valid) {
        throw "The original backup cannot be trusted, so restoration was refused. $($backupValidation.Reason)"
    }
    $originalHash = [string]$backupValidation.Manifest.SHA256
    if ((Get-CameraFixFileSha256 -Path $fullPath) -ieq $originalHash) {
        return [pscustomobject]@{ Changed = $false; RestoredSHA256 = $originalHash; ExpectedSHA256 = $originalHash; Message = 'TombRaider.exe already matches the recorded original byte for byte.' }
    }

    $directory = [IO.Path]::GetDirectoryName($fullPath)
    $tempPath = Join-Path $directory ('.TombRaiderCameraFix-restore-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $rollbackPath = Join-Path $directory ('.TombRaiderCameraFix-restore-' + [guid]::NewGuid().ToString('N') + '.rollback')
    $replacementSucceeded = $false
    try {
        Copy-CameraFixFileCreateNew -Source $backupValidation.Sidecars.BackupPath -Destination $tempPath
        if ((Get-CameraFixFileSha256 -Path $tempPath) -ine $originalHash) {
            throw 'The temporary restore copy does not match the manifest SHA-256.'
        }
        if (([IO.FileInfo]$tempPath).Length -ne [int64]$backupValidation.Manifest.Size) {
            throw 'The temporary restore copy does not match the manifest size.'
        }
        if ($FailurePoint -eq 'AfterTempWrite') {
            throw 'Simulated failure after temporary restore creation.'
        }
        if ($FailurePoint -eq 'BeforeReplace') {
            throw 'Simulated failure before restore replacement.'
        }

        $atomicFailure = if ($FailurePoint -eq 'AfterReplace') { 'AfterReplace' } else { 'None' }
        $null = Invoke-CameraFixAtomicReplace -PreparedPath $tempPath -DestinationPath $fullPath -RollbackPath $rollbackPath -FailurePoint $atomicFailure
        $replacementSucceeded = $true

        $restoredHash = Get-CameraFixFileSha256 -Path $fullPath
        if ($restoredHash -ine $originalHash) {
            throw "Restoration hash mismatch. Expected $originalHash but read $restoredHash."
        }
        $restoredStatus = Get-CameraFixStatus -Path $fullPath
        if (($restoredStatus.State -ne 'Unpatched') -or ($restoredStatus.Size -ne [int64]$backupValidation.Manifest.Size)) {
            throw 'The restored file did not pass build, size, and unpatched-pattern verification.'
        }

        if ([IO.File]::Exists($rollbackPath)) {
            Remove-Item -LiteralPath $rollbackPath -Force -ErrorAction SilentlyContinue
        }
        return [pscustomobject]@{
            Changed = $true
            RestoredSHA256 = $restoredHash
            ExpectedSHA256 = $originalHash
            Message = 'Original TombRaider.exe restored and verified byte for byte.'
        }
    }
    catch {
        if ($replacementSucceeded -and [IO.File]::Exists($rollbackPath)) {
            try {
                Restore-CameraFixRollback -RollbackPath $rollbackPath -DestinationPath $fullPath
            }
            catch {
                throw "Restore verification failed and rollback also failed: $($_.Exception.Message). The verified original backup sidecar remains available."
            }
        }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if ([IO.File]::Exists($rollbackPath) -and -not $replacementSucceeded) {
            Remove-Item -LiteralPath $rollbackPath -Force -ErrorAction SilentlyContinue
        }
    }
}
# END GENERATED SOURCE: src/CameraFixEngine.ps1

# BEGIN GENERATED SOURCE: src/CameraFixInterface.ps1
# Tomb Raider Complete Camera Fix - user interface and Windows integration
# Build-Release.ps1 loads CameraFixEngine.ps1 before this file.

if (-not [string]::IsNullOrWhiteSpace($StandaloneBatchPath)) {
    $script:CameraFixStandaloneBatchPath = [IO.Path]::GetFullPath($StandaloneBatchPath)
}
else {
    $script:CameraFixStandaloneBatchPath = $null
}

if ($ElevatedFromEnvironment) {
    $ExePath = [Environment]::GetEnvironmentVariable('TRCF_ELEVATED_EXE', 'Process')
    $Action = [Environment]::GetEnvironmentVariable('TRCF_ELEVATED_ACTION', 'Process')
    $ApplyConfirmed = ($Action -eq 'Apply')
    $PauseAfterAction = $true
    $elevatedFailure = [Environment]::GetEnvironmentVariable('TRCF_ELEVATED_FAILURE', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($elevatedFailure)) {
        $TestFailurePoint = $elevatedFailure
    }
}

function Write-CameraFixHeading {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host 'Tomb Raider Complete Camera Fix' -ForegroundColor Cyan
    Write-Host 'Steam build 743.0 only' -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-CameraFixInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-CameraFixSuccess {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-CameraFixWarning {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-CameraFixError {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Select-CameraFixUniqueWindowsPaths {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Path
    )

    $uniquePaths = New-Object 'System.Collections.Generic.List[string]'
    $seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in @($Path)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        try {
            $fullPath = [IO.Path]::GetFullPath($candidate)
            $pathRoot = [IO.Path]::GetPathRoot($fullPath)
            if ($fullPath.Length -gt $pathRoot.Length) {
                $fullPath = $fullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            }
        }
        catch {
            continue
        }

        if ($seenPaths.Add($fullPath)) {
            $uniquePaths.Add($fullPath)
        }
    }

    return @($uniquePaths)
}

function Get-CameraFixDefaultSteamRoots {
    [CmdletBinding()]
    param()

    $override = [Environment]::GetEnvironmentVariable('TRCF_STEAM_ROOTS', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        return @(Select-CameraFixUniqueWindowsPaths -Path $override.Split([IO.Path]::PathSeparator))
    }

    $roots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($candidate in @(
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Steam' }),
        $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Steam' })
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $roots.Add($candidate)
        }
    }

    foreach ($registryItem in @(
        @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' }
    )) {
        try {
            $value = (Get-ItemProperty -LiteralPath $registryItem.Path -Name $registryItem.Name -ErrorAction Stop).($registryItem.Name)
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $roots.Add([string]$value)
            }
        }
        catch {
            # A missing Steam registry entry is normal.
        }
    }

    return @(Select-CameraFixUniqueWindowsPaths -Path @($roots))
}

function Get-CameraFixSteamLibraries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SteamRoots
    )

    $libraries = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in $SteamRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }
        try {
            $fullRoot = [IO.Path]::GetFullPath($root)
            $libraries.Add($fullRoot)
            $vdfPath = Join-Path $fullRoot 'steamapps\libraryfolders.vdf'
            if ([IO.File]::Exists($vdfPath)) {
                $vdf = [IO.File]::ReadAllText($vdfPath)
                $matches = [Text.RegularExpressions.Regex]::Matches($vdf, '"path"\s*"(?<value>(?:\\.|[^"])*)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
                foreach ($match in $matches) {
                    $libraryPath = $match.Groups['value'].Value
                    $libraryPath = $libraryPath -replace '\\\\', '\'
                    $libraryPath = $libraryPath -replace '\\/', '/'
                    if (-not [string]::IsNullOrWhiteSpace($libraryPath)) {
                        try { $libraries.Add([IO.Path]::GetFullPath($libraryPath)) } catch { }
                    }
                }
            }
        }
        catch {
            # Ignore malformed or inaccessible candidate roots and continue.
        }
    }
    return @(Select-CameraFixUniqueWindowsPaths -Path @($libraries))
}

function Find-CameraFixSteamExecutables {
    [CmdletBinding()]
    param(
        [string[]]$SteamRoots
    )

    if (-not $PSBoundParameters.ContainsKey('SteamRoots')) {
        $SteamRoots = @(Get-CameraFixDefaultSteamRoots)
    }
    $libraries = @(Get-CameraFixSteamLibraries -SteamRoots $SteamRoots)
    $found = foreach ($library in $libraries) {
        $candidate = Join-Path $library 'steamapps\common\Tomb Raider\TombRaider.exe'
        if ([IO.File]::Exists($candidate)) {
            [IO.Path]::GetFullPath($candidate)
        }
    }
    return @(Select-CameraFixUniqueWindowsPaths -Path @($found))
}

function Select-CameraFixFileWithDialog {
    [CmdletBinding()]
    param()

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = New-Object Windows.Forms.OpenFileDialog
        try {
            $dialog.Title = 'Select Steam build-743 TombRaider.exe'
            $dialog.Filter = 'Tomb Raider executable (TombRaider.exe)|TombRaider.exe|Executable files (*.exe)|*.exe'
            $dialog.CheckFileExists = $true
            $dialog.Multiselect = $false
            if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                return $dialog.FileName
            }
        }
        finally {
            $dialog.Dispose()
        }
    }
    catch {
        Write-CameraFixWarning 'The normal file-selection window is unavailable in this session.'
    }
    return $null
}

function Resolve-CameraFixExePath {
    [CmdletBinding()]
    param(
        [string]$RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $trimmed = $RequestedPath.Trim().Trim('"')
        if ([IO.Directory]::Exists($trimmed)) {
            $trimmed = Join-Path $trimmed 'TombRaider.exe'
        }
        try { return [IO.Path]::GetFullPath($trimmed) } catch { return $trimmed }
    }

    Write-CameraFixInfo 'Looking for Tomb Raider in normal Steam folders and Steam libraries...'
    $detected = @(Find-CameraFixSteamExecutables)
    if ($detected.Count -eq 1) {
        Write-CameraFixSuccess "Found: $($detected[0])"
        return $detected[0]
    }
    if ($detected.Count -gt 1) {
        Write-CameraFixWarning 'More than one Tomb Raider installation was found:'
        for ($index = 0; $index -lt $detected.Count; $index++) {
            Write-Host ('[{0}] {1}' -f ($index + 1), $detected[$index])
        }
        $choice = Read-Host 'Enter the number to use, or press Enter to browse'
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and ($number -ge 1) -and ($number -le $detected.Count)) {
            return $detected[$number - 1]
        }
    }

    Write-CameraFixWarning 'Automatic detection did not find one unambiguous installation.'
    $selected = Select-CameraFixFileWithDialog
    if (-not [string]::IsNullOrWhiteSpace($selected)) {
        return [IO.Path]::GetFullPath($selected)
    }

    $typed = Read-Host 'Enter the full path to TombRaider.exe, or press Enter to cancel'
    if ([string]::IsNullOrWhiteSpace($typed)) {
        return $null
    }
    $typed = $typed.Trim().Trim('"')
    if ([IO.Directory]::Exists($typed)) {
        $typed = Join-Path $typed 'TombRaider.exe'
    }
    try { return [IO.Path]::GetFullPath($typed) } catch { return $typed }
}

function Show-CameraFixStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $status = Get-CameraFixStatus -Path $Path
    Write-Host ''
    Write-Host "Selected file: $($status.Path)" -ForegroundColor White
    if ($null -ne $status.FileVersion) {
        Write-Host "File version:  $($status.FileVersion)"
        Write-Host "File size:     $($status.Size) bytes"
        Write-Host "SHA-256:       $($status.SHA256)"
        Write-Host ('PE checksum:   0x{0:X8} (left unchanged by this tool)' -f $status.Pe.StoredChecksum)
    }

    switch ($status.State) {
        'Unpatched' { Write-CameraFixInfo 'Status: compatible build 743.0; all three fixes are currently unpatched.' }
        'PartiallyPatched' { Write-CameraFixWarning 'Status: PARTIALLY PATCHED. The three fixes are not in one consistent state.' }
        'CompletelyPatched' { Write-CameraFixSuccess 'Status: COMPLETE FIX APPLIED. All three sequences are patched.' }
        default { Write-CameraFixError "Status: UNSUPPORTED. $($status.Reason)" }
    }

    foreach ($pattern in $status.Patterns) {
        $colour = switch ($pattern.Classification) {
            'Patched' { 'Green' }
            'Unpatched' { 'Cyan' }
            default { 'Red' }
        }
        Write-Host ('  {0}: {1} (original matches: {2}; patched matches: {3})' -f $pattern.Name, $pattern.Classification, $pattern.OriginalCount, $pattern.PatchedCount) -ForegroundColor $colour
    }

    $backup = Test-CameraFixOriginalBackup -ExePath $Path
    if ($backup.Valid) {
        Write-CameraFixSuccess "Original backup: verified ($($backup.Manifest.SHA256))"
    }
    elseif ($backup.Exists) {
        Write-CameraFixError "Original backup: present but NOT trusted - $($backup.Reason)"
    }
    else {
        Write-Host 'Original backup: not created yet.' -ForegroundColor DarkGray
    }
    return $status
}

function Test-CameraFixDirectoryWritable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    if (-not [IO.Directory]::Exists($directory)) {
        return $false
    }
    $probe = Join-Path $directory ('.TombRaiderCameraFix-write-test-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stream = [IO.File]::Open($probe, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Dispose()
        [IO.File]::Delete($probe)
        return $true
    }
    catch {
        if ([IO.File]::Exists($probe)) {
            try { [IO.File]::Delete($probe) } catch { }
        }
        return $false
    }
}

function ConvertTo-CameraFixPowerShellLiteral {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Start-CameraFixElevatedAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet('Apply', 'Restore')][string]$RequestedAction
    )

    Write-CameraFixWarning 'This folder rejected a harmless write test. Windows will now ask for administrator permission for this one action.'
    $environmentNames = @('TRCF_ELEVATED_LAUNCH', 'TRCF_ELEVATED_EXE', 'TRCF_ELEVATED_ACTION', 'TRCF_ELEVATED_FAILURE')
    $previousEnvironment = @{}
    foreach ($name in $environmentNames) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        [Environment]::SetEnvironmentVariable('TRCF_ELEVATED_LAUNCH', '1', 'Process')
        [Environment]::SetEnvironmentVariable('TRCF_ELEVATED_EXE', [IO.Path]::GetFullPath($Path), 'Process')
        [Environment]::SetEnvironmentVariable('TRCF_ELEVATED_ACTION', $RequestedAction, 'Process')
        [Environment]::SetEnvironmentVariable('TRCF_ELEVATED_FAILURE', $TestFailurePoint, 'Process')

        if (-not [string]::IsNullOrWhiteSpace($script:CameraFixStandaloneBatchPath)) {
            # No user-controlled text is put on a command line. The elevated BAT
            # inherits the process environment and reads the values from there.
            $process = Start-Process -FilePath $script:CameraFixStandaloneBatchPath -Verb RunAs -WorkingDirectory ([IO.Path]::GetDirectoryName($script:CameraFixStandaloneBatchPath)) -Wait -PassThru -ErrorAction Stop
        }
        else {
            $quotedScriptPath = '"' + $PSCommandPath.Replace('"', '""') + '"'
            $process = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $quotedScriptPath, '-ElevatedFromEnvironment') -Verb RunAs -WorkingDirectory $PSScriptRoot -Wait -PassThru -ErrorAction Stop
        }
        if ($process.ExitCode -ne 0) {
            Write-CameraFixError "The elevated action ended with exit code $($process.ExitCode)."
            return $false
        }
        return $true
    }
    catch {
        Write-CameraFixError "Administrator permission was not granted or the elevated action could not start: $($_.Exception.Message)"
        return $false
    }
    finally {
        foreach ($name in $environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
    }
}

function Invoke-CameraFixUiApply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$AlreadyConfirmed
    )

    $status = Show-CameraFixStatus -Path $Path
    if ($status.State -eq 'Unsupported') {
        Write-CameraFixError 'Nothing was changed.'
        return $false
    }
    if ($status.State -eq 'CompletelyPatched') {
        Write-CameraFixSuccess 'Nothing needs to be changed.'
        return $true
    }
    if ($status.State -eq 'PartiallyPatched') {
        $backup = Test-CameraFixOriginalBackup -ExePath $Path
        if (-not $backup.Valid) {
            Write-CameraFixError 'A partly patched EXE cannot become a new original backup. Restore a clean build through Steam or provide the verified backup sidecars.'
            return $false
        }
    }

    if (-not $AlreadyConfirmed) {
        Write-Host ''
        Write-CameraFixWarning 'The complete fix always applies all three changes together.'
        Write-CameraFixWarning 'The vertical modification is an existing community fix that has been tested less extensively. It redirects the rotation value to memory expected to remain zero; unexpected game state could reveal bugs.'
        Write-Host 'The game will not be launched. steam_api.dll and all other files will remain untouched.' -ForegroundColor White
        $confirmation = Read-Host 'Type APPLY once to create/verify the backup and apply all three fixes'
        if ($confirmation -cne 'APPLY') {
            Write-CameraFixWarning 'Cancelled. Nothing was changed.'
            return $false
        }
    }

    if (-not (Test-CameraFixDirectoryWritable -Path $Path)) {
        return (Start-CameraFixElevatedAction -Path $Path -RequestedAction Apply)
    }

    try {
        $result = Invoke-CameraFixApply -ExePath $Path -FailurePoint $TestFailurePoint
        Write-Host ''
        Write-CameraFixSuccess $result.Message
        if ($result.Changed) {
            Write-Host "Original SHA-256: $($result.OriginalSHA256)"
            Write-Host "Patched SHA-256:  $($result.PatchedSHA256)"
            Write-Host 'File size stayed unchanged, every replacement was verified, and bytes outside the three expected regions retained the same SHA-256.'
        }
        return $true
    }
    catch {
        Write-CameraFixError "Apply failed safely: $($_.Exception.Message)"
        Write-CameraFixError 'The tool did not intentionally launch the game or modify any DLL.'
        return $false
    }
}

function Invoke-CameraFixUiRestore {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $backup = Test-CameraFixOriginalBackup -ExePath $Path
    if (-not $backup.Valid) {
        Write-CameraFixError "Restore refused: $($backup.Reason)"
        return $false
    }
    if (-not (Test-CameraFixDirectoryWritable -Path $Path)) {
        return (Start-CameraFixElevatedAction -Path $Path -RequestedAction Restore)
    }

    try {
        $restoreFailurePoint = if ($TestFailurePoint -in @('AfterTempWrite', 'BeforeReplace', 'AfterReplace')) { $TestFailurePoint } else { 'None' }
        $result = Invoke-CameraFixRestore -ExePath $Path -FailurePoint $restoreFailurePoint
        Write-Host ''
        Write-CameraFixSuccess $result.Message
        Write-Host "Recorded original SHA-256: $($result.ExpectedSHA256)"
        Write-Host "Restored file SHA-256:     $($result.RestoredSHA256)"
        return $true
    }
    catch {
        Write-CameraFixError "Restore failed safely: $($_.Exception.Message)"
        return $false
    }
}

function Wait-CameraFixIfRequested {
    [CmdletBinding()]
    param([switch]$ShouldPause)
    if ($ShouldPause) {
        $null = Read-Host 'Press Enter to close this window'
    }
}

if (-not $LibraryMode) {
    Write-CameraFixHeading
    $selectedPath = Resolve-CameraFixExePath -RequestedPath $ExePath
    if ([string]::IsNullOrWhiteSpace($selectedPath)) {
        Write-CameraFixWarning 'No executable was selected. Nothing was changed.'
        Wait-CameraFixIfRequested -ShouldPause:$PauseAfterAction
        exit 1
    }

    if ($Action -ne 'Menu') {
        $ok = $true
        switch ($Action) {
            'Status' { $null = Show-CameraFixStatus -Path $selectedPath }
            'Apply' { $ok = Invoke-CameraFixUiApply -Path $selectedPath -AlreadyConfirmed:$ApplyConfirmed }
            'Restore' { $ok = Invoke-CameraFixUiRestore -Path $selectedPath }
        }
        Wait-CameraFixIfRequested -ShouldPause:$PauseAfterAction
        if ($ok) { exit 0 } else { exit 1 }
    }

    while ($true) {
        Write-CameraFixHeading
        Write-Host "Selected: $selectedPath" -ForegroundColor DarkGray
        Write-Host '[1] Check current camera-fix status'
        Write-Host '[2] Apply complete camera fix'
        Write-Host '[3] Restore original TombRaider.exe'
        Write-Host '[4] Exit'
        Write-Host ''
        $choice = Read-Host 'Choose 1, 2, 3 or 4'
        switch ($choice) {
            '1' { $null = Show-CameraFixStatus -Path $selectedPath }
            '2' { $null = Invoke-CameraFixUiApply -Path $selectedPath }
            '3' { $null = Invoke-CameraFixUiRestore -Path $selectedPath }
            '4' { Write-CameraFixInfo 'No game was launched.'; break }
            default { Write-CameraFixWarning 'Please enter 1, 2, 3 or 4.' }
        }
        if ($choice -eq '4') {
            break
        }
    }
}
# END GENERATED SOURCE: src/CameraFixInterface.ps1
