# Verify a JoomEngine download

1. Open the [JoomEngine release](https://github.com/joomengine/joomengine/releases) you chose. Download the installer and **SHA-256 checksums** from its download table or **Assets**.
2. Save the installer and `SHA256SUMS` in a new, empty folder. Keep both original filenames. Version tags and previews have separate manifests.
3. Verify the release signature below, then compare the installer with that manifest using the command for [Linux](#linux), [macOS](#macos), or [Windows](#windows). The checksum commands use tools that come with the operating system.

## Verify the signed release downloads

The JoomEngine release workflow signs a GitHub provenance statement covering every uploaded file, including `SHA256SUMS`. The statement identifies the workflow and source commit used to prepare the release. This applies to releases published with attestations enabled.

**Using the GitHub CLI.** Open a terminal in your download folder. Copy the `gh attestation verify SHA256SUMS` command printed on the release page and run it with a current GitHub CLI. The command works in Bash, zsh, and PowerShell and includes the expected repository, signing workflow, source ref, and full commit for that release. For stable releases the source ref is the version tag. For previews it is `refs/heads/main` at the commit shown. If GitHub CLI asks you to authenticate, use `gh auth login`. A successful verification identifies the matching attestation. You can also run the same command with the installer's original filename in place of `SHA256SUMS` to verify that file directly. [GitHub CLI](https://cli.github.com/) · [Verification command reference](https://cli.github.com/manual/gh_attestation_verify)

**Using your browser.** Open **Actions → Attestations** in the JoomEngine repository. Search for your installer's exact filename, open its provenance record, and check the signing workflow (`.github/workflows/desktop.yml`), source ref and commit against the verification command on the release page. Use the operating-system command below to check your local file, then compare the SHA-256 digest in its `SHA256SUMS` entry with the digest in the GitHub record. The browser shows GitHub's hosted record. The CLI performs cryptographic verification against a local file. [JoomEngine attestations](https://github.com/joomengine/joomengine/attestations)

On releases marked **Immutable**, GitHub also signs the release tag, commit and asset list together. You can verify this additional record with GitHub CLI. [Verify an immutable release](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity)

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
