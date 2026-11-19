"""IP & Originality Checker: name screen for hero kits and items (MATCH-SIM-V2-DESIGN section 12).

A deny list of distinctive names from well-known MOBAs and hero games (abilities, items, heroes, places), written from
public knowledge: names only, never art or text. A name of ours is flagged when, after normalising (lower case, letters
only), it equals a denied name, shares a one-word denied name as a word, shares two or more words with one, or is close to
one in spelling (ratio 0.85 or more over the whole name). A flag the checker reviews and clears is recorded in REVIEWED
with its reason; anything else fails the screen. This is a screen, not legal clearance: the trademark search stays a Founder item.

Usage: python3 tools/ip_names.py   (screens game/data/kits_v2.json and game/data/items_v2.json; exit 1 on a flag)
"""
import difflib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

DENY = """
# --- abilities (MOBAs and hero shooters)
Judgment|Decisive Strike|Demacian Justice|Final Spark|Requiem|Mystic Shot|Trueshot Barrage|Death Mark|Black Hole|Ravage
Chronosphere|Echo Slam|Reverse Polarity|Laguna Blade|Finger of Death|Sun Strike|Meat Hook|Rot|Dismember|Omnislash|Hookshot
Global Silence|Ice Path|Freezing Field|Starfall|Moonlight Shadow|Enchanted Crystal Arrow|Death Lotus|Bladestorm|Wind Wall
Last Breath|Steel Tempest|Lucent Singularity|Rocket Grab|Static Field|Unstoppable Force|Curse of the Sad Mummy|Tidal Wave
Pyroclasm|Shadow Dance|Twilight Shroud|Perfect Execution|Nether Blade|Paranoia|Duskbringer|Unspeakable Horror|Tumble
Condemn|Final Hour|Rolling Thunder|Spinning Axe|Blood Rush|Whirling Death|Undertow|Reckless Swing|Ragnarok|Tongue Lash
Devour|Thick Skin|Abyssal Voyage|Crowstorm|Drain|Fear|Monsoon|Flash Frost|Glacial Storm|Frostbite|Absolute Zero|Death Ray
Rupture|Bloodrage|Thirst|Blink Strike|Mana Void|Mana Break|Counter Helix|Berserker's Call|Culling Blade|Battle Hunger
Burrowstrike|Epicenter|Sand Storm|Caustic Finale|Stampede|Hoof Stomp|Double Edge|Retaliate|Rolling Boulder|Boulder Smash
Geomagnetic Grip|Magnetize|Earth Splitter|Fissure|Echo Slam|Enchant Totem|Aftershock|Gust|Shackleshot|Powershot|Windrun
Focus Fire|Frost Arrows|Multishot|Marksmanship|Precision Aura|Primal Roar|Wild Axes|Call of the Wild|Shadow Poison
Dark Pact|Pounce|Essence Shift|Shadow Dance|Blur|Coup de Grace|Time Walk|Time Dilation|Backtrack|Time Lock|Mirror Image
Reality Rift|Phantom Strike|Spirit Lance|Doppelganger|Juxtapose|Static Remnant|Ball Lightning|Overload|Electric Vortex
Fiery Soul|Light Strike Array|Dragon Slave|Wave of Terror|Nether Ward|Ghost Ship|Torrent|Tidebringer|X Marks the Spot
Kraken Shell|Anchor Smash|Gush|Avalanche|Toss|Grow|Overgrowth|Nature's Call|Sprout|Teleportation|Wrath of Nature
Shadow Realm|Haunt|Reality|Spectral Dagger|Desolate|Hellfire Blast|Nightmare|Enfeeble|Brain Sap|Fiend's Grip|Sanity's Eclipse
Arcane Orb|Astral Imprisonment|Essence Aura|Purification|Guardian Angel|Degen Aura|Heal|Shield Bash|Whirlwind|Fireball
Earthshatter|Overdrive|Deadeye|High Noon|Dragonblade|Dragonstrike|Barrage|Self-Destruct|Gravitic Flux|Nano Boost|Transcendence
Sound Barrier|Amp It Up|Molten Core|Supercharger|Earthshatter|Coalescence|Biotic Grenade|Rally|Duplicate|Rip-Tire|Riptire
Annihilation|Final Blow|Starfire|Lunar Strike|Moonfall|Eclipse|Celestial Expansion|Living Shadow|Fated Strike|Dread
Sharpshooter|Bullseye|Headshot|Deathblossom|Shadowstrike|Death Sentence|Cataclysm|Exalted|Requiem|Onslaught|Seismic Slam
Blazing Fury|Lava Wave|Vortex|Ultimate Combo|Shadow Assault|Moon Blade|Impact|Divine Shield|Holy Light|Consecration
Thunder Clap|Storm Bolt|Avatar|Bash|Earth Shock|Chain Lightning|Feral Spirit|Big Bad Voodoo|Mass Teleport|Blizzard|Water Elemental
Brilliance Aura|Hex|Serpent Ward|Mana Shield|Charge|Blink|Flash|Ignite|Exhaust|Smite|Teleport|Ghost|Cleanse|Barrier
# --- items (MOBAs)
Infinity Edge|Rabadon's Deathcap|Blade of the Ruined King|Trinity Force|Black Cleaver|Zhonya's Hourglass|Void Staff|Thornmail
Sunfire Aegis|Bloodthirster|Divine Rapier|Black King Bar|Aghanim's Scepter|Blink Dagger|Eul's Scepter|Manta Style|Butterfly
Daedalus|Monkey King Bar|Radiance|Heart of Tarrasque|Desolator|Battle Fury|Mjollnir|Satanic|Abyssal Blade|Skull Basher
Shiva's Guard|Assault Cuirass|Pipe of Insight|Mekansm|Force Staff|Glimmer Cape|Scythe of Vyse|Dagon|Ethereal Blade
Linken's Sphere|Lotus Orb|Heaven's Halberd|Bloodstone|Octarine Core|Refresher Orb|Silver Edge|Shadow Blade|Diffusal Blade
Maelstrom|Echo Sabre|Armlet of Mordiggian|Vanguard|Crimson Guard|Blade Mail|Spirit Vessel|Urn of Shadows|Meteor Hammer
Nullifier|Bloodthorn|Orchid Malevolence|Kaya|Sange|Yasha|Hurricane Pike|Solar Crest|Medallion of Courage|Vladmir's Offering
Mask of Madness|Helm of the Dominator|Aether Lens|Rod of Atos|Gleipnir|Wind Waker|Harpoon|Khanda|Parasma|Disperser
Blade of Despair|Endless Battle|Windtalker|Berserker's Fury|Malefic Roar|Immortality|Athena's Shield|Antique Cuirass
Dominance Ice|Oracle|Holy Crystal|Lightning Truncheon|Clock of Destiny|Concentrated Energy|Glowing Wand|Ice Queen Wand
Necklace of Durance|Blood Wings|Genius Wand|Feather of Heaven|Sea Halberd|Corrosion Scythe|Hunter Strike|Rose Gold Meteor
Wind of Nature|Queen's Wings|Brute Force Breastplate|Thunder Belt|Radiant Armor|Twilight Armor|Guardian Helmet|Cursed Helmet
Blade of the Heptaseas|Demon Hunter Sword|Golden Staff|Haas's Claws|Scarlet Phantom|Great Dragon Spear|Bloodlust Axe
War Axe|Fleeting Time|Starlium Scythe|Winter Truncheon|Liandry's Torment|Luden's Tempest|Rylai's Crystal Scepter
Morellonomicon|Nashor's Tooth|Lich Bane|Spirit Visage|Randuin's Omen|Frozen Heart|Warmog's Armor|Dead Man's Plate
Titanic Hydra|Ravenous Hydra|Duskblade|Youmuu's Ghostblade|Edge of Night|Serylda's Grudge|Lord Dominik's Regards
Mortal Reminder|Phantom Dancer|Rapid Firecannon|Runaan's Hurricane|Statikk Shiv|Kraken Slayer|Galeforce|Immortal Shieldbow
Mercurial Scimitar|Quicksilver Sash|Maw of Malmortius|Sterak's Gage|Death's Dance|Spear of Shojin|Stridebreaker|Goredrinker
Divine Sunderer|Iceborn Gauntlet|Locket of the Iron Solari|Redemption|Mikael's Blessing|Ardent Censer|Staff of Flowing Water
Moonstone Renewer|Shurelya's Battlesong|Knight's Vow|Zeke's Convergence|Banshee's Veil|Abyssal Mask|Cosmic Drive|Riftmaker
Everfrost|Night Harvester|Hextech Rocketbelt|Crown of the Shattered Queen|Demonic Embrace|Mejai's Soulstealer|Seraph's Embrace
Archangel's Staff|Muramana|Manamune|Tear of the Goddess|Doran's Blade|Doran's Ring|B. F. Sword|Needlessly Large Rod
Amplifying Tome|Blasting Wand|Ruby Crystal|Null-Magic Mantle|Negatron Cloak|Giant's Belt|Kindlegem|Recurve Bow|Cloak of Agility
Hexdrinker|Serrated Dirk|Caulfield's Warhammer|Kircheis Shard|Noonquiver|Phage|Sheen|Tiamat|Bami's Cinder|Aegis of the Legion
Glacial Buckler|Bramble Vest|Executioner's Calling|Oblivion Orb|Fiendish Codex|Lost Chapter|Aether Wisp|Forbidden Idol
Hextech Alternator|Plated Steelcaps|Mercury's Treads|Berserker's Greaves|Sorcerer's Shoes|Ionian Boots of Lucidity
Boots of Swiftness|Mobility Boots|Phase Boots|Power Treads|Arcane Boots|Tranquil Boots|Boots of Travel|Guardian Greaves
Warden's Mail|Chain Vest|Long Sword|Pickaxe|Vampiric Scepter|Hearthbound Axe|Eclipse|Navori Quickblades|Essence Reaver
Stormrazor|Collector|Guinsoo's Rageblade|Wit's End|Nashor|Hullbreaker|Sundered Sky|Heartsteel|Unending Despair|Jak'Sho
Hollow Radiance|Kaenic Rookern|Force of Nature|Gargoyle Stoneplate|Anathema's Chains|Chempunk Chainsword|Black Mist Scythe
Spectral Sickle|Relic Shield|Steel Shoulderguards|Spellthief's Edge|Frostfang|Shard of True Ice|Targon's Buckler|Bulwark of the Mountain
Tear|Aegis|Rapier|Basher|Hydra|Dirk|Codex|Chalice|Sanguine Blade|Vigilant Wardstone|Watchful Wardstone|Control Ward
# --- places and objectives
Summoner's Rift|Baron Nashor|Rift Herald|Elemental Drake|Elder Dragon|Roshan|Tormentor|Lord|Turtle|Land of Dawn
Howling Abyss|Twisted Treeline|Nexus|Ancient|Inhibitor|Barracks|Fountain|Fate's Gate|Overlord|Tyrant|Abyssal Dragon
# --- heroes of other games (single distinctive names)
Ahri|Akali|Garen|Darius|Yasuo|Zed|Jinx|Ezreal|Thresh|Lux|Teemo|Annie|Ashe|Vayne|Riven|Fiora|Nocturne|Kassadin|Malphite
Pudge|Invoker|Juggernaut|Axe|Lina|Lion|Crystal Maiden|Sniper|Drow Ranger|Mirana|Tinker|Rubick|Meepo|Earthshaker|Tidehunter
Layla|Miya|Alucard|Tigreal|Balmond|Zilong|Gusion|Fanny|Lancelot|Chou|Franco|Eudora|Kagura|Odette|Estes|Rafaela|Angela
Tracer|Reaper|Mercy|Genji|Hanzo|Reinhardt|Widowmaker|Pharah|Lucio|Zenyatta|Omen|Jett|Sage|Sova|Phoenix|Viper|Brimstone
Monolith|Gauntlet|Dredge|Oculus
"""

