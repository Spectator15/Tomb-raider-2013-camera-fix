[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildPath = Join-Path $PSScriptRoot 'Build-Release.ps1'
$releasePath = Join-Path $repositoryRoot 'TombRaider-Camera-Fix.bat'
$templatePath = Join-Path $repositoryRoot 'src\TombRaider-Camera-Fix.template.bat'
$enginePath = Join-Path $repositoryRoot 'src\CameraFixEngine.ps1'
$interfacePath = Join-Path $repositoryRoot 'src\CameraFixInterface.ps1'
$embeddedMarker = '#__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__'
$script:PassedTestCount = 0
$script:FailedTests = New-Object 'System.Collections.Generic.List[string]'

function Assert-CameraFixTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-CameraFixEqual {
    [CmdletBinding()]
    param(
        $Expected,
        $Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected: '$Expected'. Actual: '$Actual'."
    }
}

function Assert-CameraFixThrows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$MessagePattern
    )

    $caught = $null
    try {
        & $Action
    }
    catch {
        $caught = $_
    }

    if ($null -eq $caught) {
        throw 'Expected the operation to throw, but it completed successfully.'
    }
    if (-not [string]::IsNullOrWhiteSpace($MessagePattern) -and ($caught.Exception.Message -notmatch $MessagePattern)) {
        throw "The operation threw an unexpected error: $($caught.Exception.Message)"
    }
    return $caught
}

function Invoke-CameraFixTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    try {
        & $Action
        $script:PassedTestCount++
        Write-Host "PASS  $Name" -ForegroundColor Green
    }
    catch {
        $script:FailedTests.Add("$Name`: $($_.Exception.Message)")
        Write-Host "FAIL  $Name" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ConvertTo-TestCrlf {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $normalised = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $normalised = $normalised.TrimEnd([char[]]@("`r", "`n"))
    return $normalised.Replace("`n", "`r`n")
}

function ConvertTo-CameraFixHexString {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join ' ')
}

function Copy-CameraFixFixture {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Name)

    $caseDirectory = Join-Path $script:TestRoot $Name
    [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
    $path = Join-Path $caseDirectory 'TombRaider.exe'
    [IO.File]::Copy($script:FixtureSeedPath, $path, $false)
    return $path
}

function Add-CameraFixBytesToFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$BytesToAppend
    )

    $original = [IO.File]::ReadAllBytes($Path)
    $combined = New-Object byte[] ($original.Length + $BytesToAppend.Length)
    [Array]::Copy($original, 0, $combined, 0, $original.Length)
    [Array]::Copy($BytesToAppend, 0, $combined, $original.Length, $BytesToAppend.Length)
    [IO.File]::WriteAllBytes($Path, $combined)
}

function Set-CameraFixBytesAtOffset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][long]$Offset,
        [Parameter(Mandatory = $true)][byte[]]$Bytes
    )

    $fileBytes = [IO.File]::ReadAllBytes($Path)
    [Array]::Copy($Bytes, 0, $fileBytes, [int]$Offset, $Bytes.Length)
    [IO.File]::WriteAllBytes($Path, $fileBytes)
}

function Get-CameraFixRawSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Invoke-CameraFixReleaseBatch {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object[]]$Arguments)

    $output = (& $releasePath @Arguments 2>&1 | Out-String)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
    }
}

function Remove-CameraFixTestRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $tempRoot.EndsWith([IO.Path]::DirectorySeparatorChar.ToString())) {
        $tempRoot += [IO.Path]::DirectorySeparatorChar
    }
    if ((-not $fullPath.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) -or
        ([IO.Path]::GetFileName($fullPath) -notlike 'TombRaiderCameraFixTests-*')) {
        throw "Refusing to remove an unexpected test path: $fullPath"
    }
    if ([IO.Directory]::Exists($fullPath)) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

