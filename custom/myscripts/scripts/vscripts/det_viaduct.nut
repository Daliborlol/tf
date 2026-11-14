// Detonator training on koth_viaduct — VScript port of det_koth_viaduct.cfg (by VAVLIE).
//
// Usage: `map koth_viaduct`, join BLU as Pyro (equip the Detonator), then
//   script_execute det_viaduct
//
// Chat commands:
//   !reset   put every bot and you back in place (also bound to numpad 7)
//   !next    highlight the next bot as your target
//   !prev    highlight the previous bot
//   !pos     print your current position as a ready-to-paste line

// ---- Settings ----------------------------------------------------------------

const FAKE_LAG = 20          // net_fakelag value; your ping ends up ~2x this. 0 = off
const GLOW_COLOR = "255 215 0 255"

// Where you get placed: origin + eye angles (pitch, yaw, roll).
::PlayerStart <- { pos = Vector(-1334, -1066, 452), ang = QAngle(2, 91, 0) }

// The bots. `lift` = first place it this many units lower, then raise it a bit
// later (the cfg does this for bot07, presumably so it lands on its ledge).
::Bots <- [
    { name = "bot01", cls = "pyro",    pos = Vector(-1219,  1114, 382), ang = QAngle( 7,  -93, 0) }
    { name = "bot02", cls = "pyro",    pos = Vector( -921,   549, 219), ang = QAngle( 9, -178, 0) }
    { name = "bot03", cls = "pyro",    pos = Vector(-1519,   531, 143), ang = QAngle( 1,  -95, 0) }
    { name = "bot04", cls = "pyro",    pos = Vector(-1161,  1215,  90), ang = QAngle(-5,  -95, 0) }
    { name = "bot05", cls = "pyro",    pos = Vector(-2621,  1355, 125), ang = QAngle(11,  -91, 0) }
    { name = "bot06", cls = "pyro",    pos = Vector(-2518,   323, 444), ang = QAngle(20,   -2, 0) }
    { name = "bot07", cls = "pyro",    pos = Vector( -637,   991, 382), ang = QAngle( 5, -126, 0), lift = 32 }
    { name = "bot08", cls = "pyro",    pos = Vector(-1424,   202, 234), ang = QAngle(15,    0, 0) }
    { name = "bot09", cls = "pyro",    pos = Vector(-1528,  -441, 292), ang = QAngle(11,   82, 0) }
    { name = "bot10", cls = "pyro",    pos = Vector(-1351,  -966, 158), ang = QAngle( 0,   86, 0) }
    { name = "bot11", cls = "pyro",    pos = Vector(-1438, -1208, 382), ang = QAngle( 5,   86, 0) }
    { name = "bot12", cls = "heavy",   pos = Vector(-2140,  -311, 254), ang = QAngle( 9,  118, 0) }
    { name = "bot13", cls = "medic",   pos = Vector(-1996,  -367, 254), ang = QAngle( 9,  158, 0) }
    { name = "bot14", cls = "demoman", pos = Vector(-2099,  -410, 254), ang = QAngle(10,   86, 0) }
    { name = "bot15", cls = "pyro",    pos = Vector( -524, -1365, 120), ang = QAngle( 7,  178, 0) }
]

// Index into ::Bots of the bot you're supposed to hit.
if (!("TargetIndex" in getroottable()))
    ::TargetIndex <- 0

// ---- Helpers -----------------------------------------------------------------

/** @returns {CTFPlayer|null} */
function FindBot(name)
{
    for (local i = 1; i <= MaxClients().tointeger(); i++)
    {
        local p = PlayerInstanceFromIndex(i)
        if (p != null && p.IsFakeClient() && NetProps.GetPropString(p, "m_szNetname") == name)
            return p
    }
    return null
}

function Say(player, msg)
{
    ClientPrint(player, Constants.EHudNotify.HUD_PRINTTALK, "\x07FFD700[det] \x01" + msg)
}

/** @param {CTFPlayer} p */
function Place(p, pos, ang)
{
    p.Teleport(true, pos, true, ang, true, Vector(0, 0, 0))
    p.SnapEyeAngles(ang)
    p.AddCond(Constants.ETFCond.TF_COND_RUNE_REGEN)   // addcond 92 in the cfg
}

function PlaceBot(entry)
{
    local bot = FindBot(entry.name)
    if (bot == null || !bot.IsAlive())
        return

    // targetname lets the tf_glow entity find this bot by name
    bot.KeyValueFromString("targetname", "det_" + entry.name)

    if ("lift" in entry)
    {
        Place(bot, entry.pos - Vector(0, 0, entry.lift), entry.ang)
        PendingPlacements.append({ entry = entry, at = Time() + 0.8 })
    }
    else
        Place(bot, entry.pos, entry.ang)
}

function PlaceEverything()
{
    foreach (entry in Bots)
        PlaceBot(entry)

    // Medic keeps the heavy healed, like the cfg's bot_forcefireweapon line.
    SendToConsole("bot_forcefireweapon tf_weapon_medigun")

    local me = GetListenServerHost()
    if (me != null && me.IsAlive())
        Place(me, PlayerStart.pos, PlayerStart.ang)
}

