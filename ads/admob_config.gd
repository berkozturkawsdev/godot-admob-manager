
class_name AdMobConfig
extends RefCounted

# ============================================================
# FALLBACK SETTINGS
# ============================================================

const ENABLED: bool = true
const USE_TEST_ADS: bool = true

const ENABLE_INTERSTITIAL: bool = true
const ENABLE_REWARDED: bool = true

# Production ad unit IDs.
const IOS_INTERSTITIAL_ID: String = ""
const IOS_REWARDED_ID: String = ""

# Interstitial frequency.
const GAME_OVERS_PER_AD: int = 3
const MINIMUM_SECONDS_BETWEEN_ADS: float = 60.0

# Loading and consent.
const RETRY_DELAY_SECONDS: float = 60.0
const AD_EXPIRATION_SECONDS: float = 3300.0
const CONSENT_RETRY_SECONDS: float = 60.0
