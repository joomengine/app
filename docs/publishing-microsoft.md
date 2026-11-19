# Publish Windows downloads and Store updates

GitHub Releases offers the portable ZIP and the sideload MSIX. Users can run the extracted ZIP with the Evergreen WebView2 Runtime, with no Store account or package registration. The Windows job opens the extracted executable, installs a test copy of the MSIX, and runs Playground in WebView2. [Install on Windows](install-windows.md)

## Reserve the Microsoft Store identity

1. Register the organization as a Windows app developer. In **Apps and games** create a new **MSIX or PWA app** and reserve **JoomEngine** (subject to availability). Open the product, then **Product management → Product identity**. [Register](https://storedeveloper.microsoft.com/) · [Partner Center](https://partner.microsoft.com/dashboard/) · [Product identity fields](https://learn.microsoft.com/en-us/windows/apps/publish/view-app-identity-details)
2. Open **Settings → Secrets and variables → Actions → Variables → New repository variable** in the repository's web interface. For each row enter its exact key in **Name**, paste the Partner Center value in **Value**, and click **Add variable**. Use the edit button to update an existing variable. The Windows build reads the first three values together. Set the product ID now and keep `MICROSOFT_STORE_PUBLISH` unset until the first publication completes. [JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

| Repository variable | Copy from Partner Center |
| --- | --- |
| `MICROSOFT_STORE_PACKAGE_NAME` | Product identity → **Package/Identity/Name**, including the publisher prefix. |
| `MICROSOFT_STORE_PACKAGE_PUBLISHER` | **Package/Identity/Publisher**, including the full `CN=…` value. |
| `MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME` | **Package/Properties/PublisherDisplayName**, exactly as printed. |
| `MICROSOFT_STORE_PRODUCT_ID` | **Store ID**, the product's alphanumeric ID used by `msstore`. |

## Publish the first listing manually

1. Run **Actions → JoomEngine desktop → Run workflow** on `main` after these changes are merged and the identity variables are set. After **Publish verified GitHub downloads** succeeds, **Prepare the registered Partner Center package** takes the tested executable from that run’s Windows ZIP and packages it with the three reserved identity fields. Download **microsoft-store-submission** from that run, extract the outer Actions ZIP, and keep the `.msixupload` file intact. If working on a release tag, use the artifact from that version's successful build. [JoomEngine desktop workflow](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml)
2. In Partner Center open the reserved product and **Start your submission**. Upload the `.msixupload` on **Packages**. Enter the listing description, screenshots, support and privacy information, pricing, markets and age ratings. For `runFullTrust`, explain that the package launches JoomEngine's native Win32 executable to host Microsoft Edge WebView2, open its child tool windows and save user-selected files. Provide review instructions to open Playground, load JCB and download a site. Submit for certification and wait for the listing to go live. Microsoft signs packages delivered by the Store. [Upload package](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/upload-app-packages) · [First submission](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/overview)

The direct MSIX uses the project version plus a final zero. Store version numbers require a positive major and reserve the final component. Store packages always use **(project major + 1).minor.patch.0**. For example, project `0.1.0` maps to Store `1.1.0.0` and project `1.0.0` maps to Store `2.0.0.0`. Set the next project version above the first published one when submitting an update. [Microsoft Store version numbering](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering?pivots=store-installer-msix)

## Allow GitHub Actions to submit later versions

1. Link your Microsoft Entra tenant in **Partner Center → Account settings → Tenants**. In **Microsoft Entra → App registrations → New registration**, create a single-tenant application for JoomEngine releases. Under **Partner Center → Account settings → User management → Microsoft Entra applications**, add that registered application and assign the **Manager** role Microsoft specifies for the submission API. [Partner Center](https://partner.microsoft.com/dashboard/) · [Microsoft Entra admin center](https://entra.microsoft.com/) · [Microsoft's setup instructions](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/github-actions)
2. Open **GitHub → Settings → Environments → distribution**. If it is missing, choose **New environment**, enter `distribution`, then choose **Configure environment**. If you restrict deployments, under **Deployment branches and tags** allow version tags matching `v*`. Under **Environment secrets** click **Add secret** for each row, enter the exact **Name**, paste the credential into the value box, and click **Add secret**. To rotate a value, use the edit button next to that environment secret. [JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)

| Environment secret in `distribution` | Exact value and location |
| --- | --- |
| `MICROSOFT_STORE_TENANT_ID` | **Directory (tenant) ID** on the Entra app registration's Overview. |
| `MICROSOFT_STORE_CLIENT_ID` | **Application (client) ID** on that same Overview. |
| `MICROSOFT_STORE_CLIENT_SECRET` | **Certificates & secrets → Client secrets → New client secret → Value**. Copy the generated value at creation. Replace this secret in GitHub before its Entra expiration. |
| `MICROSOFT_STORE_SELLER_ID` | **Seller ID** for the Windows developer account under **Partner Center → Account settings → Organization profile → Identifiers**. The per-app Store ID belongs in the repository variable above. |

3. Open **Settings → Secrets and variables → Actions → Variables → New repository variable**. Enter `MICROSOFT_STORE_PUBLISH` in **Name**, enter `true` in **Value**, and click **Add variable**. The next successful version-tag release triggers **Microsoft Store submission** with the Store-specific artifact from the same build. The job verifies the product identity and requires a previous published submission. If a draft or certification is already open, the job stops and preserves it. Finish that submission in Partner Center before retrying a failed job. Check **Apps and games → JoomEngine → Submissions** for certification progress. If Partner Center setup or submission fails, the direct Windows ZIP and MSIX are already published on GitHub. Microsoft controls certification and Store availability. [Repository variables](https://github.com/joomengine/joomengine/settings/variables/actions) · [Partner Center](https://partner.microsoft.com/dashboard/)

## Sign GitHub downloads for Windows

The portable ZIP works when the direct-download signing credentials are unset. For standard MSIX installation Windows must trust the signing certificate. Direct distribution and Microsoft Store registration use independent publisher identities. A Store listing does not provide a signing certificate for GitHub downloads. [MSIX signing](https://learn.microsoft.com/en-us/windows/msix/package/sign-app-package-using-signtool) · [Signing options](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)

To obtain the PFX for this workflow, ask the organization's certificate administrator for an exportable code-signing identity trusted by the devices that will install the app. If it is already in **Current User → Personal → Certificates** on Windows, run `certmgr.msc`, choose its **All tasks → Export → Yes, export the private key**, select **Personal Information Exchange (PKCS #12)**, and set the export password. Retain the certificate chain in the export. For publicly trusted signing backed by a non-exportable key, the release team must integrate its signing service. The portable ZIP is available while this is being arranged. [Export a PFX](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/export-certificate-private-key) · [Windows signing options](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)

Use these three entries for the GitHub download signer. The Windows build reads these at repository scope, independently from the Partner Center submission credentials in the `distribution` environment.

| Where to enter it in the browser | Name | Value to copy |
| --- | --- | --- |
| **Settings → Secrets and variables → Actions → Variables → New repository variable** | `WINDOWS_PUBLISHER` | Full **Subject** from the code-signing certificate in the exported PFX. Use the first clipboard command below to preserve the exact distinguished name. Paste it into **Value** and choose **Add variable**. |
| **Settings → Secrets and variables → Actions → Secrets → New repository secret** | `WINDOWS_PFX_BASE64` | The complete PFX including its private key, encoded using the second clipboard command below. Paste into **Secret** and choose **Add secret**. |
| **Settings → Secrets and variables → Actions → Secrets → New repository secret** | `WINDOWS_PFX_PASSWORD` | The password set in the Windows certificate export wizard. Paste into **Secret** and choose **Add secret**. |

Open PowerShell in the directory where you saved `joomengine-signing.pfx` on the trusted Windows computer. Run the first command, enter the PFX password locally if prompted, and paste the clipboard into the `WINDOWS_PUBLISHER` variable on GitHub. [Open JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

```powershell
(Get-PfxCertificate -FilePath .\joomengine-signing.pfx).Subject | Set-Clipboard
```

Then run the following command to copy the encoded PFX without displaying its contents. Paste directly into the `WINDOWS_PFX_BASE64` secret. After saving it, clear the clipboard with `Set-Clipboard -Value ''`. Add the password as its own secret. Version-tag builds use these settings to sign and timestamp the executable and the sideload MSIX. [Open JoomEngine repository secrets](https://github.com/joomengine/joomengine/settings/secrets/actions)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\joomengine-signing.pfx))) | Set-Clipboard
```

## Configure GitHub Actions from PowerShell

The following commands are an alternative to entering settings in GitHub's web forms. Complete the relevant certificate export, Partner Center registration and Microsoft Entra steps above. Use an interactive PowerShell window with an authenticated GitHub CLI. Confirm the active account with `gh auth status --hostname github.com`. Keep the window open across the steps you use. [GitHub CLI setup](publishing.md#github-cli-setup)

### Sign the direct downloads

From the folder containing the exported `joomengine-signing.pfx`, run the block below. Supply the export password if Windows prompts while reading the certificate, then enter it at the GitHub CLI's hidden prompt for `WINDOWS_PFX_PASSWORD`. The only value passed as a visible command argument is the public certificate subject.

```powershell
$ErrorActionPreference = 'Stop'
$repo = 'joomengine/joomengine'
$pfxPath = (Resolve-Path -LiteralPath .\joomengine-signing.pfx).Path
$subject = (Get-PfxCertificate -FilePath $pfxPath).Subject
if (-not $subject) { throw 'The PFX has no certificate subject.' }
gh variable set WINDOWS_PUBLISHER --repo $repo --body $subject
if ($LASTEXITCODE) { throw 'Could not save the direct-download publisher.' }
[Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath)) |
    gh secret set WINDOWS_PFX_BASE64 --repo $repo
if ($LASTEXITCODE) { throw 'Could not save the encoded PFX.' }
gh secret set WINDOWS_PFX_PASSWORD --repo $repo
if ($LASTEXITCODE) { throw 'Could not save the PFX password.' }
gh secret list --repo $repo --json name --jq '.[].name'
```

### Prepare the first Microsoft Store submission

Set the four public repository variables for the reserved Partner Center product. Paste each value from the **Product identity** page at its prompt. Keep `MICROSOFT_STORE_PUBLISH` unset during this first publication.

```powershell
$repo = 'joomengine/joomengine'
foreach ($name in 'MICROSOFT_STORE_PACKAGE_NAME', 'MICROSOFT_STORE_PACKAGE_PUBLISHER',
                  'MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME', 'MICROSOFT_STORE_PRODUCT_ID') {
    $value = Read-Host "Partner Center value for $name"
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing $name." }
    gh variable set $name --repo $repo --body $value
    if ($LASTEXITCODE) { throw "Could not save $name." }
}
gh workflow run desktop.yml --repo $repo --ref main
if ($LASTEXITCODE) { throw 'Could not start the Windows package build.' }
```

Once the run appears, list the recent builds below and enter the numeric ID for the run you just started. The CLI waits for it to finish and downloads the file into a run-specific folder. Upload its `.msixupload` to Partner Center and complete the first publication there as described above.

```powershell
gh run list --repo $repo --workflow desktop.yml --event workflow_dispatch --branch main --limit 10
$runId = Read-Host 'Run ID from the build list'
if ($runId -notmatch '^\d+$') { throw 'Enter a numeric run ID.' }
gh run watch $runId --repo $repo --exit-status
if ($LASTEXITCODE) { throw 'The selected build did not succeed.' }
gh run download $runId --repo $repo --name microsoft-store-submission --dir "store-submission-$runId"
if ($LASTEXITCODE) { throw 'Could not download the Store submission.' }
```

### Enable automated Store updates

After the first listing is live, ensure the `distribution` environment exists. This PowerShell check creates it only when it is absent and preserves existing protection rules. A repository administrator can configure the deployment tag policy in the common setup guide. [GitHub CLI setup](publishing.md#github-cli-setup)

```powershell
$repo = 'joomengine/joomengine'
$environments = @(gh api --paginate "repos/$repo/environments" --jq '.environments[].name')
if ($LASTEXITCODE) { throw 'Could not list deployment environments.' }
if ($environments -notcontains 'distribution') {
    gh api --method PUT "repos/$repo/environments/distribution" --silent
    if ($LASTEXITCODE) { throw 'Could not create the distribution environment.' }
}
foreach ($name in 'MICROSOFT_STORE_TENANT_ID', 'MICROSOFT_STORE_CLIENT_ID',
                  'MICROSOFT_STORE_CLIENT_SECRET', 'MICROSOFT_STORE_SELLER_ID') {
    Write-Host "Enter $name"
    gh secret set $name --repo $repo --env distribution
    if ($LASTEXITCODE) { throw "Could not save $name in distribution." }
}
gh variable set MICROSOFT_STORE_PUBLISH --repo $repo --body true
if ($LASTEXITCODE) { throw 'Could not enable Store publishing.' }
gh secret list --repo $repo --env distribution --json name --jq '.[].name'
gh variable list --repo $repo --json name --jq '.[].name'
```

Paste each Entra or Partner Center value from the **Environment secret** table at its hidden prompt. The next successful version-tag release uses the saved settings to submit the Store update.
