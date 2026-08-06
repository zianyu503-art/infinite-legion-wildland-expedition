class_name SoldierUpgradeCatalog
extends RefCounted

## Pure, data-driven research catalog for the sixteen recruitable soldier types.
## This file intentionally has no scene or main-game dependency. Callers own the
## wallet transaction and persist the sanitized research dictionary themselves.

const SCHEMA_VERSION := 2
const RECRUIT_DISCOUNT_CAP := 0.35
const SPECIAL_RANK_COST_MULTIPLIERS: Array[int] = [1, 2, 4]
const SUMMON_TEAM_CAP := 5
const SUMMON_RECURSIVE_ALLOWED := false

const SOLDIER_ORDER: Array[String] = [
	"swordsman", "healer", "archer", "roller", "mage", "heavy", "priest", "cannon",
	"musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo",
]

const SOLDIER_MULTIPLIERS: Dictionary = {
	"swordsman": 1.00,
	"healer": 1.00,
	"archer": 1.00,
	"roller": 1.15,
	"mage": 1.25,
	"heavy": 1.30,
	"priest": 1.45,
	"musketeer": 1.45,
	"rifleman": 1.60,
	"cannon": 1.80,
	"tank": 2.20,
	"rocket": 2.20,
	"gatling": 2.40,
	"helicopter": 2.80,
	"bomber": 3.10,
	"ufo": 3.60,
}

const MELEE_TYPES: Array[String] = ["swordsman", "heavy"]
const SUPPORT_TYPES: Array[String] = ["healer", "priest"]
const AIR_TYPES: Array[String] = ["helicopter", "bomber", "ufo"]

## Compact bilingual labels used by localized_effect_text(). The formatter owns
## units separately, so the same label remains correct for every rank.
const EFFECT_KEY_LABELS: Dictionary = {
	"recruit_discount": ["招募折扣", "Recruit discount"],
	"attack_or_healing_bonus": ["攻擊／療癒加成", "Attack / healing bonus"],
	"armor_bonus": ["裝甲加成", "Armor bonus"],
	"max_hp_bonus": ["最大生命加成", "Maximum health bonus"],
	"attack_or_support_speed_bonus": ["攻擊／支援速度加成", "Attack / support speed bonus"],
	"move_speed_bonus": ["移動速度加成", "Movement speed bonus"],
	"ranged_support_ratio": ["遠程／支援射程", "Ranged / support range"],
	"melee_flat_px": ["近戰觸及", "Melee reach"],
	"chance": ["機率", "Chance"],
	"multiplier": ["倍率", "Multiplier"],
	"total_burn_ratio": ["總燃燒傷害", "Total burn damage"],
	"total_poison_ratio": ["總毒素傷害", "Total poison damage"],
	"duration": ["持續時間", "Duration"],
	"source_target_proc_cooldown": ["同來源目標觸發間隔", "Per-source target proc interval"],
	"slow_ratio": ["減速", "Slow"],
	"boss_slow_ratio": ["Boss 減速", "Boss slow"],
	"arrow_interval": ["箭矢觸發間隔", "Arrow trigger interval"],
	"normal_stun": ["普通敵人暈眩", "Normal-enemy stun"],
	"boss_replacement": ["Boss 替代效果", "Boss replacement"],
	"jumps": ["跳躍次數", "Jumps"],
	"jump_damage_ratio": ["跳躍傷害", "Jump damage"],
	"jump_range": ["跳躍距離", "Jump range"],
	"armor_reduction": ["裝甲削減", "Armor reduction"],
	"max_stacks": ["最大層數", "Maximum stacks"],
	"soldier_damage_taken_bonus": ["士兵承傷加成", "Soldier damage taken"],
	"extra_projectiles": ["額外投射物", "Extra projectiles"],
	"spread_degrees": ["散射角度", "Spread angle"],
	"damage_ratio": ["傷害比例", "Damage"],
	"extra_pierce": ["額外穿透", "Extra pierces"],
	"retained_damage_ratio": ["保留傷害", "Retained damage"],
	"extra_targets": ["額外目標", "Extra targets"],
	"ricochet_damage_ratio": ["跳彈傷害", "Ricochet damage"],
	"ricochet_range": ["跳彈距離", "Ricochet range"],
	"first_hit_ratio": ["首擊傷害", "First-hit damage"],
	"linger_duration": ["滯留時間", "Linger duration"],
	"tick_interval": ["跳傷間隔", "Tick interval"],
	"tick_damage_ratio": ["每跳傷害", "Tick damage"],
	"max_per_unit": ["單位上限", "Per-unit cap"],
	"team_cap": ["全隊上限", "Team cap"],
	"turn_degrees_per_second": ["每秒轉向", "Turn rate"],
	"until_expiry": ["持續至消失", "Until expiry"],
	"ignored_armor": ["無視裝甲", "Ignored armor"],
	"extra_blasts": ["額外爆炸", "Extra blasts"],
	"blast_damage_ratios": ["爆炸傷害序列", "Blast damage sequence"],
	"impact_damage_ratio": ["命中傷害", "Impact damage"],
	"arming_time": ["啟動時間", "Arming time"],
	"mine_ttl": ["地雷存在時間", "Mine lifetime"],
	"trigger_damage_ratio": ["觸發傷害", "Trigger damage"],
	"trigger_radius": ["觸發半徑", "Trigger radius"],
	"main_damage_ratio": ["主爆炸傷害", "Main blast damage"],
	"bomblets": ["子炸彈", "Bomblets"],
	"bomblet_damage_ratio": ["子炸彈傷害", "Bomblet damage"],
	"zone_ttl": ["區域存在時間", "Zone lifetime"],
	"knockback": ["擊退距離", "Knockback"],
	"applies_slow": ["附加減速", "Applies slow"],
	"shards": ["碎片數", "Shards"],
	"shard_damage_ratio": ["碎片傷害", "Shard damage"],
	"same_target_hit_cap": ["同目標命中上限", "Same-target hit cap"],
	"structure_damage_bonus": ["建築傷害加成", "Structure damage bonus"],
	"respects_gate": ["遵守城門規則", "Respects gate rules"],
	"cooldown": ["冷卻", "Cooldown"],
	"distance": ["距離", "Distance"],
	"during_dash_damage_reduction": ["衝刺期間減傷", "Dash damage reduction"],
	"radius": ["半徑", "Radius"],
	"applies_short_stun": ["附加短暫暈眩", "Applies short stun"],
	"stun_duration": ["暈眩時間", "Stun duration"],
	"sweep_damage_ratio": ["橫掃傷害", "Sweep damage"],
	"hit_threshold": ["命中觸發門檻", "Hit threshold"],
	"move_reduction": ["移速降低", "Movement reduction"],
	"attack_speed_reduction": ["攻速降低", "Attack-speed reduction"],
	"boss_reduced": ["Boss 效果降低", "Reduced on bosses"],
	"effect_duration": ["效果時間", "Effect duration"],
	"self_damage_reduction": ["自身減傷", "Self damage reduction"],
	"boss_threat_only": ["Boss 僅增加仇恨", "Boss threat only"],
	"other_ally_damage_bonus": ["其他友軍傷害加成", "Other-ally damage bonus"],
	"boss_multiplier": ["Boss 倍率", "Boss multiplier"],
	"sidestep_distance": ["側移距離", "Sidestep distance"],
	"damage_reduction": ["減傷", "Damage reduction"],
	"army_shared_cooldown": ["全軍共享冷卻", "Army-wide cooldown"],
	"warning_time": ["預警時間", "Warning time"],
	"ttl": ["存在時間", "Lifetime"],
	"hp_ratio": ["生命倍率", "Health multiplier"],
	"attack_ratio": ["攻擊比例", "Attack ratio"],
	"attack_range": ["攻擊射程", "Attack range"],
	"attack_interval": ["攻擊間隔", "Attack interval"],
	"max_per_owner": ["持有者上限", "Per-owner cap"],
	"team_summon_cap": ["全隊召喚上限", "Team summon cap"],
	"recursive_summoning": ["可遞迴召喚", "Recursive summoning"],
	"shots_per_second": ["每秒射擊", "Shots per second"],
	"shot_damage_ratio": ["單發傷害", "Shot damage"],
	"max_hp_heal_per_second": ["每秒最大生命治療", "Maximum-health healing per second"],
	"target_roles": ["目標類型", "Target roles"],
	"healing_range": ["治療距離", "Healing range"],
	"no_hit_delay": ["未受擊等待", "No-hit delay"],
	"shield_max_hp_ratio": ["最大生命護盾", "Maximum-health shield"],
	"recharge_no_hit_time": ["充能等待", "Recharge no-hit time"],
	"once_per_life": ["每次生命一次", "Once per life"],
	"survive_hp": ["存活生命", "Survival health"],
	"invulnerability": ["無敵時間", "Invulnerability"],
	"grants_recovery": ["獲得恢復", "Grants recovery"],
	"recovery_max_hp_ratio": ["恢復最大生命", "Maximum-health recovery"],
	"recovery_duration": ["恢復時間", "Recovery duration"],
	"lifesteal_ratio": ["吸血", "Lifesteal"],
	"max_hp_heal_cap_per_second_ratio": ["每秒吸血上限", "Lifesteal cap per second"],
	"cap_mode": ["上限模式", "Cap mode"],
	"next_projectile_or_area_reduction": ["下次投射／範圍減傷", "Next projectile / area reduction"],
	"excluded_damage_kinds": ["排除傷害類型", "Excluded damage types"],
	"intercepts_homing": ["攔截追蹤彈", "Intercepts homing projectiles"],
	"air_only": ["僅限空軍", "Air only"],
	"healing_bonus": ["治療加成", "Healing bonus"],
	"trigger_every_heals": ["治療觸發間隔", "Heal trigger interval"],
	"allies": ["友軍數", "Allies"],
	"healing_ratio": ["治療比例", "Healing ratio"],
	"removes": ["清除效果", "Removes"],
	"target_cooldown": ["單目標冷卻", "Per-target cooldown"],
	"chant_time": ["詠唱時間", "Chant time"],
	"revive_hp_ratio": ["復活生命", "Revived health"],
	"tombstone_bonus_seconds": ["墓碑延長", "Tombstone extension"],
	"revived_damage_reduction": ["復活後減傷", "Post-revival reduction"],
	"reduction_duration": ["減傷時間", "Reduction duration"],
	"ally_damage_reduction": ["友軍減傷", "Ally damage reduction"],
	"stack_rule": ["疊加規則", "Stacking rule"],
	"vehicle_air_healing_bonus": ["載具／空軍治療加成", "Vehicle / air healing bonus"],
	"threshold": ["生命門檻", "Health threshold"],
	"damage_bonus": ["傷害加成", "Damage bonus"],
	"pull_distance": ["牽引距離", "Pull distance"],
	"every_attacks": ["攻擊觸發間隔", "Attack trigger interval"],
	"echo_delay": ["回響延遲", "Echo delay"],
	"echo_damage_ratio": ["回響傷害", "Echo damage"],
	"damage_multiplier": ["傷害倍率", "Damage multiplier"],
	"bonus_radius": ["額外半徑", "Bonus radius"],
	"move_distance": ["所需移動距離", "Required travel distance"],
	"ally_attack_speed_bonus": ["友軍攻速加成", "Ally attack-speed bonus"],
	"ally_move_speed_bonus": ["友軍移速加成", "Ally movement-speed bonus"],
	"overheal_to_shield_ratio": ["溢療轉護盾", "Overheal-to-shield conversion"],
	"shield_target_max_hp_ratio": ["目標最大生命護盾上限", "Target-health shield cap"],
	"hits_taken": ["承傷觸發次數", "Hits-taken trigger"],
	"next_attack_damage_bonus": ["下一擊傷害加成", "Next-attack damage bonus"],
	"bonus_gold_ratio": ["額外金幣比例", "Bonus gold"],
}

