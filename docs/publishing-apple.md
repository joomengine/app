# Publish macOS downloads

The macOS release consists of two DMGs for GitHub Releases, one for Apple silicon and one for Intel. A **Developer ID Application** certificate signs the app and its embedded Qt renderer. Apple's notary service checks each disk image, then the workflow staples and validates its ticket. Users can open the downloaded DMG and drag JoomEngine to Applications. [Apple Developer ID distribution](https://developer.apple.com/developer-id/) · [How to install on macOS](install-macos.md)

## Mac App Store eligibility

Qt documents that its embedded Chromium uses private macOS APIs and that the required App Sandbox interferes with Chromium's sandbox initialization. The current desktop app is therefore ineligible for Mac App Store distribution. Apple account credentials enable signing and notarization for GitHub downloads. A future Mac App Store edition would need a compatible browser implementation and separate Playground qualification before App Review. [Qt WebEngine platform notes](https://doc.qt.io/qt-6.11/qtwebengine-platform-notes.html#mac-app-store-compatibility) · [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Enroll and create the signing identity

1. Enroll the organization in the Apple Developer Program and accept the current agreements. An Account Holder creates the Developer ID certificate. [Enroll](https://developer.apple.com/programs/enroll/) · [Apple Developer account](https://developer.apple.com/account/)
2. On the Mac that will hold the private key, open **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**. Enter the email address and common name, select **Saved to disk**, and save the certificate signing request. In the developer portal choose **Certificates → + → Developer ID Application**, upload the request, download the certificate and open it on the same Mac. [Certificates portal](https://developer.apple.com/account/resources/certificates/list) · [Apple's certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
3. Open **Keychain Access → My Certificates**, locate the Developer ID Application identity with its private key, and export it as the password-protected file `DeveloperID.p12`. Record the password you set. Copy the certificate’s full name as displayed in **My Certificates**, including **Developer ID Application**, the organization name and the parenthesized team identifier. This full name selects the signing identity.
4. Sign in with the Apple Account used for notarization. Under **Sign-In and Security → App-Specific Passwords**, generate a password for JoomEngine notarization. The Team ID is under **Membership details** in the developer account. [Apple Account](https://account.apple.com/) · [App-specific passwords](https://support.apple.com/en-us/102654) · [Membership](https://developer.apple.com/account/)

## Configure GitHub Actions in the browser

Open the repository's **Settings → Secrets and variables → Actions → Secrets** tab in your browser. For each row below, click **New repository secret**, put the exact name from the left column in **Name**, paste the value into **Secret**, and click **Add secret**. If the name already exists, use its edit button and **Update secret**. Both macOS builds use these repository secrets on a version-tag push. [Open JoomEngine repository secrets](https://github.com/joomengine/joomengine/settings/secrets/actions)

| Name | What to paste into Secret |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | Base64 text containing the complete exported `DeveloperID.p12`, including the private key. Use the local clipboard step below. |
| `APPLE_CERTIFICATE_PASSWORD` | The password you chose when exporting that P12 from Keychain Access. |
| `APPLE_SIGNING_IDENTITY` | The complete **Developer ID Application** certificate name copied from **Keychain Access → My Certificates** in step 3. |
| `APPLE_ID` | The email address of the Apple Account signed in when generating the notarization password. |
| `APPLE_TEAM_ID` | The ten-character **Team ID** shown under **Membership details** in the Apple Developer account. |
| `APPLE_APP_SPECIFIC_PASSWORD` | The password Apple displayed when you created the JoomEngine entry under **Sign-In and Security → App-Specific Passwords**. |

To prepare `APPLE_CERTIFICATE_BASE64` on the Mac, open Terminal in the folder containing the exported file and run the command below. It puts the encoded certificate on the clipboard without displaying it. Paste it directly into GitHub's **Secret** field, click **Add secret**, then clear the clipboard with `pbcopy < /dev/null`.

```sh
base64 -i DeveloperID.p12 | pbcopy
```

## Configure GitHub Actions with the CLI

Use the same certificate, password, identity, Apple Account, team and app-specific password from the enrollment steps above. Sign in with a GitHub account that can manage the repository's Actions secrets. [GitHub CLI setup](publishing.md#github-cli-setup)

In an interactive Terminal on the Mac, change to the directory containing `DeveloperID.p12` and run this block. The encoded certificate goes directly to GitHub CLI through standard input. For each remaining name, paste its value at the hidden prompt and press Return.

```sh
(
  set -eu
  set -o pipefail
  repo=joomengine/joomengine
  test -s DeveloperID.p12
  base64 -i DeveloperID.p12 | gh secret set APPLE_CERTIFICATE_BASE64 --repo "$repo"
  for name in APPLE_CERTIFICATE_PASSWORD APPLE_SIGNING_IDENTITY APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
    printf 'Enter %s\n' "$name"
    gh secret set "$name" --repo "$repo"
  done
  gh secret list --repo "$repo" --json name --jq '.[].name'
)
```

## Verify the release

With all six values present, the version-tag build imports the identity into a temporary keychain, signs the nested frameworks and helpers, submits both final DMGs using `notarytool`, and verifies the stapled tickets. The checksum manifest covers the final stapled files. Development and unconfigured builds have ad hoc signatures. To verify a production download locally, run the following from the directory containing one downloaded DMG. [Notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

```sh
xcrun stapler validate JoomEngine-*-macos-*.dmg
```
