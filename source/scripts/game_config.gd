class_name GameConfig
extends RefCounted

## Centered game-tuning constants for a top-down infinite-map army action game.
## All displayed names/descriptions use Traditional Chinese.

const CASTLE_SETTINGS: Dictionary = {
	"name": "蠻族城堡",
	"description": "摧毀後需留在範圍內完成佔領，之後會提供收入與招募。",
	"max_level": 50,
	"hp": 2600,
	"hp_per_level": 720,
	"repair_per_second": 18.0,
	"income_interval": 10.0,
	"income_divisor": 2,
	"capture_seconds": 5.0,
	"capture_radius": 150.0,
	"garrison_capacity": 44,
	"upgrade_bonus": {"hp": 600, "income": 12, "recruit_discount": 0.04}
}

## Exact late-game milestones. Guard pools are cumulative so distant fortresses
## keep earlier battlefield technology while introducing a clear new threat.
const CASTLE_TIERS: Dictionary = {
	20: {
		"name": "砲兵要塞", "initial_garrison": 20, "reinforcement": 8,
		"wall_ratio": 0.0,
		"guards": ["grunt", "archer", "heavy", "shaman", "cannon", "grunt", "cannon"],
	},
	30: {
		"name": "火器堡壘", "initial_garrison": 26, "reinforcement": 11,
		"wall_ratio": 0.0,
		"guards": ["grunt", "archer", "heavy", "cannon", "musketeer", "rifleman", "rifleman", "shaman"],
	},
	35: {
		"name": "鋼鐵軍城", "initial_garrison": 30, "reinforcement": 13,
		"wall_ratio": 0.0,
		"guards": ["heavy", "cannon", "musketeer", "rifleman", "tank", "rocket", "grunt", "rifleman", "shaman"],
	},
	40: {
		"name": "巨壁機關城", "initial_garrison": 34, "reinforcement": 15,
		"wall_ratio": 0.62,
		"guards": ["heavy", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "grunt", "gatling", "shaman"],
	},
	45: {
		"name": "天空戰爭堡", "initial_garrison": 38, "reinforcement": 17,
		"wall_ratio": 0.72,
		"guards": ["heavy", "cannon", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "rifleman", "helicopter"],
	},
	50: {
		"name": "星界終焉城", "initial_garrison": 42, "reinforcement": 19,
		"wall_ratio": 0.82,
		"guards": ["heavy", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo", "rifleman", "ufo"],
	},
}

const SOLDIER_ORDER: Array[String] = [
	"swordsman", "healer", "archer", "roller", "mage", "heavy",
	"priest", "cannon", "musketeer", "rifleman", "tank", "rocket",
]

## 擊敗最終混沌 Boss 後永久開放的四種城堡科技兵。和初始招募名單
## 分開保存，避免舊存檔與測試場景在尚未通關時提前顯示終局獎勵。
const CHAOS_UNLOCK_SOLDIER_ORDER: Array[String] = [
	"gatling", "helicopter", "bomber", "ufo",
]

## 程序化蟒蛇 Boss 戰鬥巢穴。所有巢穴共用 PYTHON_BOSS_CONFIG 內唯一的
## 「腐沼蟒皇・薩迦」控制器；玩家接近時才啟動一座，避免同時生成多隻 Boss。
## 大間距確保同一探索區域不會塞滿巢穴。
const SNAKE_NEST_SETTINGS: Dictionary = {
	"name": "蟒蛇 Boss 巢穴",
	"spacing_x": 11,
	"spacing_y": 11,
	"offset_x": 3,
	"offset_y": 2,
	"radius": 92.0,
	"spawn_clear_radius": 260.0,
	"enemy_clear_radius": 360.0,
	"activation_radius": 950.0,
	"release_radius": 1300.0,
	"activation_check_interval": 0.20,
	"map_reveal_radius": 1450.0,
}

const CAMP_SETTINGS: Dictionary = {
	"name": "蠻族營地",
	"description": "清除守軍與補給箱可獲得額外獎勵，稍後可能重新被佔據。",
	"respawn_seconds": 180.0,
	"clear_reward_gold": 70,
	"clear_reward_xp": 55,
	"crate_hp": 90,
	"radius": 150.0
}

const WORLD_SETTINGS: Dictionary = {
	"chunk_size": 960,
	"chunk_variance": 180,
	"seed": 20260731,
	"tile_size": 64,
	"world_limit": INF,
	"min_spawn_distance": 760.0,
	"max_spawn_distance": 2800.0,
	"resource_density": 0.82,
	"fog_growth_per_second": 0.15
}

## 「腐沼蟒皇・薩迦」的唯一資料來源。
## 主動技能只允許 skills 內這五項；階段轉換與回巢回血屬被動機制。
const PYTHON_BOSS_CONFIG: Dictionary = {
	"id": "corrupt_python_emperor_saga",
	"name": "腐沼蟒皇・薩迦",
	"home_position": Vector2(2400.0, 1440.0),
	"base": {
		"max_hp": 7200.0,
		"damage": 78.0,
		"defense": 26.0,
		"move_speed": 118.0,
		"turn_speed": 3.15,
		"alert_range": 720.0,
		"arena_radius": 850.0,
		"leash_distance": 1000.0,
		"return_heal_per_second": 0.05,
		"target_lock_min": 1.2,
		"target_lock_max": 2.4,
		"global_skill_gap_min": 0.45,
		"global_skill_gap_max": 0.78,
	},
	"scaling": {
		"world_tier_hp": 0.30,
		"world_tier_damage": 0.18,
		"player_level_hp": 0.04,
		"player_level_damage": 0.03,
		"player_level_start": 8,
		"max_world_tier": 6,
		"max_player_level_bonus": 12,
	},
	"body": {
		"segment_count": 18,
		"segment_spacing": 28.0,
		"head_radius": 40.0,
		"body_radius": 32.0,
		"tail_radius": 14.0,
		"history_step": 5.0,
		"history_margin": 180.0,
		"follow_smoothing": 16.0,
		"collision_stride": 1,
	},
	"part_damage_multipliers": {
		"head": 1.0,
		"body": 0.80,
		"tail": 0.65,
		"stunned_head": 1.20,
	},
	"phases": [
		{
			"id": 1,
			"name": "狩獵",
			"threshold": 0.70,
			"move_speed": 1.0,
			"attack_speed": 1.0,
			"cooldown": 1.0,
			"pool_duration": 1.0,
			"pool_count": 2,
		},
		{
			"id": 2,
			"name": "腐毒",
			"threshold": 0.35,
			"move_speed": 1.15,
			"attack_speed": 1.14,
			"cooldown": 0.82,
			"pool_duration": 1.15,
			"pool_count": 4,
		},
		{
			"id": 3,
			"name": "狂暴蟒皇",
			"threshold": 0.0,
			"move_speed": 1.30,
			"attack_speed": 1.28,
			"cooldown": 0.62,
			"pool_duration": 1.0,
			"pool_count": 6,
		},
	],
	"phase_change": {
		"duration": 1.0,
		"damage_reduction": 0.82,
		"knockback_radius": 230.0,
		"knockback_distance": 72.0,
		"damage_multiplier": 0.38,
	},
	## 注意：此字典必須維持恰好五項。
	"skills": {
		"constrict": {
			"name": "絞蟒纏縛",
			"telegraph": 0.90,
			"min_range": 100.0,
			"max_range": 280.0,
			"lunge_speed": 570.0,
			"duration": 3.0,
			"damage_tick": 0.50,
			"initial_damage_multiplier": 0.65,
			"damage_multiplier": 0.42,
			"cooldown": 9.5,
			"recovery": 0.75,
			"control_immunity": 5.0,
			"break_gauge": 250.0,
			"click_power_multiplier": 1.10,
			"release_knockback": 80.0,
			"wrap_nodes": 4,
		},
		"dash": {
			"name": "蛇影裂地衝",
			"telegraph": 1.0,
			"speed": 820.0,
			"max_distance": 560.0,
			"width": 92.0,
			"damage_multiplier": 1.48,
			"knockback": 110.0,
			"prediction_min": 0.42,
			"prediction_max": 0.72,
			"recovery": 0.72,
			"wall_stun": 1.80,
			"cooldown": 6.8,
			"phase_three_trail_duration": 2.50,
			"phase_three_trail_width": 34.0,
		},
		"bite": {
			"name": "腐牙噬咬",
			"telegraph": 0.50,
			"range": 145.0,
			"angle_degrees": 76.0,
			"damage_multiplier": 1.22,
			"poison_damage_per_second": 0.09,
			"poison_duration": 7.0,
			"poison_max_stacks": 3,
			"three_stack_slow": 0.15,
			"cooldown": 3.80,
			"recovery": 0.48,
			"second_bite_chance": 0.72,
			"second_telegraph": 0.35,
			"second_damage_multiplier": 0.90,
		},
		"poison_pool": {
			"name": "腐沼毒潭",
			"telegraph": 0.85,
			"projectile_flight": 0.58,
			"impact_damage_multiplier": 0.72,
			"radius": 105.0,
			"duration_phase_one": 5.0,
			"duration_phase_two": 7.0,
			"duration_phase_three": 8.0,
			"damage_tick": 0.50,
			"tick_damage_multiplier": 0.16,
			"slow": 0.30,
			"cooldown": 9.5,
			"recovery": 0.72,
			"max_pools": 6,
			"merge_radius_multiplier": 1.30,
		},
		"tail_sweep": {
			"name": "裂骨巨尾",
			"telegraph": 0.75,
			"inner_radius": 90.0,
			"outer_radius": 300.0,
			"angles": [210.0, 240.0, 270.0],
			"damage_multiplier": 1.38,
			"knockback": 170.0,
			"off_balance": 0.35,
			"sweep_duration": 0.46,
			"cooldown": 5.8,
			"recovery": 0.72,
		},
	},
	"threat": {
		"player_base_per_second": 5.0,
		"damage_multiplier": 1.0,
		"cannon_multiplier": 2.2,
		"healing_multiplier": 0.65,
		"revive_flat": 170.0,
		"heavy_taunt_per_second": 25.0,
		"decay_per_second": 0.05,
	},
	"rewards": {
		"gold_min": 800,
		"gold_max": 1200,
		"xp_min": 900,
		"xp_max": 1400,
	},
	"performance": {
		"spatial_hash_cell": 160.0,
		"unit_query_padding": 48.0,
		"far_update_interval": 0.25,
		"dash_substep": 18.0,
		"max_poison_projectiles": 8,
		"max_poison_pools": 6,
		"max_aux_poison_areas": 10,
		"max_boss_particles": 160,
	},
	"audio": {
		"hiss": "boss_hiss",
		"constrict": "boss_constrict",
		"dash": "boss_dash",
		"impact": "boss_impact",
		"bite": "boss_bite",
		"poison": "boss_poison",
		"bubble": "boss_bubble",
		"tail": "boss_tail",
		"stun": "boss_stun",
		"phase": "boss_phase",
		"death": "boss_death",
	},
	"vfx": {
		"poison_color": Color("A855F7"),
		"poison_dark": Color("42145F"),
		"scale_dark": Color("173F2A"),
		"scale_mid": Color("28643C"),
		"belly": Color("B6AF72"),
		"eye": Color("F8E34E"),
		"warning": Color("FF5B68"),
		"reward": Color("FFD166"),
	},
}

## 唯一的終局 Boss。固定在 50 級城堡環帶內的「混沌裂界」，不參與
## 程序化蟒蛇巢穴生成；十招均由 chaos_boss.gd 的決定式 FSM 驅動。
const CHAOS_BOSS_CONFIG: Dictionary = {
	"id": "kaeron_annihilator_of_all",
	"name": "萬象崩滅者・卡厄隆",
	"home_position": Vector2(24960.0, 14400.0),
	"max_hp": 112000.0,
	"defense": 76.0,
	"move_speed": 188.0,
	"turn_speed": 3.4,
	"radius": 88.0,
	"engage_distance": 1250.0,
	"leash_distance": 1180.0,
	"phase_thresholds": {"two": 0.70, "three": 0.35},
	"rewards": {"gold_min": 3200, "gold_max": 4800, "xp_min": 5000, "xp_max": 7200},
	"skills": [
		{"id": "meteor", "name": "隕星天降"},
		{"id": "destruction_beam", "name": "毀滅光炮"},
		{"id": "energy_barrage", "name": "連環能量炮"},
		{"id": "shockwave", "name": "混沌衝擊波"},
		{"id": "black_hole", "name": "黑洞召喚"},
		{"id": "summon_monsters", "name": "異獸召喚"},
		{"id": "homing_missiles", "name": "追蹤飛彈"},
		{"id": "lightning", "name": "終末雷獄"},
		{"id": "rift_dash", "name": "裂界瞬襲"},
		{"id": "total_annihilation", "name": "萬象歸零"},
	],
	"vfx": {
		"body": Color("24133F"), "armor": Color("5B2A86"),
		"core": Color("FF4FCB"), "energy": Color("7AF7FF"),
		"warning": Color("FF4A6E"), "rift": Color("9B5CFF"),
	},
}

## 卡厄隆之後解鎖的超維 Boss。艾歐尼斯位於固定的「無時之庭」，以四階段、
## 時間錨破防與高威脅兵種反制來對抗滿級玩家及完整科技軍團。
const AIONIS_BOSS_CONFIG: Dictionary = {
	"id": "aionis_end_of_all_timelines",
	"name": "諸界終時者・艾歐尼斯",
	"home_position": Vector2(34560.0, -20160.0),
	"max_hp": 260000.0,
	"defense": 112.0,
	"move_speed": 230.0,
	"turn_speed": 4.2,
	"radius": 98.0,
	"engage_distance": 1480.0,
	"leash_distance": 1320.0,
	"phase_thresholds": {"two": 0.75, "three": 0.50, "four": 0.25},
	"anchors": {"count": 4, "damage_reduction": 0.48, "exposed_seconds": 5.0},
	"rewards": {"gold_min": 8200, "gold_max": 12000, "xp_min": 12800, "xp_max": 18000},
	"skills": [
		{"id": "clock_sever", "name": "時針斬界"},
		{"id": "causal_hunt", "name": "因果追獵"},
		{"id": "chrono_prison", "name": "時牢封軍"},
		{"id": "rewind_rebirth", "name": "逆時回生"},
		{"id": "parallel_legion", "name": "平行軍團"},
		{"id": "rift_board", "name": "斷界棋盤"},
		{"id": "star_gate_barrage", "name": "星門炮列"},
		{"id": "army_judgment", "name": "軍勢審判"},
		{"id": "causal_mirror", "name": "逆因果鏡"},
		{"id": "twelfth_bell", "name": "十二刻終焉"},
	],
	"vfx": {
		"body": Color("EEEAE0"), "armor": Color("111C35"),
		"gold": Color("FFD66B"), "core": Color("FF365F"),
		"time": Color("7DEAFF"), "void": Color("182044"),
		"warning": Color("FF435D"), "safe": Color("8AF6D0"),
	},
}

const BALANCE_SETTINGS: Dictionary = {
	"xp_curve": {"base": 110, "growth": 95, "level_power": 1.18},
	"difficulty": {
		"min": 1,
		"max": 16,
		"base": 1,
		"distance_per_level": 1800.0,
		"linear_growth": 1,
		"curve_growth": 2.25
	},
	"army_limit": {"base": 50, "castle_level_divisor": 2},
	"combat_global": {"critical_chance": 0.04, "critical_multiplier": 1.35, "critical_armor_pierce": 5},
	"loot_multiplier": 1.06,
	"xp_multiplier": 1.0,
	"respawn_delay": 7.5
}

const NORMAL_ATTACKS: Dictionary = {
	"archer": {
		"name": "快速射擊",
		"damage": 26,
		"attack_speed": 1.85,
		"range": 390.0,
		"projectile_speed": 900.0,
		"projectile_color": Color("7BD3FF"),
		"effects": {"pierce": 1, "armor_penetration": 2},
		"description": "持續穩定射擊，對單體目標有高穿透率。"
	},
	"mage": {
		"name": "火球術",
		"damage": 34,
		"attack_speed": 1.2,
		"range": 340.0,
		"projectile_speed": 760.0,
		"projectile_color": Color("FF8A45"),
		"effects": {"blast_radius": 78.0, "magic_type": "arcane"},
		"description": "以魔法彈造成小範圍爆裂的中距離傷害。"
	},
	"warrior": {
		"name": "重劍斬",
		"damage": 30,
		"attack_speed": 1.4,
		"range": 92.0,
		"projectile_speed": 0.0,
		"projectile_color": Color("FFD166"),
		"effects": {"knockback": 18.0},
		"description": "向滑鼠方向揮出扇形重斬，可同時擊退多名近身敵人。"
	}
}

const SPECIAL_ATTACKS: Dictionary = {
	"archer": {
		"name": "散射箭",
		"damage": 46,
		"cooldown": 12.0,
		"range": 420.0,
		"projectile_count": 7,
		"cone_angle": 48.0,
		"projectile_color": Color("9BE7FF"),
		"effects": {"slow": 0.3, "slow_duration": 2.0},
		"description": "對前方扇形區域施放多重箭矢，附帶減速效果。"
	},
	"mage": {
		"name": "火焰飛彈",
		"damage": 64,
		"cooldown": 14.0,
		"range": 300.0,
		"aoe_radius": 190.0,
		"projectile_color": Color("FF5F7A"),
		"effects": {"burn": 7, "burn_duration": 5.0},
		"description": "在地面引爆熔岩環域，持續灼燒區域內的敵人。"
	},
	"warrior": {
		"name": "衝刺斬",
		"damage": 58,
		"cooldown": 16.0,
		"range": 130.0,
		"dash_distance": 170.0,
		"projectile_color": Color("FFC857"),
		"effects": {"armor_reduce": 6, "duration": 4.0, "pierce_stack": 1},
		"description": "迅速突進並擊碎鎧甲，短時間降低目標防禦。"
	}
}

const HERO_CLASSES: Dictionary = {
	"archer": {
		"name": "弓箭手",
		"description": "擅長長距離持續輸出，與群體控制能力互補。",
		"color": Color("4FA3F7"),
		"base_stats": {"hp": 110, "attack": 24, "defense": 8, "speed": 132, "mana": 90},
		"attack_growth": {"hp": 8, "attack": 6, "defense": 2, "speed": 2, "mana": 4},
		"normal_attack": NORMAL_ATTACKS["archer"],
		"special_attack": SPECIAL_ATTACKS["archer"],
		"passive": {"name": "瞄準", "description": "暴擊機率+2%，命中時回復少量體力。", "crit_bonus": 0.02}
	},
	"mage": {
		"name": "法師",
		"description": "以大範圍法術控制戰場，對堅韌與群體目標高效。",
		"color": Color("E84B5F"),
		"base_stats": {"hp": 88, "attack": 28, "defense": 6, "speed": 118, "mana": 140},
		"attack_growth": {"hp": 5, "attack": 7, "defense": 2, "speed": 2, "mana": 7},
		"normal_attack": NORMAL_ATTACKS["mage"],
		"special_attack": SPECIAL_ATTACKS["mage"],
		"passive": {"name": "元素親和", "description": "命中法術目標有小幅範圍擴散，連鎖傷害機率提升。", "chain_bonus": 0.12}
	},
	"warrior": {
		"name": "戰士",
		"description": "前線坦克，擁有高生命與控制，適合吸收壓力。",
		"color": Color("D58D43"),
		"base_stats": {"hp": 150, "attack": 30, "defense": 16, "speed": 124, "mana": 70},
		"attack_growth": {"hp": 11, "attack": 7, "defense": 3, "speed": 2, "mana": 3},
		"normal_attack": NORMAL_ATTACKS["warrior"],
		"special_attack": SPECIAL_ATTACKS["warrior"],
		"passive": {"name": "不屈", "description": "生命低於40%時移動速度提高，持續回復小量生命。", "survive_bonus": 0.08}
	}
}

const STAT_UPGRADES: Dictionary = {
	"max_hp": {
		"name": "生命值",
		"description": "提高單位基礎生命。",
		"initial": 0,
		"step": 28,
		"cap": 240,
		"cost": {"gold": 60, "wood": 18}
	},
	"attack": {
		"name": "攻擊力",
		"description": "提升所有已招募隊伍的傷害輸出。",
		"initial": 0,
		"step": 5,
		"cap": 90,
		"cost": {"gold": 85, "crystal": 6}
	},
	"defense": {
		"name": "防禦力",
		"description": "減少受到的傷害，增加生存時間。",
		"initial": 0,
		"step": 3,
		"cap": 70,
		"cost": {"gold": 70, "iron": 8}
	},
	"speed": {
		"name": "移動速度",
		"description": "提高行軍與追擊能力。",
		"initial": 0,
		"step": 2,
		"cap": 45,
		"cost": {"gold": 58, "wood": 14}
	},
	"attack_speed": {
		"name": "攻擊速度",
		"description": "降低普通攻擊冷卻；設有安全下限。",
		"initial": 0,
		"step": 6,
		"cap": 12,
		"unit": "percent"
	}
}

const SOLDIERS: Dictionary = {
	"swordsman": {
		"name": "劍士",
		"description": "平衡穩定的近戰主力，適合大規模交戰。",
		"color": Color("CFE8A7"),
		"recruit_cost": {"gold": 50},
		"combat": {
			"hp": 140,
			"attack": 24,
			"attack_speed": 1.25,
			"range": 62.0,
			"armor": 9,
			"movement_speed": 118,
			"morale": 5
		}
	},
	"healer": {
		"name": "醫者",
		"description": "行軍中的持續治療來源，擅長維持隊伍續航。",
		"color": Color("9BDFD3"),
		"recruit_cost": {"gold": 90},
		"combat": {
			"hp": 96,
			"attack": 10,
			"attack_speed": 1.0,
			"range": 100.0,
			"armor": 6,
			"movement_speed": 112,
			"morale": 7,
			"healing_per_second": 10
		}
	},
	"archer": {
		"name": "弓兵",
		"description": "穩定遠程輸出，可壓制敵方前鋒。",
		"color": Color("6CA0F5"),
		"recruit_cost": {"gold": 100},
		"combat": {
			"hp": 102,
			"attack": 22,
			"attack_speed": 1.4,
			"range": 360.0,
			"armor": 4,
			"movement_speed": 122,
			"morale": 6
		}
	},
	"roller": {
		"name": "滾石兵",
		"description": "投出可穿透多名敵人且逐次衰減傷害的大型滾石。",
		"color": Color("F0C75E"),
		"recruit_cost": {"gold": 130},
		"combat": {
			"hp": 168,
			"attack": 34,
			"attack_speed": 0.9,
			"range": 310.0,
			"armor": 15,
			"movement_speed": 106,
			"morale": 8,
			"pierce": 4,
			"damage_falloff": 0.16
		}
	},
	"mage": {
		"name": "法師",
		"description": "低血但高爆發的法術遠距單位。",
		"color": Color("D45D7A"),
		"recruit_cost": {"gold": 160},
		"combat": {
			"hp": 84,
			"attack": 36,
			"attack_speed": 1.1,
			"range": 340.0,
			"armor": 3,
			"movement_speed": 108,
			"morale": 6,
			"mana_cost": 12
		}
	},
	"heavy": {
		"name": "重甲兵",
		"description": "高韌性突破型戰士，適合帶隊衝鋒。",
		"color": Color("9E7F53"),
		"recruit_cost": {"gold": 220},
		"combat": {
			"hp": 220,
			"attack": 28,
			"attack_speed": 1.0,
			"range": 64.0,
			"armor": 20,
			"movement_speed": 100,
			"morale": 10
		}
	},
	"priest": {
		"name": "牧師",
		"description": "以長時間儀式復活仍留有墓碑的友方士兵。",
		"color": Color("A98CD8"),
		"recruit_cost": {"gold": 280},
		"combat": {
			"hp": 112,
			"attack": 16,
			"attack_speed": 0.95,
			"range": 130.0,
			"armor": 7,
			"movement_speed": 110,
			"morale": 8,
			"revive_seconds": 2.8,
			"revive_cooldown": 14.0,
			"revive_hp_ratio": 0.45
		}
	},
	"cannon": {
		"name": "重型大砲",
		"description": "玩家專用的加固重砲；威力與爆炸範圍高於城堡普通大砲。",
		"color": Color("B34A3C"),
		"recruit_cost": {"gold": 520},
		"combat": {
			"hp": 190,
			"attack": 112,
			"attack_speed": 0.34,
			"range": 650.0,
			"armor": 11,
			"movement_speed": 68,
			"morale": 4,
			"aoe_radius": 148.0,
			"charge_seconds": 1.65,
			"siege_multiplier": 3.0
		}
	},
	"musketeer": {
		"name": "火槍手",
		"description": "裝填很慢，但單發威力與射程極高的精準射手。",
		"color": Color("D7C3A0"),
		"recruit_cost": {"gold": 240},
		"combat": {
			"hp": 108, "attack": 78, "attack_speed": 0.38, "range": 540.0,
			"armor": 5, "movement_speed": 96, "morale": 6,
			"attack_style": "musket", "can_target_air": true
		}
	},
	"rifleman": {
		"name": "突擊步槍手",
		"description": "以高速連射壓制地面與空中目標的現代步兵。",
		"color": Color("73B49A"),
		"recruit_cost": {"gold": 320},
		"combat": {
			"hp": 132, "attack": 34, "attack_speed": 3.1, "range": 470.0,
			"armor": 9, "movement_speed": 112, "morale": 8,
			"attack_style": "rifle", "can_target_air": true
		}
	},
	"tank": {
		"name": "坦克",
		"description": "履帶重甲載具；生命與砲擊傷害高，但射速緩慢。",
		"color": Color("70875B"),
		"recruit_cost": {"gold": 900},
		"combat": {
			"hp": 620, "attack": 92, "attack_speed": 0.38, "range": 560.0,
			"armor": 34, "movement_speed": 66, "morale": 12,
			"aoe_radius": 138.0, "charge_seconds": 1.05, "siege_multiplier": 1.6,
			"attack_style": "tank_shell", "can_target_air": true
		}
	},
	"rocket": {
		"name": "火箭炮",
		"description": "長距離發射大型火箭，造成極高且寬廣的爆炸傷害。",
		"color": Color("D88945"),
		"recruit_cost": {"gold": 820},
		"combat": {
			"hp": 176, "attack": 145, "attack_speed": 0.27, "range": 650.0,
			"armor": 10, "movement_speed": 74, "morale": 5,
			"aoe_radius": 188.0, "charge_seconds": 1.3, "siege_multiplier": 2.2,
			"attack_style": "rocket", "can_target_air": true
		}
	},
	"gatling": {
		"name": "加特林",
		"description": "終局解鎖的高速壓制火力；射速極快，可攻擊地面與空中目標。",
		"color": Color("5F91B8"),
		"recruit_cost": {"gold": 680},
		"combat": {
			"hp": 285, "attack": 27, "attack_speed": 5.2, "range": 520.0,
			"armor": 18, "movement_speed": 82, "morale": 9,
			"attack_style": "gatling", "can_target_air": true
		}
	},
	"helicopter": {
		"name": "直升機",
		"description": "終局解鎖的空中加特林載具；能飛越樹木、房屋與城牆。",
		"color": Color("4F9AB8"),
		"recruit_cost": {"gold": 1250},
		"combat": {
			"hp": 420, "attack": 30, "attack_speed": 4.4, "range": 540.0,
			"armor": 16, "movement_speed": 148, "morale": 10,
			"attack_style": "gatling", "can_target_air": true, "domain": "air"
		}
	},
	"bomber": {
		"name": "轟炸機",
		"description": "終局解鎖的重型空軍；連續投下三枚延遲爆炸的廣域炸彈。",
		"color": Color("718DB6"),
		"recruit_cost": {"gold": 1800},
		"combat": {
			"hp": 520, "attack": 142, "attack_speed": 0.38, "range": 590.0,
			"armor": 21, "movement_speed": 130, "morale": 11,
			"aoe_radius": 182.0, "attack_style": "bomb", "can_target_air": false, "domain": "air"
		}
	},
	"ufo": {
		"name": "UFO",
		"description": "終局解鎖的星界飛碟；以持續光柱灼燒敵軍、敵城與世界 Boss。",
		"color": Color("54D9D2"),
		"recruit_cost": {"gold": 2600},
		"combat": {
			"hp": 1080, "attack": 34, "attack_speed": 0.45, "range": 570.0,
			"armor": 33, "movement_speed": 116, "morale": 14,
			"aoe_radius": 82.0, "attack_style": "ufo_beam", "can_target_air": true, "domain": "air"
		}
	}
}

const ENEMIES: Dictionary = {
	"grunt": {
		"name": "步兵",
		"description": "最常見的敵方士兵，數量大但組織差。",
		"color": Color("7A8B8B"),
		"reward": {"gold": 16, "xp": 12},
		"combat": {
			"hp": 80,
			"attack": 14,
			"attack_speed": 1.2,
			"range": 58.0,
			"armor": 5,
			"movement_speed": 106
		}
	},
	"archer": {
		"name": "弓兵",
		"description": "輕甲遠程敵人，常作為掩護與壓制。",
		"color": Color("6088D4"),
		"reward": {"gold": 18, "xp": 14},
		"combat": {
			"hp": 68,
			"attack": 18,
			"attack_speed": 1.25,
			"range": 340.0,
			"armor": 2,
			"movement_speed": 112
		}
	},
	"thrower": {
		"name": "擲彈手",
		"description": "可投擲爆裂投射物並打斷後排隊形。",
		"color": Color("D77A4F"),
		"reward": {"gold": 24, "xp": 19},
		"combat": {
			"hp": 72,
			"attack": 28,
			"attack_speed": 0.82,
			"range": 260.0,
			"armor": 4,
			"movement_speed": 102,
			"aoe_radius": 110.0
		}
	},
	"berserker": {
		"name": "狂戰士",
		"description": "近身突進，短時間內傷害和速度顯著提升。",
		"color": Color("C14B4B"),
		"reward": {"gold": 32, "xp": 26},
		"combat": {
			"hp": 132,
			"attack": 30,
			"attack_speed": 1.0,
			"range": 64.0,
			"armor": 7,
			"movement_speed": 132,
			"rage_bonus": 0.22
		}
	},
	"heavy": {
		"name": "重甲敵",
		"description": "防禦高、移動慢的前線威脅。",
		"color": Color("9B8A67"),
		"reward": {"gold": 36, "xp": 30},
		"combat": {
			"hp": 210,
			"attack": 26,
			"attack_speed": 0.88,
			"range": 62.0,
			"armor": 18,
			"movement_speed": 96
		}
	},
	"shaman": {
		"name": "薩滿",
		"description": "具有群體輔助能力，能加速自軍。",
		"color": Color("6B8EDE"),
		"reward": {"gold": 40, "xp": 34},
		"combat": {
			"hp": 108,
			"attack": 20,
			"attack_speed": 0.78,
			"range": 290.0,
			"armor": 6,
			"movement_speed": 104,
			"buff": {"attack_speed": 0.1, "armor": 0.05}
		}
	},
	"chief": {
		"name": "酋長",
		"description": "首領型單位，會嘗試保護周邊敵軍。",
		"color": Color("DA4D70"),
		"reward": {"gold": 75, "xp": 65},
		"combat": {
			"hp": 320,
			"attack": 42,
			"attack_speed": 1.0,
			"range": 96.0,
			"armor": 22,
			"movement_speed": 104,
			"command_radius": 260.0,
			"resilience": 0.15
		}
	},
	"cannon": {
		"name": "普通大砲", "description": "20 級城堡開始部署的慢速範圍砲兵。",
		"color": Color("73554A"), "reward": {"gold": 62, "xp": 52},
		"combat": {"hp": 230, "attack": 72, "attack_speed": 0.34, "range": 610.0, "armor": 11, "movement_speed": 62, "aoe_radius": 125.0, "attack_style": "cannon", "telegraph": 1.05}
	},
	"musketeer": {
		"name": "敵軍火槍手", "description": "裝填緩慢但單發傷害極高。",
		"color": Color("B8A37F"), "reward": {"gold": 54, "xp": 48},
		"combat": {"hp": 112, "attack": 82, "attack_speed": 0.36, "range": 550.0, "armor": 6, "movement_speed": 94, "attack_style": "musket", "telegraph": 0.88}
	},
	"rifleman": {
		"name": "敵軍突擊步槍手", "description": "高速連射且傷害高的遠程威脅。",
		"color": Color("688C78"), "reward": {"gold": 58, "xp": 50},
		"combat": {"hp": 136, "attack": 36, "attack_speed": 3.0, "range": 490.0, "armor": 9, "movement_speed": 110, "attack_style": "rifle", "telegraph": 0.16}
	},
	"tank": {
		"name": "敵軍坦克", "description": "血量與護甲極高的履帶砲擊載具。",
		"color": Color("657252"), "reward": {"gold": 140, "xp": 118},
		"combat": {"hp": 680, "attack": 94, "attack_speed": 0.36, "range": 570.0, "armor": 35, "movement_speed": 62, "aoe_radius": 142.0, "attack_style": "tank_shell", "telegraph": 1.0}
	},
	"rocket": {
		"name": "敵軍火箭炮", "description": "以極慢射速換取極高範圍爆炸傷害。",
		"color": Color("B96F3D"), "reward": {"gold": 128, "xp": 112},
		"combat": {"hp": 190, "attack": 148, "attack_speed": 0.25, "range": 670.0, "armor": 10, "movement_speed": 72, "aoe_radius": 190.0, "attack_style": "rocket", "telegraph": 1.25}
	},
	"gatling": {
		"name": "敵軍加特林", "description": "射速極快、單發傷害一般的旋轉機槍。",
		"color": Color("806B57"), "reward": {"gold": 92, "xp": 80},
		"combat": {"hp": 250, "attack": 20, "attack_speed": 5.2, "range": 520.0, "armor": 15, "movement_speed": 80, "attack_style": "gatling", "telegraph": 0.12}
	},
	"helicopter": {
		"name": "敵軍直升機", "description": "高速空中加特林平台，只有遠程攻擊能命中。",
		"color": Color("587A68"), "reward": {"gold": 150, "xp": 130},
		"combat": {"hp": 360, "attack": 21, "attack_speed": 4.4, "range": 520.0, "armor": 13, "movement_speed": 150, "attack_style": "gatling", "telegraph": 0.12, "domain": "air"}
	},
	"bomber": {
		"name": "敵軍轟炸機", "description": "沿地面連續投彈的重型空中單位。",
		"color": Color("52647D"), "reward": {"gold": 190, "xp": 165},
		"combat": {"hp": 450, "attack": 125, "attack_speed": 0.38, "range": 580.0, "armor": 17, "movement_speed": 132, "aoe_radius": 178.0, "attack_style": "bomb", "telegraph": 0.72, "domain": "air"}
	},
	"ufo": {
		"name": "敵軍 UFO", "description": "從空中垂直照射可躲避、但不會秒殺玩家的光柱。",
		"color": Color("74D8D0"), "reward": {"gold": 320, "xp": 280},
		"combat": {"hp": 980, "attack": 24, "attack_speed": 0.45, "range": 560.0, "armor": 29, "movement_speed": 116, "aoe_radius": 78.0, "attack_style": "ufo_beam", "telegraph": 1.15, "domain": "air"}
	}
}

static func castle_tier_for_level(level: int) -> int:
	for milestone in [50, 45, 40, 35, 30, 20]:
		if level >= milestone:
			return milestone
	return 0

static func castle_tier(level: int) -> Dictionary:
	var tier := castle_tier_for_level(level)
	return Dictionary(CASTLE_TIERS.get(tier, {}))

static func xp_needed(level: int) -> int:
	# 從目前等級升到下一級所需經驗。
	var n: int = maxi(level - 1, 0)
	var curve: Dictionary = BALANCE_SETTINGS["xp_curve"]
	var base: float = float(curve["base"])
	var growth: float = float(curve["growth"]) * 0.55
	var power: float = float(curve["level_power"])
	return int(base + growth * pow(float(n), power))

static func difficulty_at(distance: float) -> int:
	# 依據玩家在地圖前進距離調整難度等級。
	var cfg: Dictionary = BALANCE_SETTINGS["difficulty"]
	if distance < 0.0:
		distance = 0.0
	var segments := distance / float(cfg["distance_per_level"])
	var linear := int(segments * float(cfg["linear_growth"]))
	var curve := int(pow(max(segments, 0.0), 1.2) * float(cfg["curve_growth"]))
	var value := int(cfg["base"]) + linear + curve
	return clampi(value, int(cfg["min"]), int(cfg["max"]))

static func army_limit(total_owned_castle_levels: int) -> int:
	# 初始 50 人；所有已佔領城堡等級先加總，再每 2 級增加 1 人。
	var cfg: Dictionary = BALANCE_SETTINGS["army_limit"]
	var owned_levels := maxi(total_owned_castle_levels, 0)
	return int(cfg["base"]) + int(floor(float(owned_levels) / float(cfg["castle_level_divisor"])))
