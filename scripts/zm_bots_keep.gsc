#namespace zm_bots_keep;

// Leave the last zombie (not in the original). With zb_keep_last 1: once every zombie of the round has spawned and
// only one is still alive, the bots stop shooting so a human decides when the round ends.
// Bots shoot again when a new round starts, or when no human is up (so bots alone still finish the round).
// Round spawning done = level.var_a009ab14ee0d3223.var_59c4f3931d764b9c, set to 1 when the round's spawn count is
// reached and to 0 at the next round start (zm_round_spawning, srvbase script_4e3b2b1d9542e66b.gsc:496-527).
// botsetflag( flag, value ) = builtin function_9dfcfc6e680af2db, "disable_attack": srvbase script_4f2ec5e36fe18c11.gsc:198,
// script_eaf05a0beebb7d4.gsc:3353.
// First try with only disable_attack: in game the bots still killed the last zombie, so the hold also lowers the
// bot's weapons with disableweapons / enableweapons (plain builtins, as FuzMenu zm_mod_menu.gsc:2063/2067),
// and prints a line when it starts so a test shows whether the last-zombie check fired at all.
// Tested in game (2026-11-21): the bots no longer kill the last zombie. Melee not checked on its own.

autoexec init()
{
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    self.zb_hold = 0;
    for ( ;; )
    {
        wait 0.5;
        if ( ( level.zb_cfg_keep_last ?? 0 ) == 1 && last_one() && human_up() )
        {
            // set again every tick: a respawn may reset the bot's flags
            self function_9dfcfc6e680af2db( "disable_attack", 1 );
            if ( !self.zb_hold )
            {
                self disableweapons();
                self.zb_hold = 1;
                announce();
            }
        }
        else if ( self.zb_hold )
        {
            self function_9dfcfc6e680af2db( "disable_attack", 0 );
            self enableweapons();
            self.zb_hold = 0;
            level.zb_keep_said = undefined;
        }
    }
}

last_one()
{
    if ( !isdefined( level.var_a009ab14ee0d3223 ) || !istrue( level.var_a009ab14ee0d3223.var_59c4f3931d764b9c ) )
        return 0;
    self.zb_keep_n = 0;
    foreach ( z in function_926af5fe60499e85( "team_two_hundred" ) ) // getaiarray, as zm_bots_move.gsc scan
        if ( isdefined( z ) && isalive( z ) && !istrue( z.var_79d93e09fbd8c147 ) ) // skipped by the game's own count too (function_45bd2c072cb4631a)
            self.zb_keep_n = self.zb_keep_n + 1;
    return self.zb_keep_n == 1;
}

// one line per hold, not one per bot
announce()
{
    if ( isdefined( level.zb_keep_said ) )
        return;
    level.zb_keep_said = 1;
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) )
            p iprintln( "^5zmbots^7: last zombie, bots hold fire" );
}

human_up()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) && isalive( p ) && !istrue( p.var_d0697a2251283e17 ) )
            return 1;
    return 0;
}
