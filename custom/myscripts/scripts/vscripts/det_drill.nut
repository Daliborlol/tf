// Detonator drill. Each scenario puts you at a start spot with either
//   - a glowing enemy Sniper to hit with the Detonator, or
//   - enemy stickies to destroy (Detonator explosions get them around corners).
// Hit the Sniper / clear the stickies and you move on to the next scenario.
//
// Usage: `map koth_product_final` (or koth_viaduct), join either team as Pyro with
// the Detonator, then `script_execute det_drill`. The enemies are always on the
// other team, and the control point can't be captured.
//
// No cheats needed (the bots are normal TFBots, held in place, not allowed to
// fire, ignoring you), so with FAKE_LAG = 0 your class playtime counts.
// (Puppet bots need sv_cheats, and once cheats were on, TF2 stops counting
// playtime for the rest of the map, so they're not an option.)
//
// Chat commands:
//   !reset             back to the start of the current scenario (numpad 7)
//   !next / !prev      skip to another scenario
//   !goto <number>     jump to that scenario (numbers as in !list / the HUD message)
//   !new               add a scenario starting where you stand, and edit it (below)
//   !duplicate         copy this scenario and edit the copy; the original stays as it is
//   !edit              edit this scenario: walk around freely, the spots are shown
//                      as boxes (blue = you, red = enemy, grey = where a spot was
//                      before you moved it); no peek deaths, hits don't count
//   !done              stop editing and play the scenario
//   !setme             save where you stand (and look) as this scenario's start
//   !setenemy          make this an enemy scenario, enemy where you stand
//   !class <name>      enemy class: scout, soldier, pyro, demoman, heavy, engineer,
//                      medic, sniper, spy (!class alone = next one). Only a Sniper
//                      kills you for peeking him.
//   !addsticky         make this a sticky scenario, add a sticky where you aim
//                      (floor, wall or ceiling, whatever your crosshair is on)
//   !undosticky        remove the last sticky you added
//   !clearstickies     remove all stickies from this scenario
//   !delete            remove this scenario (and its mirrored copy)
//   !list              show how many scenarios there are and where you are, how many
//                      are due for spaced repetition and how many review spots are left
//   !help              list all commands in the console (det_help)
//   !checklos          plays every Sniper scenario for SCAN_TIME by itself (don't
//                      touch anything) and remembers the ones where his sight would
//                      kill you. !checklos again stops it.
//   !losnext           edit the next bad one (!setme somewhere safe, !done = next)
//   !review            switch to/from the review list: spots found in your demos
//                      (tf/scriptdata/det_drill_review_<map>.nut), in order, not mirrored
//   !keep              (in review) save this spot into your own scenarios, starting
//                      where you stand now (move first to adjust it). The Sniper
//                      doesn't kill you for peeking while you review.
//   !review_restart    (in review) start the review list from the first spot again
//   !tp                fly to where your last flare blew up (noclip) to see how
//                      close it was; !reset puts you back (numpad 9)
//   !zeroping          with !set ping on: switch the explosion box between where it
//                      would have blown up with your ping and at 0 ping. In the !tp
//                      view you stay where you are, only the box moves
//   !set / !settings   list the settings (trail, glow, hardcore, ...) in the console;
//                      !set <name> <value> changes one (saved for next time)
//   !stats             your stats for this map, this session and all time (console)
//   !stats_reset       start this map's all-time stats over (per-scenario ones too)
//   !stats_rebuild     rebuild the per-scenario stats (hardest list, spaced repetition)
//                      from this map's session logs (since the last !stats_reset)
//   !spot              this scenario's card (chat + console): tries, first-flare rate,
//                      best time, timing bias / spread, why you miss it, its spaced
//                      repetition box and whether it's due
//   !session           this session's card (chat + console): attempts, active minutes,
//                      first-flare rate against your last 5 sessions here, hits, timing
//                      bias / spread, your worst 3 spots this session, what's due
//                      (also at the end of !stats)
//   !log               this session's log (every attempt and flare, for the offline
//                      dashboard): tf/scriptdata/det_drill_log_<map>_<session>.txt
//
// Every command also works from the console without chat: script Det("tp"),
// script Det("next"), ... (see DrillCommand below).
//
// You only set up scenarios on one side: each one is also played mirrored on the
// other half of the map (MIRROR below). Editing a mirrored copy edits the original.
//
// Scenarios come from SCENARIOS below. In-game edits are saved per map to
// tf/scriptdata/det_drill_<map>.nut and used instead; delete that file to go back.

// ---- Settings ----------------------------------------------------------------

const ENEMY_NAME = "det_enemy"
const DEMO_NAME = "det_demo"    // owns the stickies; stays in his spawn, invulnerable
// The ones marked (!set) are only defaults: change them in game with !set <name> <value>.
// What you set there is saved in tf/scriptdata/det_drill_settings.txt and wins over these.
const GLOW_COLOR = "255 215 0"  // (!set glow_color) the enemy's outline, "r g b"
const NEXT_DELAY = 0.8          // seconds between finishing and the next scenario
const RANDOM_ORDER = true       // (!set random) random scenario (each once per round) or in order
const FAKE_LAG = 0              // net_fakelag; your ping ends up ~2x this. 0 = off.
                                // net_fakelag is a cheat: > 0 turns sv_cheats on (no hours)
const DETONATOR_ONLY = true     // only flare gun hits on the Sniper count (Detonator is one)
const MIRROR = true             // (!set mirror) also play every scenario mirrored on the other side
                                // (only on maps whose mirror line is known, see Mirrors():
                                // Product, Viaduct, Ashville)
const SPAWN_LIFT = 12           // place you and the Sniper this many units above the saved spot
                                // so nobody gets stuck in the floor (you drop the rest)
const STICKY_LIFT = 8           // stickies start this far off their surface and fly into it
const STICKY_REACH = 3000       // how far away you can place a sticky by aiming
const MASK_SOLID_BRUSHONLY = 16395   // world geometry only: players don't block the aim trace
const GLOW = "shot"             // (!set glow) how long the enemy glows: "shot" = until you fire
                                // (remember where he is), "always", "off", or seconds after
                                // you're placed, like "0.5" (gone earlier if you fire)
const SCAN_TIME = 2.0           // !checklos: seconds to stand at each start
const PEEK_TIME = 1.0           // (!set peek_time; !set peek off = no peek rule) Sniper scenarios:
                                // seen by the Sniper this long and he kills you. Time out of
                                // sight counts it back down.
const SPOTTED_SOUND = "TFPlayer.ReCharged"   // (!set sound) when he gets sight of you ("off");
                                // !sound tries others. Dodgeball
                                // sounds: .FireRocket (rocket launch), .Alert (sentry_spot), .AlertTarget
const MASK_SHOT = 1174421507    // what bullets hit: world, props, players
const AIM_OFF_MIN = 10.0        // each attempt starts with your view turned 10-25 degrees off the
const AIM_OFF_MAX = 25.0        // saved aim, left or right at random, so you can't just click
const AIM_OFF_PITCH = 10.0      // ...and up to this much up/down. (!set aim_offset off) turns it off
const DET_RADIUS = 110          // flare explosion radius (Detonator/Scorch Shot, TF2 wiki):
                                // drawn as a cube around the explosion while you're in !tp
const OVERLAY_LIFE = 0.1        // redrawn overlays last this long (a little over a tick
                                // flickers: the next redraw can arrive after it's gone)
const TP_BACK = 64              // !tp puts you this far behind the explosion, seen from the target
const MAX_STICKIES = 8          // a sticky launcher holds 8; more would pop the oldest
const TRAIL = true              // (!set trail) draw the path of your flares
const BOOM = "mark"             // (!set boom) where a flare blew up: "mark" (small box), "radius"
                                // (the DET_RADIUS cube), "off". !tp always shows the radius.
const TRAIL_TIME = 4.0          // seconds a flare's path stays on screen (cleared on a new scenario)
const HARDCORE = false          // (!set hardcore) screen goes black from your shot until the flare
                                // is gone: detonate by timing alone
const COLLIDE = false           // (!set collide) flares can hit the enemy directly. Off: they fly
                                // through players, so only a detonation (or a wall) hits him;
                                // one that would have hit him plays DIRECT_SOUND and says so
const WALL_WARN = true          // (!set wall_warn) beep + say so when a flare hits a wall or the
                                // ground before you detonate it
const FLARE_INFO = true         // (!set flare_info) one chat line after each detonation: how early /
                                // late it was against the hit window (the stretch of the flare's
                                // path where the blast would have reached the target)
const WINDOW_REACH = 3000.0     // the hit window is looked for this far back / ahead along the path
const WALL_SOUND = "Player.DenyWeaponSelection"   // the "can't switch to that weapon" buzz
const DIRECT_SOUND = "Hud.Hint"                   // soft chime: a flare hit the enemy directly
const FLARE_PAD = 2.0          // a flare's half size, for "it flew through him" (collide off)
const MAX_DARK = 5.0            // hardcore: the screen comes back after this long at most
const PING = 0.0                // (!set ping) pretend you have this ping (ms), no cheats needed:
                                // your mouse2 is held back and the script detonates the flare
                                // this much later, as a server would get it. Flares aren't lag
                                // compensated, so that's all ping does to them; the game itself
                                // then does the explosion, fire, hitsound, hits. !zeroping shows
                                // where it would have blown up at 0 ping. 0 = off.
const AFK_TIME = 5.0            // (!set afk) this many seconds without any input (keys, mouse)
                                // and you're AFK: that time is left out of !stats times. 0 = off
const FOCUS = false             // (!set focus) pick the next scenario by need instead of the random
                                // bag / in order: the lower your (estimated) first-flare rate on a
                                // spot and side, the more often it comes up, more still when it's
                                // due for spaced repetition (see AggWeight)
const FATIGUE_NUDGE = true      // (!set fatigue_nudge) once a session, after FATIGUE_MIN of your own
                                // attempts: a chat line when the first-flare rate of the last
                                // FATIGUE_LAST is FATIGUE_DROP (or more) below the session's before them

// Settings you can change in game (!set). [name, default, what it does]
::OPTIONS <- [
    ["trail", TRAIL, "draw your flares' paths"],
    ["boom", BOOM, "where a flare blew up: mark (small box), radius (blast cube), off; !tp always shows the radius"],
    ["glow", GLOW, "how long the enemy glows: shot (until you fire), always, off, or seconds (e.g. 0.5)"],
    ["glow_color", GLOW_COLOR, "outline colour: \"r g b\" or yellow, red, green, blue, cyan, purple, pink, orange, white"],
    ["peek", PEEK_TIME > 0, "Sniper sight rule: spotted sound, and he kills you after peek_time"],
    ["peek_time", PEEK_TIME > 0 ? PEEK_TIME : 1.0, "seconds the Sniper has to see you"],
    ["sound", SPOTTED_SOUND == "" ? "off" : SPOTTED_SOUND, "spotted sound: off or a sound name (!sound cycles through some)"],
    ["hardcore", HARDCORE, "black screen from your shot until the flare is gone: detonate by timing"],
    ["collide", COLLIDE, "flares can hit the enemy directly (off: they fly through him, with a chime + message, and only the blast counts)"],
    ["wall_warn", WALL_WARN, "beep + chat when a flare hits a wall / the ground before you detonate"],
    ["flare_info", FLARE_INFO, "chat line after each detonation: ms early / late against the hit window, how far outside"],
    ["aim_offset", AIM_OFF_MAX > 0, "start each attempt with your aim thrown off a bit"],
    ["random", RANDOM_ORDER, "scenarios in random order"],
    ["mirror", MIRROR, "also play every scenario mirrored (Product, Viaduct, Ashville)"],
    ["ping", PING, "pretend ping (ms): your detonation goes off that much later, like on a server (!zeroping: box at 0 ping); 0 = off"],
    ["afk", AFK_TIME, "seconds without input before you count as AFK (left out of the !stats times); 0 = off"],
    ["focus", FOCUS, "next scenario by need: weaker spots (and ones due for spaced repetition) come up more often; off = random / in order"],
    ["fatigue_nudge", FATIGUE_NUDGE, "once a session: say so when your 1st-flare rate drops (last 15 attempts vs the session before them), maybe take a break"],
]
::Opt <- {}
foreach (o in OPTIONS)
    Opt[o[0]] <- o[1]

// Your scenarios (one side of the map only). Format:
//   { me = { pos = Vector(x, y, z), ang = QAngle(pitch, yaw, 0) },
//     enemy = { pos = Vector(x, y, z), ang = QAngle(pitch, yaw, 0) },   // Sniper scenario
//     stickies = [] },
//   { me = ..., enemy = null, stickies = [{ pos = Vector(x, y, z), n = Vector(nx, ny, nz) }, ...] },
//   (a sticky is the spot on the surface plus the direction the surface faces)
::SCENARIOS <- [
]

// koth_viaduct / koth_product_final are mirror images across the line through
// the control point (y = 0): same x and height, y flipped, view direction flipped.
// (Checked against the map files: 102 of 109 item/spawn positions match.)
// koth_ashville halves aren't mirror images but a half turn of each other around
// (ASHVILLE_X, 0), next to the point: x and y flipped around it, view turned 180.
// (Checked against final1 and final2: every item/spawn pair outside the middle matches.)
const ASHVILLE_X = -50

/** Mirroring is only checked for koth_product / koth_viaduct (y = 0) and koth_ashville. */
function Mirrors()
{
    local map = GetMapName()
    return Opt.mirror && !Drill.reviewing
        && (map.find("koth_product") == 0 || map.find("koth_viaduct") == 0 || HalfTurn())
}

/** The other side is a half turn of this one (koth_ashville), not a mirror image. */
function HalfTurn() { return GetMapName().find("koth_ashville") == 0 }

