[CmdletBinding()]
param(
    [string]$Publisher = $env:WINDOWS_PUBLISHER,
    [string]$CertificatePath = $env:WINDOWS_PFX_PATH,
    [string]$CertificatePassword = $env:WINDOWS_PFX_PASSWORD,
    [switch]$Store
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Packaging an MSIX requires Windows and the Windows 10 or 11 SDK.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executable = Join-Path $root 'build/Release/JoomEngine.exe'
if (-not (Test-Path $executable -PathType Leaf)) {
    throw 'Build the Release x64 application with CMake before packaging.'
}
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$' -or ($version.Split('.') | Where-Object { [int]$_ -gt 65535 })) {
    throw "MSIX needs a numeric major.minor.patch version, with each component at most 65535. Found $version."
}

if ($Store) {
    foreach ($name in 'MICROSOFT_STORE_PACKAGE_NAME', 'MICROSOFT_STORE_PACKAGE_PUBLISHER', 'MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME') {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw "Store packaging requires the Partner Center identity value $name."
        }
    }
}

$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
$sdk = Get-ChildItem -LiteralPath $kits -Directory |
    Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'x64/makeappx.exe')) } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $sdk) { throw 'MakeAppx was not found in the Windows 10 or 11 SDK.' }

$work = New-Item -Type Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString()))
try {
    $payload = Join-Path $work.FullName 'payload'
    New-Item -ItemType Directory -Path $payload | Out-Null
    Copy-Item -LiteralPath $executable -Destination $payload
    foreach ($notice in 'LICENSE', 'NOTICE', 'LICENSES') {
        Copy-Item -LiteralPath (Join-Path $root $notice) -Destination $payload -Recurse
    }
    if ($CertificatePath -and -not $Store) {
        $signTool = Join-Path $sdk.FullName 'x64/signtool.exe'
        $signArgs = @('sign', '/fd', 'SHA256', '/tr', 'http://timestamp.digicert.com', '/td', 'SHA256', '/f', $CertificatePath)
        if ($CertificatePassword) { $signArgs += @('/p', $CertificatePassword) }
        & $signTool @signArgs (Join-Path $payload 'JoomEngine.exe')
        if ($LASTEXITCODE) { throw "Signing JoomEngine.exe failed ($LASTEXITCODE)." }
    }
    if (-not $Store) {
        $packages = New-Item -ItemType Directory -Path (Join-Path $root 'dist/packages') -Force
        # The portable archive contains the same runtime binary and notices as the MSIX.
        Compress-Archive -Path "$payload/*" -DestinationPath (Join-Path $packages.FullName "JoomEngine-$version-windows-x64.zip") -Force
    }
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
    if ($Store) {
        # Store reserves revision zero and requires a positive first component.
        $storeVersion = [version]$version
        if ($storeVersion.Major -ge 65535) { throw 'The Store major version would exceed 65535.' }
        $manifest.Package.Identity.SetAttribute('Version', "$($storeVersion.Major + 1).$($storeVersion.Minor).$($storeVersion.Build).0")
        $manifest.Package.Identity.SetAttribute('Name', $env:MICROSOFT_STORE_PACKAGE_NAME)
        $manifest.Package.Identity.SetAttribute('Publisher', $env:MICROSOFT_STORE_PACKAGE_PUBLISHER)
        $manifest.Package.Properties.PublisherDisplayName = $env:MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME
    } elseif ($Publisher) {
        $manifest.Package.Identity.SetAttribute('Publisher', $Publisher)
    }
    $manifest.Save((Join-Path $payload 'AppxManifest.xml'))

    $msix = Join-Path $work.FullName "JoomEngine-$version-windows-x64.msix"
    $makeAppx = Join-Path $sdk.FullName 'x64/makeappx.exe'
    & $makeAppx pack /d $payload /p $msix /h SHA256
    if ($LASTEXITCODE) { throw "MakeAppx pack failed ($LASTEXITCODE)." }

    if ($Store) {
        # Partner Center accepts an upload archive containing the unsigned package.
        $storeDirectory = New-Item -ItemType Directory -Path (Join-Path $root 'dist/store') -Force
        $archive = Join-Path $work.FullName 'submission.zip'
        Compress-Archive -LiteralPath $msix -DestinationPath $archive
        Copy-Item -LiteralPath $archive -Destination (Join-Path $storeDirectory.FullName "JoomEngine-$version-x64.msixupload") -Force
        return
    }
    if ($CertificatePath) {
        & $signTool @signArgs $msix
        if ($LASTEXITCODE) { throw "SignTool sign failed ($LASTEXITCODE). Check WINDOWS_PUBLISHER against the certificate subject." }
        & $signTool verify /pa $msix
        if ($LASTEXITCODE) { throw "SignTool verify failed ($LASTEXITCODE)." }
    } else {
        Write-Host 'Built an unsigned MSIX. Normal Windows installation requires a trusted signature.'
    }

    Copy-Item -LiteralPath $msix -Destination $packages.FullName -Force
} finally {
    Remove-Item -LiteralPath $work.FullName -Recurse -Force
}
