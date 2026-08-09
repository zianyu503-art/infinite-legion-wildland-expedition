class_name VipAccessManager
extends RefCounted

## Persistent, clock-rollback-aware access gate for the optional VIP world.
##
## The manager owns only DEFAULT_PATH (or the explicit user:// path supplied to
## the constructor). It never reads, moves, or deletes campaign/profile saves.
## A trial begins only through begin_trial(); querying snapshot() is safe while
## the player remains in the free edition.

const SCHEMA_VERSION := 1
const TRIAL_DURATION_SECONDS := 24 * 60 * 60
const DEFAULT_PATH := "user://infinite_legion_vip_access.json"
const MAX_JSON_SAFE_INTEGER := 9_007_199_254_740_991

const STATE_NOT_STARTED := "not_started"
const STATE_ACTIVE := "active"
const STATE_EXPIRED := "expired"

const ACCESS_SOURCE_NONE := "none"
const ACCESS_SOURCE_TRIAL := "trial"
const ACCESS_SOURCE_PAID := "paid"

var _save_path: String = DEFAULT_PATH


func _init(path: String = DEFAULT_PATH) -> void:
	# Keep all persistence inside Godot's per-user storage. This also prevents an
	# integration mistake from overwriting a project or exported web asset.
	if path.begins_with("user://") and not path.ends_with("/"):
		_save_path = path


func load_state() -> Dictionary:
	## Returns validated persisted fields without beginning or advancing a trial.
	## If an existing VIP state is malformed and no valid backup exists, access
	## fails closed as expired rather than silently granting a fresh trial.
	var now_unix := _resolve_now(-1)
	var loaded := _load_state_at(now_unix)
	return (loaded["state"] as Dictionary).duplicate(true)


func begin_trial(now_unix: int = -1) -> Dictionary:
	## Explicit VIP entry point. This is the only function that can create trial
	## timestamps. An active paid entitlement does not consume the free trial.
	var observed_now := _resolve_now(now_unix)
	var loaded := _load_state_at(observed_now)
	var state: Dictionary = (loaded["state"] as Dictionary).duplicate(true)
	var guarded_now := maxi(observed_now, int(state["last_seen"]))
	var trial_started_now := false

	if not _paid_is_active(state, guarded_now) and int(state["started"]) == 0:
		var start_time := maxi(guarded_now, 1)
		state["started"] = start_time
		state["expires"] = start_time + TRIAL_DURATION_SECONDS
		state["last_seen"] = start_time
		state["access_source"] = ACCESS_SOURCE_TRIAL
		trial_started_now = true

	var evaluated := _evaluate_state(state, observed_now, true)
	var persisted: Dictionary = evaluated["persisted_state"]
	var save_succeeded := _save_state(persisted)
	return _decorate_snapshot(
		evaluated,
		loaded,
		true,
		save_succeeded,
		trial_started_now,
	)


func snapshot(now_unix: int = -1) -> Dictionary:
	## Returns the current access decision and checkpoints last_seen whenever a
	## trial or paid record exists. Pass now_unix in deterministic tests.
	var observed_now := _resolve_now(now_unix)
	var loaded := _load_state_at(observed_now)
	var original: Dictionary = loaded["state"]
	var should_checkpoint := int(original["started"]) > 0 or bool(original["paid_entitled"])
	var evaluated := _evaluate_state(original, observed_now, should_checkpoint)
	var persisted: Dictionary = evaluated["persisted_state"]
	var save_attempted := should_checkpoint and persisted != original
	var save_succeeded := true
	if save_attempted:
		save_succeeded = _save_state(persisted)
	return _decorate_snapshot(evaluated, loaded, save_attempted, save_succeeded, false)


func has_access(now_unix: int = -1) -> bool:
	return bool(snapshot(now_unix)["has_access"])


func remaining_seconds(now_unix: int = -1) -> int:
	## Returns -1 for a permanent paid entitlement, otherwise whole seconds.
	return int(snapshot(now_unix)["remaining_seconds"])


func set_paid_entitlement(
	enabled: bool,
	now_unix: int = -1,
	entitlement_expires: int = 0,
) -> Dictionary:
	## Future payment/account hook. The caller is responsible for verifying the
	## purchase or server entitlement before calling this trusted local setter.
	## entitlement_expires == 0 means permanent. This never starts a trial.
	var observed_now := _resolve_now(now_unix)
	var loaded := _load_state_at(observed_now)
	var state: Dictionary = (loaded["state"] as Dictionary).duplicate(true)
	var guarded_now := maxi(observed_now, int(state["last_seen"]))

	state["paid_entitled"] = enabled
	state["paid_expires"] = clampi(entitlement_expires, 0, MAX_JSON_SAFE_INTEGER) if enabled else 0
	if enabled:
		state["last_seen"] = guarded_now

	var evaluated := _evaluate_state(state, observed_now, enabled or int(state["started"]) > 0)
	var persisted: Dictionary = evaluated["persisted_state"]
	var save_succeeded := _save_state(persisted)
	return _decorate_snapshot(evaluated, loaded, true, save_succeeded, false)


