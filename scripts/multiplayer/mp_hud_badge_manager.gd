# scripts/multiplayer/mp_hud_badge_manager.gd
# ─────────────────────────────────────────────────────────────────────────────
# MpHudBadgeManager
# Manages the registration, updating, and presentation of player info badges/chips on the GameHUD.
# ─────────────────────────────────────────────────────────────────────────────
class_name MpHudBadgeManager
extends RefCounted

static func setup_mp_player_badges(mgr: Node, session: Dictionary) -> void:
	if mgr.hud == null:
		return
	var players_data: Array[Dictionary] = []
	var players := session.get("players", {}) as Dictionary
	var roles := session.get("roles", {}) as Dictionary

	var peer_ids: Array[int] = []
	for raw_key in players.keys():
		peer_ids.append(int(raw_key))
	peer_ids.sort()

	for peer_id in peer_ids:
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var role := String(roles.get(peer_id, roles.get(str(peer_id), info.get("role", NetworkManager.ROLE_COLLECTOR))))

		if mgr._is_maze_race_mode() or mgr._is_race_mode():
			role = NetworkManager.ROLE_RACER

		var color: Color
		if mgr._is_race_mode():
			color = mgr._distinct_race_color(peer_id, String(info.get("character_id", ""))) as Color
		else:
			var palette := AvatarAccent.palette_from_character_id(String(info.get("character_id", "")))
			color = palette.get("accent", UIColors.BLUE if peer_id == NetworkManager.HOST_PEER_ID else Color("#FF5555")) as Color

		players_data.append({
			"character_id": String(info.get("character_id", "")),
			"color": color,
			"role": mgr._chip_role_for_peer(peer_id, role),
			"trap_available": bool(mgr._trap_available_by_peer.get(peer_id, false)),
			"trap_texture": mgr._trap_texture(),
			"confusion_moves": int(mgr._confusion_moves_by_peer.get(peer_id, 0)),
			"is_confused": int(mgr._confusion_moves_by_peer.get(peer_id, 0)) > 0,
		})

	mgr.hud.set_players(players_data)

static func refresh_mp_player_badges(mgr: Node) -> void:
	if mgr.hud == null:
		return
	setup_mp_player_badges(mgr, NetworkManager.current_session)
	if mgr._is_chaser_variant():
		var remaining := 0
		if not mgr._path_chasers_released:
			remaining = maxi(0, int(mgr._path_chaser_trigger_moves()) - int(mgr._collector_move_count))
		mgr.hud.update_chaser_countdown(remaining)
