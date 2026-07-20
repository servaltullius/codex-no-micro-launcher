[CmdletBinding()]
param(
    [ValidateSet('Install', 'Prepare', 'Launch', 'Status', 'Uninstall')]
    [string]$Action = 'Launch'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:InstallRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\CodexNoMicro'
$script:RuntimesRoot = Join-Path $script:InstallRoot 'runtimes'
$script:InstalledScript = Join-Path $script:InstallRoot 'Codex-No-Micro.ps1'
$script:ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex (No Micro).lnk'
$script:LogPath = Join-Path $script:InstallRoot 'launcher.log'
$script:PatchNeedle = 'this.discovery.findWLDevices([a.Project2077])'
$script:SourceScript = $PSCommandPath

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Write-LauncherLog {
    param([Parameter(Mandatory)] [string]$Message)

    New-Item -ItemType Directory -Force -Path $script:InstallRoot | Out-Null
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK'), $Message
    [System.IO.File]::AppendAllText(
        $script:LogPath,
        $line + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Show-LauncherMessage {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$Title = 'Codex (No Micro)'
    )

    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        [System.Windows.MessageBox]::Show($Message, $Title) | Out-Null
    }
    catch {
        Write-Host "$Title`: $Message"
    }
}

function Get-CurrentCodexPackage {
    $package = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $package) {
        throw 'Microsoft Store의 OpenAI.Codex 패키지를 찾지 못했습니다.'
    }

    $appDirectory = Join-Path $package.InstallLocation 'app'
    $executable = Join-Path $appDirectory 'ChatGPT.exe'
    $asar = Join-Path $appDirectory 'resources\app.asar'

    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Codex 실행 파일을 찾지 못했습니다: $executable"
    }
    if (-not (Test-Path -LiteralPath $asar -PathType Leaf)) {
        throw "Codex app.asar를 찾지 못했습니다: $asar"
    }

    [pscustomobject]@{
        Package = $package
        Version = $package.Version.ToString()
        AppDirectory = $appDirectory
        Executable = $executable
        Asar = $asar
    }
}

function Add-BytePatchType {
    if ('CodexNoMicroBytePatch' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;

public static class CodexNoMicroBytePatch
{
    public static long[] FindAll(string path, byte[] pattern)
    {
        if (pattern == null || pattern.Length == 0)
            throw new ArgumentException("Pattern must not be empty.", "pattern");

        int[] prefix = BuildPrefix(pattern);
        var offsets = new List<long>();
        byte[] buffer = new byte[1024 * 1024];
        long absolute = 0;
        int matched = 0;

        using (var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            buffer.Length,
            FileOptions.SequentialScan))
        {
            int read;
            while ((read = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int index = 0; index < read; index++, absolute++)
                {
                    byte current = buffer[index];
                    while (matched > 0 && current != pattern[matched])
                        matched = prefix[matched - 1];

                    if (current == pattern[matched])
                        matched++;

                    if (matched == pattern.Length)
                    {
                        offsets.Add(absolute - pattern.Length + 1);
                        matched = prefix[matched - 1];
                    }
                }
            }
        }

        return offsets.ToArray();
    }

    public static void ReplaceAt(string path, long offset, byte[] expected, byte[] replacement)
    {
        if (expected.Length != replacement.Length)
            throw new ArgumentException("Replacement must preserve byte length.");

        using (var stream = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
        {
            stream.Position = offset;
            byte[] current = new byte[expected.Length];
            int total = 0;
            while (total < current.Length)
            {
                int read = stream.Read(current, total, current.Length - total);
                if (read == 0)
                    throw new EndOfStreamException("Patch target ended unexpectedly.");
                total += read;
            }

            for (int index = 0; index < expected.Length; index++)
            {
                if (current[index] != expected[index])
                    throw new InvalidDataException("Patch target changed before replacement.");
            }

            stream.Position = offset;
            stream.Write(replacement, 0, replacement.Length);
            stream.Flush(true);
        }
    }

    private static int[] BuildPrefix(byte[] pattern)
    {
        int[] prefix = new int[pattern.Length];
        int length = 0;
        for (int index = 1; index < pattern.Length; index++)
        {
            while (length > 0 && pattern[index] != pattern[length])
                length = prefix[length - 1];
            if (pattern[index] == pattern[length])
                length++;
            prefix[index] = length;
        }
        return prefix;
    }
}
'@
}

function Test-PatchManifest {
    param(
        [Parameter(Mandatory)] $CodexInfo,
        [Parameter(Mandatory)] [string]$VersionRoot
    )

    $manifestPath = Join-Path $VersionRoot 'patch-manifest.json'
    $patchedExecutable = Join-Path $VersionRoot 'app\ChatGPT.exe'
    $patchedAsar = Join-Path $VersionRoot 'app\resources\app.asar'

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $patchedExecutable -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $patchedAsar -PathType Leaf)) { return $false }

    try {
        $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
        return (
            $manifest.version -eq $CodexInfo.Version -and
            $manifest.packageFullName -eq $CodexInfo.Package.PackageFullName -and
            $manifest.patchTarget -eq $script:PatchNeedle -and
            $manifest.patchTargetCountBefore -eq 1 -and
            $manifest.patchTargetCountAfter -eq 0
        )
    }
    catch {
        return $false
    }
}