func storage_path() -> String:
	return _save_path


static func validate_persisted_state(raw_state: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not raw_state is Dictionary:
		errors.append("state_not_dictionary")
		return errors

	var state := raw_state as Dictionary
	var required_keys := [
		"version", "started", "expires", "last_seen", "access_source",
		"paid_entitled", "paid_expires",
	]
	for key in required_keys:
		if not state.has(key):
			errors.append("missing_%s" % key)

	if not errors.is_empty():
		return errors
	if not _is_integral_json_number(state["version"]) or int(state["version"]) != SCHEMA_VERSION:
		errors.append("invalid_version")

	for key in ["started", "expires", "last_seen", "paid_expires"]:
		var value: Variant = state[key]
		if not _is_integral_json_number(value):
			errors.append("invalid_%s" % key)
			continue
		var integer_value := int(value)
		if integer_value < 0 or integer_value > MAX_JSON_SAFE_INTEGER:
			errors.append("out_of_range_%s" % key)

	if not state["access_source"] is String:
		errors.append("invalid_access_source_type")
	else:
		var access_source := str(state["access_source"])
		if access_source not in [ACCESS_SOURCE_NONE, ACCESS_SOURCE_TRIAL, ACCESS_SOURCE_PAID]:
			errors.append("invalid_access_source")

	if not state["paid_entitled"] is bool:
		errors.append("invalid_paid_entitled")
	if not errors.is_empty():
		return errors

	var started := int(state["started"])
	var expires := int(state["expires"])
	var last_seen := int(state["last_seen"])
	var access_source := str(state["access_source"])
	if started == 0:
		if expires != 0:
			errors.append("expiry_without_trial")
		if access_source == ACCESS_SOURCE_TRIAL:
			errors.append("trial_source_without_trial")
	else:
		if expires != started + TRIAL_DURATION_SECONDS:
			errors.append("invalid_trial_duration")
		if last_seen < started:
			errors.append("last_seen_before_trial")
		if access_source == ACCESS_SOURCE_NONE:
			errors.append("missing_trial_source")
	if access_source == ACCESS_SOURCE_PAID and not bool(state["paid_entitled"]):
		errors.append("paid_source_without_entitlement")
	return errors


static func self_test() -> Dictionary:
	## Pure deterministic checks: no user:// files are created or removed.
	var errors: Array[String] = []
	var assertions := 0
	var start_time := 1_700_000_000
	var fresh := _default_state()
	assertions += _test_assert(
		validate_persisted_state(fresh).is_empty(),
		"fresh_state_is_valid",
		errors,
	)

	var started := fresh.duplicate(true)
	started["started"] = start_time
	started["expires"] = start_time + TRIAL_DURATION_SECONDS
	started["last_seen"] = start_time
	started["access_source"] = ACCESS_SOURCE_TRIAL
	var at_start := _evaluate_state(started, start_time, false)
	assertions += _test_assert(str(at_start["state"]) == STATE_ACTIVE, "trial_active_at_start", errors)
	assertions += _test_assert(
		int(at_start["remaining_seconds"]) == TRIAL_DURATION_SECONDS,
		"trial_has_full_duration",
		errors,
	)

	var after_hour := _evaluate_state(started, start_time + 3600, true)
	assertions += _test_assert(
		int(after_hour["remaining_seconds"]) == TRIAL_DURATION_SECONDS - 3600,
		"trial_counts_down",
		errors,
	)
	var checkpointed: Dictionary = after_hour["persisted_state"]
	var rolled_back := _evaluate_state(checkpointed, start_time + 1200, true)
	assertions += _test_assert(bool(rolled_back["clock_rollback_detected"]), "rollback_detected", errors)
	assertions += _test_assert(
		int(rolled_back["remaining_seconds"]) == TRIAL_DURATION_SECONDS - 3600,
		"rollback_does_not_restore_time",
		errors,
	)

	var at_expiry := _evaluate_state(started, start_time + TRIAL_DURATION_SECONDS, true)
	assertions += _test_assert(str(at_expiry["state"]) == STATE_EXPIRED, "trial_expires", errors)
	assertions += _test_assert(not bool(at_expiry["has_access"]), "expired_trial_denies_access", errors)

	var paid := fresh.duplicate(true)
	paid["paid_entitled"] = true
	paid["last_seen"] = start_time
	paid["access_source"] = ACCESS_SOURCE_PAID
	var paid_status := _evaluate_state(paid, start_time + TRIAL_DURATION_SECONDS * 2, true)
	assertions += _test_assert(str(paid_status["state"]) == STATE_ACTIVE, "permanent_paid_is_active", errors)
	assertions += _test_assert(int(paid_status["remaining_seconds"]) == -1, "permanent_paid_is_unlimited", errors)
	assertions += _test_assert(int(paid_status["started"]) == 0, "paid_does_not_start_trial", errors)

	var malformed := started.duplicate(true)
	malformed["expires"] = start_time + 12
	assertions += _test_assert(
		not validate_persisted_state(malformed).is_empty(),
		"malformed_duration_rejected",
		errors,
	)
	return {
		"passed": assertions - errors.size(),
		"failed": errors.size(),
		"errors": errors,
	}


func _load_state_at(now_unix: int) -> Dictionary:
	var primary := _read_state_file(_save_path)
	if bool(primary["valid"]):
		return {
			"state": primary["state"],
			"storage_valid": true,
			"state_file_existed": true,
			"recovered_from_backup": false,
		}

	var backup := _read_state_file(_save_path + ".bak")
	if bool(backup["valid"]):
		return {
			"state": backup["state"],
			"storage_valid": true,
			"state_file_existed": bool(primary["exists"]),
			"recovered_from_backup": true,
		}

	var temporary := _read_state_file(_save_path + ".tmp")
	if not bool(primary["exists"]) and bool(temporary["valid"]):
		return {
			"state": temporary["state"],
			"storage_valid": true,
			"state_file_existed": false,
			"recovered_from_backup": true,
		}

	var any_file_exists := bool(primary["exists"]) or bool(backup["exists"]) or bool(temporary["exists"])
	return {
		"state": _fail_closed_state(now_unix) if any_file_exists else _default_state(),
		"storage_valid": not any_file_exists,
		"state_file_existed": any_file_exists,
		"recovered_from_backup": false,
	}


func _save_state(state: Dictionary) -> bool:
	if not validate_persisted_state(state).is_empty():
		return false
	var json_text := JSON.stringify(state)
	var temp_path := _save_path + ".tmp"
	if not _write_file(temp_path, json_text):
		return false
	if _rename_atomic(temp_path, _save_path):
		return true

	# Some filesystems do not replace an existing path during rename. Keep the
	# previous complete VIP state until the new temporary file is fully written.
	var backup_path := _save_path + ".bak"
	_delete_file(backup_path)
	var had_previous := FileAccess.file_exists(_save_path)
	if had_previous and not _rename_atomic(_save_path, backup_path):
		_delete_file(temp_path)
		return false
	if _rename_atomic(temp_path, _save_path):
		_delete_file(backup_path)
		return true
	if had_previous:
		_rename_atomic(backup_path, _save_path)
	_delete_file(temp_path)
	return false


static func _evaluate_state(raw_state: Dictionary, observed_now: int, touch_last_seen: bool) -> Dictionary:
	var state := raw_state.duplicate(true)
	var prior_last_seen := int(state["last_seen"])
	var effective_now := maxi(observed_now, prior_last_seen)
	var rollback_detected := observed_now < prior_last_seen
	if touch_last_seen:
		state["last_seen"] = effective_now

	var paid_active := _paid_is_active(state, effective_now)
	var trial_started := int(state["started"]) > 0
	var trial_remaining := maxi(int(state["expires"]) - effective_now, 0) if trial_started else 0
	var trial_active := trial_started and trial_remaining > 0
	var access_source := ACCESS_SOURCE_NONE
	var access_state := STATE_NOT_STARTED
	var access_remaining := 0
	if paid_active:
		access_source = ACCESS_SOURCE_PAID
		access_state = STATE_ACTIVE
		var paid_expires := int(state["paid_expires"])
		access_remaining = -1 if paid_expires == 0 else maxi(paid_expires - effective_now, 0)
	elif trial_active:
		access_source = ACCESS_SOURCE_TRIAL
		access_state = STATE_ACTIVE
		access_remaining = trial_remaining
	elif trial_started:
		access_source = ACCESS_SOURCE_TRIAL
		access_state = STATE_EXPIRED
	state["access_source"] = access_source

	return {
		"persisted_state": state,
		"version": int(state["version"]),
		"started": int(state["started"]),
		"expires": int(state["expires"]),
		"last_seen": int(state["last_seen"]),
		"access_source": access_source,
		"paid_entitled": bool(state["paid_entitled"]),
		"paid_expires": int(state["paid_expires"]),
		"state": access_state,
		"has_access": access_state == STATE_ACTIVE,
		"remaining_seconds": access_remaining,
		"trial_remaining_seconds": trial_remaining,
		"clock_rollback_detected": rollback_detected,
		"effective_now": effective_now,
	}


static func _decorate_snapshot(
	evaluated: Dictionary,
	loaded: Dictionary,
	save_attempted: bool,
	save_succeeded: bool,
	trial_started_now: bool,
) -> Dictionary:
	var result := evaluated.duplicate(true)
	result.erase("persisted_state")
	result["storage_valid"] = bool(loaded["storage_valid"])
	result["state_file_existed"] = bool(loaded["state_file_existed"])
	result["recovered_from_backup"] = bool(loaded["recovered_from_backup"])
	result["save_attempted"] = save_attempted
	result["save_succeeded"] = save_succeeded
	result["trial_started_now"] = trial_started_now
	result["trial_duration_seconds"] = TRIAL_DURATION_SECONDS
	return result


static func _default_state() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"started": 0,
		"expires": 0,
		"last_seen": 0,
		"access_source": ACCESS_SOURCE_NONE,
		"paid_entitled": false,
		"paid_expires": 0,
	}


