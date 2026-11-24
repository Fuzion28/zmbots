#namespace zm_bots_cmd;

// Human commands, ported from zm_bo2_bots.gsc: manual_bot_teleport_monitor / execute_bot_teleport /
// bot_staggered_teleport, bot_command_mode_monitor / bot_cycle_command_mode, bot_move_here_monitor / bot_move_here,
// bot_show_hints and bot_console_command_think.
// Input, same buttons as the original:
//   double-tap Dpad Down (+actionslot 2) = cycle mode stay -> wander -> wander_further -> follow -> stay
//   hold Dpad Down 0.7 s                 = move here: bots hold the spot you look at
//   double-tap Dpad Left (+actionslot 3) = teleport bots to you
// notifyonplayercommand = function_5c73a3716d3cf7d0( "notify", "+actionslot N" ), then waittill( #"notify" )
// (srvbase script_59a28aa393c6bb32.gsc:709-715; dpad press and release pairs in script_2ffc9cc854107314.gsc:401-409).
// Fallback that needs no Dpad (keyboard): command wheel on ADS + Use, polled with the buttons FuzMenu reads
// (adsbuttonpressed / usebuttonpressed, FuzMenu zm_mod_menu.gsc:1085,1120, proven in game).
// Console fallback like the original "set bot_cmd x": dvar zb_cmd (unverified in game that a user can set it).
// Global mode for the HUD: level.zb_cmd_mode. No int locals: state lives in self.* / level.* fields.

autoexec init()
{
    level.zb_cmd_offsets = [ ( 50, 0, 0 ), ( -50, 0, 0 ), ( 0, 50, 0 ), ( 0, -50, 0 ) ];
    level.zb_wheel_items = [ "follow me", "stay here", "wander", "wander further", "hold where I look", "teleport to me", "reroll personalities", "status" ];
    setdvar( @"zb_cmd", "" ); // FuzMenu zm_mod_menu.gsc:91 pattern
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
    level thread humans_loop();
    level thread console_loop();
}

