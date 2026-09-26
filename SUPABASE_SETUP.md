# Supabase setup

## 1. Create the project

Create a project at https://supabase.com and copy:

- Project URL
- Publishable/anon key

Put them in `SupabaseConfiguration.moonPlace` in `ThreeOneOSFive/helpers/KeyAuthConfiguration.swift`.

Never put the `service_role` key in Swift, GitHub, or the IPA.

## 2. Create the database

Open Supabase SQL Editor and run `supabase/schema.sql`.

It creates `profiles` and `licenses`, enables RLS, and creates this test license:

```text
MOON-TEST-2026
```

## 3. Deploy the function

Install the Supabase CLI, log in, link the project, and run:

```text
supabase functions deploy moon-auth --no-verify-jwt
```

The function uses the built-in Supabase secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Do not copy those secrets into the repository.

## 4. Test the IPA key login

Run the updated `supabase/schema.sql` and deploy the updated `moon-auth` function. The script adds device binding and failed-attempt rate limiting, then refreshes the test license for 30 days.

In the IPA, paste this key and tap **INGRESAR**:

```text
MOON-TEST-2026
```

The first successful login binds this test key to that device. A different device will be rejected. The app asks for the key again on the next launch.

## 5. Optional username/password flow

Register with:

```text
Username: moon
Password: moon123
License: MOON-TEST-2026
Phone: 5551234567
```

Then log in with the same username, password, and license. The function rejects expired, inactive, already-claimed, and unknown licenses.

## 6. Verify the response

A successful request returns HTTP 200 with a Supabase access token and expiration data. The app keeps the access and refresh tokens in Keychain and the profile in UserDefaults, restoring the session automatically on the next launch (refreshing the access token when needed). HTTP 400 means invalid input, 401 means account/login failure, 403 means license failure, and 409 means the username or license is already used.

## 7. Troubleshooting: "A TLS error caused the connection to fail"

This error means the device could not complete the secure connection to your Supabase host. Check, in order:

1. **Project URL** — it must be exactly `https://<project-ref>.supabase.co` (from Project Settings → API → Project URL). No trailing slash, no extra path, no `http://`, and no typo. Do **not** use the dashboard URL (`supabase.com/dashboard/project/...`).
2. **Anon key** — copy the **anon / publishable** key (never `service_role`) from Project Settings → API and remove any surrounding quotes or spaces.
3. **Device date/time** — TLS certificate validation fails when the clock is wrong. Enable automatic date/time.
4. **Network** — try Wi-Fi and then cellular. Corporate Wi-Fi, VPNs, antivirus, or carrier proxies that intercept TLS produce this error.
5. **Endpoint reachability** — on the device open these in Safari:
   - `https://<project-ref>.supabase.co/functions/v1/moon-auth` (expects an API error, not a TLS warning), and
   - `https://<project-ref>.supabase.co/auth/v1/token?grant_type=refresh_token` (expects an error, not a TLS warning).
   If Safari shows a certificate warning, your Supabase URL/ref is wrong or the network is intercepting TLS.
6. **Function deployed** — without the deployed `moon-auth` function the app may show connection errors; redeploy with `supabase functions deploy moon-auth --no-verify-jwt`.

The app also writes the failing host and the underlying connection error code to the built-in Log view, so the next build with those credentials will name the exact host that failed.
