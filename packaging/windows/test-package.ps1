[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackagePath)
$ErrorActionPreference = 'Stop'

# Windows only deploys trusted packages. Sign a temporary copy on the disposable CI
# runner when a release certificate is unavailable. Only the original is published.
$cert = $null
$installed = $null
$copy = Join-Path $env:RUNNER_TEMP "joomengine-ci-$([Guid]::NewGuid()).msix"
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $signed = $null -ne $archive.GetEntry('AppxSignature.p7x')
        $reader = [IO.StreamReader]::new($archive.GetEntry('AppxManifest.xml').Open())
        try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $archive.Dispose() }

    if (Get-AppxPackage -Name $manifest.Package.Identity.Name) {
        throw 'Run this installer test on a clean machine with no existing JoomEngine package.'
    }

    if (-not $signed) {
        Copy-Item -LiteralPath $PackagePath -Destination $copy
        $PackagePath = $copy
        $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $manifest.Package.Identity.Publisher `
            -CertStoreLocation 'Cert:\CurrentUser\My' -KeyUsage DigitalSignature
        $store = [Security.Cryptography.X509Certificates.X509Store]::new('TrustedPeople', 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            $publicKey = [Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
            $store.Add($publicKey)
        } finally { $store.Close() }

        $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
        $tool = Get-ChildItem -LiteralPath $kits -Filter signtool.exe -Recurse |
            Where-Object { $_.Directory.Name -eq 'x64' -and $_.Directory.Parent.Name -match '^10\.0\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Directory.Parent.Name } -Descending | Select-Object -First 1
        if (-not $tool) { throw 'SignTool is required to test the unsigned package.' }
        & $tool.FullName sign /fd SHA256 /s My /sha1 $cert.Thumbprint $PackagePath
        if ($LASTEXITCODE) { throw "Failed to sign the CI package copy ($LASTEXITCODE)." }
    }

    Add-AppxPackage -Path $PackagePath
    $installed = Get-AppxPackage -Name $manifest.Package.Identity.Name -Publisher $manifest.Package.Identity.Publisher
    if (-not $installed) { throw 'The installed JoomEngine package could not be located.' }
    $executable = Join-Path $installed.InstallLocation $manifest.Package.Applications.Application.Executable
    & node (Join-Path $PSScriptRoot '../../test/smoke.cjs') $executable
    if ($LASTEXITCODE) { throw "Packaged application smoke test failed ($LASTEXITCODE)." }
} finally {
    if ($installed) { Remove-AppxPackage -Package $installed.PackageFullName }
    if ($cert) {
        Remove-Item "Cert:\LocalMachine\TrustedPeople\$($cert.Thumbprint)" -ErrorAction SilentlyContinue
        Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -DeleteKey -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $copy) { Remove-Item -LiteralPath $copy -Force }
}
