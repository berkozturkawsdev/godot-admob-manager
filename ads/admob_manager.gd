extends Node

signal status_changed
signal presentation_changed

signal interstitial_loaded
signal rewarded_loaded

signal interstitial_closed
signal rewarded_closed

signal reward_earned

signal ad_failed(ad_type: String, message: String)


# ============================================================
# TEST AD UNITS
# ============================================================

const TEST_INTERSTITIAL: String = \
	"ca-app-pub-3940256099942544/4411468910"

const TEST_REWARDED: String = \
	"ca-app-pub-3940256099942544/1712485313"


# ============================================================
# PUBLIC STATE
# ============================================================

var status_text: String = "Not started"
var last_error: String = ""

var presenting: bool = false

var interstitial_ready: bool = false
var rewarded_ready: bool = false


# ============================================================
# INTERNAL STATE
# ============================================================

var _available: bool = false

var _initialized: bool = false
var _initializing: bool = false

var _interstitial_loading: bool = false
var _rewarded_loading: bool = false

var _interstitial: InterstitialAd
var _rewarded: RewardedAd

var _interstitial_loader: InterstitialAdLoader
var _rewarded_loader: RewardedAdLoader

var _interstitial_loaded_at: int = 0
var _rewarded_loaded_at: int = 0

var _last_interstitial_at: int = -1

var _game_over_count: int = 0

var _consent_retry_pending: bool = false
var _consent_updating: bool = false

var _generation: int = 0

var _input_shield: Control

var _active_ad: String = ""
var _reward_granted: bool = false

var _interstitial_retry_pending: bool = false
var _rewarded_retry_pending: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_available = (
		AdMobConfig.ENABLED
		and OS.get_name() == "iOS"
		and Engine.has_singleton("PoingGodotAdMob")
	)

	if not _available:
		_set_status(
			"AdMob disabled, unsupported platform, or plugin missing"
		)
		return

	_create_input_shield()
	_refresh_consent()


# ============================================================
# STATUS
# ============================================================

func _set_status(message: String) -> void:
	status_text = message

	print("[AdMob] ", message)

	status_changed.emit()


func _set_error(ad_type: String, message: String) -> void:
	last_error = message

	_set_status(message)

	ad_failed.emit(ad_type, message)


# ============================================================
# INPUT SHIELD
# ============================================================

func _create_input_shield() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100

	add_child(layer)

	_input_shield = Control.new()

	layer.add_child(_input_shield)

	_input_shield.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_shield.hide()


func _set_presenting(value: bool) -> void:
	presenting = value

	if is_instance_valid(_input_shield):
		_input_shield.visible = value

	presentation_changed.emit()


# ============================================================
# CONSENT
# ============================================================

func _refresh_consent() -> void:
	if not _available or _consent_updating or presenting:
		return

	_consent_updating = true

	_set_status("Checking consent")

	UserMessagingPlatform.consent_information.update(
		ConsentRequestParameters.new(),
		_consent_updated,
		_consent_failed
	)


func _can_request_ads() -> bool:
	if not _available:
		return false

	var status := \
		UserMessagingPlatform.consent_information.get_consent_status()

	return (
		status == ConsentInformation.ConsentStatus.OBTAINED
		or status == ConsentInformation.ConsentStatus.NOT_REQUIRED
	)


func _consent_updated() -> void:
	_consent_updating = false

	var status := \
		UserMessagingPlatform.consent_information.get_consent_status()

	if status == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(
			_consent_loaded,
			_consent_failed
		)
		return

	if _can_request_ads():
		_initialize_sdk()
	else:
		_set_status("Consent not available")


func _consent_loaded(form: ConsentForm) -> void:
	_set_presenting(true)

	form.show(_consent_dismissed)


func _consent_dismissed(error: FormError) -> void:
	_set_presenting(false)

	if error != null:
		_consent_failed(error)
		return

	if _can_request_ads():
		_initialize_sdk()
	else:
		_set_status("Consent required")
		_schedule_consent_retry()


