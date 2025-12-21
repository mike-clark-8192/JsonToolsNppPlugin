# DeployPlugin.ps1
# Deploys JsonTools plugin to Notepad++

param(
    [string]$Configuration = "Debug",
    [string]$Platform = "x64"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$binPath = Join-Path $projectRoot "JsonToolsNppPlugin\bin\$Configuration-$Platform"
$sourceDll = Join-Path $binPath "JsonTools.dll"
$nppPluginsPath = "C:\Program Files\Notepad++\plugins\JsonTools"
$destDll = Join-Path $nppPluginsPath "JsonTools.dll"

Write-Host "JsonTools Plugin Deployment Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Precondition 1: Check if source DLL exists
Write-Host "[1/5] Checking if source DLL exists..." -ForegroundColor Yellow
if (!(Test-Path $sourceDll)) {
    Write-Host "ERROR: Source DLL not found at: $sourceDll" -ForegroundColor Red
    Write-Host "Please build the project first (Configuration: $Configuration, Platform: $Platform)" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Source DLL found: $sourceDll" -ForegroundColor Green
$dllInfo = Get-Item $sourceDll
Write-Host "    Size: $($dllInfo.Length) bytes" -ForegroundColor Gray
Write-Host "    Modified: $($dllInfo.LastWriteTime)" -ForegroundColor Gray
Write-Host ""

# Precondition 2: Check if Notepad++ is installed
Write-Host "[2/5] Checking if Notepad++ is installed..." -ForegroundColor Yellow
$nppPath = "C:\Program Files\Notepad++\notepad++.exe"
if (!(Test-Path $nppPath)) {
    Write-Host "ERROR: Notepad++ not found at: $nppPath" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Notepad++ found" -ForegroundColor Green
Write-Host ""

# Precondition 3: Check if Notepad++ is running
Write-Host "[3/5] Checking if Notepad++ is running..." -ForegroundColor Yellow
$nppProcess = Get-Process -Name "notepad++" -ErrorAction SilentlyContinue
if ($nppProcess) {
    Write-Host "  WARNING: Notepad++ is currently running!" -ForegroundColor Yellow
    Write-Host "  The DLL may be locked. You may need to close Notepad++ first." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "  Do you want to continue anyway? (y/n)"
    if ($response -ne "y") {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "  [OK] Notepad++ is not running" -ForegroundColor Green
}
Write-Host ""

# Precondition 4: Check if we have admin rights
Write-Host "[4/5] Checking administrator privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click the script and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Running with administrator privileges" -ForegroundColor Green
Write-Host ""

# Precondition 5: Create destination directory if needed
Write-Host "[5/5] Preparing destination directory..." -ForegroundColor Yellow
if (!(Test-Path $nppPluginsPath)) {
    Write-Host "  Creating directory: $nppPluginsPath" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $nppPluginsPath -Force | Out-Null
}
Write-Host "  [OK] Destination directory ready" -ForegroundColor Green
Write-Host ""

# Deploy the DLL and dependencies
Write-Host "Deploying plugin..." -ForegroundColor Cyan
try {
    # Copy main DLL
    Copy-Item -Path $sourceDll -Destination $destDll -Force
    Write-Host "  [OK] Successfully copied DLL to: $destDll" -ForegroundColor Green

    # Copy dependency DLLs
    $dependencies = @(
        "System.Resources.Extensions.dll",
        "System.Memory.dll",
        "System.Buffers.dll",
        "System.Runtime.CompilerServices.Unsafe.dll",
        "System.Numerics.Vectors.dll"
    )

    $copiedCount = 0
    foreach ($dep in $dependencies) {
        $sourceDep = Join-Path $binPath $dep
        if (Test-Path $sourceDep) {
            $destDep = Join-Path $nppPluginsPath $dep
            Copy-Item -Path $sourceDep -Destination $destDep -Force
            $copiedCount++
        }
    }

    if ($copiedCount -gt 0) {
        Write-Host "  [OK] Copied $copiedCount dependency DLL(s)" -ForegroundColor Green
    }
    Write-Host ""

    # Copy translation files if they exist
    $translationSource = Join-Path $projectRoot "translation"
    $translationDest = Join-Path $nppPluginsPath "translation"

    if (Test-Path $translationSource) {
        Write-Host "Copying translation files..." -ForegroundColor Cyan
        if (!(Test-Path $translationDest)) {
            New-Item -ItemType Directory -Path $translationDest -Force | Out-Null
        }
        Copy-Item -Path "$translationSource\*.json5" -Destination $translationDest -Force
        $translationCount = (Get-ChildItem "$translationDest\*.json5").Count
        Write-Host "  [OK] Copied $translationCount translation file(s)" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now start Notepad++ to use the updated plugin." -ForegroundColor Cyan

} catch {
    Write-Host "ERROR: Failed to copy DLL" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
