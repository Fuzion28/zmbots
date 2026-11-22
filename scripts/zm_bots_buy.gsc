#namespace zm_bots_buy;

// Buying for the BO7 port of "BO2 Zombies Plutonium Bots": perks, wall buys + wall ammo, Pack-a-Punch, Mystery Box.
// Original: perk buying (3.11), wall buys (3.8), Pack-a-Punch (3.10), mystery box + should_take (3.9), personalities (3.25).
// How a buy works: walk to the interact, look at it, press use (what a human does). If nothing changed, run the
// interact's own registered use callback with the bot as player (level.zb_fire in zm_bots_find.gsc): the same
// game code a use event runs, so the game itself pays and gives. No namespace function is called from this file.
// Instance lists are the game's own level arrays (all srvbase):
//   perks  level.var_2ad433898c7f6057   script_4b576523c81e6ee3.gsc:42/260, interact .var_b69810c6c14b1634.var_4cf63ec91b753a3c (:334/:345)
//   walls  level.var_caf65b937e9cbfaf   script_7df061afe12b8318.gsc:412, interact .var_f9b6c5834058f21c (:469/:480)
//   box    level.var_1bbb5557537e2c0c   script_4ccf8f7e270f2426.gsc:1465, interact .var_97c6497c84d770a.var_4cf63ec91b753a3c (:1522)
//   PaP    level.var_db52bcfd04d45a7a   script_4f24ca7a470a5fa8.gsc:37/103, interact .var_370acb837a3a86c3.var_4cf63ec91b753a3c (:538/:562)
// No int locals (they read back undefined in game): all state is in self.zb_* fields.
// Whole file: unverified in game.

