# ZM Bots

AI teammates for BO7 Zombies on Kronos. Up to 7 bots join your squad: they fight, revive you, buy perks and guns, open doors and follow your orders.

This is a BO7 port of **Call of Duty Black Ops 2 Zombies Plutonium Bots V4.0** by supergamer9787, based on the original *ZM Bots* by RlKk01.

**Version 0.3.5, test version.** Some features are not tested in game yet (see "Not tested yet" below). Please report anything that breaks.

## Install

Use [FuzMods](https://github.com/Fuzion28/fuzmods), or by hand:

1. Download the files of the [latest release](https://github.com/Fuzion28/zmbots/releases/latest).
2. Put them in `kronos\mods\zmbots\`:
   - `mod.json` in the folder itself;
   - the `.gsc` files in `scripts\`;
   - `zm_bots_hud_post.lua` in `lua\`.
3. Start Kronos and a Zombies match. The bots join a few seconds after you spawn.

To remove the mod, delete the `kronos\mods\zmbots\` folder.

## Features

### Bots
- Up to 7 bots join the host's squad (8 players in all; 5 bots tested).
  The game only shows names and squad colors for 4 players, so bots past the third have no name above their head. They still play normally.
- They fight zombies with the game's own bot AI.
- They revive downed players. At most 2 bots go for the same player; the others nearby guard them.
- 500 health (1000 with Juggernog) and refilled reserve ammo, as in the original.
- They put armor plates back in when they have plates and took no armor damage for 2 s.
- Each bot gets a name from the original list and a personality: slayer, medic, gambler, engineer or allrounder.
  - Medic buys Quick Revive first.
  - Gambler uses the Mystery Box more.
  - Engineer opens doors from farther away.

### Modes
- **Follow:** stay close to you.
- **Stay:** hold their spot.
- **Wander** (default): roam around you.
- **Wander further:** roam the map, up to 3000 units away.

### Buying
- Perks from round 8 (Juggernog, Speed Cola, Quick Revive, Double Tap, PhD, Deadshot, Stamin-Up, Mule Kick, then the rest).
- Wall guns and wall ammo.
- Pack-a-Punch from round 10.
- Mystery Box, with a cooldown that grows with the round (none during a Fire Sale).
- Doors and debris near them, with their own points.

With no gun bought yet, a bot keeps 1500 points after a door. They only buy when nobody is down, and only things within 1000 units of you, so they stay with the squad.

### Movement
- They back off when their health is low and zombies are close.
- They keep their distance from zombies.
- They close in around you when your health is low.
- The last bot standing kites the zombies and only revives when it is safe.
- A bot surrounded while reviving backs off, then comes back.

### Power-ups
- Bots grab power-ups near them. No Nuke while zombies are alive, no Insta-Kill or Double Points when none is left.
- The first bot to go for one calls it out: "Grabbing the Max Ammo!".
- If a bot is stuck, it jumps, strafes, then picks a new goal.

### HUD and chatter
- A panel on the left shows the bot mode, then one line per bot: personality, state, health, kills, downs, revives, perks owned, guns bought and doors opened.
- The bots talk in the kill feed with the original lines: "I'm down! Need a revive!", "Reviving <name>!", "I'm back in! Let's go!" and more.

## Controls

| Input | Action |
|---|---|
| Aim + Use (press Use again to scroll, release and wait 2 s to run) | Command wheel: follow, stay, wander, wander further, hold where I look, teleport to me, reroll personalities, status |
| Double-tap Dpad Down | Cycle stay, wander, wander further, follow |
| Hold Dpad Down | Bots hold the spot you look at |
| Double-tap Dpad Left | Teleport the bots to you |

On mouse and keyboard, use the command wheel (right click + your interact key).

## Settings

Settings are the dvars at the top of `scripts/zm_bots_config.gsc`. To change one, edit its default (the second argument) and restart the match.

| Dvar | Default | What it does |
|---|---|---|
| `zb_count` | 3 | Number of bots (1-7) |
| `zb_fill` | 0 | 1 = only fill the empty slots of the 8-player squad |
| `zb_mode` | wander | Start mode: stay, wander, wander_further or follow |
| `zb_hud` | 1 | Show the HUD panel |
| `zb_chatter` | 1 | Bot chat lines |
| `zb_hints` | 1 | Control hint at the start |
| `zb_perk_round` | 8 | First round for perk buys |
| `zb_pap_round` | 10 | First round for Pack-a-Punch |
| `zb_personalities` | 1 | 0 = every bot is an allrounder |
| `zb_retreat` | 1 | Back off at low health |
| `zb_retreat_health` | 75 | Health percent for backing off (30-90) |
| `zb_keep_distance` | 1 | Keep distance from zombies |
| `zb_max_health` | 500 | Bot health, doubled with Juggernog (0 = game default) |
| `zb_infinite_ammo` | 1 | Refill bot reserve ammo |
| `zb_debug` | 0 | 1 = show the yellow "zmbots ..." debug lines and the per-round stats lines |
| `zb_auto_teleport` | 0 | 1 = a bot far from you for 20 s teleports to you |
| `zb_powerups` | 1 | Grab power-ups |
| `zb_last_alive` | 1 | Last bot standing kites and revives only when safe |
| `zb_keep_last` | 0 | 1 = bots stop shooting when one zombie is left, so you decide when the round ends (console: `set zb_cmd keeplast` toggles it) |

## Not tested yet
- Bot health 500/1000 and the ammo refill.
- The 2-bot revive limit and guarding.
- Wander further.
- Buying guns, Pack-a-Punch and the box.
- New in 0.3.5: armor plates, Double Tap / Mule Kick buys, more than 5 bots.
- Everything new in 0.3: power-ups, Fire Sale, box cooldown, names, the door money guard, last-alive mode and revive abandon.

## Not ported
- Immunity to lava and map hazards.
- The box tier list, knife, grenade and shield use.
- Grief (BO7 Zombies has no Grief).

## Credits
- **RlKk01**: original *ZM Bots* mod for BO2 Zombies (Plutonium), with GerardS0406, BySc and techboy04gaming.
- **supergamer9787**: *Zombie Bots* v3.0 / v4.0 for BO2 Zombies. The chatter and HUD texts come from it.
- **Fuzion28**: BO7 port.

This is an unofficial port. If you are one of the original authors and want it changed or removed, open an issue.