const BASE_UPGRADE_ORDER: Array[String] = [
	"recruit_discount",
	"attack_or_healing",
	"armor",
	"max_hp",
	"attack_or_support_speed",
	"move_speed",
	"range",
	"critical",
]

## Base prices never use soldier multipliers. Except for critical, every rank
## effect is an increment and snapshot_for_type() adds all purchased ranks.
const BASE_UPGRADES: Dictionary = {
	"recruit_discount": {
		"name": {"zh_TW": "招募整備", "en": "Recruitment Logistics"},
		"summary": {"zh_TW": "降低此兵種的後續招募價格；總折扣最高 35%。", "en": "Reduces future recruitment cost for this type, capped at 35%."},
		"prices": [8000, 18000, 40000, 85000],
		"rank_effects": [
			{"recruit_discount": 0.05},
			{"recruit_discount": 0.10},
			{"recruit_discount": 0.15},
			{"recruit_discount": 0.20},
		],
		"stack_mode": "add_capped",
		"cap": RECRUIT_DISCOUNT_CAP,
	},
	"attack_or_healing": {
		"name": {"zh_TW": "攻擊／療癒增幅", "en": "Attack / Healing Output"},
		"summary": {"zh_TW": "攻擊兵提高傷害；支援兵提高治療量。", "en": "Raises damage for attackers and healing output for support units."},
		"prices": [5000, 10000, 20000, 40000, 80000],
		"rank_effects": [
			{"attack_or_healing_bonus": 0.05},
			{"attack_or_healing_bonus": 0.10},
			{"attack_or_healing_bonus": 0.15},
			{"attack_or_healing_bonus": 0.20},
			{"attack_or_healing_bonus": 0.25},
		],
		"stack_mode": "add",
	},
	"armor": {
		"name": {"zh_TW": "裝甲強化", "en": "Armor Reinforcement"},
		"summary": {"zh_TW": "提高此兵種的固定裝甲值。", "en": "Adds flat armor to this soldier type."},
		"prices": [4000, 8000, 16000, 32000, 64000],
		"rank_effects": [
			{"armor_bonus": 3.0}, {"armor_bonus": 6.0}, {"armor_bonus": 9.0},
			{"armor_bonus": 12.0}, {"armor_bonus": 15.0},
		],
		"stack_mode": "add",
	},
	"max_hp": {
		"name": {"zh_TW": "生命強化", "en": "Vitality Reinforcement"},
		"summary": {"zh_TW": "按比例提高此兵種的最大生命。", "en": "Raises maximum health by a percentage."},
		"prices": [4000, 8000, 16000, 32000, 64000],
		"rank_effects": [
			{"max_hp_bonus": 0.06}, {"max_hp_bonus": 0.12}, {"max_hp_bonus": 0.18},
			{"max_hp_bonus": 0.24}, {"max_hp_bonus": 0.30},
		],
		"stack_mode": "add",
	},
	"attack_or_support_speed": {
		"name": {"zh_TW": "攻擊／支援速度", "en": "Attack / Support Speed"},
		"summary": {"zh_TW": "提高攻擊頻率；支援兵則提高治療與支援頻率。", "en": "Raises attack rate, or healing and support rate for support units."},
		"prices": [6000, 12000, 24000, 48000, 96000],
		"rank_effects": [
			{"attack_or_support_speed_bonus": 0.04}, {"attack_or_support_speed_bonus": 0.08},
			{"attack_or_support_speed_bonus": 0.12}, {"attack_or_support_speed_bonus": 0.16},
			{"attack_or_support_speed_bonus": 0.20},
		],
		"stack_mode": "add",
	},
	"move_speed": {
		"name": {"zh_TW": "行軍速度", "en": "Movement Speed"},
		"summary": {"zh_TW": "按比例提高此兵種的移動速度。", "en": "Raises movement speed by a percentage."},
		"prices": [3000, 6000, 12000, 24000],
		"rank_effects": [
			{"move_speed_bonus": 0.06}, {"move_speed_bonus": 0.12},
			{"move_speed_bonus": 0.18}, {"move_speed_bonus": 0.24},
		],
		"stack_mode": "add",
	},
	"range": {
		"name": {"zh_TW": "射程／觸及", "en": "Range / Reach"},
		"summary": {"zh_TW": "遠程與支援兵提高比例射程；近戰兵提高固定觸及距離。", "en": "Adds percentage range to ranged/support units and flat reach to melee units."},
		"prices": [4000, 8000, 16000, 32000],
		"rank_effects": [
			{"ranged_support_ratio": 0.04, "melee_flat_px": 3.0},
			{"ranged_support_ratio": 0.08, "melee_flat_px": 6.0},
			{"ranged_support_ratio": 0.12, "melee_flat_px": 9.0},
			{"ranged_support_ratio": 0.16, "melee_flat_px": 12.0},
		],
		"stack_mode": "add_by_role",
	},
	"critical": {
		"name": {"zh_TW": "精準／療癒爆擊", "en": "Critical / Critical Healing"},
		"summary": {"zh_TW": "提高攻擊爆擊；支援兵改為治療爆擊。", "en": "Grants critical hits, or critical healing to support units."},
		"prices": [15000, 35000, 80000],
		"rank_effects": [
			{"chance": 0.06, "multiplier": 1.50},
			{"chance": 0.10, "multiplier": 1.65},
			{"chance": 0.14, "multiplier": 1.80},
		],
		"stack_mode": "replace",
	},
}

const SPECIAL_ABILITY_ORDER: Array[String] = [
	"burning_sword", "burning_ammo", "frost_arrow", "paralysis_arrow", "chain_lightning",
	"corrosion", "void_mark", "split_shot", "piercing_arrow", "penetrating_round", "ricochet",
	"lingering_projectile", "homing_guidance", "armor_piercing_core", "chain_explosion",
	"mine_round", "cluster_warhead", "burning_zone", "shockwave_round", "shrapnel_storm",
	"siege_warhead", "dash", "stomp", "sweeping_slash", "suppression", "taunt_guard",
	"focus_mark", "aerial_evade", "meteor", "guardian", "auto_turret", "repair_drone",
	"self_repair", "tactical_shield", "last_stand", "lifesteal", "reactive_armor",
	"evade_drill", "air_flares", "healing_mastery", "group_heal", "cleanse", "holy_shield",
	"resurrection_ritual", "soul_shelter", "guardian_aura", "battlefield_repair",
	"toxic_payload", "execution_protocol", "gravity_warhead", "temporal_echo",
	"overcharge_capacitor", "kinetic_barrier", "rally_beacon", "overheal_matrix",
	"vengeance_counter", "salvage_protocol",
]

