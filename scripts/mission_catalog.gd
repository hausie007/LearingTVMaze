extends RefCounted

const MISSION_FIND_EXIT := "find_exit"
const MISSION_FOLLOW_TRAIL := "follow_trail"
const MISSION_FIND_NEXT := "find_next"
const MISSION_RACE_MIDDLE := "race_middle"

const PICKUP_NONE := "none"
const PICKUP_NUMBERS := "numbers"
const PICKUP_LETTERS := "letters"
const PICKUP_WORDS := "words"

const STYLE_PATH := "path"
const STYLE_NEXT_SYMBOL := "next_symbol"
const STYLE_RACE := "race"

const ROLE_COLLECTOR := "collector"
const ROLE_CHASER := "chaser"
const ROLE_RACER := "racer"

const TRAINING_NONE := "none"
const TRAINING_NUMBERS := "numbers"
const TRAINING_LETTERS := "letters"
const TRAINING_WORDS := "words"

# ── Pickup Card UI Constants ─────────────────────────────────────────────────
# Canonical order and display metadata for the pickup card row.
# Used by mode_selection.gd, host_setup.gd, and game_setup_wizard.gd.

const PICKUP_CARD_ORDER: Array[String] = [PICKUP_NUMBERS, PICKUP_WORDS, PICKUP_LETTERS, PICKUP_NONE]

const PICKUP_CARD_ICONS := {
	"numbers": "123",
	"words": "W",
	"letters": "ABC",
	"none": ">",
}

const PICKUP_CARD_TITLE_KEYS := {
	"numbers": "training_numbers",
	"words": "training_words",
	"letters": "training_letters",
	"none": "pickup_just_maze",
}

const PICKUP_CARD_SUBTITLE_KEYS := {
	"numbers": "pickup_numbers_short",
	"words": "pickup_words_short",
	"letters": "pickup_letters_short",
	"none": "pickup_none_short",
}

const CHASER_LEVEL_SLOW := 1
const CHASER_LEVEL_MEDIUM := 2
const CHASER_LEVEL_FAST := 3
const CHASER_LEVEL_TURBO := 4

const DEFAULT_MISSION := MISSION_FOLLOW_TRAIL
const DEFAULT_PICKUP := PICKUP_WORDS

const CHASER_TUNING_LEVELS: Array[int] = [
	CHASER_LEVEL_SLOW,
	CHASER_LEVEL_MEDIUM,
	CHASER_LEVEL_FAST,
	CHASER_LEVEL_TURBO,
]

static func missions() -> Array[Dictionary]:
	return [
		{
			"id": MISSION_FIND_EXIT,
			"icon": "res://images/lm_maze.png",
			"title_key": "mission_find_exit",
			"subtitle_key": "mission_find_exit_short",
		},
		{
			"id": MISSION_FOLLOW_TRAIL,
			"icon": "res://images/lm_trail.png",
			"title_key": "mission_follow_trail",
			"subtitle_key": "mission_follow_trail_short",
		},
		{
			"id": MISSION_FIND_NEXT,
			"icon": "res://images/lm_next.png",
			"title_key": "mission_find_next",
			"subtitle_key": "mission_find_next_short",
		},
		{
			"id": MISSION_RACE_MIDDLE,
			"icon": "res://images/lm_center.png",
			"title_key": "mission_race_middle",
			"subtitle_key": "mission_race_middle_short",
		},
	]

static func mission_ids() -> Array[String]:
	return [
		MISSION_FIND_EXIT,
		MISSION_FOLLOW_TRAIL,
		MISSION_FIND_NEXT,
		MISSION_RACE_MIDDLE,
	]

static func mission_data(mission_id: String) -> Dictionary:
	for mission in missions():
		if String(mission.get("id", "")) == mission_id:
			return mission
	return missions()[1]

static func mission_title_key(mission_id: String) -> String:
	return String(mission_data(mission_id).get("title_key", "mission_follow_trail"))

static func mission_icon(mission_id: String) -> String:
	return String(mission_data(mission_id).get("icon", "?"))

static func allowed_pickups(mission_id: String) -> Array[String]:
	match mission_id:
		MISSION_FIND_EXIT:
			return [PICKUP_NONE]
		MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT:
			return [PICKUP_NUMBERS, PICKUP_LETTERS, PICKUP_WORDS]
		MISSION_RACE_MIDDLE:
			return [PICKUP_NONE, PICKUP_NUMBERS, PICKUP_LETTERS, PICKUP_WORDS]
		_:
			return [PICKUP_WORDS]

