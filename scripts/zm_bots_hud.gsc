#namespace zm_bots_hud;

// Mode HUD and bot stats, ported from zm_bo2_bots.gsc bot_mode_hud_think and the "status" line of bot_cmd.
// - HUD: "BOTS: FOLLOW/STAY/WANDER" (MIXED when bots differ) plus one stats line per bot, drawn by lua/zm_bots_hud_post.lua
// - with zb_debug 1, every human also gets one iprintln line per bot at each round start
// - writes self.zb_kills (from the stats player.kills) and self.zb_downs (counted on the downed edge)
// level.zb_cfg_hud 0 (zb_hud) hides the HUD and stops the stats lines.

autoexec init()
{
    setdvar( @"zb_hudtxt", "" ); // clears the last match's text
    level.zb_stats = &print_stats; // self = player to show the stats to, e.g. `p [[ level.zb_stats ]]();`
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    self notify( #"zb_hud_think" );
    self endon( #"zb_hud_think" );
    if ( !isdefined( level.zb_hud_started ) )
    {
        level.zb_hud_started = 1;
        level thread hud_loop();
        level thread round_stats();
    }
    for ( ;; )
    {
        wait 0.5;
        // zombie kills: stats::function_ee7ea2a7c2c198f3 sets player.kills = pers["kills"] (srvbase script_11083f13727030d8.gsc:399, :423)
        if ( isdefined( self.kills ) )
            self.zb_kills = self.kills;
        if ( istrue( self.var_d0697a2251283e17 ) && !istrue( self.zb_hud_wasdown ) )
            self.zb_downs = ( self.zb_downs ?? 0 ) + 1;
        self.zb_hud_wasdown = istrue( self.var_d0697a2251283e17 );
    }
}

// original texts; mode is per bot here, so MIXED when the bots disagree
mode_text()
{
    level.zb_hud_mode = undefined;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
        {
            if ( !isdefined( level.zb_hud_mode ) )
                level.zb_hud_mode = p.zb_mode ?? "follow";
            else if ( level.zb_hud_mode != ( p.zb_mode ?? "follow" ) )
                level.zb_hud_mode = "mixed";
        }
    if ( !isdefined( level.zb_hud_mode ) )
        return "";
    if ( level.zb_hud_mode == "stay" )
        return "BOTS: STAY";
    if ( level.zb_hud_mode == "follow" )
        return "BOTS: FOLLOW";
    if ( level.zb_hud_mode == "wander_further" )
        return "BOTS: WANDER FURTHER";
    if ( level.zb_hud_mode == "mixed" )
        return "BOTS: MIXED";
    return "BOTS: WANDER";
}

// writes the HUD text to dvar zb_hudtxt ("|" = new line); lua/zm_bots_hud_post.lua draws it top-left.
// GSC hud elems (newclienthudelem + settext) did not show in BO7 in game, so the text goes through a dvar like FuzMenu.
hud_loop()
{
    level endon( #"game_ended" );
    for ( ;; )
    {
        wait 0.5;
        level.zb_hud_txt = "";
        if ( ( level.zb_cfg_hud ?? 1 ) != 0 )
        {
            level.zb_hud_txt = mode_text();
            foreach ( b in level.players )
                if ( isdefined( b ) && isbot( b ) && isdefined( b.zmbots ) )
                    level.zb_hud_txt = level.zb_hud_txt + "|" + b.name + "  " + ( b.zb_pers ?? "allrounder" ) + "  " + bot_state( b ) + "  hp " + b.health + "  K " + ( b.zb_kills ?? 0 ) + " D " + ( b.zb_downs ?? 0 ) + " R " + ( b.zb_revives ?? 0 ) + "  perks " + perks_owned( b ) + " guns " + ( b.zb_weapons_bought ?? 0 ) + " doors " + ( b.zb_doors_opened ?? 0 );
        }
        if ( !( level.zb_hud_txt === level.zb_hud_said ) )
        {
            setdvar( @"zb_hudtxt", level.zb_hud_txt );
            level.zb_hud_said = level.zb_hud_txt;
        }
    }
}

// periodic stats (task fallback for the original per-bot hud lines): one line per bot at every round start
// on_round_start waittill: srvbase script_2bdf8eafdb703418.gsc:7965
round_stats()
{
    level endon( #"game_ended" );
    for ( ;; )
    {
        level waittill( #"on_round_start" );
        if ( ( level.zb_cfg_hud ?? 1 ) == 0 || ( level.zb_cfg_debug ?? 0 ) == 0 ) // the HUD panel shows the same stats
            continue;
        foreach ( p in level.players )
            if ( isdefined( p ) && !isbot( p ) )
                p print_stats();
    }
}

// self = human; same fields as the original status line where BO7 has them
print_stats()
{
    foreach ( b in level.players )
        if ( isdefined( b ) && isbot( b ) && isdefined( b.zmbots ) )
            self iprintln( "^5" + b.name + "^7 " + ( b.zb_pers ?? "allrounder" ) + " " + bot_state( b ) + " " + ( b.zb_mode ?? "follow" ) + " | hp " + b.health + " | K " + ( b.zb_kills ?? 0 ) + " D " + ( b.zb_downs ?? 0 ) + " R " + ( b.zb_revives ?? 0 ) + " | $" + ( b.zb_spent ?? 0 ) + " | perks " + perks_owned( b ) + " guns " + ( b.zb_weapons_bought ?? 0 ) + " doors " + ( b.zb_doors_opened ?? 0 ) ); // iprintln: srvbase script_2d110487966779fc.gsc:18
}

// perks the bot owns, bought or given (FuzMenu): the game's per-player perk list var_298fe7dcdb17fe4f[ perk ] = 1
// (srvbase script_25a8fa2ac8997425.gsc:275 set, :377/:428 cleared). Count in a field: int locals read back undefined.
perks_owned( b )
{
    b.zb_perks_n = 0;
    foreach ( v in b.var_298fe7dcdb17fe4f ?? [] )
        if ( istrue( v ) )
            b.zb_perks_n = b.zb_perks_n + 1;
    return b.zb_perks_n;
}

bot_state( b )
{
    if ( !isalive( b ) || b.sessionstate != "playing" )
        return "out";
    if ( istrue( b.var_d0697a2251283e17 ) )
        return "DOWN";
    if ( isdefined( b.zb_busy ) )
        return "busy:" + b.zb_busy;
    return "ok";
}
