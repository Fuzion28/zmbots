#using scripts\common\utility;

#namespace zm_bots_move;

// Movement & survival module (port of zm_bo2_bots.gsc): retreat/keep distance, protect host, doors, wander, anti-stuck, zb_doors_opened.
// zb_kills / zb_downs are written by zm_bots_hud.gsc (same sources), so not here to avoid double counting.
// Priority per tick: retreat/kite > protect low-health host > doors (idle only) > wander > anti-stuck.
// Never moves while someone is downed (core revives). No number locals: all state in self.zb_mv_* fields.
// Builtins with evidence (dumps: srvbase = SB, zm = ZM):
// - zombie list function_926af5fe60499e85( "team_two_hundred" )  ZM script_18317bad0c071e03.gsc:1811 (getaiarray)
// - closest navmesh point function_df9f501a2a0cbf4( pos ), may be undefined  SB script_23db6f5c71b1807a.gsc:500
// - randomint function_de284a0228a3400e( n )  SB script_23db6f5c71b1807a.gsc:498 / script_120270bd0a747a35.gsc:5101
// - randomfloatrange function_e6b922a34162edc2( a, b )  SB script_23db6f5c71b1807a.gsc:497
// - anglestoforward function_44e25da2d51a2988( angles )  SB script_23db6f5c71b1807a.gsc:498
// - length( v )  SB script_14f857806c1ea0cc.gsc:391
// - health / maxHealth  SB script_110f3a07c5099e1c.gsc:1670
// - jump: Bot function_aba9ac6f872dc502( "jump" )  ZM script_18d7039086efdb01.gsc:2064

autoexec init()
{
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    self.zb_mv_anchor = self.origin;
    self.zb_mv_anct = gettime();
    self.zb_mv_stage = 0;
    for ( ;; )
    {
        wait 0.25;
        if ( !isalive( self ) || istrue( self.var_d0697a2251283e17 ) )
            continue;
        self.zb_mv_host = [[ level.zb_host ]]();
        if ( isdefined( self.zb_mv_host ) && escape() )
        {
            stuck_reset();
            continue;
        }
        if ( !isdefined( self.zb_mv_host ) || any_downed() )
        {
            stuck_reset();
            continue;
        }
        if ( retreat() || protect() || doors() )
        {
            stuck_reset();
            continue;
        }
        wander();
        unstuck();
    }
}

any_downed()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && istrue( p.var_d0697a2251283e17 ) )
            return 1;
    return 0;
}

// counts zombies around the bot and builds the original's flee vector: sum of (bot - zombie) / d weighted (900 - d) / 900
scan()
{
    self.zb_mv_away = ( 0, 0, 0 );
    self.zb_mv_n300 = 0;
    self.zb_mv_n350 = 0;
    self.zb_mv_n430 = 0;
    self.zb_mv_n600 = 0;
    self.zb_mv_n900 = 0;
    self.zb_mv_zs = function_926af5fe60499e85( "team_two_hundred" ); // getaiarray, ZM script_18317bad0c071e03.gsc:1811
    if ( !isdefined( self.zb_mv_zs ) )
        return;
    foreach ( z in self.zb_mv_zs )
    {
        if ( !isdefined( z ) || !isalive( z ) )
            continue;
        self.zb_mv_d = distance( self.origin, z.origin );
        if ( self.zb_mv_d < 900 && self.zb_mv_d > 1 )
            self.zb_mv_away = self.zb_mv_away + ( self.origin - z.origin ) * ( ( 900 - self.zb_mv_d ) / ( 900 * self.zb_mv_d ) );
        if ( self.zb_mv_d < 300 )
            self.zb_mv_n300 = self.zb_mv_n300 + 1;
        if ( self.zb_mv_d < 350 )
            self.zb_mv_n350 = self.zb_mv_n350 + 1;
        if ( self.zb_mv_d < 430 )
            self.zb_mv_n430 = self.zb_mv_n430 + 1;
        if ( self.zb_mv_d < 600 )
            self.zb_mv_n600 = self.zb_mv_n600 + 1;
        if ( self.zb_mv_d < 900 )
            self.zb_mv_n900 = self.zb_mv_n900 + 1;
    }
}