::CLASS_NAMES <- ["", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"]
const SNIPER = 2   // Constants.ETFClass.TF_CLASS_SNIPER

/** The current scenario's enemy class (old saves: Sniper). */
function EnemyClass()
{
    if (Drill.scenarios.len() == 0)
        return SNIPER
    local o = Original()
    return "cls" in o ? o.cls : SNIPER
}

function MirrorVec(v) { return HalfTurn() ? Vector(2 * ASHVILLE_X - v.x, -v.y, v.z) : Vector(v.x, -v.y, v.z) }
/** A direction (sticky surface normal): turned/flipped like a position, but not moved. */
function MirrorDir(v) { return HalfTurn() ? Vector(-v.x, -v.y, v.z) : Vector(v.x, -v.y, v.z) }
function MirrorSticky(st) { return { pos = MirrorVec(st.pos), n = MirrorDir(st.n) } }
function MirrorSpot(spot)
{
    if (spot == null)
        return null
    local yaw = HalfTurn() ? spot.ang.y + 180 : -spot.ang.y
    if (yaw > 180)
        yaw -= 360
    return { pos = MirrorVec(spot.pos), ang = QAngle(spot.ang.x, yaw, 0) }
}

// ---- State -------------------------------------------------------------------

/** Statistics counters (see !stats). */
function NewStats()
{
    return {
        tries = 0        // attempts where you fired (or got caught peeking)
        hits = 0
        first = 0        // hits with the attempt's first flare
        hitTime = 0.0    // seconds from start to hit, summed
        flares = 0       // flares fired
        dets = 0         // ... detonated by you
        inRange = 0      // ... of those, the blast reached the target
        walls = 0        // ... crashed into a wall / the ground
        directs = 0      // ... hit the enemy directly (collide on)
        early = 0        // detonations before the flare's closest point to the target
        earlyU = 0.0     // ... how far before it (units), summed
        earlyMs = 0.0
        late = 0         // detonations after it
        lateU = 0.0
        lateMs = 0.0
        deaths = 0       // the Sniper got you
    }
}

::Drill <- {
    mine = []            // your scenarios, as written/saved
    scenarios = []       // what gets played: yours + mirrored copies
    index = 0
    ready = false
    done = 0
    startTime = 0.0      // when the current attempt started
    nextAt = -1.0        // pending "go to next scenario" time
    placeMeAt = -1.0     // pending "put me at the start" time (after respawn)
    placeEnemyAt = -1.0
    bag = []             // scenarios not yet played this round (random order)
    round = 0

    queue = []           // sticky positions still to be laid
    waitingShot = false  // Demoman fired, waiting for the sticky to appear
    shotAt = 0.0
    live = []            // sticky entities of the current attempt
    stickyAt = []        // where the live ones were last tick (HitTarget: the one a detonation
                         // destroys is already gone when its flare is noticed gone)
    known = {}           // sticky entities already handled
    glows = []           // one tf_glow per live sticky
    layStart = 0.0       // when laying the current set of stickies began
    fastLauncher = null  // launcher we've already given the instant-fire attributes
    destroyed = 0        // stickies destroyed in the current attempt
    stickyCount = 0      // unique names for stickies/glows

    reviewing = false    // playing the review list instead of your scenarios
    editing = false      // edit mode: markers shown, no peek deaths, hits don't count
    losList = []         // !checklos: scenarios (played indices) that start in the Sniper's sight
    fixing = false       // going through losList: !done moves on to the next one
    scan = null          // !checklos running: { todo = [indices], cur, until }
    old = {}             // edit mode: "me"/"enemy" -> where that spot was before you moved it
    flares = {}          // your flares in the air -> where they were last tick
    seen = 0.0           // how long the Sniper has (net) seen you this attempt
    placedAt = -1.0      // when you were last put at a start (you drop SPAWN_LIFT from there)
    landed = true        // touched the ground since then: only then does peeking count
    wasSeen = false      // he could see you last tick (beep only when that starts)
    glowOn = false       // the enemy's outline is showing
    altAt = -1.0         // last time you held the detonate button (mouse2)
    hurtAt = -1.0        // last time your flare hurt the enemy (any way)
    impactAt = -1.0      // ... by the flare itself, not its blast
    hurtCustom = -1      // the damage type (custom) of that last hurt, for the console log
    dark = false         // hardcore: screen is black
    darkAt = 0.0
    att = null           // the attempt being counted for !stats and the session log (see BeginAttempt):
                         // { key, flares, died, stats, n, scen, ... }; also in review, not while
                         // editing or in !checklos
    attempts = 0         // attempt numbers handed out this session (the log's A lines)
    waiting = []         // ended attempts still to be logged: their flares are in the air (FlushLog)
    log = null           // the session log: { sid, file, part, text, ... } (LogInit)
    session = NewStats() // since the script was loaded
    total = NewStats()   // all time on this map (saved)
    per = {}             // scenario key -> [tries, first-flare hits, hits] (all time)
    restartAt = -1.0     // pending restart after the Sniper got you
    anchors = {}         // bot -> { pos, ang, from }: where it's pinned (from: start time)
    trail = []           // drawn pieces: { a, b, box, until }
    lastBoom = null      // where your last flare ended: { pos, dir, info }
    tpBoom = null        // explosion you !tp'd to (blast cube shown while there)
    zeroPing = false     // ping on: show where flares would have blown up at 0 ping (!zeroping)
    lagDet = null        // ping on: when to detonate (you pressed mouse2 ping ms before that)
    forcing = false      // ping on: the script is pressing mouse2 for you
    forcedAt = 0.0
    blocked = false      // ping on: your own mouse2 is held back
    m2Down = false       // mouse2 was held last tick (to see new presses)
    blockWarned = false  // told you once that holding mouse2 back didn't work
    afk = 0.0            // AFK seconds in the current attempt (left out of its time)
    activeAt = 0.0       // last time you pressed anything / moved the mouse
    lastAng = null       // your view last tick
    agg = {}             // AggKey(scen, mir) -> per-scenario stats of your own attempts on this map,
                         // from the session logs (NewAgg; saved in AggFile, see LoadAgg)
    aggReset = null      // last !stats_reset on this map: { sid, n } (attempts up to n of session sid
                         // and every earlier session are left out of agg), null = never
    bestStreak = 0       // the map's longest run of first-flare hits in a row (your own attempts, one
                         // session), this session's included (AggFile's B line; StreakStep)
}

function MyFile() { return "det_drill_" + GetMapName() + ".nut" }
function ReviewFile() { return "det_drill_review_" + GetMapName() + ".nut" }
/** Where edits go: your scenarios, or the review list while reviewing. */
function SaveFile() { return Drill.reviewing ? ReviewFile() : MyFile() }
/** Where in the review list you were, so !review picks up there next time. */
function ProgressFile() { return "det_drill_review_" + GetMapName() + "_progress.txt" }

function LoadProgress()
{
    local s = StripNul(FileToString(ProgressFile()))
    if (s == null)
        return 0
    s = strip(s)
    if (s == "")
        return 0
    try { return s.tointeger() } catch (e) { return 0 }
}

/**
 * A file's text without the NULs StringToFile can leave in it (at the end), so
 * it parses. null stays null (no file).
 */
function StripNul(s)
{
    if (s == null)
        return null
    local out = "", from = 0
    for (local i = 0; i < s.len(); i++)
        if (s[i] == 0)
        {
            out += s.slice(from, i)
            from = i + 1
        }
    return from == 0 ? s : out + s.slice(from)
}

/** Same start spot already among your own scenarios? */
function AlreadyKept(sc, mine)
{
    foreach (m in mine)
        if ((m.me.pos - sc.me.pos).Length() < 1)
            return true
    return false
}

// ---- Saving / loading --------------------------------------------------------

function VecStr(v) { return format("Vector(%d, %d, %d)", v.x.tointeger(), v.y.tointeger(), v.z.tointeger()) }
function AngStr(a) { return format("QAngle(%d, %d, 0)", a.x.tointeger(), a.y.tointeger()) }
function SpotStr(s) { return s == null ? "null" : format("{ pos = %s, ang = %s }", VecStr(s.pos), AngStr(s.ang)) }

function SaveScenarios() { SaveList(Drill.mine, SaveFile()) }

// Scripts can only read/write files up to 16 KB, so a long list is saved in
// parts: file, then file_part1.nut, file_part2.nut, ... An empty part ends it.
const PART_BYTES = 15000
function PartFile(file, i) { return i == 0 ? file : file.slice(0, file.len() - 4) + "_part" + i + ".nut" }

function SaveList(list, file)
{
    local part = 0
    local s = "return [\n"
    foreach (sc in list)
    {
        local stickies = ""
        foreach (i, st in sc.stickies)
            stickies += (i > 0 ? ", " : "") + format("{ pos = %s, n = Vector(%.3f, %.3f, %.3f) }",
                VecStr(st.pos), st.n.x, st.n.y, st.n.z)
        local note = "note" in sc ? format(", note = \"%s\"", sc.note) : ""
        local cls = "cls" in sc && sc.cls != SNIPER ? format(", cls = %d", sc.cls) : ""
        local line = format("    { me = %s, enemy = %s, stickies = [%s]%s%s }\n",
            SpotStr(sc.me), SpotStr(sc.enemy), stickies, cls, note)
        if (s.len() + line.len() > PART_BYTES)
        {
            StringToFile(PartFile(file, part++), s + "]\n")
            s = "return [\n"
        }
        s += line
    }
    StringToFile(PartFile(file, part++), s + "]\n")
    if (FileToString(PartFile(file, part)) != null)
        StringToFile(PartFile(file, part), "return []\n")   // cut off parts left from a longer list
}

function LoadScenarios(file = null)
{
    if (file == null)
        file = SaveFile()
    local list = file == MyFile() ? SCENARIOS : []
    if (FileToString(file) != null)
    {
        list = []
        for (local i = 0; ; i++)
        {
            local text = FileToString(PartFile(file, i))
            if (text == null)
                break
            local part = null
            try
                part = compilestring(text)()
            catch (e)
            {
                printl("[det] couldn't read " + PartFile(file, i) + ": " + e)
                break
            }
            if (part.len() == 0)
                break
            list.extend(part)
        }
    }
    // Older saves have no stickies; scenarios may leave out the Sniper.
    foreach (sc in list)
    {
        if (!("enemy" in sc))
            sc.enemy <- null
        if (!("stickies" in sc))
            sc.stickies <- []
        // a bare Vector = sticky on the floor (from before stickies could go on walls)
        foreach (i, st in sc.stickies)
            if (typeof st != "table")
                sc.stickies[i] = { pos = st, n = Vector(0, 0, 1) }
    }
    return list
}

/** Rebuild the played list from Drill.mine: each scenario, then its mirror. */
function Rebuild()
{
    local list = []
    foreach (i, sc in Drill.mine)
    {
        list.append({ me = sc.me, enemy = sc.enemy, stickies = sc.stickies, src = i, mirrored = false })
        if (Mirrors())
        {
            local m = []
            foreach (st in sc.stickies)
                m.append(MirrorSticky(st))
            list.append({ me = MirrorSpot(sc.me), enemy = MirrorSpot(sc.enemy), stickies = m, src = i, mirrored = true })
        }
    }
    ::Drill.scenarios = list
    Drill.bag.clear()
    if (Drill.index >= list.len())
        ::Drill.index = 0
}

function Current() { return Drill.scenarios[Drill.index] }
function Original() { return Drill.mine[Current().src] }

/** Change me/enemy of the current scenario; un-mirrors if needed. */
function EditCurrent(which, spot)
{
    if (Drill.editing && !(which in Drill.old) && Current()[which] != null)
        Drill.old[which] <- Current()[which]   // first move this edit: keep showing where it was
    Original()[which] = Current().mirrored ? MirrorSpot(spot) : spot
    Rebuild()
    SaveScenarios()
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
function FindEnemy() { return FindBot(ENEMY_NAME) }
function FindDemo() { return FindBot(DEMO_NAME) }

function Say(msg)
{
    ClientPrint(GetListenServerHost(), Constants.EHudNotify.HUD_PRINTTALK, "\x07FFD700[det] \x01" + msg)
}

/** Your saved aim, turned a random amount (never ~0) left/right and a bit up/down. */
function ThrowOffAim(ang)
{
    if (!Opt.aim_offset || AIM_OFF_MAX <= 0)
        return ang
    local yaw = RandomFloat(AIM_OFF_MIN, AIM_OFF_MAX) * (RandomInt(0, 1) == 0 ? -1 : 1)
    local pitch = ang.x + RandomFloat(-AIM_OFF_PITCH, AIM_OFF_PITCH)
    pitch = pitch > 89 ? 89 : pitch < -89 ? -89 : pitch
    return QAngle(pitch, ang.y + yaw, 0)
}

/** @param {CTFPlayer} p */
function Place(p, spot)
{
    if (p.IsFakeClient())
    {
        // Bots are pinned in place without gravity, so put them on the spot itself.
        Drill.anchors[p] <- { pos = spot.pos, ang = spot.ang, from = 0.0 }
        p.Teleport(true, spot.pos, true, spot.ang, true, Vector(0, 0, 0))
        p.SnapEyeAngles(spot.ang)
        return
    }
    local ang = ThrowOffAim(spot.ang)
    ::Drill.placedAt = Time()
    ::Drill.landed = false
    p.SetMoveType(Constants.EMoveType.MOVETYPE_WALK, 0)   // undo !tp's noclip
    p.Teleport(true, spot.pos + Vector(0, 0, SPAWN_LIFT), true, ang, true, Vector(0, 0, 0))
    p.SnapEyeAngles(ang)
    p.RemoveCond(Constants.ETFCond.TF_COND_RUNE_REGEN)   // older versions gave you this power-up
}

/** The team the enemies should be on: the opposite of yours (RED if you're not playing yet). */
function EnemyTeam()
{
    local me = GetListenServerHost()
    local mine = me != null ? me.GetTeam() : Constants.ETFTeam.TF_TEAM_BLUE
    return mine == Constants.ETFTeam.TF_TEAM_RED ? Constants.ETFTeam.TF_TEAM_BLUE : Constants.ETFTeam.TF_TEAM_RED
}

/**
 * Keep a bot on the enemy team and the given class; respawning re-places it.
 * Also keeps the TFBot brain out of the way: frozen in place (it can't walk,
 * aim or shoot on its own) and ignoring you. Re-applied every tick because
 * conditions are lost on respawn.
 */
const PRIMARY_ONLY = 2   // TFBotWeaponRestrictionType

function FixBot(bot, cls)
{
    if (bot == null)
        return
    if (bot.IsAlive() && !bot.InCond(Constants.ETFCond.TF_COND_FREEZE_INPUT))
        bot.AddCond(Constants.ETFCond.TF_COND_FREEZE_INPUT)
    if (bot.IsBotOfType(Constants.EBotType.TF_BOT_TYPE))
    {
        bot.AddBotAttribute(Constants.FTFBotAttributeType.IGNORE_ENEMIES)
        // The enemy holds his primary (a Sniper can't scope or crouch: buttons are
        // disabled in Pin). Not the sticky Demo: he needs his sticky launcher.
        if (bot == FindEnemy() && !bot.HasWeaponRestriction(PRIMARY_ONLY))
        {
            bot.ClearAllWeaponRestrictions()
            bot.AddWeaponRestriction(PRIMARY_ONLY)
        }
        else if (bot == FindDemo() && bot.HasWeaponRestriction(PRIMARY_ONLY))
            bot.ClearAllWeaponRestrictions()   // given it by an earlier version
    }
    if (bot.IsAlive())
        Pin(bot)
    // TFBot Spies disguise (and could cloak) by themselves: you should see who you're hitting.
    if (bot.IsAlive() && bot.GetPlayerClass() == Constants.ETFClass.TF_CLASS_SPY)
    {
        if (bot.InCond(Constants.ETFCond.TF_COND_DISGUISED) || bot.InCond(Constants.ETFCond.TF_COND_DISGUISING))
        {
            bot.RemoveDisguise()
            bot.RemoveCond(Constants.ETFCond.TF_COND_DISGUISING)
        }
        if (bot.InCond(Constants.ETFCond.TF_COND_STEALTHED))
            bot.RemoveCond(Constants.ETFCond.TF_COND_STEALTHED)
    }
    local wrongTeam = bot.GetTeam() != EnemyTeam()
    local wrongClass = bot.GetPlayerClass() != cls
    if (!wrongTeam && !wrongClass)
        return
    if (wrongTeam)
        bot.ForceChangeTeam(EnemyTeam(), true)
    if (wrongClass)
    {
        bot.SetPlayerClass(cls)
        NetProps.SetPropInt(bot, "m_Shared.m_iDesiredPlayerClass", cls)
    }
    bot.ForceRegenerateAndRespawn()
}

/**
 * The TFBot brain still tries to walk (freezing input doesn't stop it), so pin
 * the bot: buttons disabled, no movement, and snapped back to its spot if it
 * drifts anyway. The spot is where it was placed, or where it stood shortly
 * after spawning. Its view isn't forced every tick: that fights the bot's own
 * aiming and jitters. (Stickies are fired by calling the launcher directly.)
 */
function Pin(bot)
{
    NetProps.SetPropInt(bot, "m_afButtonDisabled", 0x7FFFFFFF)
    if (bot.InCond(Constants.ETFCond.TF_COND_ZOOMED))
        bot.RemoveCond(Constants.ETFCond.TF_COND_ZOOMED)

    local now = Time()
    if (!(bot in Drill.anchors))
        Drill.anchors[bot] <- { pos = null, ang = null, from = now + 0.1 }   // let the spawn settle
    local a = Drill.anchors[bot]
    if (now < a.from)
        return
    if (a.pos == null)
    {
        a.pos = bot.GetOrigin()
        a.ang = bot.EyeAngles()
    }
    if (bot.GetMoveType() != Constants.EMoveType.MOVETYPE_NONE)
        bot.SetMoveType(Constants.EMoveType.MOVETYPE_NONE, 0)
    if ((bot.GetOrigin() - a.pos).Length() > 1.0)
        bot.Teleport(true, a.pos, false, QAngle(), true, Vector(0, 0, 0))

    // A TFBot that wants to walk but can't move counts as stuck and kills itself
    // after a while (and a dead Demo loses his stickies). Keep it "unstuck".
    if (bot.IsBotOfType(Constants.EBotType.TF_BOT_TYPE))
    {
        bot.GetLocomotionInterface().ClearStuckStatus("pinned by det_drill")
        bot.ClearImmobileStatus()
    }

    // The Sniper's view is locked from his own think (LockAim): that runs after
    // the bot brain has aimed for the tick, so it wins without jittering.
    if (bot == FindEnemy())
    {
        bot.ValidateScriptScope()
        local scope = bot.GetScriptScope()
        if (!("DetLockAim" in scope) || scope.DetLockAim != LockAim)
        {
            scope.DetLockAim <- LockAim
            AddThinkToEnt(bot, "DetLockAim")
        }
    }
}

/** Think function on the Sniper himself (self = the bot): hold his saved view. */
function LockAim()
{
    if (self in ::Drill.anchors)
    {
        local a = ::Drill.anchors[self]
        if (a.ang != null)
            self.SnapEyeAngles(a.ang)
    }
    return -1
}

/** Keep you and the Sniper at full health between scenario starts. */
function TopUpHealth()
{
    foreach (p in [GetListenServerHost(), FindEnemy()])
        if (p != null && p.IsAlive() && p.GetHealth() < p.GetMaxHealth())
            p.SetHealth(p.GetMaxHealth())

    // The Demoman must never die: his stickies would vanish with him.
    local demo = FindDemo()
    if (demo != null && demo.IsAlive() && !demo.InCond(Constants.ETFCond.TF_COND_INVULNERABLE))
        demo.AddCond(Constants.ETFCond.TF_COND_INVULNERABLE)
}

/** Nobody can capture the point (re-applied on every round start). */
function LockPoint()
{
    EntFire("trigger_capture_area", "SetTeamCanCap", "2 0")
    EntFire("trigger_capture_area", "SetTeamCanCap", "3 0")
}

/** Glow on the Sniper only when the scenario has one. */
function SetGlow(on)
{
    local old = Entities.FindByName(null, "det_glow")
    if (old != null)
        old.Kill()
    ::Drill.glowOn = on
    if (!on)
        return
    local enemy = FindEnemy()
    if (enemy != null)
        enemy.KeyValueFromString("targetname", ENEMY_NAME)
    SpawnEntityFromTable("tf_glow", {
        targetname = "det_glow"
        target = ENEMY_NAME
        GlowColor = Opt.glow_color + " 255"
    })
}

// ---- Stickies ----------------------------------------------------------------
// The Demoman fires each sticky from his spawn, then the script moves it to its
// spot and drops it so it sticks there. Takes a couple of ticks per sticky.

function KillStickies()
{
    foreach (s in Drill.live)
        if (s.IsValid())
            s.Kill()
    foreach (g in Drill.glows)
        if (g.IsValid())
            g.Kill()
    Drill.live.clear()
    Drill.glows.clear()
    Drill.queue.clear()
    ::Drill.waitingShot = false
    ::Drill.destroyed = 0
}

/** Make a sticky glow like the Sniper does (tf_glow finds its target by name). */
function GlowSticky(s)
{
    ::Drill.stickyCount++
    local name = "det_sticky_" + Drill.stickyCount
    s.KeyValueFromString("targetname", name)
    Drill.glows.append(SpawnEntityFromTable("tf_glow", {
        targetname = name + "_glow"
        target = name
        GlowColor = Opt.glow_color + " 255"
    }))
}

function LayStickies()
{
    KillStickies()
    if (Drill.scenarios.len() > 0)
        foreach (v in Current().stickies)
            Drill.queue.append(v)
    ::Drill.layStart = Time()
}

function Launcher(demo)
{
    for (local i = 0; i < NetProps.GetPropArraySize(demo, "m_hMyWeapons"); i++)
    {
        local w = NetProps.GetPropEntityArray(demo, "m_hMyWeapons", i)
        if (w != null && w.GetClassname() == "tf_weapon_pipebomblauncher")
            return w
    }
    return null
}

function FindNewSticky(demo)
{
    local e = null
    while ((e = Entities.FindByClassname(e, "tf_projectile_pipe_remote")) != null)
        if (!(e in Drill.known) && NetProps.GetPropEntity(e, "m_hThrower") == demo)
            return e
    return null
}

function LayStickiesStep()
{
    if (Drill.queue.len() == 0)
        return
    local demo = FindDemo()
    if (demo == null || !demo.IsAlive())
        return
    local launcher = Launcher(demo)
    if (launcher == null)
        return
    if (demo.GetActiveWeapon() != launcher)
    {
        // (a weapon with no ammo at all can't be switched to)
        launcher.SetClip1(launcher.GetMaxClip1())
        NetProps.SetPropIntArray(demo, "m_iAmmo", 24, launcher.GetPrimaryAmmoType())
        demo.Weapon_Switch(launcher)
        return
    }

    if (Drill.waitingShot)
    {
        local s = FindNewSticky(demo)
        if (s != null)
        {
            Drill.known[s] <- true
            // Start just off the surface and fly into it, so it sticks there.
            local st = Drill.queue.remove(0)
            s.Teleport(true, st.pos + st.n * STICKY_LIFT, false, QAngle(), true, st.n * -400.0)
            Drill.live.append(s)
            GlowSticky(s)
            if (Drill.queue.len() == 0)
                printl(format("[det] laid %d stickies in %.2fs", Drill.live.len(), Time() - Drill.layStart))
            ::Drill.waitingShot = false
        }
        else if (Time() - Drill.shotAt > 0.2)
            ::Drill.waitingShot = false    // shot didn't come out; try again
        return
    }

    // Make his launcher fire and release instantly (normally 0.6s between shots
    // and up to 4s of charge), so a whole set of stickies goes down in a few ticks.
    if (Drill.fastLauncher != launcher)
    {
        launcher.AddAttribute("fire rate bonus", 0.01, -1)
        launcher.AddAttribute("stickybomb charge rate", 0.01, -1)
        ::Drill.fastLauncher = launcher
    }

    // Aim at his feet and start a charge; with nobody holding the button the
    // launcher releases it on the next tick.
    demo.SnapEyeAngles(QAngle(89, 0, 0))
    NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", 0.0)
    launcher.SetClip1(launcher.GetMaxClip1())
    launcher.PrimaryAttack()
    ::Drill.waitingShot = true
    ::Drill.shotAt = Time()
}

function StickiesLeft()
{
    local n = Drill.queue.len() + (Drill.waitingShot ? 1 : 0)
    foreach (s in Drill.live)
        if (s.IsValid())
            n++
    return n
}

// ---- Scenario flow -----------------------------------------------------------

/** Put you and the targets at the current scenario's positions. */
function StartScenario()
{
    EndAttempt(false)
    Blackout(false)
    Drill.old.clear()   // "old" markers belong to the scenario being edited
    KillStickies()
    ClearTrail()
    FlushLog(true)   // flares still in the air were let go (ClearTrail): log their attempts as they are
    if (Drill.scenarios.len() == 0)
    {
        Say("No scenarios for this map yet. Stand somewhere and type !new")
        return
    }
    local sc = Current()
    if (Drill.reviewing)
        StringToFile(ProgressFile(), Drill.index.tostring())

    local enemy = FindEnemy()
    if (sc.enemy != null)
    {
        if (enemy != null && enemy.IsAlive())
        {
            enemy.RemoveCond(Constants.ETFCond.TF_COND_BURNING)
            enemy.Regenerate(true)      // full health + ammo
            Place(enemy, sc.enemy)
        }
        SetGlow(Opt.glow != "off" || Drill.editing)
    }
    else
    {
        SetGlow(false)
        if (enemy != null && enemy.IsAlive())
            enemy.ForceRespawn()        // out of the way, back in his spawn
    }
    LayStickies()

    local me = GetListenServerHost()
    if (me != null && me.IsAlive())
    {
        // Refill so every attempt starts the same (health, ammo, Detonator reloaded).
        me.Regenerate(true)
        Place(me, sc.me)
    }
    ::Drill.startTime = Time()
    ::Drill.afk = 0.0
    ::Drill.nextAt = -1.0
    ::Drill.seen = 0.0
    ::Drill.wasSeen = false
    BeginAttempt()

    local whatStr = sc.enemy != null ? CLASS_NAMES[EnemyClass()]
        : sc.stickies.len() > 0 ? sc.stickies.len() + (sc.stickies.len() == 1 ? " sticky" : " stickies")
        : "no target yet: !setenemy or !addsticky"
    ClientPrint(me, Constants.EHudNotify.HUD_PRINTCENTER, format("%s %d / %d%s  -  %s",
        Drill.reviewing ? "REVIEW" : "Scenario", Drill.index + 1, Drill.scenarios.len(),
        sc.mirrored ? " (mirrored)" : "", whatStr))
    local orig = Original()
    if ("note" in orig)
        Say(format("Review %d/%d: %s  (!keep to save it, !next to skip)",
            Drill.index + 1, Drill.scenarios.len(), orig.note))
}

/**
 * Pick the next scenario. Random order works like shuffling a deck: every
 * scenario comes up once before any repeats, and never twice in a row.
 * !set focus on instead picks by need (FocusPick), not in review.
 */
function NextScenario()
{
    local n = Drill.scenarios.len()
    if (Opt.focus && !Drill.reviewing && n >= 2)
    {
        local pick = FocusPick()
        return GoTo(pick >= 0 ? pick : Drill.index + 1)
    }
    if (!Opt.random || Drill.reviewing || n < 2)
        return GoTo(Drill.index + 1)

    if (Drill.bag.len() == 0)
    {
        for (local i = 0; i < n; i++)
            if (i != Drill.index)
                Drill.bag.append(i)
        ::Drill.round++
        if (Drill.round > 1)
            Say("All scenarios done, shuffling a new round.")
    }
    GoTo(Drill.bag.remove(RandomInt(0, Drill.bag.len() - 1)))
}

function GoTo(index)
{
    local n = Drill.scenarios.len()
    if (n == 0)
        return
    ::Drill.index = ((index % n) + n) % n
    StartScenario()
}

/** Sticky scenarios are done once every sticky is gone. */
function CheckStickiesDone()
{
    if (Drill.nextAt > 0 || Drill.scenarios.len() == 0)
        return
    local sc = Current()
    if (sc.enemy != null || sc.stickies.len() == 0)
        return

    // Count stickies that were placed and are gone now, like hits on the Sniper.
    local gone = 0
    foreach (st in Drill.live)
        if (!st.IsValid())
            gone++
    if (gone > Drill.destroyed)
    {
        ::Drill.destroyed = gone
        local total = sc.stickies.len()
        if (gone < total)
            ClientPrint(GetListenServerHost(), Constants.EHudNotify.HUD_PRINTCENTER,
                format("HIT!  %d / %d", gone, total))
    }

    if (StickiesLeft() == 0)
        Finish()
}

function Finish()
{
    EndAttempt(true)
    ::Drill.done++
    local took = AttemptTime()
    ClientPrint(GetListenServerHost(), Constants.EHudNotify.HUD_PRINTCENTER, format("DONE!  %.1fs", took))
    Say(format("Scenario %d done in %.1fs (%d total)", Drill.index + 1, took, Drill.done))
    ::Drill.nextAt = Time() + NEXT_DELAY
}

// ---- Flare trail -------------------------------------------------------------

/**
 * Record each of your flares' path, tick by tick, plus a box where it ended,
 * and draw it. Debug lines can't be erased once drawn, so everything is redrawn
 * every tick with a tiny lifetime; ClearTrail() then makes it vanish at once.
 * Also notices new flares (FlareFired) and how each one ended (FlareEnded).
 */
function DrawFlareTrails()
{
    local me = GetListenServerHost()
    if (me == null)
        return
    local now = Time()
    local seen = {}
    for (local f = null; f = Entities.FindByClassname(f, "tf_projectile_flare");)
    {
        if (f.GetOwner() != me)
            continue
        local pos = f.GetOrigin()
        local vel = f.GetAbsVelocity()
        local dir = Vector(vel.x, vel.y, vel.z)
        local tracked = false
        local through = false
        local pressPos = null   // ping on: where it was when you pressed mouse2 (= its 0 ping explosion)
        local log = null        // session log: { att, k, ms } (FlareFired), null = not logged
        if (f in Drill.flares)
        {
            local last = Drill.flares[f].pos
            Drill.trail.append({ a = last, b = pos, box = false, until = now + TRAIL_TIME })
            if ((pos - last).Length() > 0.1)
                dir = pos - last
            tracked = Drill.flares[f].tracked
            through = Drill.flares[f].through
            pressPos = Drill.flares[f].pressPos
            log = Drill.flares[f].log
            if (!through && !Opt.collide && FlewThroughEnemy(last, pos))
            {
                through = true
                PassedThrough(tracked)
            }
            // The game may reset the group after the flare spawns: keep it passing through.
            if (!Opt.collide && f.GetCollisionGroup() != Constants.ECollisionGroup.COLLISION_GROUP_DEBRIS)
                f.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_DEBRIS)
        }
        else
        {
            local fired = FlareFired(f)
            tracked = fired.tracked
            log = fired.log
        }
        dir.Norm()
        seen[f] <- { pos = pos, dir = dir, speed = vel.Length(), tracked = tracked, through = through,
            pressPos = pressPos, log = log }
    }
    Mouse2(me, now, seen)
    // Flares that were there last tick but are gone now exploded (or were detonated).
    foreach (f, last in Drill.flares)
        if (!(f in seen))
        {
            local zero = FlareEnded(last)   // ping on: where it would have blown up at 0 ping
            Drill.trail.append({ a = last.pos, b = last.pos, box = true, zero = zero, until = now + TRAIL_TIME })
        }
    Drill.stickyAt.clear()
    foreach (st in Drill.live)
        if (st.IsValid())
            Drill.stickyAt.append(st.GetOrigin())
    if (seen.len() == 0)
        ::Drill.lagDet = null   // ping on: nothing left to detonate (it hit something first)
    ::Drill.flares = seen
    if (Drill.dark && (seen.len() == 0 || now - Drill.darkAt > MAX_DARK))
        Blackout(false)

    while (Drill.trail.len() > 0 && Drill.trail[0].until < now)
        Drill.trail.remove(0)
    // Boxes are outlines only (alpha 0): overlapping redraws of see-through faces
    // add up and pulse.
    local life = OVERLAY_LIFE
    local r = Vector(DET_RADIUS, DET_RADIUS, DET_RADIUS)
    foreach (t in Drill.trail)
    {
        if (!t.box)
        {
            if (Opt.trail)
                DebugDrawLine(t.a, t.b, 255, 140, 0, false, life)
        }
        else
        {
            // ping on: the box is where it blew up (with your ping), or with
            // !zeroping where it would have at 0 ping.
            local at = t.zero != null && Drill.zeroPing ? t.zero : t.a
            if (Opt.boom == "mark")
                DebugDrawBox(at, Vector(-6, -6, -6), Vector(6, 6, 6), 255, 60, 0, 0, life)
            else if (Opt.boom == "radius")
                DebugDrawBox(at, r * -1, r, 255, 140, 0, 0, life)
        }
    }
}

/**
 * A new flare of yours. Returns { tracked = whether it counts for !stats,
 * log = { att, k (flare number in the attempt), ms (attempt start to firing) }
 * for the session log, or null }.
 */
function FlareFired(f)
{
    if (!Opt.collide)   // flies through players (debris only collides with the world)
        f.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_DEBRIS)
    if (Opt.glow != "always")
        SetGlow(false)   // you've taken your shot: glow off until a restart
    if (Opt.hardcore && !Drill.editing && Drill.scan == null)
        Blackout(true)
    local a = Drill.att
    if (a == null || !Logging())
        return { tracked = false, log = null }
    a.flares++
    a.air++
    local ms = ((Time() - Drill.startTime) * 1000).tointeger()
    if (a.flares == 1)
        a.firstMs = ms
    local log = { att = a, k = a.flares, ms = ms }
    if (!a.stats || !Tracking())
        return { tracked = false, log = log }   // review: logged, but not in !stats
    Count("flares")
    return { tracked = true, log = log }
}

