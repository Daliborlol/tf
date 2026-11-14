// Staged stunts with several actors, tick-exact and repeatable.
//
// A scene is a set of tracks. A track is one actor's performance, and you record
// them one at a time: while you play one track, every other track is acted out by
// a bot (named after its track) on the same ticks. So you can record a Detonator
// reflect launch as a Pyro, then record yourself as a Soldier shooting a rocket at
// the Pyro bot flying through the air, then go back to the Pyro and re-record it
// from just before the rocket gets there, getting hit by that rocket for real.
//
// The Detonator shooter (ss_shooter) is a puppet bot. It fires a flare at one
// track on a fixed tick; when that track airblasts it, the script detonates it
// BURST times in one tick (the reflect bug, see det_reflect.nut).
//
// Usage: `map <any>`, `script_execute stunt`. Commands go in chat. !help lists them,
// !help <command> explains one (also printed to your console). From the console:
// anyone can type say !rw 20; the host also has every command as ss_<command> without
// arguments (bind f ss_rw) and with arguments as: script SS_Cmd("!rw 20").
// Ticks are scene ticks (66 per second).
//
// With friends: everyone on your server plays their own track, recorded at the same
// time, and anyone can use the commands. !new starts a take for everyone, !rw and !to
// put everyone back at that tick and everyone goes live together; !live limits that to
// some tracks, and the rest replay theirs. Bots only stand in for a track whose player
// isn't on the server (and the Detonator shooter, if you place it). A friend replaying
// is moved by the server, since the script can only press keys on the host's PC: it
// looks right to others, but on their own screen the view steps and their own weapon
// sounds and effects are missing. Their clean POV is their live takes:
//   bind k "record mypov; hud_saytext_time 0; say !mark mypov"
//   bind j "stop; hud_saytext_time 12; say !mark off"     (then !cuts lists what to keep)
// Chat is saved in demos: watch or render them with hud_saytext_time 0.
//
// Tracks
//   !track <name> [red|blue]   play that track (your old one goes to a bot unless someone
//                       takes it); a new one gets your class and the team you give
//                       (or yours). Actors only hurt and push each other if
//                       they're on different teams: the Soldier who airshots the Pyro
//                       has to be on the other team (!track soldier blue).
//   !tracks             list them        !del <name>      delete one
//   !shift <name> <n>   move a track n ticks later (negative: earlier)
//   !mute <name>  /  !unmute <name>     leave a track out of the scene / back in
//   !live <tracks|me|all>   who goes live on !new, !rw, !to (default: all)
//
// Recording the track you play
//   !new [tick]         record from scratch, everyone starting where they stand, from that
//                       scene tick (default: where your track started, or 0). The rest plays along.
//   !stop               end the take
//   !rw [n]             go back n ticks (default 33): the scene replays a run-up to there,
//                       with you following your own recording, then you're live
//   !to <tick>          the same, to a scene tick
//   !go                 skip the frozen wait before a run (not the run-up)
//   !cp                 checkpoint at the current tick       !rr  back to the last one, live
//   !uncp  !cps         remove the last checkpoint / list them
//   !runup <ticks>      how much a rewind replays first (default 66; 0 for quick retries)
//   !undo  !redo        undo / redo the last change (take, rewind, shift, join, delete...)
//   !versions  !join <v#|file> <tick>  !save <name>  !load <name>
//
// Detonator shooter
//   !shooter            put it where you stand; it fires at the track you play
//   !noshooter          take it out
//   !fire               it fires now (during a take: recorded; between takes: practice)
//   !fireat <n|off>     when it fires by itself in a new take, in ticks from that track's
//                       start (default 66; off: only on !fire)
//   !burst <n>          detonations in the burst tick (default 24; a real client gets <= 24)
//   !delay <n>          ticks from your airblast to the burst (default 2, at least 1)
//   !hpafter <hp>       your health right after the burst (0 = what you had before it)
//
// Who has the Detonator
//   !det <track>        that track's actor has it instead of the shooter bot (!det me: the
//                       track you play; !det bot: back to the shooter bot). The actor fires
//                       flares with M1 and M2 is the burst: pressed while a flare of theirs
//                       is reflected, it detonates !burst times in that tick, on whoever
//                       reflected it. Recorded presses do the same when the track replays.
//                       !burst and !hpafter are then that track's; !fireat and !delay aren't
//                       used. A bot's movement is its recording, so a burst only launches
//                       someone you're playing live: to launch the reflector, record the
//                       Detonator track first, then the reflector, reflecting before the M2.
//
// Watching and exporting
//   !play               the whole scene through your track's eyes (you follow your recording)
//   !render <demo>      the same, recorded as one demo: your POV, HUD, name and skins
//   !spec [track] [demo]   watch a track's bot first-person from spectator
//   !demo <name> !demostop !cuts !demooffset <n>   a demo of your live takes + what to keep
//   Demo names get the date and time added (clip_1104_153012.dem), so nothing is overwritten.
//
// Other: !info  !diag  !help  !keys (let go of keys the script pressed)  !inject on|off
//        !mark <demo> / !mark off   a friend's own demo just started / stopped (see above)
//
// How following works: your player is driven through your recording. The script presses
// the recorded keys through your own client (so it predicts your shots, sounds and view
// like it does when you play) and snaps your view to the recorded angles; if you drift from
// the recording, it puts you back. Don't touch the keyboard or mouse while following.

// ---- Settings ----------------------------------------------------------------

const SHOOTER_NAME = "ss_shooter"
const NEW_FREEZE = 66        // frozen this long before a new take (!go skips it)
const RUN_FREEZE = 20        // ... before a rewind's run-up, !play, !render, !spec
const RUNUP_TICKS = 66       // a rewind replays at least this much before you take over
const POSTROLL_TICKS = 33    // !play, !render and !spec go on this long after the scene ends
const MAX_VERSIONS = 24
const MAX_TRACKS = 8
const HIDE_Z = -16000.0      // where unused bots wait
const BIG_HP = 30000         // whoever takes the burst, during it, so they don't die of it
const PREVENT_DEATH = 70     // TF_COND_PREVENT_DEATH: a lethal hit leaves 1 HP instead
const NO_FALL_DAMAGE = true  // 24 explosions launch you very high
const DETONATOR = 351
const DMG_FALL = 32
const TEAM_SPECTATOR = 1
const TF_CLASS_PYRO = 7
const TICK = 0.015
const ALL_TICKS = -2147483647    // AddMod: the change shows on every tick
const PART_BYTES = 15000     // scripts can only read/write 16 KB per file
const DRIFT_POS = 0.5        // following: put you back if you're this far off (units)
const DRIFT_VEL = 4.0        //            or your velocity is this far off (units/s)
const PROJ_DRIFT = 1.0       // replayed projectiles: put back on their recorded path
const FLARE_DRIFT = 4.0
const DUCK_SHIFT = 20.0      // standing minus crouched hull height (crouching in the air)
const VKEY = "9999"          // key code for presses by the script: never releases your keys
const MOVETYPE_NONE = 0
const MOVETYPE_WALK = 2
const MOVETYPE_VPHYSICS = 6
const FL_ONGROUND = 1
const EFL_KILLME = 1

const IN_ATTACK = 1
const IN_JUMP = 2
const IN_DUCK = 4
const IN_FORWARD = 8
const IN_BACK = 16
const IN_MOVELEFT = 512
const IN_MOVERIGHT = 1024
const IN_ATTACK2 = 2048
const IN_RELOAD = 8192
const IN_ALT2 = 32768
const IN_ATTACK3 = 33554432
const WEAPON_BUTTONS = 33564673   // IN_ATTACK | IN_ATTACK2 | IN_RELOAD | IN_ATTACK3
const FORCE_BUTTONS = 33564679    // WEAPON_BUTTONS | IN_JUMP | IN_DUCK

// Frame layout: one frame per scene tick, the actor's state before that tick's commands
// (after the previous tick), plus the buttons and view angles of the previous tick's
// command. Flat array, STRIDE numbers per frame.
enum F {
    OX, OY, OZ, VX, VY, VZ, PITCH, YAW, VIEWZ, BUTTONS, SLOT, HP, FLAGS, DUCKED, AIRDASH,
    AIRDUCKS, NEXTATK, AMMO1, AMMO2,           // air crouches so far, weapon switch delay (s from now)
    C0, NA0, NB0, C1, NA1, NB1, C2, NA2, NB2,  // per weapon slot: clip, next primary/secondary (s from now)
    FX, FY, FZ, FVX, FVY, FVZ, FSTATE,         // the shooter's flare, if this track is its target
    DEMOID, DEMOTICK, REV                      // where this tick's footage is in a demo
}
const STRIDE = 38
// FSTATE: 0 no flare yet, 1 shooter's flare in flight, 2 reflected (waiting for the
// burst), 3 burst done / flare gone

// ---- State (survives re-running the script) -----------------------------------

if (!("SS" in getroottable()) || !("v" in ::SS) || ::SS.v != 5)
{
    if ("SS" in getroottable())
        printl("[stunt] the scene in memory is from an older version of this script; starting a new one")
    ::SS <- {
        v = 5
        tracks = []           // each with owner: the id of the human who plays it, or null
        liveOnly = null       // track names that go live on !new/!rw/!to; null: all
        group = 0             // versions pushed by one command undo together
        marks = {}            // player id -> { id, start }: a friend's own demo (!mark)
        idCache = {}, botKnown = {}, botAttach = {}, botWarned = {}
        shooter = null        // { pos = Vector, target = track name }
        det = null            // track whose actor has the Detonator (null: the shooter bot)
        detFlares = {}, detNoted = {}, burstTick = -1, meSeen = {}
        fireAt = 66, burst = 24, delay = 2, hpAfter = 0   // for new tracks
        run = null            // what's playing, see StartRun
        cursor = 0            // scene tick the bots show while nothing runs
        rev = 0               // goes up on every change to the scene
        mods = []             // { rev, track, from [, own] }: which ticks of which track changed
        versions = []         // { name, copy, g }, for !undo (copy null: there was no such track)
        redo = []             // what !undo replaced, for !redo
        liveDemo = null, liveId = -1, liveStart = 0.0, demoNames = [], demoOffset = 1
        inject = true, lat = -1          // keys through your client; lat -1 = not measured yet
        ticks = 0, masterTime = -1.0
        botSeen = {}, botAsked = {}, badSlot = {}
        flare = null, flareState = 0, burstAt = -1, playFlare = null
        projSeen = {}, projLive = [], projPlay = []
        injected = 0
        diag = { fromClock = 0, fromThinker = 0, errors = 0, lastError = "", lastErrorAt = -10.0, last = "" }
    }
}

// Bots this script asked for, kept even if the scene state is rebuilt, so they still get kicked.
if (!("SS_BOTS" in getroottable()))
    ::SS_BOTS <- {}

// Added later: give a scene already in memory these too.
foreach (k, v in { inTick = false, clockAt = -1.0, otherBurst = null, flareGun = null,
    burstVictim = null, fireNow = false, cps = [], runup = RUNUP_TICKS, idleK = 0, burstFlare = null,
    botActing = {}, cheatWarned = false })
    if (!(k in ::SS))
        ::SS[k] <- v

// ---- Helpers -----------------------------------------------------------------

function Me() { return GetListenServerHost() }

/** Everyone on the server who isn't a bot. */
function Humans()
{
    local list = []
    for (local i = 1; i <= MaxClients().tointeger(); i++)
    {
        local p = PlayerInstanceFromIndex(i)
        if (p != null && !p.IsFakeClient())
            list.append(p)
    }
    return list
}

/** Stays the same if they reconnect or rename (falls back to the name without Steam). */
function PlayerId(p)
{
    if (p in SS.idCache)
        return SS.idCache[p]
    local id = NetProps.GetPropString(p, "m_szNetworkIDString")
    if (id == "" || id == "STEAM_ID_PENDING" || id == "STEAM_ID_LAN" || id == "UNKNOWN")
        return "name:" + NetProps.GetPropString(p, "m_szNetname")
    SS.idCache[p] <- id
    return id
}

function PlayerById(id)
{
    foreach (h in Humans())
        if (PlayerId(h) == id)
            return h
    return null
}

// While a demo is recording, nothing from this script goes on screen (it would be in
// the demo); messages go to the console only.
/** p is recording a demo (the host's !demo/!render, or a friend's !mark): keep text off their screen. */
function QuietFor(p) { return p == Me() ? SS.liveDemo != null : (PlayerId(p) in SS.marks) }
function Quiet() { return Me() != null && QuietFor(Me()) }

function Say(msg)
{
    foreach (h in Humans())
    {
        if (!QuietFor(h))
            ClientPrint(h, Constants.EHudNotify.HUD_PRINTTALK, "\x07FFD700[stunt] \x01" + msg)
        else if (h != Me())
            ClientPrint(h, Constants.EHudNotify.HUD_PRINTCONSOLE, "[stunt] " + msg + "\n")
    }
    printl("[stunt] " + msg)
}

function Center(msg)
{
    foreach (h in Humans())
        if (!QuietFor(h))
            ClientPrint(h, Constants.EHudNotify.HUD_PRINTCENTER, msg)
}

function Max(a, b) { return a > b ? a : b }
function Min(a, b) { return a < b ? a : b }
function Clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }

function ToInt(s, def)
{
    if (s == null)
        return def
    try { return s.tointeger() } catch (e) { return def }
}

function ReportError(e)
{
    SS.diag.errors++
    SS.diag.lastError = "" + e
    if (Time() - SS.diag.lastErrorAt > 2.0)
    {
        SS.diag.lastErrorAt = Time()
        printl("[stunt] script error: " + e + "  (!diag)")
    }
}

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

function BotName(p) { return NetProps.GetPropString(p, "m_szNetname") }

function AnglesTo(from, to)
{
    local d = to - from
    local flat = sqrt(d.x * d.x + d.y * d.y)
    return QAngle(-atan2(d.z, flat) * 57.29578, atan2(d.y, d.x) * 57.29578, 0)
}

function EnemyTeam(team) { return team == 2 ? 3 : 2 }
function TeamName(team) { return team == 2 ? "red" : "blue" }

