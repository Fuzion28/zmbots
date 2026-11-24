#using scripts\common\utility;

#namespace zm_bots;

// Core of the BO7 port of "BO2 Zombies Plutonium Bots" (supergamer9787 / RlKk01).
// Spawns the bots, revives, follows, and runs feature modules. Module contract (see docs/modules.md):
// - a module file's autoexec appends a think pointer to level.zb_mods; the core threads each one on every bot (self = bot)
// - modules talk to the core only through level.zb_msg / level.zb_host / level.zb_status (cross-file namespace calls are unproven)
// - self.zb_busy (string) = a module owns movement; the core follow then does nothing
// - self.zb_mode: "follow" (default), "stay" (hold self.zb_stay_pos); any other mode = the module that set it moves the bot
// - priority: revive (core) > modules that set zb_busy > follow
// No int locals: in game they read back undefined, so state lives in level.* / self.* fields.

autoexec init()
{
    if ( isdefined( level.zmbots_initialized ) )
        return;
    level.zmbots_initialized = 1;
    level.zb_msg = &msg;
    level.zb_host = &host;
    level.zb_downed = &downed;
    level.zb_last = &last_alive;
    level.zb_add = &add_bot;
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level thread start_when_playing();
}

// the host can spawn before mod scripts run, so poll like FuzMenu's menu_scan_players instead of player_spawned
start_when_playing()
{
    for ( ;; )
    {
        level.zb_h = host();
        if ( isdefined( level.zb_h ) && isalive( level.zb_h ) && level.zb_h.sessionstate == "playing" )
            break;
        wait 0.25;
    }
    wait 2;
    level.zb_status = "loaded, " + level.zb_mods.size + " modules";
    level thread status_loop();
    level thread spawn_bots();
}

// first human player (bots also sit in level.players)
host()
{
    if ( !isdefined( level.players ) )
        return undefined;
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) )
            return p;
    return undefined;
}

spawn_bots()
{
    // Cursed / relic modes check every player that spawns in the first 10 s (dvar default 10000 ms, srvbase
    // script_60b9c6f799b0d5d8.gsc function_b46b00a6fd556694) and can end the match; a bot fails that check.
    // Spawning after the window skips it. shortcut: waits in every mode, gate on the gametype if the delay bothers.
    level.zb_adding = 1; // add_bot refuses until the initial spawn is done
    wait 12;
    // level.zb_count may be set by the config module (zm_bots_config.gsc); 7 = full 8-player squad
    if ( !isdefined( level.zb_count ) )
        level.zb_count = 3;
    // bots already in the lobby (Kronos test_bots) are taken over, not respawned
    level.zb_lobby = 0;
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && !isdefined( p.zmbots ) )
        {
            p.zmbots = 1;
            level.zb_lobby = level.zb_lobby + 1;
            p thread bot_start();
        }
    level.zb_i = level.zb_lobby;
    while ( level.zb_i < level.zb_count )
    {
        level.zb_status = "adding bot " + ( level.zb_i + 1 ) + "/" + level.zb_count;
        level.zb_added = addbot( bot_name() );
        // addbot only gives a connecting client; zm_bots_client.gsc finishes the connect like BO6 spawn_bot_latent
        if ( !isdefined( level.zb_latent ) )
        {
            msg( "^1zmbots E no latent (zm_bots_client.gsc not linked)" ); // errors show even without zb_debug
            level.zb_adding = undefined;
            return;
        }
        if ( isdefined( level.zb_added ) )
            level.zb_added thread [[ level.zb_latent ]]();
        wait_new_bot();
        if ( !isdefined( level.zb_bot ) )
        {
            msg( "^1zmbots E bot " + ( level.zb_i + 1 ) + " missing, lat " + level.zb_lat );
            level.zb_adding = undefined;
            return;
        }
        level.zb_bot.zmbots = 1;
        level.zb_bot.zb_index = level.zb_i;
        level.zb_bot thread bot_start();
        level.zb_i = level.zb_i + 1;
        wait 1;
    }
    level.zb_adding = undefined;
    level.zb_status = "^2" + level.zb_count + " bots ready";
}

