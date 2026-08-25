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
