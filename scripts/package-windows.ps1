[CmdletBinding()]
param(
    [string]$Publisher = $env:WINDOWS_PUBLISHER,
    [string]$CertificatePath = $env:WINDOWS_PFX_PATH,
    [string]$CertificatePassword = $env:WINDOWS_PFX_PASSWORD
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Packaging an MSIX requires Windows and the Windows 10 or 11 SDK.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$staged = Join-Path $root 'dist/staged'
if (-not (Test-Path (Join-Path $staged 'JoomEngine.exe') -PathType Leaf)) {
    throw 'The staged Windows application is missing. Run node scripts/stage.mjs first.'
}
$version = (Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw | ConvertFrom-Json).version
if ($version -notmatch '^\d+\.\d+\.\d+$' -or ($version.Split('.') | Where-Object { [int]$_ -gt 65535 })) {
    throw "MSIX needs a numeric major.minor.patch version, with each component at most 65535. Found $version."
}

$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
$sdk = Get-ChildItem -LiteralPath $kits -Directory |
    Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'x64/makeappx.exe')) } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $sdk) { throw 'MakeAppx was not found in the Windows 10 or 11 SDK.' }

$work = New-Item -Type Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString()))
try {
    $payload = Join-Path $work.FullName 'payload'
    Copy-Item -LiteralPath $staged -Destination $payload -Recurse
    $assets = New-Item -ItemType Directory -Path (Join-Path $payload 'Assets') -Force
    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile((Join-Path $root 'assets/joomengine.png'))
    try {
        foreach ($logo in @{ StoreLogo = 50; Tile = 150; AppList = 44 }.GetEnumerator()) {
            $size = $logo.Value
            $bitmap = [Drawing.Bitmap]::new($size, $size)
            try {
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.DrawImage($source, 0, 0, $size, $size)
                } finally { $graphics.Dispose() }
                $bitmap.Save((Join-Path $assets.FullName ($logo.Key + '.png')), [Drawing.Imaging.ImageFormat]::Png)
            } finally { $bitmap.Dispose() }
        }
    } finally { $source.Dispose() }

    [xml]$manifest = Get-Content -LiteralPath (Join-Path $root 'packaging/windows/AppxManifest.xml') -Raw
    $manifest.Package.Identity.SetAttribute('Version', "$version.0")
    if ($Publisher) { $manifest.Package.Identity.SetAttribute('Publisher', $Publisher) }
    $manifest.Save((Join-Path $payload 'AppxManifest.xml'))

    $msix = Join-Path $work.FullName "JoomEngine-$version-windows-x64.msix"
    $makeAppx = Join-Path $sdk.FullName 'x64/makeappx.exe'
    & $makeAppx pack /d $payload /p $msix /h SHA256
    if ($LASTEXITCODE) { throw "MakeAppx pack failed ($LASTEXITCODE)." }

    if ($CertificatePath) {
        $signTool = Join-Path $sdk.FullName 'x64/signtool.exe'
        $signArgs = @('sign', '/fd', 'SHA256', '/tr', 'http://timestamp.digicert.com', '/td', 'SHA256', '/f', $CertificatePath)
        if ($CertificatePassword) { $signArgs += @('/p', $CertificatePassword) }
        & $signTool @signArgs $msix
        if ($LASTEXITCODE) { throw "SignTool sign failed ($LASTEXITCODE). Check WINDOWS_PUBLISHER against the certificate subject." }
        & $signTool verify /pa $msix
        if ($LASTEXITCODE) { throw "SignTool verify failed ($LASTEXITCODE)." }
    } else {
        Write-Host 'Built an unsigned MSIX. Normal Windows installation requires a trusted signature.'
    }

    $packages = New-Item -ItemType Directory -Path (Join-Path $root 'dist/packages') -Force
    Copy-Item -LiteralPath $msix -Destination $packages.FullName -Force
} finally {
    Remove-Item -LiteralPath $work.FullName -Recurse -Force
}
