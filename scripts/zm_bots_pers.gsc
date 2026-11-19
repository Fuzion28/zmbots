#namespace zm_bots_pers;

// Personalities, ported from zm_bo2_bots.gsc bot_roll_personality / bot_personality (rolled once, kept across respawns).
// self.zb_pers = "slayer" | "medic" | "gambler" | "engineer" | "allrounder".
// What each one changes in the original, and who ports it here:
//   slayer     grenade cluster -1: not ported (no grenade-throw module; the engine AI decides throws)
//   medic      Quick Revive after Juggernog          -> perk module reads zb_pers
//              up to 3 revivers instead of 2         -> nothing to port: the core sends every free bot, no claim limit
//   gambler    box range x1.5, box cooldown x0.5     -> box module reads zb_pers
//   engineer   door/debris range 500 instead of 300  -> door module reads zb_pers
//   allrounder no change
// The greeting line is chatter (chatter module). bot_personalities 0 (level.zb_cfg_personalities) = all allrounder.

autoexec init()
{
    level.zb_pers_types = [ "slayer", "medic", "gambler", "engineer", "allrounder" ];
    level.zb_pers_set = &roll; // zm_bots_cmd.gsc rerolls with it (self = bot)
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    // the core rethreads modules on every spawn; the personality survives like self.bot.personality did
    if ( !isdefined( self.zb_pers ) )
        roll();
}

// self = bot; randomint = function_de284a0228a3400e (zm script_10107dc25f5bd62e.gsc:453)
roll()
{
    if ( isdefined( level.zb_cfg_personalities ) && level.zb_cfg_personalities == 0 )
        self.zb_pers = "allrounder";
    else
        self.zb_pers = level.zb_pers_types[ randomint( level.zb_pers_types.size ) ];
}