// runs even while someone is downed: "last" = original build 44 last-alive mode (the last one up kites while a zombie
// is within 900, the core skips the revive meanwhile); "swarm" = the core gave up a revive because the bot was surrounded
escape()
{
    if ( isdefined( self.zb_busy ) )
        return 0;
    if ( gettime() < ( self.zb_rev_wait ?? 0 ) )
        self.zb_mv_kind = "swarm";
    else if ( ( level.zb_cfg_last_alive ?? 1 ) == 1 && isdefined( level.zb_last ) && self [[ level.zb_last ]]() )
        self.zb_mv_kind = "last";
    else
        return 0;
    scan();
    if ( self.zb_mv_kind == "last" && self.zb_mv_n900 == 0 )
        return 0;
    self.zb_busy = "escape";
    level.zb_status = "move escape " + self.zb_mv_kind + " " + self.name;
    if ( isdefined( level.zb_chat ) )
        self [[ level.zb_chat ]]( self.zb_mv_kind == "last" ? "retreat_last" : "retreat_swarm", undefined );
    self.zb_mv_until = gettime() + ( self.zb_mv_kind == "last" ? 30000 : 4000 );
    self.zb_mv_pick = 0;
    while ( gettime() < self.zb_mv_until && isalive( self ) && !istrue( self.var_d0697a2251283e17 ) && self.zb_busy === "escape" )
    {
        if ( gettime() >= self.zb_mv_pick || ( isdefined( self.zb_mv_goal ) && distance( self.origin, self.zb_mv_goal ) < 48 ) )
            if ( flee_pick() )
                self.zb_mv_pick = gettime() + 1000;
        wait 0.15;
        scan();
        if ( self.zb_mv_kind == "last" && ( self.zb_mv_n900 == 0 || !( self [[ level.zb_last ]]() ) ) )
            break;
    }
    // zb_cmd unstick can free the bot and another module take it: clear only what is still ours
    if ( self.zb_busy === "escape" )
    {
        self function_cb0d368fa87a2b78(); // botclearscriptgoal
        self.zb_busy = undefined;
    }
    self.zb_mv_goal = undefined;
    self.zb_mv_wgoal = undefined;
    return 1;
}

hp()
{
    if ( ( self.maxhealth ?? 0 ) <= 0 )
        return 1;
    return self.health / self.maxhealth; // SB script_110f3a07c5099e1c.gsc:1670
}

// bot_retreat_think / bot_do_retreat ("health") and bot_keep_distance_think ("kite": short steps away = training zombies)
retreat()
{
    if ( isdefined( self.zb_busy ) )
        return 0;
    scan();
    if ( self.zb_mv_n350 == 0 )
        return 0;
    if ( ( level.zb_cfg_retreat ?? 1 ) == 1 && hp() <= ( level.zb_cfg_retreat_health ?? 75 ) / 100.0 )
        self.zb_mv_kind = "health";
    else if ( ( level.zb_cfg_keep_distance ?? 1 ) == 1 && self.zb_mode != "stay" && gettime() >= ( self.zb_mv_kitecd ?? 0 ) )
        self.zb_mv_kind = "kite";
    else
        return 0;
    self.zb_busy = self.zb_mv_kind == "health" ? "retreat" : "kite";
    self.zb_mv_own = self.zb_busy;
    if ( self.zb_mv_kind == "health" )
    {
        level.zb_status = "move retreat " + self.name;
        if ( isdefined( level.zb_chat ) )
            self [[ level.zb_chat ]]( "retreat_low", undefined );
    }
    self.zb_mv_until = gettime() + ( self.zb_mv_kind == "health" ? 20000 : 2500 );
    self.zb_mv_pick = 0;
    while ( gettime() < self.zb_mv_until && isalive( self ) && !istrue( self.var_d0697a2251283e17 ) && !any_downed() && self.zb_busy === self.zb_mv_own )
    {
        // re-pick on a timer or at the spot (the original also re-picks when a zombie is ahead; no verified dot product here)
        if ( gettime() >= self.zb_mv_pick || ( isdefined( self.zb_mv_goal ) && distance( self.origin, self.zb_mv_goal ) < 48 ) )
            if ( flee_pick() )
                self.zb_mv_pick = gettime() + ( self.zb_mv_kind == "health" ? 1500 : 800 );
        wait 0.15;
        scan();
        if ( self.zb_mv_kind == "health" && ( self.zb_mv_n600 == 0 || ( hp() >= 0.9 && self.zb_mv_n300 == 0 ) ) )
            break;
        if ( self.zb_mv_kind == "kite" && self.zb_mv_n430 == 0 )
            break;
    }
    if ( self.zb_busy === self.zb_mv_own )
    {
        self function_cb0d368fa87a2b78(); // botclearscriptgoal
        self.zb_busy = undefined;
    }
    self.zb_mv_goal = undefined;
    self.zb_mv_wgoal = undefined;
    self.zb_mv_kitecd = gettime() + 600;
    return 1;
}