/**
 * How a flare ended: "det" (you detonated it), "wall" (crashed into the world),
 * "direct" (hit the enemy, collide on) or "gone". It was at last.pos last tick.
 */
function FlareEnd(last)
{
    // Decided by the damage events, whatever collide is set to: if the flare
    // gets through to him anyway, you still hear about it.
    local now = Time()
    if (now - Drill.impactAt < 0.1)
        return "direct"   // the flare itself hurt him (not its blast)
    if (now - Drill.altAt < 0.2)
        return "det"
    // A surface right ahead: it would have reached it this tick.
    local reach = last.speed * FrameTime() * 2 + 16
    local t = { start = last.pos, end = last.pos + last.dir * reach, mask = MASK_SOLID_BRUSHONLY,
        ignore = GetListenServerHost() }
    TraceLineEx(t)
    if (t.hit)
        return "wall"
    // Blew up without mouse2 or a wall, and he got hurt that moment: it ran into him.
    return now - Drill.hurtAt < 0.1 ? "direct" : "gone"
}

/**
 * Detonation timing against the target (the enemy's middle, or the nearest
 * sticky): units / ms before (> 0, early) or after (< 0, late) the flare's
 * closest point to it. null: no target.
 */
function DetTiming(last)
{
    local target = TargetPos(last.pos)
    if (target == null)
        return null
    local along = (target - last.pos).Dot(last.dir)
    local speed = last.speed > 1 ? last.speed : 2000.0
    return { units = along, ms = along / speed * 1000 }
}

/**
 * Mouse2, every tick. Ping off: it's when you detonated. Ping on: your mouse2 is
 * held back (the Detonator's alt-fire kept on cooldown) and a press schedules the
 * detonation ping ms later, when the script presses it for you (m_afButtonForced)
 * for one tick. seen: your flares in the air now.
 */
function Mouse2(me, now, seen)
{
    local IN_ATTACK2 = Constants.FButtons.IN_ATTACK2
    local m2 = (NetProps.GetPropInt(me, "m_nButtons") & IN_ATTACK2) != 0
    if (m2 && (Opt.ping <= 0 || Drill.forcing))
        ::Drill.altAt = now   // a flare that's gone right after this was detonated, not crashed
    else if (m2 && !Drill.m2Down && Drill.lagDet == null && seen.len() > 0)
    {
        ::Drill.lagDet = now + Opt.ping / 1000.0
        foreach (fl in seen)
            if (fl.pressPos == null)
                fl.pressPos = fl.pos
    }
    ::Drill.m2Down = m2

    local w = me.GetActiveWeapon()
    local flaregun = w != null && w.GetClassname() == "tf_weapon_flaregun"
    // Let go once the flare is gone (a command with mouse2 went through), or
    // after a bit (Detonator not out, say).
    if (Drill.forcing && (seen.len() == 0 || now - Drill.forcedAt > 0.25))
    {
        NetProps.SetPropInt(me, "m_afButtonForced", NetProps.GetPropInt(me, "m_afButtonForced") & ~IN_ATTACK2)
        ::Drill.forcing = false
    }
    if (Opt.ping <= 0)
    {
        if (Drill.blocked && flaregun)
            NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", now)
        ::Drill.blocked = false
        ::Drill.lagDet = null
        return
    }
    if (Drill.forcing)
    {
        if (flaregun)
            NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", 0.0)
        return
    }
    if (Drill.lagDet != null && now >= Drill.lagDet)
    {
        ::Drill.lagDet = null
        ::Drill.forcing = true
        ::Drill.forcedAt = now
        if (flaregun)
            NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", 0.0)
        NetProps.SetPropInt(me, "m_afButtonForced", NetProps.GetPropInt(me, "m_afButtonForced") | IN_ATTACK2)
        return
    }
    if (flaregun)
        NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", now + 0.5)
    ::Drill.blocked = true
}

/**
 * One of your flares is gone: how it went, warnings, !tp info and stats.
 * Returns where it would have blown up at 0 ping, or null (ping off, or no
 * mouse2 while it flew: same either way).
 */
function FlareEnded(last)
{
    local me = GetListenServerHost()
    local how = FlareEnd(last)
    local ping = last.pressPos != null && Opt.ping > 0 ? Opt.ping.tointeger() : 0
    local timing = how == "det" ? DetTiming(last) : null
    local edge = BoomEdge(last.pos)
    // Against the hit window: where it blew up, and (ping on) where you pressed mouse2,
    // which is where it would have blown up at 0 ping.
    local target = HitTarget(last.pos)
    local win = target == null ? null : HitWindow(last.pos, last.dir, last.speed, target)
    local pwin = target == null || ping == 0 ? null : HitWindow(last.pressPos, last.dir, last.speed, target)
    local now = Time()
    // The game's own explosion just hurt him (a flare hitting a wall can still get him).
    local caught = Drill.scenarios.len() > 0 && Current().enemy != null && now - Drill.hurtAt < 0.1
    printl(format("[det] flare ended: %s%s  (mouse2 %.0f ms ago, enemy hurt %.0f ms ago, custom=%d, %.0f u from him, collide=%s)",
        how, ping == 0 ? "" : format(", %d ms ping: %.0f units on from where you pressed", ping,
        (last.pos - last.pressPos).Length()), (now - Drill.altAt) * 1000, (now - Drill.hurtAt) * 1000,
        Drill.hurtCustom, edge == null ? -1.0 : edge, Opt.collide ? "on" : "off"))
    local info = BoomInfo(last.pos, how, timing)
    ::Drill.lastBoom = { pos = last.pos, dir = last.dir, real = null, realInfo = null,
        info = ping == 0 ? info : format("with %d ms ping: %s", ping, info) }
    if (ping > 0)
    {
        Drill.lastBoom.real = last.pressPos
        Drill.lastBoom.realInfo = "at 0 ping: " + BoomInfo(last.pressPos, "det",
            DetTiming({ pos = last.pressPos, dir = last.dir, speed = last.speed }))
    }
    ::Drill.zeroPing = false   // every flare first shows the one with your ping

    local quiet = Drill.editing || Drill.scan != null
    if (how == "wall" && Opt.wall_warn && !last.through && !quiet)
    {
        EmitSoundOnClient(WALL_SOUND, me)
        local got = caught ? " The blast still got him." : ""
        if (ping > 0)
            Say(format("With %d ms ping, your flare hit a wall / the ground before the detonation got there.%s", ping, got))
        else
            Say("Your flare hit a wall / the ground before you detonated it." + got)
    }
    else if (how == "direct" && !Drill.editing)
    {
        EmitSoundOnClient(DIRECT_SOUND, me)
        if (Opt.collide)
            Say("Direct hit: the flare hit him before you detonated it (!set collide off to stop that).")
        else
            Say("Direct hit: the flare hit him before you detonated it (it should have passed through: collide is off).")
    }
    else if (how == "det" && !last.through && !quiet && Opt.flare_info && win != null)
        Say(DetFeedback(win, pwin))   // (one that flew through him already got its message)
    // Gone after your press but before the script's detonation, without hitting
    // anything: your own mouse2 got through.
    if (ping > 0 && how == "gone" && Drill.lagDet != null && !Drill.blockWarned)
    {
        ::Drill.blockWarned = true
        Say("Pretend ping couldn't hold your detonation back, so it isn't working right. Tell Claude (or !set ping 0).")
    }

    if (last.tracked && Tracking())
        CountFlare(how, edge, timing)
    if (last.log != null)
    {
        LogFlare(last, how, win, pwin, edge, caught)
        FlushLog(false)   // its attempt may have been waiting for this flare
    }
    return ping > 0 ? last.pressPos : null
}

/** !stats for one flare, by how it went. */
function CountFlare(how, edge, timing)
{
    if (how == "det")
    {
        Count("dets")
        if (edge != null && edge <= DET_RADIUS)
            Count("inRange")
        if (timing != null && timing.units >= 0)
        {
            Count("early")
            Count("earlyU", timing.units)
            Count("earlyMs", timing.ms)
        }
        else if (timing != null)
        {
            Count("late")
            Count("lateU", -timing.units)
            Count("lateMs", -timing.ms)
        }
    }
    else if (how == "wall")
        Count("walls")
    else if (how == "direct")
        Count("directs")
}

/**
 * collide off: did the flare's path this tick (a -> b) go through the enemy's
 * body? Then it would have hit him directly.
 */
function FlewThroughEnemy(a, b)
{
    if (Drill.editing || Drill.scan != null || Drill.scenarios.len() == 0 || Current().enemy == null)
        return false
    local enemy = FindEnemy()
    if (enemy == null || !enemy.IsAlive())
        return false
    local pad = Vector(FLARE_PAD, FLARE_PAD, FLARE_PAD)   // the flare isn't a point
    return SegmentHitsBox(a, b, enemy.GetOrigin() + enemy.GetBoundingMins() - pad,
        enemy.GetOrigin() + enemy.GetBoundingMaxs() + pad)
}

/** Whether the segment a -> b touches the box lo..hi (slab test). */
function SegmentHitsBox(a, b, lo, hi)
{
    local d = b - a
    local t0 = 0.0, t1 = 1.0
    foreach (axis in ["x", "y", "z"])
    {
        local s = a[axis], e = d[axis]
        if (fabs(e) < 0.0001)
        {
            if (s < lo[axis] || s > hi[axis])
                return false
            continue
        }
        local ta = (lo[axis] - s) / e, tb = (hi[axis] - s) / e
        if (ta > tb) { local x = ta; ta = tb; tb = x }
        t0 = ta > t0 ? ta : t0
        t1 = tb < t1 ? tb : t1
        if (t0 > t1)
            return false
    }
    return true
}

/** A flare (collide off) just flew through the enemy: tell you. Detonating it after still counts. */
function PassedThrough(tracked)
{
    EmitSoundOnClient(DIRECT_SOUND, GetListenServerHost())
    Say("Direct hit: that flare would have hit him before you detonated it.")
    if (tracked && Tracking())
        Count("directs")
}

/** Distance from pos to the nearest point of a player's body (its box). */
function BodyDist(p, pos)
{
    // Explosions reach whatever part of the body is closest, not its centre.
    return BoxDist(pos, p.GetOrigin() + p.GetBoundingMins(), p.GetOrigin() + p.GetBoundingMaxs())
}

/** Distance from pos to the box lo..hi (0 inside it; lo == hi: to that point). */
function BoxDist(pos, lo, hi)
{
    local near = Vector(pos.x < lo.x ? lo.x : pos.x > hi.x ? hi.x : pos.x,
                        pos.y < lo.y ? lo.y : pos.y > hi.y ? hi.y : pos.y,
                        pos.z < lo.z ? lo.z : pos.z > hi.z ? hi.z : pos.z)
    return (pos - near).Length()
}

// ---- Hit window ----------------------------------------------------------------

/**
 * What a detonation is measured against (HitWindow): the enemy's body box, or
 * the sticky nearest to pos as a point (as of last tick: Drill.stickyAt).
 * { lo, hi } (lo == hi for a point), or null: no target.
 */
function HitTarget(pos)
{
    local enemy = FindEnemy()
    if (Drill.scenarios.len() > 0 && Current().enemy != null && enemy != null && enemy.IsAlive())
        return { lo = enemy.GetOrigin() + enemy.GetBoundingMins(), hi = enemy.GetOrigin() + enemy.GetBoundingMaxs() }
    local best = null
    foreach (at in Drill.stickyAt)
        if (best == null || (at - pos).Length() < (best - pos).Length())
            best = at
    return best == null ? null : { lo = best, hi = best }
}

/** How far from target the straight path from pos along dir is, s units on (s < 0: behind pos). */
function PathDist(pos, dir, s, target) { return BoxDist(pos + dir * s, target.lo, target.hi) }

/**
 * The hit window of a flare flying straight on from pos along dir (normalised;
 * speed in units/s) against target (HitTarget): the stretch [s1, s2] of its path
 * (s = units on from pos, < 0 behind it) where a detonation would reach the
 * target (DET_RADIUS). The distance from a line to a box or point is convex in
 * s, so its minimum is found by ternary search and the window's edges by
 * bisection, to well under a unit. Returns {
 *   close   closest approach of the path to the target (units)
 *   edge    distance from pos itself (where it blew up)
 *   win     the path comes within DET_RADIUS at all (else the rest stays 0: an aim miss)
 *   s1, s2  the window
 *   errU    + early (the window was still ahead), - late (already behind), 0 inside
 *   errMs   ... in ms of flight
 *   winMs   the window's length in ms
 *   inMs    inside: how long after the window opened
 * }
 */
function HitWindow(pos, dir, speed, target)
{
    if (speed <= 1)
        speed = 2000.0
    local lo = -WINDOW_REACH, hi = WINDOW_REACH
    while (hi - lo > 0.5)
    {
        local m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3
        if (PathDist(pos, dir, m1, target) < PathDist(pos, dir, m2, target))
            hi = m2
        else
            lo = m1
    }
    local smin = (lo + hi) / 2
    local w = { close = PathDist(pos, dir, smin, target), edge = PathDist(pos, dir, 0.0, target), win = false,
        s1 = 0.0, s2 = 0.0, errU = 0.0, errMs = 0.0, winMs = 0.0, inMs = 0.0 }
    if (w.close > DET_RADIUS)
        return w
    w.win = true
    w.s1 = WindowEdge(pos, dir, target, -WINDOW_REACH, smin)
    w.s2 = WindowEdge(pos, dir, target, WINDOW_REACH, smin)
    // In or out decided by the distance at pos itself, so it agrees with edgeU / inR.
    if (w.edge > DET_RADIUS)
        w.errU = smin > 0 ? (w.s1 > 0 ? w.s1 : 0.0) : (w.s2 < 0 ? w.s2 : 0.0)
    else
        w.inMs = (w.s1 < 0 ? -w.s1 : 0.0) / speed * 1000
    w.errMs = w.errU / speed * 1000
    w.winMs = (w.s2 - w.s1) / speed * 1000
    return w
}

