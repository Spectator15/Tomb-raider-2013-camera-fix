[CmdletBinding()]
param(
    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$templatePath = Join-Path $repositoryRoot 'src\TombRaider-Camera-Fix.template.bat'
$enginePath = Join-Path $repositoryRoot 'src\CameraFixEngine.ps1'
$interfacePath = Join-Path $repositoryRoot 'src\CameraFixInterface.ps1'
$embeddedMarker = '#__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repositoryRoot 'TombRaider-Camera-Fix.bat'
}
else {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
}

function Read-RequiredBuildSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not [IO.File]::Exists($Path)) {
        throw "Required release source is missing: $Path"
    }

    $text = [IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Required release source is empty: $Path"
    }
    return $text
}

function ConvertTo-ReleaseCrlf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $normalised = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $normalised = $normalised.TrimEnd([char[]]@("`r", "`n"))
    return $normalised.Replace("`n", "`r`n")
}

function Get-OrdinalOccurrenceCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $count = 0
    $start = 0
    while ($start -le ($Text.Length - $Value.Length)) {
        $found = $Text.IndexOf($Value, $start, [StringComparison]::Ordinal)
        if ($found -lt 0) {
            break
        }
        $count++
        $start = $found + $Value.Length
    }
    return $count
}

$template = Read-RequiredBuildSource -Path $templatePath
$engine = Read-RequiredBuildSource -Path $enginePath
$interface = Read-RequiredBuildSource -Path $interfacePath

if ((Get-OrdinalOccurrenceCount -Text $template -Value $embeddedMarker) -ne 1) {
    throw "The launcher template must contain exactly one embedded PowerShell marker: $embeddedMarker"
}
if (($engine.IndexOf($embeddedMarker, [StringComparison]::Ordinal) -ge 0) -or
    ($interface.IndexOf($embeddedMarker, [StringComparison]::Ordinal) -ge 0)) {
    throw 'The embedded PowerShell marker may appear only in the launcher template.'
}

$crlf = "`r`n"
$releaseText = @(
    (ConvertTo-ReleaseCrlf -Text $template)
    '# BEGIN GENERATED SOURCE: src/CameraFixEngine.ps1'
    (ConvertTo-ReleaseCrlf -Text $engine)
    '# END GENERATED SOURCE: src/CameraFixEngine.ps1'
    ''
    '# BEGIN GENERATED SOURCE: src/CameraFixInterface.ps1'
    (ConvertTo-ReleaseCrlf -Text $interface)
    '# END GENERATED SOURCE: src/CameraFixInterface.ps1'
) -join $crlf
$releaseText += $crlf

$unresolvedMarkerPattern = '(?im)^[ \t]*(?:rem[ \t]+|#[ \t]*)?(?:@@[A-Z][A-Z0-9_-]*@@|__CAMERAFIX_BUILD_[A-Z0-9_-]+__)[ \t]*$'
if ([Text.RegularExpressions.Regex]::IsMatch($releaseText, $unresolvedMarkerPattern)) {
    throw 'The generated release contains an unresolved build marker.'
}
if ((Get-OrdinalOccurrenceCount -Text $releaseText -Value $embeddedMarker) -ne 1) {
    throw 'The generated release does not contain exactly one embedded PowerShell marker.'
}

$outputDirectory = [IO.Path]::GetDirectoryName($OutputPath)
if (-not [IO.Directory]::Exists($outputDirectory)) {
    throw "The output directory does not exist: $outputDirectory"
}

$utf8WithoutBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($OutputPath, $releaseText, $utf8WithoutBom)

Write-Host "Built: $OutputPath"
