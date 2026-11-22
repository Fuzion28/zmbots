#namespace zm_bots_config;

// Settings for the BO7 port of "BO2 Zombies Plutonium Bots" (original: the dvar list at the top of zm_bo2_bots.gsc).
// Each setting reads a dvar with getdvarint/getdvar (function_b4b0c0cb1ac2b968 / function_cf1241c266463447,
// both take (@"name", default): zm script_1005a9f8fa0fdb60.gsc:537, srvbase script_108faf3dabbc3e99.gsc:2372).
// An unset dvar returns the default, so the defaults below are what you get unless something sets the dvar.
// unverified in game: whether a dvar typed by the user (console "set zb_count 2") reaches these reads.
// To change a setting for sure: edit the default (the second argument) in the block below.
// Grief-only settings of the original (bot_grief_*) are left out: BO7 Zombies has no Grief.
// No int locals (they read back undefined in game): everything goes into level.* fields.

autoexec init()
{
    // ===================== USER SETTINGS: edit the second argument =====================
    // Only settings a module really applies are listed. The original's other options (skill, lava immunity,
    // knife/grenade/monkey use, collision, emotes, boss callouts, smart flee, swarm,
    // retreat boost/drive/far/shoot, wallshoot) have no BO7 port yet, see docs/limitations.md.
    level.zb_cfg_count = getdvarint( @"zb_count", 3 );                   // zm_bots: bots to add (1-7, 8-player squad; 5 bots tested in game 2026-11-22)
    level.zb_cfg_fill = getdvarint( @"zb_fill", 0 );                     // zm_bots_fill: 1 = only fill the 8-player squad (bots = 8 - humans, at most zb_count)
    level.zb_cfg_mode = getdvar( @"zb_mode", "wander" );                 // zm_bot_default_mode: stay | wander | wander_further | follow (default wander, as the original)
    level.zb_cfg_hud = getdvarint( @"zb_hud", 1 );                       // zm_bot_hud: mode HUD
    level.zb_cfg_chatter = getdvarint( @"zb_chatter", 1 );               // zm_bot_chatter: bot chat lines
    level.zb_cfg_hints = getdvarint( @"zb_hints", 1 );                   // zm_bot_hints: control hint for humans after 6 s
    level.zb_cfg_perk_round = getdvarint( @"zb_perk_round", 8 );         // bot_perk_round: first round for perk buys
    level.zb_cfg_pap_round = getdvarint( @"zb_pap_round", 10 );          // bot_pap_round: first round for Pack-a-Punch
    level.zb_cfg_personalities = getdvarint( @"zb_personalities", 1 );   // bot_personalities: 0 = every bot is an allrounder
    level.zb_cfg_retreat = getdvarint( @"zb_retreat", 1 );               // bot_low_health_retreat
    level.zb_cfg_retreat_health = getdvarint( @"zb_retreat_health", 75 ); // bot_retreat_health: percent (clamped 30-90)
    level.zb_cfg_keep_distance = getdvarint( @"zb_keep_distance", 1 );   // bot_keep_distance
    level.zb_cfg_max_health = getdvarint( @"zb_max_health", 500 );       // bot_max_health: bot health, doubled with Juggernog (0 = game default)
    level.zb_cfg_infinite_ammo = getdvarint( @"zb_infinite_ammo", 1 );   // bot_infinite_ammo: refill bot reserve ammo every 5 s
    level.zb_cfg_powerups = getdvarint( @"zb_powerups", 1 );             // bot_powerups: pick up power-ups (original rules for nuke / insta-kill / double points)
    level.zb_cfg_last_alive = getdvarint( @"zb_last_alive", 1 );         // bot_last_alive_mode: the last one up kites and only revives when no zombie is within 900
    level.zb_cfg_debug = getdvarint( @"zb_debug", 0 );                   // 1 = show the "zmbots ..." debug lines and the per-round stats lines
    level.zb_cfg_auto_teleport =getdvarint( @"zb_auto_teleport", 0 );   // not in the original (it never teleports): 1 = a bot 1500+ from you for 20 s teleports to you
    level.zb_cfg_keep_last = getdvarint( @"zb_keep_last", 0 );         // not in the original: 1 = bots stop shooting when one zombie is left (round fully spawned)
    // ===================================================================================

    // clamps from the original
    if ( level.zb_cfg_count < 1 )
        level.zb_cfg_count = 1;
    if ( level.zb_cfg_count > 7 )
        level.zb_cfg_count = 7;
    if ( level.zb_cfg_retreat_health < 30 )
        level.zb_cfg_retreat_health = 30;
    if ( level.zb_cfg_retreat_health > 90 )
        level.zb_cfg_retreat_health = 90;
    if ( level.zb_cfg_mode != "stay" && level.zb_cfg_mode != "wander" && level.zb_cfg_mode != "wander_further" )
        level.zb_cfg_mode = "follow";
    // the core reads level.zb_count about 14 s after the host spawns
    level.zb_count = level.zb_cfg_count;
    if ( level.zb_cfg_fill == 1 )
        level thread apply_fill();
}

// zm_bots_fill: bots = 8 - humans (squad size 8), at most zb_count, at least 1.
// shortcut: counts humans present ~1 s after the first one spawns; later joiners don't lower it.
apply_fill()
{
    while ( !isdefined( level.players ) || level.players.size == 0 )
        wait 0.25;
    wait 1;
    level.zb_cfg_humans = 0;
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) )
            level.zb_cfg_humans = level.zb_cfg_humans + 1;
    level.zb_count = 8 - level.zb_cfg_humans;
    if ( level.zb_count > level.zb_cfg_count )
        level.zb_count = level.zb_cfg_count;
    if ( level.zb_count < 1 )
        level.zb_count = 1;
}
