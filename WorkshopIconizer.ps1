<#
    Steam Workshop Folder Icon Fixer
    ---------------------------------
    Run via WorkshopIconizer.bat, from inside:
        <SteamLibrary>\steamapps\workshop\content\

    What it does:
      1. Finds each numbered AppID subfolder.
      2. For each AppID, look up the matching installed game using Steam's
         library/appmanifest files locally.
      3. Picks a likely "main" exe for that game and pulls its icon.
      4. Shows the full list and asks for confirmation before touching anything.
      5. Sets each AppID folder's icon.

    Known limitations (heuristic, not guaranteed):
      - Picking the "main" exe out of a game folder is a best guess (see
        $ExcludeExePattern in .ps1 to tune it). Launchers/anti-cheat wrappers can
        sometimes cause the wrong icon to appear.
      - Games not currently installed locally or with missing launchers are skipped.
      - Icon quality is whatever Windows' default icon association returns for
        that exe; it is not always the highest-res icon embedded in the file.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDir
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------- Config ----------------------------------------
# Executables matching this (case-insensitive) are skipped when guessing the
# "main" game exe. Add to this if a folder keeps picking the wrong exe.
$ExcludeExePattern = '(?i)unins.*\.exe$|redist|vcredist|dxsetup|crashpad|crashhandler|battleye|easyanticheat|dotnetfx|_commonredist|helper\.exe$|report\.exe$|updater\.exe$|be_client\.exe$'

$IconCacheDir = Join-Path $env:LOCALAPPDATA 'SteamWorkshopIconizer\icons'

# ----------------------------- Helpers ----------------------------------------
function New-TopMostOwner {
    $owner = New-Object System.Windows.Forms.Form
    $owner.StartPosition = 'CenterScreen'
    $owner.Size = New-Object System.Drawing.Size(1, 1)
    $owner.ShowInTaskbar = $false
    $owner.TopMost = $true
    $owner.Opacity = 0
    $owner.FormBorderStyle = 'None'
    [void]$owner.Show()
    $owner.Activate()
    return $owner
}

function Show-Msg {
    param(
        [string]$Text,
        [string]$Title = "Steam Workshop Icon Fixer",
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    Write-Host ""
    Write-Host "[popup] $Title - if it doesn't appear on top, check your taskbar." -ForegroundColor Yellow
    $owner = New-TopMostOwner
    try {
        return [System.Windows.Forms.MessageBox]::Show($owner, $Text, $Title, $Buttons, $Icon)
    } finally {
        $owner.Close()
        $owner.Dispose()
    }
}

function Get-SteamPath {
    $candidates = @(
        @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' }
    )
    foreach ($c in $candidates) {
        try {
            $val = (Get-ItemProperty -Path $c.Path -Name $c.Name -ErrorAction Stop).($c.Name)
            if ($val) { return ($val -replace '/', '\') }
        } catch {}
    }
    return $null
}

function Get-SteamLibraries {
    $steamPath = Get-SteamPath
    $libraries = @()
    if (-not $steamPath) { return $libraries }

    $libraries += $steamPath
    $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdfPath) {
        $content = Get-Content -LiteralPath $vdfPath -Raw
        $pathMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($m in $pathMatches) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
            if ($libraries -notcontains $p) { $libraries += $p }
        }
    }
    return $libraries | Select-Object -Unique
}

function Find-GameExe {
    param([string]$InstallPath, [string]$InstallDirName)

    $exes = Get-ChildItem -LiteralPath $InstallPath -Filter *.exe -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludeExePattern }
    if (-not $exes) { return $null }

    $sameName = $exes | Where-Object { $_.BaseName -ieq $InstallDirName }
    if ($sameName) { return $sameName[0].FullName }

    $rootExes = $exes | Where-Object { $_.DirectoryName -ieq $InstallPath }
    if ($rootExes) {
        return ($rootExes | Sort-Object Length -Descending | Select-Object -First 1).FullName
    }

    return ($exes | Sort-Object Length -Descending | Select-Object -First 1).FullName
}