/**
 * One edge of a hit window, by bisection between out (out of range) and inside
 * (in range, the path's closest point).
 */
function WindowEdge(pos, dir, target, out, inside)
{
    if (PathDist(pos, dir, out, target) <= DET_RADIUS)
        return out   // still in range that far along: the window goes on past WINDOW_REACH
    while (fabs(out - inside) > 0.25)
    {
        local mid = (out + inside) / 2
        if (PathDist(pos, dir, mid, target) <= DET_RADIUS)
            inside = mid
        else
            out = mid
    }
    return (out + inside) / 2
}

/**
 * The chat line after a detonation (flare_info): w = HitWindow where it blew up,
 * pwin = where you pressed mouse2 (ping on: its 0 ping equivalent), or null.
 */
function DetFeedback(w, pwin)
{
    local s
    if (!w.win)
        s = format("Det: path never in range (closest %d u, %d u too far)", Round(w.close), Round(w.close - DET_RADIUS))
    else if (w.edge <= DET_RADIUS)
        s = format("Det in the window (%d ms in, window %d ms)", Round(w.inMs), Round(w.winMs))
    else
        s = format("Det %s (window %d ms), %d u outside", ErrText(w), Round(w.winMs), Round(w.edge - DET_RADIUS))
    if (pwin != null && (pwin.win || w.win))
        s += " | at 0 ping: " + (!pwin.win ? "path never in range" : pwin.edge <= DET_RADIUS ? "in the window"
            : ErrText(pwin))
    return s
}

/** "23 ms late" / "10 ms early" for a HitWindow outside its window. */
function ErrText(w) { return format("%d ms %s", Round(fabs(w.errMs)), w.errU > 0 ? "early" : "late") }

/** How far an explosion at pos was from the target: the enemy's body or the nearest sticky. null: none. */
function BoomEdge(pos)
{
    local enemy = FindEnemy()
    if (Drill.scenarios.len() > 0 && Current().enemy != null && enemy != null && enemy.IsAlive())
        return BodyDist(enemy, pos)
    local best = null
    foreach (st in Drill.live)
        if (st.IsValid())
        {
            local d = (pos - st.GetOrigin()).Length()
            if (best == null || d < best)
                best = d
        }
    return best
}

/** How an explosion at pos went, as text (for !tp). */
function BoomInfo(pos, how, timing)
{
    local what = how == "det" ? "detonated" : how == "wall" ? "hit a wall" : how == "direct" ? "direct hit" : "gone"
    if (timing != null)
        what += format(" %d units / %dms %s", fabs(timing.units).tointeger(), fabs(timing.ms).tointeger(),
            timing.units >= 0 ? "early" : "late")
    local edge = BoomEdge(pos)
    if (edge == null)
        return what + ", no target left"
    if (Drill.scenarios.len() > 0 && Current().enemy != null)
        return format("%s, %d units from the %s's body (%s, radius %d)", what, edge.tointeger(),
            CLASS_NAMES[EnemyClass()], edge <= DET_RADIUS ? "in range" : format("%d too far",
            (edge - DET_RADIUS).tointeger()), DET_RADIUS)
    return format("%s, %d units from the nearest sticky", what, edge.tointeger())
}

/** Hardcore: black screen while your flare flies. */
const FFADE_IN = 1
const FFADE_OUT = 2
const FFADE_STAYOUT = 8
const FFADE_PURGE = 16
function Blackout(on)
{
    local me = GetListenServerHost()
    if (me == null || on == Drill.dark)
        return
    ::Drill.dark = on
    ::Drill.darkAt = Time()
    if (on)
        ScreenFade(me, 0, 0, 0, 255, 0.01, 0.0, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE)
    else
        ScreenFade(me, 0, 0, 0, 255, 0.3, 0.0, FFADE_IN | FFADE_PURGE)
}

/** glow = seconds: the outline goes once that long has passed since you were placed. */
function GlowTimer()
{
    if (!Drill.glowOn || Drill.editing || Drill.restartAt > 0)
        return
    local secs = null
    try { secs = Opt.glow.tofloat() } catch (e) { return }
    if (Time() - Drill.placedAt >= secs)
        SetGlow(false)
}

/** Fly to where the last flare ended, eyes right at the explosion. */
function TeleportToBoom(me)
{
    if (Drill.lastBoom == null)
    {
        Say("No flare has blown up yet.")
        return
    }
    local eyes = me.EyePosition() - me.GetOrigin()
    me.SetMoveType(Constants.EMoveType.MOVETYPE_NOCLIP, 0)
    // On the line from the target through the explosion, a bit past it: you look
    // at the target with the explosion right in front of you. (No target left:
    // back along the way the flare came.)
    local shown = ShownBoom()
    local boom = shown.pos
    local target = TargetPos(boom)
    local away = target != null ? boom - target : Drill.lastBoom.dir * -1
    if (away.Length() < 1)
        away = Drill.lastBoom.dir * -1   // exploded right on him
    away.Norm()
    local view = boom + away * TP_BACK
    me.Teleport(true, view - eyes, false, QAngle(), true, Vector(0, 0, 0))
    Blackout(false)
    if (target != null)
        me.SnapEyeAngles(LookAt(view, target))
    ::Drill.tpBoom = boom
    Say("Last flare: " + shown.info + ". Noclip on, !reset to go back."
        + (Drill.lastBoom.real == null ? "" : Drill.zeroPing ? " !zeroping: with your ping." : " !zeroping: at 0 ping."))
}

/** The last explosion as shown: with your ping, or (!zeroping) where it really was. { pos, info } */
function ShownBoom()
{
    local b = Drill.lastBoom
    if (Drill.zeroPing && b.real != null)
        return { pos = b.real, info = b.realInfo }
    return { pos = b.pos, info = b.info }
}

/** !zeroping: switch the explosion box between with your ping and at 0 ping (you don't move). */
function ToggleZeroPing()
{
    if (Opt.ping <= 0)
        return Say("ping is off (0), so there's only the one box. !set ping 80 pretends you have 80 ms.")
    ::Drill.zeroPing = !Drill.zeroPing
    if (Drill.tpBoom != null && Drill.lastBoom != null)
    {
        // In the !tp view you stay put: only the blast cube moves, to compare the two.
        local shown = ShownBoom()
        ::Drill.tpBoom = shown.pos
        return Say("Box " + shown.info + ". !zeroping again switches back.")
    }
    Say(Drill.zeroPing ? "Explosion box: at 0 ping (where you pressed mouse2). !zeroping again: with your ping."
        : format("Explosion box: with %d ms ping. !zeroping again: at 0 ping.", Opt.ping.tointeger()))
}

/**
 * AFK: no keys and no mouse movement for Opt.afk seconds. Such a stretch (all
 * of it) is left out of the attempt's time.
 */
function AfkStep()
{
    local me = GetListenServerHost()
    if (me == null)
        return
    local now = Time()
    local ang = me.EyeAngles()
    if (Drill.lastAng == null)   // just loaded
    {
        ::Drill.lastAng = ang
        ::Drill.activeAt = now
        return
    }
    local yaw = fabs(ang.y - Drill.lastAng.y)
    yaw = yaw > 180 ? 360 - yaw : yaw
    local turned = fabs(ang.x - Drill.lastAng.x) + yaw > 0.2
    ::Drill.lastAng = ang
    if (!turned && NetProps.GetPropInt(me, "m_nButtons") == 0)
        return
    local idle = AfkNow(now)
    if (idle > 0)
    {
        ::Drill.afk += idle
        if (Drill.att != null && Tracking())
            Say(format("Back from AFK: %.0fs left out of this attempt's time.", idle))
    }
    ::Drill.activeAt = now
}

/** How much of the current AFK stretch (if you're AFK now) falls in this attempt. */
function AfkNow(now)
{
    if (Opt.afk <= 0 || now - Drill.activeAt < Opt.afk)
        return 0.0
    return now - (Drill.activeAt > Drill.startTime ? Drill.activeAt : Drill.startTime)
}

/** Seconds since the attempt started, without the AFK time. */
function AttemptTime()
{
    local now = Time()
    local t = now - Drill.startTime - Drill.afk - AfkNow(now)
    return t > 0 ? t : 0.0
}

/** While you're looking around after !tp: the blast radius around that explosion. */
function DrawTpCube()
{
    local me = GetListenServerHost()
    if (Drill.tpBoom == null)
        return
    if (me == null || me.GetMoveType() != Constants.EMoveType.MOVETYPE_NOCLIP)
    {
        ::Drill.tpBoom = null   // left the !tp view (reset / next scenario / died)
        return
    }
    local r = Vector(DET_RADIUS, DET_RADIUS, DET_RADIUS)
    DebugDrawBox(Drill.tpBoom, r * -1, r, 255, 140, 0, 0, OVERLAY_LIFE)
}

/** The Sniper's body, or the live sticky nearest to pos; null if neither. */
function TargetPos(pos)
{
    local enemy = FindEnemy()
    if (Drill.scenarios.len() > 0 && Current().enemy != null && enemy != null && enemy.IsAlive())
        return enemy.GetCenter()
    local best = null
    foreach (st in Drill.live)
        if (st.IsValid() && (best == null || (st.GetOrigin() - pos).Length() < (best - pos).Length()))
            best = st.GetOrigin()
    return best
}

/** View angles that look from `from` straight at `to`. */
function LookAt(from, to)
{
    local d = to - from
    local flat = sqrt(d.x * d.x + d.y * d.y)
    return QAngle(-atan2(d.z, flat) * 180 / PI, atan2(d.y, d.x) * 180 / PI, 0)
}

/**
 * Wipe the drawn trail. Flares still in the air stay known (or DrawFlareTrails
 * would take them for new ones of the next attempt), but no longer belong to
 * an attempt or !stats.
 */
/**
 * A new attempt starts clean: the drawn trail goes, and so do your flares still
 * in the air (removed, no explosion), so a leftover one can't hit the next
 * attempt's target, finish it or be counted as one of its shots.
 */
function ClearTrail()
{
    Drill.trail.clear()
    foreach (f, _ in Drill.flares)
        if (f.IsValid())
            f.Kill()
    Drill.flares.clear()
    ::Drill.lagDet = null   // pretend ping: nothing left to detonate
}

// ---- Edit mode ---------------------------------------------------------------

/** A player-sized box with a line showing which way the spot faces, and a label. */
function DrawSpot(spot, label, r, g, b)
{
    local life = OVERLAY_LIFE   // redrawn every tick, gone right after edit mode ends
    DebugDrawBox(spot.pos, Vector(-24, -24, 0), Vector(24, 24, 82), r, g, b, 0, life)
    local eye = spot.pos + Vector(0, 0, 68)
    local fwd = QAngle(0, spot.ang.y, 0).Forward()
    DebugDrawLine(eye, eye + fwd * 60, r, g, b, false, life)
    DebugDrawText(spot.pos + Vector(0, 0, 96), label, false, life)
}

function DrawEditMarkers()
{
    if (Drill.scenarios.len() == 0)
        return
    local sc = Current()
    DrawSpot(sc.me, "START", 60, 140, 255)
    if (sc.enemy != null)
        DrawSpot(sc.enemy, CLASS_NAMES[EnemyClass()].toupper(), 255, 60, 60)
    foreach (which, spot in Drill.old)
        DrawSpot(spot, which == "me" ? "old START" : "old " + CLASS_NAMES[EnemyClass()], 150, 150, 150)
}

::HELP <- [
    ["Playing", null],
    ["reset", "back to the start of this scenario (numpad 7)"],
    ["next / prev", "skip to the next / previous scenario"],
    ["goto <number>", "jump to that scenario (console: script Det(\"goto 12\"))"],
    ["tp", "fly to where your last flare blew up, facing the target (numpad 9); reset to go back"],
    ["zeroping", "ping set: switch the explosion box between with your ping and at 0 ping (in !tp you stay put)"],
    ["list", "which scenario you're on, how many there are, how many are due (spaced repetition) and review spots left"],
    ["sound", "try the next sentry sound for being spotted (numpad 3)"],
    ["Making / editing scenarios", null],
    ["new", "new scenario starting where you stand; puts you in edit mode"],
    ["edit", "edit this scenario: spots shown as boxes, walk anywhere"],
    ["duplicate", "copy this scenario and edit the copy (the original stays as it is)"],
    ["setme", "this scenario's start = where you stand and look"],
    ["setenemy", "the enemy stands where you stand"],
    ["class <name>", "enemy class (class alone = next one); console: det_class_soldier, ..."],
    ["addsticky", "sticky where your crosshair is (makes it a sticky scenario)"],
    ["undosticky / clearstickies", "remove the last / all stickies"],
    ["done", "stop editing and play it"],
    ["delete", "delete this scenario (and its mirrored copy)"],
    ["Spots from your demos", null],
    ["review", "switch to / from the review list for this map"],
    ["keep", "save this review spot, starting where you stand now"],
    ["review_restart", "start the review list from the first spot again"],
    ["Settings and stats", null],
    ["set / settings", "list the settings and their values (also at the end of this help)"],
    ["set <name> <value>", "change one (saved): set glow 0.5, set hardcore on, set glow_color red ..."],
    ["toggle_<name>", "console only: det_toggle_trail, det_toggle_hardcore, ... flips an on/off setting"],
    ["stats", "your stats on this map, this session and all time (in the console)"],
    ["stats_reset", "start this map's all-time stats over (the per-scenario ones too)"],
    ["stats_rebuild", "rebuild the per-scenario stats from this map's session logs (since the last stats_reset)"],
    ["spot", "this scenario's card: tries, 1st-flare rate, best time, timing bias, why you miss it, spaced repetition box"],
    ["session", "this session's card: attempts, active minutes, 1st-flare rate vs your last 5 sessions, timing, worst spots, due"],
    ["log", "this session's log file (every attempt and flare, for the dashboard) and what's in it"],
    ["Checking", null],
    ["checklos", "play every Sniper scenario by itself, remember the ones where he'd kill you"],
    ["losnext", "edit the next bad one (done also moves on to the next)"],
]

/** Every command, in the console (chat would flood). */
function PrintHelp(me)
{
    local out = function(line) { ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, line + "\n") }
    out("")
    out("==== det_drill commands ====  (console: det_<name>, chat: !<name>)")
    foreach (h in HELP)
    {
        if (h[1] == null)
        {
            out("")
            out("-- " + h[0] + " --")
            continue
        }
        local name = h[0]
        while (name.len() < 28)
            name += " "
        out("  " + name + h[1])
    }
    PrintSettings(me)   // the on/off and other settings, with their current values
}

function StartEditing()
{
    if (Drill.att != null)
        Drill.att.edited = true   // an attempt you edited in isn't logged
    ::Drill.editing = true
    Drill.old.clear()
    Say("Editing scenario " + (Drill.index + 1) + ": walk anywhere. !setme / !setenemy move a spot, "
        + "!class <name> picks the enemy class, !addsticky for stickies, !done when finished.")
}

// ---- Settings (!set) ---------------------------------------------------------

function OptionsFile() { return "det_drill_settings.txt" }

::COLORS <- {
    yellow = "255 215 0", gold = "255 215 0", red = "255 40 40", green = "40 255 40", blue = "60 120 255",
    cyan = "0 255 255", purple = "180 60 255", pink = "255 100 200", orange = "255 140 0", white = "255 255 255"
}

function OptStr(v)
{
    if (typeof v == "bool")
        return v ? "on" : "off"
    if (typeof v == "float")
        return format("%.2f", v)
    return v.tostring()
}

/** s with every comma made a dot: a decimal comma ("1,5"), and the log's fields are comma separated. */
function DecimalDot(s)
{
    local out = ""
    foreach (c in s)
        out += c == ',' ? "." : c.tochar()
    return out
}

/** Change a setting from text. Returns an error message, or null if it worked. Bool + no value = flip. */
function SetOption(name, val)
{
    if (!(name in Opt))
        return "No setting called " + name + ". !set lists them."
    local cur = Opt[name]
    if (name != "sound")
        val = val.tolower()
    local v = val
    if (typeof cur == "bool")
    {
        if (val == "")
            v = !cur
        else if (["on", "1", "true", "yes"].find(val) != null)
            v = true
        else if (["off", "0", "false", "no"].find(val) != null)
            v = false
        else
            return name + " is on or off."
    }
    else if (typeof cur == "float" || typeof cur == "integer")
    {
        try { v = val.tofloat() } catch (e) { return name + " needs a number, like " + OptStr(cur) + "." }
        if (v < 0)
            return name + " can't be negative."
    }
    else if (val == "")
        return format("%s is %s. %s", name, OptStr(cur), OPTIONS[OPTIONS.map(@(o) o[0]).find(name)][2])
    else if (name == "glow" && ["shot", "always", "off"].find(val) == null)
    {
        v = DecimalDot(val)   // 1,5 = 1.5 (and no comma in the log's K line)
        local secs = -1.0
        try { secs = v.tofloat() } catch (e) {}
        if (secs <= 0)
            return "glow: shot, always, off, or seconds like 0.5."
    }
    else if (name == "boom" && ["mark", "radius", "off"].find(val) == null)
        return "boom: mark, radius or off."
    else if (name == "glow_color")
    {
        if (val in COLORS)
            v = COLORS[val]
        else
        {
            local c = split(val, " ,")
            local ok = c.len() == 3
            if (ok)
                foreach (x in c)
                {
                    local n = -1
                    try { n = x.tointeger() } catch (e) {}
                    ok = ok && n >= 0 && n <= 255
                }
            if (!ok)
                return "glow_color: \"r g b\" (0-255 each) or yellow, red, green, blue, cyan, purple, pink, orange, white."
            v = c[0] + " " + c[1] + " " + c[2]
        }
    }
    else if (name == "sound" && val != "off")
        PrecacheScriptSound(val)
    Opt[name] = v
    return null
}

/** What changes right away when a setting changes. */
function ApplyOption(name)
{
    local enemyScenario = Drill.scenarios.len() > 0 && Current().enemy != null
    if (name == "mirror" || name == "random")
    {
        Rebuild()
        StartScenario()
    }
    else if (name == "glow")
        SetGlow(enemyScenario && Opt.glow != "off")
    else if (name == "glow_color" && Drill.glowOn)
        SetGlow(true)
    else if (name == "hardcore" && !Opt.hardcore)
        Blackout(false)
    else if (name == "focus" && Opt.focus && DueText() != null)
        Say(DueText())
}

/** Only what differs from the defaults is saved, so new defaults still apply. */
function SaveOptions()
{
    local s = ""
    foreach (o in OPTIONS)
        if (Opt[o[0]] != o[1])
            s += o[0] + " " + OptStr(Opt[o[0]]) + "\n"
    StringToFile(OptionsFile(), s)
}

function LoadOptions()
{
    local text = FileToString(OptionsFile())
    if (text == null)
        return
    foreach (line in split(text, "\n"))
    {
        line = strip(line)
        local sp = line.find(" ")
        if (sp != null)
            SetOption(line.slice(0, sp), strip(line.slice(sp + 1)))
    }
}

function Pad(str, n)
{
    while (str.len() < n)
        str += " "
    return str
}

function PrintSettings(me)
{
    local out = function(line) { ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, line + "\n") }
    out("")
    out("==== det_drill settings ====  (det_settings shows just these; saved in tf/scriptdata/" + OptionsFile() + ")")
    out("  chat: !set <name> <value>   console: script Det(\"set glow 0.5\"), det_toggle_<name> for on/off")
    out("")
    foreach (o in OPTIONS)
        out("  " + Pad(o[0], 12) + Pad(OptStr(Opt[o[0]]), 22) + o[2])
    out("")
}

// ---- Statistics (!stats) -----------------------------------------------------
// Counted only while playing your own scenarios: not in review, edit mode or !checklos.

function StatsFile() { return "det_drill_stats_" + GetMapName() + ".txt" }

function Tracking() { return !Drill.editing && Drill.scan == null && !Drill.reviewing }

function Count(field, amount = 1)
{
    Drill.session[field] += amount
    Drill.total[field] += amount
}

/** Same scenario = same start spot (and side). */
function ScenarioKey(sc)
{
    return format("%d_%d_%d%s", sc.me.pos.x.tointeger(), sc.me.pos.y.tointeger(), sc.me.pos.z.tointeger(),
        sc.mirrored ? "m" : "")
}

/** Attempts go in the session log in review too (not in !stats); never while editing or in !checklos. */
function Logging() { return !Drill.editing && Drill.scan == null }

