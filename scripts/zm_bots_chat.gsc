#namespace zm_bots_chat;

// Bot chatter, ported from zm_bo2_bots.gsc bot_chatter / bot_line and their callers (texts kept verbatim).
// BO7 has no say/sayall builtin in the dumps, so like the original each line is an iprintln "^5<name>^7: <text>" to every human.
// level.zb_cfg_chatter 0 (dvar zb_chatter, config module) mutes it.
// Other modules get the original event lines through `self [[ level.zb_chat ]]( ev, arg );` (self = bot), see chat_event.
// Unverified in game: everything in this file (the iprintln/randomint/getaiarrayinradius calls are cited from srvbase).

autoexec init()
{
    level.zb_chat = &chat_event;
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

// original bot_chatter: 4 s per bot rate limit, sent to humans only
say( text )
{
    if ( ( level.zb_cfg_chatter ?? 1 ) == 0 )
        return;
    if ( isdefined( self.zb_next_chat ) && gettime() < self.zb_next_chat )
        return;
    self.zb_next_chat = gettime() + 4000;
    foreach ( p in level.players )
        if ( isdefined( p ) && !isbot( p ) )
            p iprintln( "^5" + self.name + "^7: " + text ); // iprintln = function_235966f19e759592, player as self, plain string: srvbase script_12e9f63dac5ec9fe.gsc:7833, script_2d110487966779fc.gsc:18
}

// original bot_line: one random entry
pick( lines )
{
    return lines[ randomint( lines.size ) ]; // randomint = function_de284a0228a3400e( array.size ): srvbase script_4440095dbe990b46.gsc:2345
}

think()
{
    self endon( #"disconnect" );
    // a second think on the same bot replaces the first
    self notify( #"zb_chat_think" );
    self endon( #"zb_chat_think" );
    if ( !isdefined( level.zb_chat_started ) )
    {
        level.zb_chat_started = 1;
        level thread greeting();
        level thread round_lines();
    }
    self thread on_reviving();
    self thread on_revived();
    self.zb_chat_down = istrue( self.var_d0697a2251283e17 );
    self.zb_chat_alive = isalive( self ) && self.sessionstate == "playing";
    for ( ;; )
    {
        wait 0.5;
        self.zb_chat_was_down = self.zb_chat_down;
        self.zb_chat_was_alive = self.zb_chat_alive;
        self.zb_chat_down = istrue( self.var_d0697a2251283e17 );
        self.zb_chat_alive = isalive( self ) && self.sessionstate == "playing";
        // bot_chatter_down_think: laststand edge
        if ( self.zb_chat_down && !self.zb_chat_was_down )
            say( pick( [ "^1I'm down!^7 Need a revive!", "^1Down!^7 Someone pick me up!", "^1Help!^7 I'm down!", "^1They got me!^7 Revive please!" ] ) );
        // bot_thanks_think: back up; the core reviver sets zb_rev_by just after the revive ends, so wait for it
        else if ( !self.zb_chat_down && self.zb_chat_was_down && self.zb_chat_alive )
        {
            wait 1;
            if ( isdefined( self.zb_rev_by ) )
                say( pick( [ "Thanks, " + self.zb_rev_by + "!", "Owe you one, " + self.zb_rev_by + ".", "Back up! Thanks " + self.zb_rev_by + "!", "Lifesaver, " + self.zb_rev_by + "!" ] ) );
            else
                say( pick( [ "I'm back up!", "Back on my feet!" ] ) );
            self.zb_rev_by = undefined;
        }
        // bot_back_in_callout: respawn after a bleed-out, 3 s later
        else if ( self.zb_chat_alive && !self.zb_chat_was_alive )
        {
            wait 3;
            say( pick( [ "I'm back in! Let's go!", "Back in the game!", "Respawned. What did I miss?" ] ) );
        }
        else if ( self.zb_chat_alive && !self.zb_chat_down )
            help_callout();
    }
}

// bot_try_help_callout: hp <= 35% and 2+ zombies within 300, once per 30 s
help_callout()
{
    if ( isdefined( self.zb_next_help ) && gettime() < self.zb_next_help )
        return;
    if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 || self.health > self.maxhealth * 0.35 ) // maxHealth: srvbase script_8c8e132af264960.gsc:411
        return;
    if ( function_e93520ec766414ac( self.origin, 300 ).size < 2 ) // getaiarrayinradius( origin, radius ): srvbase script_1ce525b1c9956c2b.gsc:752
        return;
    self.zb_next_help = gettime() + 30000;
    say( pick( [ "I need help over here!", "I'm getting swarmed!", "Low health, cover me!", "They're all over me!" ] ) );
}

// line 2476 in the original revive: core bot_revive notifies zb_reviving with self.zb_rev = the downed player
on_reviving()
{
    self endon( #"disconnect" );
    self endon( #"zb_chat_think" );
    for ( ;; )
    {
        self waittill( #"zb_reviving" );
        if ( isdefined( self.zb_rev ) && isdefined( self.zb_rev.name ) )
            say( pick( [ "Reviving " + self.zb_rev.name + "!", "Hold on " + self.zb_rev.name + ", I've got you!", "Picking up " + self.zb_rev.name + "!", "Cover me, getting " + self.zb_rev.name + " up!" ] ) );
    }
}

// tells the revived player who picked them up, for its thanks line (BO7 laststand_revived carries no reviver)
on_revived()
{
    self endon( #"disconnect" );
    self endon( #"zb_chat_think" );
    for ( ;; )
    {
        self waittill( #"zb_revived" );
        if ( isdefined( self.zb_rev ) )
            self.zb_rev.zb_rev_by = self.name;
    }
}

// one random alive bot of ours (ZM has one team, so the original "one per team" is one bot)
random_bot()
{
    level.zb_chat_bots = [];
    foreach ( p in level.players )
        if ( isdefined( p ) && isbot( p ) && isdefined( p.zmbots ) && isalive( p ) && !istrue( p.var_d0697a2251283e17 ) )
            level.zb_chat_bots[ level.zb_chat_bots.size ] = p;
    if ( level.zb_chat_bots.size == 0 )
        return undefined;
    return pick( level.zb_chat_bots );
}

// bot_round_chatter_think, first part: personality greeting 12 s in
greeting()
{
    wait 12;
    level.zb_chat_bot = random_bot();
    if ( !isdefined( level.zb_chat_bot ) )
        return;
    level.zb_chat_pers = level.zb_chat_bot.zb_pers ?? "allrounder";
    if ( level.zb_chat_pers == "slayer" )
        level.zb_chat_bot say( pick( [ "Let's rack up some kills!", "Point me at the horde.", "I'm going for high kills." ] ) );
    else if ( level.zb_chat_pers == "medic" )
        level.zb_chat_bot say( pick( [ "Stay close, I'll pick you up.", "I've got your back.", "Nobody bleeds out on my team." ] ) );
    else if ( level.zb_chat_pers == "gambler" )
        level.zb_chat_bot say( pick( [ "Who's hitting the box first?", "Feeling lucky today.", "The box owes me one." ] ) );
    else if ( level.zb_chat_pers == "engineer" )
        level.zb_chat_bot say( pick( [ "I'll get the doors open.", "Leave the debris to me.", "I'll open up the map." ] ) );
    else
        level.zb_chat_bot say( pick( [ "GLHF everyone!", "Let's get to round 50!", "Ready when you are." ] ) );
}

// bot_round_chatter_think, second part: every 10th round
// on_round_start: srvbase script_77dca3b46e01eb1e.gsc:155 (notify), script_2bdf8eafdb703418.gsc:7965 (waittill)
// round number = what namespace_7942a9cf653f89::function_c00961f92fc28240 returns: srvbase script_77dca3b46e01eb1e.gsc:289
round_lines()
{
    level endon( #"game_ended" );
    for ( ;; )
    {
        level waittill( #"on_round_start" );
        if ( !isdefined( level.var_6781718da4f78d1c ) || !isdefined( level.var_6781718da4f78d1c.var_392f37fdba9f6777 ) )
            continue;
        level.zb_chat_round = level.var_6781718da4f78d1c.var_392f37fdba9f6777;
        if ( level.zb_chat_round <= 1 || level.zb_chat_round % 10 != 0 )
            continue;
        level.zb_chat_bot = random_bot();
        if ( isdefined( level.zb_chat_bot ) )
            level.zb_chat_bot say( pick( [ "Round " + level.zb_chat_round + "! Keep it going!", "Round " + level.zb_chat_round + " already. Let's keep it up!", level.zb_chat_round + " rounds down. Stay sharp!" ] ) );
    }
}

// event lines for the buy / retreat modules (self = bot), exact original texts:
//   "perk" (arg = perk display name), "powerup" (arg = power-up name), "box", "pap", "retreat_last", "retreat_swarm", "retreat_low"
chat_event( ev, arg )
{
    if ( ev == "perk" && isdefined( arg ) )
        say( pick( [ "Got " + arg + "!", "Just grabbed " + arg + ".", arg + " down. Let's go!" ] ) );
    else if ( ev == "powerup" && isdefined( arg ) )
        say( pick( [ "Grabbing the " + arg + "!", "I've got the " + arg + "!", "Going for the " + arg + "!", arg + "! Grabbing it." ] ) );
    else if ( ev == "box" )
        say( pick( [ "Rolling the box!", "Let's see what the box gives me.", "Come on, Ray Gun...", "Box time. Be nice to me." ] ) );
    else if ( ev == "pap" )
        say( pick( [ "Gun's Pack-a-Punched!", "Fresh upgrade, let's go!", "Packed and ready!", "Now we're talking. Upgraded!" ] ) );
    else if ( ev == "retreat_last" )
        say( pick( [ "^1I'm the last one up!^7 Keeping them moving!", "^1Last one standing!^7 Kiting them!", "^1Just me left!^7 Staying on the move!" ] ) );
    else if ( ev == "retreat_swarm" )
        say( pick( [ "^3Too many!^7 Repositioning!", "^3Getting swarmed,^7 moving!", "^3Breaking out^7 to open space!", "^3They're surrounding me!^7 Moving!" ] ) );
    else if ( ev == "retreat_low" )
        say( pick( [ "^1Low health!^7 Falling back, cover me!", "^1I'm hurt!^7 Backing off!", "^1Red screen!^7 Pulling back!", "^1Need a second!^7 Getting out of here!" ] ) );
}
