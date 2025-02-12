<#
.SYNOPSIS
    Sanitize a Windows system by removing or clearing sensitive data such as:
    - Wi-Fi profiles
    - Browsing history/cache (for Internet Explorer/Edge/Chrome/Firefox if present)
    - Windows Event Logs
    - Temp files
    - Recycle Bin
    - DNS cache
    - Optionally user profiles
    - Optionally enable pagefile clearing at shutdown

.DESCRIPTION
    This script is designed for lab image preparation, removing artifacts that
    could identify the lab creator or compromise privacy.

.NOTES
    Run as Administrator on a system you are about to image or share.
    Use at your own risk; thoroughly test for your specific environment.

.LINK
    https://docs.microsoft.com/en-us/windows/deployment/sysprep/sysprep-process-overview
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Switch] $RemoveNonDefaultProfiles = $false,
    [Switch] $ClearPageFileAtShutdown = $false
)

function Remove-WiFiProfiles {
    Write-Host "Removing all Wi-Fi profiles..."
    # This deletes all saved Wi-Fi profiles
    netsh wlan delete profile name=* | Out-Null
}

function Clear-EventLogs {
    Write-Host "Clearing Windows Event Logs..."
    wevtutil el | ForEach-Object {
        Write-Host "Clearing log: $_"
        wevtutil cl $_
    }
}

function Clear-BrowserData {
    Write-Host "Clearing common browser data..."

    # Internet Explorer / Legacy Edge
    Write-Host " - Internet Explorer / Legacy Edge"
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255  # Clears most IE data

    # If Chromium-based Microsoft Edge is installed:
    $edgePath = "$($env:LOCALAPPDATA)\Microsoft\Edge\User Data\Default"
    if (Test-Path $edgePath) {
        Write-Host " - Chromium Edge data found; removing..."
        Remove-Item -Path "$edgePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Google Chrome
    $chromePath = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default"
    if (Test-Path $chromePath) {
        Write-Host " - Chrome data found; removing..."
        Remove-Item -Path "$chromePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Mozilla Firefox
    $firefoxPath = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxPath) {
        Write-Host " - Firefox data found; removing..."
        Remove-Item -Path "$firefoxPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Clear-TempFiles {
    Write-Host "Clearing temporary files..."

    # Windows Temp
    $windowsTemp = "C:\Windows\Temp"
    if (Test-Path $windowsTemp) {
        Write-Host " - Removing files in: $windowsTemp"
        Get-ChildItem -Path $windowsTemp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Current user's Temp
    if ($env:TEMP) {
        Write-Host " - Removing files in: $env:TEMP"
        Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Clear-RecycleBin {
    Write-Host "Clearing Recycle Bin..."
    # PowerShell v5+ has a cmdlet for this:
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Could not clear Recycle Bin via Clear-RecycleBin. Attempting manual approach..."
        $recyclePaths = @(
            "$env:SystemDrive\$Recycle.Bin",
            "$env:SystemDrive\Recycler"
        )
        foreach ($path in $recyclePaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Flush-DNSCache {
    Write-Host "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
}

function Remove-NonDefaultUserProfiles {
    Write-Host "Removing non-default user profiles..."

    # Typically excludes Administrator, Default, Public.
    # Adjust filters as needed.
    $profiles = Get-WmiObject -Class Win32_UserProfile -Filter "LocalPath NOT LIKE '%\\Default%' AND LocalPath NOT LIKE '%\\Public%' AND LocalPath NOT LIKE '%\\Administrator%'"
    foreach ($profile in $profiles) {
        Write-Host " - Deleting profile: $($profile.LocalPath)"
        $profile.Delete()
    }
}

function Enable-PageFileClearAtShutdown {
    Write-Host "Enabling page file clearing at shutdown..."
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' `
                     -Name ClearPageFileAtShutdown -Value 1
}

Write-Host "===== Starting System Sanitization ====="

# 1. Remove Wi-Fi Profiles
Remove-WiFiProfiles

# 2. Clear Event Logs
Clear-EventLogs

# 3. Clear Browser Data
Clear-BrowserData

# 4. Clear Temporary Files
Clear-TempFiles

# 5. Clear Recycle Bin
Clear-RecycleBin

# 6. Flush DNS Cache
Flush-DNSCache

# 7. Remove Non-Default User Profiles (optional)
if ($RemoveNonDefaultProfiles) {
    Remove-NonDefaultUserProfiles
}

# 8. Enable Page File clearing at shutdown (optional)
if ($ClearPageFileAtShutdown) {
    Enable-PageFileClearAtShutdown
}

Write-Host "===== System Sanitization Complete ====="
Write-Host "Note: A reboot is recommended to finalize some changes (especially pagefile clearing)."
