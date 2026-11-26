// operator (operator skins), as FuzMenu zm_mod_menu_arsenal.gsc includes it; the operator:: calls did not link without it
#using script_2dc447b1dd033a26;

#namespace zm_bots_crew;

// Not in the original: when the host plays a story character, each bot wears another member of that crew;
// otherwise bots keep the random operator the game gave them.
// Skin list operator::function_27f5412663e0a09() and skin -> operator operator::function_30f20ce375c4ee40(), with the
// as the game builds level.var_5283a34c59a363ca
// (srvbase script_18a132aeee23136e.gsc:1210). The operator:: script is not in our dump.
// Kept in its own file: if those calls do not link, only this file drops out.
// No int locals: in game they read back undefined, so state lives in level.* / self.* fields.

autoexec init()
{
    // operator refs the ZM voice lines test (srvbase script_640075fcb077c6bc.gsc:1672-1724), t10 and sat variants
    level.zb_crews = [
        [ [ %"t10_rus_pl_weaver", %"sat_rus_pl_weaver" ], [ %"t10_phl_pl_maya", %"sat_phl_pl_maya" ], [ %"t10_gbr_pl_grey", %"sat_gbr_pl_grey" ], [ %"t10_usa_pl_carver", %"hash_4f7e059d808f6b7" ] ],
        [ [ %"hash_50384cf6a53f03df" ], [ %"hash_181d2fe7b630c9f7" ], [ %"hash_26c1654b06174963" ], [ %"hash_6eb958c258f756f0" ] ]
    ];
    level.zb_crew_n = 0;
    if ( !isdefined( level.zb_mods ) )
        level.zb_mods = [];
    level.zb_mods[ level.zb_mods.size ] = &think;
}

// self = bot, once
think()
{
    self endon( #"disconnect" );
    if ( isdefined( self.zb_crew_done ) )
        return;
    self.zb_crew_done = 1;
    wait 2; // let the game set the bot's own operator first
    if ( !isdefined( self.zb_host ) || !isdefined( self.zb_host.var_e5cf5a2e5629693b ) || !isdefined( level.zb_wear ) )
        return;
    // the crew members other than the host's character
    self.zb_crew_others = undefined;
    foreach ( crew in level.zb_crews )
        foreach ( member in crew )
            foreach ( op in member )
                if ( self.zb_host.var_e5cf5a2e5629693b.var_85b57f620e95b0ef === op )
                {
                    self.zb_crew_others = [];
                    foreach ( m in crew )
                        if ( !( m[ 0 ] === member[ 0 ] ) )
                            self.zb_crew_others[ self.zb_crew_others.size ] = m;
                }
    if ( !isdefined( self.zb_crew_others ) )
    {
        self crew_say( "host is not a story character" );
        return;
    }
    self.zb_crew_i = level.zb_crew_n % self.zb_crew_others.size;
    level.zb_crew_n++;
    // first skin of each other member (keyed by its first operator ref). No "has a model" filter
    // (function_82781d300aee973e): in ZM it is "" for all 40 crew skins (tested 2026-11-26)
    self.zb_crew_skins = [];
    self.zb_crew_ops = [];
    self.zb_crew_count = 0;
    self.zb_crew_found = 0;
    foreach ( skin in operator::function_27f5412663e0a09() )
    {
        self.zb_crew_count++;
        foreach ( m in self.zb_crew_others )
            foreach ( op in m )
                if ( operator::function_30f20ce375c4ee40( skin ) === op )
                {
                    self.zb_crew_found++;
                    if ( !isdefined( self.zb_crew_skins[ m[ 0 ] ] ) )
                    {
                        self.zb_crew_skins[ m[ 0 ] ] = skin;
                        self.zb_crew_ops[ m[ 0 ] ] = op;
                    }
                }
    }
    // this bot's member, or the next one that has a skin (a member can be missing from this mode)
    self.zb_crew_try = 0;
    self.zb_crew_op = undefined;
    while ( !isdefined( self.zb_crew_op ) && self.zb_crew_try < self.zb_crew_others.size )
    {
        self.zb_crew_member = self.zb_crew_others[ ( self.zb_crew_i + self.zb_crew_try ) % self.zb_crew_others.size ];
        self.zb_crew_op = self.zb_crew_ops[ self.zb_crew_member[ 0 ] ];
        self.zb_crew_skin = self.zb_crew_skins[ self.zb_crew_member[ 0 ] ];
        self.zb_crew_try++;
    }
    if ( !isdefined( self.zb_crew_op ) )
    {
        self crew_say( "no crew skin among " + self.zb_crew_count + " (" + self.zb_crew_found + " crew skins)" );
        return;
    }
    self [[ level.zb_wear ]]( self.zb_crew_op, self.zb_crew_skin );
    self crew_say( "member " + self.zb_crew_i + " -> wears member " + ( ( self.zb_crew_i + self.zb_crew_try - 1 ) % self.zb_crew_others.size ) + " (" + self.zb_crew_found + " crew skins)" );
}

// result for zb_cmd diag
crew_say( msg )
{
    self.zb_crew_msg = msg;
}
