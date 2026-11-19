# Publish Windows downloads and Store updates

GitHub Releases offers the portable ZIP and the sideload MSIX. Users can run the extracted ZIP with the Evergreen WebView2 Runtime, with no Store account or package registration. The Windows job opens the extracted executable, installs a test copy of the MSIX, and runs Playground in WebView2. [Install on Windows](install-windows.md)

## Reserve the Microsoft Store identity

1. Register the organization as a Windows app developer. In **Apps and games** create a new **MSIX or PWA app** and reserve **JoomEngine** (subject to availability). Open the product, then **Product management → Product identity**. [Register](https://storedeveloper.microsoft.com/) · [Partner Center](https://partner.microsoft.com/dashboard/) · [Product identity fields](https://learn.microsoft.com/en-us/windows/apps/publish/view-app-identity-details)
2. Open **Settings → Secrets and variables → Actions → Variables → New repository variable** in this repository. The Windows build reads the first three values together. Set the product ID now and keep `MICROSOFT_STORE_PUBLISH` unset until the first publication completes. [JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

| Repository variable | Copy from Partner Center |
| --- | --- |
| `MICROSOFT_STORE_PACKAGE_NAME` | Product identity → **Package/Identity/Name**, including the publisher prefix. |
| `MICROSOFT_STORE_PACKAGE_PUBLISHER` | **Package/Identity/Publisher**, including the full `CN=…` value. |
| `MICROSOFT_STORE_PUBLISHER_DISPLAY_NAME` | **Package/Properties/PublisherDisplayName**, exactly as printed. |
| `MICROSOFT_STORE_PRODUCT_ID` | **Store ID**, the product's alphanumeric ID used by `msstore`. |

## Publish the first listing manually

1. Run **Actions → JoomEngine desktop → Run workflow** on `main` after these changes are merged and the identity variables are set. Download **microsoft-store-submission** from the successful run, extract the outer Actions ZIP, and keep the `.msixupload` file intact. If working on a release tag, use the artifact from that version's successful build. [JoomEngine desktop workflow](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml)
2. In Partner Center open the reserved product and **Start your submission**. Upload the `.msixupload` on **Packages**. Enter the listing description, screenshots, support and privacy information, pricing, markets and age ratings. For `runFullTrust`, explain that the package launches JoomEngine's native Win32 executable to host Microsoft Edge WebView2, open its child tool windows and save user-selected files. Provide review instructions to open Playground, load JCB and download a site. Submit for certification and wait for the listing to go live. Microsoft signs packages delivered by the Store. [Upload package](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/upload-app-packages) · [First submission](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/overview)

The direct MSIX uses the project version plus a final zero. Store version numbers require a positive major and reserve the final component. Store packages always use **(project major + 1).minor.patch.0**. For example, project `0.1.0` maps to Store `1.1.0.0` and project `1.0.0` maps to Store `2.0.0.0`. Set the next project version above the first published one when submitting an update. [Microsoft Store version numbering](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering?pivots=store-installer-msix)

## Allow GitHub Actions to submit later versions

1. Link your Microsoft Entra tenant in **Partner Center → Account settings → Tenants**. In **Microsoft Entra → App registrations → New registration**, create a single-tenant application for JoomEngine releases. Under **Partner Center → Account settings → User management → Microsoft Entra applications**, add that registered application and assign the **Manager** role Microsoft specifies for the submission API. [Partner Center](https://partner.microsoft.com/dashboard/) · [Microsoft Entra admin center](https://entra.microsoft.com/) · [Microsoft's setup instructions](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/github-actions)
2. Open **GitHub → Settings → Environments → distribution**. Create the environment if needed, then choose **Add environment secret** for each value below. Configure its deployment tag rule to allow the project's version tags (`v*`). [JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)

| Environment secret in `distribution` | Exact value and location |
| --- | --- |
| `MICROSOFT_STORE_TENANT_ID` | **Directory (tenant) ID** on the Entra app registration's Overview. |
| `MICROSOFT_STORE_CLIENT_ID` | **Application (client) ID** on that same Overview. |
| `MICROSOFT_STORE_CLIENT_SECRET` | **Certificates & secrets → Client secrets → New client secret → Value**. Copy the generated value at creation. Replace this secret in GitHub before its Entra expiration. |
| `MICROSOFT_STORE_SELLER_ID` | **Seller ID** for the Windows developer account under **Partner Center → Account settings → Organization profile → Identifiers**. The per-app Store ID belongs in the repository variable above. |

3. Set the **repository variable** `MICROSOFT_STORE_PUBLISH` to `true`. The next successful version-tag release triggers **Microsoft Store submission** with the Store-specific artifact from the same build. The job verifies the product identity and requires a previous published submission. If a draft or certification is already open, the job stops and preserves it. Finish that submission in Partner Center before retrying a failed job. Check **Apps and games → JoomEngine → Submissions** for certification progress. Microsoft controls approval and availability. [Repository variables](https://github.com/joomengine/joomengine/settings/variables/actions) · [Partner Center](https://partner.microsoft.com/dashboard/)

## Sign GitHub downloads for Windows

The portable ZIP works when the direct-download signing credentials are unset. For standard MSIX installation Windows must trust the signing certificate. Direct distribution and Microsoft Store registration use independent publisher identities. A Store listing does not provide a signing certificate for GitHub downloads. [MSIX signing](https://learn.microsoft.com/en-us/windows/msix/package/sign-app-package-using-signtool) · [Signing options](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)

To obtain the PFX for this workflow, ask the organization's certificate administrator for an exportable code-signing identity trusted by the devices that will install the app. If it is already in **Current User → Personal → Certificates** on Windows, run `certmgr.msc`, choose its **All tasks → Export → Yes, export the private key**, select **Personal Information Exchange (PKCS #12)**, and set the export password. Retain the certificate chain in the export. For publicly trusted signing backed by a non-exportable key, the release team must integrate its signing service. The portable ZIP is available while this is being arranged. [Export a PFX](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/export-certificate-private-key) · [Windows signing options](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)

| GitHub setting | Value and source |
| --- | --- |
| Repository variable `WINDOWS_PUBLISHER` | Full **Subject** of the code-signing certificate used for sideloading. On Windows, read it with `(Get-PfxCertificate -FilePath .\joomengine-signing.pfx).Subject`. It must match the direct MSIX manifest publisher. |
| Repository secret `WINDOWS_PFX_BASE64` | The organization's exportable code-signing PFX, including its private key, encoded as Base64. Supply a certificate trusted by the target devices. |
| Repository secret `WINDOWS_PFX_PASSWORD` | The export password for that PFX. |

For an existing exportable PFX, set its secret from a trusted PowerShell session with the GitHub CLI. Set the password using the repository secret form. Version-tag builds sign and timestamp the EXE and sideload MSIX. [Repository secrets](https://github.com/joomengine/joomengine/settings/secrets/actions) · [Repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\joomengine-signing.pfx))) |
    gh secret set WINDOWS_PFX_BASE64 --repo joomengine/joomengine
```
