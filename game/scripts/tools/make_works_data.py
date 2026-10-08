#!/usr/bin/env python3
"""Merges the Spillway / jammer-works entries into game/data/world/rooms.json, placements.json and story_scenes.json.

Run from the repo root:  python3 game/scripts/tools/make_works_data.py
Only entries that are missing are added (rooms.json: the nine works rooms are always written, they are this
script's); anything tuned by hand later, by the Battle Programmer (M4-3) or the Writer, stays. The room scenes
come from make_works_rooms.py; the node names there carry the placement ids used here.
"""
import json
import os

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "world")
CARD = "kasp_access_card"
NO_PATROL = []


def load(name):
    with open(os.path.join(DATA, name)) as f:
        return json.load(f)


def save(name, doc):
    with open(os.path.join(DATA, name), "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


ROOMS = {
    "road_mast_road": ("The Spillway", "res://scenes/rooms/road/road_mast_road.tscn", ["from_harrow", "from_mast_foot"], "from_harrow"),
    "road_mast_foot": ("The Works Gate", "res://scenes/rooms/road/road_mast_foot.tscn", ["from_road", "from_tunnel"], "from_road"),
    "tower_sump": ("The Sump", "res://scenes/rooms/tower/tower_sump.tscn", ["from_tunnel", "from_lift", "from_above", "lamp1"], "from_tunnel"),
    "tower_cable_hall": ("Cable Mill", "res://scenes/rooms/tower/tower_cable_hall.tscn", ["from_below", "from_above"], "from_below"),
    "tower_bell_gallery": ("Bell Gallery", "res://scenes/rooms/tower/tower_bell_gallery.tscn", ["from_below", "from_above"], "from_below"),
    "tower_generator": ("Power Room", "res://scenes/rooms/tower/tower_generator.tscn", ["from_below", "from_lift"], "from_below"),
    "tower_jammer_deck": ("Drone Line", "res://scenes/rooms/tower/tower_jammer_deck.tscn", ["from_lift", "from_above"], "from_lift"),
    "tower_landing": ("Last Landing", "res://scenes/rooms/tower/tower_landing.tscn", ["from_below", "from_above", "lamp2"], "from_below"),
    "tower_roof": ("The Roof", "res://scenes/rooms/tower/tower_roof.tscn", ["from_below"], "from_below"),
}


def door(room, to_room, to_spawn, label, width=None, style=None, requires=None, locked=None, unlocked=None):
    d = {"room": room, "to_room": to_room, "to_spawn": to_spawn, "label": label}
    if width:
        d["width"] = width
    if style:
        d["style"] = style
    if requires:
        d["requires"] = requires
    if locked:
        d["locked_message"] = locked
    if unlocked:
        d["unlocked_message"] = unlocked
    return d


CARD_LOCKED = "SIGNALS ACCESS ONLY.\nCards: {have} of {need}."
CARD_OK = "The reader blinks green. Kasp's face on\nthe card looks smug about it."


def card_req(n):
    return {"item": CARD, "count": n, "consume": False}


DOORS = {
    "rd_to_foot": door("road_mast_road", "road_mast_foot", "from_road", "WORKS GATE", 4.0, "arch"),
    "fo_to_road": door("road_mast_foot", "road_mast_road", "from_mast_foot", "SPILLWAY", 3.0, "arch"),
    "fo_to_sump": door("road_mast_foot", "tower_sump", "from_tunnel", "DRAIN", 1.6, "arch", {"flag": "zeroes_back_way"},
                       "The grate won't budge. The Zeroes are still\narguing about whose turn it is to lift it."),
    "ts_to_gate": door("tower_sump", "road_mast_foot", "from_tunnel", "GRATE", 1.6, "arch"),
    "ts_to_cable": door("tower_sump", "tower_cable_hall", "from_below", "UP", 2.0, "arch"),
    "tc_to_sump": door("tower_cable_hall", "tower_sump", "from_above", "DOWN", 2.0, "arch"),
    "tc_card_door_1": door("tower_cable_hall", "tower_bell_gallery", "from_below", "CARDS 1", 1.6, None, card_req(1), CARD_LOCKED, CARD_OK),
    "tb_to_cable": door("tower_bell_gallery", "tower_cable_hall", "from_above", "DOWN", 2.0, "arch"),
    "tb_to_gen": door("tower_bell_gallery", "tower_generator", "from_below", "UP", 2.0, "arch"),
    "tg_to_bell": door("tower_generator", "tower_bell_gallery", "from_above", "DOWN", 2.0, "arch"),
    "td_card_door_3": door("tower_jammer_deck", "tower_landing", "from_below", "CARDS 3", 1.6, None, card_req(3), CARD_LOCKED, CARD_OK),
    "tl_to_deck": door("tower_landing", "tower_jammer_deck", "from_above", "DOWN", 2.0, "arch"),
    "tl_to_roof": door("tower_landing", "tower_roof", "from_below", "ROOF", 1.6, "arch"),
    "rf_to_landing": door("tower_roof", "tower_landing", "from_above", "DOWN", 2.0, "arch"),
}

CRATES = {
    "rd_tram_stash": {"room": "road_mast_road", "style": "chalk", "items": [{"item": "hot_sauce_bomb", "count": 2}]},
    "fo_supply": {"room": "road_mast_foot", "style": "supply", "items": [{"item": "smelling_salts", "count": 1}]},
    "ts_supply": {"room": "tower_sump", "style": "supply", "items": [{"item": "ration_bar", "count": 2}]},
    "tc_ledge_stash": {"room": "tower_cable_hall", "style": "chalk", "items": [{"item": "camp_stove", "count": 1}, {"item": "canned_coffee", "count": 1}]},
    "tb_bell_chest": {"room": "tower_bell_gallery", "style": "wood", "items": [{"item": "bread_knife", "count": 1}], "show_if": {"flag": "bells_solved"}},
    "tg_girder_crate": {"room": "tower_generator", "style": "supply", "items": [{"item": "protein_shake", "count": 1}]},
    "td_quota_crate": {"room": "tower_jammer_deck", "style": "supply", "items": [{"item": "sore_loser_patch", "count": 1}], "credits": 200},
}


def reward():
    return {"items": [{"item": CARD, "count": 1}]}


ENEMIES = {
    "rd_patrol": {"room": "road_mast_road", "enemy": "signals_grunt", "encounter": "grunt_pair", "kind": "regular",
                  "patrol": [[0, 0, 0], [9, 0, 0], [9, 0, 3], [0, 0, 3]]},
    "ts_card_1": {"room": "tower_sump", "enemy": "signals_grunt", "encounter": "grunt_solo", "kind": "story", "defeat_flag": "card_grunt_1_beaten",
                  "patrol": NO_PATROL, "sight_m": 2.0, "close_notice_m": 0.0, "sight_cone_deg": 80.0, "badge": True, "win_reward": reward()},
    "tc_drones": {"room": "tower_cable_hall", "enemy": "signals_drone", "encounter": "drone_flock", "kind": "regular",
                  "patrol": [[0, 0, 0], [3, 0, 3], [0, 0, 6], [-3, 0, 3]]},
    "tb_card_pair": {"room": "tower_bell_gallery", "enemy": "signals_grunt", "encounter": "grunt_pair", "kind": "story", "defeat_flag": "card_grunt_2_beaten",
                     "patrol": [[0, 0, 0], [7, 0, 0], [7, 0, 4], [0, 0, 4]], "badge": True, "win_reward": reward()},
    "td_squad": {"room": "tower_jammer_deck", "enemy": "signals_grunt", "encounter": "squad_four", "kind": "story", "defeat_flag": "card_grunt_3_beaten",
                 "patrol": [[0, 0, 0], [8, 0, 0], [8, 0, 4.5], [0, 0, 4.5]], "badge": True, "win_reward": reward()},
    "td_quota_a": {"room": "tower_jammer_deck", "enemy": "whistle_blower", "encounter": "ambush_no_exit", "kind": "regular",
                   "patrol": NO_PATROL, "sight_m": 0.0, "group": "quota_pen"},
    "td_quota_b": {"room": "tower_jammer_deck", "enemy": "buzzkill_drone", "encounter": "ambush_no_exit", "kind": "regular",
                   "patrol": NO_PATROL, "sight_m": 0.0, "group": "quota_pen"},
    "td_quota_c": {"room": "tower_jammer_deck", "enemy": "whistle_blower", "encounter": "ambush_no_exit", "kind": "regular",
                   "patrol": NO_PATROL, "sight_m": 0.0, "group": "quota_pen"},
}

GRUNT = "res://art/placeholder/enemies/signals_grunt/enm_signals_grunt.glb"
ZERO = "res://art/placeholder/characters/old_zero/npc_old_zero.glb"
MOX = "res://art/placeholder/characters/mox/chr_mox.glb"


def crowd_zero(i, line):
    tints = ["#8a7a5a", "#6a7a8a", "#7a6a5a", "#8a6a6a", "#6a8a7a", "#7a7a6a", "#8a8a5a"]
    return {"room": "road_mast_foot", "speaker": "crowd_zero",
            "look": {"body": tints[i], "head": "#d8c0a0", "scale": 0.95, "accessory": {"shape": "sphere", "color": "#d9c08a", "size": [0.1], "pos": [0.25, 0.7, 0.0]}},
            "variants": [{"conversation": line}]}


NPCS = {
    "rd_mox": {"room": "road_mast_road", "speaker": "mox", "look": {"model": MOX, "radius": 0.4, "height": 1.2}, "variants": [{"conversation": "works_rd_mox_after"}], "hidden": True},
    "fo_old_zero": {"room": "road_mast_foot", "speaker": "zero_old", "look": {"model": ZERO, "radius": 0.4, "height": 1.3},
                    "variants": [{"if": {"flag": "zeroes_back_way", "not_flag": "has_bell_napkin"}, "conversation": "works_fo_zero_napkin"},
                                 {"if": {"flag": "has_bell_napkin"}, "conversation": "works_fo_zero_again"},
                                 {"conversation": "works_fo_zero_wait"}]},
    "fo_grunt_a": {"room": "road_mast_foot", "speaker": "crowd_grunt", "look": {"model": GRUNT, "radius": 0.4, "height": 1.4}, "variants": [{"conversation": "works_fo_grunt_a"}]},
    "fo_grunt_b": {"room": "road_mast_foot", "speaker": "crowd_grunt", "look": {"model": GRUNT, "radius": 0.4, "height": 1.4}, "variants": [{"conversation": "works_fo_grunt_b"}]},
    "fo_mox": {"room": "road_mast_foot", "speaker": "mox", "look": {"model": MOX, "radius": 0.4, "height": 1.2}, "variants": [{"conversation": "works_fo_mox"}], "hidden": True},
    "tl_old_zero": {"room": "tower_landing", "speaker": "zero_old", "look": {"model": ZERO, "radius": 0.4, "height": 1.3},
                    "variants": [{"if": {"not_flag": "thermos_used"}, "scene": "works_tl_thermos"}, {"conversation": "works_tl_zero_luck"}]},
}
for _i, _line in enumerate(["works_fo_crowd_a", "works_fo_crowd_b", "works_fo_crowd_c", "works_fo_crowd_a", "works_fo_crowd_b", "works_fo_crowd_c", "works_fo_crowd_a"]):
    NPCS["fo_zero_%d" % (_i + 1)] = crowd_zero(_i, _line)


def spot(room, conversation, reach=1.4):
    return {"room": room, "kind": "examine", "variants": [{"conversation": conversation}], "reach": reach}


SPOTS = {
    "rd_tram_sign": spot("road_mast_road", "works_rd_tram_sign"), "rd_gauge": spot("road_mast_road", "works_rd_gauge"),
    "rd_grate": spot("road_mast_road", "works_rd_grate"), "fo_blast_gate": spot("road_mast_foot", "works_fo_gate", 1.8),
    "ts_plaque": spot("tower_sump", "works_ts_plaque"), "ts_mural": spot("tower_sump", "works_ts_mural"),
    "tc_chart": spot("tower_cable_hall", "works_tc_chart"), "tc_spool": spot("tower_cable_hall", "works_tc_spool"),
    "tc_conveyor": spot("tower_cable_hall", "works_tc_conveyor"), "tb_window": spot("tower_bell_gallery", "works_tb_window"),
    "tg_rubble": spot("tower_generator", "works_tg_rubble", 1.8), "tg_plate": spot("tower_generator", "works_tg_plate"),
    "tg_board": spot("tower_generator", "works_tg_board"), "td_console": spot("tower_jammer_deck", "works_td_console"),
    "td_line": spot("tower_jammer_deck", "works_td_line"), "td_coffee": spot("tower_jammer_deck", "works_td_coffee"),
    "td_pen": spot("tower_jammer_deck", "works_td_pen"), "tl_rack": spot("tower_landing", "works_tl_rack"),
}

SCENES = {
    "works_rd_crate": {
        "room": "road_mast_road",
        "trigger": {"on": "enter", "area": {"min": [11, 0], "max": [34, 8]}},
        "if": {"beat": ["b2_otis_joined", "b2_road"]},
        "once": "mox_crate_scene",
        "steps": [
            {"do": "beat", "beat": "b2_road"},
            {"do": "say", "conversation": "works_rd_crate_1"},
            {"do": "show", "actor": "rd_mox"},
            {"do": "say", "conversation": "works_rd_crate_2"},
            {"do": "move", "actor": "rd_mox", "to": [1.2, 4.0], "speed": 3.5},
            {"do": "hide", "actor": "rd_mox"},
        ],
    },
    "works_fo_sitin": {
        "room": "road_mast_foot",
        "trigger": {"on": "enter"},
        "if": {"not_flag": "zeroes_back_way"},
        "once": "works_gate_scene",
        "steps": [
            {"do": "say", "conversation": "works_fo_sitin_1"},
            {"do": "show", "actor": "fo_mox"},
            {"do": "join", "member": "mox", "at": "fo_mox"},
            {"do": "set_flag", "flag": "mox_joined"},
            {"do": "say", "conversation": "works_fo_sitin_2"},
            {"do": "hide", "actor": "fo_mox"},
            {"do": "set_flag", "flag": "zeroes_back_way"},
        ],
    },
    "works_ts_enter": {
        "room": "tower_sump",
        "trigger": {"on": "enter", "spawn": ["from_tunnel"]},
        "once": "works_sump_seen",
        "steps": [{"do": "beat", "beat": "b3_tower"}, {"do": "say", "conversation": "works_ts_enter"}],
    },
    "works_tl_thermos": {
        "room": "tower_landing",
        "steps": [
            {"do": "say", "conversation": "works_tl_zero_pour"},
            {"do": "heal_party"},
            {"do": "set_flag", "flag": "thermos_used"},
        ],
    },
}


def merge_section(doc, section, entries):
    added = []
    block = doc.setdefault(section, {})
    for key, value in entries.items():
        if key not in block:
            block[key] = value
            added.append(key)
    return added


def main():
    rooms = load("rooms.json")
    rooms["_about"] = rooms["_about"].split(" road_mast_road is a stub")[0] + (
        " The Spillway and the jammer works (M4-1): road_mast_road, road_mast_foot and the seven tower_* rooms of docs/maps/road_and_tower.md.")
    for room_id, (name, scene, spawns, default) in ROOMS.items():
        rooms["rooms"][room_id] = {"name": name, "scene": scene, "spawns": spawns, "default_spawn": default}
    save("rooms.json", rooms)

    placements = load("placements.json")
    new = []
    for section, entries in (("doors", DOORS), ("crates", CRATES), ("enemies", ENEMIES), ("npcs", NPCS), ("spots", SPOTS)):
        new += ["%s/%s" % (section, k) for k in merge_section(placements, section, entries)]
    save("placements.json", placements)

    scenes = load("story_scenes.json")
    new += ["scenes/%s" % k for k in merge_section(scenes, "scenes", SCENES)]
    save("story_scenes.json", scenes)
    print("rooms written; added %d entries" % len(new))


if __name__ == "__main__":
    main()
