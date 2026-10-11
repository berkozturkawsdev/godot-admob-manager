# Godot AdMob Manager

Reusable AdMob integration for Godot 4.x mobile games using the Poing Studios Godot AdMob Plugin.

Supports:

- Interstitial ads
- Rewarded ads
- Automatic game-over ad frequency
- Google UMP consent management
- Privacy options
- Automatic ad loading and retries
- Ad expiration
- Test and production ad units
- Diagnostic messages and signals

The manager is independent of game-specific systems such as player controllers, save files, and leaderboards.

## 1. Requirements

| Requirement | Details |
|---|---|
| Godot | 4.6.x |
| AdMob Plugin | Poing Studios Godot AdMob Plugin 5.1.0 |
| Platform | iOS |
| AdMob Account | Required for production ads |
| Apple Developer Account | Required for TestFlight/App Store distribution |

### Required plugin

**Poing Studios Godot AdMob Plugin**

https://github.com/poing-studios/godot-admob-plugin

Install the plugin and its native iOS dependencies following the repository's installation instructions.

The manager uses classes provided by this plugin, including `MobileAds`, `InterstitialAd`, `RewardedAd`, and `UserMessagingPlatform`.

The native iOS plugin must be included in the exported application.

## 2. Project Structure

```text
res://
├── addons/
│   └── ... AdMob plugin files
├── scripts/
│   └── ads/
│       ├── admob_config.gd
│       └── admob_manager.gd
└── project.godot
```

Only two custom scripts are required.

**No `ads.tres` file is needed.**

## 3. Installation

### Step 1 — Install the AdMob plugin

Install the Poing Studios plugin and configure the native iOS export dependencies.

Verify the plugin is enabled in the iOS export preset.

### Step 2 — Add the scripts

Copy the following files into `res://scripts/ads/`:

- `admob_config.gd`
- `admob_manager.gd`

### Step 3 — Configure the Autoload

Open:

**Project → Project Settings → Globals → Autoload**

Add:

```text
Path: res://scripts/ads/admob_manager.gd
Name: AdMobManager
Enabled: Yes
```

The manager will initialize automatically when the application starts.

### Step 4 — Configure AdMob

Open `admob_config.gd`.

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

Change these constants separately for each game.

## 4. AdMob App ID and Ad Unit IDs

In Google AdMob, create an iOS application and configure its App ID in your iOS export/plugin settings.

Example App ID:

```text
ca-app-pub-1234567890123456~1234567890
```

Create separate ad units for interstitial and rewarded advertisements.

Example configuration:

```gdscript
const IOS_INTERSTITIAL_ID: String = "ca-app-pub-1234567890123456/1111111111"
const IOS_REWARDED_ID: String = "ca-app-pub-1234567890123456/2222222222"
```

The App ID uses `~`, while ad unit IDs use `/`.

Do not confuse them.

## 5. Test Ads and Production Ads

### Development

```gdscript
const USE_TEST_ADS: bool = true
```

The manager uses Google's official demonstration ad units.

| Ad Type | Test Ad Unit |
|---|---|
| Interstitial | `ca-app-pub-3940256099942544/4411468910` |
| Rewarded | `ca-app-pub-3940256099942544/1712485313` |

### Production

```gdscript
const USE_TEST_ADS: bool = false
```

The manager uses the configured production ad unit IDs.

TestFlight does not automatically change the configuration. You must choose the appropriate setting for each build.

When testing your own production ad units, register your device as an AdMob test device to avoid invalid traffic.

## 6. Interstitial Ads

Interstitial ads are full-screen advertisements displayed between gameplay sessions.

### Automatic game-over ads

Call:

```gdscript
func _on_game_over() -> void:
    AdMobManager.game_over()
```

Configure the frequency:

```gdscript
const GAME_OVERS_PER_AD: int = 3
```

Example behavior:

| Game Over | Result |
|---|---|
| 1 | No ad |
| 2 | No ad |
| 3 | Attempt interstitial |
| After successful presentation | Counter resets |

If an ad is unavailable, the counter remains at its threshold so another eligible game-over event can attempt presentation.

The counter is stored in memory and resets when the app restarts.

### Manual interstitial

```gdscript
func show_ad() -> void:
    if AdMobManager.can_show_interstitial():
        AdMobManager.show_interstitial()
```

`show_interstitial()` returns `true` when presentation is initiated, not when the SDK confirms the ad was displayed.

### Minimum interval

