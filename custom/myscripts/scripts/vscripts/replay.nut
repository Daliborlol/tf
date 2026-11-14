// Demo replay prototype: bots act out a recorded moment, you play it live.
//
// 1. Generate replay_data.nut with ~/tf2-replay/demo2nut (see its usage).
// 2. `map <the demo's map>`, then `script_execute replay`
// 3. Wait for "Ready", then type !start in chat.
//
// Chat commands:
//   !start / !reset   (re)start the replay from the beginning (numpad 7 if bound)
//   !stop             freeze the bots where they are

IncludeScript("replay_data")   // defines ::ReplayData

const HIDE_Z = -16000          // where bots that are dead in the demo wait

::ClassNames <- [null, "scout", "sniper", "soldier", "demoman", "medic", "heavyweapons", "pyro", "spy", "engineer"]
::TeamNames <- { [2] = "red", [3] = "blue" }

// One entry per recorded player: { data, botname }
::ReplayBots <- []
foreach (i, p in ReplayData.players)
{
    // Console-safe, unique bot name: r<index>_<letters/digits of the real name>
    local clean = ""
    foreach (c in p.name)
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
            clean += c.tochar()
    if (clean.len() > 12)
        clean = clean.slice(0, 12)
    ReplayBots.append({ data = p, botname = "r" + i + "_" + clean })
}

::Replay <- {
    ready = false
    playing = false
    startAt = -1.0   // when to begin, after respawning you
    t0 = 0.0         // Time() at frame 0
}

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

function Say(msg)
{
    ClientPrint(null, Constants.EHudNotify.HUD_PRINTTALK, "\x07FFD700[replay] \x01" + msg)
}

/**
 * Put a bot where the recording says it is at frame idx, holding the right
 * weapon, and fire it if the player shot on this tick.
 * Frame layout (ReplayData.stride = 8): x, y, z, pitch, yaw, alive, weapon slot, fired
 * @param {CTFPlayer} bot
 */
function ApplyFrame(bot, f, idx, allowFire)
{
    local stride = ReplayData.stride
    local b = idx * stride
    if (f[b + 5] == 0)   // dead / not in the game yet at this point of the demo
    {
        bot.Teleport(true, Vector(0, 0, HIDE_Z), false, QAngle(), true, Vector())
        return
    }

    local pos = Vector(f[b], f[b + 1], f[b + 2])
    local ang = QAngle(f[b + 3], f[b + 4], 0)

    // Velocity towards the next frame so movement looks smooth between ticks.
    local vel = Vector()
    local n = b + stride
    if (n + 5 < f.len() && f[n + 5] != 0)
        vel = (Vector(f[n], f[n + 1], f[n + 2]) - pos) * (1.0 / ReplayData.interval)

    bot.Teleport(true, pos, true, ang, true, vel)
    bot.SnapEyeAngles(ang)

    // Weapon: slot is the index into m_hMyWeapons (0 primary, 1 secondary, 2 melee).
    local slot = f[b + 6]
    if (slot < 0)
        return
    local weapon = NetProps.GetPropEntityArray(bot, "m_hMyWeapons", slot)
    if (weapon == null)
        return
    if (bot.GetActiveWeapon() != weapon)
        bot.Weapon_Switch(weapon)

    if (allowFire && f[b + 7] != 0)
    {
        if (weapon.Clip1() >= 0)              // melee has no clip (-1)
            weapon.SetClip1(weapon.GetMaxClip1())   // never run dry
        weapon.PrimaryAttack()
    }
}

function StartReplay()
{
    local me = GetListenServerHost()
    if (me == null || !Replay.ready)
        return

    local want = ReplayData.me
    if (me.GetTeam() != want.team)
        me.ForceChangeTeam(want.team, true)
    if (me.GetPlayerClass() != want.cls)
    {
        me.SetPlayerClass(want.cls)
        NetProps.SetPropInt(me, "m_Shared.m_iDesiredPlayerClass", want.cls)
    }
    // Always respawn: full health/ammo, and a clean state for every attempt.
    me.ForceRegenerateAndRespawn()

    ::Replay.playing = false
    ::Replay.startAt = Time() + 0.2
}

// ---- Thinker: runs every server tick -----------------------------------------

function ReplayThink()
{
    if (!Replay.ready)
    {
        foreach (rb in ReplayBots)
            if (FindBot(rb.botname) == null)
                return 0.5

        foreach (rb in ReplayBots)
        {
            local bot = FindBot(rb.botname)
            // Noclip: no gravity or collisions fighting the per-tick teleports.
            bot.SetMoveType(Constants.EMoveType.MOVETYPE_NOCLIP, 0)
            ApplyFrame(bot, rb.data.f, 0, false)
        }
        ::Replay.ready = true
        Say(format("Ready: %d bots, %.1fs. Type !start (you are %s).",
            ReplayBots.len(), ReplayData.frames * ReplayData.interval, ReplayData.me.name))
        return -1
    }

    if (Replay.startAt > 0 && Time() >= Replay.startAt)
    {
        local me = GetListenServerHost()
        me.Teleport(true, ReplayData.me.pos, true, ReplayData.me.ang, true, Vector())
        me.SnapEyeAngles(ReplayData.me.ang)
        ::Replay.startAt = -1.0
        ::Replay.t0 = Time()
        ::Replay.playing = true
    }

    if (!Replay.playing)
        return -1

    local idx = ((Time() - Replay.t0) / ReplayData.interval).tointeger()
    if (idx >= ReplayData.frames)
    {
        ::Replay.playing = false
        Say("End of recording. !start to go again.")
        return -1
    }

    foreach (rb in ReplayBots)
    {
        local bot = FindBot(rb.botname)
        if (bot != null && bot.IsAlive())
        {
            bot.SetMoveType(Constants.EMoveType.MOVETYPE_NOCLIP, 0)   // reapply after respawns
            ApplyFrame(bot, rb.data.f, idx, true)
        }
    }
    return -1
}

local oldThinker = Entities.FindByName(null, "replay_thinker")
if (oldThinker != null)
    oldThinker.Kill()

local thinker = SpawnEntityFromTable("info_target", { targetname = "replay_thinker" })
thinker.ValidateScriptScope()
thinker.GetScriptScope().ReplayThink <- ReplayThink
AddThinkToEnt(thinker, "ReplayThink")

// ---- Chat commands -----------------------------------------------------------

ClearGameEventCallbacks()

function OnGameEvent_player_say(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p == null || p != GetListenServerHost())
        return

    if (params.text == "!start" || params.text == "!reset")
        StartReplay()
    else if (params.text == "!stop")
    {
        ::Replay.playing = false
        ::Replay.startAt = -1.0
        Say("Stopped.")
    }
}

__CollectGameEventCallbacks(this)

// ---- Setup -------------------------------------------------------------------

if (GetMapName() != ReplayData.map)
    Say("\x07FF4040Warning: \x01this recording is from " + ReplayData.map + ", you're on " + GetMapName())

SendToConsole("sv_cheats 1")                 // `bot` (puppet bots) is a cheat command
SendToConsole("mp_waitingforplayers_cancel 1")
SendToConsole("mp_autoteambalance 0")
SendToConsole("mp_teams_unbalance_limit 0")

foreach (rb in ReplayBots)
    if (FindBot(rb.botname) == null)
        SendToConsole(format("bot -team %s -class %s -name %s",
            TeamNames[rb.data.team], ClassNames[rb.data.cls], rb.botname))

Say("Spawning " + ReplayBots.len() + " bots...")