func _consent_failed(error: FormError) -> void:
	_consent_updating = false

	if error != null:
		_set_error(
			"consent",
			"Consent %d: %s" % [
				error.error_code,
				error.message
			]
		)

	# Existing consent may still be valid.
	if _can_request_ads():
		_initialize_sdk()

	_schedule_consent_retry()


func _schedule_consent_retry() -> void:
	if _consent_retry_pending:
		return

	_consent_retry_pending = true

	await get_tree().create_timer(
		AdMobConfig.CONSENT_RETRY_SECONDS
	).timeout

	_consent_retry_pending = false

	if not is_inside_tree():
		return

	if not presenting:
		_refresh_consent()


# ============================================================
# PRIVACY OPTIONS
# ============================================================

func privacy_options_required() -> bool:
	if not _available:
		return false

	return (
		UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	)


func show_privacy_options() -> void:
	if not privacy_options_required():
		return

	if presenting:
		return

	_generation += 1

	_destroy_interstitial()
	_destroy_rewarded()

	_set_presenting(true)

	UserMessagingPlatform.show_privacy_options_form(
		_privacy_options_closed
	)


func _privacy_options_closed(error: FormError) -> void:
	_set_presenting(false)

	if error != null:
		_consent_failed(error)
		return

	if _can_request_ads():
		_initialize_sdk()
	else:
		_refresh_consent()


# ============================================================
# SDK INITIALIZATION
# ============================================================

func _initialize_sdk() -> void:
	if not _available:
		return

	if not _can_request_ads():
		return

	if _initialized:
		_load_ads()
		return

	if _initializing:
		return

	_initializing = true

	_set_status("Initializing AdMob SDK")

	var listener := OnInitializationCompleteListener.new()

	listener.on_initialization_complete = _on_initialized

	MobileAds.initialize(listener)


func _on_initialized(
	_initialization_status: InitializationStatus
) -> void:
	_initializing = false
	_initialized = true

	_set_status("AdMob initialized")

	_load_ads()


# ============================================================
# AD UNIT SELECTION
# ============================================================

func _ad_unit(ad_type: String) -> String:
	if AdMobConfig.USE_TEST_ADS:
		if ad_type == "rewarded":
			return TEST_REWARDED

		return TEST_INTERSTITIAL

	if ad_type == "rewarded":
		return AdMobConfig.IOS_REWARDED_ID.strip_edges()

	return AdMobConfig.IOS_INTERSTITIAL_ID.strip_edges()


# ============================================================
# LOAD ADS
# ============================================================

func _load_ads() -> void:
	if not _initialized:
		return

	if not _can_request_ads():
		return

	if AdMobConfig.ENABLE_INTERSTITIAL:
		_load_interstitial()

	if AdMobConfig.ENABLE_REWARDED:
		_load_rewarded()


# ============================================================
# INTERSTITIAL LOADING
# ============================================================

func _load_interstitial() -> void:
	if not AdMobConfig.ENABLE_INTERSTITIAL:
		return

	if not _initialized or not _can_request_ads():
		return

	if _interstitial_loading or _interstitial != null:
		return

	if presenting:
		return

	var unit := _ad_unit("interstitial")

	if unit.is_empty():
		_set_error(
			"interstitial",
			"Interstitial ad unit missing"
		)
		return

	_interstitial_loading = true

	var generation := _generation

	_set_status("Loading interstitial")

	var callback := InterstitialAdLoadCallback.new()

	callback.on_ad_loaded = func(ad: InterstitialAd):
		_interstitial_loading = false

		if generation != _generation or not _can_request_ads():
			ad.destroy()
			_load_interstitial()
			return

		_interstitial = ad
		_interstitial_loaded_at = Time.get_ticks_msec()

		interstitial_ready = true

		_set_status("Interstitial ready")
		interstitial_loaded.emit()

	callback.on_ad_failed_to_load = func(error: LoadAdError):
		_interstitial_loading = false

		if generation != _generation:
			return

		_set_error(
			"interstitial",
			"Interstitial load %d: %s" % [
				error.code,
				error.message
			]
		)

		_schedule_retry("interstitial")

	_interstitial_loader = InterstitialAdLoader.new()

	_interstitial_loader.load(
		unit,
		AdRequest.new(),
		callback
	)


