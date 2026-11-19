# Verify a JoomEngine download

1. Open the [JoomEngine release](https://github.com/joomengine/joomengine/releases) you downloaded from and expand **Assets**.
2. Save its `SHA256SUMS` and your package in a new, empty folder. Keep the original filenames. A checksum identifies the exact bytes of a file, so both downloads must come from the same build.
3. Open a terminal in that folder and use the command for your operating system. A mismatch means the package should be downloaded again before installation.

## Linux

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

Look for your package filename followed by **OK**. Other platforms' assets can stay on GitHub.

## macOS

```sh
for dmg in JoomEngine-*.dmg; do
  awk -v name="$dmg" '$2 == name' SHA256SUMS | shasum -a 256 --check -
done
```

Look for your DMG filename followed by **OK**. An empty match produces an error.

## Windows

With just one JoomEngine Windows ZIP or MSIX in the folder, run this in PowerShell.

```powershell
$files = @(Get-ChildItem -File -Filter 'JoomEngine-*-windows-x64.*')
if ($files.Count -ne 1) { throw 'Put one Windows package in this folder with SHA256SUMS.' }
$file = $files[0]
$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
if ((Get-Content -LiteralPath .\SHA256SUMS -ErrorAction Stop) -cnotcontains "$hash  $($file.Name)") {
    throw "Checksum mismatch or missing entry for $($file.Name)."
}
Write-Output "Verified $($file.Name)"
```

A matching digest confirms that your download matches the project's release manifest. The operating system separately verifies the publisher signature when installing a signed MSIX or opening a Developer ID-signed, notarized Mac distribution.

[All JoomEngine guides](README.md)