::CLASS_NAMES <- ["", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"]
function ClassName(c) { return c > 0 && c < CLASS_NAMES.len() ? CLASS_NAMES[c] : "pyro" }

function ValidName(n)
{
    if (n == null || n.len() == 0 || n.len() > 20 || n == SHOOTER_NAME)
        return false
    foreach (c in n)
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'))
            return false
    return true
}

/** "v12": a version number, not a name. */
function IsVersionName(n)
{
    if (n == null || n.len() < 2 || n[0] != 'v')
        return false
    foreach (i, c in n)
        if (i > 0 && (c < '0' || c > '9'))
            return false
    return true
}

/** How many ticks ahead a player's own game is: key latency for the host, ping for friends. */
function LeadTicks(a)
{
    if (a.host)
        return Lat()
    local pm = Entities.FindByClassname(null, "tf_player_manager")
    if (pm == null)
        return 0
    local ping = NetProps.GetPropIntArray(pm, "m_iPing", a.p.entindex())
    return Clamp((ping / 1000.0 / TICK + 0.5).tointeger(), 0, 20)
}

function PlayerNow(p) { return NetProps.GetPropInt(p, "m_nTickBase") * TICK }

function WeaponInSlot(p, slot)
{
    for (local i = 0; i < 8; i++)
    {
        local w = NetProps.GetPropEntityArray(p, "m_hMyWeapons", i)
        if (w != null && w.GetSlot() == slot)
            return w
    }
    return null
}

function ItemDef(w) { return NetProps.GetPropInt(w, "m_AttributeManager.m_Item.m_iItemDefinitionIndex") }

/** Give p the weapon (classname + item def), replacing whatever is in that slot. */
function GiveWeapon(p, cls, def)
{
    local w = Entities.CreateByClassname(cls)
    NetProps.SetPropInt(w, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", def)
    NetProps.SetPropBool(w, "m_AttributeManager.m_Item.m_bInitialized", true)
    NetProps.SetPropBool(w, "m_bValidatedAttachedEntity", true)
    w.SetTeam(p.GetTeam())
    Entities.DispatchSpawn(w)
    for (local i = 0; i < 8; i++)
    {
        local old = NetProps.GetPropEntityArray(p, "m_hMyWeapons", i)
        if (old != null && old.GetSlot() == w.GetSlot())
        {
            old.Destroy()
            NetProps.SetPropEntityArray(p, "m_hMyWeapons", null, i)
            break
        }
    }
    p.Weapon_Equip(w)
    return w
}

function Loadout(p)
{
    local weapons = []
    foreach (slot in [0, 1, 2])
    {
        local w = WeaponInSlot(p, slot)
        if (w != null)
            weapons.append({ slot = slot, cls = w.GetClassname(), def = ItemDef(w) })
    }
    return weapons
}

function SwitchTo(p, slot)
{
    if (slot < 0)
        return
    local w = WeaponInSlot(p, slot)
    if (w != null && p.GetActiveWeapon() != w)
        p.Weapon_Switch(w)
}

function Detonator(p)
{
    local w = WeaponInSlot(p, 1)
    if ((w == null || ItemDef(w) != DETONATOR) && !("det" in SS.badSlot))
    {
        w = GiveWeapon(p, "tf_weapon_flaregun", DETONATOR)
        if (w == null || ItemDef(w) != DETONATOR)
        {
            SS.badSlot["det"] <- true
            Say("Couldn't give the shooter its Detonator.")
        }
    }
    if (w != null && p.GetActiveWeapon() != w)
        p.Weapon_Switch(w)
    return w
}

function ViewZ(p)
{
    try { return NetProps.GetPropVector(p, "m_vecViewOffset").z } catch (e) { return 68.0 }
}

function KillProjectiles()
{
    local list = []
    for (local e = null; e = Entities.FindByClassname(e, "tf_projectile_*");)
        list.append(e)
    foreach (e in list)
        e.Kill()
}

/** Who fired it: rockets and flares have an owner, grenades a thrower. */
function ProjOwner(e)
{
    local o = e.GetOwner()
    if (o == null && NetProps.HasProp(e, "m_hThrower"))
        o = NetProps.GetPropEntity(e, "m_hThrower")
    return o
}

// ---- Tracks ------------------------------------------------------------------

function TrackByName(name)
{
    if (name == null)
        return null
    local lower = name.tolower()
    foreach (t in SS.tracks)
        if (t.name.tolower() == lower)
            return t
    return null
}

function TrackOfId(id)
{
    foreach (t in SS.tracks)
        if (t.owner == id)
            return t
    return null
}

function TrackOf(p) { return TrackOfId(PlayerId(p)) }
function OwnerPlayer(t) { return t.owner != null ? PlayerById(t.owner) : null }

/** A human acts this track out (false: it's a bot's). */
function HumanPlays(t, r)
{
    // In a run the cast is fixed: someone who rejoins or spawns mid-run joins the next one.
    if (r != null)
    {
        local a = ActorOfRun(r, t)
        return a != null && !a.out
    }
    local h = OwnerPlayer(t)
    return h != null && h.GetTeam() >= 2
}

function PlayerOfTrack(t, r) { return HumanPlays(t, r) ? OwnerPlayer(t) : FindBot(t.name) }

function ActorOf(p)
{
    if (SS.run != null)
        foreach (a in SS.run.actors)
            if (a.p == p)
                return a
    return null
}

function ActorOfTrack(t)
{
    if (SS.run != null)
        foreach (a in SS.run.actors)
            if (a.t == t)
                return a
    return null
}

function IsLiveTrack(t) { return SS.liveOnly == null || SS.liveOnly.find(t.name) != null }
function Frames(t) { return t.frames.len() / STRIDE }
function Fv(t, i, k) { return t.frames[i * STRIDE + k] }
function FrameAt(t, i) { return t.frames.slice(i * STRIDE, (i + 1) * STRIDE) }
function TrackEnd(t) { return t.start + Frames(t) - 1 }

function SceneStart()
{
    local s = null
    foreach (t in SS.tracks)
        if (!t.muted && Frames(t) > 0)
            s = s == null ? t.start : Min(s, t.start)
    return s == null ? 0 : s
}

function SceneEnd()
{
    local e = null
    foreach (t in SS.tracks)
        if (!t.muted && Frames(t) > 0)
            e = e == null ? TrackEnd(t) : Max(e, TrackEnd(t))
    return e == null ? 0 : e
}

/** The latest event of that type at or before frame k. */
function LastEvent(t, type, k)
{
    local found = null
    foreach (e in t.events)
        if (e.type == type && e.t <= k && (found == null || e.t >= found.t))
            found = e
    return found
}

function FindEvent(t, type)
{
    foreach (e in t.events)
        if (e.type == type)
            return e
    return null
}

function NewTrack(name, p, team)
{
    return {
        name = name, owner = PlayerId(p), team = team, cls = p.GetPlayerClass(), weapons = Loadout(p),
        start = 0, frames = [], events = [], projs = [], muted = false,
        fireAt = SS.fireAt, burst = SS.burst, delay = SS.delay, hpAfter = SS.hpAfter
    }
}

function CopyTrack(t)
{
    local c = {}
    foreach (k, v in t)
        c[k] <- v
    c.frames = t.frames.slice(0)
    c.events = t.events.slice(0)
    c.weapons = t.weapons.slice(0)
    c.projs = []
    foreach (p in t.projs)
        c.projs.append({ spawn = p.spawn, cls = p.cls, path = p.path.slice(0) })
    return c
}

/** Keep a copy of track t as it is now, for !undo. Any new change ends what !redo can do. */
function PushVersion(t)
{
    if (t == null)
        return
    SS.versions.append({ name = t.name, copy = CopyTrack(t), g = SS.group, det = SS.det == t.name })
    TrimVersions()
    SS.redo = []
}

/** Over the limit: drop the oldest command's versions, all of them. */
function TrimVersions()
{
    while (SS.versions.len() > MAX_VERSIONS)
    {
        local g = SS.versions[0].g
        while (SS.versions.len() > 1 && SS.versions[0].g == g)
            SS.versions.remove(0)
        if (SS.versions.len() > 0 && SS.versions[0].g == g)
            SS.versions.remove(0)
    }
}

function ReplaceTrack(t)
{
    foreach (i, old in SS.tracks)
    {
        if (old.name == t.name)
        {
            SS.tracks[i] = t
            return
        }
    }
    SS.tracks.append(t)
}

/** Make track `name` be t (null: no such track). */
function PutTrack(name, t)
{
    local cur = TrackByName(name)
    if (t == null)
    {
        foreach (i, x in SS.tracks)
        {
            if (x.name == name)
            {
                SS.tracks.remove(i)
                break
            }
        }
    }
    else
    {
        // Who plays what isn't part of the undo, unless the track was gone and its
        // player hasn't got another one.
        if (cur != null)
            t.owner = cur.owner
        else if (t.owner != null && TrackOfId(t.owner) != null)
            t.owner = null
        ReplaceTrack(t)
    }
    if (SS.det == name && t == null)
        SS.det = null
    AddMod(name, ALL_TICKS)
    Housekeep()
}

/** Something changed in track `name` from scene tick `from` on. */
function AddMod(name, from)
{
    SS.rev++
    SS.mods.append({ rev = SS.rev, track = name, from = from })
    if (SS.mods.len() > 5000)
        SS.mods.remove(0)
}

function DefaultName(p)
{
    local stem = ClassName(p.GetPlayerClass())
    if (stem == "heavyweapons")
        stem = "heavy"
    local name = stem
    for (local i = 2; TrackByName(name) != null; i++)
        name = stem + i
    return name
}

function AddTrack(name, p, team)
{
    if (SS.tracks.len() >= MAX_TRACKS)
    {
        Say("That's " + MAX_TRACKS + " tracks already; !del one first.")
        return null
    }
    local t = NewTrack(name, p, team)
    SS.tracks.append(t)
    return t
}

/** Tell the user which recorded actors can't hurt or push track t's actor. */
function WarnTeams(t)
{
    foreach (o in SS.tracks)
        if (o != t && !o.muted && Frames(o) > 0 && o.team == t.team)
            Say(format("\x07FF4040%s is on your team too\x01: you can't hurt or push each other. !track %s %s switches you.",
                o.name, t.name, TeamName(EnemyTeam(t.team))))
}

/** Cut a track off at its frame k: frames, events and projectiles from k on go. */
function Truncate(t, k)
{
    t.frames = t.frames.slice(0, Clamp(k * STRIDE, 0, t.frames.len()))
    local ev = []
    foreach (e in t.events)
        if (e.t < k)
            ev.append(e)
    t.events = ev
    local pr = []
    foreach (p in t.projs)
    {
        if (p.spawn >= k - 1)
            continue                          // no path samples before tick k
        local keep = (k - p.spawn - 1) * 6
        if (keep < p.path.len())
            p.path = p.path.slice(0, keep)
        pr.append(p)
    }
    t.projs = pr
}

// ---- Capture / restore -------------------------------------------------------

/** p's state now (the start of a tick), as a frame. */
function Capture(p)
{
    local o = p.GetOrigin()
    local v = p.GetAbsVelocity()
    local a = p.EyeAngles()
    local w = p.GetActiveWeapon()
    local now = PlayerNow(p)
    local f = [
        o.x, o.y, o.z, v.x, v.y, v.z, a.x, a.y, ViewZ(p),
        NetProps.GetPropInt(p, "m_nButtons"),
        w != null ? w.GetSlot() : -1,
        p.GetHealth(),
        NetProps.GetPropInt(p, "m_fFlags"),
        NetProps.GetPropBool(p, "m_Local.m_bDucked") ? 1 : 0,
        NetProps.GetPropInt(p, "m_Shared.m_iAirDash"),
        NetProps.GetPropInt(p, "m_Shared.m_nAirDucked"),
        NetProps.GetPropFloat(p, "m_flNextAttack") - now,
        NetProps.GetPropIntArray(p, "m_iAmmo", 1),
        NetProps.GetPropIntArray(p, "m_iAmmo", 2)
    ]
    for (local slot = 0; slot < 3; slot++)
    {
        local ws = WeaponInSlot(p, slot)
        if (ws != null)
            f.extend([ws.Clip1(), NetProps.GetPropFloat(ws, "m_flNextPrimaryAttack") - now,
                NetProps.GetPropFloat(ws, "m_flNextSecondaryAttack") - now])
        else
            f.extend([0, 0.0, 0.0])
    }
    local fo = Vector(), fv = Vector()
    if (SS.flare != null && SS.flare.IsValid())
    {
        fo = SS.flare.GetOrigin()
        fv = SS.flare.GetAbsVelocity()
    }
    f.extend([fo.x, fo.y, fo.z, fv.x, fv.y, fv.z, SS.flareState, -1, -1, SS.rev])
    return f
}

/** Clips, cooldowns, weapon switch delay and ammo from frame f, `now` being p's clock. */
function WeaponState(p, f, now)
{
    for (local slot = 0; slot < 3; slot++)
    {
        local w = WeaponInSlot(p, slot)
        if (w == null)
            continue
        local c = f[F.C0 + slot * 3]
        if (c >= 0)
            w.SetClip1(c)
        NetProps.SetPropFloat(w, "m_flNextPrimaryAttack", now + f[F.NA0 + slot * 3])
        NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", now + f[F.NB0 + slot * 3])
    }
    NetProps.SetPropFloat(p, "m_flNextAttack", now + f[F.NEXTATK])
    NetProps.SetPropIntArray(p, "m_iAmmo", f[F.AMMO1], 1)
    NetProps.SetPropIntArray(p, "m_iAmmo", f[F.AMMO2], 2)
}

/** Scout double jumps and TF2's limit on crouching in the air. */
function MoveState(p, f)
{
    NetProps.SetPropInt(p, "m_Shared.m_iAirDash", f[F.AIRDASH])
    NetProps.SetPropInt(p, "m_Shared.m_nAirDucked", f[F.AIRDUCKS])
}

/** Put p exactly into the state of frame f. */
function Restore(p, f, withVelocity)
{
    local ang = QAngle(f[F.PITCH], f[F.YAW], 0)
    local vel = withVelocity ? Vector(f[F.VX], f[F.VY], f[F.VZ]) : Vector()
    p.Teleport(true, Vector(f[F.OX], f[F.OY], f[F.OZ]), true, QAngle(0, f[F.YAW], 0), true, vel)
    p.SnapEyeAngles(ang)
    SwitchTo(p, f[F.SLOT])
    p.SetHealth(f[F.HP])
    MoveState(p, f)
    WeaponState(p, f, PlayerNow(p))
}

/** Keep you frozen in frame f: no shooting, crouched if f is, can't die. */
function HoldMe(a, f)
{
    local p = a.p
    Restore(p, f, false)
    p.AddCond(PREVENT_DEATH)
    if (!a.host)
        p.SetMoveType(MOVETYPE_NONE, 0)     // their client can't predict being held
    NetProps.SetPropInt(p, "m_afButtonForced", f[F.DUCKED] != 0 ? IN_DUCK : 0)
    NetProps.SetPropInt(p, "m_afButtonDisabled", WEAPON_BUTTONS)
}

function FreeMe(me)
{
    NetProps.SetPropInt(me, "m_afButtonForced", 0)
    NetProps.SetPropInt(me, "m_afButtonDisabled", 0)
    if (me.GetMoveType() == MOVETYPE_NONE)
        me.SetMoveType(MOVETYPE_WALK, 0)
    if (me.InCond(PREVENT_DEATH))
        me.RemoveCond(PREVENT_DEATH)
}

// ---- Keys through your client --------------------------------------------------
//
// `+forward 9999` presses forward as if key #9999 went down, so `-forward 9999` lets
// go of exactly that press; your own keys are separate presses and stay down.

::KEYS <- [
    [IN_FORWARD, "forward"], [IN_BACK, "back"], [IN_MOVELEFT, "moveleft"], [IN_MOVERIGHT, "moveright"],
    [IN_JUMP, "jump"], [IN_DUCK, "duck"], [IN_ATTACK, "attack"], [IN_ATTACK2, "attack2"],
    [IN_ATTACK3, "attack3"], [IN_RELOAD, "reload"]
]
const INJECT_MASK = 33566239   // all of the above

function SetKeys(want)
{
    local have = SS.injected
    if (want == have)
        return
    local cmd = ""
    foreach (k in KEYS)
    {
        local on = (want & k[0]) != 0
        if (on != ((have & k[0]) != 0))
            cmd += (on ? "+" : "-") + k[1] + " " + VKEY + ";"
    }
    SS.injected = want
    SendToConsole(cmd)
}

function ReleaseKeys() { SetKeys(0) }

/** Ticks between pressing a key from here and the server running the command with it. */
function Lat() { return SS.lat >= 0 ? SS.lat : 1 }

/** Hold the keys of track tr's command on scene tick u (if you'll be following then). */
function InjectFor(tr, u, r, a)
{
    local want = 0
    if (SS.inject && SS.lat >= 0 && tr != null && (r.p == null || !a.want || u < r.p))
    {
        local j = u - tr.start + 1
        if (j >= 1 && j < Frames(tr))
            want = Fv(tr, j, F.BUTTONS) & INJECT_MASK
    }
    SetKeys(want)
}

/** Measure Lat(): press a key that does nothing in TF2 and see when it arrives. */
function Probe(me, r)
{
    if (!SS.inject || SS.lat >= 0 || r.spec != null)
        return
    if (r.probeAt < 0)
    {
        SendToConsole("+alt2 " + VKEY)
        r.probeAt = SS.ticks
        return
    }
    if (r.probeAt == 0x7fffffff)
        return
    local d = SS.ticks - r.probeAt
    if (NetProps.GetPropInt(me, "m_nButtons") & IN_ALT2)
    {
        SendToConsole("-alt2 " + VKEY)
        SS.lat = Max(0, d - 1)
        r.probeAt = 0x7fffffff
        printl("[stunt] key latency " + SS.lat + " tick(s)")
    }
    else if (d > 15)
    {
        SendToConsole("-alt2 " + VKEY)
        SS.inject = false
        r.probeAt = 0x7fffffff
        Say("Keys sent to your client never arrived, so following won't predict your shots (!inject on to retry).")
    }
}

// ---- Shooter -----------------------------------------------------------------

function Shooter() { return FindBot(SHOOTER_NAME) }

function ShooterTargetPlayer()
{
    if (SS.shooter == null)
        return null
    local t = TrackByName(SS.shooter.target)
    return t != null ? PlayerOfTrack(t, SS.run) : null
}

/** The shooter's own think: stand at its spot, aim at its target. */
function ShooterStep(bot)
{
    if (SS.shooter == null || SS.det != null)
    {
        Park(bot)
        return
    }
    local t = TrackByName(SS.shooter.target)
    local team = t != null ? EnemyTeam(t.team) : 3
    if (bot.GetTeam() != team)
    {
        bot.ForceChangeTeam(team, true)
        return
    }
    if (!bot.IsAlive())
    {
        bot.ForceRespawn()
        return
    }
    if (bot.GetPlayerClass() != TF_CLASS_PYRO)
    {
        bot.SetPlayerClass(TF_CLASS_PYRO)
        NetProps.SetPropInt(bot, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_PYRO)
        bot.ForceRegenerateAndRespawn()
        return
    }
    Detonator(bot)
    bot.SetHealth(bot.GetMaxHealth())
    bot.AddCond(PREVENT_DEATH)
    if (bot.GetMoveType() != MOVETYPE_NONE)
        bot.SetMoveType(MOVETYPE_NONE, 0)
    local pos = SS.shooter.pos
    local target = ShooterTargetPlayer()
    local ang = target != null ? AnglesTo(pos + Vector(0, 0, 68), target.GetCenter()) : bot.EyeAngles()
    if ((bot.GetOrigin() - pos).Length() > 1.0)
        bot.Teleport(true, pos, true, QAngle(0, ang.y, 0), true, Vector())
    else
        bot.SetAbsVelocity(Vector())
    bot.SnapEyeAngles(ang)
    NetProps.SetPropInt(bot, "m_afButtonForced", 0)
    SS.botActing[SHOOTER_NAME] <- Time()
}

/** Fire one flare from the shooter with these angles; returns it. */
function FireFlare(ang)
{
    local s = Shooter()
    if (s == null || !s.IsAlive() || SS.shooter == null)
        return null
    s.Teleport(true, SS.shooter.pos, true, QAngle(0, ang.y, 0), true, Vector())
    s.SnapEyeAngles(ang)
    local det = Detonator(s)
    SS.flareGun = det
    local before = {}
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        before[f] <- true
    NetProps.SetPropIntArray(s, "m_iAmmo", 16, det.GetPrimaryAmmoType())
    NetProps.SetPropFloat(det, "m_flNextPrimaryAttack", 0.0)
    NetProps.SetPropFloat(s, "m_flNextAttack", 0.0)
    det.PrimaryAttack()
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        if (!(f in before) && f.GetOwner() == s)
            return f
    return null
}

/** The bug: n detonations of the shooter's (reflected) flare in this one tick. */
function Burst(victim, n, hpAfter)
{
    local s = Shooter()
    if (s == null || victim == null)
        return
    local det = Detonator(s)
    if (SS.flareGun != null && det != SS.flareGun)
        printl("[stunt] the shooter's Detonator was replaced (respawn or resupply) since it fired: no burst")
    BurstWith(det, victim, n, hpAfter)
}

function BurstWith(det, victim, n, hpAfter)
{
    local hp = victim.GetHealth()
    for (local i = 0; i < n && victim.IsAlive(); i++)
    {
        victim.SetHealth(BIG_HP)
        det.SecondaryAttack()
    }
    if (victim.IsAlive())
        victim.SetHealth(hpAfter > 0 ? hpAfter : hp)
}

/** The recorded airblast missed this time: do what the reflect does for the bug. */
function ForceDeflect(victim)
{
    local fl = SS.playFlare
    if (fl == null || !fl.IsValid() || fl.GetOwner() == victim)
        return
    fl.SetOwner(victim)
    fl.SetTeam(victim.GetTeam())
    // A real reflect makes the reflector's weapon the flare's launcher; the burst's
    // self-damage (and so its push) comes from that weapon.
    local w = victim.GetActiveWeapon()
    if (w == null)
        w = WeaponInSlot(victim, 0)
    if (w != null)
        NetProps.SetPropEntity(fl, "m_hLauncher", w)
    NetProps.SetPropInt(fl, "m_iDeflected", Min(15, NetProps.GetPropInt(fl, "m_iDeflected") + 1))
    printl("[stunt] forced the reflect")
}

/** Shooter events of its target track on scene tick s. */
function ShooterTick(s, r)
{
    if (SS.shooter == null || SS.det != null)
        return
    local t = TrackByName(SS.shooter.target)
    if (t == null || t.muted)
    {
        if (SS.fireNow)
            Say("The shooter's target track is muted or gone (!shooter <track> retargets it).")
        SS.fireNow = false
        return
    }
    local k = s - t.start
    local actor = ActorOfTrack(t)
    if (actor != null && actor.live)
    {
        LiveShooter(actor.p, t, k)
        return
    }
    if (SS.fireNow)
    {
        SS.fireNow = false
        Say("Not now: " + t.name + " is replaying its recording, so the shooter does what it did then.")
    }
    local victim = PlayerOfTrack(t, r)
    if (victim == null || !victim.IsAlive())
        return
    // Fire and reflect first, then the flare goes where it was recorded, then the burst
    // (so a missed replayed airblast still bursts in the right place).
    local fired = false
    local bursts = []
    foreach (e in t.events)
    {
        if (e.t != k)
            continue
        local v = victim
        if ("by" in e)
        {
            local bt = TrackByName(e.by)
            v = bt != null ? PlayerOfTrack(bt, r) : null
        }
        if (e.type == "fire")
        {
            local fl = FireFlare(e.ang)
            if (fl != null)
            {
                if (SS.playFlare != null && SS.playFlare.IsValid())
                    SS.playFlare.Kill()
                SS.playFlare = fl
            }
            fired = true
        }
        else if (e.type == "deflect" && v != null)
            ForceDeflect(v)
        else if (e.type == "burst" && v != null)
            bursts.append({ v = v, n = e.n })
    }
    if (!fired && k >= 0 && k < Frames(t))
    {
        local st = Fv(t, k, F.FSTATE)
        local fl = SS.playFlare
        if ((st == 1 || st == 2) && fl != null && fl.IsValid() && !(NetProps.GetPropInt(fl, "m_iEFlags") & EFL_KILLME))
        {
            local want = Vector(Fv(t, k, F.FX), Fv(t, k, F.FY), Fv(t, k, F.FZ))
            if (bursts.len() > 0 || (fl.GetOrigin() - want).Length() > FLARE_DRIFT)
            {
                fl.SetAbsOrigin(want)
                fl.SetAbsVelocity(Vector(Fv(t, k, F.FVX), Fv(t, k, F.FVY), Fv(t, k, F.FVZ)))
            }
        }
    }
    foreach (b in bursts)
        if (b.v.IsAlive())
            Burst(b.v, b.n, 0)
    OtherReflects(s, r, t)
}

/** While the shooter's target replays, a different player reflecting its flare live still
 *  gets the burst; it's recorded on their own track ("sburst"), and replays of that track
 *  burst it again. */
function OtherReflects(s, r, t)
{
    // Replays of other tracks' bursts.
    foreach (o in SS.tracks)
    {
        local oa = ActorOfTrack(o)
        if (o == t || o.muted || (oa != null && oa.live))
            continue
        foreach (e in o.events)
        {
            if (e.t != s - o.start || e.type != "sburst")
                continue
            local v = PlayerOfTrack(o, r)
            local fl = SS.playFlare
            if (v != null && v.IsAlive() && fl != null && fl.IsValid())
            {
                if (fl.GetOwner() != v)
                    ForceDeflect(v)
                Burst(v, e.n, 0)
            }
        }
    }
    // Live.
    local fl = SS.playFlare
    if (SS.otherBurst == null && fl != null && fl.IsValid())
    {
        local o = fl.GetOwner()
        local oa = o != null && o.IsPlayer() && !o.IsFakeClient() ? ActorOf(o) : null
        if (oa != null && oa.live && oa.t != t)
        {
            SS.otherBurst = { a = oa, at = s - 1 + Max(1, t.delay) }
            Say(BotName(o) + " reflected it.")
        }
    }
    local ob = SS.otherBurst
    if (ob != null && s >= ob.at)
    {
        SS.otherBurst = null
        if (ob.a.live && ob.a.p.IsValid() && ob.a.p.IsAlive())
        {
            Burst(ob.a.p, t.burst, t.hpAfter)
            ob.a.t.events.append({ t = s - ob.a.t.start, type = "sburst", n = t.burst })
        }
    }
}

/** Someone plays the shooter's target live (record: a take is recording it; otherwise
 *  it's practice between takes). Fires on its tick in a new take and on !fire, catches
 *  the reflect and bursts it. This runs just before the commands of tick k, so an
 *  airblast in the command of tick k-1 shows up here; the burst comes `delay` ticks
 *  after that airblast. */
function LiveShooter(me, t, k, record = true)
{
    local manual = SS.fireNow
    SS.fireNow = false
    local auto = record && t.fireAt >= 0 && SS.flareState == 0 && k >= t.fireAt && FindEvent(t, "fire") == null
    if (manual || auto)
    {
        local old = SS.flare
        local ang = AnglesTo(SS.shooter.pos + Vector(0, 0, 68), me.GetCenter())
        local fl = FireFlare(ang)
        if (fl != null)
        {
            // A new flare replaces one still around.
            if (old != null && old.IsValid())
                old.Kill()
            if (record)
                t.events.append({ t = k, type = "fire", ang = ang })
            SS.flare = fl
            SS.flareState = 1
            SS.burstVictim = null
        }
        else if (manual)
            Say("The shooter bot isn't ready yet; try again in a moment.")
    }
    // Reflected by someone playing live (the target, or anyone else live).
    if (SS.flareState == 1 && SS.flare != null && SS.flare.IsValid())
    {
        local o = SS.flare.GetOwner()
        if (o != null && o != Shooter() && o.IsPlayer() && !o.IsFakeClient() && (!record || ActorLive(o)))
        {
            SS.flareState = 2
            SS.burstVictim = o
            if (record)
            {
                local e = { t = k, type = "deflect" }
                local ot = TrackOf(o)
                if (o != me && ot != null)
                    e.by <- ot.name
                t.events.append(e)
            }
            SS.burstAt = k - 1 + Max(1, t.delay)
            if (o != me)
                Say(BotName(o) + " reflected it.")
        }
    }
    if (SS.flareState == 2 && k >= SS.burstAt)
    {
        local victim = SS.burstVictim != null && SS.burstVictim.IsValid() ? SS.burstVictim : me
        Burst(victim, t.burst, t.hpAfter)
        if (record)
        {
            local e = { t = k, type = "burst", n = t.burst }
            local vt = TrackOf(victim)
            if (victim != me && vt != null)
                e.by <- vt.name
            t.events.append(e)
        }
        SS.flareState = 3
    }
    if (SS.flareState == 1 && (SS.flare == null || !SS.flare.IsValid()))
        SS.flareState = 3   // missed: it hit something
}

function ActorLive(p)
{
    local a = ActorOf(p)
    return a != null && a.live
}

/** Between takes: the shooter still fires on !fire at whoever plays its target. */
function IdleShooter()
{
    if (SS.shooter == null || SS.det != null)
    {
        SS.fireNow = false
        return
    }
    local t = TrackByName(SS.shooter.target)
    local p = t != null && !t.muted ? PlayerOfTrack(t, null) : null
    if (p == null || p.IsFakeClient() || !p.IsAlive())
    {
        if (SS.fireNow)
            Say("The shooter only fires at a player who is in the game and plays its target track (!shooter <track> retargets it).")
        SS.fireNow = false
        return
    }
    SS.idleK++
    LiveShooter(p, t, SS.idleK, false)
}

// ---- An actor with the Detonator (!det) ----------------------------------------

function DetWeapon(p)
{
    local w = WeaponInSlot(p, 1)
    return w != null && ItemDef(w) == DETONATOR ? w : null
}

/** The actor has to hold a Detonator when recording: give it to a Pyro who hasn't got one. */
function EnsureDet(p, t)
{
    if (SS.det != t.name || DetWeapon(p) != null)
        return
    if (p.GetPlayerClass() == TF_CLASS_PYRO)
        GiveWeapon(p, "tf_weapon_flaregun", DETONATOR)
    else
        Say("\x07FF4040You're not a Pyro\x01, so you can't have the Detonator.")
}

function NoteDetFlares(owner)
{
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
        if (f.GetOwner() == owner)
            SS.detFlares[f] <- true
}

/** A flare of `owner` still flying: reflected (someone else owns it now) or not. */
function DetFlare(owner, reflected)
{
    foreach (f, _v in SS.detFlares)
    {
        if (!f.IsValid() || (NetProps.GetPropInt(f, "m_iEFlags") & EFL_KILLME))
            continue
        local o = f.GetOwner()
        if (o != null && (o != owner) == reflected)
            return f
    }
    return null
}

/** The bug: `owner` presses M2 with a flare of theirs reflected. Their own detonation of
 *  this tick still runs after this, so OnTakeDamage drops that one (see burstTick). */
function DetBurst(owner, t)
{
    if (SS.burstTick == SS.ticks)
        return
    local fl = DetFlare(owner, true)
    local w = DetWeapon(owner)
    if (fl == null || w == null)
        return
    // Remember the reflect for replays: it may have come this same tick, so DetTick
    // never saw it.
    local r = SS.run
    local ref = fl.GetOwner()
    local ra = ActorOf(ref)
    if (r != null && r.started && ra != null && ra.live && !(fl in SS.detNoted))
    {
        SS.detNoted[fl] <- true
        ra.t.events.append(ReflectEvent(r.s - ra.t.start, fl))
    }
    BurstWith(w, ref, t.burst, t.hpAfter)
    SS.burstTick = SS.ticks
    SS.burstFlare = fl
}


function ReflectEvent(k, fl)
{
    local o = fl.GetOrigin(), v = fl.GetAbsVelocity()
    return { t = k, type = "detreflect", px = o.x, py = o.y, pz = o.z, vx = v.x, vy = v.y, vz = v.z }
}

/** Scene tick s with an actor holding the Detonator. */
function DetTick(s, r)
{
    local t = TrackByName(SS.det)
    if (t == null || t.muted)
        return
    local owner = PlayerOfTrack(t, r)
    if (owner == null || !owner.IsAlive())
        return
    NoteDetFlares(owner)
    // A recorded reflect that missed this time.
    foreach (o in SS.tracks)
    {
        local oa = ActorOfTrack(o)
        if (o == t || o.muted || (oa != null && oa.live))
            continue
        foreach (e in o.events)
        {
            if (e.t != s - o.start || e.type != "detreflect")
                continue
            local victim = PlayerOfTrack(o, r)
            local done = DetFlare(owner, true)
            if (victim == null || (done != null && done.GetOwner() == victim))
                continue                  // the replayed airblast got it
            local fl = DetFlare(owner, false)
            if (fl != null)
            {
                SS.playFlare = fl
                ForceDeflect(victim)
                if ("px" in e)
                {
                    fl.SetAbsOrigin(Vector(e.px, e.py, e.pz))
                    fl.SetAbsVelocity(Vector(e.vx, e.vy, e.vz))
                }
            }
        }
    }
    // Someone reflects it live.
    foreach (a in r.actors)
    {
        if (!a.live || a.t == t)
            continue
        local fl = DetFlare(owner, true)
        if (fl != null && fl.GetOwner() == a.p && !(fl in SS.detNoted))
        {
            SS.detNoted[fl] <- true
            a.t.events.append(ReflectEvent(s - a.t.start, fl))
        }
    }
    // Their recorded M2 (live, it's their own think below).
    local oa = ActorOfTrack(t)
    if (oa == null || !oa.live)
    {
        local j = s - t.start + 1
        if (j >= 1 && j < Frames(t) && (Fv(t, j, F.BUTTONS) & IN_ATTACK2) && Fv(t, j, F.SLOT) == 1)
            DetBurst(owner, t)
    }
}

/** Runs inside each of your commands, before your weapon does: your M2 is the burst. */
function SS_MeThink()
{
    try
    {
        SS.meSeen[PlayerId(self)] <- SS.ticks
        local r = SS.run
        local a = ActorOf(self)
        if (a != null)
        {
            // Everything this tick's commands pressed, even with two commands in one tick.
            a.btn = (a.btn != null ? a.btn : 0) | NetProps.GetPropInt(self, "m_nButtons")
            if (r.started && !a.live && !a.out)
                FollowCmd(a, r.s)
        }
        local t = TrackOf(self)
        if (t != null && t.name == SS.det && (r == null || (a != null && a.live)))
        {
            NoteDetFlares(self)
            if ((NetProps.GetPropInt(self, "m_nButtons") & IN_ATTACK2) && self.GetActiveWeapon() == DetWeapon(self))
                DetBurst(self, t)
        }
    }
    catch (e)
        ReportError(e)
    return -1
}

function SetDet(arg, who)
{
    if (arg == null)
    {
        Say("The Detonator is with " + (SS.det != null ? SS.det : "the shooter bot") + ". !det <track>, !det me, !det bot.")
        return
    }
    EndRun(true)
    local name = null
    if (arg == "me")
    {
        local a = TrackOf(who)
        if (a == null)
        {
            a = AddTrack(DefaultName(who), who, who.GetTeam() >= 2 ? who.GetTeam() : 2)
            if (a == null)
                return
            SS.versions.append({ name = a.name, copy = null, g = SS.group })
            TrimVersions()
        }
        name = a.name
    }
    else if (arg != "bot")
    {
        if (TrackByName(arg) == null)
        {
            Say("No track " + arg + " (!tracks).")
            return
        }
        name = arg
    }
    SS.det = name
    AddMod(SHOOTER_NAME, ALL_TICKS)
    Housekeep()
    if (name != null)
    {
        local dt = TrackByName(name)
        local h = OwnerPlayer(dt)
        if (h != null && h.IsAlive())
            EnsureDet(h, dt)
    }
    if (name == null)
        Say("The shooter bot has the Detonator again.")
    else
        Say(name + " has the Detonator: M1 fires, M2 with a reflected flare is the burst (" + TrackByName(name).burst + ").")
}

// ---- Bots acting out tracks ----------------------------------------------------

function Park(bot)
{
    if (bot.GetMoveType() != MOVETYPE_NONE)
        bot.SetMoveType(MOVETYPE_NONE, 0)
    local spot = Vector(0, 0, HIDE_Z)
    if ((bot.GetOrigin() - spot).Length() > 1.0)
        bot.Teleport(true, spot, false, QAngle(), true, Vector())
    NetProps.SetPropInt(bot, "m_afButtonForced", 0)
    if (bot.IsAlive())
    {
        bot.SetHealth(bot.GetMaxHealth())
        bot.AddCond(PREVENT_DEATH)
    }
}

/** Right team, class and the weapon for `slot`; false while it respawns. */
function BotReady(bot, t, slot)
{
    if (bot.GetTeam() != t.team)
    {
        bot.ForceChangeTeam(t.team, true)
        return false
    }
    if (bot.GetPlayerClass() != t.cls)
    {
        bot.SetPlayerClass(t.cls)
        NetProps.SetPropInt(bot, "m_Shared.m_iDesiredPlayerClass", t.cls)
        bot.ForceRegenerateAndRespawn()
        return false
    }
    if (!bot.IsAlive())
    {
        bot.ForceRespawn()
        return false
    }
    foreach (w in t.weapons)
    {
        if (w.slot != slot)
            continue
        local have = WeaponInSlot(bot, slot)
        if (have != null && ItemDef(have) == w.def && have.GetClassname() == w.cls)
            break
        local key = t.name + ":" + slot + ":" + w.def
        if (key in SS.badSlot)
            break
        GiveWeapon(bot, w.cls, w.def)
        have = WeaponInSlot(bot, slot)
        if (have == null || ItemDef(have) != w.def)
        {
            SS.badSlot[key] <- true
            Say(format("Couldn't give %s's bot its %s (item %d).", t.name, w.cls, w.def))
        }
        break
    }
    return true
}

/** A bot's own think (inside its command, before it moves and shoots). */
function BotStep(bot)
{
    local name = BotName(bot)
    if (name == SHOOTER_NAME)
    {
        ShooterStep(bot)
        return
    }
    local t = TrackByName(name)
    local r = SS.run
    if (t == null || t.muted || Frames(t) == 0 || HumanPlays(t, r))
    {
        Park(bot)
        return
    }
    local n = Frames(t)
    // Scene tick being shown, and the one the bot's next command belongs to.
    local s = SS.cursor
    local nextCmd = null
    local active = false
    if (r != null)
    {
        if (r.started)
        {
            s = r.s
            nextCmd = r.s + 1
            active = true
        }
        else
        {
            s = r.a - 1
            if (r.freeze == 0)
                nextCmd = r.a
        }
    }
    local i = Clamp(s - t.start + 1, 0, n - 1)     // its state after tick s
    if (!BotReady(bot, t, Fv(t, i, F.SLOT)))
        return
    local f = FrameAt(t, i)
    ActFrame(bot, t, s, f, active, Time())
    SS.botActing[name] <- Time()
    local next = f[F.DUCKED] != 0 ? IN_DUCK : 0
    if (nextCmd != null)
    {
        local j = nextCmd - t.start + 1
        if (j >= 1 && j < n)
            next = Fv(t, j, F.BUTTONS) & FORCE_BUTTONS
        else if (j >= n)
            next = Fv(t, n - 1, F.BUTTONS) & IN_DUCK
        else
            next = Fv(t, 0, F.DUCKED) != 0 ? IN_DUCK : 0
    }
    NetProps.SetPropInt(bot, "m_afButtonForced", next)
}

/** Put p (a bot, or a friend being replayed) into track t's frame f, the state after
 *  scene tick s. This runs inside p's command for tick s, before it moves and shoots. */
function ActFrame(p, t, s, f, active, now)
{
    local n = Frames(t)
    local pre = FrameAt(t, Clamp(s - t.start, 0, n - 1))   // the state before it
    local pos = Vector(f[F.OX], f[F.OY], f[F.OZ])
    local moving = active && s - t.start + 1 >= 0 && s - t.start + 1 < n
    local vel = moving ? Vector(f[F.VX], f[F.VY], f[F.VZ]) : Vector()
    // Crouching or standing up in the air moves the feet, and its own move this tick
    // will do that; only expected if it matched the actor before this tick.
    local ducked = NetProps.GetPropBool(p, "m_Local.m_bDucked")
    if (moving && !(f[F.FLAGS] & FL_ONGROUND) && ducked == (pre[F.DUCKED] != 0) && (f[F.DUCKED] != 0) != ducked)
        pos.z += f[F.DUCKED] != 0 ? -DUCK_SHIFT : DUCK_SHIFT
    if (p.GetMoveType() != MOVETYPE_NONE)
        p.SetMoveType(MOVETYPE_NONE, 0)
    // Teleport only when it's off its path (Teleport turns off interpolation).
    if ((p.GetOrigin() - pos).Length() > 64.0 + vel.Length() * TICK * 2.0)
        p.Teleport(true, pos, false, QAngle(), true, vel)
    else
    {
        p.SetAbsOrigin(pos)
        p.SetAbsVelocity(vel)
    }
    p.SnapEyeAngles(QAngle(f[F.PITCH], f[F.YAW], 0))
    // Health, weapons and movement limits as they were when this tick's command ran
    // (its buttons are already in); a hit recorded in this tick lands on top of that.
    p.SetHealth(Max(1, pre[F.HP]))
    p.AddCond(PREVENT_DEATH)
    SwitchTo(p, pre[F.SLOT])     // undo a switch they made themselves
    MoveState(p, pre)
    WeaponState(p, pre, now)
    // Switch after that, so the switch delays this command like it did the actor's.
    SwitchTo(p, f[F.SLOT])
}

// ---- Projectiles ---------------------------------------------------------------
//
// Every projectile you fire live is recorded tick by tick (track.projs: spawn tick and a
// path of x, y, z, vx, vy, vz per tick). When that track is replayed, the bot (or you,
// following) fires it again and it's held to its recorded path until the path ends;
// after that, or once someone reflects it, physics decides.

function ProjTick(s, r)
{
    for (local e = null; e = Entities.FindByClassname(e, "tf_projectile_*");)
    {
        if (e in SS.projSeen)
            continue
        SS.projSeen[e] <- true
        local owner = ProjOwner(e)
        if (owner == null || !owner.IsPlayer())
            continue
        if (!owner.IsFakeClient())
        {
            local actor = ActorOf(owner)
            if (actor == null)
                continue
            if (actor.live)
            {
                local rec = { spawn = s - 1 - actor.t.start, cls = e.GetClassname(), path = [] }
                actor.t.projs.append(rec)
                SS.projLive.append({ rec = rec, ent = e, p = owner })
            }
            else
                MatchProj(e, actor.t, s, r)
        }
        else
        {
            local t = TrackByName(BotName(owner))
            if (t != null)
                MatchProj(e, t, s, r)
        }
    }

    local live = []
    foreach (pl in SS.projLive)
    {
        if (!pl.ent.IsValid() || ProjOwner(pl.ent) != pl.p)
            continue
        local o = pl.ent.GetOrigin(), v = pl.ent.GetAbsVelocity()
        pl.rec.path.extend([o.x, o.y, o.z, v.x, v.y, v.z])
        live.append(pl)
    }
    SS.projLive = live

    local keep = []
    foreach (pp in SS.projPlay)
    {
        if (!pp.ent.IsValid() || ProjOwner(pp.ent) != pp.owner)
            continue
        local j = s - pp.at0
        local path = pp.rec.path
        if (j >= path.len() / 6)
            continue                // past its recording
        keep.append(pp)
        if (j < 0)
            continue
        local o = j * 6
        local want = Vector(path[o], path[o + 1], path[o + 2])
        if ((pp.ent.GetOrigin() - want).Length() > PROJ_DRIFT)
        {
            local vel = Vector(path[o + 3], path[o + 4], path[o + 5])
            if (pp.ent.GetMoveType() == MOVETYPE_VPHYSICS)
                pp.ent.Teleport(true, want, false, QAngle(), true, vel)
            else
            {
                pp.ent.SetAbsOrigin(want)
                pp.ent.SetAbsVelocity(vel)
            }
        }
    }
    SS.projPlay = keep

    if (SS.ticks % 66 == 0)
    {
        local seen = {}
        foreach (e, _v in SS.projSeen)
            if (e.IsValid())
                seen[e] <- true
        SS.projSeen = seen
    }
}

/** A replayed shot just appeared: find its recording. */
function MatchProj(e, t, s, r)
{
    local k = s - 1 - t.start      // the tick it was fired on
    local cls = e.GetClassname()
    foreach (i, rec in t.projs)
    {
        if (rec.cls != cls || rec.path.len() == 0 || rec.spawn < k - 1 || rec.spawn > k + 1)
            continue
        local key = t.name + ":" + i
        if (key in r.matched)
            continue
        r.matched[key] <- true
        SS.projPlay.append({ ent = e, rec = rec, track = t.name, at0 = t.start + rec.spawn + 1, owner = ProjOwner(e) })
        return
    }
    r.extraShots++
}

/** Recorded shots in [a, s] of a run that never showed up. */
function MissedShots(r)
{
    local missed = 0
    foreach (t in SS.tracks)
    {
        if (t.muted)
            continue
        // A track that went live only counts up to where it took over.
        local actor = ActorOfRun(r, t)
        local limit = actor != null && actor.want && r.p != null ? Min(r.s - 1, r.p - 1) : r.s - 1
        foreach (i, rec in t.projs)
        {
            local at = t.start + rec.spawn
            if (at >= r.a && at < limit && !((t.name + ":" + i) in r.matched))
                missed++
        }
    }
    return missed
}

/** A reflected !det flare stops being recorded at the reflect but still matters until the
 *  M2: count it as flying a second longer. */
function DetHold(tr, rec) { return SS.det != null && tr.name == SS.det && rec.cls == "tf_projectile_flare" ? 66 : 0 }

/** How far before tick t a run has to start so everything in flight at t is there. */
function Lookback(t, runup)
{
    local need = runup
    foreach (tr in SS.tracks)
    {
        if (tr.muted)
            continue
        foreach (rec in tr.projs)
        {
            local fired = tr.start + rec.spawn
            local last = fired + rec.path.len() / 6 + DetHold(tr, rec)
            if (fired < t && last >= t)
                need = Max(need, t - fired + 2)
        }
    }
    if (SS.shooter != null && SS.det == null)
    {
        local tr = TrackByName(SS.shooter.target)
        if (tr != null && !tr.muted)
        {
            local k = t - tr.start
            local fire = LastEvent(tr, "fire", k)
            if (fire != null && k >= 0 && k < Frames(tr) && (Fv(tr, k, F.FSTATE) == 1 || Fv(tr, k, F.FSTATE) == 2))
                need = Max(need, k - fire.t + 2)
        }
    }
    local a = Max(Min(t, SceneStart()), t - need)
    // The run-up's first tick mustn't be inside a flight either: StartRun clears every
    // projectile, and things are only fired again on their own tick. Every move makes
    // a smaller, so this ends.
    for (local moved = true; moved;)
    {
        moved = false
        foreach (tr in SS.tracks)
        {
            if (tr.muted)
                continue
            foreach (rec in tr.projs)
            {
                local fired = tr.start + rec.spawn
                if (fired < a && fired + rec.path.len() / 6 + DetHold(tr, rec) >= a)
                {
                    a = fired - 2
                    moved = true
                }
            }
        }
        local st = SS.shooter != null && SS.det == null ? TrackByName(SS.shooter.target) : null
        if (st != null && !st.muted)
        {
            local ka = a - st.start
            local fire = LastEvent(st, "fire", ka)
            local replaced = false
            foreach (e in st.events)
                if (fire != null && e.type == "fire" && e.t > fire.t && e.t <= t - st.start)
                    replaced = true
            if (!replaced && fire != null && ka >= 0 && ka < Frames(st) && st.start + fire.t - 2 < a &&
                (Fv(st, ka, F.FSTATE) == 1 || Fv(st, ka, F.FSTATE) == 2))
            {
                a = st.start + fire.t - 2
                moved = true
            }
        }
    }
    return a
}

// ---- Runs --------------------------------------------------------------------
//
// One server tick is one scene tick. A run starts frozen at scene tick a for `freeze`
// ticks, then plays a, a+1, ...: your track follows its recording until tick p, where
// you take over (live), and bots act out every other track all along.

function StartRun(o)
{
    EndRun(true)
    local me = Me()
    local spec = ("spec" in o) ? o.spec : null
    local inits = ("inits" in o) ? o.inits : {}
    local p = ("p" in o) ? o.p : null        // null: nobody takes over
    local actors = []
    local anyLive = false
    foreach (h in Humans())
    {
        local t = TrackOf(h)
        if (t == null || t.muted || (spec != null && h == me) || (h.GetTeam() < 2 && h != me))
            continue
        local want = p != null && IsLiveTrack(t)
        local n = Frames(t)
        if (n == 0 && !want)
            continue
        if (h.GetTeam() < 2 || !h.IsAlive() || (n > 0 && (h.GetPlayerClass() != t.cls || h.GetTeam() != t.team)))
            Become(t, h)
        EnsureDet(h, t)
        if (n > 0)
            CheckLoadout(t, h)
        local id = PlayerId(h)
        local init = (id in inits) ? inits[id] : null
        if (init == null && n == 0)
            init = StandFrame(h)
        actors.append({ p = h, id = id, t = t, host = h == me, want = want, live = false, out = false,
            init = init, fresh = id in inits, btn = null, stepS = -2147483647, punchS = null })
        anyLive = anyLive || want
    }
    if (spec == null && actors.len() == 0)
    {
        Say("Nobody to act: !track <name> or !new first.")
        return false
    }
    KillProjectiles()
    SS.projSeen = {}
    SS.detFlares = {}
    SS.detNoted = {}
    SS.projLive = []
    SS.projPlay = []
    SS.playFlare = null
    SS.flare = null
    SS.flareState = 0
    SS.burstAt = -1
    SS.fireNow = false
    SS.otherBurst = null
    local b = ("b" in o) ? o.b : null        // null: until !stop
    if (p != null && !anyLive)
    {
        Say("Nobody here is in !live, so this only plays back.")
        p = null
        b = SceneEnd() + POSTROLL_TICKS
    }
    SS.run = {
        a = o.a, p = p, b = b,
        freeze = ("freeze" in o) ? o.freeze : RUN_FREEZE,
        s = o.a - 1, started = false, live = false,
        actors = actors,
        render = ("render" in o) ? o.render : null,   // demo name
        spec = spec, specDemo = ("specDemo" in o) ? o.specDemo : null,
        prevTeam = me.GetTeam(), prevCls = me.GetPlayerClass(),
        demoStarted = false, waited = 0,
        matched = {}, extraShots = 0, drift = 0.0, fixes = 0,
        probeAt = -1
    }
    if (spec != null)
        me.ForceChangeTeam(TEAM_SPECTATOR, true)
    Housekeep()
    return true
}

/** p where they stand, as the first frame of a new take. */
function StandFrame(p)
{
    local f = Capture(p)
    f[F.VX] = 0.0; f[F.VY] = 0.0; f[F.VZ] = 0.0
    f[F.FSTATE] = 0
    return f
}

function ActorOfRun(r, t)
{
    foreach (a in r.actors)
        if (a.t == t)
            return a
    return null
}

function EndRun(silent)
{
    local r = SS.run
    if (r == null)
        return
    local missed = r.started ? MissedShots(r) : 0
    SS.run = null
    ReleaseKeys()
    if (r.probeAt >= 0 && r.probeAt != 0x7fffffff)
        SendToConsole("-alt2 " + VKEY)
    local me = Me()
    foreach (a in r.actors)
        if (a.p.IsValid())
            FreeMe(a.p)
    if (r.demoStarted)
        StopLiveDemo()
    SS.cursor = r.started ? r.s : r.a
    if (SS.flare != null && SS.flare.IsValid() && (SS.flareState == 1 || SS.flareState == 2))
        SS.flare.Kill()
    SS.otherBurst = null
    SS.flare = null             // practice between takes starts clean
    SS.flareState = 0
    SS.burstAt = -1
    SS.fireNow = false
    if (r.spec != null && me != null)
    {
        local t = TrackOf(me)
        local team = t != null ? t.team : r.prevTeam
        local cls = t != null ? t.cls : r.prevCls
        if (team >= 2)
        {
            me.ForceChangeTeam(team, true)
            me.SetPlayerClass(cls)
            NetProps.SetPropInt(me, "m_Shared.m_iDesiredPlayerClass", cls)
            me.ForceRegenerateAndRespawn()
        }
    }
    SS.diag.last = format("last run: ticks %d-%d, followed with max drift %.2f (%d fixes), %d recorded shots missing, %d extra",
        r.a, r.s, r.drift, r.fixes, missed, r.extraShots)
    SS.projLive = []
    SS.projPlay = []
    if (silent)
        return
    local any = false
    foreach (a in r.actors)
    {
        if (a.live || a.out)
        {
            any = true
            Say(format("Take stopped: %s is ticks %d-%d (%.2fs).", a.t.name, a.t.start, TrackEnd(a.t), Frames(a.t) * TICK))
        }
    }
    if (!any)
        Say("Stopped at tick " + SS.cursor + ".")
    if (missed > 0)
        Say(missed + " recorded shot(s) didn't happen in the replay (!diag).")
}

function TickStart(fromThinker)
{
    local now = Time()
    if (now == SS.masterTime)
        return
    SS.masterTime = now
    SS.ticks++
    if (fromThinker)
        SS.diag.fromThinker++
    else
        SS.diag.fromClock++
    if (Me() == null)
        return
    if (SS.run != null)
        RunTick()
    else
        IdleShooter()
}

function DropActor(a)
{
    a.out = true
    a.live = false
    if (a.p.IsValid())
        FreeMe(a.p)
    if (a.host)
        ReleaseKeys()
}

function RunTick()
{
    local r = SS.run
    foreach (a in r.actors)
    {
        if (a.out)
            continue
        if (!a.p.IsValid() || a.p.GetTeam() < 2)
        {
            // Left, or went to spectator: a bot acts out what they have from here.
            if (a.live)
                Say(a.t.name + "'s player left; that take stopped.")
            DropActor(a)
        }
        else if (a.live && !a.p.IsAlive())
        {
            Say(a.t.name + " died; that take stopped. !rw to go back.")
            DropActor(a)
        }
        else if (!a.p.IsAlive())
            a.p.ForceRespawn()
    }
    local host = null
    foreach (a in r.actors)
        if (a.host && !a.out)
            host = a

    if (r.freeze > 0)
    {
        foreach (a in r.actors)
            if (!a.out && a.p.IsAlive())
                HoldMe(a, MyFrameAt(a, r.a))
        if (host != null)
        {
            Probe(host.p, r)
            InjectFor(host.t, r.a - r.freeze + Lat() - (r.waited > 0 ? 1 : 0), r, host)
        }
        if (r.spec != null && (r.freeze % 5 == 2 || r.freeze == 1))
        {
            local tp = PlayerOfTrack(TrackByName(r.spec), r)
            SendToConsole("spec_mode 4")
            if (tp != null)
                SendToConsole("spec_player \"" + BotName(tp) + "\"")
        }
        if (r.freeze == 10)
            StartRunDemo(r)
        if (r.freeze % 11 == 0)
            Center(format("tick %d  -  starts in %.1fs", r.a, r.freeze * TICK))
        // Don't start before the stand-in bots are in and acting (up to 4 s).
        if (r.freeze == 1 && !BotsReady() && r.waited < 264)
        {
            if (r.waited++ % 33 == 0)
                Center("waiting for the bots to join...")
            return
        }
        if (r.freeze == 1 && r.waited > 0 && r.waited < 1000)
        {
            r.waited = 1000           // ready now: replay the last frozen tick(s) for the keys
            r.freeze = 1 + Lat()
        }
        r.freeze--
        return
    }

    if (!r.demoStarted)
        StartRunDemo(r)
    r.s++
    r.started = true
    local s = r.s
    local anyLive = false

    foreach (a in r.actors)
    {
        if (a.out || !a.p.IsAlive())
            continue
        if (!a.want || r.p == null || s < r.p)
            FollowMe(a, s, r)
        else if (!a.live)
            PunchIn(a, s, r)
        else
            LiveSample(a, s)
        anyLive = anyLive || a.live
    }
    // Everyone who went live this tick was sampled with the change number of the same
    // punch-in: none of that is stale against the others.
    foreach (a in r.actors)
        if (a.punchS == s && Frames(a.t) > s - a.t.start)
            a.t.frames[(s - a.t.start) * STRIDE + F.REV] = SS.rev
    if (SS.det != null)
        DetTick(s, r)
    else
        ShooterTick(s, r)
    ProjTick(s, r)
    if (host != null && !host.live)
        Probe(host.p, r)

    if (anyLive)
    {
        if (s % 6 == 0)
            Center(format("REC  %d  (%.2fs)", s, s * TICK))
    }
    else if (s % 11 == 0)
    {
        if (r.p != null && s < r.p)
            Center(format("tick %d  -  LIVE in %.1fs", s, (r.p - s) * TICK))
        else
            Center(format("tick %d / %d", s, r.b != null ? r.b : SceneEnd()))
    }
    if (r.p != null && s >= r.p && !anyLive)
    {
        Say("Nobody's left recording; stopping.")
        EndRun(true)
        return
    }
    if (r.b != null && s >= r.b)
        EndRun(false)
}

function StartRunDemo(r)
{
    if (r.demoStarted)
        return
    local name = r.render != null ? r.render : r.specDemo
    if (name == null)
        return
    StartLiveDemo(name)
    r.demoStarted = true
}

/** Your frame for scene tick s in this run: before your track starts, where it starts. */
function MyFrameAt(a, s)
{
    local t = a.t
    local n = Frames(t)
    if (a.init != null && (n == 0 || s <= t.start))
        return a.init
    if (n == 0)
        return StandFrame(a.p)
    return FrameAt(t, Clamp(s - t.start, 0, n - 1))
}

/** Following your recording on scene tick s (your command for s runs after this). */
function FollowMe(a, s, r)
{
    local t = a.t
    local me = a.p
    local n = Frames(t)
    local k = s - t.start
    if (n == 0 || k < 0 || k >= n)
    {
        // Before their track starts (or after it ends): wait where it starts (ends).
        HoldMe(a, MyFrameAt(a, s))
        if (a.host)
            InjectFor(t, s + Lat(), r, a)
        return
    }
    me.AddCond(PREVENT_DEATH)
    local pre = FrameAt(t, k)
    if (!a.host)
    {
        // A friend: we can't press their keys, so the server moves them like a bot, here
        // to where they were after the last tick (for the snapshot) and in FollowCmd to
        // this tick's frame. The buttons below go in their next command, for tick s.
        if (s == r.a || k == 0)
            Restore(me, pre, true)
        else
        {
            local pos = Vector(pre[F.OX], pre[F.OY], pre[F.OZ])
            me.SetAbsOrigin(pos)
            me.SetAbsVelocity(Vector(pre[F.VX], pre[F.VY], pre[F.VZ]))
            me.SetHealth(Max(1, pre[F.HP]))
        }
        if (me.GetMoveType() != MOVETYPE_NONE)
            me.SetMoveType(MOVETYPE_NONE, 0)
    }
    else if (s == r.a || k == 0)
        Restore(me, pre, true)
    else
    {
        local pos = Vector(pre[F.OX], pre[F.OY], pre[F.OZ])
        local vel = Vector(pre[F.VX], pre[F.VY], pre[F.VZ])
        local d = (me.GetOrigin() - pos).Length()
        if (d > r.drift)
            r.drift = d
        if (d > DRIFT_POS || (me.GetAbsVelocity() - vel).Length() > DRIFT_VEL)
        {
            r.fixes++
            me.SetAbsOrigin(pos)
            me.SetAbsVelocity(vel)
        }
        me.SetHealth(pre[F.HP])
        MoveState(me, pre)
        WeaponState(me, pre, PlayerNow(me))
    }
    if (k + 1 < n)
    {
        local b = Fv(t, k + 1, F.BUTTONS)
        if (a.host)
            SwitchTo(me, Fv(t, k + 1, F.SLOT))
        NetProps.SetPropInt(me, "m_afButtonForced", b & FORCE_BUTTONS)
        NetProps.SetPropInt(me, "m_afButtonDisabled", FORCE_BUTTONS & ~b)
        // Their game shows the view a little later than this: aim ahead, but not past the
        // tick they go live at (that's the view they take over with).
        local last = a.want && r.p != null ? Clamp(r.p - t.start, k + 1, n - 1) : n - 1
        local v = Min(k + 1 + LeadTicks(a), last)
        me.SnapEyeAngles(QAngle(Fv(t, v, F.PITCH), Fv(t, v, F.YAW), 0))
    }
    else
    {
        NetProps.SetPropInt(me, "m_afButtonForced", pre[F.DUCKED] != 0 ? IN_DUCK : 0)
        NetProps.SetPropInt(me, "m_afButtonDisabled", WEAPON_BUTTONS)
    }
    if (a.host)
        InjectFor(t, s + Lat(), r, a)
    if (SS.shooter != null && SS.det == null && SS.shooter.target == t.name)
        SS.flareState = pre[F.FSTATE]
    if (a.host && r.render != null && SS.liveDemo != null)
        Stamp(t, k)
}

/** Inside a followed player's command for scene tick s, before they move and shoot. */
function FollowCmd(a, s)
{
    local t = a.t
    local k = s - t.start
    if (k < 0 || k + 1 >= Frames(t))
        return
    if (a.host)
    {
        // The command's own view angles came in before this; weapons use these.
        a.p.SnapEyeAngles(QAngle(Fv(t, k + 1, F.PITCH), Fv(t, k + 1, F.YAW), 0))
        return
    }
    // A friend's commands come in bunches over the internet: step their frames in order,
    // catching up on a tick that had no command, and don't let an extra command (with
    // nothing left to step) shoot again.
    local step = a.stepS < s - 2 ? s : a.stepS + 1
    if (step > s)
    {
        a.p.SnapEyeAngles(QAngle(Fv(t, k + 1, F.PITCH), Fv(t, k + 1, F.YAW), 0))
        NetProps.SetPropFloat(a.p, "m_flNextAttack", PlayerNow(a.p) + 1.0)
        return
    }
    local ks = step - t.start
    if (ks < 0 || ks + 1 >= Frames(t))
    {
        a.stepS = step
        return
    }
    a.stepS = step
    ActFrame(a.p, t, step, FrameAt(t, ks + 1), true, PlayerNow(a.p))
}

/** Scene tick s = p: you take over. */
function PunchIn(a, s, r)
{
    local t = a.t
    local me = a.p
    local n = Frames(t)
    local k = s - t.start
    local f = a.init
    if (f == null)
        f = FrameAt(t, Clamp(k, 0, n - 1))
    if (!a.fresh)
        PushVersion(t)          // the take as it was before this rewind (!new pushed its own)
    if (k >= n && n > 0)
    {
        // Their track had ended: they were standing still at its end.
        f = clone f
        f[F.VX] = 0.0; f[F.VY] = 0.0; f[F.VZ] = 0.0
    }
    if (n == 0 || k < 0)
    {
        // Their track started after this tick (or has nothing yet): it starts here now.
        t.frames = []
        t.events = []
        t.projs = []
        t.start = s
        k = 0
    }
    local target = SS.shooter != null && SS.det == null && SS.shooter.target == t.name
    // The airblast that reflected the flare was their last followed command: if it
    // missed this time, do the reflect, so it's caught below like a real one.
    if (target && f[F.FSTATE] == 1)
        foreach (e in t.events)
            if (e.type == "deflect" && e.t == k)
                ForceDeflect(me)
    Truncate(t, k)
    // Their shots still in the air go on being recorded from here.
    local keep = []
    foreach (pp in SS.projPlay)
    {
        if (pp.track != t.name)
        {
            keep.append(pp)
            continue
        }
        if (!pp.ent.IsValid())
            continue
        local m = Max(0, s - pp.at0) * 6
        if (m < pp.rec.path.len())
            pp.rec.path = pp.rec.path.slice(0, m)
        if (t.projs.find(pp.rec) == null)
            t.projs.append(pp.rec)
        SS.projLive.append({ rec = pp.rec, ent = pp.ent, p = me })
    }
    SS.projPlay = keep
    Restore(me, f, true)
    FreeMe(me)
    if (a.host)
        ReleaseKeys()
    if (target)
    {
        SS.flare = SS.playFlare
        SS.flareState = f[F.FSTATE]
        SS.burstAt = -1
        if (SS.flareState == 2)
        {
            local d = LastEvent(t, "deflect", k)
            SS.burstAt = d != null ? d.t - 1 + Max(1, t.delay) : k
        }
    }
    a.live = true
    a.btn = f[F.BUTTONS]        // the recorded keys of the last command, not live ones
    a.punchS = s
    r.live = true
    // Checkpoints after this tick are on the part being recorded again.
    local cps = []
    foreach (c in SS.cps)
        if (c <= s)
            cps.append(c)
    SS.cps = cps
    AddMod(t.name, k <= 0 ? ALL_TICKS : s)
    LiveSample(a, s)
}

function LiveSample(a, s)
{
    local t = a.t
    local k = s - t.start
    if (Frames(t) != k)          // their track ended before this tick: hold its last frame
    {
        while (Frames(t) > 0 && Frames(t) < k)
        {
            local pad = FrameAt(t, Frames(t) - 1)
            pad[F.VX] = 0.0; pad[F.VY] = 0.0; pad[F.VZ] = 0.0
            pad[F.BUTTONS] = pad[F.DUCKED] != 0 ? IN_DUCK : 0
            pad[F.DEMOID] = -1
            t.frames.extend(pad)
        }
        if (Frames(t) > k)
            t.frames = t.frames.slice(0, Max(0, k) * STRIDE)
    }
    local f = Capture(a.p)
    if (a.btn != null)
        f[F.BUTTONS] = a.btn
    a.btn = null
    if (a.host && SS.liveDemo != null)
    {
        f[F.DEMOID] = SS.liveId
        f[F.DEMOTICK] = DemoTick()
    }
    else if (!a.host && (a.id in SS.marks))
    {
        local m = SS.marks[a.id]
        f[F.DEMOID] = m.id
        f[F.DEMOTICK] = ((Time() - m.start) / TICK + 0.5).tointeger() - (("off" in m) ? m.off : SS.demoOffset)
    }
    t.frames.extend(f)
}

function Stamp(t, k)
{
    local o = k * STRIDE
    t.frames[o + F.DEMOID] = SS.liveId
    t.frames[o + F.DEMOTICK] = DemoTick()
    t.frames[o + F.REV] = SS.rev
}

// ---- Demo of what you do live ------------------------------------------------

/** Demo tick of this server tick in the demo being recorded, -1 if none. */
function DemoTick()
{
    if (SS.liveDemo == null)
        return -1
    return ((Time() - SS.liveStart) / TICK + 0.5).tointeger() - SS.demoOffset
}

function StartLiveDemo(name)
{
    if (!ValidName(name))
    {
        Say("Demo names: letters, digits and _.")
        return
    }
    if (SS.liveDemo != null)
        StopLiveDemo()
    // record overwrites an existing demo: add the date and time.
    local lt = {}
    LocalTime(lt)
    local stem = format("%s_%02d%02d_%02d%02d%02d", name, lt.month, lt.day, lt.hour, lt.minute, lt.second)
    name = stem
    for (local i = 2; SS.demoNames.find(name) != null; i++)
        name = stem + "_" + i
    printl("[stunt] recording demo " + name + ".dem (chat and messages are hidden until it stops)")
    SendToConsole("record " + name)
    SendToConsole("hud_saytext_time 0")
    SS.liveDemo = name
    SS.liveStart = SS.inTick ? Time() : Time() + TICK
    SS.demoNames.append(name)
    SS.liveId = SS.demoNames.len() - 1
}

function StopLiveDemo()
{
    if (SS.liveDemo == null)
        return
    SendToConsole("stop")
    SendToConsole("hud_saytext_time 12")
    local name = SS.liveDemo
    SS.liveDemo = null
    SS.liveId = -1
    Say("Demo " + name + ".dem stopped. !cuts lists which parts make up your track.")
}

/** Which demo ranges make up the track you play, in order. */
function Cuts(who)
{
    local t = TrackOf(who)
    if (t == null || Frames(t) == 0)
    {
        Say("No take.")
        return
    }
    // Ticks changed in other tracks after this footage was shot are stale, and so is
    // footage of this track after a shift or team change.
    local others = []
    foreach (m in SS.mods)
        if (m.track != t.name || ("own" in m))
            others.append(m)
    local staleFrom = {}
    local n = Frames(t)
    local out = format("Cut list for %s (ticks %d-%d). Keep these demo ranges, in order;\n", t.name, t.start, TrackEnd(t))
    out += "demo ticks are inclusive; seconds = tick * 0.015 (demoui, demo_gototick, or your editor).\n"
    local i = 0
    local missing = 0, stale = 0
    while (i < n)
    {
        local id = Fv(t, i, F.DEMOID)
        local j = i
        while (j + 1 < n && Fv(t, j + 1, F.DEMOID) == id && (id < 0 || Fv(t, j + 1, F.DEMOTICK) == Fv(t, j, F.DEMOTICK) + 1))
            j++
        local a = Fv(t, i, F.DEMOTICK), b = Fv(t, j, F.DEMOTICK)
        local bad = 0
        for (local x = i; x <= j; x++)
        {
            local rev = Fv(t, x, F.REV)
            if (!(rev in staleFrom))
            {
                local from = 0x7fffffff
                foreach (m in others)
                    if (m.rev > rev && m.from < from)
                        from = m.from
                staleFrom[rev] <- from
            }
            if (t.start + x >= staleFrom[rev])
                bad++
        }
        if (id < 0)
        {
            out += format("  ticks %d-%d: NOT IN ANY DEMO\n", t.start + i, t.start + j)
            missing += j - i + 1
        }
        else
        {
            local dn = id < SS.demoNames.len() ? SS.demoNames[id] : "demo#" + id
            out += format("  %s.dem  ticks %d-%d  (%.3fs - %.3fs)   scene ticks %d-%d%s\n",
                dn, a, b, a * TICK, (b + 1) * TICK, t.start + i, t.start + j,
                bad > 0 ? format("   STALE: %d ticks changed in other tracks since", bad) : "")
            stale += bad
        }
        i = j + 1
    }
    if (missing > 0)
        out += format("%d ticks weren't recorded in a demo (!demo, or !render).\n", missing)
    if (stale > 0)
        out += "Stale ticks show other actors as they were before you changed them: !render, or re-record those ticks.\n"
    printl(out)
    if (who != Me())
        foreach (line in split(out, "\n"))
            ClientPrint(who, Constants.EHudNotify.HUD_PRINTCONSOLE, line + "\n")
    StringToFile("ss_cuts.txt", out.len() > PART_BYTES ? out.slice(0, PART_BYTES) : out)
    Tell(who, "Cut list in your console" + (who == Me() ? " and tf/scriptdata/ss_cuts.txt." : "."))
}

// ---- Commands that change things ------------------------------------------------

function NewTake(arg, who)
{
    EndRun(true)
    // Everyone on a team who's live starts from where they stand. A track only gets made
    // here when nobody limited !live.
    local takers = []
    foreach (h in Humans())
    {
        if (!h.IsAlive() || h.GetTeam() < 2)
            continue
        local t = TrackOf(h)
        if (t == null && SS.liveOnly == null)
        {
            t = AddTrack(DefaultName(h), h, h.GetTeam())
            if (t != null)
            {
                SS.versions.append({ name = t.name, copy = null, g = SS.group })
                TrimVersions()
                Say("Made track " + t.name + " for " + BotName(h) + " (!track <name> to pick another).")
            }
        }
        if (t != null && !t.muted && IsLiveTrack(t))
            takers.append({ h = h, t = t })
    }
    if (takers.len() == 0)
    {
        Say("Nobody's ready to record: spawn first, and check !live.")
        return
    }
    local mine = TrackOf(who)
    local start = arg != null ? ToInt(arg, mine != null ? mine.start : 0) : (mine != null ? mine.start : 0)
    local inits = {}
    foreach (x in takers)
    {
        local t = x.t
        PushVersion(t)
        EnsureDet(x.h, t)
        t.team = x.h.GetTeam()
        t.cls = x.h.GetPlayerClass()
        t.weapons = Loadout(x.h)
        t.frames = []
        t.events = []
        t.projs = []
        t.start = start
        AddMod(t.name, ALL_TICKS)
        if (SS.shooter != null && SS.det == null && SS.shooter.target == t.name && t.cls != TF_CLASS_PYRO)
            Say("\x07FF4040" + BotName(x.h) + " isn't a Pyro\x01 (the reflect needs a flamethrower).")
        inits[PlayerId(x.h)] <- StandFrame(x.h)
    }
    foreach (x in takers)
        WarnTeams(x.t)
    SS.cps = []
    if (StartRun({ a = Lookback(start, 0), p = start, inits = inits, freeze = NEW_FREEZE }))
        Say(format("New take from tick %d. !go skips the wait.", start))
}

function Rewind(to)
{
    local any = false
    foreach (t in SS.tracks)
        if (Frames(t) > 0)
            any = true
    if (!any)
    {
        Say("Nothing recorded yet. !new starts a take.")
        return
    }
    to = Clamp(to, SceneStart(), SceneEnd())
    local a = Lookback(to, SS.runup)
    if (StartRun({ a = a, p = to }))
        Say(format("Back to tick %d: run-up from %d, then you're live.", to, a))
}

function Play(render)
{
    local me = Me()
    local t = TrackOf(me)
    if (render != null && (t == null || Frames(t) == 0))
    {
        Say("!render records the host's view, and the host has no recorded track (!track, or !spec <track> <demo>).")
        return
    }
    if (SceneEnd() == 0 && SceneStart() == 0)
    {
        Say("Nothing to play: !new first.")
        return
    }
    if (render != null && SS.liveDemo != null)
    {
        Say("A !demo is recording; !demostop first (a render makes its own demo).")
        return
    }
    if (render != null && !ValidName(render))
    {
        Say("Demo names: letters, digits and _.")
        return
    }
    if (StartRun({ a = SceneStart(), b = SceneEnd() + POSTROLL_TICKS, render = render }))
    {
        if (render != null)
            printl("[stunt] rendering; hands off the keyboard and mouse")
        else
            Say("Playing; hands off the keyboard and mouse. !stop to stop.")
    }
}

function Spec(name, demo, who)
{
    if (who != Me())
    {
        Say("Only the host can spectate through this (it moves the host to spectator).")
        return
    }
    local mine = TrackOf(who)
    local t = TrackByName(name != null ? name : (mine != null ? mine.name : null))
    if (t == null || Frames(t) == 0)
    {
        Say("No such track with frames.")
        return
    }
    if (demo != null && !ValidName(demo))
    {
        Say("Demo names: letters, digits and _.")
        return
    }
    if (StartRun({ a = SceneStart(), b = SceneEnd() + POSTROLL_TICKS, spec = t.name, specDemo = demo }))
        Say("Watching " + t.name + ". !stop to stop.")
}

/** Become track t's actor: its team and class. */
function Become(t, p)
{
    if (p.GetTeam() != t.team)
        p.ForceChangeTeam(t.team, true)
    p.SetPlayerClass(t.cls)
    NetProps.SetPropInt(p, "m_Shared.m_iDesiredPlayerClass", t.cls)
    p.ForceRegenerateAndRespawn()
}

function CheckLoadout(t, p)
{
    local mine = Loadout(p)
    foreach (w in t.weapons)
    {
        local same = false
        foreach (m in mine)
            if (m.slot == w.slot && m.def == w.def)
                same = true
        if (!same)
            Say(format("%s's slot %d weapon isn't the %s (item %d) %s was recorded with.", BotName(p), w.slot + 1, w.cls, w.def, t.name))
    }
}

function ArmTrack(name, teamArg, who)
{
    if (!ValidName(name))
    {
        Say("Track names: letters, digits and _ (up to 20).")
        return
    }
    local team = null
    if (teamArg != null)
    {
        team = teamArg.tolower() == "red" ? 2 : (teamArg.tolower() == "blue" ? 3 : null)
        if (team == null)
        {
            Say("Teams: red or blue.")
            return
        }
    }
    local t = TrackByName(name)
    local holder = t != null ? OwnerPlayer(t) : null
    if (holder != null && holder != who)
    {
        Say(BotName(holder) + " plays " + name + " right now.")
        return
    }
    EndRun(true)
    local id = PlayerId(who)
    local old = TrackOfId(id)
    if (old != null && old != t)
        old.owner = null        // a bot acts it out until someone takes it
    if (t == null)
    {
        local myTeam = who.GetTeam() >= 2 ? who.GetTeam() : 2
        t = AddTrack(name, who, team != null ? team : myTeam)
        if (t == null)
        {
            if (old != null)
                old.owner = id
            return
        }
        SS.versions.append({ name = name, copy = null, g = SS.group })     // !undo removes it again
        TrimVersions()
        SS.redo = []
        if (who.GetTeam() != t.team)
        {
            who.ForceChangeTeam(t.team, true)
            who.ForceRegenerateAndRespawn()
        }
        Say(format("New track %s (%s) for %s. Pick its class, then !new.", name, TeamName(t.team), BotName(who)))
        WarnTeams(t)
        Housekeep()
        return
    }
    t.owner = id
    if (team != null && team != t.team)
    {
        PushVersion(t)
        t.team = team
        AddMod(name, ALL_TICKS)
        SS.mods.top().own <- true      // its own footage is on the old team now
    }
    if (Frames(t) > 0 && (who.GetPlayerClass() != t.cls || who.GetTeam() != t.team))
        Become(t, who)
    else if (who.GetTeam() != t.team)
    {
        who.ForceChangeTeam(t.team, true)
        who.ForceRegenerateAndRespawn()
    }
    Say(format("%s is %s now (%s, ticks %d-%d). !rw / !to <tick> re-records from a tick, !new redoes it.",
        BotName(who), name, TeamName(t.team), t.start, TrackEnd(t)))
    WarnTeams(t)
    Housekeep()
}

function DeleteTrack(name)
{
    local t = TrackByName(name)
    if (t == null)
    {
        Say("No track " + name)
        return
    }
    EndRun(true)
    PushVersion(t)
    PutTrack(name, null)
    Say("Deleted " + name + " (!undo brings it back).")
}

function Shift(name, n)
{
    local t = TrackByName(name)
    if (t == null)
    {
        Say("No track " + name)
        return
    }
    EndRun(true)
    PushVersion(t)
    local old = t.start
    t.start += n
    AddMod(name, Min(old, t.start))
    SS.mods.top().own <- true          // its own footage is out of step with the rest now
    Say(format("%s now starts at tick %d (ticks %d-%d).", name, t.start, t.start, TrackEnd(t)))
}

function SetMuted(name, muted)
{
    local t = TrackByName(name)
    if (t == null)
    {
        Say("No track " + name)
        return
    }
    EndRun(true)
    PushVersion(t)
    t.muted = muted
    AddMod(name, ALL_TICKS)
    Say(name + (muted ? " muted." : " back in."))
}

function Join(otherName, at, who)
{
    local t = TrackOf(who)
    if (t == null || Frames(t) == 0)
    {
        Say("Nothing recorded to join onto.")
        return
    }
    local other = null, scene = null
    if (IsVersionName(otherName))
    {
        local idx = otherName.slice(1).tointeger()
        if (idx >= SS.versions.len() || SS.versions[idx].copy == null)
        {
            Say("No version " + otherName + " (!versions).")
            return
        }
        if (SS.versions[idx].name != t.name)
        {
            Say(otherName + " is a version of " + SS.versions[idx].name + ", not " + t.name)
            return
        }
        other = SS.versions[idx].copy
    }
    else
    {
        scene = LoadScene(otherName)
        if (scene != null)
            foreach (x in scene.tracks)
                if (x.name == t.name)
                    other = x
    }
    if (other == null || Frames(other) < 2)
    {
        Say("No version or saved track " + t.name + " in " + otherName)
        return
    }
    // Ours up to and with frame k (tick `at`), theirs from their frame j+1 on.
    local lo = Max(t.start, other.start), hi = Min(TrackEnd(t), TrackEnd(other) - 1)
    if (lo > hi)
    {
        Say("Those don't overlap.")
        return
    }
    EndRun(true)
    at = Clamp(at, lo, hi)
    PushVersion(t)
    local k = at - t.start
    local j = at - other.start
    local shift = other.start - t.start
    local theirs = other.frames.slice((j + 1) * STRIDE)
    if (scene != null)
    {
        // Footage from a saved file: point its demo ids into this session's list, and
        // count it as possibly stale.
        for (local o = 0; o < theirs.len(); o += STRIDE)
        {
            local id = theirs[o + F.DEMOID]
            if (id >= 0)
            {
                local dn = id < scene.demoNames.len() ? scene.demoNames[id] : null
                local ni = dn != null ? SS.demoNames.find(dn) : -1
                if (dn != null && ni == null)
                {
                    SS.demoNames.append(dn)
                    ni = SS.demoNames.len() - 1
                }
                theirs[o + F.DEMOID] = ni
            }
            theirs[o + F.REV] = -1
        }
    }
    local a = Vector(Fv(t, k, F.OX), Fv(t, k, F.OY), Fv(t, k, F.OZ))
    local b = Vector(Fv(other, j, F.OX), Fv(other, j, F.OY), Fv(other, j, F.OZ))
    local joined = CopyTrack(t)
    Truncate(joined, k + 1)
    // The command of tick `at` (and so its shot, the shooter firing and the burst) is
    // theirs; the reflect caught at the start of `at` came from our last command.
    local ev = []
    foreach (e in joined.events)
        if (!(e.t == k && (e.type == "fire" || e.type == "burst")))
            ev.append(e)
    joined.events = ev
    joined.frames.extend(theirs)
    foreach (e in other.events)
    {
        if (e.t < j || (e.t == j && (e.type == "deflect" || e.type == "detreflect")))
            continue
        local c = {}
        foreach (key, v in e)
            c[key] <- v
        c.t = e.t + shift
        joined.events.append(c)
    }
    foreach (p in other.projs)
        if (p.spawn >= j)
            joined.projs.append({ spawn = p.spawn + shift, cls = p.cls, path = p.path.slice(0) })
    ReplaceTrack(joined)
    AddMod(t.name, at)
    SS.cps = []
    Say(format("Joined at tick %d: %s is ticks %d-%d. Position jump at the cut: %.1f units.",
        at, t.name, joined.start, TrackEnd(joined), (a - b).Length()))
}

function Undo()
{
    if (SS.versions.len() == 0)
    {
        Say("Nothing to undo.")
        return
    }
    EndRun(true)
    // Everything one command changed goes back together.
    local g = SS.versions.top().g
    local names = ""
    while (SS.versions.len() > 0 && SS.versions.top().g == g)
    {
        local v = SS.versions.pop()
        SS.redo.append({ name = v.name, copy = TrackByName(v.name), g = g, det = SS.det == v.name })
        PutTrack(v.name, v.copy)
        if (v.copy != null && ("det" in v) && v.det && SS.det == null)
            SS.det = v.name
        names += " " + v.name
        if (v.copy != null)
            names += format(" (%d-%d)", v.copy.start, TrackEnd(v.copy))
    }
    SS.cps = []
    Say("Undone:" + names + ". Checkpoints cleared. !redo to redo.")
}

function Redo()
{
    if (SS.redo.len() == 0)
    {
        Say("Nothing to redo.")
        return
    }
    EndRun(true)
    local g = SS.redo.top().g
    local names = ""
    while (SS.redo.len() > 0 && SS.redo.top().g == g)
    {
        local v = SS.redo.pop()
        SS.versions.append({ name = v.name, copy = TrackByName(v.name), g = g, det = SS.det == v.name })
        PutTrack(v.name, v.copy)
        if (v.copy != null && ("det" in v) && v.det && SS.det == null)
            SS.det = v.name
        names += " " + v.name
    }
    TrimVersions()
    SS.cps = []
    Say("Redone:" + names + ". Checkpoints cleared.")
}

function PlaceShooter(who, arg = null)
{
    local t = null
    if (arg != null && arg != "me")
    {
        t = TrackByName(arg)
        if (t == null)
        {
            Tell(who, "No track " + arg + " (!tracks).")
            return
        }
    }
    else
        t = TrackOf(who)
    if (t == null)
    {
        t = AddTrack(DefaultName(who), who, who.GetTeam() >= 2 ? who.GetTeam() : 2)
        if (t == null)
            return
        SS.versions.append({ name = t.name, copy = null, g = SS.group })
        TrimVersions()
    }
    SS.shooter = { pos = who.GetOrigin(), target = t.name }
    SS.det = null
    AddMod(SHOOTER_NAME, ALL_TICKS)
    Housekeep()
    local h = OwnerPlayer(t)
    Say("Shooter placed here. It aims at " + t.name + (h != null ? " (" + BotName(h) + ")" : "") +
        "; whoever reflects it live gets the burst. !fire fires it.")
}

/** !fireat / !burst / !delay / !hpafter: on the shooter's target track (for its next takes). */
function SetShot(key, v, who)
{
    EndRun(true)
    local t = SS.det != null ? TrackByName(SS.det) : (SS.shooter != null ? TrackByName(SS.shooter.target) : TrackOf(who))
    SS[key] = v
    if (t != null)
    {
        PushVersion(t)
        t[key] = v
        AddMod(SHOOTER_NAME, t.start)
    }
    Info(who)
}

// ---- Save / load ---------------------------------------------------------------

// Numbers per field: times need more digits than positions.
::PRECISE <- {}
foreach (k in [F.NEXTATK, F.NA0, F.NB0, F.NA1, F.NB1, F.NA2, F.NB2])
    PRECISE[k] <- true

function Num(v, precise)
{
    if (typeof v == "integer")
        return "" + v
    local s = format(precise ? "%.4f" : "%.2f", v)
    return (s == "-0.00" || s == "-0.0000") ? "0" : s
}

function PartFile(stem, i) { return format("ss_%s_%d.nut", stem, i) }

/** A string as a Squirrel literal. */
function Q(v)
{
    if (v == null)
        return "null"
    local out = "\""
    foreach (c in v)
    {
        if (c == '\\' || c == '"')
            out += "\\"
        out += c.tochar()
    }
    return out + "\""
}

/** Write arr (stride numbers per row) in files under the size limit; returns how many. */
function WriteParts(stem, arr, stride, isFrames, dry = false)
{
    local parts = 0
    local s = "return ["
    local n = arr.len()
    for (local i = 0; i < n; i++)
    {
        local item = Num(arr[i], isFrames && ((i % stride) in PRECISE)) + ","
        if (s.len() + item.len() > PART_BYTES && i % stride == 0)
        {
            if (!dry)
                StringToFile(PartFile(stem, parts), s + "]")
            parts++
            s = "return ["
        }
        s += item
    }
    if (!dry)
        StringToFile(PartFile(stem, parts), s + "]")
    return parts + 1
}

function ReadParts(stem, count)
{
    local arr = []
    for (local i = 0; i < count; i++)
    {
        local text = FileToString(PartFile(stem, i))
        if (text == null)
        {
            Say("Missing file tf/scriptdata/" + PartFile(stem, i))
            return null
        }
        arr.extend(compilestring(text)())
    }
    return arr
}

function SceneFile(name) { return "ss_" + name + ".nut" }

function SaveScene(name, dry = true)
{
    if (!ValidName(name) || IsVersionName(name) || name.find("__") != null)
    {
        Tell(null, "Save names: letters, digits and single _ (and not v<number>, that's a version).")
        return
    }
    local hdr = format("return { v = 3, map = \"%s\", demoNames = [", GetMapName())
    foreach (d in SS.demoNames)
        hdr += "\"" + d + "\","
    hdr += "], tracks = ["
    foreach (ti, t in SS.tracks)
    {
        local stem = name + "__t" + ti
        local parts = WriteParts(stem, t.frames, STRIDE, true, dry)
        // Projectiles: spawn, class number, samples, then the samples.
        local classes = []
        local flat = []
        foreach (p in t.projs)
        {
            local ci = classes.find(p.cls)
            if (ci == null)
            {
                ci = classes.len()
                classes.append(p.cls)
            }
            flat.extend([p.spawn, ci, p.path.len() / 6])
            flat.extend(p.path)
        }
        local pparts = flat.len() > 0 ? WriteParts(stem + "p", flat, 1, false, dry) : 0
        local ev = ""
        foreach (e in t.events)
        {
            ev += format("{ t = %d, type = \"%s\"", e.t, e.type)
            if ("ang" in e) ev += format(", ang = QAngle(%.4f, %.4f, 0)", e.ang.x, e.ang.y)
            if ("n" in e) ev += format(", n = %d", e.n)
            if ("by" in e) ev += format(", by = \"%s\"", e.by)
            if ("px" in e) ev += format(", px = %.2f, py = %.2f, pz = %.2f, vx = %.2f, vy = %.2f, vz = %.2f", e.px, e.py, e.pz, e.vx, e.vy, e.vz)
            ev += " },"
        }
        local wp = ""
        foreach (w in t.weapons)
            wp += format("{ slot = %d, cls = \"%s\", def = %d },", w.slot, w.cls, w.def)
        local cl = ""
        foreach (c in classes)
            cl += "\"" + c + "\","
        hdr += format("{ name = \"%s\", owner = %s, team = %d, cls = %d, start = %d, muted = %s, fireAt = %d, burst = %d, delay = %d, hpAfter = %d, parts = %d, pparts = %d, classes = [%s], weapons = [%s], events = [%s] },",
            t.name, Q(t.owner), t.team, t.cls, t.start, t.muted ? "true" : "false", t.fireAt, t.burst, t.delay, t.hpAfter, parts, pparts, cl, wp, ev)
    }
    hdr += "], shooter = "
    if (SS.shooter != null)
        hdr += format("{ pos = Vector(%.3f, %.3f, %.3f), target = \"%s\" }", SS.shooter.pos.x, SS.shooter.pos.y, SS.shooter.pos.z, SS.shooter.target)
    else
        hdr += "null"
    hdr += ", det = " + (SS.det != null ? "\"" + SS.det + "\"" : "null")
    // What changed when, so !cuts can still tell stale footage after loading.
    local modNames = []
    local mflat = []
    foreach (m in SS.mods)
    {
        local ni = modNames.find(m.track)
        if (ni == null)
        {
            ni = modNames.len()
            modNames.append(m.track)
        }
        mflat.extend([m.rev, ni, m.from, ("own" in m) ? 1 : 0])
    }
    local mparts = mflat.len() > 0 ? WriteParts(name + "__m", mflat, 4, false, dry) : 0
    hdr += format(", rev = %d, mparts = %d, modNames = [", SS.rev, mparts)
    foreach (mn in modNames)
        hdr += "\"" + mn + "\","
    hdr += "] }"
    if (hdr.len() > PART_BYTES)
    {
        Say("Scene header too big to save (too many events?); nothing was written.")
        return
    }
    if (dry)
    {
        SaveScene(name, false)     // it fits: now write the parts, then this header
        return
    }
    StringToFile(SceneFile(name), hdr)
    if (!dry)
        Say(format("Saved %d track(s) to tf/scriptdata/%s (+ parts).", SS.tracks.len(), SceneFile(name)))
}

/** A saved scene as { tracks, shooter, armed, demoNames, mods, rev }, or null. */
function LoadScene(name)
{
    if (!ValidName(name))
        return null
    local text = FileToString(SceneFile(name))
    if (text == null)
        return null
    local hdr = compilestring(text)()
    if (!("v" in hdr) || hdr.v != 3)
    {
        Say(name + " isn't a scene from this version of the script.")
        return null
    }
    local tracks = []
    foreach (ti, h in hdr.tracks)
    {
        local stem = name + "__t" + ti
        local frames = ReadParts(stem, h.parts)
        if (frames == null)
            return null
        local projs = []
        if (h.pparts > 0)
        {
            local flat = ReadParts(stem + "p", h.pparts)
            if (flat == null)
                return null
            local i = 0
            while (i + 2 < flat.len())
            {
                local len = flat[i + 2] * 6
                projs.append({ spawn = flat[i], cls = h.classes[flat[i + 1]], path = flat.slice(i + 3, i + 3 + len) })
                i += 3 + len
            }
        }
        tracks.append({
            name = h.name,
            owner = ("owner" in h) ? h.owner : ((("armed" in hdr) && hdr.armed == h.name) ? PlayerId(Me()) : null),
            team = h.team, cls = h.cls, weapons = h.weapons, start = h.start,
            frames = frames, events = h.events, projs = projs, muted = h.muted,
            fireAt = h.fireAt, burst = h.burst, delay = h.delay, hpAfter = h.hpAfter
        })
    }
    local mods = []
    if (hdr.mparts > 0)
    {
        local mflat = ReadParts(name + "__m", hdr.mparts)
        if (mflat == null)
            return null
        for (local i = 0; i + 3 < mflat.len(); i += 4)
        {
            local m = { rev = mflat[i], track = hdr.modNames[mflat[i + 1]], from = mflat[i + 2] }
            if (mflat[i + 3] != 0)
                m.own <- true
            mods.append(m)
        }
    }
    return { tracks = tracks, shooter = hdr.shooter, det = ("det" in hdr) ? hdr.det : null, demoNames = hdr.demoNames, mods = mods, rev = hdr.rev }
}

function LoadCmd(name)
{
    local scene = LoadScene(name)
    if (scene == null)
    {
        Say("Couldn't load " + name)
        return
    }
    EndRun(true)
    SS.tracks = scene.tracks
    SS.shooter = scene.shooter
    SS.det = scene.det
    SS.liveOnly = null
    SS.demoNames = scene.demoNames
    if (SS.liveDemo != null)
    {
        SS.demoNames.append(SS.liveDemo)          // the demo still recording
        SS.liveId = SS.demoNames.len() - 1
    }
    // Friends still recording go on being stamped.
    foreach (_id, m in SS.marks)
    {
        SS.demoNames.append(("name" in m) ? m.name : "unknown")
        m.id = SS.demoNames.len() - 1
    }
    SS.versions = []
    SS.redo = []
    SS.cps = []
    SS.mods = scene.mods
    local maxRev = scene.rev
    foreach (t in SS.tracks)
        for (local i = 0; i < Frames(t); i++)
            maxRev = Max(maxRev, Fv(t, i, F.REV))
    foreach (m in SS.mods)
        maxRev = Max(maxRev, m.rev)
    SS.rev = maxRev + 1
    Housekeep()
    Say(format("Loaded %s: %d track(s). Undo history cleared.", name, SS.tracks.len()))
}

function TrackByNameIn(list, name)
{
    foreach (t in list)
        if (t.name == name)
            return t
    return null
}

// ---- Info ------------------------------------------------------------------------

function Info(who = null)
{
    if (SS.tracks.len() == 0)
    {
        Tell(who, "No tracks yet. !new starts one (!shooter first if you want the Detonator bot).")
        return
    }
    local mine = who != null ? TrackOf(who) : null
    foreach (t in SS.tracks)
    {
        local ev = ""
        foreach (e in t.events)
            ev += format(" %s@%d", e.type, t.start + e.t)
        local shot = ""
        if (SS.shooter != null && SS.shooter.target == t.name)
            shot = format(", shooter fires %s, burst %d, %d after the airblast",
                t.fireAt >= 0 ? "at +" + t.fireAt + " and on !fire" : "on !fire", t.burst, Max(1, t.delay))
        if (SS.det != null)
            shot = SS.det == t.name ? format(", HAS THE DETONATOR (burst %d)", t.burst) : ""
        local h = OwnerPlayer(t)
        Tell(who, format("%s%s (%s): %s %s, ticks %d-%d, %d shots%s%s%s", t == mine ? "* " : "", t.name,
            h != null ? BotName(h) : "bot", TeamName(t.team), ClassName(t.cls), t.start, TrackEnd(t), t.projs.len(),
            t.muted ? ", MUTED" : "", shot, ev))
    }
    if (SS.liveOnly != null)
    {
        local l = ""
        foreach (n in SS.liveOnly)
            l += " " + n
        Tell(who, "Only these go live:" + l + " (!live all to undo that).")
    }
}

function Diag()
{
    local d = SS.diag
    printl(format("[stunt] ticks %d (clock %d, thinker %d), key latency %d, keys %s, errors %d %s",
        SS.ticks, d.fromClock, d.fromThinker, SS.lat, SS.inject ? "on" : "off", d.errors, d.lastError))
    printl("[stunt] " + d.last)
    local now = Time()
    foreach (h in Humans())
    {
        local id = PlayerId(h)
        local t = TrackOf(h)
        printl(format("[stunt]   human %s (%s): track %s, last command %s ticks ago", BotName(h), id, t != null ? t.name : "none",
            (id in SS.meSeen) ? "" + (SS.ticks - SS.meSeen[id]) : "?"))
    }
    foreach (name in NeededBots())
    {
        local b = FindBot(name)
        local seen = (name in SS.botSeen) ? format("%.2fs ago", now - SS.botSeen[name]) : "never"
        printl(format("[stunt]   bot %s: %s, thought %s", name, b == null ? "missing" : (b.IsAlive() ? "alive" : "dead"), seen))
    }
    Tell(null, "Diagnostics in the host's console.")
}

// Every command: name, how to type it, what it does. !help and the ss_ aliases use this.
::HELP <- [
    ["track", "!track <name> [red|blue]", "Play that track; a new one gets your class and that team. Your old track goes to a bot until someone takes it. Actors only hurt and push each other on opposite teams."],
    ["tracks", "!tracks", "List the tracks: who plays them, team, class, ticks, shots, shooter settings."],
    ["info", "!info", "Same as !tracks."],
    ["del", "!del <name>", "Delete a track (!undo brings it back)."],
    ["shift", "!shift <name> <n>", "Move a whole track n ticks later (negative: earlier), to time it against the others."],
    ["mute", "!mute <name>", "Leave a track out of the scene."],
    ["unmute", "!unmute <name>", "Put a muted track back in."],
    ["live", "!live <tracks|me|all>", "Who goes live on !new, !rw and !to; the others replay their take. Default: all. Without arguments: show it."],
    ["new", "!new [tick]", "New take for everyone on a team (or just !live), from where they stand, starting at that scene tick (default: where your track started, or 0)."],
    ["stop", "!stop", "End the take, or stop playing."],
    ["rw", "!rw [n]", "Go back n ticks (default 33): the scene replays a run-up with everyone following their recording, then you're live again."],
    ["to", "!to <tick>", "Like !rw, to a scene tick."],
    ["go", "!go", "Skip the frozen wait before a run (not the run-up)."],
    ["cp", "!cp", "Checkpoint at the current tick (during a take, or where the last one stopped)."],
    ["rr", "!rr", "Back to the last checkpoint (or the start of the take) and live again from there. Bind it: host bind r ss_rr, friends bind r "say !rr". Your good attempts join into one take."],
    ["uncp", "!uncp", "Remove the last checkpoint."],
    ["cps", "!cps", "List the checkpoints."],
    ["runup", "!runup <ticks>", "How much a rewind replays before you're live (default 66 = 1 s; 0 for quick retries)."],
    ["undo", "!undo", "Undo the last change (take, rewind, shift, join, delete...), for every track it touched."],
    ["redo", "!redo", "Redo what !undo undid."],
    ["versions", "!versions", "List the kept versions (v0 is the oldest)."],
    ["join", "!join <v#|file> <tick>", "Your track up to that tick, then that version (or your track in that saved file) after it."],
    ["save", "!save <name>", "Save the whole scene to tf/scriptdata/ss_<name>*.nut."],
    ["load", "!load <name>", "Load a saved scene (replaces this one, clears undo)."],
    ["shooter", "!shooter [track]", "Put the Detonator bot where you stand. It aims at your track (or that one); whoever reflects its flare live gets the burst."],
    ["noshooter", "!noshooter", "Take the Detonator bot out."],
    ["det", "!det <track|me|bot>", "Who has the Detonator: that track's actor fires with M1, and M2 with a reflected flare is the burst. bot: the shooter bot again."],
    ["fire", "!fire", "The shooter bot fires now, at whoever plays its target track: during a take (recorded) or between takes (practice). A new flare replaces one still flying; whoever reflects it live gets the burst. Bind it: host bind mouse4 ss_fire, friends bind mouse4 "say !fire""],
    ["fireat", "!fireat <n|off>", "When the shooter bot fires by itself in a new take, in ticks from its target track's start (default 66; off: only on !fire)."],
    ["burst", "!burst <n>", "Detonations in the burst tick (default 24; 7 reaches the speed cap)."],
    ["delay", "!delay <n>", "Shooter bot: ticks from the airblast to the burst (default 2, at least 1)."],
    ["hpafter", "!hpafter <hp>", "Health right after the burst (0: what they had before it)."],
    ["play", "!play", "Watch the whole scene through your track's eyes (you follow your recording; hands off)."],
    ["render", "!render [demo]", "Like !play, recorded as one demo on the host's PC, from the host's view."],
    ["spec", "!spec [track] [demo]", "Host only: watch a track first-person from spectator, optionally recorded."],
    ["demo", "!demo [name]", "Host only: record a demo of the live takes (!cuts finds them in it)."],
    ["demostop", "!demostop", "Host only: stop that demo."],
    ["cuts", "!cuts", "Which demo tick ranges make up your track, and which are stale. Also in tf/scriptdata/ss_cuts.txt."],
    ["demooffset", "!demooffset <n>", "If every cut is off by the same tick or two, shift new footage by this much (a friend with !mark on sets their own)."],
    ["mark", "!mark <demo>|off", "For friends: your own demo just started, or stopped: bind k \"record mypov; hud_saytext_time 0; say !mark mypov\" and bind j \"stop; hud_saytext_time 12; say !mark off\". Script messages then go to your console only."],
    ["diag", "!diag", "Diagnostics in the host's console."],
    ["keys", "!keys", "Host only: let go of every key the script pressed."],
    ["inject", "!inject on|off", "Host only: whether replaying presses your keys through your client."],
    ["help", "!help [command]", "List the commands, or explain one."],
]

/** To one player: chat (unless a demo is recording) and always their console. */
function Tell(who, msg)
{
    if (who == null)
        who = Me()
    if (!QuietFor(who))
        ClientPrint(who, Constants.EHudNotify.HUD_PRINTTALK, "\x07FFD700[stunt] \x01" + msg)
    ClientPrint(who, Constants.EHudNotify.HUD_PRINTCONSOLE, "[stunt] " + msg + "\n")
}

function Help(arg = null, who = null)
{
    if (who == null)
        who = Me()
    if (arg != null)
    {
        local name = arg.slice(0, 1) == "!" ? arg.slice(1) : arg
        foreach (h in HELP)
        {
            if (h[0] == name.tolower())
            {
                Tell(who, h[1] + "  -  " + h[2])
                return
            }
        }
        Tell(who, "No command " + arg + ". !help lists them.")
        return
    }
    // Short list in chat, a few commands per line; everything with descriptions in the console.
    local line = ""
    foreach (h in HELP)
    {
        if (line.len() + h[1].len() > 110)
        {
            Tell(who, line)
            line = ""
        }
        line += (line.len() > 0 ? "   " : "") + h[1]
    }
    if (line.len() > 0)
        Tell(who, line)
    Tell(who, "!help <command> explains one. From the console: say !rw 20" + (who == Me() ? ", or ss_<command> without arguments." : "."))
    foreach (h in HELP)
        ClientPrint(who, Constants.EHudNotify.HUD_PRINTCONSOLE, format("  %-26s %s\n", h[1], h[2]))
}


// ---- Commands ----------------------------------------------------------------

/** !cp: this tick is a checkpoint; !rr goes back to the last one. */
function Checkpoint(who)
{
    local r = SS.run
    if (r != null && !r.live)
    {
        Tell(who, "Not live yet: set the checkpoint once you're recording (or after !stop).")
        return
    }
    local s = r != null ? r.s : SS.cursor
    if (SS.cps.len() > 0 && SS.cps.top() >= s)
    {
        Tell(who, format("There's already a checkpoint at tick %d or later (!uncp removes it).", SS.cps.top()))
        return
    }
    SS.cps.append(s)
    Say(format("Checkpoint %d at tick %d. !rr goes back to it.", SS.cps.len(), s))
}

/** !rr: back to the last checkpoint (or the start of your take), everyone live from there. */
function ResetToCp(who)
{
    local t = TrackOf(who)
    local to = SS.cps.len() > 0 ? SS.cps.top() : (t != null && Frames(t) > 0 ? t.start : SceneStart())
    Rewind(to)
}

function ListCps()
{
    if (SS.cps.len() == 0)
    {
        Say("No checkpoints: !cp sets one at the current tick.")
        return
    }
    local l = ""
    foreach (i, c in SS.cps)
        l += format(" %d:%d", i + 1, c)
    Say("Checkpoints (number:tick):" + l)
}

/** !live <tracks|me|all>: who goes live on !new, !rw and !to. */
function SetLive(args, who)
{
    if (args.len() < 2)
    {
        Info(who)
        return
    }
    if (args[1] == "all")
    {
        SS.liveOnly = null
        Say("Everyone goes live.")
        return
    }
    local list = []
    for (local i = 1; i < args.len(); i++)
    {
        local t = args[i] == "me" ? TrackOf(who) : TrackByName(args[i])
        if (t == null)
        {
            Say("No track " + args[i] + " (!tracks).")
            return
        }
        list.append(t.name)
    }
    SS.liveOnly = list
    local l = ""
    foreach (n in list)
        l += " " + n
    Say("Only these go live now:" + l + ". The rest replay.")
}

/** !mark <demo>: a friend's own `record` just started, so !cuts can find their footage. */
function Mark(name, who)
{
    local id = PlayerId(who)
    if (who == Me())
    {
        Tell(who, "The host records with !demo (or !render), not !mark.")
        return
    }
    if (name == "off")
    {
        if (id in SS.marks)
            delete SS.marks[id]
        Tell(who, "Marked as not recording; messages are back.")
        return
    }
    if (!ValidName(name))
    {
        Tell(who, "Demo names: letters, digits and _.")
        return
    }
    if (id in SS.marks)
    {
        Tell(who, "You're already marked as recording (!mark off first).")
        return
    }
    if (SS.demoNames.find(name) != null)
    {
        Tell(who, name + " was used already (record would overwrite it): pick another name, e.g. " + name + "2.")
        return
    }
    SS.demoNames.append(name)
    SS.marks[id] <- { id = SS.demoNames.len() - 1, start = Time(), name = name }
    printl("[stunt] " + BotName(who) + " is recording " + name)
}

function SS_Cmd(text, who = null)
{
    local args = split(text, " ", true)
    if (args.len() == 0)
        return false
    local c = args[0].tolower()
    local arg = args.len() > 1 ? args[1] : null
    local arg2 = args.len() > 2 ? args[2] : null
    if (who == null)
        who = Me()
    if (who == null)
        return false
    SS.group++

    if (c == "!track" && arg != null)      ArmTrack(arg, arg2, who)
    else if (c == "!tracks")               Info(who)
    else if (c == "!del" && arg != null)   DeleteTrack(arg)
    else if (c == "!shift" && arg2 != null) Shift(arg, ToInt(arg2, 0))
    else if (c == "!mute" && arg != null)  SetMuted(arg, true)
    else if (c == "!unmute" && arg != null) SetMuted(arg, false)
    else if (c == "!new")                  NewTake(arg, who)
    else if (c == "!stop")                 EndRun(false)
    else if (c == "!go")
    {
        if (SS.run != null && SS.run.freeze > 0)
        {
            // Keep the last frozen tick(s): that's when the bots and your keys get the
            // first tick's buttons.
            SS.run.freeze = Min(SS.run.freeze, Max(1, Lat()))
            StartRunDemo(SS.run)
        }
    }
    else if (c == "!rw")
    {
        local t = TrackOf(who)
        local r = SS.run
        local end = null
        foreach (x in SS.tracks)
            if (Frames(x) > 0 && !x.muted && OwnerPlayer(x) != null && IsLiveTrack(x))
                end = end == null ? TrackEnd(x) : Max(end, TrackEnd(x))
        if (end == null)
            end = t != null && Frames(t) > 0 ? TrackEnd(t) : SceneEnd()
        local from = r != null && r.live ? r.s : (r != null && r.p != null ? r.p : end)
        Rewind(from - ToInt(arg, 33))
    }
    else if (c == "!to" && arg != null)    Rewind(ToInt(arg, 0))
    else if (c == "!undo")                 Undo()
    else if (c == "!redo")                 Redo()
    else if (c == "!versions")
    {
        foreach (i, v in SS.versions)
        {
            if (v.copy != null)
                Say(format("v%d: %s, ticks %d-%d", i, v.name, v.copy.start, TrackEnd(v.copy)))
            else
                Say(format("v%d: %s didn't exist", i, v.name))
        }
        if (SS.versions.len() == 0)
            Say("No versions kept yet.")
    }
    else if (c == "!join" && arg2 != null) Join(arg, ToInt(arg2, 0), who)
    else if (c == "!save" && arg != null)  SaveScene(arg)
    else if (c == "!load" && arg != null)  LoadCmd(arg)
    else if (c == "!shooter")              PlaceShooter(who, arg)
    else if (c == "!fire")
    {
        if (SS.shooter == null || SS.det != null)
            Say("No shooter bot: !shooter places one" + (SS.det != null ? " (with !det, the Detonator is " + SS.det + "'s)." : "."))
        else
            SS.fireNow = true
    }
    else if (c == "!cp")                   Checkpoint(who)
    else if (c == "!rr")                   ResetToCp(who)
    else if (c == "!uncp")
    {
        if (SS.cps.len() > 0)
            Say(format("Removed the checkpoint at tick %d.", SS.cps.pop()))
        ListCps()
    }
    else if (c == "!cps")                  ListCps()
    else if (c == "!runup" && arg != null)
    {
        SS.runup = Max(0, ToInt(arg, RUNUP_TICKS))
        Say(format("Rewinds replay %d ticks (%.1fs) before you're live (more if something is in the air then).", SS.runup, SS.runup * TICK))
    }
    else if (c == "!det")                  SetDet(arg, who)
    else if (c == "!live")                 SetLive(args, who)
    else if (c == "!mark" && arg != null)  Mark(arg, who)
    else if (c == "!noshooter")            { EndRun(true); SS.shooter = null; AddMod(SHOOTER_NAME, ALL_TICKS); Housekeep(); Say("Shooter removed.") }
    else if (c == "!fireat" && arg != null)  SetShot("fireAt", arg == "off" ? -1 : ToInt(arg, 66), who)
    else if (c == "!burst" && arg != null)   SetShot("burst", Clamp(ToInt(arg, 24), 0, 200), who)
    else if (c == "!delay" && arg != null)   SetShot("delay", Max(1, ToInt(arg, 2)), who)
    else if (c == "!hpafter" && arg != null) SetShot("hpAfter", Max(0, ToInt(arg, 0)), who)
    else if (c == "!play")                 Play(null)
    else if (c == "!render")               Play(arg != null ? arg : "stunt_render")
    else if (c == "!spec")                 Spec(arg, arg2, who)
    else if (c == "!demo")
    {
        if (who != Me())
            Say("!demo records on the host's PC. For your own view: bind k \"record clip2; say !mark clip2\"")
        else
            StartLiveDemo(arg != null ? arg : "stunt_live")
    }
    else if (c == "!cuts")                 Cuts(who)
    else if (c == "!demooffset" && arg != null)
    {
        local id = PlayerId(who)
        if (who != Me() && (id in SS.marks))
        {
            SS.marks[id].off <- ToInt(arg, 1)
            Tell(who, "Your demo offset: " + SS.marks[id].off + " (for new footage).")
        }
        else
        {
            SS.demoOffset = ToInt(arg, 1)
            Tell(who, "Demo offset " + SS.demoOffset + " (for new footage).")
        }
    }
    else if (c == "!info")                 Info(who)
    else if (c == "!diag")                 Diag()
    else if (c == "!help")                 Help(arg, who)
    else if ((c == "!keys" || c == "!inject" || c == "!demostop") && who != Me())
        Say(c + " acts on the host's PC, so only the host can use it.")
    else if (c == "!demostop")             StopLiveDemo()
    else if (c == "!keys")
    {
        SS.injected = 0
        SendToConsole("-forward;-back;-moveleft;-moveright;-jump;-duck;-attack;-attack2;-attack3;-reload;-alt2")
        Say("Let go of every key (press your keys again).")
    }
    else if (c == "!inject" && arg != null)
    {
        SS.inject = arg == "on"
        SS.lat = -1
        Say("Keys through your client: " + (SS.inject ? "on (measured on the next run)" : "off"))
    }
    else
    {
        foreach (h in HELP)
        {
            if ("!" + h[0] == c)
            {
                Help(h[0], who)
                return true
            }
        }
        return false
    }
    return true
}

// ---- Bots and thinkers -----------------------------------------------------------

function NeededBots()
{
    local names = []
    if (SS.shooter != null && SS.det == null)
        names.append(SHOOTER_NAME)
    foreach (t in SS.tracks)
        if (!t.muted && Frames(t) > 0 && !HumanPlays(t, SS.run))
            names.append(t.name)
    return names
}

function BotsReady()
{
    local now = Time()
    foreach (name in NeededBots())
        if (!(name in SS.botWarned) && (FindBot(name) == null || !(name in SS.botActing) || now - SS.botActing[name] > 0.1))
            return false
    return true
}

/** Ask for bot `name` to be added if it isn't there (not more than every 3 s). */
function AskBot(name, team, cls)
{
    if (FindBot(name) != null)
        return
    local now = Time()
    if (name in SS.botAsked && now - SS.botAsked[name] < 3.0)
        return
    // A bot can't have a name someone here has: the game would call it (1)name, we'd never
    // find it and we'd keep adding more.
    local lower = name.tolower()
    local clash = false
    for (local i = 1; i <= MaxClients().tointeger(); i++)
    {
        local p = PlayerInstanceFromIndex(i)
        if (p == null)
            continue
        local pn = BotName(p).tolower()
        if (!p.IsFakeClient() && pn == lower)
            clash = true
        else if (p.IsFakeClient() && pn.len() > lower.len() + 2 && pn.slice(0, 1) == "(" && pn.slice(pn.len() - lower.len()) == lower)
            SendToConsole("kick \"" + BotName(p) + "\"")   // our own duplicate, renamed by the game
    }
    if (!clash && (name in SS.botWarned))
        delete SS.botWarned[name]
    if (clash)
    {
        if (!(name in SS.botWarned))
            Say("\x07FF4040Track " + name + " has a player's name\x01, so no bot can act it out. Use a different track name.")
        SS.botWarned[name] <- true
        return
    }
    if (!Convars.GetBool("sv_cheats"))
    {
        if (!SS.cheatWarned)
            Say("Bots need sv_cheats 1 (turning it back on).")
        SS.cheatWarned = true
        SendToConsole("sv_cheats 1")
    }
    SS.botAsked[name] <- now
    ::SS_BOTS[name] <- true
    SendToConsole(format("bot -team %s -class %s -name %s", TeamName(team), ClassName(cls), name))
}



function AttachThink(bot)
{
    bot.ValidateScriptScope()
    bot.GetScriptScope().SS_BotThink <- SS_BotThink
    AddThinkToEnt(bot, "SS_BotThink")
}

function AttachMeThink(h)
{
    h.ValidateScriptScope()
    h.GetScriptScope().SS_MeThink <- SS_MeThink
    AddThinkToEnt(h, "SS_MeThink")
    SS.meSeen[PlayerId(h)] <- SS.ticks
}

/** Every bot of ours thinks inside its own command, before it moves or shoots, at the
 *  start of the server tick. */
function SS_BotThink()
{
    try
    {
        SS.botSeen[BotName(self)] <- Time()
        BotStep(self)
    }
    catch (e)
        ReportError(e)
    return -1
}

function Housekeep()
{
    local now = Time()
    foreach (h in Humans())
    {
        local id = PlayerId(h)
        if (!(id in SS.meSeen) || SS.ticks - SS.meSeen[id] > 20)
            AttachMeThink(h)
    }
    foreach (h in Humans())
    {
        local id = PlayerId(h)
        if (id.slice(0, Min(5, id.len())) == "name:" || TrackOfId(id) != null)
            continue
        local byName = TrackOfId("name:" + BotName(h))
        if (byName != null)
            byName.owner = id
    }
    local needed = NeededBots()
    foreach (name in needed)
    {
        local t = TrackByName(name)
        if (t != null)
            AskBot(name, t.team, t.cls)
        else
        {
            local st = SS.shooter != null ? TrackByName(SS.shooter.target) : null
            AskBot(name, st != null ? EnemyTeam(st.team) : 3, TF_CLASS_PYRO)
        }
        local b = FindBot(name)
        if (b != null && (!(name in SS.botSeen) || now - SS.botSeen[name] > 0.3) &&
            (!(name in SS.botAttach) || now - SS.botAttach[name] > 0.5))
        {
            AttachThink(b)
            SS.botAttach[name] <- now
        }
    }
    // A friend who left can't turn their !mark off.
    local gone = []
    foreach (id, _m in SS.marks)
        if (PlayerById(id) == null)
            gone.append(id)
    foreach (id in gone)
        delete SS.marks[id]
    // Bots nobody needs anymore leave: no bots unless a track has no human.
    foreach (name, _v in ::SS_BOTS)
    {
        if (needed.find(name) == null && FindBot(name) != null &&
            (!(name in SS.botAsked) || now - SS.botAsked[name] >= 3.0))
        {
            SS.botAsked[name] <- now
            SendToConsole("kick " + name)
        }
    }
}

/** The thinker runs during the tick: housekeeping, and it schedules SS_Clock, which
 *  runs the scene's tick. */
function SSThink()
{
    try
    {
        if (Me() == null)
            return 0.1
        // The scene's tick runs from the event queue, right after every player and
        // projectile has moved this tick and before the next tick's commands.
        EntFireByHandle(self, "CallScriptFunction", "SS_Clock", 0.0, null, null)
        if (Time() - SS.clockAt > 1.5 * TICK && Time() != SS.masterTime)
            TickStart(true)         // the event didn't come
        local r = SS.run
        if (SS.ticks % (r != null && !r.started ? 5 : 33) == 0)
            Housekeep()
    }
    catch (e)
        ReportError(e)
    return -1
}

function SS_Clock()
{
    SS.clockAt = Time()
    SS.inTick = true
    try
    {
        TickStart(false)
    }
    catch (e)
        ReportError(e)
    SS.inTick = false
}

// ---- Events ------------------------------------------------------------------

ClearGameEventCallbacks()

function OnGameEvent_player_say(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p != null && !p.IsFakeClient())
        SS_Cmd(params.text, p)
}

function OnScriptHook_OnTakeDamage(params)
{
    local victim = params.const_entity
    if (victim == null || !victim.IsPlayer())
        return
    // The actor's own detonation right after a burst is already counted in it.
    local inflictor = params.inflictor
    if (SS.burstTick == SS.ticks && inflictor != null && inflictor == SS.burstFlare)
    {
        params.damage = 0
        params.early_out = true
        return
    }
    if (!victim.IsFakeClient())
    {
        if (NO_FALL_DAMAGE && (params.damage_type & DMG_FALL))
        {
            params.damage = 0
            params.early_out = true
            return
        }
        // Frozen, or following a recording: don't die of something new. (Normally
        // PREVENT_DEATH covers it; this is for a second lethal hit in the same tick.)
        local a = ActorOf(victim)
        local guarded = a != null && !a.out && (SS.run.freeze > 0 || !a.live)
        if (guarded && !victim.InCond(PREVENT_DEATH) && params.damage * 3 >= victim.GetHealth())
        {
            params.damage = 0
            params.early_out = true
        }
        return
    }
    // Our bots never die (that would put a ragdoll and the kill feed in the clip).
    if (victim.IsFakeClient() && !victim.InCond(PREVENT_DEATH) && params.damage * 3 >= victim.GetHealth())
    {
        local n = BotName(victim)
        if (n == SHOOTER_NAME || TrackByName(n) != null)
            params.damage = Max(0.0, (victim.GetHealth() - 1) / 3.0)
    }
}

__CollectGameEventCallbacks(this)

// Console aliases: ss_new, ss_rw, ss_go, ... (no arguments; chat or SS_Cmd for the rest).
foreach (h in HELP)
{
    local c = h[0]
    getroottable()["SS_Cmd_" + c] <- (function(c) { return function() { SS_Cmd("!" + c) } })(c)
    SendToConsole(format("alias ss_%s \"script SS_Cmd_%s()\"", c, c))
}

// ---- Setup -------------------------------------------------------------------

SendToConsole("sv_cheats 1")                  // puppet bots
SendToConsole("mp_waitingforplayers_cancel 1")
SendToConsole("mp_autoteambalance 0")
SendToConsole("mp_teams_unbalance_limit 0")
SendToConsole("tf_weapon_criticals 0")        // same damage and knockback every time
SendToConsole("tf_damage_disablespread 1")
SendToConsole("mp_respawnwavetime 0")
SendToConsole("-forward;-back;-moveleft;-moveright;-jump;-duck;-attack;-attack2;-attack3;-reload;-alt2")
if (SS.run != null)
{
    try { EndRun(true) } catch (e) { SS.run = null }
}
SS.injected = 0
SS.botAsked = {}
SS.botSeen = {}
SS.botAttach = {}
SS.meSeen = {}
foreach (h in Humans())
    FreeMe(h)

local oldThinker = Entities.FindByName(null, "ss_thinker")
if (oldThinker != null)
    oldThinker.Kill()
local thinker = SpawnEntityFromTable("info_target", { targetname = "ss_thinker" })
thinker.ValidateScriptScope()
thinker.GetScriptScope().SSThink <- SSThink
thinker.GetScriptScope().SS_Clock <- SS_Clock
AddThinkToEnt(thinker, "SSThink")
Housekeep()

Say("Loaded. !new records everyone here (!shooter first for the Detonator bot); !help for everything.")