function New-PatchedRuntime {
    param([Parameter(Mandatory)] $CodexInfo)

    Add-BytePatchType
    New-Item -ItemType Directory -Force -Path $script:RuntimesRoot | Out-Null

    $versionRoot = Join-Path $script:RuntimesRoot $CodexInfo.Version
    if (Test-PatchManifest -CodexInfo $CodexInfo -VersionRoot $versionRoot) {
        return $versionRoot
    }

    $needleBytes = [System.Text.Encoding]::ASCII.GetBytes($script:PatchNeedle)
    $replacementText = '[]' + (' ' * ($script:PatchNeedle.Length - 2))
    $replacementBytes = [System.Text.Encoding]::ASCII.GetBytes($replacementText)
    $sourceOffsets = [CodexNoMicroBytePatch]::FindAll($CodexInfo.Asar, $needleBytes)

    if ($sourceOffsets.Count -ne 1) {
        throw "안전 검증 실패: 현재 Codex app.asar의 패치 대상이 1개가 아니라 $($sourceOffsets.Count)개입니다. 앱 구조가 변경됐을 수 있으므로 수정하지 않습니다."
    }

    $stagingRoot = Join-Path $script:RuntimesRoot ('.staging-{0}-{1}' -f $CodexInfo.Version, [guid]::NewGuid().ToString('N'))
    $stagingApp = Join-Path $stagingRoot 'app'
    New-Item -ItemType Directory -Force -Path $stagingApp | Out-Null

    try {
        Write-LauncherLog "Preparing runtime version=$($CodexInfo.Version) source=$($CodexInfo.Package.PackageFullName)"
        $robocopy = Join-Path $env:SystemRoot 'System32\robocopy.exe'
        & $robocopy $CodexInfo.AppDirectory $stagingApp /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        $copyExitCode = $LASTEXITCODE
        if ($copyExitCode -ge 8) {
            throw "Codex 런타임 복사에 실패했습니다. Robocopy 종료 코드: $copyExitCode"
        }

        $stagingAsar = Join-Path $stagingApp 'resources\app.asar'
        $backupAsar = Join-Path $stagingApp 'resources\app.asar.original'
        Copy-Item -LiteralPath $stagingAsar -Destination $backupAsar -Force

        $stagingOffsets = [CodexNoMicroBytePatch]::FindAll($stagingAsar, $needleBytes)
        if ($stagingOffsets.Count -ne 1) {
            throw "복사본 안전 검증 실패: 패치 대상 수가 $($stagingOffsets.Count)개입니다."
        }

        [CodexNoMicroBytePatch]::ReplaceAt(
            $stagingAsar,
            $stagingOffsets[0],
            $needleBytes,
            $replacementBytes
        )

        $remainingOffsets = [CodexNoMicroBytePatch]::FindAll($stagingAsar, $needleBytes)
        if ($remainingOffsets.Count -ne 0) {
            throw '패치 후 검증 실패: 원래 탐색 코드가 남아 있습니다.'
        }

        $originalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupAsar).Hash
        $patchedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $stagingAsar).Hash
        $manifest = [ordered]@{
            schemaVersion = 1
            createdAt = (Get-Date).ToString('o')
            version = $CodexInfo.Version
            packageFullName = $CodexInfo.Package.PackageFullName
            sourceInstallLocation = $CodexInfo.Package.InstallLocation
            patchTarget = $script:PatchNeedle
            patchOffset = $stagingOffsets[0]
            patchTargetCountBefore = 1
            patchTargetCountAfter = 0
            originalAsarSha256 = $originalHash
            patchedAsarSha256 = $patchedHash
            originalAsarLength = (Get-Item -LiteralPath $backupAsar).Length
            patchedAsarLength = (Get-Item -LiteralPath $stagingAsar).Length
            codexMicroDiscoveryDisabled = $true
        }
        Write-Utf8NoBom -Path (Join-Path $stagingRoot 'patch-manifest.json') -Content ($manifest | ConvertTo-Json -Depth 5)

        if (Test-Path -LiteralPath $versionRoot) {
            $oldRoot = "$versionRoot.old-$([guid]::NewGuid().ToString('N'))"
            Move-Item -LiteralPath $versionRoot -Destination $oldRoot
            Move-Item -LiteralPath $stagingRoot -Destination $versionRoot
            Remove-Item -LiteralPath $oldRoot -Recurse -Force
        }
        else {
            Move-Item -LiteralPath $stagingRoot -Destination $versionRoot
        }

        $sourceIcon = Join-Path $versionRoot 'app\resources\icon-chatgpt.ico'
        if (Test-Path -LiteralPath $sourceIcon) {
            Copy-Item -LiteralPath $sourceIcon -Destination (Join-Path $script:InstallRoot 'Codex-No-Micro.ico') -Force
        }

        Write-LauncherLog "Prepared runtime version=$($CodexInfo.Version) patchedSha256=$patchedHash"
        return $versionRoot
    }
    catch {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Install-LauncherShortcut {
    $shortcutShell = New-Object -ComObject WScript.Shell
    $shortcut = $shortcutShell.CreateShortcut($script:ShortcutPath)
    $shortcut.TargetPath = (Join-Path $PSHOME 'powershell.exe')
    if (-not (Test-Path -LiteralPath $shortcut.TargetPath)) {
        $shortcut.TargetPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    }
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Action Launch' -f $script:InstalledScript
    $shortcut.WorkingDirectory = $script:InstallRoot
    $shortcut.Description = 'Launch the current Codex app with Codex Micro HID discovery disabled.'
    $iconPath = Join-Path $script:InstallRoot 'Codex-No-Micro.ico'
    if (Test-Path -LiteralPath $iconPath) {
        $shortcut.IconLocation = "$iconPath,0"
    }
    $shortcut.Save()
}

function Install-Launcher {
    New-Item -ItemType Directory -Force -Path $script:InstallRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $script:RuntimesRoot | Out-Null

    $currentScript = $script:SourceScript
    if ([string]::IsNullOrWhiteSpace($currentScript)) {
        throw '현재 런처 스크립트 경로를 확인하지 못했습니다.'
    }

    $resolvedCurrent = (Resolve-Path -LiteralPath $currentScript).Path
    $resolvedInstalled = [System.IO.Path]::GetFullPath($script:InstalledScript)
    if (-not [string]::Equals($resolvedCurrent, $resolvedInstalled, [System.StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $resolvedCurrent -Destination $script:InstalledScript -Force
    }

    $codexInfo = Get-CurrentCodexPackage
    $versionRoot = New-PatchedRuntime -CodexInfo $codexInfo
    Install-LauncherShortcut
    Write-LauncherLog "Installed launcher shortcut=$script:ShortcutPath runtime=$versionRoot"

    [pscustomobject]@{
        Installed = $true
        Version = $codexInfo.Version
        InstallRoot = $script:InstallRoot
        RuntimeRoot = $versionRoot
        Shortcut = $script:ShortcutPath
    }
}

function Start-PatchedCodex {
    $codexInfo = Get-CurrentCodexPackage
    $versionRoot = New-PatchedRuntime -CodexInfo $codexInfo
    $patchedExecutable = Join-Path $versionRoot 'app\ChatGPT.exe'

    $normalProcess = Get-CimInstance Win32_Process -Filter "Name = 'ChatGPT.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -and
            [string]::Equals($_.ExecutablePath, $codexInfo.Executable, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        Select-Object -First 1

    if ($null -ne $normalProcess) {
        throw '현재 Microsoft Store Codex가 실행 중입니다. Codex를 완전히 종료한 다음 바탕화면의 Codex (No Micro)를 다시 실행하세요.'
    }

    Write-LauncherLog "Launching patched runtime version=$($codexInfo.Version) executable=$patchedExecutable"
    Start-Process -FilePath $patchedExecutable -WorkingDirectory (Split-Path -Parent $patchedExecutable) | Out-Null
}

function Get-LauncherStatus {
    $codexInfo = Get-CurrentCodexPackage
    $versionRoot = Join-Path $script:RuntimesRoot $codexInfo.Version
    [pscustomobject]@{
        InstalledVersion = $codexInfo.Version
        PackageFullName = $codexInfo.Package.PackageFullName
        LauncherInstalled = (Test-Path -LiteralPath $script:InstalledScript -PathType Leaf)
        ShortcutInstalled = (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)
        CurrentRuntimeReady = (Test-PatchManifest -CodexInfo $codexInfo -VersionRoot $versionRoot)
        CurrentRuntimeRoot = $versionRoot
        StoreExecutable = $codexInfo.Executable
        PatchedExecutable = (Join-Path $versionRoot 'app\ChatGPT.exe')
    }
}

function Uninstall-Launcher {
    if (Test-Path -LiteralPath $script:ShortcutPath) {
        Remove-Item -LiteralPath $script:ShortcutPath -Force
    }

    $expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'OpenAI\CodexNoMicro'))
    $actualRoot = [System.IO.Path]::GetFullPath($script:InstallRoot)
    if (-not [string]::Equals($expectedRoot, $actualRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "제거 대상 경로 검증에 실패했습니다: $actualRoot"
    }

    if (Test-Path -LiteralPath $actualRoot) {
        Remove-Item -LiteralPath $actualRoot -Recurse -Force
    }
}

$mutex = [System.Threading.Mutex]::new($false, 'Local\OpenAI.CodexNoMicroLauncher')
$lockTaken = $false
try {
    $lockTaken = $mutex.WaitOne(0)
    if (-not $lockTaken) {
        throw 'Codex (No Micro) 런처가 이미 준비 또는 실행 중입니다. 잠시 후 다시 시도하세요.'
    }

    switch ($Action) {
        'Install' {
            Install-Launcher
            break
        }
        'Prepare' {
            $codexInfo = Get-CurrentCodexPackage
            $versionRoot = New-PatchedRuntime -CodexInfo $codexInfo
            [pscustomobject]@{ Prepared = $true; Version = $codexInfo.Version; RuntimeRoot = $versionRoot }
            break
        }
        'Launch' {
            Start-PatchedCodex
            break
        }
        'Status' {
            Get-LauncherStatus
            break
        }
        'Uninstall' {
            Uninstall-Launcher
            [pscustomobject]@{ Uninstalled = $true; RemovedRoot = $script:InstallRoot; RemovedShortcut = $script:ShortcutPath }
            break
        }
    }
}
catch {
    Write-LauncherLog "ERROR action=$Action message=$($_.Exception.Message)"
    if ($Action -eq 'Launch') {
        Show-LauncherMessage -Message $_.Exception.Message
    }
    throw
}
finally {
    if ($lockTaken) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
