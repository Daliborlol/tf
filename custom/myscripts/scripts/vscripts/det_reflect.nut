// Detonator reflect bug: deterministic test between two puppet-bot Pyros.
//
// The bug: a reflected Detonator flare stays in the shooter's flare list
// (SendDeathNotice asks the *new* owner's weapon to remove it), and UTIL_Remove
// only deletes it at the start of the next server tick. Every SecondaryAttack()
// the shooter runs before then detonates it again, as the reflector's own
// (self-damage) explosion.
//
// A real client runs one SecondaryAttack per usercmd, and the server runs all of
// a client's queued usercmds back to back in one tick (CBasePlayer::PhysicsSimulate,
// capped by sv_maxusrcmdprocessticks = 24). Bots only ever send one usercmd per
// tick, so this script stands in for "N usercmds this tick" by calling the
// Detonator's SecondaryAttack() N times in a single tick. Everything else (the
// flare, the airblast, the damage and knockback) is the real game code.
//
// Usage: `map itemtest`, stand somewhere open and flat, look the way the test
// should run, then `script_execute det_reflect`. You get moved off to the side.
// Results: console, and tf/scriptdata/det_reflect_results.txt
//   script DR_Stop()      stop the sweep

// ---- Settings ----------------------------------------------------------------

const SHOOTER = "dr_shooter"      // BLU Pyro with the Detonator
const REFLECTOR = "dr_reflector"  // RED Pyro with the stock flamethrower
const DETONATOR = 351
const DIST = 600                  // shooter <-> reflector
const SETTLE_TICKS = 20           // ticks held in place before each trial
const MAX_FLY_TICKS = 60          // give up if the flare never gets in range
const AFTER_TICKS = 3             // ticks watched after the burst
const EFL_KILLME = 1              // marked by UTIL_Remove, deleted next tick
const RESULTS = "det_reflect_results.txt"

// ---- Sweep -------------------------------------------------------------------
//   reflect  airblast once the flare is this close to the reflector's eyes (units);
//            0 = control, never airblast: detonate the shooter's own flare there
//   pitch    reflector's view pitch when airblasting (89 = straight down)
//   delay    ticks between the airblast and the detonation burst (0 = same tick)
//   cmds     SecondaryAttack() calls in that one tick (= usercmds a client sent)
//   flares   flares fired at once (only 1 is possible in a real game: 2s refire)
//   hp       reflector health (175 = real Pyro; big = see the full burst)

::Phases <- []

function AddPhase(name, list) { Phases.append({ name = name, trials = list }) }

function T(reflect, pitch, delay, cmds, flares, hp)
{
    return { reflect = reflect, pitch = pitch, delay = delay, cmds = cmds, flares = flares, hp = hp }
}

// 0) Controls: no airblast. A normal flare must explode exactly once, whatever cmds is.
AddPhase("control", [T(0, 0, 0, 1, 1, 5000), T(0, 0, 0, 24, 1, 5000)])

// 1) Geometry, 1 command: which reflect setups leave the flare close enough to
//    hurt the reflector, and how hard one explosion pushes.
local geo = []
foreach (reflect in [240, 180, 120, 60])
    foreach (pitch in [0, 30, 60, 89])
        foreach (delay in [0, 1, 2, 3, 5, 8])
            geo.append(T(reflect, pitch, delay, 1, 1, 5000))
AddPhase("geometry", geo)

// 2) and 3) are filled in from the best geometry result (see PickBest).
::BEST <- null

// ---- State -------------------------------------------------------------------