function BeginAttempt()
{
    ::Drill.att = null
    if (!Logging() || Drill.scenarios.len() == 0)
        return
    local sc = Current()
    local geo = ScenarioGeo(Original())
    ::Drill.attempts++
    ::Drill.att = {
        key = ScenarioKey(sc)
        flares = 0               // flares fired
        died = false             // the Sniper got you
        stats = Tracking()       // counts for !stats (your own scenarios, not review)
        // Session log:
        n = Drill.attempts       // attempt number
        index = Drill.index      // the played entry (a copy with the same spots is another scenario)
        scen = geo.id            // scenario id (unmirrored definition)
        cline = geo.cline        // its C line
        enemy = sc.enemy != null
        mir = sc.mirrored
        src = Drill.reviewing ? "r" : "o"
        t0 = Time()
        k = SettingsKey()        // settings when it started (K line)
        firstMs = -1             // attempt start to the first flare
        air = 0                  // its flares still in the air (FlareEnded logs them)
        lines = []               // their F lines, written with the A line
        edited = false           // you went into edit mode during it: not logged
        out = ""                 // how it ended (EndAttempt): hit, death, reset, skip
        timeMs = 0
        afkMs = 0
        seenMs = 0
        deathMs = -1             // the Sniper got you: timeMs / afkMs then (CheckPeek), -1 = not yet
        deathAfkMs = 0
    }
}

/** The attempt is over: hit, or restarted / skipped. Not counted if you never fired. */
function EndAttempt(hit)
{
    local a = Drill.att
    ::Drill.att = null
    if (a == null)
        return
    if (Logging() && !a.edited && (hit || a.flares > 0 || a.died))
    {
        // Logged once its flares are gone (the one that hit ends a tick after the hit).
        a.out = hit ? "hit" : a.died ? "death" : SameScenario(a) ? "reset" : "skip"
        a.timeMs = (AttemptTime() * 1000).tointeger()
        a.afkMs = ((Drill.afk + AfkNow(Time())) * 1000).tointeger()
        if (a.out == "death" && a.deathMs >= 0)
        {
            a.timeMs = a.deathMs   // not the time spent dead before the restart
            a.afkMs = a.deathAfkMs
        }
        a.seenMs = a.enemy ? (Drill.seen * 1000).tointeger() : 0
        Drill.waiting.append(a)
        FlushLog(false)
    }
    if (!a.stats || !Tracking() || (!hit && a.flares == 0 && !a.died))
        return
    if (!(a.key in Drill.per))
        Drill.per[a.key] <- [0, 0, 0]
    local p = Drill.per[a.key]
    Count("tries")
    p[0]++
    if (hit)
    {
        Count("hits")
        Count("hitTime", AttemptTime())
        p[2]++
        if (a.flares <= 1)
        {
            Count("first")
            p[1]++
        }
    }
    SaveStats()
}

/** Plain text lines over as many files as needed (16 KB limit, like SaveList). */
function WriteParts(file, lines)
{
    local part = 0, s = ""
    foreach (line in lines)
    {
        if (s.len() + line.len() + 1 > PART_BYTES)
        {
            StringToFile(PartFile(file, part++), s)
            s = ""
        }
        s += line + "\n"
    }
    StringToFile(PartFile(file, part++), s)
    if (FileToString(PartFile(file, part)) != null)
        StringToFile(PartFile(file, part), "")   // cut off parts left from a longer list
}

function ReadParts(file)
{
    local lines = []
    for (local i = 0; ; i++)
    {
        local text = StripNul(FileToString(PartFile(file, i)))
        if (text == null || strip(text) == "")
            break
        lines.extend(split(text, "\n"))
    }
    return lines
}

function SaveStats()
{
    local t = "total"
    foreach (k, v in Drill.total)
        t += " " + k + "=" + v
    local lines = [t]
    foreach (key, p in Drill.per)
        lines.append(format("s %s %d %d %d", key, p[0], p[1], p[2]))
    WriteParts(StatsFile(), lines)
}

function LoadStats()
{
    ::Drill.total = NewStats()
    Drill.per.clear()
    foreach (line in ReadParts(StatsFile()))
    {
        local w = split(line, " ")
        if (w.len() == 0)
            continue
        if (w[0] == "total")
            foreach (kv in w.slice(1))
            {
                local p = split(kv, "=")
                if (p.len() == 2 && p[0] in Drill.total)
                    Drill.total[p[0]] = typeof Drill.total[p[0]] == "float" ? p[1].tofloat() : p[1].tointeger()
            }
        else if (w[0] == "s" && w.len() == 5)
            Drill.per[w[1]] <- [w[2].tointeger(), w[3].tointeger(), w[4].tointeger()]
    }
}

function Pct(a, b) { return b > 0 ? format("%d%%", (100.0 * a / b + 0.5).tointeger()) : "-" }

function AvgStr(n, units, ms)
{
    return n > 0 ? format("%d (avg %d units, %dms)", n, (units / n).tointeger(), (ms / n).tointeger()) : "0"
}

/** One column of the !stats table. */
function StatCol(s)
{
    return [
        s.tries.tostring(),
        format("%d (%s)", s.hits, Pct(s.hits, s.tries)),
        format("%d (%s)", s.first, Pct(s.first, s.tries)),
        s.hits > 0 ? format("%.1fs", s.hitTime / s.hits) : "-",
        s.flares.tostring() + (s.hits > 0 ? format(" (%.1f per hit)", s.flares.tofloat() / s.hits) : ""),
        format("%d (%s)", s.dets, Pct(s.dets, s.flares)),
        format("%d (%s)", s.inRange, Pct(s.inRange, s.dets)),
        AvgStr(s.early, s.earlyU, s.earlyMs),
        AvgStr(s.late, s.lateU, s.lateMs),
        format("%d (%s)", s.walls, Pct(s.walls, s.flares)),
        s.directs.tostring(),
        s.deaths.tostring(),
    ]
}

::STAT_LABELS <- [
    "attempts", "hit", "hit with the 1st flare", "avg time to hit", "flares fired",
    "  detonated by you", "    blast reached target", "    early", "    late",
    "  hit a wall / ground", "  direct hits", "Sniper got you",
]

function PrintStats(me)
{
    local out = function(line) { ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, line + "\n") }
    out("")
    out("==== det_drill stats: " + GetMapName() + " ====  (your scenarios only, not review / edit mode)")
    out("  " + Pad("", 26) + Pad("this session", 34) + "all time")
    local a = StatCol(Drill.session), b = StatCol(Drill.total)
    foreach (i, label in STAT_LABELS)
        out("  " + Pad(label, 26) + Pad(a[i], 34) + b[i])
    out("")
    out("  early / late: when you detonated, compared with the moment the flare was closest")
    out("  to the target (Sniper's middle / nearest sticky). ms = how much sooner / later.")

    PrintHardest(out)   // by estimated first-flare rate, from the per-scenario stats
    out("")
    out("  This session (!session; every logged attempt, review ones too):")
    foreach (line in SessionCard(false))
        out("    " + line)
    out("")
}

// ---- Session log (!log) ------------------------------------------------------
// Every attempt and flare of this session, for the offline dashboard, as comma
// separated records (one per line, no spaces) in tf/scriptdata:
//   det_drill_log_<map>_<sid>.txt, then _part1.txt, _part2.txt, ... (each < 16 KB)
//     V,1                                  first line of every part
//     S,sid,map,YYYY-MM-DD hh:mm,version   the session (sid = YYMMDD-hhmm, + b, c ... if taken)
//     K,kid,ping,hardcore,glow,aim_offset,collide,peek,peek_time   settings (new kid when they change)
//     C,scen,sx,sy,sz,tx,ty,tz,e|s,cls,nsticky   a scenario, the first time it's logged
//     F,n,k,tFireMs,end,errMs,errU,winMs,closeU,edgeU,inR,ping,pressErrMs,hurt   a flare (LogFlare)
//     A,n,scen,mir,o|r,kid,t0,hit|death|reset|skip,nfl,firstShotMs,timeMs,afkMs,seenMs   an attempt
//   det_drill_log_index.txt (+ _partN.txt): V,1, then one line per session (all maps):
//     I,sid,map,parts,attempts,firstFlareHits,hits,flares,activeMinutes,YYYY-MM-DD
// Attempts are logged like !stats counts them (you fired or the Sniper got you),
// review ones too; editing and !checklos never. Written after every logged attempt.

const SCRIPT_VERSION = 1   // the S line's version: bump it when what the log means changes
const LOG_INDEX = "det_drill_log_index.txt"
const LETTERS = "bcdefghijklmnopqrstuvwxyz"

/** Part i of a log file: file, file_part1.txt, ... (like PartFile, but .txt). */
function LogPart(file, i) { return i == 0 ? file : file.slice(0, file.len() - 4) + "_part" + i + ".txt" }

function LogFile(sid) { return "det_drill_log_" + GetMapName() + "_" + sid + ".txt" }

/** Rounded to the nearest whole number (either sign). */
function Round(x) { return (x >= 0 ? x + 0.5 : x - 0.5).tointeger() }

/** The real date and time: { id = "YYMMDD-hhmm", date = "YYYY-MM-DD", stamp = "YYYY-MM-DD hh:mm" }. */
function Clock()
{
    local t = {}
    try { LocalTime(t) } catch (e) {}
    foreach (k in ["year", "month", "day", "hour", "minute"])
        if (!(k in t))   // no real clock: an id from the server time instead
            return { id = format("t%d", Time().tointeger()), date = "0000-00-00", stamp = "0000-00-00 00:00" }
    local y = t.year.tointeger(), mo = t.month.tointeger(), d = t.day.tointeger()
    local h = t.hour.tointeger(), mi = t.minute.tointeger()
    return {
        id = format("%02d%02d%02d-%02d%02d", y % 100, mo, d, h, mi)
        date = format("%04d-%02d-%02d", y, mo, d)
        stamp = format("%04d-%02d-%02d %02d:%02d", y, mo, d, h, mi)
    }
}

/** Lines of a log / index file (all its parts), without the V lines and blank lines. */
function ReadLog(file)
{
    local lines = []
    for (local i = 0; ; i++)
    {
        local text = StripNul(FileToString(LogPart(file, i)))
        if (text == null || strip(text) == "")
            break
        foreach (line in split(text, "\n"))
        {
            line = strip(line)
            if (line != "" && line.find("V,") != 0)
                lines.append(line)
        }
    }
    return lines
}

/** Lines over as many parts as needed, each starting with V,1. */
function WriteLog(file, lines)
{
    local part = 0, s = "V,1\n"
    foreach (line in lines)
    {
        if (s.len() + line.len() + 1 > PART_BYTES)
        {
            StringToFile(LogPart(file, part++), s)
            s = "V,1\n"
        }
        s += line + "\n"
    }
    StringToFile(LogPart(file, part++), s)
    if (FileToString(LogPart(file, part)) != null)
        StringToFile(LogPart(file, part), "")   // cut off parts left from a longer list
}

/** At load: pick this session's id (nothing is written before the first logged attempt). */
function LogInit()
{
    local c = Clock()
    local index = ReadLog(LOG_INDEX)
    local taken = {}
    foreach (line in index)
    {
        local w = split(line, ",")
        if (w.len() > 1 && w[0] == "I")
            taken[w[1]] <- true
    }
    local sid = c.id
    for (local k = 0; sid in taken || FileToString(LogFile(sid)) != null; k++)
        sid = c.id + (k < LETTERS.len() ? LETTERS.slice(k, k + 1) : "z" + k)
    ::Drill.log = {
        sid = sid
        file = LogFile(sid)
        stamp = c.stamp        // S line
        date = c.date          // I line
        t0 = Time()            // session start (A lines' t0)
        started = false        // S line written
        part = 0               // the part being written
        text = ""              // ... its text so far
        kid = 0                // last K line
        k = null               // ... its settings
        scens = {}             // scenario ids with a C line already
        attempts = 0           // for the I line and !log
        first = 0
        hits = 0
        flares = 0
        activeMs = 0           // AFK left out
        review = 0             // logged attempts in review (src r)
        errSum = 0.0           // errMs (+ early, - late) of the logged detonations whose path came in
        errSq = 0.0            // range: sum, sum of squares, how many (the session card's timing)
        errN = 0
        spots = {}             // AggKey -> { scen, mir, tries, miss }: your own attempts this session
                               // per spot and side, miss = not hit (the session card's worst spots)
        own = []               // your own attempts in order, true = first-flare hit (FatigueCheck)
        nudged = false         // the fatigue nudge was said
        streak = 0             // first-flare hits in a row now, your own attempts (StreakStep)
        bestStreak = 0         // ... the session's longest
        runFrom = 0            // Drill.bestStreak when the current streak began
        record = false         // the current streak beat it (and that was said)
        told = 0               // ... at this length
        index = index          // the index's lines (all sessions)
        row = -1               // ... this session's line in it
    }
}

/** The K line's settings: ping,hardcore,glow,aim_offset,collide,peek,peek_time. */
function SettingsKey()
{
    return format("%d,%d,%s,%d,%d,%d,%.2f", Opt.ping.tointeger(), Opt.hardcore ? 1 : 0, DecimalDot(Opt.glow.tostring()),
        Opt.aim_offset ? 1 : 0, Opt.collide ? 1 : 0, Opt.peek ? 1 : 0, Opt.peek_time.tofloat())
}

/**
 * A scenario (as defined: unmirrored) for the log: { id = "sx_sy_sz-tx_ty_tz", cline = its C line }.
 * t = the enemy, or the middle of the stickies (0 0 0: no target yet).
 */
function ScenarioGeo(o)
{
    local s = o.me.pos, t = Vector(0, 0, 0), kind = "s", cls = 0, n = o.stickies.len()
    if (o.enemy != null)
    {
        t = o.enemy.pos
        kind = "e"
        cls = "cls" in o ? o.cls.tointeger() : SNIPER
    }
    else if (n > 0)
    {
        foreach (st in o.stickies)
            t = t + st.pos
        t = t * (1.0 / n)
    }
    local id = format("%d_%d_%d-%d_%d_%d", s.x.tointeger(), s.y.tointeger(), s.z.tointeger(),
        t.x.tointeger(), t.y.tointeger(), t.z.tointeger())
    return { id = id, cline = format("C,%s,%d,%d,%d,%d,%d,%d,%s,%d,%d", id, s.x.tointeger(), s.y.tointeger(),
        s.z.tointeger(), t.x.tointeger(), t.y.tointeger(), t.z.tointeger(), kind, cls, kind == "e" ? 0 : n) }
}

/** Is the scenario up now the one attempt a was on (same entry, spot, side and list)? Then it's a reset. */
function SameScenario(a)
{
    if (Drill.scenarios.len() == 0 || Drill.index >= Drill.scenarios.len() || Drill.index != a.index)
        return false
    local sc = Current()
    return ScenarioGeo(Drill.mine[sc.src]).id == a.scen && sc.mirrored == a.mir
        && (Drill.reviewing ? "r" : "o") == a.src
}

/**
 * A flare of a logged attempt is gone: its F line, kept with the attempt until
 * that's logged. win / pwin: HitWindow where it blew up / where you pressed
 * mouse2 (ping on), null: no target. errMs / errU (+ early, - late, 0 inside the
 * window) for detonations whose path came within range; winMs, closeU: its
 * window and how close its path passes the target; edge: BoomEdge (the window's
 * own distance when there is one: the same for an enemy, and it still knows the
 * sticky this flare destroyed).
 */
function LogFlare(last, how, win, pwin, edge, hurt)
{
    local a = last.log.att
    a.air--
    local end = how == "direct" ? "direct" : last.through ? "through" : how
    local err = "", errU = "", winMs = 0, close = "", press = ""
    if (win != null)
    {
        close = Round(win.close).tostring()
        winMs = Round(win.winMs)
        edge = win.edge
        if (end == "det" && win.win)
        {
            err = Round(win.errMs).tostring()
            errU = Round(win.errU).tostring()
        }
    }
    if (pwin != null && pwin.win)
        press = Round(pwin.errMs).tostring()
    a.lines.append(format("F,%d,%d,%d,%s,%s,%s,%d,%s,%s,%d,%d,%s,%d", a.n, last.log.k, last.log.ms, end,
        err, errU, winMs, close, edge == null ? "" : Round(edge).tostring(), edge != null && edge <= DET_RADIUS ? 1 : 0,
        Opt.ping.tointeger(), press, hurt ? 1 : 0))
}

/** Log the ended attempts whose flares are all gone (force: all of them; their flares were forgotten). */
function FlushLog(force)
{
    while (Drill.waiting.len() > 0 && (force || Drill.waiting[0].air <= 0))
        LogAttempt(Drill.waiting.remove(0))
}

/** One more line in the session log; a full part is written out and a new one started. */
function LogLine(line)
{
    local L = Drill.log
    if (L.text.len() + line.len() + 1 > PART_BYTES)
    {
        StringToFile(LogPart(L.file, L.part), L.text)
        L.part++
        L.text = "V,1\n"
    }
    L.text += line + "\n"
}

/** An ended attempt (EndAttempt) into the log, with its flares; saves the log and the index. */
function LogAttempt(a)
{
    local L = Drill.log
    if (L == null)
        return
    if (!L.started)
    {
        L.started = true
        L.text = "V,1\n"
        LogLine(format("S,%s,%s,%s,%d", L.sid, GetMapName(), L.stamp, SCRIPT_VERSION))
    }
    if (a.k != L.k)
    {
        L.kid++
        L.k = a.k
        LogLine(format("K,%d,%s", L.kid, a.k))
    }
    if (!(a.scen in L.scens))
    {
        L.scens[a.scen] <- true
        LogLine(a.cline)
    }
    foreach (line in a.lines)
        LogLine(line)
    LogLine(format("A,%d,%s,%d,%s,%d,%d,%s,%d,%d,%d,%d,%d", a.n, a.scen, a.mir ? 1 : 0, a.src, L.kid,
        (a.t0 - L.t0).tointeger(), a.out, a.flares, a.firstMs, a.timeMs, a.afkMs, a.seenMs))
    StringToFile(LogPart(L.file, L.part), L.text)   // crash safe: on disk after every attempt

    L.attempts++
    L.flares += a.flares
    L.activeMs += a.timeMs
    if (a.out == "hit")
    {
        L.hits++
        if (a.flares <= 1)
            L.first++
    }
    if (a.src == "r")
        L.review++
    foreach (line in a.lines)
    {
        local f = Fields(line)
        if (f.len() >= 6 && f[4] == "det" && f[5] != "")
        {
            local ms = ToFloat(f[5], 0.0)
            L.errSum += ms
            L.errSq += ms * ms
            L.errN++
        }
    }
    if (a.src == "o")
    {
        local key = AggKey(a.scen, a.mir)
        if (!(key in L.spots))
            L.spots[key] <- { scen = a.scen, mir = a.mir, tries = 0, miss = 0 }
        L.spots[key].tries++
        if (a.out != "hit")
            L.spots[key].miss++
        L.own.append(a.out == "hit" && a.flares <= 1)
    }
    local row = format("I,%s,%s,%d,%d,%d,%d,%d,%.2f,%s", L.sid, GetMapName(), L.part + 1, L.attempts,
        L.first, L.hits, L.flares, L.activeMs / 60000.0, L.date)
    if (L.row < 0)
    {
        L.index.append(row)
        L.row = L.index.len() - 1
    }
    else
        L.index[L.row] = row
    WriteLog(LOG_INDEX, L.index)
    AggAttempt(a, L.sid)
    if (a.src == "o")
        FatigueCheck()
}

/** !log: this session's id, file and what's in it so far (console). */
function PrintLog(me)
{
    local L = Drill.log
    if (L == null)
        return Say("No session log (it couldn't start).")
    local out = function(line) { ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, line + "\n") }
    out("")
    out("==== det_drill session log ====")
    out("  session   " + L.sid + (L.started ? "" : "  (nothing logged yet: starts with your first attempt)"))
    out("  file      tf/scriptdata/" + L.file + (L.part > 0 ? format(" (+ %d more parts, now %s)", L.part,
        LogPart(L.file, L.part)) : ""))
    out("  index     tf/scriptdata/" + LOG_INDEX)
    out(format("  logged    %d attempts, %d hit (%d with the 1st flare), %d flares, %.1f active minutes",
        L.attempts, L.hits, L.first, L.flares, L.activeMs / 60000.0))
    if (Drill.waiting.len() > 0)
        out(format("  waiting   %d attempt(s): logged once their flares are gone", Drill.waiting.len()))
    out("")
    Say(format("Session %s: %d attempts logged in tf/scriptdata/%s. More in the console (~).",
        L.sid, L.attempts, L.file))
}