```gdscript
const MINIMUM_SECONDS_BETWEEN_ADS: float = 60.0
```

Prevents another interstitial from being shown too soon after the previous successful presentation.

### Games with revive functionality

If your game offers a rewarded revive, do not call `game_over()` before the player makes their revive decision.

Recommended flow:

```text
Player dies
    ↓
Show Game Over / Revive UI
    ↓
Player chooses revive?
    ├── Yes → Request rewarded ad
    │          ├── Reward earned → Revive player
    │          └── No reward → Remain on Game Over
    │
    └── No → Finalize game over
               ↓
          AdMobManager.game_over()
```

This prevents an interstitial from interrupting a rewarded-ad opportunity.

## 7. Rewarded Ads

Rewarded ads should only be shown after the player voluntarily requests them.

### Example: Revive player

```gdscript
extends Node

func _ready() -> void:
    AdMobManager.reward_earned.connect(
        _on_reward_earned
    )


func _on_revive_pressed() -> void:
    if not AdMobManager.can_show_rewarded():
        print("Rewarded ad unavailable")
        return

    AdMobManager.show_rewarded()


func _on_reward_earned() -> void:
    revive_player()


func revive_player() -> void:
    print("Player revived!")
```

The manager emits `reward_earned` when the SDK confirms the reward.

Do not grant rewards simply because the advertisement opened or closed.

### Example: Bonus coins

```gdscript
var pending_reward: String = ""


func _ready() -> void:
    AdMobManager.reward_earned.connect(
        _on_reward_earned
    )


func _on_double_coins_pressed() -> void:
    if not AdMobManager.can_show_rewarded():
        return

    pending_reward = "double_coins"

    if not AdMobManager.show_rewarded():
        pending_reward = ""


func _on_reward_earned() -> void:
    if pending_reward == "double_coins":
        give_bonus_coins()

    pending_reward = ""
```

For multiple reward types, keep the selected reward in your gameplay system rather than the AdMob manager.

For production, associate each rewarded request with the current run or reward transaction to prevent stale rewards from being applied to another run.

## 8. Available Methods

| Method | Description |
|---|---|
| `game_over()` | Counts game overs and attempts an interstitial |
| `show_interstitial()` | Attempts to show an interstitial |
| `can_show_interstitial()` | Checks interstitial eligibility |
| `show_rewarded()` | Attempts to show a rewarded ad |
| `can_show_rewarded()` | Checks rewarded ad eligibility |
| `privacy_options_required()` | Checks whether privacy options are required |
| `show_privacy_options()` | Opens the privacy options form |
| `diagnostics()` | Returns AdMob status information |

## 9. Signals

| Signal | Description |
|---|---|
| `status_changed` | AdMob status changed |
| `presentation_changed` | Full-screen presentation state changed |
| `interstitial_loaded` | Interstitial loaded successfully |
| `rewarded_loaded` | Rewarded ad loaded successfully |
| `interstitial_closed` | Interstitial presentation finished |
| `rewarded_closed` | Rewarded presentation finished |
| `reward_earned` | Reward confirmed by SDK |
| `ad_failed(ad_type, message)` | Ad loading, consent, or presentation error |

### Example: Update a revive button

```gdscript
func _ready() -> void:
    AdMobManager.rewarded_loaded.connect(
        _update_revive_button
    )

    AdMobManager.rewarded_closed.connect(
        _update_revive_button
    )

    AdMobManager.presentation_changed.connect(
        _update_revive_button
    )

    _update_revive_button()


func _update_revive_button() -> void:
    $ReviveButton.disabled = not (
        AdMobManager.can_show_rewarded()
    )
```

### Example: Display ad status

```gdscript
func _ready() -> void:
    AdMobManager.status_changed.connect(
        _update_status
    )

    _update_status()


func _update_status() -> void:
    $StatusLabel.text = AdMobManager.status_text
```

## 10. Consent and Privacy

The manager uses Google User Messaging Platform (UMP) to handle consent.

During initialization, it:

1. Requests updated consent information.
2. Loads a consent form when required.
3. Displays the form to the user.
4. Checks whether consent permits ad requests.
5. Initializes the Mobile Ads SDK.
6. Loads enabled advertisements.

Consent forms must be configured in your AdMob account.

Open **AdMob → Privacy & messaging** and configure the applicable consent messages.

### Privacy options

Check whether privacy options are required:

```gdscript
func _ready() -> void:
    $PrivacyButton.visible = (
        AdMobManager.privacy_options_required()
    )
```