autoexec init()
{
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

think()
{
    self endon( #"disconnect" );
    self.zb_pfail = [];
    // 3.11 order, BO7 names (has-perk string args: script_30ff79340e09d7d0.gsc:63, script_25a8fa2ac8997425.gsc:576,
    // script_2167bb17f6da435d.gsc:99, script_2d65125a9787d413.gsc:101, script_1ed5c8921b4c1572.gsc:128).
    // BO7 names: Double Tap = specialty_d_mod (icon ui_icon_perks_double_tap, script_2bdf8eafdb703418.gsc:987),
    // Mule Kick = specialty_z_mod (3rd weapon slot check, script_1667bc66bcc6e6e2.gsc:3356; inferred).
    // Electric Cherry, movefaster: no BO7 counterpart found.
    self.zb_order = [ "specialty_juggernog" ];
    if ( ( self.zb_pers ?? "allrounder" ) == "medic" )
        self.zb_order[ self.zb_order.size ] = "specialty_quickrevive";
    self.zb_order[ self.zb_order.size ] = "specialty_speedcola";
    if ( ( self.zb_pers ?? "allrounder" ) != "medic" )
        self.zb_order[ self.zb_order.size ] = "specialty_quickrevive";
    self.zb_order[ self.zb_order.size ] = "specialty_d_mod";
    self.zb_order[ self.zb_order.size ] = "specialty_phd_flopper";
    self.zb_order[ self.zb_order.size ] = "specialty_deadshot";
    self.zb_order[ self.zb_order.size ] = "specialty_staminup";
    self.zb_order[ self.zb_order.size ] = "specialty_z_mod";
    self.zb_order[ self.zb_order.size ] = "specialty_elemental_pop";
    self.zb_order[ self.zb_order.size ] = "specialty_vulture_aid";
    self.zb_order[ self.zb_order.size ] = "specialty_death_perception";
    wait 8;
    for ( ;; )
    {
        wait 2; // kite and power-ups hold zb_busy often; a 5 s poll rarely found the bot free
        if ( !idle() )
        {
            // shown by "zb_cmd diag": why this bot is not shopping right now
            self.zb_buy_why = ( self.zb_mode ?? "follow" ) == "stay" ? "mode stay" : ( isdefined( self.zb_busy ) ? "busy " + self.zb_busy : "someone down" );
            continue;
        }
        read_pts();
        // original round gates bot_perk_round / bot_pap_round; round number field from ZM round script (srvbase script_77dca3b46e01eb1e.gsc:289)
        self.zb_round = isdefined( level.var_6781718da4f78d1c ) ? ( level.var_6781718da4f78d1c.var_392f37fdba9f6777 ?? 1 ) : 1;
        self.zb_buy_why = "nothing in range";
        if ( ( self.zb_round >= ( level.zb_cfg_perk_round ?? 8 ) && pick_perk() ) || pick_wall() || ( self.zb_round >= ( level.zb_cfg_pap_round ?? 10 ) && pick_pap() ) || pick_box() )
            do_buy();
    }
}

// idle = alive, not downed, nobody downed, no module owns movement, not told to stay
idle()
{
    self.zb_h = [[ level.zb_host ]]();
    if ( !isdefined( self.zb_h ) || !isalive( self ) || isdefined( self.zb_busy ) || ( self.zb_mode ?? "follow" ) == "stay" )
        return 0;
    return !someone_down();
}

someone_down()
{
    foreach ( p in level.players )
        if ( [[ level.zb_downed ]]( p ) )
            return 1;
    return 0;
}

// points = player.var_8b69ecbd466a79fa[ "score" ]: what the points getter returns (points function_8f0a9502ff7321a,
// srvbase script_2301d27669c5a079.gsc:416 -> script_267a69c97e3c6c7c.gsc:562). FuzMenu gives points through that setter.
// The old read (var_189fe7075a0930a5, a debug HUD field) was always empty, so bots never bought anything.
read_pts()
{
    self.zb_pts = 0;
    if ( isdefined( self.var_8b69ecbd466a79fa ) && isdefined( self.var_8b69ecbd466a79fa[ "score" ] ) )
        self.zb_pts = self.var_8b69ecbd466a79fa[ "score" ];
}

// owned perks: player.var_298fe7dcdb17fe4f[ specialty ] (script_25a8fa2ac8997425.gsc:275 set, :471-475 has-perk read)
has_perk( spec )
{
    return isdefined( spec ) && isdefined( self.var_298fe7dcdb17fe4f ) && isdefined( self.var_298fe7dcdb17fe4f[ spec ] );
}

// specialty of a perk machine: level.var_35cae1d5b8f6f7c2[ interact.var_c39ab5c52b7dfb33 ].var_b9ec0088c51d2977
// (on_use script_4b576523c81e6ee3.gsc:640/:670; perk name set on the interact at :795)
perk_spec( s )
{
    if ( !isdefined( s ) || !isdefined( s.var_b69810c6c14b1634 ) || !isdefined( s.var_b69810c6c14b1634.var_4cf63ec91b753a3c ) || !isdefined( level.var_35cae1d5b8f6f7c2 ) )
        return undefined;
    self.zb_pn = s.var_b69810c6c14b1634.var_4cf63ec91b753a3c.var_c39ab5c52b7dfb33 ?? s.script_noteworthy;
    if ( !isdefined( self.zb_pn ) || !isdefined( level.var_35cae1d5b8f6f7c2[ self.zb_pn ] ) )
        return undefined;
    return level.var_35cae1d5b8f6f7c2[ self.zb_pn ].var_b9ec0088c51d2977;
}

// machine cost .var_e2ea5c9302351a97 (script_4b576523c81e6ee3.gsc:327-329); the real price can rise per perk owned (:861), the verify catches that
perk_ok( s, spec )
{
    return !has_perk( spec ) && gettime() >= ( self.zb_pfail[ spec ] ?? 0 ) && distance( s.origin, self.origin ) < 1000 && self.zb_pts >= ( s.var_e2ea5c9302351a97 ?? 2000 );
}

pick_perk()
{
    if ( !isdefined( level.var_2ad433898c7f6057 ) )
        return 0;
    self.zb_cand = undefined;
    foreach ( spec in self.zb_order )
        foreach ( s in level.var_2ad433898c7f6057 )
            if ( !isdefined( self.zb_cand ) && perk_spec( s ) === spec && perk_ok( s, spec ) )
                self.zb_cand = s;
    // then any other machine (perks not in the list)
    foreach ( s in level.var_2ad433898c7f6057 )
        if ( !isdefined( self.zb_cand ) && isdefined( perk_spec( s ) ) && perk_ok( s, perk_spec( s ) ) )
            self.zb_cand = s;
    if ( !isdefined( self.zb_cand ) )
        return 0;
    self.zb_kind = "perk";
    self.zb_spec = perk_spec( self.zb_cand );
    self.zb_name = self.zb_spec;
    self.zb_ia = self.zb_cand.var_b69810c6c14b1634.var_4cf63ec91b753a3c;
    self.zb_tgt = self.zb_ia.origin ?? self.zb_cand.origin;
    return 1;
}

// wall interact fields .cost/.weapon/.var_2752c96850e281e8 (script_7df061afe12b8318.gsc:472-474);
// "already owned" = a weapon in player.var_812aadce27201d64 whose .var_1b57e3034f84a054 is the wall base (:1167, :1176)
owns_base( base )
{
    if ( !isdefined( self.var_812aadce27201d64 ) )
        return 0;
    foreach ( w in self.var_812aadce27201d64 )
        if ( isdefined( w ) && w.var_1b57e3034f84a054 === base )
            return 1;
    return 0;
}

// 3.8 without the BO2 weapon score table: buy the priciest affordable wall gun that costs more than the last one bought.
// Wall ammo: buying the wall of the gun in hand buys ammo instead (:1167-1170 -> function_21da8105947ab024 :1375).
pick_wall()
{
    if ( !isdefined( level.var_caf65b937e9cbfaf ) || gettime() < ( self.zb_wall_next ?? 0 ) )
        return 0;
    self.zb_cand = undefined;
    self.zb_cur = self function_e3b3cc459cc1f25b(); // current weapon: script_7df061afe12b8318.gsc:1165
    foreach ( w in level.var_caf65b937e9cbfaf )
    {
        if ( !isdefined( w ) || !isdefined( w.var_f9b6c5834058f21c ) || !isdefined( w.var_f9b6c5834058f21c.cost ) || !isdefined( w.var_f9b6c5834058f21c.var_2752c96850e281e8 ) )
            continue;
        if ( distance( w.origin, self.origin ) > 1000 || self.zb_pts < w.var_f9b6c5834058f21c.cost )
            continue;
        if ( owns_base( w.var_f9b6c5834058f21c.var_2752c96850e281e8 ) )
            continue;
        if ( w.var_f9b6c5834058f21c.cost <= ( self.zb_wall_cost ?? 0 ) )
            continue;
        if ( !isdefined( self.zb_cand ) || w.var_f9b6c5834058f21c.cost > self.zb_cand.var_f9b6c5834058f21c.cost )
            self.zb_cand = w;
    }
    if ( isdefined( self.zb_cand ) )
    {
        self.zb_kind = "wall";
        self.zb_name = self.zb_cand.var_f9b6c5834058f21c.var_2752c96850e281e8;
    }
    else if ( gettime() >= ( self.zb_ammo_next ?? 0 ) && isdefined( self.zb_cur ) )
    {
        // ammo: keep 2x the price so ammo does not eat perk money. No ammo-full check: the game's check is private
        // (function_d8176f86ff361ba, Kronos refuses to link it); the wall buy refuses a full gun and the 120 s cooldown applies.
        foreach ( w in level.var_caf65b937e9cbfaf )
            if ( !isdefined( self.zb_cand ) && isdefined( w ) && isdefined( w.var_f9b6c5834058f21c ) && isdefined( w.var_f9b6c5834058f21c.cost ) && self.zb_cur.var_1b57e3034f84a054 === w.var_f9b6c5834058f21c.var_2752c96850e281e8 && distance( w.origin, self.origin ) < 1000 && self.zb_pts >= w.var_f9b6c5834058f21c.cost * 2 )
                self.zb_cand = w;
        if ( !isdefined( self.zb_cand ) )
            return 0;
        self.zb_kind = "ammo";
        self.zb_name = self.zb_cand.var_f9b6c5834058f21c.var_2752c96850e281e8;
        self.zb_ammo_next = gettime() + 120000;
    }
    else
        return 0;
    self.zb_ia = self.zb_cand.var_f9b6c5834058f21c;
    self.zb_cost = self.zb_ia.cost;
    self.zb_tgt = self.zb_ia.origin ?? self.zb_cand.origin;
    return 1;
}

// 3.10: score >= 5000, machine within 1000. Callback function_8ff137553260336f (script_4f24ca7a470a5fa8.gsc:913)
pick_pap()
{
    if ( !isdefined( level.var_db52bcfd04d45a7a ) || gettime() < ( self.zb_pap_next ?? 0 ) || self.zb_pts < 5000 )
        return 0;
    self.zb_cand = undefined;
    foreach ( m in level.var_db52bcfd04d45a7a )
        if ( !isdefined( self.zb_cand ) && isdefined( m ) && isdefined( m.var_370acb837a3a86c3 ) && isdefined( m.var_370acb837a3a86c3.var_4cf63ec91b753a3c ) && distance( m.var_370acb837a3a86c3.origin, self.origin ) < 1000 )
            self.zb_cand = m;
    if ( !isdefined( self.zb_cand ) )
        return 0;
    self.zb_kind = "pap";
    self.zb_name = "pack-a-punch";
    self.zb_ia = self.zb_cand.var_370acb837a3a86c3.var_4cf63ec91b753a3c;
    self.zb_tgt = self.zb_ia.origin ?? self.zb_cand.var_370acb837a3a86c3.origin;
    return 1;
}

// Ranges (1000, box 1000/1500) are measured from the bot, not the host: a wandering bot shopped only near the host and often gave up (tester report, unverified).
// 3.9: active box (.var_f14b2b4820b635e7, script_4ccf8f7e270f2426.gsc:2130), not open (interact .var_6365ea93403efebd :2201/:2239),
// cost .var_e2ea5c9302351a97 ?? 950 (:3592), one bot at a time, range 1000 (Gambler x1.5)
pick_box()
{
    // original: no box cooldown during a Fire Sale. Flag "powerup_fire_sale_active" read as flag-get does (script_4c67f790177c4d64.gsc:265)
    if ( !isdefined( level.var_1bbb5557537e2c0c ) || ( gettime() < ( self.zb_box_next ?? 0 ) && !fire_sale() ) )
        return 0;
    if ( isdefined( level.zb_box_bot ) && level.zb_box_bot != self )
        return 0;
    self.zb_range = 1000;
    if ( ( self.zb_pers ?? "allrounder" ) == "gambler" )
        self.zb_range = 1500;
    self.zb_cand = undefined;
    foreach ( b in level.var_1bbb5557537e2c0c )
        if ( !isdefined( self.zb_cand ) && isdefined( b ) && istrue( b.var_f14b2b4820b635e7 ) && isdefined( b.var_97c6497c84d770a ) && isdefined( b.var_97c6497c84d770a.var_4cf63ec91b753a3c ) && !istrue( b.var_97c6497c84d770a.var_4cf63ec91b753a3c.var_6365ea93403efebd ) && distance( b.var_97c6497c84d770a.origin, self.origin ) < self.zb_range && self.zb_pts >= ( b.var_e2ea5c9302351a97 ?? 950 ) )
            self.zb_cand = b;
    if ( !isdefined( self.zb_cand ) )
        return 0;
    self.zb_kind = "box";
    self.zb_name = "mystery box";
    self.zb_ia = self.zb_cand.var_97c6497c84d770a.var_4cf63ec91b753a3c;
    self.zb_tgt = self.zb_ia.origin ?? self.zb_cand.var_97c6497c84d770a.origin;
    return 1;
}

// can the current buy go on
go_on()
{
    return isalive( self ) && !( [[ level.zb_downed ]]( self ) ) && !someone_down() && self.zb_busy === "buy";
}

do_buy()
{
    self.zb_busy = "buy";
    if ( self.zb_kind == "box" )
        level.zb_box_bot = self;
    self.zb_until = gettime() + 12000;
    self function_75794c5ddff5c061( self.zb_tgt, 32, "critical" ); // botsetscriptgoal (core zm_bots.gsc:138)
    while ( go_on() && gettime() < self.zb_until && distance( self.origin, self.zb_tgt ) > 110 )
        wait 0.25;
    self function_cb0d368fa87a2b78(); // botclearscriptgoal (core zm_bots.gsc:146)
    if ( !go_on() )
        return fail( "buy failed: " + self.zb_name + " interrupted" );
    if ( distance( self.origin, self.zb_tgt ) > 110 )
        return fail( "buy failed: " + self.zb_name + " not reached" );
    read_pts();
    self.zb_pts0 = self.zb_pts;
    self.zb_w0 = self function_e3b3cc459cc1f25b(); // current weapon (script_7df061afe12b8318.gsc:1165)
    self function_b217ccc053191d61( self.zb_tgt + ( 0, 0, 40 ), 4, "script_forced" ); // botlookatpoint (core zm_bots.gsc:176)
    wait 0.5;
    self function_aba9ac6f872dc502( "use", 0.5 ); // botpressbutton (core zm_bots.gsc:178)
    wait 3;
    if ( !bought() && go_on() && isdefined( level.zb_fire ) && isdefined( self.zb_ia ) && isdefined( self.zb_ia.var_d8e3b07237845727 ) && isdefined( self.zb_ia.var_d8e3b07237845727[ 0 ] ) )
    {
        self.zb_cb = self.zb_ia.var_d8e3b07237845727[ 0 ]; // the interact's use callback (script_27623f7ac600060c.gsc:148/377)
        self thread [[ level.zb_fire ]]();
        wait 3;
    }
    if ( !bought() )
        return fail( "buy failed: " + self.zb_name + " no effect" );
    self.zb_spent = ( self.zb_spent ?? 0 ) + ( self.zb_pts0 - self.zb_pts );
    if ( self.zb_kind == "perk" )
    {
        chat( "perk", self.zb_name );
        return finish( "buy perk " + self.zb_name + " ok" );
    }
    if ( self.zb_kind == "wall" )
    {
        self.zb_wall_cost = self.zb_cost;
        self.zb_weapons_bought = ( self.zb_weapons_bought ?? 0 ) + 1;
        return finish( "buy wall " + self.zb_name + " ok" );
    }
    if ( self.zb_kind == "ammo" )
        return finish( "buy ammo " + self.zb_name + " ok" );
    if ( self.zb_kind == "pap" )
    {
        self.zb_pap_next = gettime() + 120000;
        chat( "pap", undefined );
        return finish( "buy pack-a-punch ok" );
    }
    return box_take();
}

// after paying the box: wait for the carousel (game waits up to 5 s, script_4ccf8f7e270f2426.gsc:3567), then take the gun
// from the pickup interact .var_aaebed696583903c.var_4cf63ec91b753a3c (:3572/:3585), owner .var_37f3a4cd8252c9f0 (:2187).
// should_take is reduced to "always take": BO7 has no weapon score table.
box_take()
{
    box_cd();
    wait 5.5;
    if ( !isdefined( self.zb_cand.var_aaebed696583903c ) || !isdefined( self.zb_cand.var_aaebed696583903c.var_4cf63ec91b753a3c ) || !( self.zb_cand.var_37f3a4cd8252c9f0 === self ) )
        return fail( "buy failed: box paid, no gun to take" );
    self.zb_ia = self.zb_cand.var_aaebed696583903c.var_4cf63ec91b753a3c;
    self.zb_tgt = self.zb_ia.origin ?? self.zb_tgt;
    self.zb_w0 = self function_e3b3cc459cc1f25b();
    self.zb_try = 0;
    while ( self.zb_try < 3 && self function_e3b3cc459cc1f25b() === self.zb_w0 && go_on() )
    {
        self function_b217ccc053191d61( self.zb_tgt, 2, "script_forced" );
        wait 0.2;
        self function_aba9ac6f872dc502( "use", 0.3 );
        wait 0.5;
        self.zb_try++;
    }
    // fallback: the pickup callback function_f289ba80c654e2e1 reads self.var_aaebed696583903c on the interact (:3980)
    if ( self function_e3b3cc459cc1f25b() === self.zb_w0 && go_on() && isdefined( level.zb_fire ) && isdefined( self.zb_ia.var_aaebed696583903c ) && isdefined( self.zb_ia.var_d8e3b07237845727 ) && isdefined( self.zb_ia.var_d8e3b07237845727[ 0 ] ) )
    {
        self.zb_cb = self.zb_ia.var_d8e3b07237845727[ 0 ];
        self thread [[ level.zb_fire ]]();
        wait 1;
    }
    if ( self function_e3b3cc459cc1f25b() === self.zb_w0 )
        return fail( "buy failed: box gun not taken" );
    self.zb_weapons_bought = ( self.zb_weapons_bought ?? 0 ) + 1;
    box_cd();
    chat( "box", undefined );
    return finish( "buy box gun ok" );
}

// original box cooldown (zm_bo2_bots.gsc:1251): round <=8 90-180 s, <=15 240-450 s, else 480-900 s; starter guns 20-40 s; gambler x0.5.
// shortcut: "starter guns" = no gun bought yet (BO7 has no weapon score table), use a weapon tier if one is found.
box_cd()
{
    if ( self.zb_round <= 8 )
        self.zb_box_cd = 90000 + function_de284a0228a3400e( 90000 ); // randomint
    else if ( self.zb_round <= 15 )
        self.zb_box_cd = 240000 + function_de284a0228a3400e( 210000 );
    else
        self.zb_box_cd = 480000 + function_de284a0228a3400e( 420000 );
    if ( ( self.zb_weapons_bought ?? 0 ) == 0 )
        self.zb_box_cd = 20000 + function_de284a0228a3400e( 20000 );
    else if ( ( self.zb_pers ?? "allrounder" ) == "gambler" )
        self.zb_box_cd = self.zb_box_cd * 0.5;
    self.zb_box_next = gettime() + self.zb_box_cd;
}

fire_sale()
{
    if ( !isdefined( level.var_3c9cba73fc7b0e72 ) || !isdefined( level.var_3c9cba73fc7b0e72.var_2d8db9854390eecd ) || !isdefined( level.var_3c9cba73fc7b0e72.var_2d8db9854390eecd.var_a34b3b574ceb601d ) )
        return 0;
    return istrue( level.var_3c9cba73fc7b0e72.var_2d8db9854390eecd.var_a34b3b574ceb601d[ "powerup_fire_sale_active" ] );
}

bought()
{
    read_pts();
    if ( self.zb_kind == "perk" )
        return has_perk( self.zb_spec );
    return self.zb_pts < self.zb_pts0;
}

// failed buys get a retry cooldown (box: 30 s give-up cooldown of 3.9, unless a longer one is already set)
fail( text )
{
    if ( self.zb_kind == "perk" )
        self.zb_pfail[ self.zb_spec ] = gettime() + 60000;
    else if ( self.zb_kind == "wall" || self.zb_kind == "ammo" )
        self.zb_wall_next = gettime() + 60000;
    else if ( self.zb_kind == "pap" )
        self.zb_pap_next = gettime() + 120000;
    else if ( self.zb_kind == "box" && gettime() >= ( self.zb_box_next ?? 0 ) )
        self.zb_box_next = gettime() + 30000;
    return finish( text );
}

// one status per action; always frees movement
finish( text )
{
    if ( level.zb_box_bot === self )
        level.zb_box_bot = undefined;
    self.zb_busy = undefined;
    self.zb_buy_why = text;
    level.zb_status = text;
    return 1;
}

// chatter line from zm_bots_chat.gsc when that file is loaded (event + arg through fields would be safer, but a direct 2-arg pointer call compiles)
chat( ev, arg )
{
    if ( isdefined( level.zb_chat ) )
        self [[ level.zb_chat ]]( ev, arg );
}
