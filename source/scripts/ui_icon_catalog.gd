class_name UiIconCatalog
extends RefCounted

## Stable semantic access to the shared monochrome SVG icon family.
##
## Callers should draw these white source textures with a material-aware
## modulate color. Aliases keep game code semantic while avoiding duplicate
## resources (for example, `anvil` and `upgrades` share one texture).

const _CLOSE: Texture2D = preload("res://assets/ui/icons/close.svg")
const _PREVIOUS: Texture2D = preload("res://assets/ui/icons/previous.svg")
const _NEXT: Texture2D = preload("res://assets/ui/icons/next.svg")
const _PLUS: Texture2D = preload("res://assets/ui/icons/plus.svg")
const _MINUS: Texture2D = preload("res://assets/ui/icons/minus.svg")
const _FULLSCREEN: Texture2D = preload("res://assets/ui/icons/fullscreen.svg")
const _PAUSE: Texture2D = preload("res://assets/ui/icons/pause.svg")
const _NOTIFICATIONS: Texture2D = preload("res://assets/ui/icons/notifications.svg")
const _NOTIFICATIONS_OFF: Texture2D = preload("res://assets/ui/icons/notifications_off.svg")
const _MAP: Texture2D = preload("res://assets/ui/icons/map.svg")
const _HELP: Texture2D = preload("res://assets/ui/icons/help.svg")
const _INFO: Texture2D = preload("res://assets/ui/icons/info.svg")
const _CHEAT: Texture2D = preload("res://assets/ui/icons/cheat.svg")
const _UPGRADES: Texture2D = preload("res://assets/ui/icons/upgrades.svg")
const _RECRUIT: Texture2D = preload("res://assets/ui/icons/recruit.svg")
const _FLAG: Texture2D = preload("res://assets/ui/icons/flag.svg")
const _SKILLS: Texture2D = preload("res://assets/ui/icons/skills.svg")
const _COMMAND: Texture2D = preload("res://assets/ui/icons/command.svg")
const _SAVE: Texture2D = preload("res://assets/ui/icons/save.svg")
const _LOAD: Texture2D = preload("res://assets/ui/icons/load.svg")
const _RESTART: Texture2D = preload("res://assets/ui/icons/restart.svg")
const _WARNING: Texture2D = preload("res://assets/ui/icons/warning.svg")
const _CHECK: Texture2D = preload("res://assets/ui/icons/check.svg")
const _PLAY: Texture2D = preload("res://assets/ui/icons/play.svg")
const _EXIT: Texture2D = preload("res://assets/ui/icons/exit.svg")
const _VOLUME_UP: Texture2D = preload("res://assets/ui/icons/volume_up.svg")
const _VOLUME_OFF: Texture2D = preload("res://assets/ui/icons/volume_off.svg")
const _BATTLE: Texture2D = preload("res://assets/ui/icons/battle.svg")
const _SETTINGS: Texture2D = preload("res://assets/ui/icons/settings.svg")
const _LANGUAGE: Texture2D = preload("res://assets/ui/icons/language.svg")

const _ICONS: Dictionary = {
	"close": _CLOSE,
	"back": _PREVIOUS,
	"prev": _PREVIOUS,
	"previous": _PREVIOUS,
	"next": _NEXT,
	"plus": _PLUS,
	"minus": _MINUS,
	"fullscreen": _FULLSCREEN,
	"pause": _PAUSE,
	"bell": _NOTIFICATIONS,
	"notifications": _NOTIFICATIONS,
	"notification": _NOTIFICATIONS,
	"bell_off": _NOTIFICATIONS_OFF,
	"notifications_off": _NOTIFICATIONS_OFF,
	"notification_off": _NOTIFICATIONS_OFF,
	"map": _MAP,
	"help": _HELP,
	"guide": _HELP,
	"info": _INFO,
	"terminal": _CHEAT,
	"cheat": _CHEAT,
	"upgrade": _UPGRADES,
	"upgrades": _UPGRADES,
	"anvil": _UPGRADES,
	"recruit": _RECRUIT,
	"person_add": _RECRUIT,
	"flag": _FLAG,
	"skills": _SKILLS,
	"chart": _SKILLS,
	"command": _COMMAND,
	"save": _SAVE,
	"load": _LOAD,
	"restart": _RESTART,
	"rematch": _RESTART,
	"warning": _WARNING,
	"check": _CHECK,
	"play": _PLAY,
	"exit": _EXIT,
	"sound_on": _VOLUME_UP,
	"volume_up": _VOLUME_UP,
	"sound_off": _VOLUME_OFF,
	"volume_off": _VOLUME_OFF,
	"battle": _BATTLE,
	"swords": _BATTLE,
	"settings": _SETTINGS,
	"sliders": _SETTINGS,
	"language": _LANGUAGE,
	"globe": _LANGUAGE,
}


static func texture(icon_id: String) -> Texture2D:
	return _ICONS.get(icon_id, _INFO) as Texture2D


static func has_icon(icon_id: String) -> bool:
	return _ICONS.has(icon_id)


static func semantic_ids() -> PackedStringArray:
	return PackedStringArray(_ICONS.keys())