// ---- Per-scenario stats and spaced repetition --------------------------------
// Your own attempts (src o in the log, not review) per scenario and side, kept in
// tf/scriptdata/det_drill_agg_<map>.txt (+ _partN.txt): V,1, M,<AGG_VERSION>,
// B,<the map's best first-flare streak> (Drill.bestStreak), then one line each:
//   G,scen,mir,tries,firstFlareHits,hits,bestMs,errSum,errSq,errN,lastSid,box,
//     wall,through,aim,early,late,death,other
// bestMs: fastest hit (timeMs, -1 none); errSum / errSq / errN: errMs of your
// detonations (sum, sum of squares, how many); lastSid: the session it was last
// played in; box: spaced repetition (Leitner) box 1-5. The rest are why it was
// missed (MissReason): flares that didn't hit, by reason, and attempts that
// ended in death. Only a cache: !stats_rebuild makes it again from the session
// logs (via the index), and so does loading a cache from an older version (no
// M line: miss counts not filled in yet). !stats_reset clears it and writes
// det_drill_stats_reset_<map>.txt (R,sid,n): a rebuild leaves out everything
// up to attempt n of session sid.

/** Sessions since it was last seen before a spot in each box is due again (box 1: always). */
::LEITNER_GAP <- [0, 1, 2, 4, 8]
const PRIOR_TRIES = 4.0   // the Bayesian estimate counts the map's average as this many attempts
const AGG_VERSION = 3     // the agg file's M line; older caches are rebuilt at load (2: miss counts,
                          // 3: B line, best streak)
/** Miss counts in each NewAgg (MissReason's reasons, then deaths), and how !stats / !spot name them. */
::MISS_KINDS <- ["wall", "through", "aim", "early", "late", "other", "death"]
::MISS_NAMES <- { wall = "wall", through = "through him", aim = "aim", early = "early", late = "late",
    other = "other", death = "died" }

function AggFile() { return "det_drill_agg_" + GetMapName() + ".txt" }
function ResetFile() { return "det_drill_stats_reset_" + GetMapName() + ".txt" }
function AggKey(scen, mir) { return scen + "," + (mir ? 1 : 0) }

function NewAgg(scen, mir)
{
    return {
        scen = scen, mir = mir
        tries = 0, ffh = 0, hits = 0
        best = -1                // fastest hit, ms (AFK left out)
        errSum = 0.0, errSq = 0.0, errN = 0   // detonation errMs (+ early, - late)
        last = ""                // sid of the session it was last played in
        box = 1                  // Leitner box 1-5
        // Misses (MissReason): flares that didn't hit, by why, and attempts the Sniper ended
        wall = 0, through = 0, aim = 0, early = 0, late = 0, other = 0, death = 0
    }
}

/**
 * Why a flare (its F line's Fields) missed, or null: it hit (hurt the enemy; on
 * stickies, its blast reached one). "wall": crashed into the world; "through":
 * flew through the enemy (collide off) or hit him directly without it counting;
 * "aim": detonated, but its path never came within range (winMs 0); "early" /
 * "late": detonated before / after its hit window; "other": in the window but
 * no hit, no target, or just gone. enemy: an enemy scenario (else stickies).
 */
function MissReason(f, enemy)
{
    if (f.len() < 14)
        return "other"
    if (f[13] == "1" || (!enemy && f[10] == "1"))
        return null
    local end = f[4]
    if (end == "wall")
        return "wall"
    if (end == "through" || end == "direct")
        return "through"
    if (end != "det")
        return "other"
    if (f[5] != "")
    {
        local ms = ToInt(f[5], 0)
        return ms > 0 ? "early" : ms < 0 ? "late" : "other"
    }
    return f[8] != "" ? "aim" : "other"   // closeU but no errMs: there was a target, never in range
}

/** All of a spot's misses and deaths. */
function MissTotal(e)
{
    local n = 0
    foreach (k in MISS_KINDS)
        n += e[k]
    return n
}

/** The main reason a spot is missed, like "mostly late 5/8" (of all its misses and deaths), or "". */
function MissText(e)
{
    local n = MissTotal(e), top = null
    if (n == 0)
        return ""
    foreach (k in MISS_KINDS)
        if (top == null || e[k] > e[top])
            top = k
    return format("mostly %s %d/%d", MISS_NAMES[top], e[top], n)
}

/** A comma separated line's fields, empty ones kept (split() may drop them). */
function Fields(line)
{
    local out = [], from = 0
    for (;;)
    {
        local i = line.find(",", from)
        if (i == null)
        {
            out.append(line.slice(from))
            return out
        }
        out.append(line.slice(from, i))
        from = i + 1
    }
}

function ToInt(s, def) { try { return s.tointeger() } catch (e) { return def } }
function ToFloat(s, def) { try { return s.tofloat() } catch (e) { return def } }

/** The last !stats_reset on this map ({ sid, n }), or null. */
function LoadReset()
{
    foreach (line in ReadLog(ResetFile()))
    {
        local f = Fields(line)
        if (f.len() >= 3 && f[0] == "R")
            return { sid = f[1], n = ToInt(f[2], 0) }
    }
    return null
}

/** Attempt n of session sid came before the last !stats_reset, in that same session. */
function BeforeReset(sid, n)
{
    local r = Drill.aggReset
    return r != null && sid == r.sid && n <= r.n
}

/**
 * Sessions (MapSessions) whose attempts all came before the last !stats_reset:
 * the ones before its session in the index (or, if that session never got into
 * the index, the ones with an older sid).
 */
function SkippedSessions(sids)
{
    local skip = {}, r = Drill.aggReset
    if (r == null)
        return skip
    local at = sids.find(r.sid)
    foreach (i, sid in sids)
        if (at != null ? i < at : sid < r.sid)
            skip[sid] <- true
    return skip
}

function SaveAgg()
{
    local lines = [format("M,%d", AGG_VERSION), format("B,%d", Drill.bestStreak)]
    foreach (e in Drill.agg)
        lines.append(format("G,%s,%d,%d,%d,%d,%d,%.0f,%.0f,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d", e.scen, e.mir ? 1 : 0,
            e.tries, e.ffh, e.hits, e.best, e.errSum, e.errSq, e.errN, e.last, e.box,
            e.wall, e.through, e.aim, e.early, e.late, e.death, e.other))
    WriteLog(AggFile(), lines)
}

/** All attempts in a table of per-scenario stats. */
function AggTries(agg)
{
    local n = 0
    foreach (e in agg)
        n += e.tries
    return n
}

/**
 * At load: the cache, or (no cache yet) a rebuild from the logs. A cache from
 * an older version is rebuilt too (to fill in what it didn't count), unless the
 * logs have fewer attempts than it (deleted?): then it's kept as it is.
 */
function LoadAgg()
{
    Drill.agg.clear()
    ::Drill.bestStreak = 0
    ::Drill.aggReset = LoadReset()
    if (FileToString(AggFile()) == null)
        return RebuildAgg()
    local cache = ReadAgg()
    if (cache.version < AGG_VERSION)
    {
        RebuildAgg()   // fills Drill.agg and Drill.bestStreak (not cache.agg)
        if (AggTries(Drill.agg) >= AggTries(cache.agg))
            return
        printl(format("[det] %s: the session logs have fewer attempts than the old cache, kept the cache", AggFile()))
        Drill.agg.clear()   // (the best streak stays the one the logs have)
    }
    else
        ::Drill.bestStreak = cache.streak
    foreach (key, e in cache.agg)
        Drill.agg[key] <- e
    if (cache.version < AGG_VERSION)
        SaveAgg()   // as the current version, so it isn't rebuilt every time
}

/** The agg file: { version (its M line, 1 = none), streak (B line, 0 = none), agg = AggKey -> NewAgg }. */
function ReadAgg()
{
    local out = { version = 1, streak = 0, agg = {} }
    foreach (line in ReadLog(AggFile()))
    {
        local f = Fields(line)
        if (f.len() >= 2 && f[0] == "M")
            out.version = ToInt(f[1], 1)
        if (f.len() >= 2 && f[0] == "B")
            out.streak = ToInt(f[1], 0)
        if (f.len() < 12 || f[0] != "G")
            continue
        local e = NewAgg(f[1], f[2] == "1")
        e.tries = ToInt(f[3], 0)
        e.ffh = ToInt(f[4], 0)
        e.hits = ToInt(f[5], 0)
        e.best = ToInt(f[6], -1)
        e.errSum = ToFloat(f[7], 0.0)
        e.errSq = ToFloat(f[8], 0.0)
        e.errN = ToInt(f[9], 0)
        e.last = f[10]
        local box = ToInt(f[11], 1)
        e.box = box < 1 ? 1 : box > 5 ? 5 : box
        if (f.len() >= 18)
        {
            e.wall = ToInt(f[12], 0)
            e.through = ToInt(f[13], 0)
            e.aim = ToInt(f[14], 0)
            e.early = ToInt(f[15], 0)
            e.late = ToInt(f[16], 0)
            e.death = ToInt(f[17], 0)
        }
        if (f.len() >= 19)
            e.other = ToInt(f[18], 0)
        out.agg[AggKey(e.scen, e.mir)] <- e
    }
    return out
}

/**
 * One of your own attempts into the per-scenario stats: out / nfl / timeMs as
 * in its A line, flares = its F lines' Fields, enemy: an enemy scenario (not
 * stickies). Moves its Leitner box: up one on a first-flare hit (only on its
 * first attempt of a session: the gaps are counted in sessions), back to 1 on
 * any other attempt. Counts why its flares missed (MissReason) and a death.
 */
function AggAdd(scen, mir, sid, out, nfl, timeMs, flares, enemy)
{
    local key = AggKey(scen, mir)
    if (!(key in Drill.agg))
        Drill.agg[key] <- NewAgg(scen, mir)
    local e = Drill.agg[key]
    local first = out == "hit" && nfl <= 1
    e.tries++
    if (out == "hit")
    {
        e.hits++
        if (e.best < 0 || timeMs < e.best)
            e.best = timeMs
    }
    if (first)
        e.ffh++
    foreach (f in flares)
        if (f.len() >= 6 && f[4] == "det" && f[5] != "")
        {
            local ms = ToFloat(f[5], 0.0)
            e.errSum += ms
            e.errSq += ms * ms
            e.errN++
        }
    local misses = [], hit = false
    foreach (f in flares)
    {
        local why = MissReason(f, enemy)
        if (why == null)
            hit = true
        else
            misses.append(why)
    }
    // A hit none of whose flares shows as one (its hurt came a bit late, say): the last one did it.
    if (out == "hit" && !hit && misses.len() > 0)
        misses.pop()
    foreach (why in misses)
        e[why] += 1
    if (out == "death")
        e.death++
    if (!first)
        e.box = 1
    else if (e.last != sid && e.box < 5)
        e.box++
    e.last = sid
}

/**
 * A logged attempt (LogAttempt): your own ones go into the per-scenario stats,
 * saved. Says so when it's a new best time on that spot and side (if it had
 * one before), and keeps the first-flare streak (StreakStep).
 */
function AggAttempt(a, sid)
{
    if (a.src != "o" || BeforeReset(sid, a.n))
        return
    local flares = []
    foreach (line in a.lines)
        flares.append(Fields(line))
    local key = AggKey(a.scen, a.mir)
    local was = key in Drill.agg ? Drill.agg[key].best : -1
    AggAdd(a.scen, a.mir, sid, a.out, a.flares, a.timeMs, flares, a.enemy)
    if (a.out == "hit" && was >= 0 && a.timeMs < was)
        Say(format("New best time on this spot: %.2fs (was %.2fs).", a.timeMs / 1000.0, was / 1000.0))
    StreakStep(a.out == "hit" && a.flares <= 1)
    SaveAgg()
}

const STREAK_MIN = 3   // a new best streak is only announced from this many in a row

/**
 * One of your own attempts (ffh: a first-flare hit) for the streak: first-flare
 * hits in a row this session. Once the current one beats the map's best from
 * before it began (and is STREAK_MIN or more), that's said, and again how long
 * it got when it ends (if it grew since). The map's best (Drill.bestStreak,
 * saved with the per-scenario stats) follows it.
 */
function StreakStep(ffh)
{
    local L = Drill.log
    if (!ffh)
    {
        if (L.record && L.streak > L.told)
            Say(format("Streak over: %d first-flare hits in a row, your best on this map.", L.streak))
        L.streak = 0
        L.record = false
        return
    }
    if (L.streak == 0)
        L.runFrom = Drill.bestStreak
    L.streak++
    if (L.streak > L.bestStreak)
        L.bestStreak = L.streak
    if (L.streak > Drill.bestStreak)
        ::Drill.bestStreak = L.streak
    if (!L.record && L.streak > L.runFrom && L.streak >= STREAK_MIN)
    {
        L.record = true
        L.told = L.streak
        Say(format("New best streak on this map: %d first-flare hits in a row (was %d).", L.streak, L.runFrom))
    }
}

const FATIGUE_MIN = 30     // !set fatigue_nudge: only after this many of your own attempts this session,
const FATIGUE_LAST = 15    // ... the first-flare rate of the last this many
const FATIGUE_DROP = 0.2   // ... this much below the session's rate before them

/** !set fatigue_nudge: once a session, a chat line when your first-flare rate has dropped (see FATIGUE_MIN). */
function FatigueCheck()
{
    local L = Drill.log, n = L.own.len()
    if (!Opt.fatigue_nudge || L.nudged || n < FATIGUE_MIN)
        return
    local before = 0, last = 0
    foreach (i, ffh in L.own)
        if (ffh)
        {
            if (i < n - FATIGUE_LAST)
                before++
            else
                last++
        }
    local was = before.tofloat() / (n - FATIGUE_LAST), now = last.tofloat() / FATIGUE_LAST
    if (was - now < FATIGUE_DROP - 0.001)   // (a little slack for float rounding)
        return
    L.nudged = true
    Say(format("Your 1st-flare rate is dropping (%s in the last %d, %s before): maybe take a break.",
        Pct(now * 100, 100), FATIGUE_LAST, Pct(was * 100, 100)))
}

/** This map's sessions in the index, oldest first (their sids). */
function MapSessions()
{
    local sids = []
    if (Drill.log == null)
        return sids
    foreach (line in Drill.log.index)
    {
        local f = Fields(line)
        if (f.len() > 2 && f[0] == "I" && f[2] == GetMapName())
            sids.append(f[1])
    }
    return sids
}

/** !stats_rebuild (and a missing cache): the per-scenario stats again from this map's session logs. */
function RebuildAgg()
{
    Drill.agg.clear()
    local sessions = 0, attempts = 0, sids = MapSessions(), best = 0
    local skip = SkippedSessions(sids)
    local enemy = {}   // scenario id -> an enemy scenario (its C line's kind e), not stickies
    foreach (sid in sids)
    {
        if (sid in skip)
            continue
        sessions++
        local run = 0       // first-flare hits in a row (your own attempts)
        local flares = {}   // attempt number -> its F lines' Fields (they come before its A line)
        foreach (line in ReadLog(LogFile(sid)))
        {
            local f = Fields(line)
            if (f[0] == "C" && f.len() >= 9)
                enemy[f[1]] <- f[8] == "e"
            else if (f[0] == "F" && f.len() >= 14)
            {
                if (!(f[1] in flares))
                    flares[f[1]] <- []
                flares[f[1]].append(f)
            }
            else if (f[0] == "A" && f.len() >= 13)
            {
                local fl = f[1] in flares ? flares[f[1]] : []
                if (f[1] in flares)
                    delete flares[f[1]]
                if (f[4] != "o" || BeforeReset(sid, ToInt(f[1], 0)))
                    continue
                AggAdd(f[2], f[3] == "1", sid, f[7], ToInt(f[8], 0), ToInt(f[10], 0), fl,
                    f[2] in enemy ? enemy[f[2]] : true)
                attempts++
                run = f[7] == "hit" && ToInt(f[8], 0) <= 1 ? run + 1 : 0
                if (run > best)
                    best = run
            }
        }
    }
    ::Drill.bestStreak = best
    SaveAgg()
    return { sessions = sessions, attempts = attempts }
}

/** !stats_reset: the per-scenario stats start over from now (a rebuild won't bring them back). */
function ResetAgg()
{
    Drill.agg.clear()
    ::Drill.bestStreak = 0
    if (Drill.log != null)
    {
        Drill.log.streak = 0   // a streak starts over too (like a rebuild would see it)
        Drill.log.record = false
    }
    if (Drill.log != null)
    {
        ::Drill.aggReset = { sid = Drill.log.sid, n = Drill.attempts }
        StringToFile(ResetFile(), format("V,1\nR,%s,%d\n", Drill.log.sid, Drill.attempts))
    }
    SaveAgg()
}

/** The per-scenario stats of a played scenario (yours, that side), or null: never played. */
function AggFor(sc)
{
    local key = AggKey(ScenarioGeo(Drill.mine[sc.src]).id, sc.mirrored)
    return key in Drill.agg ? Drill.agg[key] : null
}

/** This map's first-flare rate over all your attempts (0.5 with none yet). */
function PooledRate()
{
    local tries = 0, ffh = 0
    foreach (e in Drill.agg)
    {
        tries += e.tries
        ffh += e.ffh
    }
    return tries > 0 ? ffh.tofloat() / tries : 0.5
}

/** Estimated first-flare rate: your record there, pulled towards the map's rate p while it's short. */
function Bayes(e, p)
{
    return e == null ? p : (e.ffh + PRIOR_TRIES * p) / (e.tries + PRIOR_TRIES)
}

/** How many of this map's sessions since sid (0: this one; a lot: not in the index). */
function SessionsSince(sid, sids)
{
    if (Drill.log != null && sid == Drill.log.sid)
        return 0
    local i = sids.find(sid)
    if (i == null)
        return 1000
    // This session isn't in sids (MapSessions lists it once logged): it comes after them all.
    local cur = Drill.log == null ? null : sids.find(Drill.log.sid)
    return (cur == null ? sids.len() : cur) - i
}

/** Due for spaced repetition: never played, or enough sessions since for its box. */
function Due(e, sids)
{
    return e == null || SessionsSince(e.last, sids) >= LEITNER_GAP[e.box - 1]
}

/** !set focus: how likely a scenario is to come up next. */
function AggWeight(e, p, sids)
{
    local w = 1.0 - Bayes(e, p)
    return (w < 0.05 ? 0.05 : w) + (Due(e, sids) ? 0.5 : 0.0)
}

/** !set focus: the next scenario, at random by AggWeight (never the one just played). */
function FocusPick()
{
    local p = PooledRate(), sids = MapSessions()
    local weights = [], sum = 0.0
    foreach (i, sc in Drill.scenarios)
    {
        local w = i == Drill.index ? 0.0 : AggWeight(AggFor(sc), p, sids)
        weights.append(w)
        sum += w
    }
    local r = RandomFloat(0.0, sum), pick = -1
    foreach (i, w in weights)
        if (w > 0)
        {
            pick = i
            r -= w
            if (r < 0)
                break
        }
    return pick
}

/** "N of M spots due on this map" for chat, or null (review, no scenarios). */
function DueText()
{
    local n = Drill.scenarios.len()
    if (Drill.reviewing || n == 0)
        return null
    local sids = MapSessions(), due = 0, fresh = 0
    foreach (sc in Drill.scenarios)
    {
        local e = AggFor(sc)
        if (e == null)
            fresh++
        if (Due(e, sids))
            due++
    }
    return format("Spaced repetition: %d of %d spots due on this map%s.%s", due, n,
        fresh > 0 ? format(" (%d never played)", fresh) : "",
        Opt.focus ? "" : " !set focus on to get them (and your weak ones) more often.")
}

/** How many review spots are left on this map (from where !review continues), or null: no list. */
function ReviewLeftText()
{
    local total = Drill.reviewing ? Drill.mine.len() : LoadScenarios(ReviewFile()).len()
    if (total == 0)
        return null
    local at = Drill.reviewing ? Drill.index : LoadProgress()
    if (at < 0 || at >= total)
        at = 0
    return format("Review list: %d of %d spots left on this map (from spot %d).", total - at, total, at + 1)
}