::DR <- {
    ready = false
    stopped = false
    origin = null        // where the reflector stands
    fwd = null         // test direction (towards the shooter)
    phase = 0
    trial = 0
    state = "settle"
    ticks = 0
    flares = []
    measuring = false
    hitsReflector = 0
    hitsOther = 0
    lines = []
    geoResults = []
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

function Log(s)
{
    printl("[det_reflect] " + s)
    DR.lines.append(s)
}

function AnglesTo(from, to)
{
    local d = to - from
    local flat = sqrt(d.x * d.x + d.y * d.y)
    return QAngle(-atan2(d.z, flat) * 57.29578, atan2(d.y, d.x) * 57.29578, 0)
}

/** First weapon in m_hMyWeapons with this classname. */
function FindWeapon(p, cls)
{
    for (local i = 0; i < 8; i++)
    {
        local w = NetProps.GetPropEntityArray(p, "m_hMyWeapons", i)
        if (w != null && w.GetClassname() == cls)
            return w
    }
    return null
}

/** Replace the shooter's secondary with a Detonator (item 351). */
function GiveDetonator(p)
{
    local w = FindWeapon(p, "tf_weapon_flaregun")
    if (w != null && NetProps.GetPropInt(w, "m_AttributeManager.m_Item.m_iItemDefinitionIndex") == DETONATOR)
        return w

    local det = Entities.CreateByClassname("tf_weapon_flaregun")
    NetProps.SetPropInt(det, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", DETONATOR)
    NetProps.SetPropBool(det, "m_AttributeManager.m_Item.m_bInitialized", true)
    NetProps.SetPropBool(det, "m_bValidatedAttachedEntity", true)
    det.SetTeam(p.GetTeam())
    Entities.DispatchSpawn(det)

    for (local i = 0; i < 8; i++)
    {
        local old = NetProps.GetPropEntityArray(p, "m_hMyWeapons", i)
        if (old != null && old.GetSlot() == det.GetSlot())
        {
            old.Destroy()
            NetProps.SetPropEntityArray(p, "m_hMyWeapons", null, i)
            break
        }
    }
    p.Weapon_Equip(det)
    p.Weapon_Switch(det)
    return det
}

function Hold(p, pos, ang)
{
    p.Teleport(true, pos, true, ang, true, Vector(0, 0, 0))
    p.SnapEyeAngles(ang)
}

function ShooterPos() { return DR.origin + DR.fwd * DIST }

function Cur()
{
    local ph = Phases[DR.phase]
    return ph.trials[DR.trial]
}

function Describe(t)
{
    return format("reflect=%d pitch=%d delay=%d cmds=%d flares=%d hp=%d",
        t.reflect, t.pitch, t.delay, t.cmds, t.flares, t.hp)
}

function KillFlares()
{
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        f.Kill()
}

// ---- Trial state machine -----------------------------------------------------

function Settle(shooter, reflector, t)
{
    if (!reflector.IsAlive() || !shooter.IsAlive())
    {
        // Died last trial (hp = 175 runs): respawn now, keep settling.
        if (!reflector.IsAlive()) reflector.ForceRespawn()
        if (!shooter.IsAlive()) shooter.ForceRespawn()
        DR.ticks = 0
        return
    }

    local det = GiveDetonator(shooter)
    local ft = FindWeapon(reflector, "tf_weapon_flamethrower")
    if (ft != null && reflector.GetActiveWeapon() != ft)
        reflector.Weapon_Switch(ft)
    if (shooter.GetActiveWeapon() != det)
        shooter.Weapon_Switch(det)

    // Reflector faces the shooter; shooter aims at the reflector's chest.
    Hold(reflector, DR.origin, AnglesTo(DR.origin, ShooterPos()))
    Hold(shooter, ShooterPos(), AnglesTo(shooter.EyePosition(), reflector.GetCenter()))
    if (DR.ticks == 0)
        reflector.Regenerate(true)   // full ammo for the airblast
    reflector.SetHealth(t.hp)

    if (++DR.ticks < SETTLE_TICKS)
        return

    // Fire.
    local before = {}
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        before[f] <- true
    for (local i = 0; i < t.flares; i++)
    {
        NetProps.SetPropIntArray(shooter, "m_iAmmo", 16, det.GetPrimaryAmmoType())
        NetProps.SetPropFloat(det, "m_flNextPrimaryAttack", 0.0)
        det.PrimaryAttack()
    }
    DR.flares = []
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        if (!(f in before) && f.GetOwner() == shooter)
            DR.flares.append(f)

    if (DR.flares.len() != t.flares)
    {
        Finish(t, format("FAIL fired %d/%d flares", DR.flares.len(), t.flares))
        return
    }
    DR.state = "fly"
    DR.ticks = 0
}

function Fly(shooter, reflector, t)
{
    if (!DR.flares[0].IsValid())
    {
        Finish(t, "FAIL flare gone before it got in range")
        return
    }
    local d = (DR.flares[0].GetOrigin() - reflector.EyePosition()).Length()
    if (d > (t.reflect > 0 ? t.reflect : 80) && ++DR.ticks < MAX_FLY_TICKS)
        return
    if (DR.ticks >= MAX_FLY_TICKS)
    {
        Finish(t, "FAIL flare never got in range")
        return
    }
    DR.flyDist <- d

    if (t.reflect == 0)   // control: no airblast
    {
        DR.state = "delay"
        DR.ticks = 0
        if (t.delay == 0)
            Burst(shooter, reflector, t)
        return
    }

    // Airblast: face the flare's side at the chosen pitch.
    local ang = AnglesTo(DR.origin, ShooterPos())
    ang = QAngle(t.pitch, ang.y, 0)
    reflector.SnapEyeAngles(ang)
    local ft = FindWeapon(reflector, "tf_weapon_flamethrower")
    NetProps.SetPropFloat(ft, "m_flNextSecondaryAttack", 0.0)
    ft.SecondaryAttack()

    local deflected = 0
    foreach (f in DR.flares)
        if (f.IsValid() && f.GetOwner() == reflector)
            deflected++
    if (deflected == 0)
    {
        Finish(t, format("FAIL airblast missed (flare %.0f from eyes)", d))
        return
    }
    DR.deflected <- deflected

    DR.state = "delay"
    DR.ticks = 0
    if (t.delay == 0)
        Burst(shooter, reflector, t)
}

function Delay(shooter, reflector, t)
{
    if (DR.state != "delay")
        return
    if (++DR.ticks >= t.delay)
        Burst(shooter, reflector, t)
}

/** The shooter "presses right-click" in t.cmds usercmds, all in this one tick. */
function Burst(shooter, reflector, t)
{
    local alive = 0
    local near = 999999.0
    foreach (f in DR.flares)
        if (f.IsValid() && !(NetProps.GetPropInt(f, "m_iEFlags") & EFL_KILLME))
        {
            alive++
            local dd = (f.GetOrigin() - reflector.GetCenter()).Length()
            if (dd < near) near = dd
        }

    local det = FindWeapon(shooter, "tf_weapon_flaregun")
    local v0 = reflector.GetAbsVelocity()
    local h0 = reflector.GetHealth()
    DR.hitsReflector = 0
    DR.hitsOther = 0
    DR.measuring = true
    for (local i = 0; i < t.cmds; i++)
        det.SecondaryAttack()
    DR.measuring = false
    local dv = reflector.GetAbsVelocity() - v0

    DR.burst <- {
        alive = alive, near = near, dv = dv, dmg = h0 - reflector.GetHealth(),
        died = !reflector.IsAlive(), hits = DR.hitsReflector, other = DR.hitsOther
    }
    DR.state = "after"
    DR.ticks = 0
}

function After(shooter, reflector, t)
{
    if (++DR.ticks < AFTER_TICKS)
        return
    local gone = true
    foreach (f in DR.flares)
        if (f.IsValid())
            gone = false
    local b = DR.burst
    Finish(t, format("hits=%d other=%d dmg=%d dv=%.0f (vz %.0f) died=%s live_flares=%d near=%.0f deleted=%s",
        b.hits, b.other, b.dmg, b.dv.Length(), b.dv.z, b.died ? "yes" : "no", b.alive, b.near, gone ? "yes" : "NO"))
}

function Finish(t, result)
{
    local ph = Phases[DR.phase]
    Log(format("%-8s %3d/%-3d %s -> %s", ph.name, DR.trial + 1, ph.trials.len(), Describe(t), result))
    if (ph.name == "geometry" && "burst" in DR && result.find("FAIL") == null)
        DR.geoResults.append({ t = t, b = DR.burst })
    if ("burst" in DR)
        delete DR.burst

    KillFlares()
    DR.state = "settle"
    DR.ticks = 0
    if (++DR.trial >= ph.trials.len())
    {
        DR.trial = 0
        DR.phase++
        if (ph.name == "geometry")
            PickBest()
        if (DR.phase >= Phases.len())
        {
            Done()
            return
        }
        Log("---- phase " + Phases[DR.phase].name)
    }
}

/** Best geometry = hit the reflector with the most knockback per explosion. */
function PickBest()
{
    local best = null
    foreach (r in DR.geoResults)
        if (r.b.hits > 0 && (best == null || r.b.dv.Length() > best.b.dv.Length()))
            best = r
    if (best == null)
    {
        Log("no geometry hit the reflector; skipping the cmds/flares sweeps")
        return
    }
    ::BEST = best.t
    Log("best geometry: " + Describe(best.t) + format(" (dv %.0f per explosion)", best.b.dv.Length()))

    local b = BEST
    local cmds = []
    foreach (n in [1, 2, 3, 4, 6, 8, 12, 16, 20, 24, 32, 48])
        cmds.append(T(b.reflect, b.pitch, b.delay, n, 1, 5000))
    AddPhase("cmds", cmds)

    local real = []
    foreach (n in [1, 2, 3, 4, 6, 8, 12, 24])
        real.append(T(b.reflect, b.pitch, b.delay, n, 1, 175))
    AddPhase("real_hp", real)

    local fl = []
    foreach (f in [1, 2, 3, 4])
        fl.append(T(b.reflect, b.pitch, b.delay, 24, f, 5000))
    AddPhase("flares", fl)
}

function Done()
{
    Log("done")
    DR.stopped = true
    local s = ""
    foreach (l in DR.lines)
        s += l + "\n"
    StringToFile(RESULTS, s)
    printl("[det_reflect] saved tf/scriptdata/" + RESULTS)
}

::DR_Stop <- function() { DR.stopped = true; KillFlares(); Done() }

// ---- Thinker -----------------------------------------------------------------

function DRThink()
{
    if (DR.stopped)
        return 1.0
    local shooter = FindBot(SHOOTER)
    local reflector = FindBot(REFLECTOR)
    if (shooter == null || reflector == null)
        return 0.5

    if (!DR.ready)
    {
        if (shooter.GetTeam() != Constants.ETFTeam.TF_TEAM_BLUE || reflector.GetTeam() != Constants.ETFTeam.TF_TEAM_RED)
            return 0.5
        DR.ready = true
        Log("start: base " + DR.origin + " dir " + DR.fwd)
        Log("---- phase " + Phases[0].name)
    }

    local t = Cur()
    if (DR.state == "settle")      Settle(shooter, reflector, t)
    else if (DR.state == "fly")    Fly(shooter, reflector, t)
    else if (DR.state == "delay")  Delay(shooter, reflector, t)
    else if (DR.state == "after")  After(shooter, reflector, t)
    return -1   // every tick
}

// ---- Damage hook: count flare explosions that reach someone -------------------

ClearGameEventCallbacks()

function OnScriptHook_OnTakeDamage(params)
{
    if (!DR.measuring)
        return
    local inf = params.inflictor
    if (inf == null || inf.GetClassname() != "tf_projectile_flare")
        return
    if (params.const_entity == FindBot(REFLECTOR))
        DR.hitsReflector++
    else
        DR.hitsOther++
}

__CollectGameEventCallbacks(this)

// ---- Setup -------------------------------------------------------------------

local me = GetListenServerHost()
local yaw = me.EyeAngles().y * 0.0174533
::DR.fwd = Vector(cos(yaw), sin(yaw), 0)
::DR.origin = me.GetOrigin() + Vector(0, 0, 8)
// Out of the way: 400 units to the side of the test line.
me.Teleport(true, DR.origin + Vector(-DR.fwd.y, DR.fwd.x, 0) * 400, false, QAngle(), true, Vector())

SendToConsole("sv_cheats 1")                  // puppet bots
SendToConsole("mp_waitingforplayers_cancel 1")
SendToConsole("mp_autoteambalance 0")
SendToConsole("mp_teams_unbalance_limit 0")
SendToConsole("tf_weapon_criticals 0")        // no random crits
SendToConsole("tf_damage_disablespread 1")    // no +-10% damage spread
SendToConsole("mp_respawnwavetime 0")
if (FindBot(SHOOTER) == null)
    SendToConsole("bot -team blue -class pyro -name " + SHOOTER)
if (FindBot(REFLECTOR) == null)
    SendToConsole("bot -team red -class pyro -name " + REFLECTOR)

local old = Entities.FindByName(null, "dr_thinker")
if (old != null)
    old.Kill()
local thinker = SpawnEntityFromTable("info_target", { targetname = "dr_thinker" })
thinker.ValidateScriptScope()
thinker.GetScriptScope().DRThink <- DRThink
AddThinkToEnt(thinker, "DRThink")
