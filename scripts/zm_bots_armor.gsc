#using script_1f6b7243f8d72fef;

#namespace zm_bots_armor;

// Bots never insert their armor plates. When a bot has armor room, a plate in its stash and took no armor
// damage for 2 s, put one plate in, one per second like a quick player would.
// What the game does on a plate insert (armor, script_1f6b7243f8d72fef.gsc:1999-2017): armor health + plate
// value (function_cb22658f54166b6b), then plate count - 1. Public calls only: function_6a2b9bcb602048f sets armor
// health and refreshes it (:606), function_164c824617d7e8d7( -1 ) removes a plate (:693, the game does the same
// in script_6452c708dfd9cdbb.gsc:108). Fields: armor health .var_f0c9e2c7c2b57263, max .var_208247d6c5edea95.
// Own file: if Kronos refuses to link the armor:: calls, only this module is lost.
// unverified in game

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
        if ( !isalive( self ) || istrue( self.var_d0697a2251283e17 ) )
            continue;
        self.zb_ar_now = self.var_f0c9e2c7c2b57263 ?? 0;
        if ( self.zb_ar_now < ( self.zb_ar_last ?? 0 ) )
            self.zb_ar_hit = gettime();
        self.zb_ar_last = self.zb_ar_now;
        if ( ( self.var_208247d6c5edea95 ?? 0 ) <= 0 || self.zb_ar_now >= self.var_208247d6c5edea95 )
            continue;
        if ( gettime() - ( self.zb_ar_hit ?? 0 ) < 2000 )
            continue;
        if ( self armor::function_22290101992e4874() <= 0 )
            continue;
        self armor::function_6a2b9bcb602048f( self.zb_ar_now + max( 1, self armor::function_cb22658f54166b6b() ) );
        self armor::function_164c824617d7e8d7( -1 );
        self.zb_ar_last = self.var_f0c9e2c7c2b57263 ?? 0;
    }
}
