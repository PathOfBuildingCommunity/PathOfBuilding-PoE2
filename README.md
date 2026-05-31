# Path of Building 2 Community
## Welcome to Path of Building 2, an offline build planner for Path of Exile 2!

<p float="middle">
  <img alt="Tree tab" src="https://github.com/user-attachments/assets/225bf25f-1ac4-4639-b280-565a24d2a2fc" width="48%" />
  <img alt="Items tab" src="https://github.com/user-attachments/assets/de8e6dc0-1e1a-46c5-b8a4-18877e67d48d" width="48%" />
</p>

## Download
Head over to the [Releases](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/releases) page to download the install wizard or portable zip.

## Features
* Comprehensive offence + defence calculations:
  * Calculate your skill DPS, damage over time, life/mana/ES totals and much more!
  * Can factor in auras, buffs, charges, curses, monster resistances and more, to estimate your effective DPS
  * Also calculates life/mana reservations
  * Shows a summary of character stats in the side bar, as well as a detailed calculations breakdown tab which can show you how the stats were derived
  * Supports all skills and support gems, and most passives and item modifiers
    * Throughout the program, supported modifiers will show in blue and unsupported ones in red
  * Full support for minions
  * Support for party play and support builds
* Passive skill tree planner:
  * Support for jewels including most radius/conversion and timeless jewels
  * Features alternate path tracing (mouse over a sequence of nodes while holding shift, then click to allocate them all)
  * Fully integrated with the offence/defence calculations; see exactly how each node will affect your character!
  * Can import PathOfExile.com and PoEPlanner.com passive tree links; links shortened with PoEURL.com also work
* Skill planner:
  * Add any number of main or supporting skills to your build
  * Supporting skills (auras, curses, buffs) can be toggled on and off
  * Automatically applies Socketed Gem modifiers from the item a skill is socketed into
  * Automatically applies support gems granted by items
* Item planner:
  * Add items from in game by copying and pasting them straight into the program!
  * Automatically adds quality to non-corrupted items
  * Search the trade site for the most impactful items
  * Fully integrated with the offence/defence calculations; see exactly how much of an upgrade a given item is!
  * Contains a searchable database of all uniques that are currently in game (and some that aren't yet!)
    * You can choose the modifier rolls when you add a unique to your build
    * Includes all league-specific items and legacy variants
  * Features an item crafting system:
    * You can select from any of the game's base item types
    * You can select prefix/suffix modifiers from lists
    * Custom modifiers can be added, with Master and Essence modifiers available
  * Also contains a database of rare item templates:
    * Allows you to create rare items for your build to approximate the gear you will be using
    * Choose which modifiers appear on each item, and the rolls for each modifier, to suit your needs
    * Has templates that should cover the majority of builds
* Other features:
  * You can import passive tree, items, and skills from existing characters
  * Share builds with other users by generating a share code
  * Automatic updating; most updates will only take a couple of seconds to apply

## Running Tests

The test suite uses [Busted](https://lunarmodules.github.io/busted/) with LuaJIT and runs inside a pre-built Docker/Podman image.

### Prerequisites

You need either **Docker** or **Podman** installed and available in your PATH. No other local dependencies are required — the test image bundles LuaJIT, Busted, and LuaCov.

### Run all tests

**With Docker:**
```bash
docker run --rm \
  -e HOME=/tmp \
  -v "$(pwd)":/workdir:ro \
  -w /workdir \
  ghcr.io/pathofbuildingcommunity/pathofbuilding-tests:latest \
  busted --lua=luajit
```

**With Podman:**
```bash
podman run --rm \
  -e HOME=/tmp \
  -v "$(pwd)":/workdir:ro \
  -w /workdir \
  ghcr.io/pathofbuildingcommunity/pathofbuilding-tests:latest \
  busted --lua=luajit
```

**With Docker Compose** (if `docker compose` v2 is available):
```bash
docker compose run --rm busted-tests
```

### Run a subset of tests

Pass a `--tags` filter to scope which tests run:

```bash
# Build snapshot tests (slow)
... busted --lua=luajit --tags builds

# Data file validation only
... busted --lua=luajit --tags data
```

### Run with coverage

```bash
... busted --lua=luajit --coverage
```

Coverage output is written to `luacov.report.out`. Compare against `main` to ensure coverage does not drop.

### Test layout

| Path | Purpose |
|------|---------|
| `spec/System/` | Busted test suite (all `*_spec.lua` files) |
| `src/HeadlessWrapper.lua` | Test bootstrap / headless PoB initialiser |
| `.busted` | Busted configuration (working dir, helper, Lua path) |
| `docker-compose.yml` | Convenience wrapper for the test container |
| `Dockerfile` | Definition of the test image |

### Notes

- Tests must pass before opening a PR: `370 successes` is the baseline on `dev`.
- The two known failures in `TestWard_spec.lua` are in-progress work (Ward regen/bypass not yet implemented).
- Numeric calculation tests assert specific stat values within ±0.01 tolerance.

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Contribute
You can find instructions on how to contribute code and bug reports [here](CONTRIBUTING.md).

## Licence
[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md).
The licencing information is considered to be part of the documentation.

## AI Workflow Escape Hatches

The automated PR workflow (AI fix → AI review → auto-merge) can be controlled as follows:

**Disable AI workflows temporarily**
- Go to Actions → select the workflow → "..." menu → Disable workflow

**Manually trigger an AI review on an existing PR**
```bash
gh workflow run ai-review.yml --repo jay9297/PathOfBuilding-PoE2
```

**Override an AI review with a manual one**
- Simply post your own review comment on the PR — your approval is always required before merge regardless of the AI review verdict.

**Rotate the `CLAUDE_CODE_OAUTH_TOKEN`**
```bash
# On your local machine (claude must be logged in via Pro):
claude setup-token
# Then update the secret:
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo jay9297/SinsGuide
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo jay9297/PathOfBuilding-PoE2
```

**Rotate the `OPENCODE_API_KEY`**
```bash
# Get new key from https://opencode.ai console, then:
gh secret set OPENCODE_API_KEY --repo jay9297/SinsGuide
gh secret set OPENCODE_API_KEY --repo jay9297/PathOfBuilding-PoE2
```

**Skip AI fix on an issue**
- Do not add the `ai-fix` label. The workflow only triggers on that label.
