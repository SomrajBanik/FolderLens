param(
    [Parameter(Position=0)]
    [string]$FolderPath
)

try {
    if (-not ('FolderLensFolderPicker' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport]
[Guid("D57C7288-D4AD-4768-BE02-9D969532D960")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFolderLensFileOpenDialog : IFolderLensFileDialog
{
    [PreserveSig] int GetResults(out IntPtr items);
    [PreserveSig] int GetSelectedItems(out IntPtr items);
}

[ComImport]
[Guid("42F85136-DB7E-439C-85F1-E4075D135FC8")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFolderLensFileDialog
{
    [PreserveSig] int Show(IntPtr parent);
    [PreserveSig] int SetFileTypes(uint count, IntPtr filters);
    [PreserveSig] int SetFileTypeIndex(uint index);
    [PreserveSig] int GetFileTypeIndex(out uint index);
    [PreserveSig] int Advise(IntPtr events, out uint cookie);
    [PreserveSig] int Unadvise(uint cookie);
    [PreserveSig] int SetOptions(uint options);
    [PreserveSig] int GetOptions(out uint options);
    [PreserveSig] int SetDefaultFolder(IFolderLensShellItem folder);
    [PreserveSig] int SetFolder(IFolderLensShellItem folder);
    [PreserveSig] int GetFolder(out IFolderLensShellItem folder);
    [PreserveSig] int GetCurrentSelection(out IFolderLensShellItem item);
    [PreserveSig] int SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
    [PreserveSig] int GetFileName(out IntPtr name);
    [PreserveSig] int SetTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
    [PreserveSig] int SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
    [PreserveSig] int SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
    [PreserveSig] int GetResult(out IFolderLensShellItem item);
    [PreserveSig] int AddPlace(IFolderLensShellItem item, uint alignment);
    [PreserveSig] int SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string extension);
    [PreserveSig] int Close(int result);
    [PreserveSig] int SetClientGuid(ref Guid guid);
    [PreserveSig] int ClearClientData();
    [PreserveSig] int SetFilter(IntPtr filter);
}

[ComImport]
[Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFolderLensShellItem
{
    [PreserveSig] int BindToHandler(IntPtr bindContext, ref Guid handler, ref Guid interfaceId, out IntPtr result);
    [PreserveSig] int GetParent(out IFolderLensShellItem parent);
    [PreserveSig] int GetDisplayName(uint nameType, out IntPtr name);
    [PreserveSig] int GetAttributes(uint mask, out uint attributes);
    [PreserveSig] int Compare(IFolderLensShellItem item, uint hint, out int order);
}

public static class FolderLensFolderPicker
{
    private const uint PickFolders = 0x00000020;
    private const uint ForceFileSystem = 0x00000040;
    private const uint PathMustExist = 0x00000800;
    private const int Cancelled = unchecked((int)0x800704C7);
    private const uint FileSystemPath = 0x80058000;
    private static readonly IntPtr PerMonitorAwareV2 = new IntPtr(-4);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
    private static extern int SHCreateItemFromParsingName(
        string path, IntPtr bindContext, ref Guid interfaceId, out IFolderLensShellItem item);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);

    [DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    public static string Choose(string initialFolder)
    {
        object instance = null;
        IFolderLensShellItem initialItem = null;
        IFolderLensShellItem selectedItem = null;
        IntPtr displayName = IntPtr.Zero;
        IntPtr previousDpiContext = IntPtr.Zero;
        try
        {
            previousDpiContext = SetThreadDpiAwarenessContext(PerMonitorAwareV2);
        }
        catch (EntryPointNotFoundException)
        {
            SetProcessDPIAware();
        }
        try
        {
            Type dialogType = Type.GetTypeFromCLSID(new Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7"), true);
            instance = Activator.CreateInstance(dialogType);
            IFolderLensFileOpenDialog dialog = (IFolderLensFileOpenDialog)instance;
            int result = dialog.SetTitle("Choose a folder for FolderLens");
            Marshal.ThrowExceptionForHR(result);
            result = dialog.SetOkButtonLabel("Open folder");
            Marshal.ThrowExceptionForHR(result);

            uint options;
            result = dialog.GetOptions(out options);
            Marshal.ThrowExceptionForHR(result);
            result = dialog.SetOptions(options | PickFolders | ForceFileSystem | PathMustExist);
            Marshal.ThrowExceptionForHR(result);

            if (!String.IsNullOrWhiteSpace(initialFolder))
            {
                Guid shellItemId = new Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE");
                result = SHCreateItemFromParsingName(initialFolder, IntPtr.Zero, ref shellItemId, out initialItem);
                if (result >= 0)
                {
                    result = dialog.SetFolder(initialItem);
                    Marshal.ThrowExceptionForHR(result);
                }
            }

            result = dialog.Show(IntPtr.Zero);
            if (result == Cancelled) return null;
            Marshal.ThrowExceptionForHR(result);

            result = dialog.GetResult(out selectedItem);
            Marshal.ThrowExceptionForHR(result);
            result = selectedItem.GetDisplayName(FileSystemPath, out displayName);
            Marshal.ThrowExceptionForHR(result);
            return Marshal.PtrToStringUni(displayName);
        }
        finally
        {
            if (displayName != IntPtr.Zero) Marshal.FreeCoTaskMem(displayName);
            if (selectedItem != null && Marshal.IsComObject(selectedItem)) Marshal.ReleaseComObject(selectedItem);
            if (initialItem != null && Marshal.IsComObject(initialItem)) Marshal.ReleaseComObject(initialItem);
            if (instance != null && Marshal.IsComObject(instance)) Marshal.ReleaseComObject(instance);
            if (previousDpiContext != IntPtr.Zero) SetThreadDpiAwarenessContext(previousDpiContext);
        }
    }
}
'@
    }

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        $FolderPath = [FolderLensFolderPicker]::Choose($PSScriptRoot)
        if ([string]::IsNullOrWhiteSpace($FolderPath)) { return }
    }

    $root = [IO.Path]::GetFullPath($FolderPath)
    $pathRoot = [IO.Path]::GetPathRoot($root)
    if (-not $root.Equals($pathRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $root = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Folder not found: $root"
    }

    if (-not ('ExplorerNameComparer' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.IO;
using System.Runtime.InteropServices;

public sealed class ExplorerNameComparer : IComparer
{
    [DllImport("Shlwapi.dll", CharSet = CharSet.Unicode)]
    private static extern int StrCmpLogicalW(string left, string right);

    public int Compare(object x, object y)
    {
        var left = x as string;
        var right = y as string;
        return StrCmpLogicalW(left ?? String.Empty, right ?? String.Empty);
    }
}
'@
    }

    if (-not ('FolderLensPathResolver' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class FolderLensPathResolver
{
    private const uint OpenExisting = 3;
    private const uint BackupSemantics = 0x02000000;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "CreateFileW")]
    private static extern SafeFileHandle CreateFile(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(
        SafeFileHandle file,
        StringBuilder path,
        uint pathLength,
        uint flags);

    public static string Resolve(string path)
    {
        using (SafeFileHandle handle = CreateFile(
            path, 0, 7, IntPtr.Zero, OpenExisting, BackupSemantics, IntPtr.Zero))
        {
            if (handle.IsInvalid)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not resolve the file system path.");
            }

            uint required = GetFinalPathNameByHandle(handle, null, 0, 0);
            if (required == 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not resolve the file system path.");
            }

            StringBuilder buffer = new StringBuilder(checked((int)required + 1));
            uint written = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0);
            if (written == 0 || written >= buffer.Capacity)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not resolve the complete file system path.");
            }

            string resolved = buffer.ToString();
            if (resolved.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase))
            {
                return @"\\" + resolved.Substring(8);
            }
            if (resolved.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase))
            {
                return resolved.Substring(4);
            }
            return resolved;
        }
    }
}
'@
    }

    $rootFinalPath = [FolderLensPathResolver]::Resolve($root)
    $rootFinalPathRoot = [IO.Path]::GetPathRoot($rootFinalPath)
    if (-not $rootFinalPath.Equals($rootFinalPathRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $rootFinalPath = $rootFinalPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }

    $port = 8765
    $url = "http://localhost:$port/"
    $edgePath = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $edgePath) {
        $edgeAppPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" -ErrorAction SilentlyContinue
        if ($edgeAppPath -and (Test-Path -LiteralPath $edgeAppPath.'(default)')) {
            $edgePath = $edgeAppPath.'(default)'
        }
    }

    function Test-PathWithinRoot {
        param([Parameter(Mandatory=$true)][string]$Path)
        $fullPath = [IO.Path]::GetFullPath($Path)
        if ($root.EndsWith([IO.Path]::DirectorySeparatorChar.ToString()) -or $root.EndsWith([IO.Path]::AltDirectorySeparatorChar.ToString())) {
            if (-not $fullPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        } elseif (
            -not $fullPath.Equals($root, [StringComparison]::OrdinalIgnoreCase) -and
            -not $fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
            -not $fullPath.StartsWith($root + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        ) {
            return $false
        }

        $resolvedPath = [FolderLensPathResolver]::Resolve($fullPath)
        if ($rootFinalPath.EndsWith([IO.Path]::DirectorySeparatorChar.ToString()) -or $rootFinalPath.EndsWith([IO.Path]::AltDirectorySeparatorChar.ToString())) {
            return $resolvedPath.StartsWith($rootFinalPath, [StringComparison]::OrdinalIgnoreCase)
        }
        return $resolvedPath.Equals($rootFinalPath, [StringComparison]::OrdinalIgnoreCase) -or
            $resolvedPath.StartsWith($rootFinalPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            $resolvedPath.StartsWith($rootFinalPath + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    }

    function Test-IsGitMetadataPath {
        param([Parameter(Mandatory=$true)][string]$Path)
        $relativePath = $Path.Substring([Math]::Min($Path.Length, $root.Length)).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        return $relativePath -match '(^|[\\/])\.git([\\/]|$)'
    }

    function Test-ScannedEntryWithinRoot {
        param([Parameter(Mandatory=$true)][IO.FileSystemInfo]$Entry)
        $fullPath = [IO.Path]::GetFullPath($Entry.FullName)
        $insideRoot = if (
            $root.EndsWith([IO.Path]::DirectorySeparatorChar.ToString()) -or
            $root.EndsWith([IO.Path]::AltDirectorySeparatorChar.ToString())
        ) {
            $fullPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)
        } else {
            $fullPath.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
            $fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            $fullPath.StartsWith($root + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        }
        if (-not $insideRoot) {
            return $false
        }
        if (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return Test-PathWithinRoot -Path $fullPath
        }
        return $true
    }

    function Get-LibraryCatalog {
        $sections = [ordered]@{}
        $targets = @{}
        $sections[$root] = [System.Collections.Generic.List[object]]::new()
        $targets[$root] = $root
        $pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
        $visitedDirectories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $pendingDirectories.Push($root)
        [void]$visitedDirectories.Add($rootFinalPath)
        $directoryCount = 0
        $fileCount = 0
        $spinner = @('|', '/', '-', '\')
        $scanStarted = Get-Date
        Write-Host "Scanning folder contents..." -ForegroundColor Cyan

        while ($pendingDirectories.Count -gt 0) {
            $currentDirectory = $pendingDirectories.Pop()
            $directoryInfo = [IO.DirectoryInfo]::new($currentDirectory)
            foreach ($entry in $directoryInfo.EnumerateFileSystemInfos()) {
                if (Test-IsGitMetadataPath -Path $entry.FullName) { continue }
                if (-not (Test-ScannedEntryWithinRoot -Entry $entry)) { continue }
                $isDirectory = ($entry.Attributes -band [IO.FileAttributes]::Directory) -ne 0
                if ($isDirectory) {
                    $sectionName = $entry.FullName
                    if (-not $sections.Contains($sectionName)) {
                        $sections[$sectionName] = [System.Collections.Generic.List[object]]::new()
                        $targets[$sectionName] = $entry.FullName
                    }
                    $resolvedDirectory = if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        [FolderLensPathResolver]::Resolve($entry.FullName)
                    } else {
                        [IO.Path]::GetFullPath($entry.FullName)
                    }
                    if ($visitedDirectories.Add($resolvedDirectory)) {
                        $pendingDirectories.Push($entry.FullName)
                    }
                    $directoryCount++
                } else {
                    $file = [IO.FileInfo]$entry
                    $sectionName = $file.DirectoryName
                    if (-not $sections.Contains($sectionName)) {
                        $sections[$sectionName] = [System.Collections.Generic.List[object]]::new()
                        $targets[$sectionName] = $file.DirectoryName
                    }
                    $extension = $file.Extension.TrimStart('.').ToUpperInvariant()
                    if ([string]::IsNullOrWhiteSpace($extension)) { $extension = "FILE" }
                    $previewKind = switch -Regex ($file.Extension.ToLowerInvariant()) {
                        '^\.(png|jpe?g|gif|bmp|webp|avif|svg|ico)$' { 'image'; break }
                        '^\.(mp4|webm|ogv|mov|m4v)$' { 'video'; break }
                        '^\.(mp3|wav|ogg|m4a|flac|aac)$' { 'audio'; break }
                        '^\.(pdf)$' { 'pdf'; break }
                        '^\.(txt|md|csv|log|json|xml|html?|css|js|ps1|py|bat|cmd|ini|yml|yaml|toml|rtf)$' { 'text'; break }
                        default { 'unsupported' }
                    }
                    $sections[$sectionName].Add([PSCustomObject]@{
                        name = $file.Name
                        path = $file.FullName
                        ext = $extension
                        size = [int64]$file.Length
                        added = $file.LastWriteTimeUtc.ToString('o')
                        image = $file.Extension -match '^\.(png|jpe?g|gif|bmp|webp|avif)$'
                        previewKind = $previewKind
                    })
                    $fileCount++
                }
                $scannedCount = $fileCount + $directoryCount
                if ($scannedCount -eq 1 -or ($scannedCount % 250) -eq 0) {
                    $frame = [int](($scannedCount / 250) % $spinner.Length)
                    $elapsed = (Get-Date) - $scanStarted
                    Write-Host ("`r{0} Scanned {1:N0} files and {2:N0} folders ({3:mm\:ss})" -f $spinner[$frame], $fileCount, $directoryCount, $elapsed) -NoNewline -ForegroundColor Cyan
                }
            }
        }

        $sortedSections = [ordered]@{}
        $sectionNames = [string[]]@($sections.Keys)
        [Array]::Sort($sectionNames, (New-Object ExplorerNameComparer))
        foreach ($sectionName in $sectionNames) {
            $sortedSections[$sectionName] = $sections[$sectionName].ToArray()
        }
        Write-Host ("`rScan complete: {0:N0} files in {1:N0} folders ({2:mm\:ss})." -f $fileCount, $directoryCount, ((Get-Date) - $scanStarted)) -ForegroundColor Green
        return [PSCustomObject]@{ Sections = $sortedSections; Targets = $targets; Count = $fileCount }
    }

    function Get-QueryValue {
        param(
            [Parameter(Mandatory=$true)][string]$Query,
            [Parameter(Mandatory=$true)][string]$Name
        )
        foreach ($part in $Query.TrimStart('?').Split('&')) {
            $pair = [regex]::Split($part, '=', 2)
            if ($pair.Count -eq 2 -and $pair[0] -eq $Name) {
                return [Uri]::UnescapeDataString($pair[1].Replace('+', ' '))
            }
        }
        return $null
    }

    function Get-RegisteredOpenCommand {
        param([Parameter(Mandatory=$true)][string]$ProgId)
        $keyPath = "Registry::HKEY_CLASSES_ROOT\$ProgId\shell\open\command"
        $key = Get-Item -LiteralPath $keyPath -ErrorAction SilentlyContinue
        if (-not $key) { return $null }
        $command = [string]$key.GetValue('')
        if ([string]::IsNullOrWhiteSpace($command)) { return $null }

        $expanded = [Environment]::ExpandEnvironmentVariables($command)
        $match = [regex]::Match($expanded, '^\s*"([^"]+)"|^\s*([^\s]+)')
        if (-not $match.Success) { return $null }
        $executable = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
            $commandInfo = Get-Command -Name $executable -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($commandInfo) { $executable = $commandInfo.Source } else { return $null }
        }

        [PSCustomObject]@{
            Executable = $executable
            Arguments = $expanded.Substring($match.Length).Trim()
        }
    }

    function Get-ApplicationFileArguments {
        param(
            [Parameter(Mandatory=$true)][string]$CommandArguments,
            [Parameter(Mandatory=$true)][string]$FilePath
        )

        $fileArgument = $FilePath
        if ($CommandArguments -match '(?i)(?:^|\s)--single-argument(?:\s|$)') {
            $fileArgument = ([Uri]$FilePath).AbsoluteUri
        }
        $quotedFileArgument = if ($fileArgument -eq $FilePath) {
            '"' + $fileArgument + '"'
        } else {
            $fileArgument
        }

        if ($CommandArguments -match '"%[1lL]"') {
            return [regex]::Replace(
                $CommandArguments,
                '"%[1lL]"',
                [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $quotedFileArgument }
            )
        }
        if ($CommandArguments -match '%[1lL]') {
            return [regex]::Replace(
                $CommandArguments,
                '%[1lL]',
                [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $quotedFileArgument }
            )
        }
        return ($CommandArguments + ' ' + $quotedFileArgument).Trim()
    }

    $script:appCatalogById = @{}
    function Get-InstalledAppsForExtension {
        param([Parameter(Mandatory=$true)][string]$Extension)

        $extension = $Extension.ToLowerInvariant()
        $progidSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $exeNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $extensionKey = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$extension" -ErrorAction SilentlyContinue
        if ($extensionKey) {
            $defaultProgId = [string]$extensionKey.GetValue('')
            if ($defaultProgId) { [void]$progidSet.Add($defaultProgId) }
            $openWithProgIds = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$extension\OpenWithProgids" -ErrorAction SilentlyContinue
            if ($openWithProgIds) {
                foreach ($name in $openWithProgIds.GetValueNames()) {
                    if ($name) { [void]$progidSet.Add($name) }
                }
            }
            $openWithList = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$extension\OpenWithList" -ErrorAction SilentlyContinue
            if ($openWithList) {
                foreach ($entry in $openWithList.GetSubKeyNames()) {
                    if ($entry) { [void]$exeNames.Add($entry) }
                }
            }
        }

        $userOpenWith = Get-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\OpenWithProgids" -ErrorAction SilentlyContinue
        if ($userOpenWith) {
            foreach ($name in $userOpenWith.GetValueNames()) {
                if ($name) { [void]$progidSet.Add($name) }
            }
        }
        $userList = Get-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\OpenWithList" -ErrorAction SilentlyContinue
        if ($userList) {
            foreach ($name in $userList.GetValueNames()) {
                $exeName = [string]$userList.GetValue($name)
                if ($exeName) { [void]$exeNames.Add($exeName) }
            }
        }
        $userChoice = Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\UserChoice" -ErrorAction SilentlyContinue
        if ($userChoice -and $userChoice.ProgId) {
            [void]$progidSet.Add([string]$userChoice.ProgId)
        }

        $apps = @()
        foreach ($progId in $progidSet) {
            $command = Get-RegisteredOpenCommand -ProgId $progId
            if (-not $command) { continue }
            $appKey = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$progId" -ErrorAction SilentlyContinue
            $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($command.Executable)
            $name = $versionInfo.ProductName
            if (-not $name) { $name = $versionInfo.FileDescription }
            $applicationKey = Get-Item -LiteralPath ("Registry::HKEY_CLASSES_ROOT\Applications\" + (Split-Path -Leaf $command.Executable)) -ErrorAction SilentlyContinue
            if ((-not $name -or $name.StartsWith('@')) -and $applicationKey) { $name = [string]$applicationKey.GetValue('FriendlyAppName') }
            if (-not $name -and $appKey) { $name = [string]$appKey.GetValue('FriendlyTypeName') }
            if (-not $name -or $name.StartsWith('@')) {
                $name = [IO.Path]::GetFileNameWithoutExtension($command.Executable)
            }
            $apps += [PSCustomObject]@{ Name = $name; ProgId = $progId; Executable = $command.Executable; Arguments = $command.Arguments }
        }
        foreach ($exeName in $exeNames) {
            $appKey = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\Applications\$exeName" -ErrorAction SilentlyContinue
            if (-not $appKey) { continue }
            $command = Get-RegisteredOpenCommand -ProgId "Applications\$exeName"
            if (-not $command) { continue }
            $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($command.Executable)
            $name = $versionInfo.ProductName
            if (-not $name) { $name = $versionInfo.FileDescription }
            if (-not $name) { $name = [string]$appKey.GetValue('FriendlyAppName') }
            if (-not $name -or $name.StartsWith('@')) { $name = $exeName }
            $apps += [PSCustomObject]@{ Name = $name; ProgId = "Applications\$exeName"; Executable = $command.Executable; Arguments = $command.Arguments }
        }

        $result = @([PSCustomObject]@{ id = 'default'; name = 'Windows default app' })
        $uniqueApps = @{}
        foreach ($app in $apps) {
            $key = $app.Executable.ToLowerInvariant()
            if (-not $uniqueApps.ContainsKey($key) -or
                ($uniqueApps[$key].Name -match '\.exe$' -and $app.Name -notmatch '\.exe$')) {
                $uniqueApps[$key] = $app
            }
        }

        foreach ($registrationPath in @(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\RegisteredApplications',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\RegisteredApplications'
        )) {
            $registrations = Get-Item -LiteralPath $registrationPath -ErrorAction SilentlyContinue
            if (-not $registrations) { continue }
            foreach ($applicationName in $registrations.GetValueNames()) {
                $capabilitiesPath = [string]$registrations.GetValue($applicationName)
                if ([string]::IsNullOrWhiteSpace($capabilitiesPath)) { continue }
                $associations = Get-Item -LiteralPath "Registry::HKEY_LOCAL_MACHINE\$capabilitiesPath\FileAssociations" -ErrorAction SilentlyContinue
                if (-not $associations) {
                    $associations = Get-Item -LiteralPath "Registry::HKEY_CURRENT_USER\$capabilitiesPath\FileAssociations" -ErrorAction SilentlyContinue
                }
                if (-not $associations) { continue }
                $registeredProgId = [string]$associations.GetValue($extension)
                if (-not $registeredProgId) { continue }
                $command = Get-RegisteredOpenCommand -ProgId $registeredProgId
                if (-not $command) { continue }
                $executableKey = $command.Executable.ToLowerInvariant()
                if (-not $uniqueApps.ContainsKey($executableKey)) {
                    $uniqueApps[$executableKey] = [PSCustomObject]@{
                        Name = $applicationName
                        ProgId = $registeredProgId
                        Executable = $command.Executable
                        Arguments = $command.Arguments
                    }
                }
            }
        }

        foreach ($app in ($uniqueApps.Values | Sort-Object Name)) {
            $id = [Guid]::NewGuid().ToString('N')
            $script:appCatalogById[$id] = [PSCustomObject]@{
                Name = $app.Name
                ProgId = $app.ProgId
                Executable = $app.Executable
                Arguments = $app.Arguments
                Extension = $extension
            }
            $result += [PSCustomObject]@{ id = $id; name = $app.Name }
        }
        return $result
    }

    function Get-ContentType {
        param([Parameter(Mandatory=$true)][string]$Extension)
        switch ($Extension.ToLowerInvariant()) {
            '.svg' { 'image/svg+xml'; break }
            '.ico' { 'image/x-icon'; break }
            '.jpg' { 'image/jpeg'; break }
            '.jpeg' { 'image/jpeg'; break }
            '.png' { 'image/png'; break }
            '.gif' { 'image/gif'; break }
            '.bmp' { 'image/bmp'; break }
            '.webp' { 'image/webp'; break }
            '.avif' { 'image/avif'; break }
            '.pdf' { 'application/pdf'; break }
            '.mp4' { 'video/mp4'; break }
            '.webm' { 'video/webm'; break }
            '.ogv' { 'video/ogg'; break }
            '.mov' { 'video/quicktime'; break }
            '.m4v' { 'video/mp4'; break }
            '.mp3' { 'audio/mpeg'; break }
            '.wav' { 'audio/wav'; break }
            '.ogg' { 'audio/ogg'; break }
            '.m4a' { 'audio/mp4'; break }
            '.flac' { 'audio/flac'; break }
            '.aac' { 'audio/aac'; break }
            '.txt' { 'text/plain; charset=utf-8'; break }
            '.md' { 'text/plain; charset=utf-8'; break }
            '.csv' { 'text/plain; charset=utf-8'; break }
            '.log' { 'text/plain; charset=utf-8'; break }
            '.json' { 'text/plain; charset=utf-8'; break }
            '.xml' { 'text/plain; charset=utf-8'; break }
            '.html' { 'text/plain; charset=utf-8'; break }
            '.htm' { 'text/plain; charset=utf-8'; break }
            '.css' { 'text/plain; charset=utf-8'; break }
            '.js' { 'text/plain; charset=utf-8'; break }
            '.ps1' { 'text/plain; charset=utf-8'; break }
            '.py' { 'text/plain; charset=utf-8'; break }
            '.bat' { 'text/plain; charset=utf-8'; break }
            '.cmd' { 'text/plain; charset=utf-8'; break }
            '.ini' { 'text/plain; charset=utf-8'; break }
            '.yml' { 'text/plain; charset=utf-8'; break }
            '.yaml' { 'text/plain; charset=utf-8'; break }
            '.toml' { 'text/plain; charset=utf-8'; break }
            '.rtf' { 'text/plain; charset=utf-8'; break }
            default { 'application/octet-stream' }
        }
    }

    function Write-JsonResponse {
        param(
            [Parameter(Mandatory=$true)]$Response,
            [Parameter(Mandatory=$true)]$Value,
            [int]$StatusCode = 200
        )
        $json = ConvertTo-Json -InputObject $Value -Depth 10 -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        $Response.StatusCode = $StatusCode
        $Response.ContentType = "application/json; charset=utf-8"
        $Response.ContentLength64 = $bytes.Length
        $Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $Response.Close()
    }

    $catalog = [PSCustomObject]@{
        Sections = [ordered]@{}
        Targets = @{}
        Count = 0
    }
    $catalog.Sections[$root] = @()
    $catalog.Targets[$root] = $root
    $catalogJson = @{ sections = $catalog.Sections; targets = $catalog.Targets; root = $root } | ConvertTo-Json -Depth 10 -Compress
    $catalogJson = $catalogJson -replace '</script>', '<\/script>'
    $safeTitle = [Net.WebUtility]::HtmlEncode((Split-Path -Leaf $root))

    $html = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#111315">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<title>FolderLens - $safeTitle</title>
<style>
  :root { color-scheme: dark; }
  :root[data-theme="light"] { color-scheme: light; }
  * { box-sizing: border-box; }
  body { position: relative; isolation: isolate; min-height: 100vh; margin: 0; padding: 18px 44px 36px; background: #111315; color: #f1f2f4; font-family: 'Segoe UI', system-ui, sans-serif; }
  body::before { content: ''; position: fixed; inset: 0; z-index: -1; pointer-events: none; background: radial-gradient(circle at 12% 8%, rgba(220,225,232,.14), transparent 31%), radial-gradient(circle at 82% 14%, rgba(129,147,168,.11), transparent 29%), linear-gradient(145deg, #111315, #1b1e22 58%, #121416); }
  :root[data-theme="light"] body { background: #eaf0f5; color: #24364b; }
  :root[data-theme="light"] body::before { background: radial-gradient(circle at 12% 8%, rgba(255,255,255,.95), transparent 31%), radial-gradient(circle at 82% 14%, rgba(157,201,233,.35), transparent 29%), linear-gradient(145deg, #eaf0f5, #dce9f3 58%, #edf3f8); }
  #loading-screen { position: fixed; inset: 0; z-index: 50; display: grid; place-items: center; padding: 24px; background: rgba(12,15,18,.58); backdrop-filter: blur(7px); }
  #loading-screen[hidden] { display: none; }
  :root[data-theme="light"] #loading-screen { background: rgba(226,237,246,.62); }
  .loading-card { display: flex; width: min(360px, 100%); align-items: center; gap: 16px; padding: 20px 22px; border: 1px solid rgba(255,255,255,.16); border-radius: 16px; background: rgba(35,39,45,.96); box-shadow: 0 20px 60px rgba(0,0,0,.28); }
  :root[data-theme="light"] .loading-card { border-color: rgba(104,140,174,.25); background: rgba(255,255,255,.97); }
  .loading-spinner { width: 30px; height: 30px; flex: 0 0 30px; border: 3px solid rgba(130,174,211,.2); border-top-color: #82b9e7; border-radius: 50%; animation: loading-spin .8s linear infinite; }
  @keyframes loading-spin { to { transform: rotate(360deg); } }
  .loading-title { margin-bottom: 4px; font-size: 13px; font-weight: 700; }
  .loading-detail { color: #aab5c0; font-size: 11px; line-height: 1.5; }
  :root[data-theme="light"] .loading-detail { color: #647d93; }
  .page-header { display: flex; justify-content: space-between; align-items: center; gap: 18px; margin: 0 auto 28px; padding: 14px 18px; max-width: 1440px; border: 1px solid rgba(255,255,255,.15); border-radius: 18px; background: rgba(37,40,46,.65); backdrop-filter: blur(20px); }
  :root[data-theme="light"] .page-header { background: rgba(255,255,255,.62); border-color: rgba(104,140,174,.25); }
  .brand { display: flex; align-items: center; gap: 12px; min-width: 180px; }
  .brand-mark { width: 38px; height: 38px; display: grid; place-items: center; }
  .brand-mark img { width: 34px; height: 34px; }
  .brand-copy h1 { margin: 0; font-size: 17px; }
  .brand-copy span { font-size: 11px; opacity: .7; overflow-wrap: anywhere; }
  .header-actions { display: flex; flex: 1 1 auto; align-items: center; justify-content: center; gap: 10px; flex-wrap: wrap; }
  .sort-control { display: inline-flex; align-items: center; gap: 7px; }
  .sort-control label { font-size: 11px; font-weight: 600; }
  .sort-control select, .header-button { display: inline-flex; align-items: center; justify-content: center; min-height: 34px; padding: 7px 10px; border: 1px solid rgba(239,242,247,.2); border-radius: 9px; color: inherit; font: inherit; font-size: 11px; background: rgba(255,255,255,.08); }
  .sort-control select { cursor: pointer; }
  .sort-control select option { background: #25282e; color: #f1f2f4; }
  .header-button { cursor: pointer; }
  .header-button:hover:not(:disabled) { background: rgba(255,255,255,.2); }
  .header-button:disabled { opacity: .6; cursor: wait; }
  .theme-control { display: inline-flex; align-items: center; gap: 8px; }
  .theme-label { font-size: 10px; font-weight: 650; opacity: .72; }
  .theme-switch { position: relative; width: 68px; height: 34px; flex: 0 0 68px; padding: 0; border: 1px solid rgba(239,242,247,.2); border-radius: 999px; color: inherit; background: #252a31; cursor: pointer; box-shadow: inset 0 2px 5px rgba(0,0,0,.24); }
  .theme-switch-track { position: absolute; inset: 0; display: flex; align-items: center; justify-content: space-between; padding: 0 8px; font-size: 13px; pointer-events: none; }
  .theme-switch-knob { position: absolute; left: 3px; top: 3px; width: 26px; height: 26px; border-radius: 50%; background: #dce6f0; box-shadow: 0 2px 7px rgba(0,0,0,.3); transition: transform .2s ease, background .2s ease; }
  .theme-switch[aria-checked="true"] .theme-switch-knob { transform: translateX(34px); background: #fff1c7; }
  :root[data-theme="light"] .theme-switch { border-color: rgba(104,140,174,.3); background: #dce9f3; }
  :root[data-theme="light"] .sort-control select, :root[data-theme="light"] .header-button { border-color: rgba(104,140,174,.3); background: rgba(255,255,255,.65); }
  #workspace { display: flex; align-items: stretch; gap: 0; max-width: 1600px; min-height: calc(100vh - 124px); margin: auto; }
  #main-content { flex: 1 1 auto; min-width: 0; padding: 0 16px 24px 0; }
  #tree-pane { position: sticky; top: 12px; display: flex; flex: 0 0 auto; flex-direction: column; width: min(360px, 38vw); height: calc(100vh - 124px); min-width: 240px; max-width: 55vw; align-self: flex-start; overflow: hidden; border: 1px solid rgba(255,255,255,.14); border-radius: 16px; background: rgba(31,34,39,.92); box-shadow: 0 18px 48px rgba(0,0,0,.24); animation: pane-in .16s ease-out; }
  :root[data-theme="light"] #tree-pane { border-color: rgba(104,140,174,.25); background: rgba(248,251,254,.94); box-shadow: 0 18px 48px rgba(74,105,139,.12); }
  @keyframes pane-in { from { opacity: .5; transform: translateX(8px); } to { opacity: 1; transform: translateX(0); } }
  #tree-resizer { flex: 0 0 12px; position: relative; cursor: col-resize; touch-action: none; }
  #tree-resizer::after { content: ''; position: absolute; top: 12px; bottom: 12px; left: 5px; width: 3px; border-radius: 3px; background: transparent; transition: background .15s, box-shadow .15s; }
  #tree-resizer:hover::after, #tree-resizer.dragging::after { background: #88b9e4; }
  #tree-resizer:focus-visible { outline: none; }
  #tree-resizer:focus-visible::after { background: #88b9e4; box-shadow: 0 0 0 3px rgba(112,162,207,.2); }
  .tree-header { display: flex; align-items: center; justify-content: space-between; min-height: 59px; padding: 0 12px 0 16px; border-bottom: 1px solid rgba(255,255,255,.1); }
  :root[data-theme="light"] .tree-header { border-bottom-color: rgba(104,140,174,.2); }
  .tree-heading-wrap { display: flex; min-width: 0; flex-direction: column; gap: 3px; }
  .tree-heading { font-size: 12px; font-weight: 700; letter-spacing: .2px; }
  .tree-root-name { max-width: 260px; overflow: hidden; color: #9da9b5; font-size: 10px; text-overflow: ellipsis; white-space: nowrap; }
  :root[data-theme="light"] .tree-root-name { color: #637b90; }
  .tree-header-actions { display: flex; align-items: center; gap: 4px; }
  .icon-button { display: inline-grid; place-items: center; width: 30px; height: 30px; border: 1px solid transparent; border-radius: 8px; color: inherit; background: transparent; font: inherit; font-size: 19px; line-height: 1; cursor: pointer; }
  .icon-button:hover { border-color: rgba(255,255,255,.14); background: rgba(255,255,255,.09); }
  .tree-toolbar { display: grid; gap: 9px; padding: 12px; border-bottom: 1px solid rgba(255,255,255,.08); }
  :root[data-theme="light"] .tree-toolbar { border-bottom-color: rgba(104,140,174,.16); }
  .tree-search-wrap { position: relative; }
  .tree-search-icon { position: absolute; top: 50%; left: 11px; width: 15px; height: 15px; color: #9aa8b7; pointer-events: none; transform: translateY(-50%); }
  .tree-search { width: 100%; height: 36px; padding: 0 11px 0 34px; border: 1px solid rgba(255,255,255,.13); border-radius: 9px; outline: none; color: inherit; background: rgba(0,0,0,.15); font: inherit; font-size: 11px; }
  .tree-search:focus { border-color: #78a9d4; box-shadow: 0 0 0 3px rgba(112,162,207,.16); }
  .tree-search::placeholder { color: #929eaa; }
  :root[data-theme="light"] .tree-search { border-color: rgba(104,140,174,.25); background: rgba(255,255,255,.75); }
  .tree-toolbar-actions { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
  .tree-count-summary { color: #929eaa; font-size: 10px; }
  :root[data-theme="light"] .tree-count-summary { color: #637b90; }
  .tree-action-group { display: flex; gap: 5px; }
  .tree-action { padding: 4px 7px; border: 1px solid transparent; border-radius: 6px; color: #b7c1cb; background: transparent; font: inherit; font-size: 10px; cursor: pointer; }
  .tree-action:hover { border-color: rgba(255,255,255,.12); background: rgba(255,255,255,.07); color: inherit; }
  :root[data-theme="light"] .tree-action { color: #526c82; }
  :root[data-theme="light"] .tree-action:hover { border-color: rgba(104,140,174,.22); background: rgba(94,157,210,.08); }
  #tree-content { flex: 1 1 auto; min-height: 0; overflow: auto; padding: 9px 8px 16px; scrollbar-color: rgba(145,165,183,.35) transparent; scrollbar-width: thin; }
  #tree-empty { padding: 22px 14px; color: #9da9b5; font-size: 11px; text-align: center; }
  #tree-empty[hidden] { display: none; }
  .tree-list { list-style: none; margin: 0; padding: 0; }
  .tree-children { list-style: none; margin: 2px 0 3px 12px; padding: 0 0 0 9px; border-left: 1px solid rgba(255,255,255,.1); }
  :root[data-theme="light"] .tree-children { border-left-color: rgba(104,140,174,.22); }
  .tree-row { display: flex; align-items: center; gap: 7px; min-width: 0; width: 100%; min-height: 30px; padding: 4px 7px; border: 0; border-radius: 7px; color: inherit; background: transparent; text-align: left; font: inherit; font-size: 11px; cursor: pointer; }
  summary.tree-row { list-style: none; }
  summary.tree-row::-webkit-details-marker { display: none; }
  details[open] > summary .tree-caret { transform: rotate(90deg); }
  .tree-row:hover { background: rgba(255,255,255,.065); }
  .tree-row:focus-visible, .icon-button:focus-visible, .tree-action:focus-visible { outline: 2px solid #78a9d4; outline-offset: 1px; }
  .tree-row.active { background: rgba(112,162,207,.2); color: #d5e9fb; box-shadow: inset 2px 0 #78a9d4; }
  :root[data-theme="light"] .tree-row.active { color: #245982; background: rgba(94,157,210,.15); }
  .tree-caret { display: inline-grid; flex: 0 0 13px; place-items: center; color: #91a5b7; font-size: 11px; transition: transform .12s ease; }
  .tree-folder-icon, .tree-file-icon { display: inline-grid; flex: 0 0 16px; place-items: center; }
  .tree-folder-icon svg, .tree-file-icon svg { width: 15px; height: 15px; display: block; }
  .tree-folder-icon { color: #e3b95f; }
  .tree-file-icon { color: #9aaabd; }
  .tree-label { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tree-count { margin-left: auto; padding: 1px 6px; border-radius: 10px; color: #9ca8b4; background: rgba(255,255,255,.06); font-size: 9px; font-variant-numeric: tabular-nums; }
  :root[data-theme="light"] .tree-count { color: #58748d; background: rgba(80,127,164,.08); }
  #workspace.tree-hidden #tree-pane, #workspace.tree-hidden #tree-resizer { display: none; }
  #workspace.tree-hidden #main-content { padding-right: 0; }
  .tree-toggle { display: inline-flex; align-items: center; gap: 7px; }
  .tree-toggle svg { width: 15px; height: 15px; }
  .series { margin-bottom: 38px; }
  .series h2 { font-size: 15px; color: #d2d5dc; text-transform: uppercase; letter-spacing: 1px; border-bottom: 1px solid rgba(232,235,240,.16); padding-bottom: 10px; margin-bottom: 16px; overflow-wrap: anywhere; }
  :root[data-theme="light"] .series h2 { color: #42688d; border-bottom-color: rgba(75,112,147,.2); }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 16px; }
  .card { position: relative; min-width: 0; overflow: hidden; display: flex; flex-direction: column; border: 1px solid rgba(238,241,246,.19); border-radius: 15px; background: linear-gradient(155deg, rgba(255,255,255,.12), rgba(255,255,255,.045) 48%, rgba(190,197,208,.07)); box-shadow: 0 14px 34px rgba(7,5,16,.22); backdrop-filter: blur(14px); transition: transform .2s, border-color .2s; }
  .card:hover { transform: translateY(-3px); border-color: rgba(232,236,243,.5); }
  .card.tree-file-highlight { border-color: #ffd166; outline: 2px solid rgba(255,209,102,.72); outline-offset: 2px; box-shadow: 0 0 0 4px rgba(255,209,102,.16), 0 0 30px rgba(255,196,87,.28); }
  .card.tree-file-highlight::after { content: ''; position: absolute; z-index: 2; inset: 0; border: 2px solid rgba(255,209,102,.86); border-radius: inherit; background: rgba(255,196,87,.3); box-shadow: inset 0 0 34px rgba(255,196,87,.28), 0 0 26px rgba(255,196,87,.32); opacity: 0; pointer-events: none; animation: tree-file-highlight 6s ease-in-out both; }
  @keyframes tree-file-highlight {
    0%, 8% { opacity: 0; }
    22%, 58% { opacity: 1; }
    100% { opacity: 0; }
  }
  :root[data-theme="light"] .card.tree-file-highlight { border-color: #3488c7; outline-color: rgba(52,136,199,.68); box-shadow: 0 0 0 4px rgba(52,136,199,.12), 0 0 28px rgba(52,136,199,.22); }
  :root[data-theme="light"] .card.tree-file-highlight::after { border-color: rgba(52,136,199,.9); background: rgba(52,136,199,.2); box-shadow: inset 0 0 32px rgba(52,136,199,.2), 0 0 24px rgba(52,136,199,.26); }
  @media (prefers-reduced-motion: reduce) { .card.tree-file-highlight::after { animation-duration: .01ms; } }
  :root[data-theme="light"] .card { background: linear-gradient(155deg, rgba(255,255,255,.85), rgba(255,255,255,.48) 48%, rgba(207,230,249,.42)); border-color: rgba(255,255,255,.88); box-shadow: 0 14px 34px rgba(74,105,139,.12); }
  .thumb { width: 100%; height: 142px; display: flex; align-items: center; justify-content: center; overflow: hidden; background: linear-gradient(160deg,#383c43,#22252a); }
  :root[data-theme="light"] .thumb { background: linear-gradient(160deg,#e5f1fb,#cbdff0); }
  .thumb img { width: 100%; height: 100%; object-fit: cover; }
  .placeholder { color: #aeb4bf; font-size: 24px; font-weight: 800; letter-spacing: 1px; overflow-wrap: anywhere; padding: 12px; text-align: center; }
  :root[data-theme="light"] .placeholder { color: #7792aa; }
  .info { min-width: 0; padding: 10px; display: flex; flex-direction: column; gap: 8px; }
  .title { font-size: 12px; font-weight: 650; line-height: 1.35; min-height: 32px; overflow-wrap: anywhere; }
  .metadata { display: flex; justify-content: space-between; gap: 5px; font-size: 10px; opacity: .72; }
  .card-actions { display: flex; gap: 7px; }
  .card-actions button, .modal-actions button { min-height: 32px; border: 1px solid rgba(255,255,255,.18); border-radius: 8px; background: rgba(255,255,255,.09); color: inherit; font: inherit; font-size: 11px; cursor: pointer; text-align: center; }
  .card-actions button { display: inline-flex; flex: 1 1 0; align-items: center; justify-content: center; }
  .card-actions button:hover, .modal-actions button:hover { background: rgba(255,255,255,.2); }
  :root[data-theme="light"] .card-actions button, :root[data-theme="light"] .modal-actions button { border-color: rgba(104,140,174,.3); background: rgba(255,255,255,.65); }
  .add-card { min-height: 300px; align-items: center; justify-content: center; gap: 12px; padding: 20px; border: 1px dashed rgba(234,158,101,.55); color: inherit; text-align: center; cursor: pointer; }
  .add-card.drag-over { background: rgba(234,158,101,.16); border-color: #ec806d; }
  .add-title { font-size: 13px; font-weight: 700; }
  .add-hint { font-size: 11px; opacity: .7; line-height: 1.5; }
  .add-input { display: none; }
  .empty { padding: 32px; opacity: .7; text-align: center; }
  #toast { position: fixed; bottom: 24px; right: 24px; max-width: min(440px, calc(100vw - 32px)); background: #292d33; border: 1px solid rgba(238,241,246,.24); color: #f1f2f4; padding: 12px 18px; border-radius: 12px; font-size: 13px; opacity: 0; transform: translateY(8px); transition: .2s; pointer-events: none; overflow-wrap: anywhere; }
  :root[data-theme="light"] #toast { background: #fff; border-color: rgba(125,159,190,.35); color: #263a50; }
  #toast.show { opacity: 1; transform: translateY(0); }
  dialog { width: min(460px, calc(100% - 28px)); padding: 0; border: 1px solid rgba(238,241,246,.22); border-radius: 18px; color: #f1f2f4; background: linear-gradient(155deg,#292d34,#202329); box-shadow: 0 22px 80px rgba(0,0,0,.5); }
  dialog::backdrop { background: rgba(0,0,0,.62); backdrop-filter: blur(4px); }
  :root[data-theme="light"] dialog { color: #263a50; background: linear-gradient(155deg,#fff,#edf4fa); border-color: rgba(104,140,174,.25); }
  .modal-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 20px 22px 15px; border-bottom: 1px solid rgba(255,255,255,.1); }
  :root[data-theme="light"] .modal-heading { border-bottom-color: rgba(104,140,174,.18); }
  .modal-heading h2 { margin: 0; font-size: 17px; overflow-wrap: anywhere; }
  .modal-subtitle { margin: 5px 0 0; color: #aeb8c4; font-size: 11px; line-height: 1.5; overflow-wrap: anywhere; }
  :root[data-theme="light"] .modal-subtitle { color: #62788b; }
  .modal-body { padding: 16px 22px 20px; }
  .app-list-label { display: block; margin-bottom: 9px; color: #aeb8c4; font-size: 10px; font-weight: 750; letter-spacing: .8px; text-transform: uppercase; }
  :root[data-theme="light"] .app-list-label { color: #62788b; }
  #app-list { display: grid; gap: 7px; max-height: min(48vh, 340px); overflow: auto; padding: 2px; }
  .app-option { display: flex; align-items: center; gap: 11px; width: 100%; padding: 10px 12px; border: 1px solid rgba(255,255,255,.09); border-radius: 11px; color: inherit; background: rgba(255,255,255,.035); text-align: left; font: inherit; cursor: pointer; transition: background .15s, border-color .15s, transform .15s; }
  .app-option:hover { transform: translateY(-1px); background: rgba(255,255,255,.08); }
  .app-option.selected { border-color: rgba(112,175,229,.62); background: rgba(91,155,211,.16); box-shadow: inset 0 0 0 1px rgba(112,175,229,.12); }
  :root[data-theme="light"] .app-option { border-color: rgba(104,140,174,.16); background: rgba(255,255,255,.55); }
  :root[data-theme="light"] .app-option.selected { border-color: #77acd4; background: #e4f2fc; }
  .app-icon { display: grid; place-items: center; width: 35px; height: 35px; flex: 0 0 35px; border-radius: 10px; color: #d9edff; background: linear-gradient(145deg,#415f7a,#283e52); font-size: 14px; font-weight: 750; text-transform: uppercase; }
  .app-option.selected .app-icon { background: linear-gradient(145deg,#4d91c7,#35678f); }
  :root[data-theme="light"] .app-icon { color: #2e5e82; background: linear-gradient(145deg,#d6eafa,#c1d9ee); }
  .app-option-copy { min-width: 0; flex: 1; }
  .app-option-name { display: block; overflow: hidden; font-size: 12px; font-weight: 650; text-overflow: ellipsis; white-space: nowrap; }
  .app-option-detail { display: block; margin-top: 3px; color: #9ba8b7; font-size: 10px; }
  :root[data-theme="light"] .app-option-detail { color: #72869a; }
  .app-radio { display: grid; place-items: center; width: 17px; height: 17px; flex: 0 0 17px; border: 1px solid rgba(255,255,255,.35); border-radius: 50%; }
  .app-option.selected .app-radio { border-color: #83bbe9; }
  .app-option.selected .app-radio::after { content: ''; width: 9px; height: 9px; border-radius: 50%; background: #83bbe9; }
  .modal-actions { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 14px 22px 18px; border-top: 1px solid rgba(255,255,255,.1); }
  :root[data-theme="light"] .modal-actions { border-top-color: rgba(104,140,174,.18); }
  .modal-actions button { flex: 0 0 auto; min-width: 94px; min-height: 36px; padding: 0 13px; font-weight: 600; }
  .modal-actions .primary-action { border-color: #6699c2; color: #fff; background: linear-gradient(145deg,#538cb8,#3a6b91); }
  .modal-actions .primary-action:hover { background: linear-gradient(145deg,#65a2d2,#477da5); }
  :root[data-theme="light"] .modal-actions .primary-action { color: #fff; background: linear-gradient(145deg,#4d8fbe,#35749e); }
  .modal-message { padding: 17px; border: 1px solid rgba(255,255,255,.1); border-radius: 11px; color: #b9c4d0; font-size: 12px; line-height: 1.55; }
  :root[data-theme="light"] .modal-message { border-color: rgba(104,140,174,.2); color: #526a7e; }
  .preview-dialog { width: min(92vw, 1440px); height: min(88vh, 900px); max-width: 1440px; max-height: 92vh; overflow: hidden; }
  .preview-dialog[open] { display: grid; grid-template-rows: auto minmax(0, 1fr) auto; }
  .preview-heading { align-items: center; padding: 12px 16px; }
  .preview-heading h2 { max-width: min(72vw, 760px); overflow: hidden; font-size: 13px; text-overflow: ellipsis; white-space: nowrap; }
  .preview-file-meta { margin-top: 4px; color: #aeb8c4; font-size: 10px; }
  :root[data-theme="light"] .preview-file-meta { color: #62788b; }
  #preview-stage { display: flex; align-items: center; justify-content: center; min-height: 0; height: 100%; overflow: auto; overscroll-behavior: contain; padding: clamp(12px, 2vw, 28px); background: radial-gradient(ellipse at center,#2c3037,#181a1e 78%); }
  :root[data-theme="light"] #preview-stage { background: radial-gradient(ellipse at center,#e3ebf3,#cfd9e3 78%); }
  #preview-stage.preview-image-stage { display: block; }
  #preview-frame { display: block; width: 100%; height: 100%; min-height: 0; border: 0; border-radius: 8px; background: #fff; box-shadow: 0 12px 42px rgba(0,0,0,.3); }
  #preview-frame.preview-pdf { height: 100%; }
  .preview-media-image { display: block; max-width: none; max-height: none; object-fit: contain; margin: 0 auto; border-radius: 4px; filter: drop-shadow(0 12px 28px rgba(0,0,0,.28)); transition: width .14s ease, height .14s ease; }
  .preview-media-video { display: block; width: 100%; max-height: 100%; background: #090a0b; border-radius: 9px; box-shadow: 0 12px 42px rgba(0,0,0,.3); }
  .preview-media-audio { width: min(620px, 100%); }
  #preview-text { width: 100%; height: 100%; margin: 0; overflow: auto; padding: 22px 26px; border: 1px solid rgba(255,255,255,.1); border-radius: 10px; color: #dce5ef; background: #171a1f; font: 12px/1.7 Consolas, 'Cascadia Code', monospace; tab-size: 4; white-space: pre; }
  #preview-text.wrap-lines { white-space: pre-wrap; overflow-wrap: anywhere; }
  :root[data-theme="light"] #preview-text { color: #263a50; border-color: rgba(104,140,174,.2); background: #f8fbfe; }
  .preview-tools { display: flex; align-items: center; gap: 7px; min-width: 0; }
  .preview-tools button { min-height: 31px; padding: 0 10px; border: 1px solid rgba(255,255,255,.16); border-radius: 8px; color: inherit; background: rgba(255,255,255,.06); font: inherit; font-size: 11px; cursor: pointer; }
  .preview-tools button:hover { background: rgba(255,255,255,.14); }
  :root[data-theme="light"] .preview-tools button { border-color: rgba(104,140,174,.24); background: rgba(255,255,255,.55); }
  .zoom-control { display: inline-flex; align-items: center; gap: 8px; margin-left: 4px; color: #b5c0cc; font-size: 10px; }
  :root[data-theme="light"] .zoom-control { color: #526a7e; }
  .zoom-control input { width: 100px; accent-color: #6ea6d2; }
  .zoom-value { min-width: 34px; text-align: right; }
  .preview-empty { width: min(460px, 100%); padding: 32px 22px; border: 1px solid rgba(255,255,255,.14); border-radius: 17px; background: rgba(255,255,255,.06); text-align: center; }
  :root[data-theme="light"] .preview-empty { border-color: rgba(104,140,174,.2); background: rgba(255,255,255,.55); }
  .preview-empty-icon { margin-bottom: 12px; font-size: 32px; }
  .preview-empty h3 { margin: 0 0 8px; font-size: 15px; }
  .preview-empty p { margin: 0; color: #b5c0cc; font-size: 12px; line-height: 1.6; }
  :root[data-theme="light"] .preview-empty p { color: #62788b; }
  .preview-actions { display: grid; grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr); align-items: center; }
  .preview-tools { grid-column: 1; justify-self: start; flex-wrap: wrap; }
  .preview-buttons { display: flex; grid-column: 2; align-items: center; justify-content: center; gap: 8px; }
  .preview-actions button { min-width: 106px; }
  @media (max-width: 900px) {
    #tree-pane { width: 38vw; min-width: 190px; }
  }
  @media (max-width: 700px) {
    body { padding: 10px 12px 24px; }
    .page-header { align-items: flex-start; flex-direction: column; }
    .header-actions { width: 100%; justify-content: center; }
    .sort-control { width: 100%; justify-content: space-between; }
    .sort-control select { flex: 1; max-width: 70%; }
    .grid { grid-template-columns: repeat(auto-fill, minmax(155px, 1fr)); gap: 10px; }
    #workspace { min-height: calc(100vh - 180px); }
    #main-content { padding-right: 0; }
    #tree-pane { position: fixed; z-index: 10; top: 10px; right: 10px; bottom: 10px; width: min(82vw, 340px) !important; max-width: none; min-width: 0; box-shadow: 0 18px 70px rgba(0,0,0,.42); }
    #tree-resizer { display: none !important; }
    .preview-dialog { width: calc(100% - 16px); height: 90vh; max-height: calc(100vh - 16px); }
    .preview-heading { padding: 10px 12px; }
    #preview-stage { padding: 9px; }
    #preview-text { padding: 14px; font-size: 11px; }
    .preview-actions { gap: 6px; padding: 10px; }
    .preview-actions button { min-width: 76px; padding: 0 9px; }
    .preview-tools { gap: 4px; }
    .preview-tools button { padding: 0 7px; }
    .zoom-control { gap: 4px; }
    .zoom-control input { width: 62px; }
  }
</style>
</head>
<body>
<div id="loading-screen" role="status" aria-live="polite">
  <div class="loading-card"><span class="loading-spinner" aria-hidden="true"></span><div><div id="loading-title" class="loading-title">Opening folder</div><div id="loading-detail" class="loading-detail">Scanning files and preparing your library…</div></div></div>
</div>
<header class="page-header">
  <div class="brand"><div class="brand-mark"><img src="/favicon.svg" alt=""></div><div class="brand-copy"><h1>FolderLens</h1><span id="root-label"></span></div></div>
  <div class="header-actions">
    <div class="sort-control"><label for="sort-by">Sort</label><select id="sort-by"><option value="name">Name</option><option value="added">Date modified</option><option value="size">File size</option></select></div>
    <div class="sort-control"><label for="sort-order">Order</label><select id="sort-order"><option value="asc">Ascending</option><option value="desc">Descending</option></select></div>
    <div class="theme-control"><span class="theme-label">Appearance</span><button id="theme-switch" class="theme-switch" type="button" role="switch" aria-checked="false" aria-label="Toggle light and dark appearance"><span class="theme-switch-track"><span aria-hidden="true">&#9790;</span><span aria-hidden="true">&#9728;</span></span><span class="theme-switch-knob"></span></button></div>
    <button id="toggle-tree" class="header-button tree-toggle" type="button" aria-expanded="false" aria-controls="tree-pane"><svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><rect x="2.5" y="3" width="15" height="14" rx="2" stroke="currentColor" stroke-width="1.5"/><path d="M7.5 3.5v13" stroke="currentColor" stroke-width="1.5"/><path d="M4.7 6.5h.7M4.7 9.5h.7M4.7 12.5h.7" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg><span>Folder tree</span></button>
    <button id="refresh-library" class="header-button" type="button">Refresh folder</button>
  </div>
</header>
<div id="workspace" class="tree-hidden">
  <main id="main-content"><div id="app"></div></main>
  <div id="tree-resizer" role="separator" aria-label="Resize folder tree" aria-orientation="vertical" tabindex="0" hidden></div>
  <aside id="tree-pane" aria-label="Folder tree" hidden>
    <div class="tree-header">
      <div class="tree-heading-wrap"><span class="tree-heading">Folder explorer</span><span id="tree-root-name" class="tree-root-name"></span></div>
      <div class="tree-header-actions"><button id="close-tree" class="icon-button" type="button" aria-label="Close folder tree" title="Close folder tree">&times;</button></div>
    </div>
    <div class="tree-toolbar">
      <label class="tree-search-wrap"><svg class="tree-search-icon" viewBox="0 0 20 20" fill="none" aria-hidden="true"><circle cx="8.8" cy="8.8" r="5.8" stroke="currentColor" stroke-width="1.6"/><path d="m13.2 13.2 4 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg><input id="tree-search" class="tree-search" type="search" placeholder="Search folders and files" aria-label="Search folders and files"></label>
      <div class="tree-toolbar-actions"><span id="tree-count-summary" class="tree-count-summary"></span><div class="tree-action-group"><button id="tree-expand-all" class="tree-action" type="button">Expand all</button><button id="tree-collapse-all" class="tree-action" type="button">Collapse all</button></div></div>
    </div>
    <div id="tree-content"></div><div id="tree-empty" hidden>No matching folders or files.</div>
  </aside>
</div>
<div id="toast" role="status"></div>
<dialog id="open-dialog">
  <div class="modal-heading"><div><h2>Open with</h2><p id="open-filename" class="modal-subtitle"></p></div><button id="dismiss-open" class="icon-button" type="button" aria-label="Close app picker">&times;</button></div>
  <div class="modal-body"><span class="app-list-label">Apps installed for this file type</span><div id="app-list" role="radiogroup" aria-label="Choose an installed application"></div></div>
  <div class="modal-actions"><button id="cancel-open" type="button">Cancel</button><button id="launch-file" class="primary-action" type="button">Open file</button></div>
</dialog>
<dialog id="preview-dialog" class="preview-dialog">
  <div class="modal-heading preview-heading"><div><h2 id="preview-title"></h2><div id="preview-file-meta" class="preview-file-meta"></div></div><button id="dismiss-preview" class="icon-button" type="button" aria-label="Close preview">&times;</button></div>
  <div id="preview-stage"></div>
  <div class="modal-actions preview-actions"><div id="preview-tools" class="preview-tools"></div><div class="preview-buttons"><button id="close-preview" type="button">Close</button><button id="preview-open-with" class="primary-action" type="button">Open with...</button></div></div>
</dialog>
<script>
const initialCatalog = $catalogJson;
let data = initialCatalog.sections;
let sectionTargets = initialCatalog.targets;
const app = document.getElementById('app');
const toast = document.getElementById('toast');
const loadingScreen = document.getElementById('loading-screen');
const loadingTitle = document.getElementById('loading-title');
const loadingDetail = document.getElementById('loading-detail');
const rootElement = document.documentElement;
const themeSwitch = document.getElementById('theme-switch');
const workspace = document.getElementById('workspace');
const treePane = document.getElementById('tree-pane');
const treeResizer = document.getElementById('tree-resizer');
const treeContent = document.getElementById('tree-content');
const treeToggle = document.getElementById('toggle-tree');
const treeSearch = document.getElementById('tree-search');
const treeEmpty = document.getElementById('tree-empty');
const sortBy = document.getElementById('sort-by');
const sortOrder = document.getElementById('sort-order');
const refreshButton = document.getElementById('refresh-library');
const openDialog = document.getElementById('open-dialog');
const appList = document.getElementById('app-list');
const previewDialog = document.getElementById('preview-dialog');
let toastTimer = null;
let activeFile = null;
let activePreviewFile = null;
let selectedAppId = 'default';
let refreshing = false;
let treeResizeActive = false;
let selectedTreeFilePath = null;
const expandedTreePaths = new Set([initialCatalog.root.toLowerCase()]);
const folderSectionIds = new Map();
const fileDomIds = new Map();
document.getElementById('root-label').textContent = initialCatalog.root;
const naturalCompare = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 2400);
}

function setTheme(theme, save) {
  rootElement.dataset.theme = theme;
  themeSwitch.setAttribute('aria-checked', String(theme === 'light'));
  if (save) {
    try { localStorage.setItem('fileLibraryTheme', theme); }
    catch (error) { console.warn('Could not save theme preference:', error); }
  }
}
let savedTheme = 'dark';
try {
  const stored = localStorage.getItem('fileLibraryTheme');
  if (stored === 'light' || stored === 'dark') savedTheme = stored;
} catch (error) { console.warn('Could not read theme preference:', error); }
setTheme(savedTheme, false);
themeSwitch.addEventListener('click', () => setTheme(rootElement.dataset.theme === 'light' ? 'dark' : 'light', true));

function fileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  let amount = bytes;
  let index = -1;
  do { amount /= 1024; index++; } while (amount >= 1024 && index < units.length - 1);
  return amount.toFixed(amount < 10 ? 1 : 0) + ' ' + units[index];
}
function sortFiles(files) {
  const direction = sortOrder.value === 'desc' ? -1 : 1;
  return [...files].sort((left, right) => {
    let comparison = 0;
    if (sortBy.value === 'size') comparison = left.size - right.size;
    else if (sortBy.value === 'added') comparison = Date.parse(left.added) - Date.parse(right.added);
    else comparison = naturalCompare.compare(left.name, right.name);
    return comparison * direction || naturalCompare.compare(left.name, right.name);
  });
}

function normalizeFolderPath(path) {
  const normalized = String(path).replace(/\//g, '\\');
  return (normalized.length > 3 ? normalized.replace(/\\+$/, '') : normalized).toLocaleLowerCase();
}
function parentFolderPath(path) {
  const normalized = String(path).replace(/\//g, '\\');
  const trimmed = normalized.length > 3 ? normalized.replace(/\\+$/, '') : normalized;
  const separator = trimmed.lastIndexOf('\\');
  if (separator < 0) return '';
  if (separator === 2 && /^[a-z]:/i.test(trimmed)) return trimmed.slice(0, 3);
  return trimmed.slice(0, separator);
}
function buildFolderTreeModel() {
  const rootPath = initialCatalog.root.replace(/[\\/]+$/, '');
  const rootNode = {
    name: rootPath.split(/[\\/]/).pop() || initialCatalog.root,
    path: initialCatalog.root,
    children: new Map(),
    sectionName: null,
    files: [],
    depth: 0,
    size: 0,
    modified: 0
  };
  const nodes = new Map([[normalizeFolderPath(rootNode.path), rootNode]]);
  const targetsByDepth = Object.entries(sectionTargets).sort((left, right) =>
    String(left[1]).split(/[\\/]+/).length - String(right[1]).split(/[\\/]+/).length);
  for (const [, targetPath] of targetsByDepth) {
    const target = String(targetPath);
    const key = normalizeFolderPath(target);
    if (!nodes.has(key)) {
      const parentPath = parentFolderPath(target);
      const parent = nodes.get(normalizeFolderPath(parentPath)) || rootNode;
      const name = target.replace(/[\\/]+$/, '').split(/[\\/]/).pop() || target;
      const node = { name, path: target, children: new Map(), sectionName: null, files: [], depth: parent.depth + 1, size: 0, modified: 0 };
      nodes.set(key, node);
      parent.children.set(key, node);
    }
  }
  for (const [sectionName, targetPath] of Object.entries(sectionTargets)) {
    const node = nodes.get(normalizeFolderPath(targetPath));
    if (!node) continue;
    node.sectionName = sectionName;
    node.files = data[sectionName] || [];
  }
  function calculateFolderStats(node) {
    for (const file of node.files) {
      node.size += Number(file.size) || 0;
      node.modified = Math.max(node.modified, Date.parse(file.added) || 0);
    }
    for (const child of node.children.values()) {
      calculateFolderStats(child);
      node.size += child.size;
      node.modified = Math.max(node.modified, child.modified);
    }
  }
  calculateFolderStats(rootNode);
  return rootNode;
}
function compareFolderNodes(left, right) {
  const direction = sortOrder.value === 'desc' ? -1 : 1;
  let comparison = 0;
  if (sortBy.value === 'size') comparison = left.size - right.size;
  else if (sortBy.value === 'added') comparison = left.modified - right.modified;
  else comparison = naturalCompare.compare(left.name, right.name);
  return comparison * direction || naturalCompare.compare(left.name, right.name);
}
function getSortedFolderSections(rootNode) {
  const ordered = [];
  function visit(node) {
    if (node.sectionName) ordered.push(node);
    const children = [...node.children.values()].sort(compareFolderNodes);
    for (const child of children) visit(child);
  }
  visit(rootNode);
  return ordered;
}

function highlightTreeFile(filePath) {
  const previousCardId = selectedTreeFilePath && fileDomIds.get(selectedTreeFilePath.toLowerCase());
  const previousCard = previousCardId && document.getElementById(previousCardId);
  if (previousCard) previousCard.classList.remove('tree-file-highlight');
  selectedTreeFilePath = filePath;
  const cardId = fileDomIds.get(filePath.toLowerCase());
  const card = cardId && document.getElementById(cardId);
  if (!card) return;
  card.scrollIntoView({ behavior: 'smooth', block: 'center' });
  card.classList.remove('tree-file-highlight');
  void card.offsetWidth;
  card.classList.add('tree-file-highlight');
}

function renderFolderTree(rootNode) {
  document.getElementById('tree-root-name').textContent = initialCatalog.root;
  function makeTreeBranch(node, isRoot) {
    const item = document.createElement('li');
    const details = document.createElement('details');
    details.dataset.path = node.path.toLowerCase();
    details.open = isRoot || expandedTreePaths.has(node.path.toLowerCase());
    details.addEventListener('toggle', () => {
      if (details.open) expandedTreePaths.add(details.dataset.path);
      else expandedTreePaths.delete(details.dataset.path);
    });
    const summary = document.createElement('summary');
    summary.className = 'tree-row';
    summary.title = node.path;
    const caret = document.createElement('span');
    caret.className = 'tree-caret';
    caret.textContent = node.children.size ? '\u25B8' : '';
    const folderIcon = document.createElement('span');
    folderIcon.className = 'tree-folder-icon';
    folderIcon.innerHTML = '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M2.5 5.2a1.7 1.7 0 0 1 1.7-1.7h4l1.7 1.8h5.9a1.7 1.7 0 0 1 1.7 1.7v7.7a1.7 1.7 0 0 1-1.7 1.7H4.2a1.7 1.7 0 0 1-1.7-1.7V5.2Z" fill="currentColor" fill-opacity=".18" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"/><path d="M2.8 7.4h14.4" stroke="currentColor" stroke-width="1.2"/></svg>';
    const label = document.createElement('span');
    label.className = 'tree-label';
    label.textContent = node.name;
    summary.append(caret, folderIcon, label);
    const folderId = folderSectionIds.get(node.path.toLowerCase());
    const sectionName = node.sectionName;
    if (sectionName && data[sectionName]) {
      const count = document.createElement('span');
      count.className = 'tree-count';
      count.textContent = String(data[sectionName].length);
      summary.appendChild(count);
    }
    if (folderId && document.getElementById(folderId)) summary.classList.add('active');
    summary.addEventListener('click', () => {
      if (folderId) {
        document.querySelectorAll('.tree-row.active').forEach(row => row.classList.remove('active'));
        summary.classList.add('active');
        const section = document.getElementById(folderId);
        if (section) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
    details.appendChild(summary);

    const children = [...node.children.values()].sort(compareFolderNodes);
    if (children.length || node.files.length) {
      const nested = document.createElement('ul');
      nested.className = 'tree-children';
      for (const child of children) nested.appendChild(makeTreeBranch(child, false));
      for (const file of sortFiles(node.files)) {
        const fileItem = document.createElement('li');
        const fileRow = document.createElement('button');
        fileRow.type = 'button';
        fileRow.className = 'tree-row file-tree-row';
        fileRow.title = file.path;
        if (selectedTreeFilePath && selectedTreeFilePath.toLowerCase() === file.path.toLowerCase()) fileRow.classList.add('active');
        const fileIcon = document.createElement('span');
        fileIcon.className = 'tree-file-icon';
        fileIcon.innerHTML = '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M5 2.8h6.4l3.8 3.8v10.6H5V2.8Z" fill="currentColor" fill-opacity=".12" stroke="currentColor" stroke-width="1.25" stroke-linejoin="round"/><path d="M11.2 3v4h4M7.5 10h5.2M7.5 12.7h5.2" stroke="currentColor" stroke-width="1.15" stroke-linecap="round" stroke-linejoin="round"/></svg>';
        const fileLabel = document.createElement('span');
        fileLabel.className = 'tree-label';
        fileLabel.textContent = file.name;
        fileRow.append(fileIcon, fileLabel);
        fileRow.addEventListener('click', () => {
          document.querySelectorAll('.tree-row.active').forEach(row => row.classList.remove('active'));
          fileRow.classList.add('active');
          highlightTreeFile(file.path);
        });
        fileItem.appendChild(fileRow);
        nested.appendChild(fileItem);
      }
      details.appendChild(nested);
    }
    item.appendChild(details);
    return item;
  }

  const list = document.createElement('ul');
  list.className = 'tree-list';
  list.appendChild(makeTreeBranch(rootNode, true));
  treeContent.replaceChildren(list);
  const folderCount = treeContent.querySelectorAll('details').length;
  const fileCount = treeContent.querySelectorAll('.file-tree-row').length;
  document.getElementById('tree-count-summary').textContent = folderCount + ' folders · ' + fileCount + ' files';
  applyTreeSearch();
}

function applyTreeSearch() {
  const query = treeSearch.value.trim().toLocaleLowerCase();
  const items = [...treeContent.querySelectorAll('li')];
  for (const item of items.reverse()) {
    const row = item.querySelector(':scope > details > .tree-row, :scope > .tree-row');
    const ownMatch = !query || row.textContent.toLocaleLowerCase().includes(query) || row.title.toLocaleLowerCase().includes(query);
    const descendantMatch = Boolean(item.querySelector('li:not([hidden])'));
    item.hidden = !ownMatch && !descendantMatch;
    if (query && descendantMatch) {
      const details = item.querySelector(':scope > details');
      if (details) details.open = true;
    }
  }
  const hasResults = Boolean(treeContent.querySelector('li:not([hidden])'));
  treeEmpty.hidden = !query || hasResults;
}

function renderCatalog(nextData, nextTargets) {
  data = nextData;
  if (nextTargets) sectionTargets = nextTargets;
  app.replaceChildren();
  folderSectionIds.clear();
  fileDomIds.clear();
  const folderRoot = buildFolderTreeModel();
  const orderedFolders = getSortedFolderSections(folderRoot);
  const sectionNames = orderedFolders.map(folder => folder.sectionName);
  if (!sectionNames.length) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = 'This folder is empty.';
    app.appendChild(empty);
    renderFolderTree(folderRoot);
    return;
  }
  for (const [sectionIndex, sectionName] of sectionNames.entries()) {
    const folder = orderedFolders[sectionIndex];
    const section = document.createElement('section');
    section.className = 'series';
    section.id = 'folder-section-' + sectionIndex;
    section.dataset.folderPath = sectionTargets[sectionName] || '';
    section.style.setProperty('--folder-depth', String(Math.min(folder.depth, 6)));
    section.style.marginLeft = Math.min(folder.depth * 18, 108) + 'px';
    if (section.dataset.folderPath) folderSectionIds.set(section.dataset.folderPath.toLowerCase(), section.id);
    const heading = document.createElement('h2');
    heading.textContent = sectionName;
    heading.title = sectionName;
    section.appendChild(heading);
    const grid = document.createElement('div');
    grid.className = 'grid';
    for (const [fileIndex, file] of sortFiles(data[sectionName]).entries()) {
      const card = document.createElement('article');
      card.className = 'card';
      card.id = 'file-entry-' + sectionIndex + '-' + fileIndex;
      fileDomIds.set(file.path.toLowerCase(), card.id);
      if (selectedTreeFilePath && selectedTreeFilePath.toLowerCase() === file.path.toLowerCase()) {
        card.classList.add('tree-file-highlight');
      }
      const thumb = document.createElement('div');
      thumb.className = 'thumb';
      if (file.image) {
        const image = document.createElement('img');
        image.src = '/preview?path=' + encodeURIComponent(file.path);
        image.alt = '';
        image.loading = 'lazy';
        thumb.appendChild(image);
      } else {
        const placeholder = document.createElement('span');
        placeholder.className = 'placeholder';
        placeholder.textContent = file.ext;
        thumb.appendChild(placeholder);
      }
      const info = document.createElement('div');
      info.className = 'info';
      const title = document.createElement('div');
      title.className = 'title';
      title.textContent = file.name;
      const metadata = document.createElement('div');
      metadata.className = 'metadata';
      metadata.innerHTML = '<span></span><span></span>';
      metadata.children[0].textContent = file.ext;
      metadata.children[1].textContent = fileSize(file.size);
      const actions = document.createElement('div');
      actions.className = 'card-actions';
      const preview = document.createElement('button');
      preview.type = 'button';
      preview.textContent = 'Preview';
      preview.addEventListener('click', () => showPreview(file));
      const open = document.createElement('button');
      open.type = 'button';
      open.textContent = 'Open with...';
      open.addEventListener('click', () => chooseApp(file));
      actions.append(preview, open);
      info.append(title, metadata, actions);
      card.append(thumb, info);
      grid.appendChild(card);
    }
    const addCard = document.createElement('div');
    addCard.className = 'card add-card';
    addCard.tabIndex = 0;
    addCard.setAttribute('role', 'button');
    addCard.setAttribute('aria-label', 'Add files to ' + sectionName);
    const addTitle = document.createElement('span');
    addTitle.className = 'add-title';
    addTitle.textContent = 'Add files to this folder';
    const addHint = document.createElement('span');
    addHint.className = 'add-hint';
    addHint.textContent = 'Drop any file here or click to browse';
    const fileInput = document.createElement('input');
    fileInput.className = 'add-input';
    fileInput.type = 'file';
    fileInput.multiple = true;
    fileInput.addEventListener('click', event => event.stopPropagation());
    fileInput.addEventListener('change', () => {
      if (fileInput.files.length) uploadFiles(fileInput.files, sectionTargets[sectionName]);
      fileInput.value = '';
    });
    addCard.append(addTitle, addHint, fileInput);
    addCard.addEventListener('click', () => fileInput.click());
    addCard.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        fileInput.click();
      }
    });
    addCard.addEventListener('dragover', event => {
      event.preventDefault();
      addCard.classList.add('drag-over');
    });
    addCard.addEventListener('dragleave', event => {
      if (!addCard.contains(event.relatedTarget)) addCard.classList.remove('drag-over');
    });
    addCard.addEventListener('drop', event => {
      event.preventDefault();
      addCard.classList.remove('drag-over');
      if (event.dataTransfer.files.length) uploadFiles(event.dataTransfer.files, sectionTargets[sectionName]);
    });
    grid.appendChild(addCard);
    section.appendChild(grid);
    app.appendChild(section);
  }
  renderFolderTree(folderRoot);
}

async function uploadFiles(fileList, targetFolder) {
  if (!targetFolder) {
    showToast('Could not find the destination folder. Refresh and try again.');
    return;
  }
  const files = Array.from(fileList);
  refreshButton.disabled = true;
  let added = 0;
  const failures = [];
  try {
    for (const file of files) {
      refreshButton.textContent = 'Adding ' + (added + 1) + '/' + files.length + '...';
      try {
        const query = '?folder=' + encodeURIComponent(targetFolder) + '&name=' + encodeURIComponent(file.name);
        const response = await fetch('/upload' + query, {
          method: 'POST',
          headers: { 'Content-Type': 'application/octet-stream' },
          body: file
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Upload failed.');
        added++;
      } catch (error) { failures.push(file.name + ': ' + error.message); }
    }
    if (added) {
      const response = await fetch('/library', { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Could not refresh the folder.');
      renderCatalog(result.sections, result.targets);
    }
    if (failures.length) {
      showToast(added + ' file(s) added; ' + failures.length + ' failed.');
      console.error('Some file uploads failed:', failures);
    } else {
      showToast(added + ' file(s) added.');
    }
  } catch (error) {
    showToast(error.message);
    console.error('Could not complete file upload:', error);
  } finally {
    refreshButton.disabled = false;
    refreshButton.textContent = 'Refresh folder';
  }
}

async function chooseApp(file) {
  activeFile = file;
  document.getElementById('open-filename').textContent = file.name;
  selectedAppId = 'default';
  appList.replaceChildren();
  const loading = document.createElement('div');
  loading.className = 'modal-message';
  loading.textContent = 'Looking up apps registered on this PC for .' + (file.ext === 'FILE' ? 'unknown' : file.ext.toLowerCase()) + ' files...';
  appList.appendChild(loading);
  openDialog.showModal();
  try {
    const response = await fetch('/apps?path=' + encodeURIComponent(file.path), { cache: 'no-store' });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Could not find apps.');
    appList.replaceChildren();
    for (const appInfo of result.apps) {
      const option = document.createElement('button');
      option.type = 'button';
      option.className = 'app-option' + (appInfo.id === 'default' ? ' selected' : '');
      option.setAttribute('role', 'radio');
      option.setAttribute('aria-checked', String(appInfo.id === 'default'));
      const icon = document.createElement('span');
      icon.className = 'app-icon';
      icon.textContent = appInfo.id === 'default' ? 'OS' : appInfo.name.slice(0, 2);
      const copy = document.createElement('span');
      copy.className = 'app-option-copy';
      const name = document.createElement('span');
      name.className = 'app-option-name';
      name.textContent = appInfo.name;
      const detail = document.createElement('span');
      detail.className = 'app-option-detail';
      detail.textContent = appInfo.id === 'default' ? 'Use the Windows default app' : 'Installed on this PC';
      const radio = document.createElement('span');
      radio.className = 'app-radio';
      copy.append(name, detail);
      option.append(icon, copy, radio);
      option.addEventListener('click', () => {
        selectedAppId = appInfo.id;
        appList.querySelectorAll('.app-option').forEach(item => {
          const selected = item === option;
          item.classList.toggle('selected', selected);
          item.setAttribute('aria-checked', String(selected));
        });
      });
      appList.appendChild(option);
    }
  } catch (error) {
    openDialog.close();
    showToast(error.message);
  }
}

async function launchFile() {
  if (!activeFile) return;
  const button = document.getElementById('launch-file');
  button.disabled = true;
  try {
    const response = await fetch('/open?path=' + encodeURIComponent(activeFile.path) + '&app=' + encodeURIComponent(selectedAppId), { cache: 'no-store' });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Could not open file.');
    openDialog.close();
    showToast('Opened ' + activeFile.name);
  } catch (error) {
    showToast(error.message);
  } finally { button.disabled = false; }
}
document.getElementById('launch-file').addEventListener('click', launchFile);
document.getElementById('cancel-open').addEventListener('click', () => openDialog.close());
document.getElementById('dismiss-open').addEventListener('click', () => openDialog.close());

function showPreviewMessage(title, description) {
  const empty = document.createElement('div');
  empty.className = 'preview-empty';
  const icon = document.createElement('div');
  icon.className = 'preview-empty-icon';
  icon.textContent = '\u25A4';
  const heading = document.createElement('h3');
  heading.textContent = title;
  const message = document.createElement('p');
  message.textContent = description;
  empty.append(icon, heading, message);
  document.getElementById('preview-stage').replaceChildren(empty);
}

async function showPreview(file) {
  activePreviewFile = file;
  document.getElementById('preview-title').textContent = file.name;
  document.getElementById('preview-file-meta').textContent = file.ext + ' | ' + fileSize(file.size);
  const stage = document.getElementById('preview-stage');
  const tools = document.getElementById('preview-tools');
  stage.replaceChildren();
  stage.classList.remove('preview-image-stage');
  tools.replaceChildren();
  if (file.previewKind === 'unsupported') {
    showPreviewMessage('Preview is not available for this file', 'This file type cannot be displayed safely in the browser. Choose an installed app with "Open with..." to view it.');
  } else if (file.previewKind === 'image') {
    stage.classList.add('preview-image-stage');
    const image = document.createElement('img');
    image.className = 'preview-media-image';
    image.src = '/preview?path=' + encodeURIComponent(file.path);
    image.alt = file.name;
    const zoom = document.createElement('input');
    zoom.type = 'range';
    zoom.min = '50';
    zoom.max = '250';
    zoom.step = '10';
    zoom.value = '100';
    zoom.setAttribute('aria-label', 'Image zoom');
    const zoomLabel = document.createElement('span');
    zoomLabel.className = 'zoom-value';
    zoomLabel.textContent = '100%';
    const zoomControl = document.createElement('label');
    zoomControl.className = 'zoom-control';
    zoomControl.append('Zoom', zoom, zoomLabel);
    tools.appendChild(zoomControl);
    let fittedWidth = 0;
    let fittedHeight = 0;
    function fitImage() {
      if (!image.naturalWidth || !image.naturalHeight) return;
      const availableWidth = Math.max(100, stage.clientWidth - 56);
      const availableHeight = Math.max(100, stage.clientHeight - 56);
      const scaleToFit = Math.min(1, availableWidth / image.naturalWidth, availableHeight / image.naturalHeight);
      fittedWidth = image.naturalWidth * scaleToFit;
      fittedHeight = image.naturalHeight * scaleToFit;
      const zoomFactor = Number(zoom.value) / 100;
      image.style.width = Math.max(1, fittedWidth * zoomFactor) + 'px';
      image.style.height = Math.max(1, fittedHeight * zoomFactor) + 'px';
    }
    image.addEventListener('load', fitImage);
    image.addEventListener('error', () => showPreviewMessage('Image could not be loaded', 'The file may have changed or the image format may not be supported by this browser.'));
    zoom.addEventListener('input', () => {
      fitImage();
      zoomLabel.textContent = zoom.value + '%';
    });
    window.addEventListener('resize', fitImage);
    previewDialog.addEventListener('close', () => window.removeEventListener('resize', fitImage), { once: true });
    stage.appendChild(image);
  } else if (file.previewKind === 'audio' || file.previewKind === 'video') {
    const media = document.createElement(file.previewKind);
    media.className = 'preview-media-' + file.previewKind;
    media.controls = true;
    media.preload = 'metadata';
    media.src = '/preview?path=' + encodeURIComponent(file.path);
    media.addEventListener('error', () => showPreviewMessage('Media could not be played', 'The browser may not support this codec. Use "Open with..." to choose an installed player.'));
    stage.appendChild(media);
  } else if (file.previewKind === 'text') {
    if (file.size > 4 * 1024 * 1024) {
      showPreviewMessage('This text file is large', 'For responsiveness, browser preview is limited to 4 MB. Use "Open with..." to view the full file.');
    } else {
      const pre = document.createElement('pre');
      pre.id = 'preview-text';
      pre.textContent = 'Loading preview...';
      stage.appendChild(pre);
      const wrap = document.createElement('button');
      wrap.type = 'button';
      wrap.textContent = 'Wrap lines';
      wrap.addEventListener('click', () => {
        pre.classList.toggle('wrap-lines');
        wrap.setAttribute('aria-pressed', String(pre.classList.contains('wrap-lines')));
      });
      const copy = document.createElement('button');
      copy.type = 'button';
      copy.textContent = 'Copy text';
      copy.addEventListener('click', async () => {
        try {
          await navigator.clipboard.writeText(pre.textContent);
          showToast('Text copied to clipboard.');
        } catch (error) {
          showToast('Could not copy text. Check browser clipboard permissions.');
          console.error('Could not copy preview text:', error);
        }
      });
      tools.append(wrap, copy);
      try {
        const response = await fetch('/preview?path=' + encodeURIComponent(file.path), { cache: 'no-store' });
        if (!response.ok) throw new Error('HTTP ' + response.status);
        pre.textContent = await response.text();
      } catch (error) {
        showPreviewMessage('Text could not be loaded', 'The file may have changed or become unavailable. ' + error.message);
      }
    }
  } else {
    const frame = document.createElement('iframe');
    frame.id = 'preview-frame';
    frame.title = 'Preview of ' + file.name;
    frame.className = 'preview-' + file.previewKind;
    frame.src = '/preview?path=' + encodeURIComponent(file.path);
    frame.addEventListener('error', () => showPreviewMessage('Preview could not be loaded', 'The browser may not support this document format. Use "Open with..." to choose an installed app.'));
    stage.appendChild(frame);
  }
  previewDialog.showModal();
}
document.getElementById('close-preview').addEventListener('click', () => {
  previewDialog.close();
});
document.getElementById('dismiss-preview').addEventListener('click', () => previewDialog.close());
document.getElementById('preview-open-with').addEventListener('click', () => {
  if (!activePreviewFile) return;
  const file = activePreviewFile;
  previewDialog.close();
  chooseApp(file);
});
previewDialog.addEventListener('close', () => {
  document.getElementById('preview-stage').replaceChildren();
  document.getElementById('preview-stage').classList.remove('preview-image-stage');
  document.getElementById('preview-tools').replaceChildren();
  activePreviewFile = null;
});

function setTreeOpen(open) {
  workspace.classList.toggle('tree-hidden', !open);
  treePane.hidden = !open;
  treeResizer.hidden = !open;
  treeToggle.setAttribute('aria-expanded', String(open));
  if (open) {
    try {
      const savedWidth = Number(localStorage.getItem('fileLibraryTreeWidth'));
      const width = Number.isFinite(savedWidth) && savedWidth > 0
        ? savedWidth
        : Math.min(360, window.innerWidth * .38);
      treePane.style.width = clampTreeWidth(width) + 'px';
    } catch (error) { console.warn('Could not read folder tree width:', error); }
  }
}
treeToggle.addEventListener('click', () => setTreeOpen(workspace.classList.contains('tree-hidden')));
document.getElementById('close-tree').addEventListener('click', () => setTreeOpen(false));
treeSearch.addEventListener('input', applyTreeSearch);
document.getElementById('tree-expand-all').addEventListener('click', () => {
  treeContent.querySelectorAll('details').forEach(details => {
    details.open = true;
    expandedTreePaths.add(details.dataset.path);
  });
});
document.getElementById('tree-collapse-all').addEventListener('click', () => {
  treeContent.querySelectorAll('details').forEach(details => {
    if (details.dataset.path === initialCatalog.root.toLowerCase()) {
      details.open = true;
      return;
    }
    details.open = false;
    expandedTreePaths.delete(details.dataset.path);
  });
});
function clampTreeWidth(width) {
  const minimum = window.innerWidth <= 900 ? 190 : 240;
  const maximum = Math.max(minimum, Math.min(window.innerWidth * .55, workspace.clientWidth - 280));
  return Math.max(minimum, Math.min(width, maximum));
}
treeResizer.addEventListener('pointerdown', event => {
  treeResizeActive = true;
  treeResizer.classList.add('dragging');
  treeResizer.setPointerCapture(event.pointerId);
  event.preventDefault();
});
treeResizer.addEventListener('pointermove', event => {
  if (!treeResizeActive) return;
  const bounds = workspace.getBoundingClientRect();
  const width = clampTreeWidth(bounds.right - event.clientX - treeResizer.offsetWidth / 2);
  treePane.style.width = width + 'px';
});
function finishTreeResize(event) {
  if (!treeResizeActive) return;
  treeResizeActive = false;
  treeResizer.classList.remove('dragging');
  if (event && treeResizer.hasPointerCapture(event.pointerId)) treeResizer.releasePointerCapture(event.pointerId);
  try { localStorage.setItem('fileLibraryTreeWidth', String(Math.round(treePane.getBoundingClientRect().width))); }
  catch (error) { console.warn('Could not save folder tree width:', error); }
}
treeResizer.addEventListener('pointerup', finishTreeResize);
treeResizer.addEventListener('pointercancel', finishTreeResize);
treeResizer.addEventListener('keydown', event => {
  if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
  event.preventDefault();
  const change = event.key === 'ArrowLeft' ? 24 : -24;
  treePane.style.width = clampTreeWidth(treePane.getBoundingClientRect().width + change) + 'px';
  try { localStorage.setItem('fileLibraryTreeWidth', String(Math.round(treePane.getBoundingClientRect().width))); }
  catch (error) { console.warn('Could not save folder tree width:', error); }
});
window.addEventListener('resize', () => {
  if (!treePane.hidden && window.innerWidth > 700) {
    treePane.style.width = clampTreeWidth(treePane.getBoundingClientRect().width) + 'px';
  }
});

async function refreshLibrary(initialLoad = false) {
  if (refreshing) return;
  refreshing = true;
  refreshButton.disabled = true;
  refreshButton.textContent = initialLoad ? 'Opening...' : 'Scanning...';
  loadingTitle.textContent = initialLoad ? 'Opening folder' : 'Refreshing folder';
  loadingDetail.textContent = initialLoad
    ? 'Scanning files and preparing your library…'
    : 'Rescanning files and updating the folder view…';
  loadingScreen.hidden = false;
  try {
    const response = await fetch('/library', { cache: 'no-store' });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Could not refresh folder.');
    renderCatalog(result.sections, result.targets);
    loadingScreen.hidden = true;
    if (!initialLoad) showToast('Folder refreshed.');
  } catch (error) {
    loadingScreen.hidden = true;
    showToast(error.message);
    console.error('Could not refresh folder:', error);
    if (initialLoad) {
      app.replaceChildren();
      const failure = document.createElement('div');
      failure.className = 'empty';
      failure.textContent = 'Folder could not be opened: ' + error.message + ' ';
      const retry = document.createElement('button');
      retry.type = 'button';
      retry.textContent = 'Try again';
      retry.addEventListener('click', () => refreshLibrary(true));
      failure.appendChild(retry);
      app.appendChild(failure);
    }
  } finally {
    refreshing = false;
    refreshButton.disabled = false;
    refreshButton.textContent = 'Refresh folder';
  }
}
refreshButton.addEventListener('click', () => refreshLibrary());
sortBy.addEventListener('change', () => renderCatalog(data));
sortOrder.addEventListener('change', () => renderCatalog(data));
refreshLibrary(true);
function heartbeat() { fetch('/heartbeat', { cache: 'no-store' }).catch(() => {}); }
heartbeat();
setInterval(heartbeat, 5000);
window.addEventListener('pagehide', () => navigator.sendBeacon('/page-close', ''));
</script>
</body>
</html>
"@

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($url)
    $listener.Start()
    if ($edgePath) {
        Start-Process -FilePath $edgePath -ArgumentList "--app=$url"
    } else {
        Start-Process $url
    }

    [Console]::Title = "FolderLens - DO NOT CLOSE THIS WINDOW"
    Write-Host "Browsing $root"
    Write-Host "DO NOT CLOSE THIS TERMINAL while FolderLens is open." -ForegroundColor Yellow
    Write-Host "FolderLens will stop this server after you close its browser window." -ForegroundColor DarkGray
    $pageCloseRequested = $null
    $pending = $listener.BeginGetContext($null, $null)
    while ($listener.IsListening) {
        if (-not $pending.AsyncWaitHandle.WaitOne(500)) {
            if ($pageCloseRequested -and ((Get-Date) - $pageCloseRequested).TotalSeconds -ge 15) { break }
            continue
        }

        $context = $listener.EndGetContext($pending)
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath
        if ($path -eq '/heartbeat') {
            $pageCloseRequested = $null
            $response.StatusCode = 204
            $response.Close()
        }
        elseif ($path -eq '/page-close') {
            $pageCloseRequested = Get-Date
            $response.StatusCode = 204
            $response.Close()
        }
        elseif ($path -eq '/favicon.svg') {
            try {
                $faviconPath = Join-Path $PSScriptRoot 'opened-book-4983.svg'
                $bytes = [IO.File]::ReadAllBytes($faviconPath)
                $response.ContentType = 'image/svg+xml'
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
            } catch {
                $response.StatusCode = 404
                $response.Close()
            }
        }
        elseif ($path -eq '/library') {
            try {
                $fresh = Get-LibraryCatalog
                $value = @{ sections = $fresh.Sections; targets = $fresh.Targets; root = $root }
                Write-JsonResponse -Response $response -Value $value
                Write-Host "Folder refreshed: $($fresh.Count) file(s)."
            } catch {
                Write-JsonResponse -Response $response -Value @{ error = $_.Exception.Message } -StatusCode 500
            }
        }
        elseif ($path -eq '/apps') {
            try {
                $filePath = Get-QueryValue -Query $request.Url.Query -Name 'path'
                if (-not $filePath -or -not (Test-PathWithinRoot -Path $filePath) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    throw "The file is outside the selected folder or no longer exists."
                }
                $extension = [IO.Path]::GetExtension($filePath)
                $apps = if ($extension) { Get-InstalledAppsForExtension -Extension $extension } else { @([PSCustomObject]@{ id = 'default'; name = 'Windows default app' }) }
                Write-JsonResponse -Response $response -Value @{ apps = $apps }
            } catch {
                Write-JsonResponse -Response $response -Value @{ error = $_.Exception.Message } -StatusCode 400
            }
        }
        elseif ($path -eq '/upload') {
            $destinationPath = $null
            try {
                $targetFolder = Get-QueryValue -Query $request.Url.Query -Name 'folder'
                $fileName = Get-QueryValue -Query $request.Url.Query -Name 'name'
                if (-not $targetFolder -or -not (Test-PathWithinRoot -Path $targetFolder) -or -not (Test-Path -LiteralPath $targetFolder -PathType Container)) {
                    throw "The destination folder is outside the selected folder or no longer exists."
                }
                if ([string]::IsNullOrWhiteSpace($fileName) -or [IO.Path]::GetFileName($fileName) -ne $fileName) {
                    throw "Invalid filename."
                }
                $destinationPath = Join-Path $targetFolder $fileName
                if (Test-Path -LiteralPath $destinationPath) {
                    $baseName = [IO.Path]::GetFileNameWithoutExtension($fileName)
                    $extension = [IO.Path]::GetExtension($fileName)
                    $suffix = 2
                    do {
                        $destinationPath = Join-Path $targetFolder ("{0} ({1}){2}" -f $baseName, $suffix, $extension)
                        $suffix++
                    } while (Test-Path -LiteralPath $destinationPath)
                }
                $fileStream = [IO.File]::Open($destinationPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $request.InputStream.CopyTo($fileStream) } finally { $fileStream.Dispose() }
                Write-JsonResponse -Response $response -Value @{ name = [IO.Path]::GetFileName($destinationPath) }
                Write-Host "Added file: $destinationPath"
            } catch {
                if ($destinationPath -and (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
                    Remove-Item -LiteralPath $destinationPath -Force -ErrorAction SilentlyContinue
                }
                Write-JsonResponse -Response $response -Value @{ error = $_.Exception.Message } -StatusCode 400
            }
        }
        elseif ($path -eq '/open') {
            try {
                $filePath = Get-QueryValue -Query $request.Url.Query -Name 'path'
                $appId = Get-QueryValue -Query $request.Url.Query -Name 'app'
                if (-not $filePath -or -not (Test-PathWithinRoot -Path $filePath) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    throw "The file is outside the selected folder or no longer exists."
                }
                if (-not $appId -or $appId -eq 'default') {
                    Start-Process -FilePath $filePath -ErrorAction Stop
                } else {
                    $selectedApp = $script:appCatalogById[$appId]
                    if (-not $selectedApp -or
                        $selectedApp.Extension -ne [IO.Path]::GetExtension($filePath).ToLowerInvariant() -or
                        -not (Test-Path -LiteralPath $selectedApp.Executable -PathType Leaf)) {
                        throw "That app is no longer available. Reopen the app list and try again."
                    }
                    $arguments = Get-ApplicationFileArguments -CommandArguments $selectedApp.Arguments -FilePath $filePath
                    Start-Process -FilePath $selectedApp.Executable -ArgumentList $arguments -ErrorAction Stop
                }
                Write-JsonResponse -Response $response -Value @{ ok = $true }
                Write-Host "Opened: $filePath"
            } catch {
                Write-JsonResponse -Response $response -Value @{ error = $_.Exception.Message } -StatusCode 400
            }
        }
        elseif ($path -eq '/preview') {
            try {
                $filePath = Get-QueryValue -Query $request.Url.Query -Name 'path'
                if (-not $filePath -or -not (Test-PathWithinRoot -Path $filePath) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    throw "The file is outside the selected folder or no longer exists."
                }
                $contentType = Get-ContentType -Extension ([IO.Path]::GetExtension($filePath))
                $response.ContentType = $contentType
                $response.Headers.Add('X-Content-Type-Options', 'nosniff')
                if ([IO.Path]::GetExtension($filePath).ToLowerInvariant() -ne '.pdf') {
                    $response.Headers.Add('Content-Security-Policy', "default-src 'none'; sandbox")
                }
                $response.Headers.Add('Content-Disposition', 'inline; filename="' + [IO.Path]::GetFileName($filePath).Replace('"', '') + '"')
                $fileStream = [IO.File]::OpenRead($filePath)
                try {
                    $totalLength = $fileStream.Length
                    $rangeHeader = [string]$request.Headers['Range']
                    $rangeMatch = [regex]::Match($rangeHeader, '^bytes=(\d*)-(\d*)$')
                    $start = [long]0
                    $end = $totalLength - 1
                    $validRange = $true
                    if ($rangeMatch.Success) {
                        if (-not $rangeMatch.Groups[1].Value) {
                            $suffixLength = [long]$rangeMatch.Groups[2].Value
                            if ($suffixLength -le 0) { $validRange = $false }
                            else { $start = [Math]::Max(0, $totalLength - $suffixLength) }
                        } else {
                            $start = [long]$rangeMatch.Groups[1].Value
                            if ($rangeMatch.Groups[2].Value) { $end = [long]$rangeMatch.Groups[2].Value }
                        }
                        if ($start -ge $totalLength -or $end -lt $start) {
                            $validRange = $false
                        }
                        if (-not $validRange) {
                            $response.StatusCode = 416
                            $response.Headers.Add('Content-Range', "bytes */$totalLength")
                            $response.ContentLength64 = 0
                        } else {
                            $end = [Math]::Min($end, $totalLength - 1)
                            $response.StatusCode = 206
                            $response.Headers.Add('Content-Range', "bytes $start-$end/$totalLength")
                        }
                    }
                    $response.Headers.Add('Accept-Ranges', 'bytes')
                    if ($validRange) {
                        $response.ContentLength64 = $end - $start + 1
                        $fileStream.Position = $start
                        $buffer = New-Object byte[] 65536
                        $remaining = $response.ContentLength64
                        while ($remaining -gt 0) {
                            $readLength = [int][Math]::Min($buffer.Length, $remaining)
                            $read = $fileStream.Read($buffer, 0, $readLength)
                            if ($read -le 0) { break }
                            $response.OutputStream.Write($buffer, 0, $read)
                            $remaining -= $read
                        }
                    }
                } finally {
                    $fileStream.Dispose()
                    $response.Close()
                }
            } catch {
                Write-Host "Could not preview '$filePath': $($_.Exception.Message)" -ForegroundColor Yellow
                if ($response.OutputStream.CanWrite) {
                    Write-JsonResponse -Response $response -Value @{ error = $_.Exception.Message } -StatusCode 400
                }
            }
        }
        else {
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = 'text/html; charset=utf-8'
            $response.Headers.Add('X-Content-Type-Options', 'nosniff')
            $response.Headers.Add('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src 'self' about:; connect-src 'self'; object-src 'none'; base-uri 'none'")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
        }
        $pending = $listener.BeginGetContext($null, $null)
    }
    $listener.Stop()
    $listener.Close()
    Write-Host "FolderLens browser closed. Local server stopped." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    Write-Host ""
    Read-Host "Press Enter to close"
}