// self = bot: apply the current mode once (the core starts every bot on "follow")
think()
{
    self endon( #"disconnect" );
    if ( isdefined( self.zb_cmd_done ) )
        return;
    self.zb_cmd_done = 1;
    if ( !isdefined( level.zb_cmd_mode ) )
        level.zb_cmd_mode = level.zb_cfg_mode ?? "follow";
    self.zb_mode = level.zb_cmd_mode;
    if ( self.zb_mode == "stay" )
        self.zb_stay_pos = self.origin;
}

// starts the monitors on every human, late joiners too (original: human connect watcher)
humans_loop()
{
    for ( ;; )
    {
        if ( isdefined( level.players ) )
            foreach ( p in level.players )
                if ( isdefined( p ) && !isbot( p ) && !isdefined( p.zb_cmd_on ) )
                {
                    p.zb_cmd_on = 1;
                    p thread down_monitor();
                    p thread left_monitor();
                    p thread wheel_monitor();
                    p thread hint();
                    level.zb_status = "commands ready";
                }
        wait 1;
    }
}

hint()
{
    self endon( #"disconnect" );
    if ( ( level.zb_cfg_hints ?? 1 ) == 0 )
        return;
    wait 6;
    self iprintlnbold( "^5zmbots^7: Dpad Down x2 = bot mode, hold = hold there, Dpad Left x2 = teleport | ADS+Use = command wheel" );
}

// Dpad Down: a press within 500 ms of the last one cycles the mode, a 700 ms hold is move-here
down_monitor()
{
    self endon( #"disconnect" );
    self notifyonplayercommand( "zb_down_press", "+actionslot 2" ); // function_5c73a3716d3cf7d0, zm script_2ffc9cc854107314.gsc:402
    self notifyonplayercommand( "zb_down_release", "-actionslot 2" ); // release form: srvbase script_59a28aa393c6bb32.gsc:710
    self.zb_down_last = 0;
    self.zb_down_up = 0;
    self thread down_release();
    for ( ;; )
    {
        self waittill( #"zb_down_press" );
        self.zb_down_at = gettime();
        if ( self.zb_down_at - self.zb_down_last < 500 )
        {
            self.zb_down_last = 0;
            self thread cycle_mode();
            wait 1;
            continue;
        }
        self.zb_down_last = self.zb_down_at;
        // poll the release time instead of waittill: a lost release (menu, death) would freeze Dpad Down for good
        while ( self.zb_down_up < self.zb_down_at && gettime() - self.zb_down_at < 2000 )
            wait 0.05;
        if ( self.zb_down_up >= self.zb_down_at && self.zb_down_up - self.zb_down_at >= 700 )
        {
            self.zb_down_last = 0;
            self thread move_here();
        }
    }
}

down_release()
{
    self endon( #"disconnect" );
    for ( ;; )
    {
        self waittill( #"zb_down_release" );
        self.zb_down_up = gettime();
    }
}

// Dpad Left double-tap: teleport, then 1 s lockout like the original
left_monitor()
{
    self endon( #"disconnect" );
    self notifyonplayercommand( "zb_left_press", "+actionslot 3" ); // zm script_2ffc9cc854107314.gsc:407
    self.zb_left_last = 0;
    for ( ;; )
    {
        self waittill( #"zb_left_press" );
        if ( gettime() - self.zb_left_last < 500 )
        {
            self.zb_left_last = 0;
            self thread teleport();
            wait 1;
        }
        else
            self.zb_left_last = gettime();
    }
}

// ADS + Use: each press shows the next command; 2 s without a press runs the shown one
wheel_monitor()
{
    self endon( #"disconnect" );
    self.zb_wheel = -1;
    for ( ;; )
    {
        wait 0.05;
        // FuzMenu is open: Use is its confirm key
        if ( isdefined( self.zmm ) && istrue( self.zmm.is_open ) )
            continue;
        if ( self adsbuttonpressed() && self usebuttonpressed() )
        {
            self.zb_wheel = self.zb_wheel + 1;
            if ( self.zb_wheel >= level.zb_wheel_items.size )
                self.zb_wheel = 0;
            self.zb_wheel_at = gettime();
            self iprintlnbold( "^5Bots^7 command: " + level.zb_wheel_items[ self.zb_wheel ] + " (ADS+Use = next)" );
            while ( self adsbuttonpressed() && self usebuttonpressed() )
                wait 0.05;
        }
        else if ( self.zb_wheel >= 0 && gettime() - self.zb_wheel_at > 2000 )
        {
            self.zb_cmd = level.zb_wheel_items[ self.zb_wheel ];
            self.zb_wheel = -1;
            self thread run_wheel();
        }
    }
}

// self = human, command in self.zb_cmd
run_wheel()
{
    if ( self.zb_cmd == "follow me" )
        set_mode( "follow" );
    else if ( self.zb_cmd == "stay here" )
        set_mode( "stay" );
    else if ( self.zb_cmd == "wander further" )
        set_mode( "wander_further" );
    else if ( self.zb_cmd == "wander" )
        set_mode( "wander" );
    else if ( self.zb_cmd == "hold where I look" )
        move_here();
    else if ( self.zb_cmd == "teleport to me" )
        teleport();
    else if ( self.zb_cmd == "reroll personalities" )
        reroll();
    else if ( self.zb_cmd == "status" )
        status();
}

// original bot_cycle_command_mode: stay -> wander -> wander_further -> follow -> stay
cycle_mode()
{
    if ( !isdefined( level.zb_cmd_mode ) || level.zb_cmd_mode == "follow" )
        set_mode( "stay" );
    else if ( level.zb_cmd_mode == "stay" )
        set_mode( "wander" );
    else if ( level.zb_cmd_mode == "wander" )
        set_mode( "wander_further" );
    else
        set_mode( "follow" );
}

// self = human who gave the order; stay pins each bot where it stands (original)
set_mode( mode )
{
    level.zb_cmd_mode = mode;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
        {
            p.zb_mode = mode;
            if ( mode == "stay" )
                p.zb_stay_pos = p.origin;
            else
                p.zb_stay_pos = undefined;
        }
    level.zb_status = "mode " + mode;
    self iprintlnbold( "Bots: " + mode );
}

// original bot_move_here: trace 3000 from the eye, a spot within 220 of the hit for each bot, mode stay.
// geteye = function_5255d85caf38b6eb, getplayerangles = function_3996cf2c8d4762a3, anglestoforward = function_44e25da2d51a2988
// (srvbase script_114ff5f60c83a16e.gsc:194); physicstrace(start, end) returns the hit point = function_7d6c548616e54ef4
// (srvbase script_33bfee5f725b7de5.gsc:1722-1726, script_2fc321d925a41e8f.gsc:1335); getclosestpointonnavmesh =
// function_df9f501a2a0cbf4 (srvbase script_108faf3dabbc3e99.gsc:1480) stands in for the original's node search.
// Not ported: the original's findpath check ("they can't get there"); no path builtin is verified.
// unverified in game. Runs in its own thread so an error cannot kill the button monitor.
move_here()
{
    self endon( #"disconnect" );
    if ( self.sessionstate != "playing" )
        return;
    self.zb_mh_eye = self geteye();
    self.zb_mh_hit = physicstrace( self.zb_mh_eye, self.zb_mh_eye + anglestoforward( self getplayerangles() ) * 3000 );
    self.zb_mh_n = 0;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
        {
            p.zb_mh_spot = getclosestpointonnavmesh( self.zb_mh_hit + level.zb_cmd_offsets[ self.zb_mh_n % level.zb_cmd_offsets.size ] );
            if ( !isdefined( p.zb_mh_spot ) || distance( p.zb_mh_spot, self.zb_mh_hit ) > 220 )
                p.zb_mh_spot = getclosestpointonnavmesh( self.zb_mh_hit );
            if ( !isdefined( p.zb_mh_spot ) || distance( p.zb_mh_spot, self.zb_mh_hit ) > 220 )
                continue;
            p.zb_stay_pos = p.zb_mh_spot;
            p.zb_mode = "stay";
            self.zb_mh_n = self.zb_mh_n + 1;
        }
    if ( self.zb_mh_n == 0 )
    {
        self iprintlnbold( "^5Bots^7: they can't stand there" );
        return;
    }
    level.zb_cmd_mode = "stay";
    level.zb_status = "move here " + self.zb_mh_n;
    self iprintlnbold( "Bots: hold that position (" + self.zb_mh_n + ")" );
}

// original execute_bot_teleport + bot_staggered_teleport: only while on the ground, offsets +-50, 0.2-0.4 s apart.
// isonground = function_104df4fcd5adb088 (zm script_1462ea00c464fd65.gsc:210); setorigin = function_a544338816001600 (core);
// randomfloatrange = function_e6b922a34162edc2 (srvbase script_110f3a07c5099e1c.gsc:2873)
teleport()
{
    self endon( #"disconnect" );
    if ( self.sessionstate != "playing" )
        return;
    if ( !self isonground() )
    {
        self iprintlnbold( "You must be on the ground to teleport the bots." );
        return;
    }
    self.zb_tp_n = 0;
    self.zb_tp_m = 0;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
            self.zb_tp_m = self.zb_tp_m + 1;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
        {
            p function_a544338816001600( self.origin + level.zb_cmd_offsets[ self.zb_tp_n % level.zb_cmd_offsets.size ] );
            self.zb_tp_n = self.zb_tp_n + 1;
            wait randomfloatrange( 0.2, 0.4 );
        }
    level.zb_status = "teleported " + self.zb_tp_n;
    self iprintlnbold( "Bots teleported! (" + self.zb_tp_n + "/" + self.zb_tp_m + ")" );
}

// not in the original: new random personality per bot (uses zm_bots_pers.gsc's roll)
reroll()
{
    if ( !isdefined( level.zb_pers_set ) )
    {
        self iprintlnbold( "^5Bots^7: personalities module not loaded" );
        return;
    }
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
        {
            p [[ level.zb_pers_set ]]();
            self iprintlnbold( p.name + " is now " + p.zb_pers );
        }
}

// original "status" console command (money and weapon left out: no verified BO7 field for them)
status()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
            self iprintlnbold( "^5" + p.name + "^7 " + ( p.zb_pers ?? "allrounder" ) + " " + ( p.zb_mode ?? "?" ) + ( istrue( p.var_d0697a2251283e17 ) ? " ^1DOWN^7" : "" ) + " | hp " + p.health + " | K " + ( p.zb_kills ?? 0 ) + " D " + ( p.zb_downs ?? 0 ) + " R " + ( p.zb_revives ?? 0 ) );
}

// original bot_console_command_think: "set zb_cmd <stay|wander|follow|regroup|teleport|movehere|pers|status|help>" (+ keeplast and kick, not in the original).
// getdvar/setdvar with @"name": FuzMenu zm_mod_menu.gsc:1153 (getdvar) and :91 (setdvar).
// The order comes from the first human. regroup = everyone walks back to you (follow); teleport = the original's regroup.
console_loop()
{
    for ( ;; )
    {
        wait 0.5;
        level.zb_cmdv = getdvar( @"zb_cmd", "" );
        if ( !isdefined( level.zb_cmdv ) || level.zb_cmdv == "" )
            continue;
        // cleared only once a host exists, so a command typed before the host spawns is kept
        if ( !isdefined( level.zb_host ) )
            continue;
        level.zb_cmdh = [[ level.zb_host ]]();
        if ( !isdefined( level.zb_cmdh ) )
            continue;
        setdvar( @"zb_cmd", "" );
        if ( level.zb_cmdv == "stay" || level.zb_cmdv == "wander" || level.zb_cmdv == "wander_further" || level.zb_cmdv == "follow" )
            level.zb_cmdh thread set_mode_cmd();
        else if ( level.zb_cmdv == "regroup" )
        {
            level.zb_cmdv = "follow";
            level.zb_cmdh thread set_mode_cmd();
        }
        else if ( level.zb_cmdv == "teleport" )
            level.zb_cmdh thread teleport();
        else if ( level.zb_cmdv == "movehere" )
            level.zb_cmdh thread move_here();
        else if ( level.zb_cmdv == "pers" )
            level.zb_cmdh thread reroll();
        else if ( level.zb_cmdv == "status" )
            level.zb_cmdh thread status();
        else if ( level.zb_cmdv == "diag" )
            level.zb_cmdh thread diag();
        else if ( level.zb_cmdv == "unstick" )
            level.zb_cmdh thread unstick_all();
        else if ( level.zb_cmdv == "keeplast" )
        {
            // toggles the zm_bots_keep.gsc setting (zb_keep_last)
            level.zb_cfg_keep_last = ( ( level.zb_cfg_keep_last ?? 0 ) == 1 ) ? 0 : 1;
            level.zb_cmdh iprintlnbold( "^5zb_cmd^7: leave the last zombie " + ( level.zb_cfg_keep_last == 1 ? "^2on" : "^1off" ) );
            // test aid: what zm_bots_keep.gsc sees right now (alive AI on the zombie team, round fully spawned flag)
            level.zb_cmdn = function_926af5fe60499e85( "team_two_hundred" ).size;
            level.zb_cmdh iprintln( "^5zb_cmd^7: zombie AI " + level.zb_cmdn + ", round spawned " + ( isdefined( level.var_a009ab14ee0d3223 ) ? ( level.var_a009ab14ee0d3223.var_59c4f3931d764b9c ?? "undef" ) : "no struct" ) );
        }
        else if ( level.zb_cmdv == "add" && isdefined( level.zb_add ) )
            level thread [[ level.zb_add ]]();
        else if ( level.zb_cmdv == "kick" )
            level.zb_cmdh thread kick_bot();
        else
            level.zb_cmdh iprintlnbold( "^5zb_cmd^7: help | status | diag | stay | wander | wander_further | follow | regroup | teleport | movehere | pers | unstick | keeplast | add | kick" );
    }
}

// original "diag": one line per bot with what the anti-stuck sees (mode, busy task, stuck stage, distance to you),
// plus points and the last buy result or why the bot is not shopping (zm_bots_buy.gsc zb_buy_why; not in the original)
diag()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
            self iprintlnbold( "^5" + p.name + "^7 " + ( p.zb_mode ?? "?" ) + " busy " + ( p.zb_busy ?? "-" ) + " stuck " + ( p.zb_mv_stage ?? 0 ) + " dist " + int( distance( p.origin, self.origin ) ) + " $" + ( isdefined( p.var_8b69ecbd466a79fa ) ? ( p.var_8b69ecbd466a79fa[ "score" ] ?? "?" ) : "?" ) + " buy: " + ( p.zb_buy_why ?? "-" ) );
}

// not in the original: kick the last bot added. Kick builtin function_af1903472dca798( entnum, reason ) with
// getentitynumber function_937c3c41c638f604(), as the game kicks disconnected players (srvbase script_21a04df18edbd7c9.gsc:882)
kick_bot()
{
    level.zb_kick = undefined;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) )
            level.zb_kick = p;
    if ( !isdefined( level.zb_kick ) )
    {
        self iprintlnbold( "^5Bots^7: no bot to kick" );
        return;
    }
    self iprintlnbold( "^5Bots^7: kicked " + level.zb_kick.name );
    function_af1903472dca798( level.zb_kick function_937c3c41c638f604(), &"hash_44a7d00c557627fb" );
}

// original "unstick" (bot_soft_reset): drop every goal and task, the bots pick a fresh one next tick
unstick_all()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) && isalive( p ) )
        {
            p function_cb0d368fa87a2b78(); // botclearscriptgoal
            p.zb_busy = undefined;
            p.zb_mv_wgoal = undefined;
            p.zb_mv_stage = 0;
            p.zb_mv_anchor = p.origin;
            p.zb_mv_anct = gettime();
        }
    self iprintlnbold( "^5Bots^7: all bots reset" );
}

// threaded wrapper: acts rejects thread calls with args, so the mode comes from level.zb_cmdv
set_mode_cmd()
{
    set_mode( level.zb_cmdv );
}