// sets level.zb_bot to a bot not yet taken over (marked at once so add and spawn cannot both take it), or undefined after 60 s (latent waits 60 s); polls so a missed notify cannot hang
wait_new_bot()
{
    level.zb_bot = undefined;
    level.zb_t = 0;
    while ( level.zb_t < 240 && !isdefined( level.zb_bot ) )
    {
        wait 0.25;
        level.zb_t = level.zb_t + 1;
        foreach ( p in level.players )
            if ( !isdefined( level.zb_bot ) && isdefined( p ) && isbot( p ) && !isdefined( p.zmbots ) )
            {
                level.zb_bot = p;
                p.zmbots = 1;
            }
    }
}

bot_start()
{
    self endon( #"disconnect" );
    while ( !isalive( self ) )
        wait 0.1;
    if ( !isdefined( self.zb_mode ) )
        self.zb_mode = "follow";
    self.zb_host = host();
    if ( isdefined( self.zb_host ) )
        self function_a544338816001600( self.zb_host.origin + ( 40, 0, 0 ) ); // setorigin
    // each module thread is separate: a runtime error in one only kills that thread
    foreach ( f in level.zb_mods )
        self thread [[ f ]]();
    for ( ;; )
    {
        wait 0.5;
        self.zb_host = host();
        if ( !isdefined( self.zb_host ) || !isalive( self ) )
            continue;
        // a downed bot used to get a new follow/stay goal every 0.5 s; clear it once and wait (tester: FPS tanks while a bot is down, cause unverified)
        if ( downed( self ) )
        {
            if ( !istrue( self.zb_down_clr ) )
                self function_cb0d368fa87a2b78();
            self.zb_down_clr = 1;
            continue;
        }
        self.zb_down_clr = undefined;
        if ( bot_revive() )
            continue;
        self.zb_goal_p = undefined; // rev_goal cache: follow and modules set their own goals
        if ( isdefined( self.zb_busy ) )
            continue;
        if ( self.zb_mode == "stay" && isdefined( self.zb_stay_pos ) )
        {
            if ( distance( self.origin, self.zb_stay_pos ) > 80 )
                self function_75794c5ddff5c061( self.zb_stay_pos, 40, "critical" ); // botsetscriptgoal
            continue;
        }
        if ( self.zb_mode != "follow" )
            continue;
        if ( distance( self.origin, self.zb_host.origin ) > 350 )
            self function_75794c5ddff5c061( self.zb_host.origin, 150, "critical" );
        else
            self function_cb0d368fa87a2b78(); // botclearscriptgoal
    }
}

// downed = player.var_d0697a2251283e17, what player::function_fd9147715bbe28f3 reads (zm_laststand uses it to find downed players)
downed( p )
{
    return isdefined( p ) && istrue( p.var_d0697a2251283e17 );
}

// BO6 bots::revive_player ported: walk to the downed player, look at them, hold use (verified in game)
// botlookatpoint = function_b217ccc053191d61, botpressbutton = function_aba9ac6f872dc502
// returns 1 while a revive is in progress so the follow step is skipped
// original revive_claimer_count / guard_claimer_count: at most 2 bots revive one downed player; the others,
// within 1000, guard a spot 150 around them (at most 2 guards), and the engine AI shoots what comes.
bot_revive()
{
    self.zb_rev = undefined;
    self.zb_guard = undefined;
    // zb_rev_wait: a revive given up because the bot was surrounded; zm_bots_move.gsc escape() moves it out meanwhile
    // zb_rev_cd: a revive that timed out (not in the original), so a failing bot does not retry every 0.5 s
    if ( downed( self ) || istrue( self.zb_norevive ) || gettime() < ( self.zb_rev_wait ?? 0 ) || gettime() < ( self.zb_rev_cd ?? 0 ) )
        return 0;
    foreach ( p in level.players )
        if ( p != self && downed( p ) && claimers( p, 0 ) < ( self.zb_pers === "medic" ? 3 : 2 ) && ( !isdefined( self.zb_rev ) || distance( self.origin, p.origin ) < distance( self.origin, self.zb_rev.origin ) ) )
            self.zb_rev = p;
    // original build 44 (bot_last_alive_mode): the last one up only revives when no zombie is within 900 of it or of the downed player
    if ( isdefined( self.zb_rev ) && ( level.zb_cfg_last_alive ?? 1 ) == 1 && last_alive() && ( function_e93520ec766414ac( self.origin, 900 ).size > 0 || function_e93520ec766414ac( self.zb_rev.origin, 900 ).size > 0 ) )
    {
        self.zb_rev = undefined;
        return 0;
    }
    if ( !isdefined( self.zb_rev ) )
    {
        foreach ( p in level.players )
            if ( !isdefined( self.zb_guard ) && p != self && downed( p ) && claimers( p, 1 ) < 2 && distance( self.origin, p.origin ) < 1000 )
                self.zb_guard = p;
        if ( !isdefined( self.zb_guard ) )
            return 0;
        // spot picked once per guarded player and snapped to the navmesh: an unreachable spot re-pathed every 0.5 s all round
        if ( !isdefined( self.zb_guard_pos ) || !( self.zb_guard_of === self.zb_guard ) || distance( self.zb_guard_pos, self.zb_guard.origin ) > 300 )
        {
            self.zb_guard_of = self.zb_guard;
            self.zb_guard_pos = function_df9f501a2a0cbf4( self.zb_guard.origin + function_44e25da2d51a2988( ( 0, function_de284a0228a3400e( 360 ), 0 ) ) * 150 ) ?? self.zb_guard.origin; // anglestoforward * 150, as move.gsc wander
        }
        if ( distance( self.origin, self.zb_guard_pos ) > 120 )
            rev_goal( self.zb_guard_pos, 100 );
        return 1;
    }
    self.zb_guard_pos = undefined;
    if ( distance( self.origin, self.zb_rev.origin ) > 60 )
    {
        rev_goal( self.zb_rev.origin, 48 );
        return 1;
    }
    self notify( #"zb_reviving" );
    self function_cb0d368fa87a2b78();
    self function_b217ccc053191d61( self.zb_rev.origin + ( 0, 0, 20 ), 8, "script_forced" );
    wait 0.3;
    self function_aba9ac6f872dc502( "use", 8 );
    self.zb_rev_until = gettime() + 8500;
    while ( gettime() < self.zb_rev_until && downed( self.zb_rev ) && isalive( self ) && !downed( self ) )
    {
        wait 0.25;
        // not in the original: surrounded (4+ zombies within 120) -> give up for 4 s, escape, then come back
        if ( function_e93520ec766414ac( self.origin, 120 ).size >= 4 && downed( self.zb_rev ) )
        {
            self.zb_rev_wait = gettime() + 4000;
            self.zb_rev = undefined;
            level.zb_status = "revive abandoned, surrounded " + self.name;
            return 1;
        }
    }
    if ( isdefined( self.zb_rev ) && isalive( self.zb_rev ) && !downed( self.zb_rev ) ) // not bled out or gone
    {
        self.zb_revives = ( isdefined( self.zb_revives ) ? self.zb_revives : 0 ) + 1;
        self notify( #"zb_revived", self.zb_rev );
    }
    else if ( downed( self.zb_rev ) && isalive( self ) && !downed( self ) ) // held 8.5 s, still down
        self.zb_rev_cd = gettime() + 10000;
    self.zb_goal_p = undefined;
    return 1;
}

// botsetscriptgoal only when the spot moved 32+ or after 3 s; the engine re-paths on every call (FPS suspect while someone is down)
rev_goal( pos, r )
{
    if ( isdefined( self.zb_goal_p ) && distance( pos, self.zb_goal_p ) < 32 && gettime() < self.zb_goal_t )
        return;
    self.zb_goal_p = pos;
    self.zb_goal_t = gettime() + 3000;
    self function_75794c5ddff5c061( pos, r, "critical" );
}

// original bot_is_last_alive: no other player alive and up (level.zb_last for zm_bots_move.gsc)
last_alive()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && p != self && isalive( p ) && !downed( p ) )
            return 0;
    return 1;
}

// bots other than self that revive (guard 0) or guard (guard 1) downed player d; a count in a level field, not an int local
claimers( d, guard )
{
    level.zb_claims = 0;
    foreach ( b in level.players )
        if ( isdefined( b ) && b != self && isdefined( b.zmbots ) && ( guard ? b.zb_guard === d : b.zb_rev === d ) )
            level.zb_claims = level.zb_claims + 1;
    return level.zb_claims;
}

// a random unused name from the original bots.txt list (addbot( name ) sets the bot's name); "zmbot" once all are used
bot_name()
{
    if ( !isdefined( level.zb_names ) )
        level.zb_names = [ "Rusty_Hinge", "GhostToast", "NoScopeNana", "TrainConductor", "CampingCarl", "Box_Gambler", "JuggerNOT", "MuleKickMike", "PaP_Pete", "DeadshotDan", "WallBuyWendy", "StaminUpSteve", "QuickRevQueen", "RayGunRita", "TeddyBearTony", "WindowBoarder", "LastStandLarry", "CrawlerCrusher", "NukeNoob", "SprintAndPray", "Round99Dreamer", "TrapLordTerry", "SlidingSally", "OlympiaOllie" ];
    if ( level.zb_names.size == 0 )
        return "zmbot";
    level.zb_nm = level.zb_names[ function_de284a0228a3400e( level.zb_names.size ) ]; // randomint
    level.zb_left = [];
    foreach ( n in level.zb_names )
        if ( n != level.zb_nm )
            level.zb_left[ level.zb_left.size ] = n;
    level.zb_names = level.zb_left;
    return level.zb_nm;
}

// console "add" (original bot_console_add): one more bot if the 8-player squad has room
add_bot()
{
    level.zb_have = level.players.size;
    if ( level.zb_have >= 8 || !isdefined( level.zb_latent ) )
    {
        msg( "^5Bots^7: squad full" );
        return;
    }
    // two adds at once shared level.zb_bot and both took over the same bot
    if ( istrue( level.zb_adding ) )
    {
        msg( "^5Bots^7: a bot is still joining" );
        return;
    }
    level.zb_adding = 1;
    level.zb_added = addbot( bot_name() );
    if ( isdefined( level.zb_added ) )
        level.zb_added thread [[ level.zb_latent ]]();
    wait_new_bot();
    level.zb_adding = undefined;
    if ( !isdefined( level.zb_bot ) )
    {
        msg( "^5Bots^7: add failed" );
        return;
    }
    level.zb_bot.zmbots = 1;
    level.zb_bot thread bot_start();
    msg( "^5Bots^7: bot added" );
}

// repeats the last status so a message overwritten on screen still shows; level.zb_quiet pauses it, empty status stops printing
status_loop()
{
    for ( ;; )
    {
        // debug lines only with zb_debug 1 (errors call msg directly)
        if ( !istrue( level.zb_quiet ) && isdefined( level.zb_status ) && level.zb_status != "" )
        {
            if ( ( level.zb_cfg_debug ?? 0 ) == 1 )
                msg( "^3zmbots " + level.zb_status );
            level.zb_status = "";
        }
        wait 3;
    }
}

// a bare iprintlnbold (no player as self) seems to stop the thread in BO7, so send to every human
msg( text )
{
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) )
            p iprintlnbold( text );
}
