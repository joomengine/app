$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$upload = Get-Item 'dist/store/*.msixupload'
$unpacked = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
try {
    [IO.Compression.ZipFile]::ExtractToDirectory($upload.FullName, $unpacked)
    $msix = Get-Item (Join-Path $unpacked '*.msix')
    $archive = [IO.Compression.ZipFile]::OpenRead($msix.FullName)
    try {
        $reader = [IO.StreamReader]::new($archive.GetEntry('AppxManifest.xml').Open())
        try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $version = [version](Get-Content VERSION -Raw).Trim()
        $expected = "$($version.Major + 1).$($version.Minor).$($version.Build).0"
        if ($manifest.Package.Identity.Name -cne $env:MICROSOFT_STORE_PACKAGE_NAME -or
            $manifest.Package.Identity.Publisher -cne $env:MICROSOFT_STORE_PACKAGE_PUBLISHER -or
            $manifest.Package.Properties.PublisherDisplayName -cne $env:MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME -or
            $manifest.Package.Identity.Version -cne $expected) {
            throw 'Incorrect Partner Center package identity.'
        }
    } finally { $archive.Dispose() }
} finally {
    if (Test-Path $unpacked) { Remove-Item -LiteralPath $unpacked -Recurse -Force }
}