$script:TestRoot = Join-Path ([IO.Path]::GetTempPath()) ('TombRaiderCameraFixTests-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($script:TestRoot) | Out-Null
$script:FixtureSeedPath = Join-Path $script:TestRoot 'TombRaider.exe'

try {
    Invoke-CameraFixTest 'PowerShell source files parse successfully' {
        $powerShellSources = @(
            $buildPath
            (Join-Path $PSScriptRoot 'Test-Release.ps1')
            $enginePath
            $interfacePath
        )
        foreach ($path in $powerShellSources) {
            $tokens = $null
            $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
            Assert-CameraFixEqual -Expected 0 -Actual @($parseErrors).Count -Message "PowerShell parser errors were found in $path."
        }
    }

    Invoke-CameraFixTest 'Release builds deterministically and matches the committed batch' {
        $firstOutput = Join-Path $script:TestRoot 'first-build.bat'
        $secondOutput = Join-Path $script:TestRoot 'second-build.bat'
        & $buildPath -OutputPath $firstOutput | Out-Null
        & $buildPath -OutputPath $secondOutput | Out-Null

        $firstHash = Get-CameraFixRawSha256 -Path $firstOutput
        $secondHash = Get-CameraFixRawSha256 -Path $secondOutput
        $committedHash = Get-CameraFixRawSha256 -Path $releasePath
        Assert-CameraFixEqual -Expected $firstHash -Actual $secondHash -Message 'Two unchanged builds produced different SHA-256 hashes.'
        Assert-CameraFixEqual -Expected $firstHash -Actual $committedHash -Message 'The committed batch does not match the organised sources.'
    }

    Invoke-CameraFixTest 'Generated release has the expected source order, marker, encoding and CRLF lines' {
        $releaseBytes = [IO.File]::ReadAllBytes($releasePath)
        Assert-CameraFixTest -Condition ($releaseBytes.Length -gt 3) -Message 'The generated release is unexpectedly small.'
        $hasBom = (($releaseBytes[0] -eq 0xEF) -and ($releaseBytes[1] -eq 0xBB) -and ($releaseBytes[2] -eq 0xBF))
        Assert-CameraFixTest -Condition (-not $hasBom) -Message 'The generated release must be UTF-8 without a BOM.'

        for ($index = 0; $index -lt $releaseBytes.Length; $index++) {
            if ($releaseBytes[$index] -eq 0x0A) {
                Assert-CameraFixTest -Condition (($index -gt 0) -and ($releaseBytes[$index - 1] -eq 0x0D)) -Message "An LF without a preceding CR was found at byte $index."
            }
            if ($releaseBytes[$index] -eq 0x0D) {
                Assert-CameraFixTest -Condition ((($index + 1) -lt $releaseBytes.Length) -and ($releaseBytes[$index + 1] -eq 0x0A)) -Message "A CR without a following LF was found at byte $index."
            }
        }

        $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
        $releaseText = $strictUtf8.GetString($releaseBytes)
        Assert-CameraFixEqual -Expected 1 -Actual ([Text.RegularExpressions.Regex]::Matches($releaseText, [Text.RegularExpressions.Regex]::Escape($embeddedMarker))).Count -Message 'The embedded marker count is wrong.'

        $engineStart = $releaseText.IndexOf('# BEGIN GENERATED SOURCE: src/CameraFixEngine.ps1', [StringComparison]::Ordinal)
        $interfaceStart = $releaseText.IndexOf('# BEGIN GENERATED SOURCE: src/CameraFixInterface.ps1', [StringComparison]::Ordinal)
        Assert-CameraFixTest -Condition (($engineStart -gt 0) -and ($interfaceStart -gt $engineStart)) -Message 'Generated source boundaries are absent or out of order.'
        Assert-CameraFixTest -Condition ($releaseText.Contains((ConvertTo-TestCrlf -Text ([IO.File]::ReadAllText($enginePath))))) -Message 'The engine source was not included exactly.'
        Assert-CameraFixTest -Condition ($releaseText.Contains((ConvertTo-TestCrlf -Text ([IO.File]::ReadAllText($interfacePath))))) -Message 'The interface source was not included exactly.'
        Assert-CameraFixTest -Condition ($releaseText.Contains('rem GENERATED FILE: contributors should edit the source files in src.')) -Message 'The generated-file notice is missing.'

        $unresolvedPattern = '(?im)^[ \t]*(?:rem[ \t]+|#[ \t]*)?(?:@@[A-Z][A-Z0-9_-]*@@|__CAMERAFIX_BUILD_[A-Z0-9_-]+__)[ \t]*$'
        Assert-CameraFixTest -Condition (-not [Text.RegularExpressions.Regex]::IsMatch($releaseText, $unresolvedPattern)) -Message 'An unresolved build marker remains.'
        Assert-CameraFixTest -Condition ($releaseText -notmatch '(?i)(?:[A-Z]:\\Users\\|/home/|/Users/|gho_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+)') -Message 'The release contains a machine-specific path or credential-like value.'
    }

    Invoke-CameraFixTest 'Generated embedded PowerShell parses and LibraryMode loads it without UI' {
        $releaseText = [IO.File]::ReadAllText($releasePath)
        $markerIndex = $releaseText.IndexOf($embeddedMarker, [StringComparison]::Ordinal)
        Assert-CameraFixTest -Condition ($markerIndex -ge 0) -Message 'The Batch marker cannot be found.'
        $embeddedSource = $releaseText.Substring($markerIndex + $embeddedMarker.Length)
        $tokens = $null
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseInput($embeddedSource, [ref]$tokens, [ref]$parseErrors)
        Assert-CameraFixEqual -Expected 0 -Actual @($parseErrors).Count -Message 'The generated embedded PowerShell has parser errors.'
        $scriptBlock = [ScriptBlock]::Create($embeddedSource)
        $output = @(& $scriptBlock -LibraryMode)
        Assert-CameraFixEqual -Expected 0 -Actual $output.Count -Message 'LibraryMode unexpectedly produced pipeline output.'
    }

    . $enginePath

    $LibraryMode = $true
    $StandaloneBatchPath = $null
    $ElevatedFromEnvironment = $false
    $ExePath = $null
    $Action = 'Menu'
    $ApplyConfirmed = $false
    $PauseAfterAction = $false
    $TestFailurePoint = 'None'
    . $interfacePath

    Invoke-CameraFixTest 'Known patch definitions are byte-for-byte unchanged' {
        $expected = [ordered]@{
            WobbleOriginal = '8B CF E8 DB FD 41 00 84 C0 74 14 56'
            WobblePatched = '8B CF E8 DB FD 41 00 84 C0 EB 14 56'
            HorizontalOriginal = '08 B0 01 D9 9E A0 0F 00 00'
            HorizontalPatched = '08 B0 01 90 90 90 90 90 90'
            VerticalOriginal = 'D9 5E 04 D9 44 24 0C D9 5E 0C D9 44 24 18 D9 5E 10 C6 87 C4 0F 00 00 01 E9 A2 FE FF FF DD D8 6A 00 D9 87 40 06 00 00 83 EC 0C D9 5C 24'
            VerticalPatched = 'D9 5E 20 D9 44 24 0C D9 5E 0C D9 44 24 18 D9 5E 10 C6 87 C4 0F 00 00 01 E9 A2 FE FF FF DD D8 6A 00 D9 87 40 06 00 00 83 EC 0C D9 5C 24'
        }
        $definitions = @(Get-CameraFixDefinitions)
        Assert-CameraFixEqual -Expected 3 -Actual $definitions.Count -Message 'The patch definition count changed.'
        Assert-CameraFixEqual -Expected $expected.WobbleOriginal -Actual (ConvertTo-CameraFixHexString $definitions[0].Original) -Message 'Wobble original bytes changed.'
        Assert-CameraFixEqual -Expected $expected.WobblePatched -Actual (ConvertTo-CameraFixHexString $definitions[0].Patched) -Message 'Wobble patched bytes changed.'
        Assert-CameraFixEqual -Expected $expected.HorizontalOriginal -Actual (ConvertTo-CameraFixHexString $definitions[1].Original) -Message 'Horizontal original bytes changed.'
        Assert-CameraFixEqual -Expected $expected.HorizontalPatched -Actual (ConvertTo-CameraFixHexString $definitions[1].Patched) -Message 'Horizontal patched bytes changed.'
        Assert-CameraFixEqual -Expected $expected.VerticalOriginal -Actual (ConvertTo-CameraFixHexString $definitions[2].Original) -Message 'Vertical original bytes changed.'
        Assert-CameraFixEqual -Expected $expected.VerticalPatched -Actual (ConvertTo-CameraFixHexString $definitions[2].Patched) -Message 'Vertical patched bytes changed.'
    }

    Invoke-CameraFixTest 'Disposable compatible PE fixture is created and classified as unpatched' {
        $fixtureSource = @'
using System;
using System.Reflection;

[assembly: AssemblyVersion("1.1.743.0")]
[assembly: AssemblyFileVersion("1.1.743.0")]

namespace TombRaiderCameraFixFixture
{
    internal static class Program
    {
        private static readonly byte[] Wobble = new byte[] { 0x8B, 0xCF, 0xE8, 0xDB, 0xFD, 0x41, 0x00, 0x84, 0xC0, 0x74, 0x14, 0x56 };
        private static readonly byte[] Horizontal = new byte[] { 0x08, 0xB0, 0x01, 0xD9, 0x9E, 0xA0, 0x0F, 0x00, 0x00 };
        private static readonly byte[] Vertical = new byte[] { 0xD9, 0x5E, 0x04, 0xD9, 0x44, 0x24, 0x0C, 0xD9, 0x5E, 0x0C, 0xD9, 0x44, 0x24, 0x18, 0xD9, 0x5E, 0x10, 0xC6, 0x87, 0xC4, 0x0F, 0x00, 0x00, 0x01, 0xE9, 0xA2, 0xFE, 0xFF, 0xFF, 0xDD, 0xD8, 0x6A, 0x00, 0xD9, 0x87, 0x40, 0x06, 0x00, 0x00, 0x83, 0xEC, 0x0C, 0xD9, 0x5C, 0x24 };

        [STAThread]
        private static void Main()
        {
            if ((Wobble.Length + Horizontal.Length + Vertical.Length) == 0)
            {
                throw new InvalidOperationException();
            }
        }
    }

}
'@
        $compilerParameters = New-Object CodeDom.Compiler.CompilerParameters
        $compilerParameters.CompilerOptions = '/platform:x86 /target:winexe /optimize-'
        $compilerParameters.GenerateExecutable = $true
        $compilerParameters.GenerateInMemory = $false
        $compilerParameters.OutputAssembly = $script:FixtureSeedPath
        $compiler = New-Object Microsoft.CSharp.CSharpCodeProvider
        try {
            $compilerResult = $compiler.CompileAssemblyFromSource($compilerParameters, $fixtureSource)
            $compilerErrors = @($compilerResult.Errors | Where-Object { -not $_.IsWarning })
            if ($compilerErrors.Count -gt 0) {
                $errorText = (($compilerErrors | ForEach-Object { "line $($_.Line): $($_.ErrorText)" }) -join '; ')
                throw "The disposable fixture did not compile: $errorText"
            }
        }
        finally {
            $compiler.Dispose()
        }
        $status = Get-CameraFixStatus -Path $script:FixtureSeedPath
        Assert-CameraFixEqual -Expected 'Unpatched' -Actual $status.State -Message "The disposable PE was not classified as unpatched. $($status.Reason)"
        Assert-CameraFixEqual -Expected '1.1.743.0' -Actual $status.FileVersion -Message 'The disposable PE file version is wrong.'
        Assert-CameraFixTest -Condition $status.Pe.IsExpectedArchitecture -Message 'The disposable PE is not 32-bit x86.'
        Assert-CameraFixTest -Condition $status.Pe.IsGuiExecutable -Message 'The disposable PE is not a Windows GUI executable.'
        foreach ($pattern in $status.Patterns) {
            Assert-CameraFixEqual -Expected 'Unpatched' -Actual $pattern.Classification -Message "$($pattern.Name) was not uniquely unpatched in the fixture."
        }
    }

    Invoke-CameraFixTest 'Unsupported build, architecture and subsystem metadata are rejected' {
        $wrongVersionPath = Copy-CameraFixFixture -Name 'wrong-version'
        $wrongVersionBytes = [IO.File]::ReadAllBytes($wrongVersionPath)
        $fixedInfoSignature = [byte[]](ConvertFrom-CameraFixHex 'BD 04 EF FE')
        $binaryText = [Text.Encoding]::GetEncoding(28591).GetString($wrongVersionBytes)
        $signatureOffsets = @(Find-CameraFixBytePattern -BinaryText $binaryText -Pattern $fixedInfoSignature)
        Assert-CameraFixEqual -Expected 1 -Actual $signatureOffsets.Count -Message 'The fixture version metadata signature is not unique.'
        $wrongVersionBytes[$signatureOffsets[0] + 14] = 0xE6
        [IO.File]::WriteAllBytes($wrongVersionPath, $wrongVersionBytes)
        $wrongVersionStatus = Get-CameraFixStatus -Path $wrongVersionPath
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual $wrongVersionStatus.State -Message 'A non-743 file version was not rejected.'
        Assert-CameraFixEqual -Expected '1.1.742.0' -Actual $wrongVersionStatus.FileVersion -Message 'The wrong-version fixture was not prepared correctly.'

        $wrongArchitecturePath = Copy-CameraFixFixture -Name 'wrong-architecture'
        $wrongArchitectureBytes = [IO.File]::ReadAllBytes($wrongArchitecturePath)
        $peOffset = [BitConverter]::ToInt32($wrongArchitectureBytes, 0x3C)
        $wrongArchitectureBytes[$peOffset + 4] = 0x64
        $wrongArchitectureBytes[$peOffset + 5] = 0x86
        [IO.File]::WriteAllBytes($wrongArchitecturePath, $wrongArchitectureBytes)
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual (Get-CameraFixStatus -Path $wrongArchitecturePath).State -Message 'A non-x86 executable was not rejected.'

        $consolePath = Copy-CameraFixFixture -Name 'wrong-subsystem'
        $consoleBytes = [IO.File]::ReadAllBytes($consolePath)
        $consolePeOffset = [BitConverter]::ToInt32($consoleBytes, 0x3C)
        $optionalOffset = $consolePeOffset + 24
        $consoleBytes[$optionalOffset + 68] = 0x03
        $consoleBytes[$optionalOffset + 69] = 0x00
        [IO.File]::WriteAllBytes($consolePath, $consoleBytes)
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual (Get-CameraFixStatus -Path $consolePath).State -Message 'A non-GUI executable was not rejected.'
    }

    Invoke-CameraFixTest 'Partial, missing, duplicated and conflicting pattern states are detected safely' {
        $seedInspection = Get-CameraFixInspection -Path $script:FixtureSeedPath -RequireTargetName
        $definitions = @(Get-CameraFixDefinitions)

        $partialPath = Copy-CameraFixFixture -Name 'partial-state'
        $wobble = @($seedInspection.Patterns | Where-Object { $_.Key -eq 'Wobble' })[0]
        Set-CameraFixBytesAtOffset -Path $partialPath -Offset $wobble.OriginalOffsets[0] -Bytes $definitions[0].Patched
        Assert-CameraFixEqual -Expected 'PartiallyPatched' -Actual (Get-CameraFixStatus -Path $partialPath).State -Message 'A partly patched fixture was not detected.'

        $missingPath = Copy-CameraFixFixture -Name 'missing-state'
        $missingBytes = New-Object byte[] $definitions[0].Original.Length
        for ($index = 0; $index -lt $missingBytes.Length; $index++) { $missingBytes[$index] = 0xCC }
        Set-CameraFixBytesAtOffset -Path $missingPath -Offset $wobble.OriginalOffsets[0] -Bytes $missingBytes
        $missingStatus = Get-CameraFixStatus -Path $missingPath
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual $missingStatus.State -Message 'A missing pattern was not rejected.'
        Assert-CameraFixEqual -Expected 'Missing' -Actual (@($missingStatus.Patterns | Where-Object { $_.Key -eq 'Wobble' })[0].Classification) -Message 'The missing pattern classification is wrong.'

        $duplicatedPath = Copy-CameraFixFixture -Name 'duplicated-state'
        Add-CameraFixBytesToFile -Path $duplicatedPath -BytesToAppend $definitions[0].Original
        $duplicatedStatus = Get-CameraFixStatus -Path $duplicatedPath
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual $duplicatedStatus.State -Message 'A duplicated pattern was not rejected.'
        Assert-CameraFixEqual -Expected 'Duplicated' -Actual (@($duplicatedStatus.Patterns | Where-Object { $_.Key -eq 'Wobble' })[0].Classification) -Message 'The duplicated pattern classification is wrong.'

        $conflictingPath = Copy-CameraFixFixture -Name 'conflicting-state'
        Add-CameraFixBytesToFile -Path $conflictingPath -BytesToAppend $definitions[0].Patched
        $conflictingStatus = Get-CameraFixStatus -Path $conflictingPath
        Assert-CameraFixEqual -Expected 'Unsupported' -Actual $conflictingStatus.State -Message 'Conflicting original and patched patterns were not rejected.'
        Assert-CameraFixEqual -Expected 'Conflicting' -Actual (@($conflictingStatus.Patterns | Where-Object { $_.Key -eq 'Wobble' })[0].Classification) -Message 'The conflicting pattern classification is wrong.'
    }

    Invoke-CameraFixTest 'Apply changes only expected regions, preserves backups, repeats safely and restores exactly' {
        $path = Copy-CameraFixFixture -Name 'apply-restore'
        $originalBytes = [IO.File]::ReadAllBytes($path)
        $originalInspection = Get-CameraFixInspection -Path $path -RequireTargetName
        $regions = @(Get-CameraFixRegionsFromUnpatchedInspection -Inspection $originalInspection)

        $apply = Invoke-CameraFixApply -ExePath $path
        Assert-CameraFixTest -Condition $apply.Changed -Message 'The first apply did not report a change.'
        Assert-CameraFixTest -Condition $apply.BackupCreated -Message 'The first apply did not create a backup.'
        Assert-CameraFixEqual -Expected 'CompletelyPatched' -Actual (Get-CameraFixStatus -Path $path).State -Message 'The applied fixture is not completely patched.'

        $patchedBytes = [IO.File]::ReadAllBytes($path)
        $changeCheck = Test-CameraFixExpectedChanges -Original $originalBytes -Modified $patchedBytes -Regions $regions
        Assert-CameraFixTest -Condition $changeCheck.Valid -Message "Apply changed unexpected bytes. $($changeCheck.Reason)"

        $backup = Test-CameraFixOriginalBackup -ExePath $path
        Assert-CameraFixTest -Condition $backup.Valid -Message "The created backup is not valid. $($backup.Reason)"
        $backupHashBefore = Get-CameraFixRawSha256 -Path $backup.Sidecars.BackupPath
        $manifestBefore = [IO.File]::ReadAllText($backup.Sidecars.ManifestPath)
        $patchedHashBefore = Get-CameraFixRawSha256 -Path $path
        $patchedTimeBefore = ([IO.FileInfo]$path).LastWriteTimeUtc

        $secondApply = Invoke-CameraFixApply -ExePath $path
        Assert-CameraFixTest -Condition (-not $secondApply.Changed) -Message 'A repeated apply unexpectedly rewrote the fixture.'
        Assert-CameraFixEqual -Expected $patchedHashBefore -Actual (Get-CameraFixRawSha256 -Path $path) -Message 'A repeated apply changed the executable hash.'
        Assert-CameraFixEqual -Expected $patchedTimeBefore -Actual ([IO.FileInfo]$path).LastWriteTimeUtc -Message 'A repeated apply changed the executable timestamp.'

        $restore = Invoke-CameraFixRestore -ExePath $path
        Assert-CameraFixTest -Condition $restore.Changed -Message 'Restore did not report a change.'
        Assert-CameraFixEqual -Expected (Get-CameraFixSha256FromBytes -Bytes $originalBytes) -Actual (Get-CameraFixRawSha256 -Path $path) -Message 'Restore did not reproduce the original bytes.'

        $reapply = Invoke-CameraFixApply -ExePath $path
        Assert-CameraFixTest -Condition $reapply.Changed -Message 'Reapply after restore did not patch the fixture.'
        Assert-CameraFixTest -Condition (-not $reapply.BackupCreated) -Message 'Reapply replaced an existing valid backup.'
        Assert-CameraFixEqual -Expected $backupHashBefore -Actual (Get-CameraFixRawSha256 -Path $backup.Sidecars.BackupPath) -Message 'The valid backup changed during repeated use.'
        Assert-CameraFixEqual -Expected $manifestBefore -Actual ([IO.File]::ReadAllText($backup.Sidecars.ManifestPath)) -Message 'The valid manifest changed during repeated use.'

        $null = Invoke-CameraFixRestore -ExePath $path
        $secondRestore = Invoke-CameraFixRestore -ExePath $path
        Assert-CameraFixTest -Condition (-not $secondRestore.Changed) -Message 'Restoring an already original fixture was not a safe no-op.'
    }

    Invoke-CameraFixTest 'A valid backup can safely complete a partially patched executable' {
        $path = Copy-CameraFixFixture -Name 'partial-completion'
        $null = Invoke-CameraFixApply -ExePath $path
        $null = Invoke-CameraFixRestore -ExePath $path
        $inspection = Get-CameraFixInspection -Path $path -RequireTargetName
        $definitions = @(Get-CameraFixDefinitions)
        $wobble = @($inspection.Patterns | Where-Object { $_.Key -eq 'Wobble' })[0]
        Set-CameraFixBytesAtOffset -Path $path -Offset $wobble.OriginalOffsets[0] -Bytes $definitions[0].Patched
        Assert-CameraFixEqual -Expected 'PartiallyPatched' -Actual (Get-CameraFixStatus -Path $path).State -Message 'The prepared partial state is wrong.'
        $result = Invoke-CameraFixApply -ExePath $path
        Assert-CameraFixTest -Condition $result.Changed -Message 'The valid partial executable was not completed.'
        Assert-CameraFixEqual -Expected 'CompletelyPatched' -Actual (Get-CameraFixStatus -Path $path).State -Message 'The partial executable was not completed safely.'
    }

    Invoke-CameraFixTest 'Incomplete and invalid backup sets are refused and preserved' {
        $incompletePath = Copy-CameraFixFixture -Name 'incomplete-backup'
        $incompleteSidecars = Get-CameraFixSidecarPaths -ExePath $incompletePath
        [IO.File]::Copy($incompletePath, $incompleteSidecars.BackupPath, $false)
        $incompleteHash = Get-CameraFixRawSha256 -Path $incompleteSidecars.BackupPath
        $null = Assert-CameraFixThrows -Action { New-CameraFixOriginalBackup -ExePath $incompletePath } -MessagePattern 'not trustworthy|incomplete'
        Assert-CameraFixEqual -Expected $incompleteHash -Actual (Get-CameraFixRawSha256 -Path $incompleteSidecars.BackupPath) -Message 'The incomplete backup was overwritten.'
        Assert-CameraFixTest -Condition (-not [IO.File]::Exists($incompleteSidecars.ManifestPath)) -Message 'A manifest was created beside an incomplete backup.'

        $invalidPath = Copy-CameraFixFixture -Name 'invalid-backup'
        $invalidStatus = Get-CameraFixStatus -Path $invalidPath
        $invalidSidecars = Get-CameraFixSidecarPaths -ExePath $invalidPath
        [IO.File]::Copy($invalidPath, $invalidSidecars.BackupPath, $false)
        $invalidManifest = [ordered]@{
            SchemaVersion = 1
            Tool = 'Tomb Raider Complete Camera Fix'
            OriginalFilename = 'TombRaider.exe'
            FileVersion = '1.1.743.0'
            Size = [int64]$invalidStatus.Size
            SHA256 = ('0' * 64)
            StoredPEChecksum = ('0x{0:X8}' -f $invalidStatus.Pe.StoredChecksum)
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json
        [IO.File]::WriteAllText($invalidSidecars.ManifestPath, $invalidManifest, (New-Object Text.UTF8Encoding($false)))
        $backupHash = Get-CameraFixRawSha256 -Path $invalidSidecars.BackupPath
        $manifestText = [IO.File]::ReadAllText($invalidSidecars.ManifestPath)
        $validation = Test-CameraFixOriginalBackup -ExePath $invalidPath
        Assert-CameraFixTest -Condition (-not $validation.Valid) -Message 'The invalid backup was trusted.'
        $null = Assert-CameraFixThrows -Action { Invoke-CameraFixApply -ExePath $invalidPath } -MessagePattern 'not trustworthy|failed validation'
        Assert-CameraFixEqual -Expected $backupHash -Actual (Get-CameraFixRawSha256 -Path $invalidSidecars.BackupPath) -Message 'The invalid backup was overwritten.'
        Assert-CameraFixEqual -Expected $manifestText -Actual ([IO.File]::ReadAllText($invalidSidecars.ManifestPath)) -Message 'The invalid manifest was overwritten.'
    }

    Invoke-CameraFixTest 'Apply failure hooks leave the live fixture original and clean' {
        foreach ($failurePoint in @('AfterBackup', 'AfterTempWrite', 'BeforeReplace', 'AfterReplace')) {
            $path = Copy-CameraFixFixture -Name ("apply-failure-$failurePoint")
            $originalHash = Get-CameraFixRawSha256 -Path $path
            $null = Assert-CameraFixThrows -Action { Invoke-CameraFixApply -ExePath $path -FailurePoint $failurePoint } -MessagePattern 'Simulated failure'
            Assert-CameraFixEqual -Expected $originalHash -Actual (Get-CameraFixRawSha256 -Path $path) -Message "$failurePoint did not preserve or roll back the live executable."
            Assert-CameraFixEqual -Expected 'Unpatched' -Actual (Get-CameraFixStatus -Path $path).State -Message "$failurePoint left the fixture patched."
            $backup = Test-CameraFixOriginalBackup -ExePath $path
            Assert-CameraFixTest -Condition $backup.Valid -Message "$failurePoint did not preserve the verified original backup."
            $leftovers = @(Get-ChildItem -LiteralPath ([IO.Path]::GetDirectoryName($path)) -Force | Where-Object { $_.Name -like '.TombRaiderCameraFix-*' })
            Assert-CameraFixEqual -Expected 0 -Actual $leftovers.Count -Message "$failurePoint left temporary or rollback files behind."
        }
    }

    Invoke-CameraFixTest 'Restore failure hooks leave the live fixture patched and recoverable' {
        foreach ($failurePoint in @('AfterTempWrite', 'BeforeReplace', 'AfterReplace')) {
            $path = Copy-CameraFixFixture -Name ("restore-failure-$failurePoint")
            $null = Invoke-CameraFixApply -ExePath $path
            $patchedHash = Get-CameraFixRawSha256 -Path $path
            $null = Assert-CameraFixThrows -Action { Invoke-CameraFixRestore -ExePath $path -FailurePoint $failurePoint } -MessagePattern 'Simulated failure'
            Assert-CameraFixEqual -Expected $patchedHash -Actual (Get-CameraFixRawSha256 -Path $path) -Message "$failurePoint did not preserve or roll back the patched executable."
            Assert-CameraFixEqual -Expected 'CompletelyPatched' -Actual (Get-CameraFixStatus -Path $path).State -Message "$failurePoint did not leave the fixture in a verified patched state."
            Assert-CameraFixTest -Condition (Test-CameraFixOriginalBackup -ExePath $path).Valid -Message "$failurePoint damaged the verified original backup."
        }
    }

    Invoke-CameraFixTest 'Windows installation paths are normalized and deduplicated case-insensitively' {
        $displayPath = Join-Path $script:TestRoot 'Normally Cased\TombRaider.exe'
        $uniquePaths = @(Select-CameraFixUniqueWindowsPaths -Path @($displayPath, $displayPath.ToLowerInvariant(), "$displayPath\"))
        Assert-CameraFixEqual -Expected 1 -Actual $uniquePaths.Count -Message 'Capitalization or a trailing separator produced a duplicate Windows path.'
        Assert-CameraFixEqual -Expected ([IO.Path]::GetFullPath($displayPath)) -Actual $uniquePaths[0] -Message 'The first normalized path spelling was not preserved for display.'
    }

    Invoke-CameraFixTest 'Steam discovery merges duplicate methods but keeps separate installations' {

        $steamRoot = Join-Path $script:TestRoot 'fake-steam'
        $secondLibrary = Join-Path $script:TestRoot 'fake-library'
        $rootGameDirectory = Join-Path $steamRoot 'steamapps\common\Tomb Raider'
        $libraryGameDirectory = Join-Path $secondLibrary 'steamapps\common\Tomb Raider'
        [IO.Directory]::CreateDirectory((Join-Path $steamRoot 'steamapps')) | Out-Null
        [IO.Directory]::CreateDirectory($rootGameDirectory) | Out-Null
        [IO.Directory]::CreateDirectory($libraryGameDirectory) | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $rootGameDirectory 'TombRaider.exe'), [byte[]]@())
        [IO.File]::WriteAllBytes((Join-Path $libraryGameDirectory 'TombRaider.exe'), [byte[]]@())

        $escapedRootPath = $steamRoot.ToLowerInvariant().Replace('\', '\\')
        $escapedLibraryPath = $secondLibrary.Replace('\', '\\')
        $vdf = '"libraryfolders"' + [Environment]::NewLine + '{' + [Environment]::NewLine + '  "0"' + [Environment]::NewLine + '  {' + [Environment]::NewLine + "    `"path`" `"$escapedRootPath`"" + [Environment]::NewLine + '  }' + [Environment]::NewLine + '  "1"' + [Environment]::NewLine + '  {' + [Environment]::NewLine + "    `"path`" `"$escapedLibraryPath`"" + [Environment]::NewLine + '  }' + [Environment]::NewLine + '}'
        [IO.File]::WriteAllText((Join-Path $steamRoot 'steamapps\libraryfolders.vdf'), $vdf, (New-Object Text.UTF8Encoding($false)))

        $found = @(Find-CameraFixSteamExecutables -SteamRoots @($steamRoot, $steamRoot.ToUpperInvariant()))
        Assert-CameraFixEqual -Expected 2 -Actual $found.Count -Message 'Duplicate discovery methods were not merged, or separate installations were lost.'
        Assert-CameraFixTest -Condition ($found -contains (Join-Path $rootGameDirectory 'TombRaider.exe')) -Message 'The primary Steam installation was not discovered.'
        Assert-CameraFixTest -Condition ($found -contains (Join-Path $libraryGameDirectory 'TombRaider.exe')) -Message 'The secondary Steam library installation was not discovered.'
        Assert-CameraFixEqual -Expected (Join-Path $libraryGameDirectory 'TombRaider.exe') -Actual (Resolve-CameraFixExePath -RequestedPath $libraryGameDirectory) -Message 'A requested game directory did not resolve to TombRaider.exe.'
    }

    Invoke-CameraFixTest 'A single unique Steam installation is selected automatically' {
        $singleSteamRoot = Join-Path $script:TestRoot 'single-steam'
        $singleGameDirectory = Join-Path $singleSteamRoot 'steamapps\common\Tomb Raider'
        $singleExecutable = Join-Path $singleGameDirectory 'TombRaider.exe'
        [IO.Directory]::CreateDirectory($singleGameDirectory) | Out-Null
        [IO.File]::WriteAllBytes($singleExecutable, [byte[]]@())

        $previousRoots = [Environment]::GetEnvironmentVariable('TRCF_STEAM_ROOTS', 'Process')
        try {
            $duplicateRoots = $singleSteamRoot + [IO.Path]::PathSeparator + $singleSteamRoot.ToUpperInvariant()
            [Environment]::SetEnvironmentVariable('TRCF_STEAM_ROOTS', $duplicateRoots, 'Process')
            $selected = Resolve-CameraFixExePath
            Assert-CameraFixEqual -Expected $singleExecutable -Actual $selected -Message 'The single unique installation was not selected automatically.'
        }
        finally {
            [Environment]::SetEnvironmentVariable('TRCF_STEAM_ROOTS', $previousRoots, 'Process')
        }
    }

    Invoke-CameraFixTest 'Generated Batch launcher loads embedded PowerShell and preserves CLI action exits' {
        $missingPath = Join-Path $script:TestRoot 'launcher-smoke\TombRaider.exe'
        $statusResult = Invoke-CameraFixReleaseBatch -Arguments @($missingPath, '-Action', 'Status')
        Assert-CameraFixEqual -Expected 0 -Actual $statusResult.ExitCode -Message 'The launcher Status action returned the wrong exit code.'
        Assert-CameraFixTest -Condition ($statusResult.Output.Contains('Status: UNSUPPORTED.')) -Message 'The launcher did not load and report unsupported status.'

        $applyResult = Invoke-CameraFixReleaseBatch -Arguments @($missingPath, '-Action', 'Apply', '-ApplyConfirmed')
        Assert-CameraFixEqual -Expected 1 -Actual $applyResult.ExitCode -Message 'The launcher Apply action did not preserve the safe failure exit code.'
        Assert-CameraFixTest -Condition ($applyResult.Output.Contains('Nothing was changed.')) -Message 'The launcher did not fail safely for an unsupported Apply target.'
        Assert-CameraFixTest -Condition (-not [IO.File]::Exists($missingPath)) -Message 'The launcher created or modified the nonexistent target.'
    }
}
finally {
    Remove-CameraFixTestRoot -Path $script:TestRoot
}

Write-Host ''
if ($script:FailedTests.Count -gt 0) {
    Write-Host "$($script:PassedTestCount) test groups passed; $($script:FailedTests.Count) failed." -ForegroundColor Red
    foreach ($failure in $script:FailedTests) {
        Write-Host "  $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "$($script:PassedTestCount) test groups passed. All fixtures were disposable synthetic files." -ForegroundColor Green
exit 0