/** !stats: the hardest scenarios by estimated first-flare rate, and what's due (console). */
function PrintHardest(out)
{
    if (Drill.reviewing)
        return out("  (!review back to your own scenarios for the hardest list)")
    local p = PooledRate(), sids = MapSessions()
    local list = []
    // No session logs yet (from before they existed): the older all-time counts, same estimate.
    local legacy = Drill.agg.len() == 0
    if (legacy && Drill.total.tries > 0)
        p = Drill.total.first.tofloat() / Drill.total.tries
    foreach (i, sc in Drill.scenarios)
    {
        local e = AggFor(sc)
        if (legacy && ScenarioKey(sc) in Drill.per)
        {
            local c = Drill.per[ScenarioKey(sc)]
            e = NewAgg("", sc.mirrored)
            e.tries = c[0]
            e.ffh = c[1]
            e.hits = c[2]
        }
        if (e != null && e.tries > 0)
            list.append({ i = i, e = e, est = Bayes(e, p), due = !legacy && Due(e, sids) })
    }
    list.sort(function(x, y) {
        return x.est < y.est ? -1 : x.est > y.est ? 1 : y.e.tries - x.e.tries
    })
    if (list.len() > 0)
    {
        out("")
        out(format("  Hardest scenarios (since your logs began / !stats_reset; estimated 1st-flare rate, map average %s;",
            Pct(p * 100, 100)))
        out("  !goto <number> to practise one, !set focus on to get the weak ones more often, !spot for one's card):")
        foreach (k, x in list)
            if (k < 8)
            {
                local miss = MissText(x.e)
                out(format("    #%-5d est %4s  %d tries: 1st flare %d, hit %d%s", x.i + 1,
                    Pct(x.est * 100, 100), x.e.tries, x.e.ffh, x.e.hits, legacy ? "" : format(", best %s, box %d%s%s",
                    x.e.best >= 0 ? format("%.1fs", x.e.best / 1000.0) : "-", x.e.box, x.due ? ", due" : "",
                    miss == "" ? "" : ", " + miss)))
            }
        if (legacy)
            out("    (from the older all-time counts: no session logs on this map yet, !stats_rebuild once there are)")
        else
            out("    (mostly ...: why it's missed, of all its flares that didn't hit and deaths: wall, through him,"
                + " aim = path never in range, early / late = outside the hit window, other, died)")
    }
    local due = DueText()
    if (due != null)
    {
        out("")
        out("  " + due)
    }
}

/** "5 ms early" / "12 ms late" / "on time" for a mean detonation error (ms, + early). */
function BiasText(ms)
{
    local r = Round(ms)
    return r > 0 ? format("%d ms early", r) : r < 0 ? format("%d ms late", -r) : "on time"
}

/**
 * !spot: the current scenario's card, in chat and the console: side, tries,
 * first-flare rate (estimated and raw), hits, best time, detonation timing
 * (mean and spread of errMs), why it's missed and its spaced repetition box.
 */
function PrintSpot(me)
{
    if (Drill.scenarios.len() == 0)
        return Say("No scenarios yet. Type !new first.")
    if (Drill.reviewing)
        return Say("The spot card is for your own scenarios (!review to go back to them).")
    local sc = Current()
    local e = AggFor(sc), p = PooledRate(), sids = MapSessions()
    local what = sc.enemy != null ? CLASS_NAMES[EnemyClass()]
        : sc.stickies.len() == 1 ? "1 sticky" : sc.stickies.len() + " stickies"
    local lines = [format("Spot %d of %d: %s side, %s.", Drill.index + 1, Drill.scenarios.len(),
        sc.mirrored ? "mirrored" : "original", what)]
    if (e == null || e.tries == 0)
    {
        local key = ScenarioKey(sc)
        if (key in Drill.per)
        {
            local c = Drill.per[key]
            lines.append(format("No logged attempts yet (older all-time counts: %d tries, %d with the 1st flare, %d hits).",
                c[0], c[1], c[2]))
        }
        else
            lines.append("Not played yet (since your logs began / !stats_reset).")
        lines.append(format("1st flare estimate %s (the map's average). Spaced repetition: due (never played).",
            Pct(p * 100, 100)))
    }
    else
    {
        lines.append(format("%d tries, %d hits (%s), best %s. 1st flare: est %s, raw %d/%d (%s), map %s.",
            e.tries, e.hits, Pct(e.hits, e.tries), e.best >= 0 ? format("%.1fs", e.best / 1000.0) : "-",
            Pct(Bayes(e, p) * 100, 100), e.ffh, e.tries, Pct(e.ffh, e.tries), Pct(p * 100, 100)))
        if (e.errN > 0)
        {
            local mean = e.errSum / e.errN
            local v = e.errSq / e.errN - mean * mean
            lines.append(format("Timing: %s on average, spread (SD) %d ms, over %d detonations whose path came in range.",
                BiasText(mean), Round(sqrt(v > 0 ? v : 0.0)), e.errN))
        }
        else
            lines.append("Timing: no detonations yet whose path came within range.")
        local parts = []
        foreach (k in MISS_KINDS)
            if (e[k] > 0)
                parts.append(MISS_NAMES[k] + " " + e[k])
        local miss = "Misses: none."
        if (parts.len() > 0)
        {
            miss = "Misses:"
            foreach (i, s in parts)
                miss += (i > 0 ? ", " : " ") + s
            miss += " (" + MissText(e) + ")."
        }
        lines.append(miss)
        local gap = LEITNER_GAP[e.box - 1], since = SessionsSince(e.last, sids)
        lines.append(format("Spaced repetition: box %d of 5 (%s), last played %s: %s.", e.box,
            gap == 0 ? "always due" : format("due %d session%s after", gap, gap == 1 ? "" : "s"),
            since == 0 ? "this session" : since >= 1000 ? "in a session not in the index"
                : format("%d session%s ago", since, since == 1 ? "" : "s"),
            Due(e, sids) ? "due now" : format("due in %d more session%s", gap - since, gap - since == 1 ? "" : "s")))
    }
    foreach (line in lines)
    {
        Say(line)
        ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, "[det] " + line + "\n")
    }
}

// ---- Session card (!session), practice days ----------------------------------

/**
 * The mean first-flare rate of this map's last (up to) n sessions before this
 * one in the index (each session's rate, all its logged attempts): { rate, n },
 * or null: none.
 */
function RecentRate(n)
{
    local L = Drill.log, rates = []
    foreach (line in L.index)
    {
        local f = Fields(line)
        if (f.len() >= 6 && f[0] == "I" && f[2] == GetMapName() && f[1] != L.sid)
        {
            local tries = ToInt(f[4], 0)
            if (tries > 0)
                rates.append(ToInt(f[5], 0).tofloat() / tries)
        }
    }
    if (rates.len() == 0)
        return null
    local from = rates.len() > n ? rates.len() - n : 0, sum = 0.0
    for (local i = from; i < rates.len(); i++)
        sum += rates[i]
    return { rate = sum / (rates.len() - from), n = rates.len() - from }
}

/** "#12": a spot's number in the list playing now (scen id, side), or null: not in it (review, edited). */
function SpotNumber(scen, mir)
{
    if (Drill.reviewing)
        return null
    foreach (i, sc in Drill.scenarios)
        if (sc.mirrored == mir && ScenarioGeo(Drill.mine[sc.src]).id == scen)
            return "#" + (i + 1)
    return null
}

/**
 * The session card's lines: this session on this map (every logged attempt,
 * review ones too, like the index): attempts, active minutes, first-flare rate
 * against your last 5 sessions here, hits, streak, detonation timing (errMs),
 * your 3 worst spots (most attempts not hit) and, with due, what's due.
 */
function SessionCard(due)
{
    local L = Drill.log
    if (L == null)
        return ["No session log (it couldn't start), so no session card."]
    local lines = [format("Session %s on %s: %d attempts%s, %.1f active minutes (AFK left out).", L.sid,
        GetMapName(), L.attempts, L.review > 0 ? format(" (%d in review)", L.review) : "", L.activeMs / 60000.0)]
    if (L.attempts == 0)
        lines.append("Nothing logged yet: an attempt counts once you fire (or the Sniper gets you).")
    else
    {
        local recent = RecentRate(5)
        lines.append(format("1st flare %s (%d/%d), %s. Hits %d (%s). Best streak %d in a row (map best %d).",
            Pct(L.first, L.attempts), L.first, L.attempts,
            recent == null ? "no earlier sessions on this map"
                : format("last %d session%s here %s", recent.n, recent.n == 1 ? "" : "s", Pct(recent.rate * 100, 100)),
            L.hits, Pct(L.hits, L.attempts), L.bestStreak, Drill.bestStreak))
        if (L.errN > 0)
        {
            local mean = L.errSum / L.errN
            local v = L.errSq / L.errN - mean * mean
            lines.append(format("Timing: %s on average, spread (SD) %d ms, over %d detonations whose path came in range.",
                BiasText(mean), Round(sqrt(v > 0 ? v : 0.0)), L.errN))
        }
        else
            lines.append("Timing: no detonations yet whose path came within range.")
        local worst = []
        foreach (s in L.spots)
            if (s.miss > 0)
                worst.append(s)
        worst.sort(function(x, y) { return y.miss != x.miss ? y.miss - x.miss : y.tries - x.tries })
        if (worst.len() > 0)
        {
            local text = "Worst spots (not hit / tries):"
            foreach (i, s in worst)
                if (i < 3)
                {
                    local num = SpotNumber(s.scen, s.mir)
                    text += format("%s %s %d/%d", i > 0 ? "," : "",
                        num != null ? num : s.scen + (s.mir ? " mirrored" : ""), s.miss, s.tries)
                }
            lines.append(text + ". !goto <number> to practise one.")
        }
        else if (L.spots.len() > 0)
            lines.append("Worst spots: none, every attempt on your own spots hit.")
    }
    local d = due ? DueText() : null
    if (d != null)
        lines.append(d)
    return lines
}

/** !session: the session card in chat and the console. */
function PrintSession(me)
{
    foreach (line in SessionCard(true))
    {
        Say(line)
        ClientPrint(me, Constants.EHudNotify.HUD_PRINTCONSOLE, "[det] " + line + "\n")
    }
}

/** Days since 1970-01-01 of a "YYYY-MM-DD" date, or null (no real clock: 0000-00-00, or not a date). */
function DayNumber(date)
{
    local f = split(date, "-")
    if (f.len() != 3)
        return null
    local y = ToInt(f[0], 0), m = ToInt(f[1], 0), d = ToInt(f[2], 0)
    if (y < 1 || m < 1 || m > 12 || d < 1 || d > 31)
        return null
    if (m <= 2)   // (the year starts in March here, so leap days come last)
        y--
    local era = y / 400
    local yoe = y - era * 400
    local doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
    return era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468
}

/** Days in a row you've practised (any map, from the index's dates), up to and with today. 0: no clock. */
function PracticeDays()
{
    local L = Drill.log
    if (L == null)
        return 0
    local today = DayNumber(L.date)
    if (today == null)
        return 0
    local days = {}
    days[today] <- true   // you're practising now
    foreach (line in L.index)
    {
        local f = Fields(line)
        if (f.len() >= 10 && f[0] == "I")
        {
            local day = DayNumber(f[9])
            if (day != null)
                days[day] <- true
        }
    }
    local n = 0
    while ((today - n) in days)
        n++
    return n
}

// ---- Line-of-sight check -----------------------------------------------------

/** !checklos: queue every Sniper scenario to be played for SCAN_TIME. */
function CheckLos()
{
    if (Drill.scan != null)
    {
        ::Drill.scan = null
        StartScenario()   // a normal (logged) attempt on the one you're left on
        return Say(format("Check stopped. %d bad so far: !losnext to edit them.", Drill.losList.len()))
    }
    local todo = []
    foreach (i, sc in Drill.scenarios)
    {
        local o = Drill.mine[sc.src]
        if (sc.enemy != null && !("cls" in o && o.cls != SNIPER))
            todo.append(i)
    }
    if (todo.len() == 0)
        return Say("No Sniper scenarios to check.")
    ::Drill.editing = false
    ::Drill.fixing = false
    Drill.losList.clear()
    ::Drill.scan = { todo = todo, cur = -1, until = 0.0, total = todo.len() }
    Say(format("Checking %d Sniper scenarios, %.0fs each. Don't touch anything. !checklos to stop.",
        todo.len(), SCAN_TIME))
}

/** Called every tick: move the check on to the next scenario when it's time. */
function ScanStep()
{
    local sc = Drill.scan
    if (sc == null)
        return
    local now = Time()
    if (sc.cur >= 0 && now < sc.until)
        return
    if (sc.todo.len() == 0)
    {
        ::Drill.scan = null
        StartScenario()   // a normal (logged) attempt on the one you're left on
        local nums = ""
        foreach (k, i in Drill.losList)
            if (k < 30)
                nums += (k > 0 ? ", " : "") + (i + 1) + (Drill.scenarios[i].mirrored ? "m" : "")
        if (Drill.losList.len() > 30)
            nums += ", ..."
        if (Drill.losList.len() == 0)
            return Say(format("Checked %d: none start in the Sniper's sight.", sc.total))
        return Say(format("Checked %d: %d start in the Sniper's sight: %s (m = mirrored copy). "
            + "!losnext to edit them one by one.", sc.total, Drill.losList.len(), nums))
    }
    sc.cur = sc.todo.remove(0)
    sc.until = now + SCAN_TIME
    GoTo(sc.cur)
    ClientPrint(GetListenServerHost(), Constants.EHudNotify.HUD_PRINTCENTER,
        format("CHECKING %d / %d  (%d bad)", sc.total - sc.todo.len(), sc.total, Drill.losList.len()))
}

/** Next scenario from the !checklos list, in edit mode. */
function LosNext()
{
    if (Drill.losList.len() == 0)
    {
        if (Drill.fixing)
            StartScenario()
        ::Drill.fixing = false
        return Say("That was the last one. !checklos again to make sure they're all fixed.")
    }
    ::Drill.fixing = true
    local i = Drill.losList.remove(0)
    if (i >= Drill.scenarios.len())
        return LosNext()
    GoTo(i)
    StartEditing()
    Say(format("Scenario %d starts in the Sniper's sight. Find a spot out of it, !setme, then !done "
        + "for the next one (%d left).", i + 1, Drill.losList.len()))
}

// ---- Peeking the Sniper ------------------------------------------------------

/** Can the Sniper see you? Your head or your body in his line of fire. */
function SniperSees(enemy, me)
{
    foreach (spot in [me.EyePosition(), me.GetCenter()])
    {
        local t = { start = enemy.EyePosition(), end = spot, mask = MASK_SHOT, ignore = enemy }
        TraceLineEx(t)
        if (t.hit && "enthit" in t && t.enthit == me)
            return true
    }
    return false
}

/**
 * Sniper scenarios: every tick he can see you adds to Drill.seen, every tick
 * he can't takes it back off. Reach peek_time and he headshots you; the
 * scenario then restarts.
 */
function CheckPeek()
{
    local now = Time()
    if (Drill.restartAt > 0)
    {
        if (now >= Drill.restartAt)
        {
            ::Drill.restartAt = -1.0
            local me = GetListenServerHost()
            if (me != null && !me.IsAlive())
                me.ForceRespawn()
            StartScenario()
        }
        return
    }

    local me = GetListenServerHost()
    local enemy = FindEnemy()
    if ((!Opt.peek && Drill.scan == null) || Opt.peek_time <= 0 || Drill.scenarios.len() == 0 || Current().enemy == null
        || EnemyClass() != SNIPER || Drill.editing
        || me == null || !me.IsAlive() || enemy == null || !enemy.IsAlive()
        || Drill.nextAt > 0 || Drill.placeMeAt > 0                                  // done / not placed yet
        || me.GetMoveType() == Constants.EMoveType.MOVETYPE_NOCLIP)               // looking around after !tp
        return

    // You're placed SPAWN_LIFT up and drop for a moment; that drop can poke your
    // head into his sight. Start counting once you've landed (or after 0.5s).
    if (!Drill.landed)
    {
        if ((me.GetFlags() & Constants.FPlayer.FL_ONGROUND) == 0 && now - Drill.placedAt < 0.5)
            return
        ::Drill.landed = true
    }

    local dt = FrameTime()
    local sees = SniperSees(enemy, me)
    if (sees && !Drill.wasSeen && Opt.sound != "off" && Opt.sound != "")
        EmitSoundOnClient(Opt.sound, me)   // only you hear it, like a sentry locking on
    ::Drill.wasSeen = sees
    if (sees)
    {
        ::Drill.seen += dt
        ClientPrint(me, Constants.EHudNotify.HUD_PRINTCENTER,
            format("SPOTTED  %.1f / %.1fs", Drill.seen, Opt.peek_time))
        if (Drill.seen >= Opt.peek_time && Drill.scan != null)
        {
            Drill.losList.append(Drill.scan.cur)   // he'd have killed you: bad start
            Drill.scan.until = 0.0                 // on to the next one now
            ::Drill.seen = 0.0
        }
        else if (Drill.seen >= Opt.peek_time && !Drill.reviewing)   // reviewing: just warn, so you can try spots
        {
            if (Drill.att != null)
            {
                Drill.att.died = true   // session log (and !stats below)
                Drill.att.deathMs = (AttemptTime() * 1000).tointeger()
                Drill.att.deathAfkMs = ((Drill.afk + AfkNow(now)) * 1000).tointeger()
            }
            SetGlow(true)   // so you see where he was
            // Killed by the world, not the Sniper: his kills would add up to a
            // domination (and the nemesis icon over his head).
            local world = Entities.FindByClassname(null, "worldspawn")
            me.TakeDamageCustom(world, world, null, Vector(0, 0, 0), me.EyePosition(),
                1000, Constants.FDmgType.DMG_BULLET, Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT)
            Say(format("The Sniper got you (seen for %.1fs). Restarting.", Opt.peek_time))
            ::Drill.restartAt = now + 1.5
            Blackout(false)
            if (Drill.att != null && Drill.att.stats && Tracking())
                Count("deaths")
        }
    }
    else if (Drill.seen > 0)
        ::Drill.seen = Drill.seen > dt ? Drill.seen - dt : 0.0
}

// ---- Thinker -----------------------------------------------------------------

function DrillThink()
{
    if (!Drill.ready)
    {
        if (FindEnemy() == null || FindDemo() == null)
            return 0.5
        ::Drill.ready = true
        Say(format("Ready: %d scenarios. Hit the glowing Sniper / destroy the stickies with the Detonator. "
            + "det_help in the console lists all commands.", Drill.scenarios.len()))
        local due = DueText()
        if (due != null)
            Say(due)
        local days = PracticeDays()
        if (days >= 2)
            Say(format("Practice streak: %d days in a row, today included.", days))
        StartScenario()
        return -1
    }

    FixBot(FindEnemy(), EnemyClass())
    if (Drill.editing)
        DrawEditMarkers()
    FixBot(FindDemo(), Constants.ETFClass.TF_CLASS_DEMOMAN)
    TopUpHealth()
    LayStickiesStep()
    CheckStickiesDone()
    DrawFlareTrails()   // also remembers the last explosion for !tp
    AfkStep()
    DrawTpCube()
    GlowTimer()
    ScanStep()
    CheckPeek()

    local now = Time()
    if (Drill.nextAt > 0 && now >= Drill.nextAt)
        NextScenario()

    if (Drill.placeMeAt > 0 && now >= Drill.placeMeAt)
    {
        ::Drill.placeMeAt = -1.0
        local me = GetListenServerHost()
        if (me != null && me.IsAlive() && Drill.scenarios.len() > 0)
        {
            Place(me, Current().me)
            ::Drill.startTime = now
            ::Drill.afk = 0.0
        }
    }
    if (Drill.placeEnemyAt > 0 && now >= Drill.placeEnemyAt)
    {
        ::Drill.placeEnemyAt = -1.0
        local enemy = FindEnemy()
        if (enemy != null && enemy.IsAlive() && Drill.scenarios.len() > 0 && Current().enemy != null)
            Place(enemy, Current().enemy)
    }
    return -1   // every tick, so stickies get laid quickly
}

foreach (name in ["det_thinker", "sticky_thinker"])
{
    local old = Entities.FindByName(null, name)
    if (old != null)
        old.Kill()
}
local thinker = SpawnEntityFromTable("info_target", { targetname = "det_thinker" })
thinker.ValidateScriptScope()
thinker.GetScriptScope().DrillThink <- DrillThink
AddThinkToEnt(thinker, "DrillThink")

// Reloaded while pretend ping was pressing mouse2 for you: let go of it.
local host = GetListenServerHost()
if (host != null)
    NetProps.SetPropInt(host, "m_afButtonForced",
        NetProps.GetPropInt(host, "m_afButtonForced") & ~Constants.FButtons.IN_ATTACK2)

// ---- Events ------------------------------------------------------------------

ClearGameEventCallbacks()

/** Forget every domination (the icons over players' heads). */
function ClearDominations()
{
    for (local i = 1; i <= MaxClients().tointeger(); i++)
    {
        local p = PlayerInstanceFromIndex(i)
        if (p == null)
            continue
        local n = NetProps.GetPropArraySize(p, "m_Shared.m_bPlayerDominated")
        for (local j = 0; j < n; j++)
        {
            NetProps.SetPropBoolArray(p, "m_Shared.m_bPlayerDominated", false, j)
            NetProps.SetPropBoolArray(p, "m_Shared.m_bPlayerDominatingMe", false, j)
        }
    }
}