function Show-ConfirmForm {
    param($Results)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Steam Workshop Icon Fixer"
    $form.Size = New-Object System.Drawing.Size(640, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.Add_Shown({ $form.Activate() })

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "You can only manually undo these changes.`r`nThe folders below will get the icon of the game each belongs to:"
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(605, 40)
    $form.Controls.Add($label)

    $listView = New-Object System.Windows.Forms.ListView
    $listView.View = 'Details'
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.Location = New-Object System.Drawing.Point(10, 55)
    $listView.Size = New-Object System.Drawing.Size(605, 355)
    [void]$listView.Columns.Add("AppID", 80)
    [void]$listView.Columns.Add("Game", 280)
    [void]$listView.Columns.Add("Status", 225)

    foreach ($r in $Results) {
        $item = New-Object System.Windows.Forms.ListViewItem($r.AppId)
        [void]$item.SubItems.Add($r.Name)
        $statusText = if ($r.Status -eq "Ready") { "Will change icon" } else { $r.Status }
        [void]$item.SubItems.Add($statusText)
        if ($r.Status -ne "Ready") { $item.ForeColor = [System.Drawing.Color]::Gray }
        [void]$listView.Items.Add($item)
    }
    $form.Controls.Add($listView)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "OK"
    $okBtn.Location = New-Object System.Drawing.Point(445, 420)
    $okBtn.Size = New-Object System.Drawing.Size(80, 30)
    $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Location = New-Object System.Drawing.Point(535, 420)
    $cancelBtn.Size = New-Object System.Drawing.Size(80, 30)
    $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelBtn)

    $form.AcceptButton = $okBtn
    $form.CancelButton = $cancelBtn

    return $form.ShowDialog()
}

function Set-FolderIcon {
    param([string]$FolderPath, [string]$IconPath)

    $iniPath = Join-Path $FolderPath 'desktop.ini'
    if (Test-Path -LiteralPath $iniPath) {
        attrib -h -s "$iniPath" 2>$null
    }

    $iniContent = "[.ShellClassInfo]`r`nIconResource=$IconPath,0`r`n"
    Set-Content -LiteralPath $iniPath -Value $iniContent -Encoding ASCII -Force -NoNewline

    attrib +h +s "$iniPath"
    attrib +r "$FolderPath"
}

# ----------------------------- Step 1: Validate folder -------------------------
Write-Host "Steam Workshop Icon Fixer" -ForegroundColor Cyan
Write-Host "========================="
Write-Host "Target folder: $TargetDir"

