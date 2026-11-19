#namespace zm_bots_find;

// Helper for zm_bots_buy.gsc: runs an interact's own use callback with the bot as player.
// This is the call the interaction system makes on a use event: `self thread [[ callback ]]( player )`
// (srvbase script_27623f7ac600060c.gsc:377, callbacks stored in .var_d8e3b07237845727 at lines 32/148).
// It skips the interaction-level checks (function_221183d25494e417); the callback still does its own
// checks and payment. Kept in its own file (rule 3). Inputs: self.zb_ia (interact), self.zb_cb (callback).
// unverified in game

autoexec init()
{
    level.zb_fire = &fire;
}

fire()
{
    self endon( #"disconnect" );
    if ( isdefined( self.zb_ia ) && isdefined( self.zb_cb ) )
        self.zb_ia [[ self.zb_cb ]]( self );
}
