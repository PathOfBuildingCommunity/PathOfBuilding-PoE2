# Security

This document explains how the macOS port of Path of Building (PoE2) handles
your data — in particular, **how signing in with your Path of Exile account
works** — so you can decide for yourself whether it is safe to run.

The short version: this app talks to **Grinding Gear Games' official servers
and nobody else**. It has no telemetry, no analytics, no "phone home", and the
maintainer of this port never sees your account, your tokens, or your builds.

Everything described below is implemented in open source you can read:
- `src/Classes/PoEAPI.lua` — the OAuth client and PoE API calls
- `src/LaunchServer.lua` — the temporary local redirect server
- `macos/src/Host.mm` — the native networking (libcurl) layer

## What this app is

This is an **unofficial, community-built native macOS port** of
[Path of Building Community (PoE2)](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2).
The calculation engine, data, and UI are unchanged from upstream; only the
Windows-only rendering/host runtime was replaced with a native macOS host. The
account/OAuth logic is the same logic used by upstream Path of Building.

## A note on the unsigned app and Gatekeeper

This app is **not signed or notarized by Apple** (that requires a paid Apple
Developer account). As a result, macOS Gatekeeper will warn you on first launch.
This is expected and does **not** mean the app is malicious — it only means
Apple has not been paid to vouch for it.

Because it is unsigned, **you are trusting this binary**. If you would rather not
take that on faith, you have two options that don't require trusting anyone:

1. **Build it yourself** from this repository — see [docs/macos.md](docs/macos.md).
   Two commands produce the exact same `.app`.
2. **Verify the download.** Each release publishes a `…zip.sha256` checksum file
   next to the zip. With both files in the same folder, run:

   ```bash
   shasum -a 256 -c PathOfBuilding-PoE2-macos-arm64.zip.sha256
   ```

   It should print `…zip: OK`. (Or compare manually with
   `shasum -a 256 PathOfBuilding-PoE2-macos-arm64.zip`.)

To open the unsigned app:

```bash
# After moving it to /Applications, clear the quarantine flag:
xattr -dr com.apple.quarantine "/Applications/Path of Building (PoE2).app"
```

…or right‑click the app and choose **Open** the first time.

## How Path of Exile sign-in works

Signing in is **optional**. It is only used to import your characters directly
from your PoE account. You can use the entire build planner without ever signing
in. When you do sign in, the app uses the standard, secure OAuth 2.0 flow that
GGG provides for desktop applications:

1. **PKCE (Proof Key for Code Exchange).** The app generates a random
   `code_verifier` and sends only its SHA‑256 hash (`code_challenge`, method
   `S256`) to PoE. The secret verifier never leaves your machine until the final
   token exchange. This means an intercepted authorization code is useless to an
   attacker. *(`PoEAPI.lua`)*

2. **No client secret.** The app uses the official public client id `pob`. There
   is no embedded secret to steal.

3. **You log in on pathofexile.com, not in this app.** The app opens
   `https://www.pathofexile.com/oauth/authorize` in **your browser**. You type
   your credentials into GGG's website — this app never sees your username or
   password.

4. **A temporary localhost redirect server.** To receive the result of the login,
   the app starts a tiny HTTP server bound to **`localhost` only** (never exposed
   to your network) on one of ports `49082`–`49084`. It accepts only `GET`
   requests, handles a single OAuth redirect, and **shuts down automatically
   after at most 30 seconds**. *(`LaunchServer.lua`)*

5. **Anti-forgery `state` check.** A random `state` value is generated for each
   login and verified when the browser redirects back. If it doesn't match, the
   login is rejected. *(`PoEAPI.lua`)*

6. **Limited, read-only scopes.** The app requests only:
   `account:profile`, `account:leagues`, `account:characters`,
   `account:trade`. These let it read your character list and use trade search.
   It cannot change anything on your account.

## Where your tokens are stored

After login, GGG returns an **access token** and a **refresh token**. These are
stored **locally on your Mac**, in:

```
~/Library/Application Support/Path of Building (PoE2)/Settings.xml
```

Be aware of the following, in the interest of full disclosure:

- The tokens are stored **in plaintext** as XML attributes (`lastToken`,
  `lastRefreshToken`). They are **not** encrypted and are **not** stored in the
  macOS Keychain. This matches upstream Path of Building's behavior.
- The file is protected by normal macOS file permissions (readable by your user
  account). Any process running as your user could read it.
- The tokens are **only ever sent back to `pathofexile.com`** to authenticate
  your API requests. They are never transmitted anywhere else.

To **sign out and erase your tokens**, use the "Manage" / log-out option in the
Import tab, which clears these values and re-saves settings. You can also delete
`Settings.xml` (or just remove those attributes) at any time.

## Network connections this app makes

This app makes outbound HTTPS connections **only** to Grinding Gear Games and
Path of Building Community resources, specifically:

- `https://www.pathofexile.com` — OAuth login and token exchange
- `https://api.pathofexile.com` — your character data and trade API
- Path of Building Community / GitHub endpoints for game data and updates that
  exist in upstream

All requests go through libcurl with **TLS certificate verification enabled**
(`CURLOPT_SSL_VERIFYPEER` / `CURLOPT_SSL_VERIFYHOST`). *(`macos/src/Host.mm`)*

There is:
- **No telemetry or analytics.**
- **No data sent to the maintainer of this port** or any third party.
- **No background auto-update** on macOS — updates are manual, by downloading a
  new release. (Auto-update is disabled in this port.)

## What this means for you

- Your PoE password is **never** seen by this app — you enter it on GGG's site.
- Your tokens **never leave your machine** except to talk to GGG.
- The only meaningful local risk is the **plaintext token storage** described
  above. If your Mac is shared or compromised, sign out to clear the tokens.
- If you don't sign in, the app makes no account-related connections at all.

## Reporting a vulnerability

If you find a security issue in this **macOS port** (the `macos/` host, the
build/packaging scripts, or the OAuth integration as ported here), please report
it privately rather than opening a public issue:

- Open a [GitHub Security Advisory](../../security/advisories/new) on this
  repository, **or**
- Open a regular issue that contains **no exploit details**, asking a maintainer
  to make contact.

Please allow a reasonable amount of time for a fix before any public disclosure.

Vulnerabilities in the **upstream calculation engine, data, or shared Lua**
should be reported to the
[Path of Building Community project](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2),
since that code is shared and not specific to this port.