function OnGameEvent_player_spawn(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p == null || !Drill.ready)
        return
    if (p in Drill.anchors)
        delete Drill.anchors[p]   // re-pinned where he spawned, or where he's placed
    // Teleporting during the spawn event gets overridden, so do it a moment later.
    if (p == GetListenServerHost())
        ::Drill.placeMeAt = Time() + 0.1
    else if (p == FindEnemy())
        ::Drill.placeEnemyAt = Time() + 0.1
    else if (p == FindDemo())
    {
        printl("[det] Demo respawned, laying his stickies again")
        LayStickies()   // his stickies vanished when he respawned; lay them again
    }
}

/** Debug: why did one of our bots die? (printed to the console) */
function OnGameEvent_player_death(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p == null || (p != FindDemo() && p != FindEnemy()))
        return
    local attacker = GetPlayerFromUserID(params.attacker)
    printl(format("[det] %s died: attacker=%s weapon=%s customkill=%d damagebits=%d health=%d alive_time=%.1fs "
        + "pos=%s weapon_in_hand=%s queue=%d",
        NetProps.GetPropString(p, "m_szNetname"),
        attacker == null ? "none" : NetProps.GetPropString(attacker, "m_szNetname"),
        "weapon" in params ? params.weapon : "?", params.customkill, params.damagebits,
        p.GetHealth(), p in Drill.anchors ? Time() - Drill.anchors[p].from : -1.0,
        VecStr(p.GetOrigin()),
        p.GetActiveWeapon() == null ? "none" : p.GetActiveWeapon().GetClassname(), Drill.queue.len()))
}

function OnGameEvent_player_hurt(params)
{
    local me = GetListenServerHost()
    if (me == null || GetPlayerFromUserID(params.attacker) != me)
        return
    local victim = GetPlayerFromUserID(params.userid)
    if (victim != null && victim == FindEnemy() && params.custom != Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING)
    {
        // For telling a direct hit from a detonation (FlareEnd).
        ::Drill.hurtAt = Time()
        ::Drill.hurtCustom = params.custom
        if (params.custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING_FLARE)
            ::Drill.impactAt = Time()
    }
    if (victim == null || victim != FindEnemy() || Drill.nextAt > 0 || Drill.editing || Drill.scan != null)
        return
    if (Drill.scenarios.len() == 0 || Current().enemy == null)
        return
    // Afterburn isn't a hit (and would otherwise "hit" the next scenario's enemy).
    if (params.custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING)
        return

    if (DETONATOR_ONLY)
    {
        local w = me.GetActiveWeapon()
        if (w == null || w.GetClassname() != "tf_weapon_flaregun")
            return
    }

    SetGlow(false)
    Finish()
}

function OnGameEvent_player_say(params)
{
    local p = GetPlayerFromUserID(params.userid)
    if (p != null && p == GetListenServerHost())
        DrillCommand(params.text)
}

// Console versions, so you don't spam chat (and get kicked for flooding):
//   det_keep, det_next, ...   every chat command as a console command (aliases
//                             made at the bottom of this file; bindable too)
//   script Det("tp")          the same, by name
function Det(cmd) { DrillCommand("!" + cmd) }
function DetTp() { DrillCommand("!tp") }
function DetReset() { DrillCommand("!reset") }
function DetNext() { DrillCommand("!next") }
function DetSound() { DrillCommand("!sound") }
function DetPrev() { DrillCommand("!prev") }

function DrillCommand(text)
{
    local me = GetListenServerHost()
    if (me == null)
        return
    local n = Drill.scenarios.len()

    if (text == "!reset")
        StartScenario()
    else if (text == "!next")
        GoTo(Drill.index + 1)
    else if (text == "!prev")
        GoTo(Drill.index - 1)
    else if (text == "!goto" || text.find("!goto ") == 0)
    {
        local want = 0
        try { want = text.slice(6).tointeger() } catch (e) {}
        if (want < 1 || want > n)
            return Say(format("Usage: !goto <1-%d>  (console: script Det(\"goto 12\"))", n))
        GoTo(want - 1)
    }
    else if (text == "!tp")
        TeleportToBoom(me)
    else if (text == "!zeroping")
        ToggleZeroPing()
    else if (text == "!checklos")
        CheckLos()
    else if (text == "!losnext")
        LosNext()
    else if (text == "!help")
    {
        PrintHelp(me)
        Say("Commands listed in the console (~).")
    }
    else if (text == "!review")
    {
        ::Drill.reviewing = !Drill.reviewing
        ::Drill.mine = LoadScenarios()
        ::Drill.index = 0
        Rebuild()
        if (Drill.reviewing)
        {
            local at = LoadProgress()
            if (at > 0 && at < Drill.scenarios.len())
            {
                ::Drill.index = at
                Say(format("Continuing where you left off (spot %d). !review_restart to start over.", at + 1))
            }
        }
        if (Drill.reviewing && Drill.mine.len() == 0)
            Say("No review list for this map (tf/scriptdata/" + ReviewFile() + ").")
        else
            Say(Drill.reviewing ? format("Reviewing %d spots from your demos. !keep saves one, !review to go back.", Drill.mine.len())
                : format("Back to your %d scenarios.", Drill.mine.len()))
        StartScenario()
    }
    else if (text == "!review_restart")
    {
        if (!Drill.reviewing)
            return Say("!review_restart only works while reviewing (!review).")
        GoTo(0)
        Say("Back to the first review spot.")
    }
    else if (text == "!keep")
    {
        if (!Drill.reviewing || n == 0)
            return Say("!keep only works while reviewing (!review).")
        if (!me.IsAlive() || me.GetMoveType() == Constants.EMoveType.MOVETYPE_NOCLIP
            || (me.GetFlags() & Constants.FPlayer.FL_ONGROUND) == 0)
            return Say("Stand on the ground where you want to start, then !keep.")
        // Your spot as you stand now (move / turn first to adjust it); his spot as recorded.
        local sc = Original()
        local kept = { me = { pos = me.GetOrigin(), ang = me.EyeAngles() }, enemy = sc.enemy, stickies = sc.stickies }
        local mine = LoadScenarios(MyFile())
        if (AlreadyKept(kept, mine))
            return Say("Already kept this one.")
        mine.append(kept)
        SaveList(mine, MyFile())
        Say(format("Kept: now %d scenarios of your own (+ mirrored).", mine.len()))
    }
    else if (text == "!sound")
    {
        local i = SOUNDS.find(Opt.sound)
        Opt.sound = SOUNDS[i == null ? 0 : (i + 1) % SOUNDS.len()]
        SaveOptions()
        EmitSoundOnClient(Opt.sound, me)
        Say(format("Peek sound %d/%d: %s (saved)", SOUNDS.find(Opt.sound) + 1, SOUNDS.len(), Opt.sound))
    }
    else if (text == "!set" || text == "!settings")
    {
        PrintSettings(me)
        Say("Settings listed in the console (~). !set <name> <value> to change one.")
    }
    else if (text.find("!set ") == 0)
    {
        local rest = strip(text.slice(5))
        local sp = rest.find(" ")
        local name = (sp == null ? rest : rest.slice(0, sp)).tolower()
        local value = sp == null ? "" : strip(rest.slice(sp + 1))
        local err = SetOption(name, value)
        if (err != null)
            return Say(err)
        SaveOptions()
        ApplyOption(name)
        Say(format("%s = %s (saved)", name, OptStr(Opt[name])))
    }
    else if (text == "!stats")
    {
        PrintStats(me)
        local st = Drill.session
        Say(format("This session: %d attempts, %d hit (%s), %d with the first flare (%s). More in the console (~).",
            st.tries, st.hits, Pct(st.hits, st.tries), st.first, Pct(st.first, st.tries)))
    }
    else if (text == "!log")
        PrintLog(me)
    else if (text == "!spot")
        PrintSpot(me)
    else if (text == "!session")
        PrintSession(me)
    else if (text == "!stats_reset")
    {
        ::Drill.total = NewStats()
        Drill.per.clear()
        SaveStats()
        ResetAgg()
        Say("All-time stats for this map cleared, per-scenario ones too (this session's are kept).")
    }
    else if (text == "!stats_rebuild")
    {
        local r = RebuildAgg()
        Say(format("Per-scenario stats rebuilt from %d attempts in %d session logs%s. !stats to see them.",
            r.attempts, r.sessions, Drill.aggReset != null ? " (since your last !stats_reset)" : ""))
    }
    else if (text == "!list")
    {
        Say(format("Scenario %d of %d (%d yours%s), edits saved in tf/scriptdata/%s",
            Drill.index + 1, n, Drill.mine.len(), Mirrors() ? " + mirrored" : "", SaveFile()))
        foreach (line in [DueText(), ReviewLeftText()])
            if (line != null)
                Say(line)
    }
    else if (text == "!new")
    {
        Drill.mine.append({ me = { pos = me.GetOrigin(), ang = me.EyeAngles() }, enemy = null, stickies = [] })
        Rebuild()
        SaveScenarios()
        ::Drill.index = Mirrors() ? Drill.scenarios.len() - 2 : Drill.scenarios.len() - 1
        StartScenario()
        StartEditing()
        Say(format("Added scenario %d starting here (blue box). Pick the enemy with !class <name>, "
            + "then go where he should stand and !setenemy (or !addsticky for stickies).", Drill.index + 1))
    }
    else if (text == "!duplicate")
    {
        if (n == 0)
            return Say("No scenarios yet. Type !new first.")
        if (Drill.reviewing)
            return Say("In review, !keep saves a spot (where you stand now).")
        // A copy of the scenario as you see it (the mirrored side, if that's the one
        // playing), so changing it leaves the original as it was.
        local sc = Current()
        local copy = { me = sc.me, enemy = sc.enemy, stickies = clone sc.stickies }
        if ("cls" in Original())
            copy.cls <- Original().cls
        local from = Drill.index + 1
        Drill.mine.append(copy)
        Rebuild()
        SaveScenarios()
        ::Drill.index = Mirrors() ? Drill.scenarios.len() - 2 : Drill.scenarios.len() - 1
        StartScenario()
        StartEditing()
        Say(format("Scenario %d is a copy of %d: change it, then !done (!delete if you don't want it).",
            Drill.index + 1, from))
    }
    else if (text == "!edit")
    {
        if (n == 0)
            return Say("No scenarios yet. Type !new first.")
        StartEditing()
    }
    else if (text == "!done")
    {
        if (!Drill.editing)
            return Say("Not editing. !edit to edit this scenario.")
        ::Drill.editing = false
        Drill.old.clear()
        Say(format("Scenario %d saved.", Drill.index + 1))
        if (Drill.fixing)
            LosNext()
        else
            StartScenario()
    }
    else if (text == "!class" || text.find("!class ") == 0)
    {
        if (n == 0)
            return Say("No scenarios yet. Type !new first.")
        local cls = -1
        if (text == "!class")
            cls = EnemyClass() % 9 + 1
        else
        {
            local want = text.slice(7).tolower()
            foreach (i, name in CLASS_NAMES)
                if (i > 0 && (name == want || (want.len() >= 3 && name.find(want) == 0)))
                    cls = i
            if (want == "demo")
                cls = 4
            if (want == "engi" || want == "engy")
                cls = 9
        }
        if (cls < 1)
            return Say("Unknown class. scout, soldier, pyro, demoman, heavy, engineer, medic, sniper, spy")
        Original().cls <- cls
        SaveScenarios()
        Say(format("Scenario %d: enemy is a %s%s.", Drill.index + 1, CLASS_NAMES[cls],
            Current().enemy == null ? " (now place him: !setenemy)" : ""))
    }
    else if (n == 0)
        Say("No scenarios yet. Type !new first.")
    else if (text == "!setme")
    {
        EditCurrent("me", { pos = me.GetOrigin(), ang = me.EyeAngles() })
        Say(format("Scenario %d: your start saved.", Drill.index + 1))
    }
    else if (text == "!setenemy")
    {
        // The Sniper faces the way you're looking (flattened, so he doesn't look at the floor).
        local a = me.EyeAngles()
        local hadStickies = Original().stickies.len() > 0
        Original().stickies.clear()     // one target type per scenario
        EditCurrent("enemy", { pos = me.GetOrigin(), ang = QAngle(0, a.y, 0) })
        Say(format("Scenario %d: %s position saved%s.", Drill.index + 1, CLASS_NAMES[EnemyClass()],
            hadStickies ? " (stickies removed, it's an enemy scenario now)" : ""))
        if (Drill.editing)
        {
            // Keep walking around: just put him there (you stay where you are).
            local enemy = FindEnemy()
            if (enemy != null && enemy.IsAlive())
                Place(enemy, Current().enemy)
            SetGlow(true)
            KillStickies()
        }
        else
            StartScenario()
    }
    else if (text == "!addsticky")
    {
        local list = Original().stickies
        if (list.len() >= MAX_STICKIES)
            return Say(format("A launcher only holds %d stickies.", MAX_STICKIES))
        // Find the surface under your crosshair.
        local eye = me.EyePosition()
        local trace = {
            start = eye
            end = eye + me.EyeAngles().Forward() * STICKY_REACH
            mask = MASK_SOLID_BRUSHONLY
            ignore = me
        }
        TraceLineEx(trace)
        if (!trace.hit || !("plane_normal" in trace))
            return Say("Aim at a floor, wall or ceiling to place a sticky.")

        local hadSniper = Original().enemy != null
        Original().enemy = null         // one target type per scenario
        local st = { pos = trace.pos, n = trace.plane_normal }
        list.append(Current().mirrored ? MirrorSticky(st) : st)
        Rebuild()
        SaveScenarios()
        if (hadSniper)
            StartScenario()             // sends the Sniper away, lays the sticky
        else
            LayStickies()
        Say(format("Scenario %d: sticky %d added%s.", Drill.index + 1, list.len(),
            hadSniper ? " (Sniper removed, it's a sticky scenario now)" : ""))
    }
    else if (text == "!undosticky")
    {
        local list = Original().stickies
        if (list.len() == 0)
            return Say("No stickies in this scenario.")
        list.pop()
        Rebuild()
        SaveScenarios()
        LayStickies()
        Say(format("Scenario %d: last sticky removed, %d left.", Drill.index + 1, list.len()))
    }
    else if (text == "!clearstickies")
    {
        Original().stickies.clear()
        Rebuild()
        SaveScenarios()
        KillStickies()
        Say(format("Scenario %d: stickies removed.", Drill.index + 1))
    }
    else if (text == "!delete")
    {
        Drill.mine.remove(Current().src)
        Rebuild()
        SaveScenarios()
        Say(format("Deleted. %d scenarios left.", Drill.scenarios.len()))
        GoTo(Drill.index)
    }
}

function OnGameEvent_teamplay_round_start(_params)
{
    LockPoint()
}

__CollectGameEventCallbacks(this)

// ---- Setup -------------------------------------------------------------------

LoadOptions()
LoadStats()
LogInit()
LoadAgg()   // after LogInit: a missing cache is rebuilt from the logs in its index
::Drill.mine = LoadScenarios()
// Candidates for the peek sound; !sound plays the next one and uses it.
::SOUNDS <- [
    "TFPlayer.ReCharged",                // player/recharged.wav: the full-charge ding
    "Weapon_SniperRifle.BoltBack",       // rifle bolt pulled back
    "Weapon_SniperRifle.BoltForward",    // rifle bolt pushed forward
    "Weapon_SniperRifle.Draw",           // pulling the rifle out
    "Weapon_SniperRifle.ClipEmpty",      // dry click
    "Weapon_SniperRailgun.BoltBack",     // Machina bolt back
    "Weapon_SniperRailgun.NonScoped",
    "Weapon_SniperRifle.Single",         // the shot itself
    "Building_Sentrygun.Alert",          // the current one (sentry_spot.wav)
]
foreach (snd in SOUNDS)
    PrecacheScriptSound(snd)
if (Opt.sound != "off")
    PrecacheScriptSound(Opt.sound)
PrecacheScriptSound(WALL_SOUND)
PrecacheScriptSound(DIRECT_SOUND)
Rebuild()

// Remove leftover bots from older scripts (det_viaduct's bot01..bot15).
for (local i = 1; i <= 15; i++)
    SendToConsole(format("kick bot%02d", i))
SendToConsole("kick sticky_demo")

// Puppet bots from older versions of this script (made with the cheat command
// `bot`) are replaced by TFBots.
foreach (b in [FindEnemy(), FindDemo()])
    if (b != null && !b.IsBotOfType(Constants.EBotType.TF_BOT_TYPE))
        SendToConsole("kick " + NetProps.GetPropString(b, "m_szNetname"))

SendToConsole(FAKE_LAG > 0 ? "sv_cheats 1" : "sv_cheats 0")
// TFBots don't pull the trigger at all. Scripts may set this one (it's in
// cfg/vscript_convar_allowlist.txt); it's reset on map change.
Convars.SetValue("tf_bot_fire_weapon_allowed", 0)
// No random crits (melee too).
Convars.SetValue("tf_weapon_criticals", 0)
Convars.SetValue("tf_weapon_criticals_melee", 0)
// TFBots in a spawn room keep reconsidering their class; a class change
// respawns the Demo and his stickies vanish (then get laid again, over and over).
Convars.SetValue("tf_bot_reevaluate_class_in_spawnroom", 0)
Convars.SetValue("tf_bot_keep_class_after_death", 1)
// Bots turn towards gunfire they hear (your flares); stop the Sniper doing that.
Convars.SetValue("tf_bot_notice_gunfire_range", 0)
Convars.SetValue("tf_bot_notice_quiet_gunfire_range", 0)
SendToConsole("mp_waitingforplayers_cancel 1")
SendToConsole("mp_autoteambalance 0")
SendToConsole("mp_teams_unbalance_limit 0")
SendToConsole("net_fakelag " + FAKE_LAG)   // ignored (stays 0) with cheats off
SendToConsole("bind KP_HOME \"script DetReset()\"")   // numpad 7
SendToConsole("bind KP_PGUP \"script DetTp()\"")      // numpad 9
SendToConsole("bind KP_PGDN \"script DetSound()\"")   // numpad 3

// Console commands: det_<command> for every chat command (det_keep, det_next, ...).
// Each alias calls a no-argument function, since quotes can't nest in an alias.
foreach (c in ["help", "checklos", "losnext", "reset", "next", "prev", "tp", "zeroping", "sound", "review", "review_restart", "keep", "list", "new", "duplicate",
    "set", "settings", "stats", "stats_reset", "stats_rebuild", "spot", "session", "log", "edit", "done", "class", "setme", "setenemy", "addsticky", "undosticky", "clearstickies", "delete"])
{
    getroottable()["DetCmd_" + c] <- (function(c) { return function() { DrillCommand("!" + c) } })(c)
    SendToConsole(format("alias det_%s \"script DetCmd_%s()\"", c, c))
}
// det_toggle_<name> (det_toggle_hardcore, ...) flips an on/off setting.
foreach (o in OPTIONS)
    if (typeof o[1] == "bool")
    {
        getroottable()["DetToggle_" + o[0]] <- (function(name) { return function() { DrillCommand("!set " + name) } })(o[0])
        SendToConsole(format("alias det_toggle_%s \"script DetToggle_%s()\"", o[0], o[0]))
    }
// det_class_<name> (det_class_soldier, ...) sets the enemy class from the console.
foreach (i, name in CLASS_NAMES)
    if (i > 0)
    {
        getroottable()["DetClass_" + name] <- (function(name) { return function() { DrillCommand("!class " + name) } })(name)
        SendToConsole(format("alias det_class_%s \"script DetClass_%s()\"", name, name))
    }
local enemyTeamName = EnemyTeam() == Constants.ETFTeam.TF_TEAM_RED ? "red" : "blue"
// noquota: don't raise tf_bot_quota, so they don't come back on the next map.
local enemy = FindEnemy()
if (enemy == null || !enemy.IsBotOfType(Constants.EBotType.TF_BOT_TYPE))
    SendToConsole(format("tf_bot_add 1 sniper %s easy %s noquota", enemyTeamName, ENEMY_NAME))
local demo = FindDemo()
if (demo == null || !demo.IsBotOfType(Constants.EBotType.TF_BOT_TYPE))
    SendToConsole(format("tf_bot_add 1 demoman %s easy %s noquota", enemyTeamName, DEMO_NAME))
LockPoint()
ClearDominations()   // left over from earlier versions, where the Sniper got the kills
