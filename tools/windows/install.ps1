param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\After Silence'),
    [string]$StartMenu = ([Environment]::GetFolderPath('Programs'))
)

$ErrorActionPreference = 'Stop'
$sourceGame = Join-Path $PSScriptRoot 'AfterSilence.exe'
$sourceLicenses = Join-Path $PSScriptRoot 'Licenses'
if (-not (Test-Path -LiteralPath $sourceGame -PathType Leaf) -or
    -not (Test-Path -LiteralPath $sourceLicenses -PathType Container)) {
    throw 'Extract all files from the ZIP before running Install-AfterSilence.cmd.'
}

$destination = (New-Item -ItemType Directory -Path $InstallDir -Force).FullName
if ($destination -ne $PSScriptRoot) {
    Copy-Item -LiteralPath $sourceGame, (Join-Path $PSScriptRoot 'README_RU.md') -Destination $destination -Force
    Copy-Item -LiteralPath $sourceLicenses -Destination $destination -Recurse -Force
}

New-Item -ItemType Directory -Path $StartMenu -Force | Out-Null
# Use the Unicode Shell Link interface for Windows profiles with non-ASCII names.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class AfterSilenceShortcut {
    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellLinkW {
        void GetPath(IntPtr path, int size, IntPtr data, uint flags);
        void GetIDList(out IntPtr idList);
        void SetIDList(IntPtr idList);
        void GetDescription(IntPtr text, int size);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string text);
        void GetWorkingDirectory(IntPtr path, int size);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string path);
        void GetArguments(IntPtr arguments, int size);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string arguments);
        void GetHotkey(out short hotkey);
        void SetHotkey(short hotkey);
        void GetShowCmd(out int command);
        void SetShowCmd(int command);
        void GetIconLocation(IntPtr path, int size, out int index);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int index);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string path, uint flags);
        void Resolve(IntPtr window, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string path);
    }

    public static void Save(string link, string target, string directory) {
        Type type = Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046"));
        object instance = Activator.CreateInstance(type);
        try {
            var shortcut = (IShellLinkW)instance;
            shortcut.SetPath(target);
            shortcut.SetWorkingDirectory(directory);
            ((IPersistFile)instance).Save(link, true);
        } finally {
            Marshal.FinalReleaseComObject(instance);
        }
    }
}
"@
[AfterSilenceShortcut]::Save(
    (Join-Path $StartMenu 'After Silence.lnk'),
    (Join-Path $destination 'AfterSilence.exe'),
    $destination
)
Write-Host "After Silence is installed in $destination. Open it from Start."
