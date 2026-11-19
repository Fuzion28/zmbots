#namespace zm_bots_client;

// Second half of BO6 bots::spawn_bot_latent: an addbot() entity is only a connecting client until
// spawnbotortestclient() turns it into a player. These two builtins appear only in BO7 dev code
// (script_7262b27de233448f.gsc:4823), so they live in their own file: if Kronos refuses to link them,
// only this file is lost and zm_bots.gsc reports "no latent".
// No locals: in game, int locals read back undefined, so state goes in fields.

autoexec init()
{
    level.zb_latent = &latent;
}

// self = entity returned by addbot
latent()
{
    level.zb_lat = "waiting canspawn";
    self.zb_until = gettime() + 60000;
    while ( !self canspawnbotortestclient() )
    {
        if ( gettime() >= self.zb_until )
        {
            level.zb_lat = "canspawn timeout";
            return;
        }
        wait 0.05;
        if ( !isdefined( self ) )
        {
            level.zb_lat = "bot gone";
            return;
        }
    }
    self spawnbotortestclient();
    // no bot_funcs["think"] here: verified in game that the engine bot already aims and shoots on its own
    level.zb_lat = "spawned";
}