static func _fail_closed_state(now_unix: int) -> Dictionary:
	# A corrupted access record must not become a renewable trial. It is replaced
	# in memory by a valid expired trial; campaign and profile saves are untouched.
	var expiry := maxi(now_unix, TRIAL_DURATION_SECONDS + 1)
	return {
		"version": SCHEMA_VERSION,
		"started": expiry - TRIAL_DURATION_SECONDS,
		"expires": expiry,
		"last_seen": expiry,
		"access_source": ACCESS_SOURCE_TRIAL,
		"paid_entitled": false,
		"paid_expires": 0,
	}


static func _paid_is_active(state: Dictionary, now_unix: int) -> bool:
	if not bool(state["paid_entitled"]):
		return false
	var paid_expires := int(state["paid_expires"])
	return paid_expires == 0 or now_unix < paid_expires


static func _normalized_state(raw_state: Dictionary) -> Dictionary:
	return {
		"version": int(raw_state["version"]),
		"started": int(raw_state["started"]),
		"expires": int(raw_state["expires"]),
		"last_seen": int(raw_state["last_seen"]),
		"access_source": str(raw_state["access_source"]),
		"paid_entitled": bool(raw_state["paid_entitled"]),
		"paid_expires": int(raw_state["paid_expires"]),
	}