// bot_pick_flee_node: point along the flee vector, snapped to the navmesh; 1 if a goal was set
flee_pick()
{
    self.zb_mv_away = ( self.zb_mv_away[ 0 ], self.zb_mv_away[ 1 ], 0 );
    if ( length( self.zb_mv_away ) < 0.001 ) // SB script_14f857806c1ea0cc.gsc:391
        return 0;
    self.zb_mv_goal = function_df9f501a2a0cbf4( self.origin + self.zb_mv_away / length( self.zb_mv_away ) * ( self.zb_mv_kind == "kite" ? 250 : 450 ) ); // SB script_23db6f5c71b1807a.gsc:500
    if ( !isdefined( self.zb_mv_goal ) )
        return 0;
    self function_75794c5ddff5c061( self.zb_mv_goal, 48, "critical" ); // botsetscriptgoal
    return 1;
}

// protect players: hug a low-health host (downed host is the core revive's job)
protect()
{
    if ( isdefined( self.zb_busy ) || self.zb_mode == "stay" || !isalive( self.zb_mv_host ) || self.zb_mv_host hp() >= 0.5 )
        return 0;
    self.zb_busy = "protect";
    level.zb_status = "move protect host " + self.name;
    self.zb_mv_until = gettime() + 10000;
    while ( gettime() < self.zb_mv_until && isalive( self ) && isalive( self.zb_mv_host ) && !any_downed() && self.zb_mv_host hp() < 0.6 && self.zb_busy === "protect" )
    {
        if ( distance( self.origin, self.zb_mv_host.origin ) > 150 )
            self function_75794c5ddff5c061( self.zb_mv_host.origin, 100, "critical" );
        wait 0.5;
    }
    if ( self.zb_busy === "protect" )
    {
        self function_cb0d368fa87a2b78();
        self.zb_busy = undefined;
    }
    self.zb_mv_wgoal = undefined;
    return 1;
}

