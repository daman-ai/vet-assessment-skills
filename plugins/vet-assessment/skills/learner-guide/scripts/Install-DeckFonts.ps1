#requires -Version 5.1
<#
    Install-DeckFonts.ps1

    Puts the deck's two typefaces on the machine: Sawarabi Mincho for titles,
    Questrial for body. Both are free Google Fonts under the OFL.

    WHY THIS IS A PREREQUISITE AND NOT A NICETY

    The delivered deck carries its fonts inside the file so it renders on a
    machine that has never seen them - and PowerPoint does that embedding
    itself, on save, in Add-DeckAnimations. It can only embed a font it has
    INSTALLED. With the fonts missing you get a deck that names two typefaces it
    does not carry, and every heading silently falls back to the body face, so
    the deck loses the serif/sans contrast the whole design rests on. Nothing
    errors. It just quietly comes out wrong.

    Carrying the fonts as .fntdata parts lifted from the template package was
    tried first and does not work for the Mincho: the parts go in, the
    declaration matches the template's byte for byte, and PowerPoint still will
    not bind a large CJK face's embedded copy to Latin text.

    Per-user install - no administrator rights, and removable from
    Settings > Fonts. Idempotent: safe to run on every build.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Fonts = @(
    @{ Family = 'Sawarabi Mincho'; File = 'SawarabiMincho-Regular.ttf'
       Url = 'https://raw.githubusercontent.com/google/fonts/main/ofl/sawarabimincho/SawarabiMincho-Regular.ttf' }
    @{ Family = 'Questrial';       File = 'Questrial-Regular.ttf'
       Url = 'https://raw.githubusercontent.com/google/fonts/main/ofl/questrial/Questrial-Regular.ttf' }
)

Add-Type -AssemblyName System.Drawing
Add-Type -Namespace DeckFont -Name Win -MemberDefinition @'
[DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string p);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
'@

function Test-Installed ([string] $Family) {
    $ifc = New-Object System.Drawing.Text.InstalledFontCollection
    $hit = @($ifc.Families | Where-Object { $_.Name -eq $Family })
    return ($hit.Count -gt 0)
}

$dstDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
$key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

$did = 0
foreach ($f in $Fonts) {
    if ((Test-Installed $f.Family) -and -not $Force) {
        Write-Host ("present  {0}" -f $f.Family); continue
    }
    $dst = Join-Path $dstDir $f.File
    if (-not (Test-Path $dst) -or $Force) {
        Write-Host ("fetching {0} ..." -f $f.Family)
        Invoke-WebRequest -Uri $f.Url -OutFile $dst -UseBasicParsing -TimeoutSec 120
    }
    New-ItemProperty -Path $key -Name ("{0} (TrueType)" -f $f.Family) -Value $dst -PropertyType String -Force | Out-Null
    [void][DeckFont.Win]::AddFontResourceW($dst)
    $r = [IntPtr]::Zero
    [void][DeckFont.Win]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 2000, [ref]$r)
    Write-Host ("installed {0}  ({1:N0} bytes)" -f $f.Family, (Get-Item $dst).Length)
    $did++
}

# Verify in a fresh enumeration. GDI caches the font list per process, so the
# process that registered a font may not see it - check, do not assume.
Start-Sleep -Milliseconds 400
$missing = @()
foreach ($f in $Fonts) { if (-not (Test-Installed $f.Family)) { $missing += $f.Family } }
if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Warning ("not yet visible to GDI: {0}" -f ($missing -join ', '))
    Write-Warning 'Re-run this script in a new PowerShell session before building the deck.'
    exit 1
}
Write-Host ''
Write-Host ("deck fonts ready ({0} installed this run)" -f $did) -ForegroundColor Green
