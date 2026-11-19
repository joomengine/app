# Publish macOS downloads

The macOS release consists of two DMGs for GitHub Releases, one for Apple silicon and one for Intel. A **Developer ID Application** certificate signs the app and its embedded Qt renderer. Apple's notary service checks each disk image, then the workflow staples and validates its ticket. Users can open the downloaded DMG and drag JoomEngine to Applications. [Apple Developer ID distribution](https://developer.apple.com/developer-id/) · [How to install on macOS](install-macos.md)

## Mac App Store eligibility

Qt documents that its embedded Chromium uses private macOS APIs and that the required App Sandbox interferes with Chromium's sandbox initialization. The current desktop app is therefore ineligible for Mac App Store distribution. Apple account credentials enable signing and notarization for GitHub downloads. A future Mac App Store edition would need a compatible browser implementation and separate Playground qualification before App Review. [Qt WebEngine platform notes](https://doc.qt.io/qt-6.11/qtwebengine-platform-notes.html#mac-app-store-compatibility) · [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Enroll and create the signing identity

1. Enroll the organization in the Apple Developer Program and accept the current agreements. An Account Holder creates the Developer ID certificate. [Enroll](https://developer.apple.com/programs/enroll/) · [Apple Developer account](https://developer.apple.com/account/)
2. On the Mac that will hold the private key, open **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**. Enter the email address and common name, select **Saved to disk**, and save the certificate signing request. In the developer portal choose **Certificates → + → Developer ID Application**, upload the request, download the certificate and open it on the same Mac. [Certificates portal](https://developer.apple.com/account/resources/certificates/list) · [Apple's certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
3. Open **Keychain Access → My Certificates**, locate the Developer ID Application identity with its private key, and export it as the password-protected file `DeveloperID.p12`. Record that export password. Run `security find-identity -v -p codesigning` to find the identity's 40-character hexadecimal fingerprint.
4. Sign in with the Apple Account used for notarization. Under **Sign-In and Security → App-Specific Passwords**, generate a password for JoomEngine notarization. The Team ID is under **Membership details** in the developer account. [Apple Account](https://account.apple.com/) · [App-specific passwords](https://support.apple.com/en-us/102654) · [Membership](https://developer.apple.com/account/)

## Configure GitHub Actions

Open **Settings → Secrets and variables → Actions → Secrets → New repository secret**. These secrets are read by the reusable macOS build job only when a version tag is pushed. The same values serve both DMGs. [JoomEngine repository secrets](https://github.com/joomengine/joomengine/settings/secrets/actions)

| Repository secret | Exact value |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | On the Mac run `base64 -i DeveloperID.p12 \| pbcopy` and paste the clipboard into the secret. This value contains the private key. |
| `APPLE_CERTIFICATE_PASSWORD` | Password set when exporting that same P12 file. |
| `APPLE_SIGNING_IDENTITY` | Fingerprint from `security find-identity -v -p codesigning` for that Developer ID Application identity. |
| `APPLE_ID` | Apple Account email address that generated the app-specific password. |
| `APPLE_TEAM_ID` | The organization's ten-character Apple Developer Team ID. |
| `APPLE_APP_SPECIFIC_PASSWORD` | The generated app-specific password for the Apple Account above. |

To provision the certificate secret directly from the certificate file on a trusted Mac with the GitHub CLI, use the following command.

```sh
base64 -i DeveloperID.p12 | gh secret set APPLE_CERTIFICATE_BASE64 --repo joomengine/joomengine
```

With all six values present, the version-tag build imports the identity into a temporary keychain, signs the nested frameworks and helpers, submits both final DMGs using `notarytool`, and verifies the stapled tickets. The checksum manifest covers the final stapled files. Development and unconfigured builds have ad hoc signatures. To verify a production download locally, run the following from the directory containing one downloaded DMG. [Notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

```sh
xcrun stapler validate JoomEngine-*-macos-*.dmg
```