def norm(s):
    return re.sub(r"[^a-z ]", "", s.lower().replace("'", "").replace("-", " ")).strip()


def words(s):
    return [w for w in norm(s).split() if w]


def deny_list():
    out = []
    for line in DENY.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        out += [x.strip() for x in line.split("|") if x.strip()]
    return sorted(set(out))


STOP = set("the of a an and to in on at by for with from into over under its his her their".split())

# Flags the IP & Originality Checker reviewed and cleared, with the reason (docs/design/IP-REVIEW-KITS-ITEMS.md).
REVIEWED = {
    "Lighthouse Charge": "'charge' is a plain English verb and a generic genre action; the name is our own compound (Ottomere the lamp keeper)",
    "Spade Toss": "'toss' is a plain English verb; our own compound (Barrowick the gravedigger)",
    "Ember Toss": "'toss' is a plain English verb; our own compound (Embrel the ember apprentice)",
    "Harpoon Shot": "'harpoon' is a common noun describing the weapon; the denied 'Harpoon' is an item, ours is an ability of a harpoon gunner",
    "Harpoon Gunner": "title only; 'harpoon' is a common noun describing the hero's weapon",
}


def screen(name, deny=None):
    """Return a list of reasons the name is flagged (empty = clear).
    Rules: (1) equal to a denied name; (2) contains a one-word denied name as a word; (3) shares two or more words with a
    denied name; (4) the whole name is very close in spelling (ratio 0.85 or more) to a denied name."""
    deny = deny or deny_list()
    n = norm(name)
    nw = set(words(name)) - STOP
    reasons = []
    for d in deny:
        dn = norm(d)
        if not dn:
            continue
        dw = set(words(d)) - STOP
        if n == dn:
            reasons.append(f"equals '{d}'"); continue
        if len(dw) == 1 and dw <= nw:
            reasons.append(f"contains the name '{d}'"); continue
        if len(nw & dw) >= 2:
            reasons.append(f"shares {sorted(nw & dw)} with '{d}'"); continue
        a, b = n.replace(" ", ""), dn.replace(" ", "")
        if len(a) >= 6 and difflib.SequenceMatcher(None, a, b).ratio() >= 0.85:
            reasons.append(f"close to '{d}'")
    return reasons