$TargetDir = $TargetDir.Trim('"')
try {
    $normalized = ([System.IO.Path]::GetFullPath($TargetDir)).TrimEnd('\')
} catch {
    $normalized = $TargetDir.TrimEnd('\')
}
if ($normalized -notmatch '\\steamapps\\workshop\\content$') {
    Show-Msg -Text "This tool must be run from inside:`r`n`r`nsteamapps\workshop\content\`r`n`r`nMove both WorkshopIconizer.bat and WorkshopIconizer.ps1 into that folder and run it again." -Title "Wrong Folder" -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
Write-Host "Folder OK." -ForegroundColor Green

# ----------------------------- Step 2: Find AppID folders -----------------------
$appFolders = Get-ChildItem -LiteralPath $normalized -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d+$' }

if (-not $appFolders) {
    Show-Msg -Text "No workshop content folders found here."
    exit 0
}
Write-Host "Found $($appFolders.Count) workshop AppID folder(s): $(($appFolders.Name) -join ', ')"

# ----------------------------- Step 3: Find Steam libraries ---------------------
Write-Host "Looking up Steam libraries (registry)..."
$libraries = Get-SteamLibraries
if ($libraries.Count -eq 0) {
    Show-Msg -Text "Could not locate a Steam installation via the registry. Cannot look up games." -Title "Steam Not Found" -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
Write-Host "Found $($libraries.Count) librar$(if ($libraries.Count -eq 1) {'y'} else {'ies'}):"
$libraries | ForEach-Object { Write-Host "  $_" }

[System.IO.Directory]::CreateDirectory($IconCacheDir) | Out-Null

# ----------------------------- Step 4: Resolve each AppID -----------------------
Write-Host ""
Write-Host "Resolving each AppID against installed games (this scans install folders for exes, can take a bit on large libraries)..."
$results = @()

foreach ($folder in $appFolders) {
    $appId = $folder.Name
    Write-Host "  [$appId] checking..." -NoNewline
    $entry = [PSCustomObject]@{
        AppId        = $appId
        Name         = "(Unknown - AppID $appId)"
        Status       = "Not installed here"
        IconPath     = $null
        TargetFolder = $folder.FullName
    }

    foreach ($lib in $libraries) {
        $manifest = Join-Path $lib "steamapps\appmanifest_$appId.acf"
        if (-not (Test-Path -LiteralPath $manifest)) { continue }

        $content = Get-Content -LiteralPath $manifest -Raw
        $nameMatch = [regex]::Match($content, '"name"\s+"([^"]+)"')
        $dirMatch = [regex]::Match($content, '"installdir"\s+"([^"]+)"')
        if (-not $dirMatch.Success) { continue }

        $installDir = $dirMatch.Groups[1].Value
        $installPath = Join-Path $lib "steamapps\common\$installDir"
        if (-not (Test-Path -LiteralPath $installPath)) { continue }

        $entry.Name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { $installDir }

        $exe = Find-GameExe -InstallPath $installPath -InstallDirName $installDir
        if (-not $exe) {
            $entry.Status = "Installed, no exe found"
            break
        }

        try {
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
            if (-not $icon) {
                $entry.Status = "No icon in exe"
                break
            }
            $iconOut = Join-Path $IconCacheDir "$appId.ico"
            $fs = [System.IO.File]::Open($iconOut, [System.IO.FileMode]::Create)
            try { $icon.Save($fs) } finally { $fs.Close() }
            $icon.Dispose()

            $entry.IconPath = $iconOut
            $entry.Status = "Ready"
        } catch {
            $entry.Status = "Icon extraction failed"
        }
        break
    }

    $results += $entry
    $color = if ($entry.Status -eq "Ready") { "Green" } else { "DarkGray" }
    Write-Host (" -> {0} [{1}]" -f $entry.Name, $entry.Status) -ForegroundColor $color
}

# ----------------------------- Step 5: Confirm ----------------------------------
$readyCount = ($results | Where-Object { $_.Status -eq "Ready" }).Count
if ($readyCount -eq 0) {
    Show-Msg -Text "None of these could be matched to a local, installed game with a usable icon. Nothing to do."
    exit 0
}

Write-Host ""
Write-Host "$readyCount of $($results.Count) folder(s) are ready to change."
Write-Host ""
Write-Host "[popup] Confirmation window - if it doesn't appear on top, check your taskbar." -ForegroundColor Yellow
$confirm = Show-ConfirmForm -Results $results
if ($confirm -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Cancelled - no changes made." -ForegroundColor Yellow
    exit 0
}
Write-Host "Confirmed. Applying changes..."

# ----------------------------- Step 6: Apply -------------------------------------
$changed = 0
$errorList = @()
foreach ($r in $results) {
    if ($r.Status -eq "Ready" -and $r.IconPath) {
        try {
            Set-FolderIcon -FolderPath $r.TargetFolder -IconPath $r.IconPath
            $changed++
            Write-Host "  [$($r.AppId)] $($r.Name) -> icon set" -ForegroundColor Green
        } catch {
            $errorList += "$($r.AppId) ($($r.Name)): $($_.Exception.Message)"
            Write-Host "  [$($r.AppId)] $($r.Name) -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ----------------------------- Step 7: Done ---------------------------------------
$skipped = $results | Where-Object { $_.Status -ne "Ready" }
$summary = "Icons changed for $changed folder(s). You may need to refresh the folder (F5) to see results."

if ($skipped.Count -gt 0) {
    $skipLines = $skipped | ForEach-Object { "  $($_.AppId) - $($_.Name): $($_.Status)" }
    $summary += "`r`n`r`nSkipped:`r`n" + ($skipLines -join "`r`n")
}
if ($errorList.Count -gt 0) {
    $summary += "`r`n`r`nErrors:`r`n" + ($errorList -join "`r`n")
}

Write-Host ""
Write-Host "Done. $changed folder(s) changed." -ForegroundColor Cyan
Show-Msg -Text $summary -Title "Done"