static func default_pickup(mission_id: String) -> String:
	var options := allowed_pickups(mission_id)
	if options.has(DEFAULT_PICKUP):
		return DEFAULT_PICKUP
	return String(options[0])

static func pickup_title_key(pickup: String) -> String:
	match pickup:
		PICKUP_NONE:
			return "pickup_none"
		PICKUP_NUMBERS:
			return "training_numbers"
		PICKUP_LETTERS:
			return "training_letters"
		PICKUP_WORDS:
			return "training_words"
		_:
			return "training_words"

static func chaser_allowed(mission_id: String) -> bool:
	return mission_id != MISSION_RACE_MIDDLE

static func chaser_required(mission_id: String, is_multiplayer: bool) -> bool:
	return is_multiplayer and mission_id == MISSION_FOLLOW_TRAIL

static func default_chaser_enabled(mission_id: String, is_multiplayer: bool) -> bool:
	return chaser_required(mission_id, is_multiplayer)

static func chaser_forced_off(mission_id: String) -> bool:
	return mission_id == MISSION_RACE_MIDDLE

static func max_players_options(mission_id: String, chaser_enabled: bool) -> Array[int]:
	if chaser_enabled:
		return [2]
	match mission_id:
		MISSION_FIND_EXIT, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE:
			return [2, 3, 4]
		_:
			return [2]

static func style_for_mission(mission_id: String) -> String:
	match mission_id:
		MISSION_FIND_NEXT:
			return STYLE_NEXT_SYMBOL
		MISSION_RACE_MIDDLE:
			return STYLE_RACE
		_:
			return STYLE_PATH

static func training_for_pickup(pickup: String) -> String:
	match pickup:
		PICKUP_NONE:
			return PICKUP_NONE
		PICKUP_NUMBERS:
			return PICKUP_NUMBERS
		PICKUP_LETTERS:
			return PICKUP_LETTERS
		PICKUP_WORDS:
			return PICKUP_WORDS
		_:
			return PICKUP_WORDS

static func pickup_for_training(training: String) -> String:
	match training:
		PICKUP_NONE:
			return PICKUP_NONE
		PICKUP_NUMBERS:
			return PICKUP_NUMBERS
		PICKUP_LETTERS:
			return PICKUP_LETTERS
		PICKUP_WORDS:
			return PICKUP_WORDS
		_:
			return PICKUP_WORDS

static func mission_from_config(style: String, training: String) -> String:
	if style == STYLE_RACE:
		return MISSION_RACE_MIDDLE
	if style == STYLE_NEXT_SYMBOL:
		return MISSION_FIND_NEXT
	if training == PICKUP_NONE:
		return MISSION_FIND_EXIT
	return MISSION_FOLLOW_TRAIL

static func goal_key(mission_id: String, pickup: String, chaser_enabled: bool, is_multiplayer: bool) -> String:
	if chaser_enabled:
		match mission_id:
			MISSION_FIND_EXIT:
				return "mission_goal_exit_chaser"
			MISSION_FOLLOW_TRAIL:
				return "mission_goal_trail_chaser"
			MISSION_FIND_NEXT:
				return "mission_goal_next_chaser"
	if mission_id == MISSION_FIND_EXIT:
		return "mission_goal_exit_multi" if is_multiplayer else "mission_goal_exit"
	if mission_id == MISSION_FOLLOW_TRAIL:
		return "mission_goal_trail"
	if mission_id == MISSION_FIND_NEXT:
		return "mission_goal_next"
	if mission_id == MISSION_RACE_MIDDLE:
		return "mission_goal_race_plain" if pickup == PICKUP_NONE else "mission_goal_race_pickups"
	return "mission_goal_trail"

static func role_summary_key(mission_id: String, chaser_enabled: bool) -> String:
	if chaser_enabled:
		return "mission_roles_chaser"
	if mission_id == MISSION_FIND_EXIT:
		return "mission_roles_maze_race"
	if mission_id == MISSION_FIND_NEXT:
		return "mission_roles_shared_hunt"
	if mission_id == MISSION_RACE_MIDDLE:
		return "mission_roles_race"
	return "mission_roles_solo"

static func head_start_title_key(level: int) -> String:
	match level:
		CHASER_LEVEL_SLOW:
			return "head_start_long"
		CHASER_LEVEL_MEDIUM:
			return "head_start_normal"
		CHASER_LEVEL_FAST:
			return "head_start_short"
		CHASER_LEVEL_TURBO:
			return "head_start_tiny"
		_:
			return "head_start_normal"