# ============================================================
# INTERSTITIAL AVAILABILITY
# ============================================================

func can_show_interstitial() -> bool:
	if not _available:
		return false

	if not AdMobConfig.ENABLE_INTERSTITIAL:
		return false

	if presenting:
		return false

	if _interstitial == null:
		return false

	if not _can_request_ads():
		return false

	if _last_interstitial_at >= 0:
		var elapsed := (
			Time.get_ticks_msec() - _last_interstitial_at
		) / 1000.0

		if elapsed < AdMobConfig.MINIMUM_SECONDS_BETWEEN_ADS:
			return false

	return true


# ============================================================
# SHOW INTERSTITIAL
# ============================================================

func show_interstitial() -> bool:
	if not can_show_interstitial():
		return false

	_active_ad = "interstitial"

	_set_presenting(true)

	var callback := FullScreenContentCallback.new()

	callback.on_ad_showed_full_screen_content = func():
		_last_interstitial_at = Time.get_ticks_msec()

		_game_over_count = 0

		_set_status("Interstitial shown")

	callback.on_ad_dismissed_full_screen_content = func():
		_finish_interstitial()

	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError):
		_set_error(
			"interstitial",
			"Interstitial show %d: %s" % [
				error.code,
				error.message
			]
		)

		_finish_interstitial()

	_interstitial.full_screen_content_callback = callback

	interstitial_ready = false

	_interstitial.show()

	return true


# ============================================================
# GAME OVER TRACKING
# ============================================================

func game_over() -> void:
	if not AdMobConfig.ENABLE_INTERSTITIAL:
		return

	_game_over_count = mini(
		_game_over_count + 1,
		maxi(1, AdMobConfig.GAME_OVERS_PER_AD)
	)

	if _game_over_count < AdMobConfig.GAME_OVERS_PER_AD:
		return

	if show_interstitial():
		return

	# Keep the counter at the threshold.
	_game_over_count = maxi(
		1,
		AdMobConfig.GAME_OVERS_PER_AD
	)


# ============================================================
# INTERSTITIAL CLEANUP
# ============================================================

func _finish_interstitial() -> void:
	if _active_ad != "interstitial":
		return

	_destroy_interstitial()

	_active_ad = ""

	_set_presenting(false)

	interstitial_closed.emit()

	_load_ads()


func _destroy_interstitial() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null

	interstitial_ready = false


# ============================================================
# REWARDED LOADING
# ============================================================

func _load_rewarded() -> void:
	if not AdMobConfig.ENABLE_REWARDED:
		return

	if not _initialized or not _can_request_ads():
		return

	if _rewarded_loading or _rewarded != null:
		return

	if presenting:
		return

	var unit := _ad_unit("rewarded")

	if unit.is_empty():
		_set_error(
			"rewarded",
			"Rewarded ad unit missing"
		)
		return

	_rewarded_loading = true

	var generation := _generation

	_set_status("Loading rewarded ad")

	var callback := RewardedAdLoadCallback.new()

	callback.on_ad_loaded = func(ad: RewardedAd):
		_rewarded_loading = false

		if generation != _generation or not _can_request_ads():
			ad.destroy()
			_load_rewarded()
			return

		_rewarded = ad
		_rewarded_loaded_at = Time.get_ticks_msec()

		rewarded_ready = true

		_set_status("Rewarded ad ready")
		rewarded_loaded.emit()

	callback.on_ad_failed_to_load = func(error: LoadAdError):
		_rewarded_loading = false

		if generation != _generation:
			return

		_set_error(
			"rewarded",
			"Rewarded load %d: %s" % [
				error.code,
				error.message
			]
		)

		_schedule_retry("rewarded")

	_rewarded_loader = RewardedAdLoader.new()

	_rewarded_loader.load(
		unit,
		AdRequest.new(),
		callback
	)