// bot_buy_door / bot_clear_debris: remote buy of the closest door within 300 (engineer 500), one bot per door for 4 s
// BO7 doors and debris are both doorbuy triggers in level.var_7cfb92ddbd4165 (SB script_681a06cc8e9fcb34.gsc:414)
doors()
{
    if ( isdefined( self.zb_busy ) || !isdefined( level.zb_door_buy ) || !isdefined( level.var_7cfb92ddbd4165 ) || gettime() < ( self.zb_mv_doorcd ?? 0 ) )
        return 0;
    self.zb_mv_doorcd = gettime() + 1000;
    self.zb_mv_range = ( ( self.zb_pers ?? "allrounder" ) == "engineer" ? 500 : 300 );
    self.zb_door = undefined;
    foreach ( t in level.var_7cfb92ddbd4165 )
    {
        // interact .var_82e5b92a84918d29 = bought (:1115), .var_df00f5fbf4a6d195 = disabled (:973); cost .var_e2ea5c9302351a97
        if ( !isdefined( t ) || !isdefined( t.var_4cf63ec91b753a3c ) || istrue( t.var_4cf63ec91b753a3c.var_82e5b92a84918d29 ) || istrue( t.var_4cf63ec91b753a3c.var_df00f5fbf4a6d195 ) )
            continue;
        if ( ( t.script_noteworthy ?? "" ) == "barrier_unpurchaseable_trigger" || ( t.var_e2ea5c9302351a97 ?? 0 ) <= 0 )
            continue;
        // original bot_can_spend_on_map: on starter guns, keep 1500 after the door (shortcut: starter = no gun bought yet, no BO7 weapon tier)
        if ( ( self.zb_weapons_bought ?? 0 ) == 0 && isdefined( self.var_8b69ecbd466a79fa ) && ( self.var_8b69ecbd466a79fa[ "score" ] ?? 0 ) - t.var_e2ea5c9302351a97 < 1500 )
            continue;
        if ( gettime() < ( t.zb_fail ?? 0 ) || ( gettime() < ( t.zb_claim ?? 0 ) && t.zb_claimer != self ) )
            continue;
        if ( distance( self.origin, t.origin ) > self.zb_mv_range )
            continue;
        if ( !isdefined( self.zb_door ) || distance( self.origin, t.origin ) < distance( self.origin, self.zb_door.origin ) )
            self.zb_door = t;
    }
    if ( !isdefined( self.zb_door ) )
        return 0;
    self.zb_door.zb_claim = gettime() + 4000;
    self.zb_door.zb_claimer = self;
    self.zb_mv_pts0 = isdefined( self.var_8b69ecbd466a79fa ) ? ( self.var_8b69ecbd466a79fa[ "score" ] ?? 0 ) : 0;
    self thread [[ level.zb_door_buy ]](); // zm_bots_move_api.gsc
    wait 3; // bought flag may only be set after the door anim; 1.5 s counted some buys as failures
    // in game the doors opened but the counter stayed 0: the bought flag is not set (or not there), so points spent count too
    if ( isdefined( self.zb_door ) && ( istrue( self.zb_door.var_4cf63ec91b753a3c.var_82e5b92a84918d29 ) || ( isdefined( self.var_8b69ecbd466a79fa ) && ( self.var_8b69ecbd466a79fa[ "score" ] ?? 0 ) < self.zb_mv_pts0 ) ) )
    {
        self.zb_doors_opened = ( self.zb_doors_opened ?? 0 ) + 1;
        level.zb_status = "move door opened by " + self.name;
    }
    else if ( isdefined( self.zb_door ) )
        self.zb_door.zb_fail = gettime() + 30000; // not affordable, power off or buy failed: retry later
    return 1;
}

// bot_update_wander / get_wander_location: random navmesh spot 120-600 around the host, radius 100, not within 150 of another bot's spot
wander()
{
    // another module owns movement (buy, power-up): drop the spot, its goal was cleared or replaced
    if ( isdefined( self.zb_busy ) || ( self.zb_mode != "wander" && self.zb_mode != "wander_further" ) )
    {
        self.zb_mv_wgoal = undefined;
        self.zb_mv_wandering = undefined;
        return;
    }
    if ( isdefined( self.zb_mv_wgoal ) && distance( self.origin, self.zb_mv_wgoal ) > 100 && gettime() < self.zb_mv_wuntil )
        return;
    if ( !istrue( self.zb_mv_wandering ) )
        level.zb_status = "move wander " + self.name;
    self.zb_mv_wandering = 1;
    self.zb_mv_wgoal = function_df9f501a2a0cbf4( self.zb_mv_host.origin + function_44e25da2d51a2988( ( 0, function_de284a0228a3400e( 360 ), 0 ) ) * function_e6b922a34162edc2( 120, 600 ) ); // SB script_23db6f5c71b1807a.gsc:497-500
    // original wander_further_get_wander_location: a spot up to 3000 from the bot itself, at least 20% of that away.
    // shortcut: no visited-spot memory (the original skips recently seen spots); add it if bots keep looping back.
    if ( self.zb_mode == "wander_further" )
        self.zb_mv_wgoal = function_df9f501a2a0cbf4( self.origin + function_44e25da2d51a2988( ( 0, function_de284a0228a3400e( 360 ), 0 ) ) * function_e6b922a34162edc2( 600, 3000 ) );
    if ( !isdefined( self.zb_mv_wgoal ) )
        return;
    foreach ( p in level.players )
        if ( isdefined( p ) && p != self && isdefined( p.zb_mv_wgoal ) && distance( p.zb_mv_wgoal, self.zb_mv_wgoal ) < 150 )
            self.zb_mv_wgoal = undefined;
    if ( !isdefined( self.zb_mv_wgoal ) )
        return;
    self.zb_mv_wuntil = gettime() + ( self.zb_mode == "wander_further" ? 30000 : 12000 );
    self function_75794c5ddff5c061( self.zb_mv_wgoal, 100, "critical" );
}

