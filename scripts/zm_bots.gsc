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
    wait 4;
    // level.zb_count may be set by the config module (zm_bots_config.gsc); 3 = full 4-player squad
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
        level.zb_added = addbot( "zmbot" );
        // addbot only gives a connecting client; zm_bots_client.gsc finishes the connect like BO6 spawn_bot_latent
        if ( !isdefined( level.zb_latent ) )
        {
            level.zb_status = "^1E no latent (zm_bots_client.gsc not linked)";
            return;
        }
        if ( isdefined( level.zb_added ) )
            level.zb_added thread [[ level.zb_latent ]]();
        wait_new_bot();
        if ( !isdefined( level.zb_bot ) )
        {
            level.zb_status = "^1E bot " + ( level.zb_i + 1 ) + " missing, lat " + level.zb_lat;
            return;
        }
        level.zb_bot.zmbots = 1;
        level.zb_bot.zb_index = level.zb_i;
        level.zb_bot thread bot_start();
        level.zb_i = level.zb_i + 1;
        wait 1;
    }
    level.zb_status = "^2" + level.zb_count + " bots ready";
}

// sets level.zb_bot to a bot not yet taken over, or undefined after 15 s; polls so a missed notify cannot hang
wait_new_bot()
{
    level.zb_bot = undefined;
    level.zb_t = 0;
    while ( level.zb_t < 60 && !isdefined( level.zb_bot ) )
    {
        wait 0.25;
        level.zb_t = level.zb_t + 1;
        foreach ( p in level.players )
            if ( isdefined( p ) && isbot( p ) && !isdefined( p.zmbots ) )
                level.zb_bot = p;
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
        if ( bot_revive() )
            continue;
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
    if ( downed( self ) || istrue( self.zb_norevive ) )
        return 0;
    foreach ( p in level.players )
        if ( p != self && downed( p ) && claimers( p, 0 ) < 2 && ( !isdefined( self.zb_rev ) || distance( self.origin, p.origin ) < distance( self.origin, self.zb_rev.origin ) ) )
            self.zb_rev = p;
    if ( !isdefined( self.zb_rev ) )
    {
        foreach ( p in level.players )
            if ( !isdefined( self.zb_guard ) && p != self && downed( p ) && claimers( p, 1 ) < 2 && distance( self.origin, p.origin ) < 1000 )
                self.zb_guard = p;
        if ( !isdefined( self.zb_guard ) )
            return 0;
        if ( !isdefined( self.zb_guard_off ) )
            self.zb_guard_off = function_44e25da2d51a2988( ( 0, function_de284a0228a3400e( 360 ), 0 ) ) * 150; // anglestoforward * 150, as move.gsc wander
        if ( distance( self.origin, self.zb_guard.origin + self.zb_guard_off ) > 120 )
            self function_75794c5ddff5c061( self.zb_guard.origin + self.zb_guard_off, 100, "critical" );
        return 1;
    }
    self.zb_guard_off = undefined;
    if ( distance( self.origin, self.zb_rev.origin ) > 60 )
    {
        self function_75794c5ddff5c061( self.zb_rev.origin, 24, "critical" );
        return 1;
    }
    self notify( #"zb_reviving" );
    self function_cb0d368fa87a2b78();
    self function_b217ccc053191d61( self.zb_rev.origin + ( 0, 0, 20 ), 8, "script_forced" );
    wait 0.3;
    self function_aba9ac6f872dc502( "use", 8 );
    self.zb_until = gettime() + 8500;
    while ( gettime() < self.zb_until && downed( self.zb_rev ) && isalive( self ) && !downed( self ) )
        wait 0.25;
    if ( !downed( self.zb_rev ) )
    {
        self.zb_revives = ( isdefined( self.zb_revives ) ? self.zb_revives : 0 ) + 1;
        self notify( #"zb_revived", self.zb_rev );
    }
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

// console "add" (original bot_console_add): one more bot if the 4-player squad has room
add_bot()
{
    level.zb_have = level.players.size;
    if ( level.zb_have >= 4 || !isdefined( level.zb_latent ) )
    {
        msg( "^5Bots^7: squad full" );
        return;
    }
    level.zb_added = addbot( "zmbot" );
    if ( isdefined( level.zb_added ) )
        level.zb_added thread [[ level.zb_latent ]]();
    wait_new_bot();
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
        if ( !istrue( level.zb_quiet ) && isdefined( level.zb_status ) && level.zb_status != "" )
        {
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