def our_names():
    names = []
    kp = ROOT / "game/data/kits_v2.json"
    if kp.exists():
        for k in json.loads(kp.read_text())["kits"]:
            names.append(("kit", k["id"] + ".passive", k["passive"]["name"]))
            for a in k["abilities"]:
                names.append(("kit", a["id"], a["name"]))
            names.append(("title", k["id"], k["title"]))
    ip = ROOT / "game/data/items_v2.json"
    if ip.exists():
        for it in json.loads(ip.read_text())["items"]:
            names.append(("item", it["id"], it["name"]))
    return names


def main():
    deny = deny_list()
    flagged = 0
    seen = {}
    for kind, key, name in our_names():
        if kind != "title":
            if norm(name) in seen:
                print(f"DUPLICATE  {key}: '{name}' also used by {seen[norm(name)]}"); flagged += 1
            seen[norm(name)] = key
        r = screen(name, deny)
        if r and norm(name) in {norm(k) for k in REVIEWED}:
            print(f"cleared  {key}: '{name}' ({'; '.join(r)}): {REVIEWED[[k for k in REVIEWED if norm(k) == norm(name)][0]]}")
            continue
        if r:
            flagged += 1
            print(f"FLAG  {kind} {key}: '{name}': {'; '.join(r)}")
    print(f"ip_names: {len(our_names())} names screened against {len(deny)} denied names, {flagged} flagged")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