function UpdateGlow()
{
    local old = Entities.FindByName(null, "det_glow")
    if (old != null)
        old.Kill()

    local entry = Bots[TargetIndex]
    SpawnEntityFromTable("tf_glow", {
        targetname = "det_glow"
        target = "det_" + entry.name
        GlowColor = GLOW_COLOR
    })

    local me = GetListenServerHost()
    if (me != null)
        Say(me, "Target: \x07FFD700" + entry.name + " \x01(" + entry.cls + ")")
}

// ---- Setup -------------------------------------------------------------------

function Setup()
{
    // Puppet bots (`bot`) and bot_forcefireweapon are cheat commands, like in the cfg.
    SendToConsole("sv_cheats 1")
    SendToConsole("mp_waitingforplayers_cancel 1")
    SendToConsole("mp_autoteambalance 0")
    SendToConsole("mp_teams_unbalance_limit 0")
    SendToConsole("net_fakelag " + FAKE_LAG)
    SendToConsole("bind KP_HOME \"say !reset\"")

    // Only create bots that don't exist yet, so re-running the script is safe.
    foreach (entry in Bots)
        if (FindBot(entry.name) == null)
            SendToConsole("bot -team red -class " + entry.cls + " -name " + entry.name)
}

// Bots join asynchronously, so a thinker waits until they all exist before
// placing them, and also handles delayed placements (lift, respawns).
::PendingPlacements <- []
::SetupDone <- false

function DetThink()
{
    if (!SetupDone)
    {
        foreach (entry in Bots)
            if (FindBot(entry.name) == null)
                return 0.5

        ::SetupDone = true
        PlaceEverything()
        UpdateGlow()
        Say(GetListenServerHost(), "Ready. Chat: !reset (numpad 7), !next, !prev, !pos")
        return 0.1
    }

    local now = Time()
    local still = []
    foreach (p in PendingPlacements)
    {
        if (now < p.at)
        {
            still.append(p)
            continue
        }
        if ("player" in p)       // a respawned player (you, or a bot that died)
        {
            if (p.player.IsValid() && p.player.IsAlive())
            {
                if (p.player == GetListenServerHost())
                    Place(p.player, PlayerStart.pos, PlayerStart.ang)
                else
                    PlaceBot(p.entry)
            }
        }
        else                     // second step of a `lift` placement
        {
            local bot = FindBot(p.entry.name)
            if (bot != null && bot.IsAlive())
                Place(bot, p.entry.pos, p.entry.ang)
        }
    }
    ::PendingPlacements = still
    return 0.1
}

local oldThinker = Entities.FindByName(null, "det_thinker")
if (oldThinker != null)
    oldThinker.Kill()

local thinker = SpawnEntityFromTable("info_target", { targetname = "det_thinker" })
thinker.ValidateScriptScope()
thinker.GetScriptScope().DetThink <- DetThink
AddThinkToEnt(thinker, "DetThink")

// ---- Events ------------------------------------------------------------------

ClearGameEventCallbacks()

function OnGameEvent_player_spawn(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p == null || !SetupDone)
        return

    // Teleporting during the spawn event itself gets overridden, so defer it.
    if (p == GetListenServerHost())
    {
        PendingPlacements.append({ player = p, at = Time() + 0.1 })
        return
    }
    local name = NetProps.GetPropString(p, "m_szNetname")
    foreach (entry in Bots)
        if (entry.name == name)
            PendingPlacements.append({ player = p, entry = entry, at = Time() + 0.1 })
}

function OnGameEvent_player_hurt(params)
{
    local me = GetListenServerHost()
    local attacker = GetPlayerFromUserID(params.attacker)
    local victim = GetPlayerFromUserID(params.userid)
    if (me == null || attacker != me || victim == null)
        return

    local name = NetProps.GetPropString(victim, "m_szNetname")
    if (name == Bots[TargetIndex].name)
        ClientPrint(me, Constants.EHudNotify.HUD_PRINTCENTER, "HIT " + name + " for " + params.damageamount)
}

function OnGameEvent_player_say(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p == null || p != GetListenServerHost())
        return

    local text = params.text
    if (text == "!reset")
    {
        PlaceEverything()
    }
    else if (text == "!next" || text == "!prev")
    {
        local step = text == "!next" ? 1 : Bots.len() - 1
        ::TargetIndex = (TargetIndex + step) % Bots.len()
        UpdateGlow()
    }
    else if (text == "!pos")
    {
        local o = p.GetOrigin()
        local a = p.EyeAngles()
        local line = format("pos = Vector(%d, %d, %d), ang = QAngle(%d, %d, 0)", o.x.tointeger(), o.y.tointeger(), o.z.tointeger(), a.x.tointeger(), a.y.tointeger())
        Say(p, line)
        printl(line)   // also in the console, easier to copy
    }
}

__CollectGameEventCallbacks(this)

Setup()
