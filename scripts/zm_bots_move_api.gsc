#namespace zm_bots_move_api;

// Remote door/debris buy for zm_bots_move.gsc, like the original bot_buy_door (buys without walking).
// Kronos refused to link srvbase namespace calls (doorbuy::, namespace_189fe7075a0930a5::: "unresolved import"
// in poi_reg.log), so this only uses fields and the interact's stored callback pointer.

autoexec init()
{
    level.zb_door_buy = &door_buy;
}

// self = bot, door trigger in self.zb_door. unverified in game.
door_buy()
{
    self.zb_dia = self.zb_door.var_4cf63ec91b753a3c;
    if ( !isdefined( self.zb_dia ) || !isdefined( self.zb_dia.var_d8e3b07237845727 ) || !isdefined( self.zb_dia.var_d8e3b07237845727[ 0 ] ) )
        return;
    // afford check so the bot does not trigger the deny UI: cost = .var_e2ea5c9302351a97 (what doorbuy passes to the
    // currency check, script_681a06cc8e9fcb34.gsc:626); points = the score field zm_bots_buy.gsc reads
    if ( !isdefined( self.var_8b69ecbd466a79fa ) || ( self.var_8b69ecbd466a79fa[ "score" ] ?? 0 ) < ( self.zb_door.var_e2ea5c9302351a97 ?? 999999 ) )
        return;
    // the door interact was made with &doorbuy::function_ff4e31657c10cfde as its use callback (script_681a06cc8e9fcb34.gsc:399)
    self.zb_dia [[ self.zb_dia.var_d8e3b07237845727[ 0 ] ]]( self );
}