Because consent information updates asynchronously, refresh this visibility after consent initialization rather than relying solely on `_ready()`.

To open privacy options:

```gdscript
func _on_privacy_pressed() -> void:
    AdMobManager.show_privacy_options()
```

The manager must not bypass required consent.

The supplied implementation uses `get_consent_status()` to determine whether requests are allowed. Confirm that this matches the consent behavior required by your installed plugin and Google UMP version.

## 11. Diagnostics and Debugging

Display diagnostics:

```gdscript
print(AdMobManager.diagnostics())
```

Or:

```gdscript
$DiagnosticsLabel.text = AdMobManager.diagnostics()
```

Example output:

```text
AdMob diagnostics
Test ads: true
Interstitial ready: true
Rewarded ready: false
Game overs: 2 / 3
Status: Interstitial ready
Last error: None
```

This is useful when debugging TestFlight builds without direct access to Xcode.

### Common errors

| Error | Possible Cause |
|---|---|
| Account is not approved yet | AdMob account approval incomplete |
| No forms configured | Missing or unpublished UMP consent message |
| No fill | No eligible advertising inventory |
| Invalid ad unit | Incorrect App ID or ad unit ID |
| Plugin missing | Native iOS plugin not included |
| Ads always show demo creatives | Test ads enabled or device registered for testing |

Ad failures should not prevent normal gameplay.

## 12. Automatic Loading and Expiration

Ads are loaded automatically after SDK initialization.

After an ad is consumed, the manager attempts to load a replacement.

Failed loads use:

```gdscript
const RETRY_DELAY_SECONDS: float = 60.0
```

Cached ads expire after:

```gdscript
const AD_EXPIRATION_SECONDS: float = 3300.0
```

This represents 55 minutes.

Expired advertisements are destroyed and replaced.

The manager also uses generation checks to reject outdated loading callbacks after privacy-related invalidation.

## 13. Reusing Across Games

Copy the same two scripts into each Godot project.

Only modify `admob_config.gd`.

Example configurations:

| Game | Interstitial | Rewarded | Game Overs per Ad |
|---|---|---|---|
| Spin Frenzy | Enabled | Revive | 3 |
| Fruit Wobble | Enabled | Continue | 3 |
| Sealide | Enabled | Revive | 4 |
| Hop Up | Enabled | Revive | 4 |

Each game must use its own AdMob App ID and appropriate ad unit IDs.

Game Center leaderboard IDs and other game-specific services are configured separately.

## 14. Release Checklist

Before submitting to TestFlight or the App Store:

- [ ] AdMob plugin installed correctly
- [ ] Native iOS plugin enabled in export
- [ ] Correct AdMob App ID
- [ ] Correct interstitial and rewarded unit IDs
- [ ] `USE_TEST_ADS` configured for the intended build
- [ ] Consent messages configured
- [ ] Privacy options tested
- [ ] AdMob account and app readiness checked
- [ ] `app-ads.txt` status reviewed
- [ ] Rewarded ads grant rewards only after SDK confirmation
- [ ] Game-over ads do not interrupt revive flows
- [ ] Ad loading failures do not block gameplay
- [ ] Native ad lifecycle tested on a physical device
- [ ] TestFlight diagnostics checked
- [ ] Production builds do not request Google's demo ad units

## 15. Implementation Notes

The current manager is a reusable starting implementation. Before using it in multiple production games, validate the following with Poing Studios 5.1.0:

- Native ad loader cleanup and reference release
- Callback ordering when rewarded ads close
- Consent eligibility after UMP updates
- Ad-loading behavior while another full-screen presentation is active
- Recovery after privacy changes
- Retry behavior when the application is backgrounded
- Repeated ad loading and destruction without native resource leaks

The current manager's game-over counter is not persistent. Use a game-specific save system if persistence is required.

## References

- Poing Studios Godot AdMob Plugin: https://github.com/poing-studios/godot-admob-plugin
- Google AdMob: https://admob.google.com/
- Google Mobile Ads SDK for iOS: https://developers.google.com/admob/ios/quick-start
- Google UMP: https://developers.google.com/admob/ios/privacy
- Google Test Ads: https://developers.google.com/admob/ios/test-ads

---

**Target:** Godot 4.6.x / iOS / Poing Studios AdMob Plugin 5.1.0

**Architecture:** One reusable AdMob manager, one per-game configuration script, no `.tres` dependency.