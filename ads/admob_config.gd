class_name AdMobConfig
extends RefCounted

# ============================================================
# GENERAL
# ============================================================

const ENABLED: bool = true
const USE_TEST_ADS: bool = true

const ENABLE_INTERSTITIAL: bool = true
const ENABLE_REWARDED: bool = true


# ============================================================
# IOS AD UNITS
# ============================================================

const IOS_INTERSTITIAL_ID: String = ""
const IOS_REWARDED_ID: String = ""


# ============================================================
# INTERSTITIAL RULES
# ============================================================

const GAME_OVERS_PER_AD: int = 3
const MINIMUM_SECONDS_BETWEEN_ADS: float = 60.0


# ============================================================
# LOADING
# ============================================================

const RETRY_DELAY_SECONDS: float = 60.0
const AD_EXPIRATION_SECONDS: float = 3300.0
const CONSENT_RETRY_SECONDS: float = 60.0