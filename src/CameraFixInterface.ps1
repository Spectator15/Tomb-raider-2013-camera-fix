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

function Get-CameraFixDefaultSteamRoots {
    [CmdletBinding()]
    param()

    $override = [Environment]::GetEnvironmentVariable('TRCF_STEAM_ROOTS', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        return @($override.Split([IO.Path]::PathSeparator) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
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

    return @($roots | ForEach-Object {
        try { [IO.Path]::GetFullPath($_) } catch { $null }
    } | Where-Object { $_ } | Select-Object -Unique)
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
    return @($libraries | Select-Object -Unique)
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
    return @($found | Select-Object -Unique)
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