## Special prices are stored as rank-I base prices. next_rank_cost() applies
## [P, 2P, 4P], then the soldier multiplier, and finally rounds upward to 100.
## Each rank_effects entry is the complete effect for that rank (not an increment).
const SPECIAL_ABILITIES: Dictionary = {
	"burning_sword": {
		"name": {"zh_TW": "燃燒劍", "en": "Burning Sword"},
		"summary": {"zh_TW": "斬擊附加會在數秒內結算的燃燒傷害。", "en": "Slashes inflict burning damage over time."},
		"base_price": 30000, "related_base": "attack_or_healing",
		"compatible_types": ["swordsman", "heavy"],
		"rank_effects": [
			{"total_burn_ratio": 0.24, "duration": 3.0},
			{"total_burn_ratio": 0.36, "duration": 3.0},
			{"total_burn_ratio": 0.50, "duration": 4.0},
		],
	},
	"burning_ammo": {
		"name": {"zh_TW": "燃燒彈藥", "en": "Burning Ammunition"},
		"summary": {"zh_TW": "遠程命中附加燃燒；同一來源對同一目標有觸發間隔。", "en": "Ranged hits burn targets with a per-source/target trigger interval."},
		"base_price": 28000, "related_base": "attack_or_healing",
		"compatible_types": ["archer", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber"],
		"rank_effects": [
			{"total_burn_ratio": 0.18, "duration": 3.0, "source_target_proc_cooldown": 0.7},
			{"total_burn_ratio": 0.28, "duration": 3.0, "source_target_proc_cooldown": 0.7},
			{"total_burn_ratio": 0.40, "duration": 3.0, "source_target_proc_cooldown": 0.7},
		],
	},
	"frost_arrow": {
		"name": {"zh_TW": "冰霜箭", "en": "Frost Arrow"},
		"summary": {"zh_TW": "箭矢造成減速；Boss 僅承受較弱的減速。", "en": "Arrows slow normal targets and apply a weaker slow to bosses."},
		"base_price": 32000, "related_base": "range", "compatible_types": ["archer"],
		"rank_effects": [
			{"slow_ratio": 0.25, "duration": 2.0, "boss_slow_ratio": 0.08},
			{"slow_ratio": 0.32, "duration": 2.5, "boss_slow_ratio": 0.10},
			{"slow_ratio": 0.40, "duration": 3.0, "boss_slow_ratio": 0.12},
		],
	},
	"paralysis_arrow": {
		"name": {"zh_TW": "麻痺箭", "en": "Paralysis Arrow"},
		"summary": {"zh_TW": "固定箭數後麻痺普通敵人；對 Boss 改為弱減速。", "en": "Every few arrows stun normal enemies; bosses receive a weak slow instead."},
		"base_price": 45000, "related_base": "critical", "compatible_types": ["archer"],
		"rank_effects": [
			{"arrow_interval": 7, "normal_stun": 0.45, "boss_replacement": "weak_slow"},
			{"arrow_interval": 6, "normal_stun": 0.65, "boss_replacement": "weak_slow"},
			{"arrow_interval": 5, "normal_stun": 0.85, "boss_replacement": "weak_slow"},
		],
	},
	"chain_lightning": {
		"name": {"zh_TW": "連鎖閃電", "en": "Chain Lightning"},
		"summary": {"zh_TW": "命中後跳向額外目標並保留部分傷害。", "en": "Hits jump to extra targets while retaining part of the damage."},
		"base_price": 48000, "related_base": "critical",
		"compatible_types": ["mage", "musketeer", "rifleman", "gatling", "helicopter", "ufo"],
		"rank_effects": [
			{"jumps": 2, "jump_damage_ratio": 0.35, "jump_range": 240.0},
			{"jumps": 3, "jump_damage_ratio": 0.40, "jump_range": 240.0},
			{"jumps": 4, "jump_damage_ratio": 0.45, "jump_range": 240.0},
		],
	},
	"corrosion": {
		"name": {"zh_TW": "腐蝕", "en": "Corrosion"},
		"summary": {"zh_TW": "攻擊暫時削減目標裝甲，最多疊加兩層。", "en": "Temporarily reduces target armor, stacking up to twice."},
		"base_price": 42000, "related_base": "attack_or_healing",
		"compatible_types": ["roller", "cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"armor_reduction": 3.0, "duration": 4.0, "max_stacks": 2},
			{"armor_reduction": 5.0, "duration": 4.0, "max_stacks": 2},
			{"armor_reduction": 7.0, "duration": 4.0, "max_stacks": 2},
		],
	},
	"void_mark": {
		"name": {"zh_TW": "虛空印記", "en": "Void Mark"},
		"summary": {"zh_TW": "標記目標，使其承受更多士兵傷害。", "en": "Marks a target to increase damage taken from soldiers."},
		"base_price": 70000, "related_base": "range", "compatible_types": ["mage", "priest", "ufo"],
		"rank_effects": [
			{"soldier_damage_taken_bonus": 0.04, "duration": 4.0},
			{"soldier_damage_taken_bonus": 0.06, "duration": 4.0},
			{"soldier_damage_taken_bonus": 0.08, "duration": 4.0},
		],
	},
	"split_shot": {
		"name": {"zh_TW": "分裂射擊", "en": "Split Shot"},
		"summary": {"zh_TW": "額外射出兩枚低傷害投射物。", "en": "Fires two additional reduced-damage projectiles."},
		"base_price": 38000, "related_base": "range",
		"compatible_types": ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber"],
		"rank_effects": [
			{"extra_projectiles": 2, "spread_degrees": 12.0, "damage_ratio": 0.12},
			{"extra_projectiles": 2, "spread_degrees": 16.0, "damage_ratio": 0.18},
			{"extra_projectiles": 2, "spread_degrees": 20.0, "damage_ratio": 0.24},
		],
	},
	"piercing_arrow": {
		"name": {"zh_TW": "穿刺箭", "en": "Piercing Arrow"},
		"summary": {"zh_TW": "箭矢可額外穿過敵人並保留大部分傷害。", "en": "Arrows pierce extra enemies while retaining most damage."},
		"base_price": 34000, "related_base": "range", "compatible_types": ["archer"],
		"rank_effects": [
			{"extra_pierce": 2, "retained_damage_ratio": 0.80},
			{"extra_pierce": 3, "retained_damage_ratio": 0.84},
			{"extra_pierce": 4, "retained_damage_ratio": 0.88},
		],
	},
	"penetrating_round": {
		"name": {"zh_TW": "貫穿彈", "en": "Penetrating Round"},
		"summary": {"zh_TW": "實彈可額外貫穿目標並保留部分傷害。", "en": "Ballistic rounds penetrate extra targets with retained damage."},
		"base_price": 40000, "related_base": "range",
		"compatible_types": ["musketeer", "rifleman", "gatling", "helicopter"],
		"rank_effects": [
			{"extra_pierce": 1, "retained_damage_ratio": 0.70},
			{"extra_pierce": 2, "retained_damage_ratio": 0.75},
			{"extra_pierce": 3, "retained_damage_ratio": 0.80},
		],
	},
	"ricochet": {
		"name": {"zh_TW": "跳彈", "en": "Ricochet"},
		"summary": {"zh_TW": "投射物從首個目標彈向額外敵人。", "en": "Projectiles bounce from the first target to extra enemies."},
		"base_price": 46000, "related_base": "critical",
		"compatible_types": ["archer", "musketeer", "rifleman", "gatling", "helicopter"],
		"rank_effects": [
			{"extra_targets": 1, "ricochet_damage_ratio": 0.45, "ricochet_range": 280.0},
			{"extra_targets": 2, "ricochet_damage_ratio": 0.48, "ricochet_range": 280.0},
			{"extra_targets": 3, "ricochet_damage_ratio": 0.52, "ricochet_range": 280.0},
		],
	},
	"lingering_projectile": {
		"name": {"zh_TW": "滯留彈體", "en": "Lingering Projectile"},
		"summary": {"zh_TW": "首擊後投射物滯留並持續傷害；設有單位與全隊上限。", "en": "Projectiles linger after first impact and deal capped periodic damage."},
		"base_price": 60000, "related_base": "range",
		"compatible_types": ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber"],
		"rank_effects": [
			{"first_hit_ratio": 0.70, "linger_duration": 2.0, "tick_interval": 0.5, "tick_damage_ratio": 0.12, "max_per_unit": 2, "team_cap": 16},
			{"first_hit_ratio": 0.70, "linger_duration": 3.0, "tick_interval": 0.5, "tick_damage_ratio": 0.14, "max_per_unit": 2, "team_cap": 16},
			{"first_hit_ratio": 0.70, "linger_duration": 4.0, "tick_interval": 0.5, "tick_damage_ratio": 0.16, "max_per_unit": 2, "team_cap": 16},
		],
	},
	"homing_guidance": {
		"name": {"zh_TW": "導引追蹤", "en": "Homing Guidance"},
		"summary": {"zh_TW": "投射物在消失前以限制轉向速度追蹤目標。", "en": "Projectiles home until expiry at a capped turn rate."},
		"base_price": 44000, "related_base": "range",
		"compatible_types": ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"turn_degrees_per_second": 100.0, "until_expiry": true},
			{"turn_degrees_per_second": 150.0, "until_expiry": true},
			{"turn_degrees_per_second": 210.0, "until_expiry": true},
		],
	},
	"armor_piercing_core": {
		"name": {"zh_TW": "破甲核心", "en": "Armor-Piercing Core"},
		"summary": {"zh_TW": "攻擊忽略固定數值的敵方裝甲。", "en": "Attacks ignore a flat amount of target armor."},
		"base_price": 36000, "related_base": "attack_or_healing",
		"compatible_types": ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"ignored_armor": 6.0}, {"ignored_armor": 12.0}, {"ignored_armor": 18.0},
		],
	},
	"chain_explosion": {
		"name": {"zh_TW": "連鎖爆炸", "en": "Chain Explosion"},
		"summary": {"zh_TW": "主爆炸後依序觸發數次遞減爆炸。", "en": "The primary blast triggers a sequence of diminishing explosions."},
		"base_price": 70000, "related_base": "attack_or_healing",
		"compatible_types": ["mage", "cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"extra_blasts": 2, "blast_damage_ratios": [0.45, 0.35]},
			{"extra_blasts": 3, "blast_damage_ratios": [0.45, 0.35, 0.25]},
			{"extra_blasts": 4, "blast_damage_ratios": [0.45, 0.35, 0.25, 0.18]},
		],
	},
	"mine_round": {
		"name": {"zh_TW": "地雷彈", "en": "Mine Round"},
		"summary": {"zh_TW": "命中只結算部分傷害並落下延時地雷；設有單位與全隊上限。", "en": "Impacts deal partial damage and drop an armed mine with unit/team caps."},
		"base_price": 62000, "related_base": "range",
		"compatible_types": ["cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"impact_damage_ratio": 0.30, "arming_time": 0.70, "mine_ttl": 7.0, "trigger_damage_ratio": 1.20, "trigger_radius": 78.0, "max_per_unit": 2, "team_cap": 24},
			{"impact_damage_ratio": 0.30, "arming_time": 0.55, "mine_ttl": 9.0, "trigger_damage_ratio": 1.45, "trigger_radius": 84.0, "max_per_unit": 3, "team_cap": 24},
			{"impact_damage_ratio": 0.30, "arming_time": 0.40, "mine_ttl": 12.0, "trigger_damage_ratio": 1.75, "trigger_radius": 92.0, "max_per_unit": 4, "team_cap": 24},
		],
	},
	"cluster_warhead": {
		"name": {"zh_TW": "集束彈頭", "en": "Cluster Warhead"},
		"summary": {"zh_TW": "主爆炸降低部分威力並散出多枚小炸彈。", "en": "Trades some primary blast damage for multiple bomblets."},
		"base_price": 78000, "related_base": "attack_or_healing",
		"compatible_types": ["cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"main_damage_ratio": 0.70, "bomblets": 3, "bomblet_damage_ratio": 0.25},
			{"main_damage_ratio": 0.75, "bomblets": 4, "bomblet_damage_ratio": 0.27},
			{"main_damage_ratio": 0.80, "bomblets": 5, "bomblet_damage_ratio": 0.30},
		],
	},
	"burning_zone": {
		"name": {"zh_TW": "燃燒區域", "en": "Burning Zone"},
		"summary": {"zh_TW": "爆炸留下固定頻率造成傷害的燃燒區。", "en": "Explosions leave a burning zone that ticks at a fixed interval."},
		"base_price": 58000, "related_base": "attack_or_healing",
		"compatible_types": ["mage", "cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"zone_ttl": 3.0, "tick_interval": 0.5, "tick_damage_ratio": 0.08},
			{"zone_ttl": 4.0, "tick_interval": 0.5, "tick_damage_ratio": 0.10},
			{"zone_ttl": 5.0, "tick_interval": 0.5, "tick_damage_ratio": 0.12},
		],
	},
	"shockwave_round": {
		"name": {"zh_TW": "衝擊波彈", "en": "Shockwave Round"},
		"summary": {"zh_TW": "爆炸擊退並減速；第三階對普通敵人附加短暫暈眩。", "en": "Blasts knock back and slow; rank III briefly stuns normal enemies."},
		"base_price": 42000, "related_base": "attack_or_healing",
		"compatible_types": ["roller", "cannon", "tank", "rocket"],
		"rank_effects": [
			{"knockback": 60.0, "applies_slow": true, "slow_ratio": 0.20, "slow_duration": 1.5, "normal_stun": 0.0},
			{"knockback": 85.0, "applies_slow": true, "slow_ratio": 0.25, "slow_duration": 1.5, "normal_stun": 0.0},
			{"knockback": 110.0, "applies_slow": true, "slow_ratio": 0.30, "slow_duration": 1.5, "normal_stun": 0.45},
		],
	},
	"shrapnel_storm": {
		"name": {"zh_TW": "榴霰風暴", "en": "Shrapnel Storm"},
		"summary": {"zh_TW": "爆炸散出碎片，同一目標最多被兩片命中。", "en": "Blasts scatter shards; the same target can be hit at most twice."},
		"base_price": 50000, "related_base": "critical",
		"compatible_types": ["cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"shards": 6, "shard_damage_ratio": 0.15, "same_target_hit_cap": 2},
			{"shards": 8, "shard_damage_ratio": 0.17, "same_target_hit_cap": 2},
			{"shards": 10, "shard_damage_ratio": 0.20, "same_target_hit_cap": 2},
		],
	},
	"siege_warhead": {
		"name": {"zh_TW": "攻城彈頭", "en": "Siege Warhead"},
		"summary": {"zh_TW": "提高對建築傷害，且仍遵守城門與城牆規則。", "en": "Increases structure damage while respecting gate and wall rules."},
		"base_price": 55000, "related_base": "attack_or_healing",
		"compatible_types": ["cannon", "tank", "rocket", "bomber"],
		"rank_effects": [
			{"structure_damage_bonus": 0.25, "respects_gate": true},
			{"structure_damage_bonus": 0.45, "respects_gate": true},
			{"structure_damage_bonus": 0.70, "respects_gate": true},
		],
	},
	"dash": {
		"name": {"zh_TW": "衝刺", "en": "Dash"},
		"summary": {"zh_TW": "定期向目標衝刺攻擊，期間減少一半傷害。", "en": "Periodically dashes through a target with 50% damage reduction."},
		"base_price": 42000, "related_base": "move_speed", "compatible_types": ["swordsman", "heavy"],
		"rank_effects": [
			{"cooldown": 7.0, "distance": 120.0, "damage_ratio": 1.20, "during_dash_damage_reduction": 0.50},
			{"cooldown": 6.0, "distance": 150.0, "damage_ratio": 1.40, "during_dash_damage_reduction": 0.50},
			{"cooldown": 5.0, "distance": 180.0, "damage_ratio": 1.65, "during_dash_damage_reduction": 0.50},
		],
	},
	"stomp": {
		"name": {"zh_TW": "踐踏", "en": "Stomp"},
		"summary": {"zh_TW": "近身造成範圍傷害與短暫暈眩。", "en": "Deals nearby area damage with a short stun."},
		"base_price": 50000, "related_base": "max_hp", "compatible_types": ["heavy", "tank"],
		"rank_effects": [
			{"radius": 105.0, "damage_ratio": 0.65, "applies_short_stun": true, "stun_duration": 0.45, "cooldown": 5.5},
			{"radius": 125.0, "damage_ratio": 0.85, "applies_short_stun": true, "stun_duration": 0.55, "cooldown": 5.0},
			{"radius": 145.0, "damage_ratio": 1.10, "applies_short_stun": true, "stun_duration": 0.65, "cooldown": 4.5},
		],
	},
	"sweeping_slash": {
		"name": {"zh_TW": "橫掃斬", "en": "Sweeping Slash"},
		"summary": {"zh_TW": "近戰攻擊額外命中多名目標。", "en": "Melee attacks sweep through additional targets."},
		"base_price": 34000, "related_base": "attack_or_healing", "compatible_types": ["swordsman", "heavy"],
		"rank_effects": [
			{"extra_targets": 2, "sweep_damage_ratio": 0.60},
			{"extra_targets": 3, "sweep_damage_ratio": 0.70},
			{"extra_targets": 4, "sweep_damage_ratio": 0.80},
		],
	},
	"suppression": {
		"name": {"zh_TW": "壓制", "en": "Suppression"},
		"summary": {"zh_TW": "累積命中後降低目標移動與攻擊速度；Boss 效果較弱。", "en": "Repeated hits reduce movement and attack speed, with a reduced boss effect."},
		"base_price": 44000, "related_base": "attack_or_support_speed",
		"compatible_types": ["archer", "musketeer", "rifleman", "gatling", "helicopter", "ufo"],
		"rank_effects": [
			{"hit_threshold": 6, "move_reduction": 0.20, "attack_speed_reduction": 0.10, "effect_duration": 3.5, "boss_reduced": true},
			{"hit_threshold": 5, "move_reduction": 0.25, "attack_speed_reduction": 0.15, "effect_duration": 3.5, "boss_reduced": true},
			{"hit_threshold": 4, "move_reduction": 0.30, "attack_speed_reduction": 0.20, "effect_duration": 3.5, "boss_reduced": true},
		],
	},
	"taunt_guard": {
		"name": {"zh_TW": "嘲諷守勢", "en": "Taunting Guard"},
		"summary": {"zh_TW": "吸引附近普通敵軍並降低自身傷害；對 Boss 只增加威脅值。", "en": "Taunts nearby normal enemies and grants self mitigation; bosses only gain threat."},
		"base_price": 46000, "related_base": "armor", "compatible_types": ["swordsman", "heavy", "tank"],
		"rank_effects": [
			{"radius": 160.0, "self_damage_reduction": 0.10, "boss_threat_only": true},
			{"radius": 180.0, "self_damage_reduction": 0.14, "boss_threat_only": true},
			{"radius": 200.0, "self_damage_reduction": 0.18, "boss_threat_only": true},
		],
	},
	"focus_mark": {
		"name": {"zh_TW": "集火印記", "en": "Focus Mark"},
		"summary": {"zh_TW": "讓其他友軍對標記目標造成更多傷害；Boss 效果減半。", "en": "Other allies deal more damage to the marked target; the boss bonus is halved."},
		"base_price": 48000, "related_base": "critical",
		"compatible_types": ["archer", "mage", "priest", "musketeer", "rifleman", "gatling", "helicopter", "ufo"],
		"rank_effects": [
			{"other_ally_damage_bonus": 0.05, "effect_duration": 4.0, "boss_multiplier": 0.50},
			{"other_ally_damage_bonus": 0.07, "effect_duration": 4.0, "boss_multiplier": 0.50},
			{"other_ally_damage_bonus": 0.10, "effect_duration": 4.0, "boss_multiplier": 0.50},
		],
	},
	"aerial_evade": {
		"name": {"zh_TW": "空中迴避", "en": "Aerial Evade"},
		"summary": {"zh_TW": "空軍定期側移閃避，移動期間減少一半傷害。", "en": "Air units periodically sidestep with 50% damage reduction."},
		"base_price": 52000, "related_base": "move_speed", "compatible_types": AIR_TYPES,
		"rank_effects": [
			{"cooldown": 8.0, "sidestep_distance": 100.0, "damage_reduction": 0.50},
			{"cooldown": 7.0, "sidestep_distance": 130.0, "damage_reduction": 0.50},
			{"cooldown": 6.0, "sidestep_distance": 160.0, "damage_reduction": 0.50},
		],
	},
	"meteor": {
		"name": {"zh_TW": "隕星術", "en": "Meteor"},
		"summary": {"zh_TW": "全軍共用冷卻的預警範圍轟擊。", "en": "A telegraphed area strike with an army-wide shared cooldown."},
		"base_price": 120000, "related_base": "attack_or_healing",
		"compatible_types": ["mage", "rocket", "bomber", "ufo"],
		"rank_effects": [
			{"army_shared_cooldown": 16.0, "warning_time": 1.2, "damage_ratio": 2.20, "radius": 120.0},
			{"army_shared_cooldown": 14.0, "warning_time": 1.2, "damage_ratio": 2.80, "radius": 145.0},
			{"army_shared_cooldown": 12.0, "warning_time": 1.2, "damage_ratio": 3.50, "radius": 170.0},
		],
	},
	"guardian": {
		"name": {"zh_TW": "守護者召喚", "en": "Guardian Summon"},
		"summary": {"zh_TW": "召喚限時守護者；召喚物不可再召喚。", "en": "Summons temporary guardians that cannot summon recursively."},
		"base_price": 95000, "related_base": "max_hp", "compatible_types": ["mage", "priest"],
		"rank_effects": [
			{"ttl": 14.0, "hp_ratio": 1.60, "attack_ratio": 0.45, "attack_range": 280.0, "attack_interval": 1.10, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
			{"ttl": 18.0, "hp_ratio": 2.10, "attack_ratio": 0.55, "attack_range": 300.0, "attack_interval": 1.00, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
			{"ttl": 22.0, "hp_ratio": 2.70, "attack_ratio": 0.65, "attack_range": 320.0, "attack_interval": 0.90, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
		],
	},
	"auto_turret": {
		"name": {"zh_TW": "自動砲塔", "en": "Auto Turret"},
		"summary": {"zh_TW": "部署限時自動砲塔；召喚物不可再召喚。", "en": "Deploys temporary auto turrets that cannot summon recursively."},
		"base_price": 90000, "related_base": "attack_or_healing",
		"compatible_types": ["cannon", "rifleman", "tank", "gatling"],
		"rank_effects": [
			{"ttl": 14.0, "shots_per_second": 2.0, "shot_damage_ratio": 0.25, "attack_range": 500.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
			{"ttl": 18.0, "shots_per_second": 2.0, "shot_damage_ratio": 0.30, "attack_range": 520.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
			{"ttl": 22.0, "shots_per_second": 2.0, "shot_damage_ratio": 0.35, "attack_range": 540.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED},
		],
	},
	"repair_drone": {
		"name": {"zh_TW": "維修無人機", "en": "Repair Drone"},
		"summary": {"zh_TW": "召喚維修無人機，持續治療載具與空軍。", "en": "Summons repair drones that heal vehicles and air units over time."},
		"base_price": 80000, "related_base": "attack_or_healing", "compatible_types": ["healer", "priest"],
		"rank_effects": [
			{"duration": 5.0, "max_hp_heal_per_second": 0.025, "healing_range": 360.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED, "target_roles": ["vehicle", "air"]},
			{"duration": 5.0, "max_hp_heal_per_second": 0.035, "healing_range": 390.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED, "target_roles": ["vehicle", "air"]},
			{"duration": 5.0, "max_hp_heal_per_second": 0.045, "healing_range": 420.0, "max_per_owner": 2, "team_summon_cap": SUMMON_TEAM_CAP, "recursive_summoning": SUMMON_RECURSIVE_ALLOWED, "target_roles": ["vehicle", "air"]},
		],
	},
	"self_repair": {
		"name": {"zh_TW": "自我修復", "en": "Self Repair"},
		"summary": {"zh_TW": "一段時間未受擊後，持續回復最大生命比例。", "en": "Regenerates a percentage of maximum health after avoiding damage."},
		"base_price": 35000, "related_base": "max_hp",
		"compatible_types": ["roller", "cannon", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"no_hit_delay": 5.0, "max_hp_heal_per_second": 0.008},
			{"no_hit_delay": 4.0, "max_hp_heal_per_second": 0.011},
			{"no_hit_delay": 3.0, "max_hp_heal_per_second": 0.014},
		],
	},
	"tactical_shield": {
		"name": {"zh_TW": "戰術護盾", "en": "Tactical Shield"},
		"summary": {"zh_TW": "生成按最大生命計算的護盾；長時間未受擊後充能。", "en": "Grants a max-health shield that recharges after avoiding damage."},
		"base_price": 48000, "related_base": "max_hp", "compatible_types": SOLDIER_ORDER,
		"rank_effects": [
			{"shield_max_hp_ratio": 0.12, "recharge_no_hit_time": 12.0},
			{"shield_max_hp_ratio": 0.18, "recharge_no_hit_time": 12.0},
			{"shield_max_hp_ratio": 0.25, "recharge_no_hit_time": 12.0},
		],
	},
	"last_stand": {
		"name": {"zh_TW": "背水一戰", "en": "Last Stand"},
		"summary": {"zh_TW": "每次生命僅一次，以 1 HP 承受致命傷並獲得短暫無敵與恢復。", "en": "Once per life, survives lethal damage at 1 HP with brief invulnerability and recovery."},
		"base_price": 72000, "related_base": "max_hp", "compatible_types": SOLDIER_ORDER,
		"rank_effects": [
			{"once_per_life": true, "survive_hp": 1.0, "invulnerability": 0.6, "grants_recovery": true, "recovery_max_hp_ratio": 0.12, "recovery_duration": 3.0},
			{"once_per_life": true, "survive_hp": 1.0, "invulnerability": 0.9, "grants_recovery": true, "recovery_max_hp_ratio": 0.18, "recovery_duration": 3.0},
			{"once_per_life": true, "survive_hp": 1.0, "invulnerability": 1.2, "grants_recovery": true, "recovery_max_hp_ratio": 0.25, "recovery_duration": 3.0},
		],
	},
	"lifesteal": {
		"name": {"zh_TW": "吸血", "en": "Lifesteal"},
		"summary": {"zh_TW": "按造成傷害回復生命，並受每秒上限限制。", "en": "Restores health from damage dealt, subject to a per-second cap."},
		"base_price": 50000, "related_base": "critical",
		"compatible_types": ["swordsman", "archer", "roller", "mage", "heavy", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"lifesteal_ratio": 0.03, "max_hp_heal_cap_per_second_ratio": 0.06, "cap_mode": "per_second"},
			{"lifesteal_ratio": 0.04, "max_hp_heal_cap_per_second_ratio": 0.06, "cap_mode": "per_second"},
			{"lifesteal_ratio": 0.05, "max_hp_heal_cap_per_second_ratio": 0.06, "cap_mode": "per_second"},
		],
	},
	"reactive_armor": {
		"name": {"zh_TW": "反應裝甲", "en": "Reactive Armor"},
		"summary": {"zh_TW": "定期減免下一次投射物或範圍傷害。", "en": "Periodically mitigates the next projectile or area hit."},
		"base_price": 48000, "related_base": "armor",
		"compatible_types": ["roller", "heavy", "cannon", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"cooldown": 8.0, "next_projectile_or_area_reduction": 0.35},
			{"cooldown": 7.0, "next_projectile_or_area_reduction": 0.45},
			{"cooldown": 6.0, "next_projectile_or_area_reduction": 0.55},
		],
	},
	"evade_drill": {
		"name": {"zh_TW": "閃避操練", "en": "Evasion Drill"},
		"summary": {"zh_TW": "定期側移閃避投射物並短暫無敵，不適用光束、地面區域或抓取。", "en": "Sidesteps projectiles with brief invulnerability; beams, ground zones, and grabs are excluded."},
		"base_price": 55000, "related_base": "move_speed",
		"compatible_types": ["swordsman", "healer", "archer", "mage", "priest", "musketeer", "rifleman", "gatling"],
		"rank_effects": [
			{"cooldown": 8.0, "sidestep_distance": 100.0, "invulnerability": 0.25, "excluded_damage_kinds": ["beam", "ground", "grab"]},
			{"cooldown": 7.0, "sidestep_distance": 130.0, "invulnerability": 0.25, "excluded_damage_kinds": ["beam", "ground", "grab"]},
			{"cooldown": 6.0, "sidestep_distance": 160.0, "invulnerability": 0.25, "excluded_damage_kinds": ["beam", "ground", "grab"]},
		],
	},
	"air_flares": {
		"name": {"zh_TW": "空中熱焰彈", "en": "Air Flares"},
		"summary": {"zh_TW": "空軍定期攔截追蹤投射物。", "en": "Air units periodically intercept homing projectiles."},
		"base_price": 70000, "related_base": "move_speed", "compatible_types": AIR_TYPES,
		"rank_effects": [
			{"cooldown": 14.0, "intercepts_homing": true, "air_only": true},
			{"cooldown": 12.0, "intercepts_homing": true, "air_only": true},
			{"cooldown": 10.0, "intercepts_homing": true, "air_only": true},
		],
	},
	"healing_mastery": {
		"name": {"zh_TW": "療癒精通", "en": "Healing Mastery"},
		"summary": {"zh_TW": "直接提高治療量。", "en": "Directly increases healing output."},
		"base_price": 28000, "related_base": "attack_or_healing", "compatible_types": SUPPORT_TYPES,
		"rank_effects": [
			{"healing_bonus": 0.20}, {"healing_bonus": 0.35}, {"healing_bonus": 0.50},
		],
	},
	"group_heal": {
		"name": {"zh_TW": "群體治療", "en": "Group Heal"},
		"summary": {"zh_TW": "每第三次治療同時治療多名友軍。", "en": "Every third heal also heals several allies."},
		"base_price": 48000, "related_base": "attack_or_healing", "compatible_types": ["healer"],
		"rank_effects": [
			{"trigger_every_heals": 3, "allies": 3, "healing_ratio": 0.50},
			{"trigger_every_heals": 3, "allies": 4, "healing_ratio": 0.70},
			{"trigger_every_heals": 3, "allies": 5, "healing_ratio": 0.90},
		],
	},
	"cleanse": {
		"name": {"zh_TW": "淨化", "en": "Cleanse"},
		"summary": {"zh_TW": "定期移除燃燒、減速與麻痺。", "en": "Periodically removes burn, slow, and paralysis."},
		"base_price": 55000, "related_base": "attack_or_support_speed", "compatible_types": SUPPORT_TYPES,
		"rank_effects": [
			{"cooldown": 10.0, "removes": ["burn", "slow", "paralysis"]},
			{"cooldown": 8.0, "removes": ["burn", "slow", "paralysis"]},
			{"cooldown": 6.0, "removes": ["burn", "slow", "paralysis"]},
		],
	},
	"holy_shield": {
		"name": {"zh_TW": "聖盾", "en": "Holy Shield"},
		"summary": {"zh_TW": "治療時賦予短暫護盾；同一目標有獨立冷卻。", "en": "Healing grants a temporary shield with a per-target cooldown."},
		"base_price": 60000, "related_base": "attack_or_healing", "compatible_types": SUPPORT_TYPES,
		"rank_effects": [
			{"shield_max_hp_ratio": 0.08, "duration": 4.0, "target_cooldown": 10.0},
			{"shield_max_hp_ratio": 0.12, "duration": 4.0, "target_cooldown": 10.0},
			{"shield_max_hp_ratio": 0.16, "duration": 4.0, "target_cooldown": 10.0},
		],
	},
	"resurrection_ritual": {
		"name": {"zh_TW": "復活儀式", "en": "Resurrection Ritual"},
		"summary": {"zh_TW": "縮短吟唱與冷卻，並提高復活生命比例。", "en": "Shortens resurrection chant/cooldown and raises revived health."},
		"base_price": 70000, "related_base": "attack_or_support_speed", "compatible_types": ["priest"],
		"rank_effects": [
			{"chant_time": 2.3, "cooldown": 12.0, "revive_hp_ratio": 0.55},
			{"chant_time": 1.9, "cooldown": 10.0, "revive_hp_ratio": 0.65},
			{"chant_time": 1.6, "cooldown": 8.0, "revive_hp_ratio": 0.75},
		],
	},
	"soul_shelter": {
		"name": {"zh_TW": "靈魂庇護", "en": "Soul Shelter"},
		"summary": {"zh_TW": "延長墓碑時間，復活後短暫減傷。", "en": "Extends tombstone lifetime and grants post-revival mitigation."},
		"base_price": 90000, "related_base": "max_hp", "compatible_types": ["priest"],
		"rank_effects": [
			{"tombstone_bonus_seconds": 6.0, "revived_damage_reduction": 0.30, "reduction_duration": 3.0},
			{"tombstone_bonus_seconds": 12.0, "revived_damage_reduction": 0.45, "reduction_duration": 3.0},
			{"tombstone_bonus_seconds": 18.0, "revived_damage_reduction": 0.60, "reduction_duration": 3.0},
		],
	},
	"guardian_aura": {
		"name": {"zh_TW": "守護光環", "en": "Guardian Aura"},
		"summary": {"zh_TW": "降低範圍友軍承傷；重疊時只採最強效果。", "en": "Reduces allied damage taken in an aura; only the strongest aura applies."},
		"base_price": 65000, "related_base": "armor", "compatible_types": ["healer", "heavy", "priest", "tank"],
		"rank_effects": [
			{"radius": 180.0, "ally_damage_reduction": 0.04, "stack_rule": "strongest_only"},
			{"radius": 210.0, "ally_damage_reduction": 0.06, "stack_rule": "strongest_only"},
			{"radius": 240.0, "ally_damage_reduction": 0.08, "stack_rule": "strongest_only"},
		],
	},
	"battlefield_repair": {
		"name": {"zh_TW": "戰地維修", "en": "Battlefield Repair"},
		"summary": {"zh_TW": "醫者對載具與空軍的治療大幅提高。", "en": "Greatly increases healer output on vehicles and air units."},
		"base_price": 52000, "related_base": "attack_or_healing", "compatible_types": ["healer"],
		"rank_effects": [
			{"vehicle_air_healing_bonus": 0.60, "target_roles": ["vehicle", "air"]},
			{"vehicle_air_healing_bonus": 0.80, "target_roles": ["vehicle", "air"]},
			{"vehicle_air_healing_bonus": 1.00, "target_roles": ["vehicle", "air"]},
		],
	},
	"toxic_payload": {
		"name": {"zh_TW": "毒素載荷", "en": "Toxic Payload"},
		"summary": {"zh_TW": "命中累積可疊加的持續毒素傷害。", "en": "Hits apply stacking poison damage over time."},
		"base_price": 46000, "related_base": "attack_or_healing",
		"compatible_types": ["archer", "roller", "mage", "musketeer", "rifleman", "gatling", "helicopter"],
		"rank_effects": [
			{"total_poison_ratio": 0.18, "duration": 5.0, "max_stacks": 3},
			{"total_poison_ratio": 0.30, "duration": 5.0, "max_stacks": 3},
			{"total_poison_ratio": 0.45, "duration": 5.0, "max_stacks": 3},
		],
	},
	"execution_protocol": {
		"name": {"zh_TW": "處決協定", "en": "Execution Protocol"},
		"summary": {"zh_TW": "對低生命敵人造成更高傷害。", "en": "Deals increased damage to low-health enemies."},
		"base_price": 68000, "related_base": "critical",
		"compatible_types": ["swordsman", "archer", "roller", "mage", "heavy", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"threshold": 0.25, "damage_bonus": 0.35},
			{"threshold": 0.30, "damage_bonus": 0.45},
			{"threshold": 0.35, "damage_bonus": 0.60},
		],
	},
	"gravity_warhead": {
		"name": {"zh_TW": "重力彈頭", "en": "Gravity Warhead"},
		"summary": {"zh_TW": "命中形成牽引敵軍並減速的重力場。", "en": "Impacts create a gravity field that pulls and slows enemies."},
		"base_price": 88000, "related_base": "range",
		"compatible_types": ["mage", "cannon", "tank", "rocket", "bomber", "ufo"],
		"rank_effects": [
			{"radius": 130.0, "pull_distance": 70.0, "slow_ratio": 0.15, "duration": 2.5},
			{"radius": 160.0, "pull_distance": 100.0, "slow_ratio": 0.22, "duration": 2.5},
			{"radius": 190.0, "pull_distance": 130.0, "slow_ratio": 0.30, "duration": 2.5},
		],
	},
	"temporal_echo": {
		"name": {"zh_TW": "時序回響", "en": "Temporal Echo"},
		"summary": {"zh_TW": "固定攻擊次數後延遲重現一次較弱攻擊。", "en": "Repeats a reduced attack after a fixed number of attacks."},
		"base_price": 82000, "related_base": "attack_or_support_speed",
		"compatible_types": ["archer", "mage", "musketeer", "rifleman", "rocket", "ufo"],
		"rank_effects": [
			{"every_attacks": 6, "echo_delay": 0.35, "echo_damage_ratio": 0.45},
			{"every_attacks": 5, "echo_delay": 0.35, "echo_damage_ratio": 0.55},
			{"every_attacks": 4, "echo_delay": 0.35, "echo_damage_ratio": 0.70},
		],
	},
	"overcharge_capacitor": {
		"name": {"zh_TW": "超載電容", "en": "Overcharge Capacitor"},
		"summary": {"zh_TW": "固定攻擊次數後釋放高傷害的擴大超載攻擊。", "en": "Periodically releases an amplified attack with an expanded blast."},
		"base_price": 76000, "related_base": "critical",
		"compatible_types": ["roller", "mage", "cannon", "tank", "rocket", "gatling", "helicopter", "ufo"],
		"rank_effects": [
			{"every_attacks": 7, "damage_multiplier": 1.60, "bonus_radius": 35.0},
			{"every_attacks": 6, "damage_multiplier": 1.80, "bonus_radius": 50.0},
			{"every_attacks": 5, "damage_multiplier": 2.10, "bonus_radius": 70.0},
		],
	},
	"kinetic_barrier": {
		"name": {"zh_TW": "動能屏障", "en": "Kinetic Barrier"},
		"summary": {"zh_TW": "累積移動距離後生成短暫生命護盾。", "en": "Builds a temporary health shield after travelling enough distance."},
		"base_price": 58000, "related_base": "move_speed",
		"compatible_types": ["swordsman", "roller", "heavy", "tank", "helicopter"],
		"rank_effects": [
			{"move_distance": 300.0, "shield_max_hp_ratio": 0.06, "duration": 5.0},
			{"move_distance": 260.0, "shield_max_hp_ratio": 0.09, "duration": 5.0},
			{"move_distance": 220.0, "shield_max_hp_ratio": 0.12, "duration": 5.0},
		],
	},
	"rally_beacon": {
		"name": {"zh_TW": "集結信標", "en": "Rally Beacon"},
		"summary": {"zh_TW": "提升範圍友軍的攻擊與移動速度，重疊只取最強。", "en": "Raises nearby allies' attack and movement speed; only the strongest beacon applies."},
		"base_price": 85000, "related_base": "attack_or_support_speed",
		"compatible_types": ["healer", "heavy", "priest", "tank", "ufo"],
		"rank_effects": [
			{"radius": 170.0, "ally_attack_speed_bonus": 0.05, "ally_move_speed_bonus": 0.05, "stack_rule": "strongest_only"},
			{"radius": 210.0, "ally_attack_speed_bonus": 0.08, "ally_move_speed_bonus": 0.08, "stack_rule": "strongest_only"},
			{"radius": 250.0, "ally_attack_speed_bonus": 0.12, "ally_move_speed_bonus": 0.12, "stack_rule": "strongest_only"},
		],
	},
	"overheal_matrix": {
		"name": {"zh_TW": "溢療矩陣", "en": "Overheal Matrix"},
		"summary": {"zh_TW": "將溢出的治療量轉為有上限的短暫護盾。", "en": "Converts excess healing into a capped temporary shield."},
		"base_price": 64000, "related_base": "attack_or_healing",
		"compatible_types": ["healer", "priest"],
		"rank_effects": [
			{"overheal_to_shield_ratio": 0.50, "shield_target_max_hp_ratio": 0.08, "duration": 6.0},
			{"overheal_to_shield_ratio": 0.75, "shield_target_max_hp_ratio": 0.12, "duration": 6.0},
			{"overheal_to_shield_ratio": 1.00, "shield_target_max_hp_ratio": 0.16, "duration": 6.0},
		],
	},
	"vengeance_counter": {
		"name": {"zh_TW": "復仇反擊", "en": "Vengeance Counter"},
		"summary": {"zh_TW": "承受固定次數攻擊後強化下一次攻擊。", "en": "Empowers the next attack after taking a fixed number of hits."},
		"base_price": 62000, "related_base": "armor",
		"compatible_types": ["swordsman", "heavy", "tank"],
		"rank_effects": [
			{"hits_taken": 5, "next_attack_damage_bonus": 0.40},
			{"hits_taken": 4, "next_attack_damage_bonus": 0.55},
			{"hits_taken": 3, "next_attack_damage_bonus": 0.75},
		],
	},
	"salvage_protocol": {
		"name": {"zh_TW": "戰場回收協定", "en": "Battlefield Salvage Protocol"},
		"summary": {"zh_TW": "依擊殺獎勵比例取得額外金幣。", "en": "Recovers bonus gold as a percentage of defeated enemies' rewards."},
		"base_price": 70000, "related_base": "recruit_discount",
		"compatible_types": ["roller", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"],
		"rank_effects": [
			{"bonus_gold_ratio": 0.06},
			{"bonus_gold_ratio": 0.10},
			{"bonus_gold_ratio": 0.15},
		],
	},
}


static func has_soldier_type(type_id: String) -> bool:
	return SOLDIER_MULTIPLIERS.has(type_id)


static func soldier_multiplier(type_id: String) -> float:
	return float(SOLDIER_MULTIPLIERS.get(type_id, 1.0))


static func category_for(upgrade_id: String) -> String:
	if BASE_UPGRADES.has(upgrade_id):
		return "base"
	if SPECIAL_ABILITIES.has(upgrade_id):
		return "special"
	return ""


static func definition_for(upgrade_id: String) -> Dictionary:
	if BASE_UPGRADES.has(upgrade_id):
		return Dictionary(BASE_UPGRADES[upgrade_id]).duplicate(true)
	if SPECIAL_ABILITIES.has(upgrade_id):
		return Dictionary(SPECIAL_ABILITIES[upgrade_id]).duplicate(true)
	return {}


static func localized_name(upgrade_id: String, locale: String = "zh_TW") -> String:
	return _localized_field(upgrade_id, "name", locale)


static func localized_summary(upgrade_id: String, locale: String = "zh_TW") -> String:
	return _localized_field(upgrade_id, "summary", locale)


static func localized_effect_text(upgrade_id: String, rank: int, locale: String = "zh_TW") -> String:
	var definition := definition_for(upgrade_id)
	if definition.is_empty():
		return ""
	var rank_effects: Array = definition.get("rank_effects", [])
	if rank <= 0 or rank > rank_effects.size():
		return ""
	var language := "en" if locale.to_lower().begins_with("en") else "zh_TW"
	var effect := _as_dictionary(rank_effects[rank - 1])
	var parts := PackedStringArray()
	for key_value in effect.keys():
		var key := str(key_value)
		parts.append("%s %s" % [_effect_key_label(key, language), _localized_effect_value(key, effect[key], language)])
	return (" · " if language == "en" else "　").join(parts)


static func name_for(upgrade_id: String, locale: String = "zh_TW") -> String:
	return localized_name(upgrade_id, locale)


static func summary_for(upgrade_id: String, locale: String = "zh_TW") -> String:
	return localized_summary(upgrade_id, locale)


static func create_empty_research() -> Dictionary:
	var types: Dictionary = {}
	for type_value in SOLDIER_ORDER:
		var type_id := str(type_value)
		var base_ranks: Dictionary = {}
		for upgrade_value in BASE_UPGRADE_ORDER:
			base_ranks[str(upgrade_value)] = 0
		var special_ranks: Dictionary = {}
		for ability_value in SPECIAL_ABILITY_ORDER:
			var ability_id := str(ability_value)
			if is_compatible(type_id, ability_id):
				special_ranks[ability_id] = 0
		types[type_id] = {"base": base_ranks, "special": special_ranks}
	return {"version": SCHEMA_VERSION, "types": types}


static func sanitize_research(raw_research: Variant) -> Dictionary:
	var sanitized := create_empty_research()
	var raw_root := _as_dictionary(raw_research)
	var raw_types := _as_dictionary(raw_root.get("types", raw_root.get("soldiers", raw_root)))
	var clean_types: Dictionary = sanitized["types"]

	for type_value in SOLDIER_ORDER:
		var type_id := str(type_value)
		var raw_type := _as_dictionary(raw_types.get(type_id, {}))
		var raw_base := _as_dictionary(raw_type.get("base", raw_type.get("base_upgrades", {})))
		var raw_special := _as_dictionary(raw_type.get("special", raw_type.get("special_abilities", {})))
		var clean_type: Dictionary = clean_types[type_id]
		var clean_base: Dictionary = clean_type["base"]
		var clean_special: Dictionary = clean_type["special"]

		for upgrade_value in BASE_UPGRADE_ORDER:
			var upgrade_id := str(upgrade_value)
			clean_base[upgrade_id] = _sanitized_rank(raw_base.get(upgrade_id, 0), _max_rank_for_definition(BASE_UPGRADES[upgrade_id]))

		for ability_value in SPECIAL_ABILITY_ORDER:
			var ability_id := str(ability_value)
			if not clean_special.has(ability_id):
				continue
			var ability: Dictionary = SPECIAL_ABILITIES[ability_id]
			var requested_rank := _sanitized_rank(raw_special.get(ability_id, 0), 3)
			var related_base := str(ability["related_base"])
			var base_rank := int(clean_base.get(related_base, 0))
			var base_max_rank := _max_rank_for_definition(BASE_UPGRADES[related_base])
			clean_special[ability_id] = mini(requested_rank, _special_rank_allowed_by_base(base_rank, base_max_rank))

		clean_type["base"] = clean_base
		clean_type["special"] = clean_special
		clean_types[type_id] = clean_type

	sanitized["types"] = clean_types
	return sanitized


static func validate_research(raw_research: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not raw_research is Dictionary:
		errors.append("research_not_dictionary")
		return errors
	# JSON parses every number as a float. Treat integral 0.0/1.0 ranks as their
	# integer canonical values while still rejecting missing/extra keys, fractions,
	# invalid ranks, and prerequisite violations.
	if not _variants_equivalent(Dictionary(raw_research), sanitize_research(raw_research)):
		errors.append("research_requires_sanitization")
	return errors


static func research_is_valid(raw_research: Variant) -> bool:
	return validate_research(raw_research).is_empty()


static func is_compatible(type_id: String, upgrade_id: String) -> bool:
	if not has_soldier_type(type_id):
		return false
	if BASE_UPGRADES.has(upgrade_id):
		return true
	if not SPECIAL_ABILITIES.has(upgrade_id):
		return false
	return type_id in Array(SPECIAL_ABILITIES[upgrade_id]["compatible_types"])


static func current_rank(type_id: String, upgrade_id: String, research: Variant) -> int:
	var sanitized := sanitize_research(research)
	return _rank_from_sanitized(type_id, upgrade_id, sanitized)


static func max_rank(upgrade_id: String) -> int:
	var definition := definition_for(upgrade_id)
	return _max_rank_for_definition(definition) if not definition.is_empty() else 0


static func prerequisite_for_rank(type_id: String, ability_id: String, target_rank: int) -> Dictionary:
	if not has_soldier_type(type_id) or not SPECIAL_ABILITIES.has(ability_id) or not is_compatible(type_id, ability_id):
		return {}
	var ability: Dictionary = SPECIAL_ABILITIES[ability_id]
	var related_base := str(ability["related_base"])
	var base_max_rank := _max_rank_for_definition(BASE_UPGRADES[related_base])
	var normalized_target := clampi(target_rank, 1, 3)
	var required_rank := 2
	if normalized_target == 2:
		required_rank = 3
	elif normalized_target == 3:
		required_rank = base_max_rank
	return {
		"soldier_type": type_id,
		"soldier_unlocked": true,
		"base_upgrade": related_base,
		"base_rank": required_rank,
		"special_rank": normalized_target,
	}


static func next_rank_cost(type_id: String, upgrade_id: String, research: Variant = null) -> int:
	if not has_soldier_type(type_id) or not is_compatible(type_id, upgrade_id):
		return -1
	var sanitized := sanitize_research(research)
	var rank := _rank_from_sanitized(type_id, upgrade_id, sanitized)
	var category := category_for(upgrade_id)
	if category == "base":
		var prices: Array = BASE_UPGRADES[upgrade_id]["prices"]
		return -1 if rank >= prices.size() else int(prices[rank])
	if category == "special":
		if rank >= 3:
			return -1
		var base_price := int(SPECIAL_ABILITIES[upgrade_id]["base_price"])
		var unrounded := float(base_price * SPECIAL_RANK_COST_MULTIPLIERS[rank]) * soldier_multiplier(type_id)
		return _round_up_to_100(unrounded)
	return -1


static func can_purchase(
	type_id: String,
	upgrade_id: String,
	research: Variant,
	available_gold: int = -1,
	soldier_unlocked: bool = true
) -> bool:
	var sanitized := sanitize_research(research)
	return bool(_purchase_status_sanitized(type_id, upgrade_id, sanitized, available_gold, soldier_unlocked)["allowed"])


static func purchase_preview(
	type_id: String,
	upgrade_id: String,
	research: Variant,
	available_gold: int = -1,
	soldier_unlocked: bool = true
) -> Dictionary:
	var before := sanitize_research(research)
	var preview := _purchase_status_sanitized(type_id, upgrade_id, before, available_gold, soldier_unlocked)
	preview["research_before"] = before.duplicate(true)
	preview["research_after"] = before.duplicate(true)
	preview["gold_after"] = available_gold
	if not bool(preview["allowed"]):
		return preview

	var after: Dictionary = before.duplicate(true)
	var types: Dictionary = after["types"]
	var type_research: Dictionary = types[type_id]
	var category := str(preview["category"])
	var ranks: Dictionary = type_research[category]
	ranks[upgrade_id] = int(preview["next_rank"])
	type_research[category] = ranks
	types[type_id] = type_research
	after["types"] = types
	preview["research_after"] = after
	preview["snapshot_after"] = snapshot_for_type(type_id, after)
	if available_gold >= 0:
		preview["gold_after"] = available_gold - int(preview["cost"])
	return preview


static func recruit_discount_for_type(type_id: String, research: Variant) -> float:
	if not has_soldier_type(type_id):
		return 0.0
	var sanitized := sanitize_research(research)
	var rank := _rank_from_sanitized(type_id, "recruit_discount", sanitized)
	var total := 0.0
	var effects: Array = BASE_UPGRADES["recruit_discount"]["rank_effects"]
	for index in rank:
		total += float(Dictionary(effects[index]).get("recruit_discount", 0.0))
	return minf(total, RECRUIT_DISCOUNT_CAP)


static func snapshot_for_type(type_id: String, research: Variant) -> Dictionary:
	if not has_soldier_type(type_id):
		return {}
	var sanitized := sanitize_research(research)
	var type_research: Dictionary = Dictionary(Dictionary(sanitized["types"])[type_id])
	var base_ranks: Dictionary = Dictionary(type_research["base"]).duplicate(true)
	var special_ranks: Dictionary = Dictionary(type_research["special"]).duplicate(true)
	var base_effects := _cumulative_base_effects(type_id, base_ranks)
	var active_specials: Array[Dictionary] = []
	var special_effects: Dictionary = {}
	for ability_value in SPECIAL_ABILITY_ORDER:
		var ability_id := str(ability_value)
		var rank := int(special_ranks.get(ability_id, 0))
		if rank <= 0:
			continue
		var ability: Dictionary = SPECIAL_ABILITIES[ability_id]
		var current_effect := Dictionary(Array(ability["rank_effects"])[rank - 1]).duplicate(true)
		special_effects[ability_id] = current_effect.duplicate(true)
		active_specials.append({
			"id": ability_id,
			"rank": rank,
			"name": Dictionary(ability["name"]).duplicate(true),
			"summary": Dictionary(ability["summary"]).duplicate(true),
			"effect": current_effect,
		})
	var discount := recruit_discount_for_type(type_id, sanitized)
	return {
		"type": type_id,
		"price_multiplier": soldier_multiplier(type_id),
		"base_ranks": base_ranks,
		"special_ranks": special_ranks,
		"base_effects": base_effects,
		"active_specials": active_specials,
		"special_effects": special_effects,
		"recruit_discount": discount,
		"recruit_cost_multiplier": 1.0 - discount,
		"compatible_base_ids": compatible_base_ids(type_id),
		"compatible_special_ids": compatible_special_ids(type_id),
	}


static func compatible_base_ids(type_id: String) -> Array[String]:
	var result: Array[String] = []
	if not has_soldier_type(type_id):
		return result
	result.assign(BASE_UPGRADE_ORDER)
	return result


static func compatible_special_ids(type_id: String) -> Array[String]:
	var result: Array[String] = []
	if not has_soldier_type(type_id):
		return result
	for ability_value in SPECIAL_ABILITY_ORDER:
		var ability_id := str(ability_value)
		if is_compatible(type_id, ability_id):
			result.append(ability_id)
	return result


static func all_compatible_base_options(
	type_id: String,
	research: Variant = null,
	available_gold: int = -1,
	soldier_unlocked: bool = true
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not has_soldier_type(type_id):
		return result
	var sanitized := sanitize_research(research)
	for upgrade_value in BASE_UPGRADE_ORDER:
		result.append(_option_snapshot(type_id, str(upgrade_value), sanitized, available_gold, soldier_unlocked))
	return result


static func all_compatible_special_options(
	type_id: String,
	research: Variant = null,
	available_gold: int = -1,
	soldier_unlocked: bool = true
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not has_soldier_type(type_id):
		return result
	var sanitized := sanitize_research(research)
	for ability_value in SPECIAL_ABILITY_ORDER:
		var ability_id := str(ability_value)
		if is_compatible(type_id, ability_id):
			result.append(_option_snapshot(type_id, ability_id, sanitized, available_gold, soldier_unlocked))
	return result


static func all_compatible_options(
	type_id: String,
	research: Variant = null,
	available_gold: int = -1,
	soldier_unlocked: bool = true
) -> Dictionary:
	return {
		"base": all_compatible_base_options(type_id, research, available_gold, soldier_unlocked),
		"special": all_compatible_special_options(type_id, research, available_gold, soldier_unlocked),
	}


static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	if SOLDIER_ORDER.size() != 16 or SOLDIER_MULTIPLIERS.size() != 16:
		errors.append("catalog_requires_16_soldier_types")
	if BASE_UPGRADE_ORDER.size() != 8 or BASE_UPGRADES.size() != 8:
		errors.append("catalog_requires_8_base_upgrades")
	if SPECIAL_ABILITY_ORDER.size() != 57 or SPECIAL_ABILITIES.size() != 57:
		errors.append("catalog_requires_57_special_abilities")

	var seen_types: Dictionary = {}
	for type_value in SOLDIER_ORDER:
		var type_id := str(type_value)
		if seen_types.has(type_id):
			errors.append("duplicate_soldier:%s" % type_id)
		seen_types[type_id] = true
		if not SOLDIER_MULTIPLIERS.has(type_id) or float(SOLDIER_MULTIPLIERS.get(type_id, 0.0)) <= 0.0:
			errors.append("invalid_multiplier:%s" % type_id)

	var seen_base: Dictionary = {}
	for upgrade_value in BASE_UPGRADE_ORDER:
		var upgrade_id := str(upgrade_value)
		if seen_base.has(upgrade_id):
			errors.append("duplicate_base:%s" % upgrade_id)
		seen_base[upgrade_id] = true
		if not BASE_UPGRADES.has(upgrade_id):
			errors.append("missing_base:%s" % upgrade_id)
			continue
		var definition: Dictionary = BASE_UPGRADES[upgrade_id]
		var prices: Array = definition.get("prices", [])
		var effects: Array = definition.get("rank_effects", [])
		if prices.is_empty() or prices.size() != effects.size():
			errors.append("invalid_base_ranks:%s" % upgrade_id)
		if _localized_value(definition.get("name", {}), "zh_TW") == "" or _localized_value(definition.get("name", {}), "en") == "":
			errors.append("missing_base_name:%s" % upgrade_id)
		for price_value in prices:
			if typeof(price_value) not in [TYPE_INT, TYPE_FLOAT] or int(price_value) <= 0:
				errors.append("invalid_base_price:%s" % upgrade_id)

	var seen_special: Dictionary = {}
	for ability_value in SPECIAL_ABILITY_ORDER:
		var ability_id := str(ability_value)
		if seen_special.has(ability_id):
			errors.append("duplicate_special:%s" % ability_id)
		seen_special[ability_id] = true
		if not SPECIAL_ABILITIES.has(ability_id):
			errors.append("missing_special:%s" % ability_id)
			continue
		var ability: Dictionary = SPECIAL_ABILITIES[ability_id]
		if int(ability.get("base_price", 0)) <= 0:
			errors.append("invalid_special_price:%s" % ability_id)
		if not BASE_UPGRADES.has(str(ability.get("related_base", ""))):
			errors.append("invalid_special_prerequisite:%s" % ability_id)
		var rank_effects: Array = ability.get("rank_effects", [])
		if rank_effects.size() != 3:
			errors.append("special_requires_three_ranks:%s" % ability_id)
		var compatible: Array = ability.get("compatible_types", [])
		if compatible.is_empty():
			errors.append("special_without_compatibility:%s" % ability_id)
		for compatible_value in compatible:
			if not SOLDIER_MULTIPLIERS.has(str(compatible_value)):
				errors.append("unknown_compatible_type:%s:%s" % [ability_id, str(compatible_value)])
		if _localized_value(ability.get("name", {}), "zh_TW") == "" or _localized_value(ability.get("name", {}), "en") == "":
			errors.append("missing_special_name:%s" % ability_id)

	return errors


static func catalog_self_test() -> Dictionary:
	var errors := validate_catalog()
	var empty_research := create_empty_research()
	if not validate_research(empty_research).is_empty():
		errors.append("empty_research_invalid")
	var discount_test := create_empty_research()
	var discount_types: Dictionary = discount_test["types"]
	var swordsman: Dictionary = discount_types["swordsman"]
	var swordsman_base: Dictionary = swordsman["base"]
	swordsman_base["recruit_discount"] = 4
	swordsman["base"] = swordsman_base
	discount_types["swordsman"] = swordsman
	discount_test["types"] = discount_types
	if not is_equal_approx(recruit_discount_for_type("swordsman", discount_test), RECRUIT_DISCOUNT_CAP):
		errors.append("recruit_discount_cap_failed")
	return {
		"ok": errors.is_empty(),
		"errors": Array(errors),
		"soldier_types": SOLDIER_ORDER.size(),
		"base_upgrades": BASE_UPGRADE_ORDER.size(),
		"special_abilities": SPECIAL_ABILITY_ORDER.size(),
	}


static func _localized_field(upgrade_id: String, field: String, locale: String) -> String:
	var definition := definition_for(upgrade_id)
	if definition.is_empty():
		return ""
	var localized := _as_dictionary(definition.get(field, {}))
	var language := "en" if locale.to_lower().begins_with("en") else "zh_TW"
	return str(localized.get(language, localized.get("zh_TW", localized.get("en", upgrade_id))))


static func _localized_value(value: Variant, locale: String) -> String:
	var localized := _as_dictionary(value)
	return str(localized.get(locale, ""))


static func _effect_key_label(key: String, locale: String) -> String:
	var labels: Array = EFFECT_KEY_LABELS.get(key, [])
	if labels.size() >= 2:
		return str(labels[1] if locale == "en" else labels[0])
	var fallback := key.replace("_", " ")
	return fallback.capitalize() if locale == "en" else fallback


static func _localized_effect_value(key: String, value: Variant, locale: String) -> String:
	if value is Array:
		var items := PackedStringArray()
		for item in Array(value):
			items.append(_localized_effect_value(key, item, locale))
		return "[%s]" % ", ".join(items)
	if value is bool:
		return ("Yes" if bool(value) else "No") if locale == "en" else ("是" if bool(value) else "否")
	if value is String or value is StringName:
		return _localized_effect_enum(str(value), locale)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return str(value)

	var number := float(value)
	if key in ["multiplier", "damage_multiplier", "boss_multiplier", "hp_ratio"]:
		return "×%s" % _compact_number(number)
	if _effect_value_is_percent(key):
		return "%s%%" % _compact_number(number * 100.0)
	if _effect_value_is_seconds(key):
		return "%s s" % _compact_number(number) if locale == "en" else "%s 秒" % _compact_number(number)
	if key == "turn_degrees_per_second":
		return "%s°/s" % _compact_number(number)
	if key == "shots_per_second":
		return "%s/s" % _compact_number(number)
	if key == "max_hp_heal_per_second":
		return "%s%%/s" % _compact_number(number * 100.0)
	if key == "spread_degrees":
		return "%s°" % _compact_number(number)
	if _effect_value_is_distance(key):
		return "%s px" % _compact_number(number)
	if _effect_value_is_count(key):
		return _localized_effect_count(key, number, locale)
	return _compact_number(number)


static func _effect_value_is_percent(key: String) -> bool:
	if key in ["armor_reduction"]:
		return false
	return (
		key == "chance"
		or key == "threshold"
		or key == "recruit_discount"
		or key.ends_with("_ratio")
		or key.ends_with("_ratios")
		or key.ends_with("_bonus")
		or key.ends_with("_reduction")
	)


static func _effect_value_is_seconds(key: String) -> bool:
	return (
		key == "duration"
		or key == "cooldown"
		or key == "ttl"
		or key == "attack_interval"
		or key == "tick_interval"
		or key == "normal_stun"
		or key == "invulnerability"
		or key.ends_with("_duration")
		or key.ends_with("_cooldown")
		or key.ends_with("_delay")
		or key.ends_with("_time")
		or key.ends_with("_ttl")
		or key.ends_with("_seconds")
	)


static func _effect_value_is_distance(key: String) -> bool:
	return (
		key == "distance"
		or key == "radius"
		or key == "knockback"
		or key == "melee_flat_px"
		or key.ends_with("_distance")
		or key.ends_with("_radius")
		or key.ends_with("_range")
	)


static func _effect_value_is_count(key: String) -> bool:
	return (
		key in [
			"jumps", "max_stacks", "extra_projectiles", "extra_pierce", "extra_targets",
			"max_per_unit", "team_cap", "extra_blasts", "bomblets", "shards",
			"same_target_hit_cap", "max_per_owner", "team_summon_cap", "allies",
			"arrow_interval", "hit_threshold", "trigger_every_heals", "every_attacks", "hits_taken",
		]
	)


static func _localized_effect_count(key: String, number: float, locale: String) -> String:
	var compact := _compact_number(number)
	if locale == "en":
		if key in ["max_stacks"]:
			return "%s stacks" % compact
		if key in ["arrow_interval", "hit_threshold", "trigger_every_heals", "every_attacks", "hits_taken", "jumps", "extra_blasts"]:
			return "%s times" % compact
		return compact
	if key in ["max_stacks"]:
		return "%s 層" % compact
	if key in ["arrow_interval", "hit_threshold", "trigger_every_heals", "every_attacks", "hits_taken", "jumps", "extra_blasts", "extra_pierce"]:
		return "%s 次" % compact
	return "%s 個" % compact


static func _localized_effect_enum(value: String, locale: String) -> String:
	var values := {
		"weak_slow": ["弱減速", "Weak slow"],
		"per_second": ["每秒上限", "Per-second cap"],
		"strongest_only": ["只取最強", "Strongest only"],
		"vehicle": ["載具", "Vehicle"],
		"air": ["空軍", "Air"],
		"beam": ["光束", "Beam"],
		"ground": ["地面區域", "Ground area"],
		"grab": ["抓取", "Grab"],
		"burn": ["燃燒", "Burn"],
		"slow": ["減速", "Slow"],
		"paralysis": ["麻痺", "Paralysis"],
	}
	var labels: Array = values.get(value, [])
	if labels.size() >= 2:
		return str(labels[1] if locale == "en" else labels[0])
	return value.replace("_", " ").capitalize() if locale == "en" else value


static func _compact_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var result := "%.2f" % snappedf(value, 0.01)
	while result.ends_with("0"):
		result = result.left(result.length() - 1)
	if result.ends_with("."):
		result = result.left(result.length() - 1)
	return result


static func _as_dictionary(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}


static func _variants_equivalent(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		var left_number := float(left)
		var right_number := float(right)
		return not is_nan(left_number) and not is_inf(left_number) and not is_nan(right_number) and not is_inf(right_number) and is_equal_approx(left_number, right_number)
	if left is Dictionary and right is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key in left_dictionary.keys():
			if not right_dictionary.has(key) or not _variants_equivalent(left_dictionary[key], right_dictionary[key]):
				return false
		return true
	if left is Array and right is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _variants_equivalent(left_array[index], right_array[index]):
				return false
		return true
	return typeof(left) == typeof(right) and left == right


static func _sanitized_rank(value: Variant, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	return clampi(int(value), 0, maximum)


static func _max_rank_for_definition(definition_value: Variant) -> int:
	var definition := _as_dictionary(definition_value)
	if definition.has("prices"):
		return Array(definition["prices"]).size()
	if definition.has("rank_effects"):
		return Array(definition["rank_effects"]).size()
	return 0


static func _special_rank_allowed_by_base(base_rank: int, base_max_rank: int) -> int:
	var allowed := 0
	if base_rank >= 2:
		allowed = 1
	if base_rank >= 3:
		allowed = 2
	if base_rank >= base_max_rank:
		allowed = 3
	return allowed


static func _rank_from_sanitized(type_id: String, upgrade_id: String, sanitized: Dictionary) -> int:
	if not has_soldier_type(type_id):
		return 0
	var category := category_for(upgrade_id)
	if category == "":
		return 0
	var types := _as_dictionary(sanitized.get("types", {}))
	var type_research := _as_dictionary(types.get(type_id, {}))
	var ranks := _as_dictionary(type_research.get(category, {}))
	return int(ranks.get(upgrade_id, 0))


static func _round_up_to_100(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return int(ceil(amount / 100.0)) * 100


static func _purchase_status_sanitized(
	type_id: String,
	upgrade_id: String,
	sanitized: Dictionary,
	available_gold: int,
	soldier_unlocked: bool
) -> Dictionary:
	var category := category_for(upgrade_id)
	var result := {
		"allowed": false,
		"reason": "",
		"type": type_id,
		"upgrade_id": upgrade_id,
		"category": category,
		"current_rank": 0,
		"next_rank": 0,
		"max_rank": max_rank(upgrade_id),
		"cost": -1,
		"prerequisite": {},
	}
	if not has_soldier_type(type_id):
		result["reason"] = "unknown_soldier_type"
		return result
	if category == "":
		result["reason"] = "unknown_upgrade"
		return result
	if not is_compatible(type_id, upgrade_id):
		result["reason"] = "incompatible_soldier_type"
		return result
	if not soldier_unlocked:
		result["reason"] = "soldier_locked"
		return result

	var rank := _rank_from_sanitized(type_id, upgrade_id, sanitized)
	result["current_rank"] = rank
	result["next_rank"] = rank + 1
	if rank >= int(result["max_rank"]):
		result["reason"] = "max_rank"
		return result

	if category == "special":
		var prerequisite := prerequisite_for_rank(type_id, upgrade_id, rank + 1)
		prerequisite["soldier_unlocked"] = soldier_unlocked
		result["prerequisite"] = prerequisite
		var related_base := str(prerequisite.get("base_upgrade", ""))
		var required_base_rank := int(prerequisite.get("base_rank", 0))
		if _rank_from_sanitized(type_id, related_base, sanitized) < required_base_rank:
			result["reason"] = "base_prerequisite"
			return result

	var cost := next_rank_cost(type_id, upgrade_id, sanitized)
	result["cost"] = cost
	if cost < 0:
		result["reason"] = "no_next_rank"
		return result
	if available_gold >= 0 and available_gold < cost:
		result["reason"] = "insufficient_gold"
		return result
	result["allowed"] = true
	result["reason"] = "ok"
	return result


static func _option_snapshot(
	type_id: String,
	upgrade_id: String,
	sanitized: Dictionary,
	available_gold: int,
	soldier_unlocked: bool
) -> Dictionary:
	var option := definition_for(upgrade_id)
	var status := _purchase_status_sanitized(type_id, upgrade_id, sanitized, available_gold, soldier_unlocked)
	option["id"] = upgrade_id
	option["category"] = category_for(upgrade_id)
	option["current_rank"] = int(status["current_rank"])
	option["max_rank"] = int(status["max_rank"])
	option["next_rank"] = int(status["next_rank"])
	option["next_cost"] = int(status["cost"])
	option["can_purchase"] = bool(status["allowed"])
	option["purchase_reason"] = str(status["reason"])
	option["prerequisite"] = Dictionary(status["prerequisite"]).duplicate(true)
	return option


static func _cumulative_base_effects(type_id: String, base_ranks: Dictionary) -> Dictionary:
	var result := {
		"attack_or_healing_bonus": 0.0,
		"armor_bonus": 0.0,
		"max_hp_bonus": 0.0,
		"attack_or_support_speed_bonus": 0.0,
		"move_speed_bonus": 0.0,
		"range_bonus_ratio": 0.0,
		"range_bonus_px": 0.0,
		"critical_chance": 0.0,
		"critical_multiplier": 1.0,
		"critical_mode": "healing" if type_id in SUPPORT_TYPES else "damage",
		"recruit_discount": 0.0,
	}

	for upgrade_value in ["attack_or_healing", "armor", "max_hp", "attack_or_support_speed", "move_speed"]:
		var upgrade_id := str(upgrade_value)
		var rank := int(base_ranks.get(upgrade_id, 0))
		var effects: Array = BASE_UPGRADES[upgrade_id]["rank_effects"]
		for index in rank:
			for effect_key_value in Dictionary(effects[index]).keys():
				var effect_key := str(effect_key_value)
				result[effect_key] = float(result.get(effect_key, 0.0)) + float(Dictionary(effects[index])[effect_key])

	var range_rank := int(base_ranks.get("range", 0))
	var range_effects: Array = BASE_UPGRADES["range"]["rank_effects"]
	for index in range_rank:
		var range_effect: Dictionary = range_effects[index]
		if type_id in MELEE_TYPES:
			result["range_bonus_px"] = float(result["range_bonus_px"]) + float(range_effect["melee_flat_px"])
		else:
			result["range_bonus_ratio"] = float(result["range_bonus_ratio"]) + float(range_effect["ranged_support_ratio"])

	var critical_rank := int(base_ranks.get("critical", 0))
	if critical_rank > 0:
		var critical_effect: Dictionary = Array(BASE_UPGRADES["critical"]["rank_effects"])[critical_rank - 1]
		result["critical_chance"] = float(critical_effect["chance"])
		result["critical_multiplier"] = float(critical_effect["multiplier"])

	var discount_rank := int(base_ranks.get("recruit_discount", 0))
	var discount_effects: Array = BASE_UPGRADES["recruit_discount"]["rank_effects"]
	for index in discount_rank:
		result["recruit_discount"] = float(result["recruit_discount"]) + float(Dictionary(discount_effects[index])["recruit_discount"])
	result["recruit_discount"] = minf(float(result["recruit_discount"]), RECRUIT_DISCOUNT_CAP)
	return result
