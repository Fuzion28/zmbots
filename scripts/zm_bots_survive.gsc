#namespace zm_bots_survive;

// Port of the original bot_max_health / bot_infinite_ammo: bots get 500 health (1000 with Juggernog) and their
// reserve ammo is refilled. Same calls FuzMenu uses on players (zm_mod_menu.gsc:5481 self.health = self.maxhealth,
// :3126 givemaxammo over player.primaryinventory). Owned perks: var_298fe7dcdb17fe4f, as zm_bots_buy.gsc has_perk.
// Lava/hazard immunity is not ported: it needs a damage callback, and a mod cannot hook srvbase ones (see docs).

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
        if ( ( level.zb_cfg_max_health ?? 500 ) > 0 )
        {
            self.zb_hp_want = level.zb_cfg_max_health ?? 500;
            if ( isdefined( self.var_298fe7dcdb17fe4f ) && isdefined( self.var_298fe7dcdb17fe4f[ "specialty_juggernog" ] ) )
                self.zb_hp_want = self.zb_hp_want * 2;
            // the game resets maxhealth on spawn, revive and perk changes: re-apply and fill up once each time
            if ( !isdefined( self.maxhealth ) || self.maxhealth != self.zb_hp_want )
            {
                self.maxhealth = self.zb_hp_want;
                self.health = self.zb_hp_want;
            }
        }
        self.zb_ammo_t = ( self.zb_ammo_t ?? 0 ) + 1;
        if ( istrue( level.zb_cfg_infinite_ammo ?? 1 ) && self.zb_ammo_t % 5 == 0 && isdefined( self.primaryinventory ) )
            foreach ( w in self.primaryinventory )
                self givemaxammo( w );
    }
}
