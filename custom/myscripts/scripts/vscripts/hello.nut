printl("testsetsetsetstsetes");

ClearGameEventCallbacks();
function OnGameEvent_player_say(params)
{
  local userid = params.userid;
  local player = GetPlayerFromUserID(userid);
  if (player != null)
  {
    printl("not null");
    local name = player.GetName();
    printl("userid: " + userid);
    printl("player: " + name + " spoke");
    player.SetHealth(1000);
    local name = NetProps.GetPropString(player, "m_szNetname");
    ClientPrint(player, Constants.EHudNotify.HUD_PRINTTALK, "Health set to 1000, " + name + "!");
    if (player.GetPlayerClass() == Constants.ETFClass.TF_CLASS_PYRO) 
    {
      ClientPrint(player, Constants.EHudNotify.HUD_PRINTTALK, "playing pyro!");
    }
  }
}

__CollectGameEventCallbacks(this)