static func _read_state_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "valid": false, "state": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "valid": false, "state": {}}
	var json_text := file.get_as_text()
	file.close()
	if json_text.is_empty():
		return {"exists": true, "valid": false, "state": {}}
	var parser := JSON.new()
	if parser.parse(json_text) != OK or not parser.data is Dictionary:
		return {"exists": true, "valid": false, "state": {}}
	var parsed := parser.data as Dictionary
	if not validate_persisted_state(parsed).is_empty():
		return {"exists": true, "valid": false, "state": {}}
	return {"exists": true, "valid": true, "state": _normalized_state(parsed)}


static func _write_file(path: String, content: String) -> bool:
	if not _prepare_directory(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error == OK


static func _prepare_directory(path: String) -> bool:
	var directory := path.get_base_dir()
	if directory.is_empty() or directory == "user://" or directory == "user:":
		return true
	var error := DirAccess.make_dir_recursive_absolute(directory)
	return error == OK or error == ERR_ALREADY_EXISTS


static func _rename_atomic(from_path: String, to_path: String) -> bool:
	var result := DirAccess.rename_absolute(from_path, to_path)
	return result == OK if result is int else bool(result)


static func _delete_file(path: String) -> bool:
	var result := DirAccess.remove_absolute(path)
	return (result == OK or result == ERR_FILE_NOT_FOUND) if result is int else bool(result)


static func _resolve_now(now_unix: int) -> int:
	var resolved := now_unix
	if resolved < 0:
		resolved = int(Time.get_unix_time_from_system())
	return clampi(resolved, 0, MAX_JSON_SAFE_INTEGER - TRIAL_DURATION_SECONDS)


static func _is_integral_json_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number == floor(number)


static func _test_assert(condition: bool, label: String, errors: Array[String]) -> int:
	if not condition:
		errors.append(label)
	return 1
