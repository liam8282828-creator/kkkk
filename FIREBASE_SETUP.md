# Moon Place – Firebase Authentication

Moon Place now uses **Firebase Authentication** (email/password) as its primary
backend. It talks to Firebase through the Identity Toolkit REST API, so **no
Firebase SDK package is needed** and the GitHub Actions build stays
dependency-free.

If Firebase is not configured, the app automatically falls back to the Supabase
backend (see `SUPABASE_SETUP.md`).

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and create a project.
2. **Project settings → General → Web API Key** — copy it.
3. **Build → Authentication → Get started → Email/Password → Enable → Save**.

## 2. Put the key in the app

Open `ThreeOneOSFive/helpers/FirebaseAuthenticationClient.swift` and replace the
placeholder in `FirebaseConfiguration.moonPlace`:

```swift
static let moonPlace = FirebaseConfiguration(
    apiKey: "YOUR_FIREBASE_API_KEY",   // <- paste your Web API Key here
    syntheticEmailDomain: "moonexternal.app"
)
```

`FirebaseAuthenticationClient.isConfigured` becomes `true` once a real key is
set; until then the app uses Supabase.

## 3. How accounts work

- The login screen asks for username / password / key. Firebase only supports
  email + password, so the username maps to the synthetic email
  `user@moonexternal.app`. The license `key` is accepted but Firebase does not
  validate it (license validation only happens with the Supabase backend).
- ID and refresh tokens are stored in the **Keychain**; the display profile is
  stored in **UserDefaults**. Sessions restore automatically on launch, and the
  refresh token is rotated through `securetoken.googleapis.com`.

## 4. Error messages

Firebase raw codes are translated to friendly text (`EMAIL_EXISTS`,
`INVALID_LOGIN_CREDENTIALS`, `WEAK_PASSWORD`, `OPERATION_NOT_ALLOWED`, ...).
Transport errors (TLS, DNS, no Internet, timeout) are reported with the failing
host, mirroring the Supabase client.
