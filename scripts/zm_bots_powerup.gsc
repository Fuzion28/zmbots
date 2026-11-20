#namespace zm_bots_powerup;

// Power-up pickup, port of zm_bo2_bots.gsc bot_pickup_powerup: closest power-up within 1000, goal radius 25,
// double points / insta-kill only while zombies are alive, nuke only when none is alive, first bot calls it out.
// Active power-ups: level.var_27becec7ea16c97c.var_d06f4fd319d1ef1c, script_models with the name in .var_a943ba132e3d2d5e
// (srvbase script_427ce33ec0c820cf.gsc:836 powerup_drop, :1899; names compared as strings :1171/:1248). The game's
// pickup is a trigger_radius on the power-up (powerup_wait_for_pickup), so walking onto it grabs it.
// shortcut: "zombies left" = zombies alive now (the original also counts zombies still to spawn), add the round's
// remaining-count field if bots grab nukes between spawn waves.
// Unverified in game: everything in this file.

autoexec init()
{
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    for ( ;; )
    {
        wait 1;
        if ( ( level.zb_cfg_powerups ?? 1 ) == 0 || !isalive( self ) || istrue( self.var_d0697a2251283e17 ) || isdefined( self.zb_busy ) || ( self.zb_mode ?? "" ) == "stay" || any_downed() )
            continue;
        if ( pick() )
            go();
    }
}

any_downed()
{
    foreach ( p in level.players )
        if ( isdefined( p ) && istrue( p.var_d0697a2251283e17 ) )
            return 1;
    return 0;
}

pick()
{
    self.zb_pu = undefined;
    if ( !isdefined( level.var_27becec7ea16c97c ) || !isdefined( level.var_27becec7ea16c97c.var_d06f4fd319d1ef1c ) )
        return 0;
    self.zb_pu_zs = function_926af5fe60499e85( "team_two_hundred" ); // getaiarray, as zm_bots_move.gsc scan
    self.zb_pu_left = isdefined( self.zb_pu_zs ) && self.zb_pu_zs.size > 0;
    foreach ( p in level.var_27becec7ea16c97c.var_d06f4fd319d1ef1c )
    {
        if ( !isdefined( p ) || !isdefined( p.var_a943ba132e3d2d5e ) || distance( self.origin, p.origin ) > 1000 || gettime() < ( p.zb_pu_fail ?? 0 ) )
            continue;
        if ( ( p.var_a943ba132e3d2d5e == "double_points" || p.var_a943ba132e3d2d5e == "insta_kill" ) && !self.zb_pu_left )
            continue;
        if ( p.var_a943ba132e3d2d5e == "nuke" && self.zb_pu_left )
            continue;
        if ( !isdefined( self.zb_pu ) || distance( self.origin, p.origin ) < distance( self.origin, self.zb_pu.origin ) )
            self.zb_pu = p;
    }
    return isdefined( self.zb_pu );
}

// walk onto it; the entity is deleted once grabbed. 10 s without reaching it: skip that power-up for 15 s.
go()
{
    self.zb_busy = "powerup";
    level.zb_status = "powerup " + self.zb_pu.var_a943ba132e3d2d5e + " " + self.name;
    if ( !istrue( self.zb_pu.zb_called ) && isdefined( level.zb_chat ) && isdefined( display( self.zb_pu.var_a943ba132e3d2d5e ) ) )
    {
        self.zb_pu.zb_called = 1;
        self [[ level.zb_chat ]]( "powerup", display( self.zb_pu.var_a943ba132e3d2d5e ) );
    }
    self.zb_pu_until = gettime() + 10000;
    self.zb_pu_reset = 0;
    while ( isdefined( self.zb_pu ) && active( self.zb_pu ) && gettime() < self.zb_pu_until && isalive( self ) && !istrue( self.var_d0697a2251283e17 ) && !any_downed() )
    {
        if ( gettime() >= self.zb_pu_reset )
        {
            self function_75794c5ddff5c061( self.zb_pu.origin, 25, "critical" ); // botsetscriptgoal
            self.zb_pu_reset = gettime() + 2000;
        }
        wait 0.25;
    }
    if ( isdefined( self.zb_pu ) && active( self.zb_pu ) )
        self.zb_pu.zb_pu_fail = gettime() + 15000;
    else
        level.zb_status = "powerup grabbed by " + self.name;
    self function_cb0d368fa87a2b78(); // botclearscriptgoal
    self.zb_busy = undefined;
}

// grabbed power-ups leave the active list (script_427ce33ec0c820cf.gsc:1107) before the entity may be deleted
active( pu )
{
    if ( !isdefined( level.var_27becec7ea16c97c ) || !isdefined( level.var_27becec7ea16c97c.var_d06f4fd319d1ef1c ) )
        return 0;
    foreach ( p in level.var_27becec7ea16c97c.var_d06f4fd319d1ef1c )
        if ( p === pu )
            return 1;
    return 0;
}

// original bot_powerup_display_name; undefined = no callout
display( n )
{
    if ( n == "full_ammo" )
        return "Max Ammo";
    if ( n == "insta_kill" )
        return "Insta-Kill";
    if ( n == "double_points" )
        return "Double Points";
    if ( n == "nuke" )
        return "Nuke";
    if ( n == "carpenter" )
        return "Carpenter";
    if ( n == "fire_sale" )
        return "Fire Sale";
    if ( n == "free_perk" )
        return "free perk";
    if ( n == "minigun" )
        return "Death Machine";
    if ( n == "zombie_blood" )
        return "Zombie Blood";
    if ( n == "bonus_points_player" || n == "bonus_points_team" )
        return "bonus points";
    return undefined;
}