# ============================================================
# REWARDED AVAILABILITY
# ============================================================

func can_show_rewarded() -> bool:
	return (
		_available
		and AdMobConfig.ENABLE_REWARDED
		and not presenting
		and _rewarded != null
		and _can_request_ads()
	)


# ============================================================
# SHOW REWARDED
# ============================================================

func show_rewarded() -> bool:
	if not can_show_rewarded():
		return false

	_active_ad = "rewarded"
	_reward_granted = false

	_set_presenting(true)

	var callback := FullScreenContentCallback.new()

	callback.on_ad_dismissed_full_screen_content = func():
		_finish_rewarded()

	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError):
		_set_error(
			"rewarded",
			"Rewarded show %d: %s" % [
				error.code,
				error.message
			]
		)

		_finish_rewarded()

	_rewarded.full_screen_content_callback = callback

	var listener := OnUserEarnedRewardListener.new()

	listener.on_user_earned_reward = func(_item: RewardedItem):
		if _active_ad != "rewarded":
			return

		if _reward_granted:
			return

		_reward_granted = true

		reward_earned.emit()

	rewarded_ready = false

	_set_status("Showing rewarded ad")

	_rewarded.show(listener)

	return true


# ============================================================
# REWARDED CLEANUP
# ============================================================

func _finish_rewarded() -> void:
	if _active_ad != "rewarded":
		return

	call_deferred("_finalize_rewarded")


func _finalize_rewarded() -> void:
	if _active_ad != "rewarded":
		return

	_destroy_rewarded()

	_active_ad = ""

	_set_presenting(false)

	rewarded_closed.emit()

	_load_ads()


func _destroy_rewarded() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null

	rewarded_ready = false


# ============================================================
# RETRY
# ============================================================

func _schedule_retry(ad_type: String) -> void:
	if ad_type == "interstitial":
		if _interstitial_retry_pending:
			return

		_interstitial_retry_pending = true

	elif ad_type == "rewarded":
		if _rewarded_retry_pending:
			return

		_rewarded_retry_pending = true

	else:
		return

	await get_tree().create_timer(
		AdMobConfig.RETRY_DELAY_SECONDS
	).timeout

	if ad_type == "interstitial":
		_interstitial_retry_pending = false
	else:
		_rewarded_retry_pending = false

	if not is_inside_tree():
		return

	if not _initialized or not _can_request_ads():
		return

	if presenting:
		return

	if ad_type == "interstitial":
		_load_interstitial()
	else:
		_load_rewarded()


# ============================================================
# AD EXPIRATION
# ============================================================

func _process(_delta: float) -> void:
	if not _initialized or presenting:
		return

	var now := Time.get_ticks_msec()

	var expiry := int(
		AdMobConfig.AD_EXPIRATION_SECONDS * 1000.0
	)

	if _interstitial != null:
		if now - _interstitial_loaded_at >= expiry:
			_destroy_interstitial()
			_load_interstitial()

	if _rewarded != null:
		if now - _rewarded_loaded_at >= expiry:
			_destroy_rewarded()
			_load_rewarded()


# ============================================================
# DIAGNOSTICS
# ============================================================

func diagnostics() -> String:
	return (
		"AdMob diagnostics\n"
		+ "Test ads: %s\n" % AdMobConfig.USE_TEST_ADS
		+ "Interstitial ready: %s\n" % interstitial_ready
		+ "Rewarded ready: %s\n" % rewarded_ready
		+ "Game overs: %d / %d\n" % [
			_game_over_count,
			AdMobConfig.GAME_OVERS_PER_AD
		]
		+ "Status: %s\n" % status_text
		+ "Last error: %s" % (
			last_error if not last_error.is_empty() else "None"
		)
	)


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	_generation += 1

	_destroy_interstitial()
	_destroy_rewarded()