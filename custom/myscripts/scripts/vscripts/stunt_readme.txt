STUNT SCRIPT - how to use it
============================

Records TF2 stunts tick by tick on the host's local server. You can rewind to any
moment or checkpoint and retry from there, put several people (or bots) in one scene,
and export a demo. Made for staged clips and jump runs, not for real matches.

Install: put stunt.nut in Team Fortress 2/tf/custom/stunt/scripts/vscripts/ (host only;
friends install nothing). Start: map <any map>, then script_execute stunt in the console.
Run script_execute stunt again after every map change. Friends join with a Steam invite.

The script changes the host's server until TF2 restarts: sv_cheats 1, no random crits or
damage spread, instant respawn, no autobalance, no fall damage for players. Bots and
anyone frozen or replaying can't die.


COMMANDS
--------
Type them in chat. !help lists them, !help <command> explains one (to you only).
From the console: say !rr. The host also has ss_<command> without arguments:
    host:     bind r ss_rr          bind x ss_cp        bind mouse4 ss_fire
    friends:  bind r "say !rr"      bind x "say !cp"    bind mouse4 "say !fire"
Ticks: 66 per second (tick 300 = 4.5 s).


A RUN
-----
1. Everyone picks a team and class. Players only hurt or push each other on opposite teams.
2. !new           everyone on a team records from where they stand (1 s countdown, !go
                  skips it; you're frozen during it and can't shoot).
3. !cp            after each jump you land: checkpoint at this tick.
4. !rr            failed? Everyone goes back to the last checkpoint (or the start of the
                  take) and is live again. A short run-up replays first; !runup 0 makes it
                  shorter (there's still a 0.3 s freeze, longer if something was in the air).
5. !stop          end the take.   !play  watch it back: the good attempts join seamlessly.

With friends, !new, !rw, !to and !rr put EVERYONE back, and everything after that tick is
recorded again for everyone; anyone's !undo or !load changes the whole scene.
    !live me / !live soldier pyro   only those re-record; the rest replay   (!live all)
    !rw 20 / !to 300                back 20 ticks / to tick 300 (default !rw is 33)
    !undo / !redo                   undo the last command, for everyone it touched
During run-ups and !play don't touch your keyboard or mouse: the script is moving you.
Friends being replayed see their view step and miss their own weapon sounds; it looks
normal to everyone else. If you die while recording, your take stops: !rr to retry.


TRACKS (actors)
---------------
Each player plays one track. Alone, you can record one track, switch to another, and a
bot replays the first while you record the second.
    !track soldier blue   play the track called "soldier" (any name; it does NOT set your
                          class). A new track moves you to that team: then pick your class
                          and !new. Taking a recorded track, or any !rr/!rw/!play, respawns
                          you as that track's class and team.
    !tracks               list them        !shift soldier -5   move it 5 ticks earlier
    !mute / !unmute / !del <track>
Bots named after tracks (and ss_shooter) join and leave by themselves: leave free player
slots, and don't name a track after a player.


DETONATOR
---------
    !shooter [track]  a Detonator bot stands where you are and aims at your track (or that
                      one). Whoever reflects its flare live gets it detonated !burst times
                      at once.
    !fire             it fires now: during a take (recorded) or between takes (practice);
                      not during a run-up. !fireat off: it never fires by itself.
    !burst 7          detonations (7 is enough for max speed)
    !det me           (Pyro) you get the Detonator instead, in place of your secondary:
                      M1 fires, M2 while your flare is reflected bursts it.
    !noshooter        remove the bot


MAKING THE VIDEO
----------------
Host:    !render clip     one demo of the whole scene from the host's track
                          (tf/clip_<date>_<time>.dem). Not while a !demo is recording.
Friends: bind k "record mypov; hud_saytext_time 0; say !mark mypov"
         bind j "stop; hud_saytext_time 12; say !mark off"
         press k before the takes and j after; !cuts then lists (in your console) which
         parts of mypov.dem to keep. Use a new name each time. While you're marked, script
         messages go to your console only.
Chat is saved in demos: watch or render them with hud_saytext_time 0.
Play demos with demoui (Shift+F2 during playback).


SAVE / LOAD
-----------
    !save myscene / !load myscene     in the host's tf/scriptdata (no double __ in names). !save overwrites;
                                      !load replaces the scene and clears undo. Only load
                                      a scene on the map it was saved on.

Problems: !keys (host) if the host keeps moving or shooting by itself. !diag, then the
HOST sends the [stunt] lines from the host's console.