stuck_reset()
{
    self.zb_mv_anchor = self.origin;
    self.zb_mv_anct = gettime();
    self.zb_mv_stage = 0;
    self.zb_mv_fart = undefined;
}

// bot_watchdog_think / bot_unstick: no 120-unit progress while not legitimately idle -> 4 s jump, 6 s strafe, 10 s new goal
// Teleport to host is NOT in the original ("never teleports"): off unless zb_auto_teleport 1, then only when free and > 1500 from host for 20 s.
unstuck()
{
    if ( isdefined( self.zb_busy ) || self.zb_mode == "stay" )
    {
        stuck_reset();
        return;
    }
    if ( distance( self.origin, self.zb_mv_anchor ) > 120 || ( self.zb_mode == "follow" && distance( self.origin, self.zb_mv_host.origin ) < 400 ) ) // above the core follow range (350) so a parked bot is not "stuck"
    {
        self.zb_mv_anchor = self.origin;
        self.zb_mv_anct = gettime();
        self.zb_mv_stage = 0;
    }
    if ( self.zb_mv_stage == 0 && gettime() - self.zb_mv_anct > 4000 )
    {
        self.zb_mv_stage = 1;
        level.zb_status = "move unstuck jump " + self.name;
        self function_aba9ac6f872dc502( "jump", 0.2 ); // ZM script_18d7039086efdb01.gsc:2064
    }
    else if ( self.zb_mv_stage == 1 && gettime() - self.zb_mv_anct > 6000 )
    {
        self.zb_mv_stage = 2;
        self.zb_mv_goal = function_df9f501a2a0cbf4( self.origin + function_44e25da2d51a2988( ( 0, function_de284a0228a3400e( 360 ), 0 ) ) * function_e6b922a34162edc2( 150, 200 ) );
        if ( isdefined( self.zb_mv_goal ) )
        {
            level.zb_status = "move unstuck strafe " + self.name;
            self.zb_busy = "unstuck";
            self function_75794c5ddff5c061( self.zb_mv_goal, 32, "critical" );
            wait 2;
            if ( self.zb_busy === "unstuck" )
            {
                self function_cb0d368fa87a2b78();
                self.zb_busy = undefined;
            }
        }
    }
    else if ( self.zb_mv_stage == 2 && gettime() - self.zb_mv_anct > 10000 )
    {
        self.zb_mv_stage = 0;
        self.zb_mv_anct = gettime();
        level.zb_status = "move unstuck new goal " + self.name;
        self function_cb0d368fa87a2b78();
        self.zb_mv_wgoal = undefined; // wander picks a new spot; follow: core re-sets the host goal next tick
    }
    if ( !istrue( level.zb_cfg_auto_teleport ) || self.zb_mode == "wander_further" || distance( self.origin, self.zb_mv_host.origin ) < 1500 || !isalive( self.zb_mv_host ) )
    {
        self.zb_mv_fart = undefined;
        return;
    }
    if ( !isdefined( self.zb_mv_fart ) )
        self.zb_mv_fart = gettime();
    if ( gettime() - self.zb_mv_fart < 20000 )
        return;
    level.zb_status = "move teleport to host " + self.name;
    self function_a544338816001600( self.zb_mv_host.origin + ( 40, 0, 0 ) ); // setorigin, as core bot_start
    stuck_reset();
}
