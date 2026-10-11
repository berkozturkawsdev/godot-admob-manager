# Godot Remote Configuration, AdMob & Game Center

Reusable configuration and monetization setup for **Godot 4.6.x**, **iOS**, and **Poing Studios Godot AdMob Plugin 5.1.0**. The app downloads per-game settings from GitHub Pages **before entering the game**. AdMob starts only after the remote configuration loads successfully.

## Features

- Startup screen built entirely from code, with configurable title, destination scene, colors, and remote JSON URL in the Inspector.
- Internet-required startup: failed network request displays **No internet connection** and a **Retry** button; HTTP/server/JSON errors display their own messages.
- Remotely configurable AdMob enablement, interstitials, rewarded ads, ad frequency, minimum interval, retry delay, expiration, test mode, and iOS ad unit IDs.
- Google UMP consent, privacy options, automatic loading, ad expiration, and diagnostics.
- Remote Game Center enablement and leaderboard ID, consumed by your separate Game Center manager.
- No `.tres` configuration resource required.

## 1. Requirements

- Godot 4.6.x and iOS export support.
- [Poing Studios Godot AdMob Plugin](https://github.com/poing-studios/godot-admob-plugin) 5.1.0 and its native iOS dependencies.
- An AdMob App ID configured in the native iOS build and ad unit IDs for production ads.
- Game Center plugin and entitlement configured in the native iOS build **if** using leaderboards.
- A publicly accessible HTTPS JSON file, such as one hosted by GitHub Pages.

## 2. Project structure

```text
res://
├── ads/
│   ├── admob_config.gd
│   ├── admob_manager.gd
│   ├── remote_config.gd
│   ├── startup_screen.gd
│   └── startup_screen.tscn
├── game_center/
│   └── game_center_manager.gd  # Your existing manager; integration required
└── scenes/
    └── main.tscn
```

The startup `.tscn` contains only the root node; `startup_screen.gd` creates the UI programmatically.

### `res://ads/startup_screen.tscn`

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ads/startup_screen.gd" id="1_script"]

[node name="StartupScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")
```

## 3. Autoload and main scene

In **Project → Project Settings → Globals → Autoload**, add in this order:

| Order | Path | Name |
|---|---|---|
| 1 | `res://ads/remote_config.gd` | `RemoteConfig` |
| 2 | `res://ads/admob_manager.gd` | `AdMobManager` |

Configure your Game Center manager separately if it is also an Autoload. It must wait until `RemoteConfig.is_loaded` before using remote leaderboard settings.

Set **Project → Project Settings → Application → Run → Main Scene** to `res://ads/startup_screen.tscn`.

> Autoload order alone does **not** mean the HTTP download has finished. `AdMobManager` must wait for `RemoteConfig.config_loaded` before requesting consent or initializing/loading ads.

## 4. Configure the startup scene in the Inspector

Open `res://ads/startup_screen.tscn`, select `StartupScreen`, and set the exported properties:

| Property | Example | Purpose |
|---|---|---|
| Game Title | `Spin Frenzy` | Displayed while loading |
| Next Scene | `res://scenes/main.tscn` | Opened after valid JSON loads |
| Remote Config URL | `https://bozapps.com/config/spin-frenzy.json` | HTTPS endpoint to download |
| Background Color | `#100b2a` | Startup background |
| Text Color | `#ffffff` | Labels |
| Accent Color | `#ffb379` | Retry button |

`RemoteConfig` does not fetch automatically in `_ready()`; `StartupScreen` calls `RemoteConfig.load_config(remote_config_url)`.

### Startup sequence

```text
App launch
  → StartupScreen
  → RemoteConfig.load_config(URL)
     ├─ Valid HTTP 200 + JSON with "ads" object
     │    → config_loaded
     │    → AdMobManager starts consent / SDK initialization
     │    → StartupScreen opens Next Scene
     └─ Failure
          → config_failed(message)
          → StartupScreen shows error and Retry
          → Game scene remains blocked until retry succeeds
```

A failed network request shows **No internet connection**, but that is a user-facing message rather than proof the device is offline: DNS, TLS, hosting, and timeout errors can also cause a failure. Non-200 HTTP responses show **Configuration server unavailable**; malformed JSON shows **Invalid game configuration**.

**This is intentionally online-only startup.** If GitHub Pages is unavailable, the game cannot start even when the device has internet access. No offline cache is used in the current implementation.

## 5. Host configuration on GitHub Pages

Create a public file such as `config/spin-frenzy.json` in your GitHub Pages repository. It will be accessible at a URL such as:

`https://bozapps.com/config/spin-frenzy.json`

Example full configuration:

```json
{
  "version": 1,
  "ads": {
    "enabled": true,
    "enable_interstitial": true,
    "enable_rewarded": false,
    "game_overs_per_ad": 3,
    "minimum_seconds_between_ads": 90,
    "retry_delay_seconds": 60,
    "ad_expiration_seconds": 3300,
    "use_test_ads": true,
    "ios_interstitial_id": "ca-app-pub-1234567890123456/1111111111",
    "ios_rewarded_id": "ca-app-pub-1234567890123456/2222222222"
  },
  "game_center": {
    "enabled": true,
    "leaderboard_id": "spin_frenzy_high_score"
  }
}
```

Replace the sample ad unit IDs with your real IDs. The `game_center.leaderboard_id` must exactly match a leaderboard configured for the app in App Store Connect.

After editing the JSON, commit and publish the changes. They are applied on the next successful startup download (subject to GitHub Pages/CDN caching). You do **not** need a new App Store build for these supported settings.

### Suggested per-game files

```text
config/
├── spin-frenzy.json
├── fruit-wobble.json
├── sealide.json
└── hop-up.json
```

Each game's startup scene uses its own URL. The native AdMob App ID and Game Center entitlement remain build-specific.

## 6. Remote JSON setting reference

### `ads`

| Key | Type | Description |
|---|---|---|
| `enabled` | boolean | Master switch for AdMob |
| `enable_interstitial` | boolean | Allow interstitial loading and display |
| `enable_rewarded` | boolean | Allow rewarded loading and display |
| `game_overs_per_ad` | integer | Number of final game overs before attempting an interstitial; minimum 1 |
| `minimum_seconds_between_ads` | number | Minimum seconds between successfully shown interstitials |
| `retry_delay_seconds` | number | Delay before retrying failed loads |
| `ad_expiration_seconds` | number | Age at which a cached ad is replaced |
| `use_test_ads` | boolean | Select Google demo ad units when `true` |
| `ios_interstitial_id` | string | Production interstitial unit ID when test mode is `false` |
| `ios_rewarded_id` | string | Production rewarded unit ID when test mode is `false` |

### `game_center`

| Key | Type | Description |
|---|---|---|
| `enabled` | boolean | Whether your Game Center integration should operate |
| `leaderboard_id` | string | Existing leaderboard identifier used for submissions and display |

The current `RemoteConfig` loader checks that the response is a JSON object containing an `ads` object. It does **not** yet enforce every setting's type, allowed range, or leaderboard validity. Add schema validation before relying on untrusted remote values in production.

## 7. Local defaults: `admob_config.gd`

The manager reads remote settings through `RemoteConfig.get_ad_setting(key, fallback)`. `AdMobConfig` holds fallback values:

```gdscript
class_name AdMobConfig
extends RefCounted

const ENABLED: bool = true
const USE_TEST_ADS: bool = true
const ENABLE_INTERSTITIAL: bool = true
const ENABLE_REWARDED: bool = true

const IOS_INTERSTITIAL_ID: String = ""
const IOS_REWARDED_ID: String = ""

const GAME_OVERS_PER_AD: int = 3
const MINIMUM_SECONDS_BETWEEN_ADS: float = 60.0
const RETRY_DELAY_SECONDS: float = 60.0
const AD_EXPIRATION_SECONDS: float = 3300.0
const CONSENT_RETRY_SECONDS: float = 60.0
```

Fallbacks apply when a **key is missing from an otherwise successfully loaded JSON**. They do **not** bypass the startup requirement: if downloading or parsing the JSON fails, the startup screen remains blocked.

## 8. AdMob App ID, ad units, and test mode

An AdMob **App ID** (example `ca-app-pub-1234567890123456~1234567890`) is configured in the native iOS project/export. It cannot be changed using remote JSON.

Ad **unit IDs** use `/`, for example `ca-app-pub-1234567890123456/1111111111`, and can be changed through the JSON.

When `use_test_ads` is `true`, the manager selects Google's demonstration IDs regardless of the production IDs in JSON:

| Format | Google demo unit ID |
|---|---|
| Interstitial | `ca-app-pub-3940256099942544/4411468910` |
| Rewarded | `ca-app-pub-3940256099942544/1712485313` |

When `use_test_ads` is `false`, the manager selects `ios_interstitial_id` and `ios_rewarded_id` from the JSON.

**Release warning:** The current manager permits `use_test_ads` to be changed remotely even in release builds. Keep this `false` for production monetization. A safer production implementation should lock test mode at build time and register development devices for test ads. TestFlight does not automatically determine which ad unit IDs the manager uses.

## 9. Interstitial usage

Call only after a run is **finally** over, not before the player has chosen whether to revive:

```gdscript
func finalize_game_over() -> void:
    AdMobManager.game_over()
```

The remote `game_overs_per_ad` value controls the attempt threshold. The counter resets when the SDK reports a successful interstitial presentation, and is not persisted between app launches.

Manual display:

```gdscript
if AdMobManager.can_show_interstitial():
    AdMobManager.show_interstitial()
```

`show_interstitial()` returns whether a presentation was initiated, not confirmation that the ad was actually displayed.

## 10. Rewarded usage

Only show rewarded ads after the player chooses to watch one. Grant the reward **only** on `reward_earned`:

```gdscript
func _ready() -> void:
    AdMobManager.reward_earned.connect(_on_reward_earned)

func _on_revive_pressed() -> void:
    if AdMobManager.can_show_rewarded():
        AdMobManager.show_rewarded()

func _on_reward_earned() -> void:
    revive_player()  # Implement in your gameplay script
```

If `enable_rewarded` is `false`, `can_show_rewarded()` returns `false` and the manager does not load rewarded ads.

## 11. Game Center leaderboard integration

`RemoteConfig` can expose these convenience getters. Add them to `remote_config.gd` if they are not already present:

```gdscript
func is_game_center_enabled() -> bool:
    return bool(get_setting("game_center", "enabled", false))

func get_leaderboard_id() -> String:
    return str(get_setting("game_center", "leaderboard_id", "")).strip_edges()
```

In your **existing** `game_center_manager.gd`, replace any hardcoded leaderboard identifier used for score submission and display with:

```gdscript
var leaderboard_id: String = RemoteConfig.get_leaderboard_id()
```

Example of a guard around your existing Game Center submission API:

```gdscript
func submit_score(score: int) -> void:
    if not RemoteConfig.is_loaded:
        return
    if not RemoteConfig.is_game_center_enabled():
        return

    var leaderboard_id := RemoteConfig.get_leaderboard_id()
    if leaderboard_id.is_empty():
        push_warning("Game Center leaderboard ID is missing")
        return

    # Call your installed Game Center plugin's actual submit API
    # with leaderboard_id and score here.
```

**Integration status:** This is a configuration contract and usage example, **not** a full Game Center plugin implementation. Your Game Center manager must explicitly consume these getters and wait for remote config. Changing JSON cannot create a leaderboard, move historical scores, add native entitlements, or install a plugin. Leaderboards must already exist in App Store Connect for the app.

## 12. RemoteConfig API

| Member | Purpose |
|---|---|
| `load_config(url: String)` | Download configuration from the startup scene's URL |
| `config_loaded` | Signal emitted after valid JSON is accepted |
| `config_failed(message: String)` | Signal emitted on network/server/JSON failure |
| `is_loaded` | Whether valid config is available |
| `is_loading` | Whether a request is in progress |
| `error_message` | Latest failure reason |
| `current_url` | URL used for the request |
| `get_setting(section, key, default)` | Read a setting from any section |
| `get_ad_setting(key, default)` | Read from the `ads` section |
| `is_game_center_enabled()` | Optional helper; add as shown above |
| `get_leaderboard_id()` | Optional helper; add as shown above |

Example:

```gdscript
var frequency: int = int(RemoteConfig.get_ad_setting(
    "game_overs_per_ad", AdMobConfig.GAME_OVERS_PER_AD
))
```

## 13. AdMobManager API and signals

| Method | Purpose |
|---|---|
| `game_over()` | Increment game-over counter and attempt interstitial at threshold |
| `can_show_interstitial()` | Check interstitial eligibility |
| `show_interstitial()` | Attempt to present interstitial |
| `can_show_rewarded()` | Check rewarded eligibility |
| `show_rewarded()` | Attempt to present rewarded ad |
| `privacy_options_required()` | Check UMP privacy options requirement |
| `show_privacy_options()` | Display UMP privacy options form |
| `diagnostics()` | Return status information |

Signals: `status_changed`, `presentation_changed`, `interstitial_loaded`, `rewarded_loaded`, `interstitial_closed`, `rewarded_closed`, `reward_earned`, and `ad_failed(ad_type, message)`.

Example:

```gdscript
func _ready() -> void:
    AdMobManager.rewarded_loaded.connect(_update_revive_button)
    AdMobManager.rewarded_closed.connect(_update_revive_button)
    AdMobManager.presentation_changed.connect(_update_revive_button)
    _update_revive_button()

func _update_revive_button() -> void:
    $ReviveButton.disabled = not AdMobManager.can_show_rewarded()
```

## 14. Consent, privacy, loading, and diagnostics

The AdMob manager waits for remote configuration, then requests Google UMP consent information, presents a form when required, initializes the Mobile Ads SDK, and loads enabled ads. Configure your consent messages in **AdMob → Privacy & messaging**.

```gdscript
if AdMobManager.privacy_options_required():
    AdMobManager.show_privacy_options()

print(AdMobManager.diagnostics())
```

Ads are automatically reloaded after use. Failed loads are retried after the configured delay; cached ads are replaced after the configured expiration. Consent and native ad callbacks should be verified against the installed Poing Studios 5.1.0 plugin on a physical iOS device.

## 15. Troubleshooting

| Symptom | Check |
|---|---|
| No internet connection | Device connection, DNS, TLS, request timeout, and GitHub Pages reachability |
| Configuration server unavailable | URL path, GitHub Pages publishing, HTTP response code |
| Invalid game configuration | JSON syntax and top-level object |
| Missing ads configuration | JSON contains an `ads` object |
| Game does not open | `next_scene` is set and the JSON request succeeded |
| AdMob does not initialize | Remote config loaded, `ads.enabled`, iOS platform, native plugin, UMP consent |
| Rewarded unavailable | `enable_rewarded`, ad unit, SDK readiness, ad fill |
| Demo ads appear | Remote `use_test_ads` and registered test devices |
| Leaderboard not submitting | Remote Game Center enabled, correct ID, authentication, entitlement, and actual manager integration |
| AdMob account not approved | AdMob account/app approval status |

## 16. Release checklist

- [ ] GitHub Pages JSON URL opens publicly over HTTPS.
- [ ] Startup screen has correct Game Title, Next Scene, and Remote Config URL.
- [ ] Startup handles success, offline/network errors, HTTP errors, invalid JSON, and Retry.
- [ ] `RemoteConfig` Autoload precedes `AdMobManager`.
- [ ] AdMob waits for remote config and consent before loading ads.
- [ ] Production AdMob App ID is embedded in the iOS build.
- [ ] JSON contains the correct production ad unit IDs.
- [ ] `use_test_ads` is `false` for production monetization.
- [ ] Remote ad settings are validated and tested on a physical device.
- [ ] UMP consent messages and privacy options work.
- [ ] Rewarded ads only grant rewards after reward confirmation.
- [ ] Interstitials do not interrupt revive decisions.
- [ ] Game Center entitlement and plugin are present if needed.
- [ ] Leaderboard exists in App Store Connect and its ID matches JSON.
- [ ] Game Center manager actually reads remote settings for submission and display.
- [ ] App behavior complies with App Store review and applicable privacy requirements.

## 17. Known limitations and next improvements

- **Online-only startup:** A GitHub Pages outage can block play. There is no last-known-good offline cache.
- **Basic JSON validation:** The current loader validates the top-level dictionary and `ads` object, but not every field type or value range.
- **Remote test-mode safety:** Production builds currently accept remote `use_test_ads`; consider locking it off for releases.
- **Game Center integration:** Requires updating your existing manager; JSON getters alone do not submit scores.
- **Native lifecycle:** Validate AdMob loader cleanup, UMP callback behavior, reward ordering, retry behavior, and background/foreground transitions with Poing Studios 5.1.0.
- **No live push:** JSON changes are applied at the next successful configuration download, normally app startup. GitHub Pages caching may delay propagation.

## References

- [Poing Studios Godot AdMob Plugin](https://github.com/poing-studios/godot-admob-plugin)
- [Google AdMob](https://admob.google.com/)
- [Google Mobile Ads SDK for iOS](https://developers.google.com/admob/ios/quick-start)
- [Google UMP](https://developers.google.com/admob/ios/privacy)
- [Google Test Ads](https://developers.google.com/admob/ios/test-ads)

---

**Target:** Godot 4.6.x · iOS · Poing Studios AdMob Plugin 5.1.0  
**Architecture:** RemoteConfig + reusable StartupScreen + AdMobManager + separate Game Center manager; one JSON per game; no `.tres` file.
