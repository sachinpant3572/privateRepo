# Fracture: audio

How the game's sound works, and how to replace the built-in music with
studio-quality tracks.

## What's in the game now

| Part | Files | Made with |
|---|---|---|
| Music | `games/prototype/audio/music/*.ogg` | `tools/audio/compose.py` (original, composed in code) |
| Combat sound effects | `games/prototype/audio/sfx/<id>_<n>.ogg`: weapons, impacts, explosions, alarm, freeze | Recorded-style audio from Higgsfield video clips, cut by `tools/audio/realistic.py` |
| Interface and reward sounds | same folder: pickups, level-up, cards, synergy, evolution | `tools/audio/sfx.py` (synthesized: clean and crisp suits these) |
| Announcer | `games/prototype/audio/voice/*.ogg` (28 lines) | Higgsfield, ElevenLabs v4, voice "Gideon", stability 0 with delivery tags such as `[shouting excitedly]` and `[urgent, shouting]` |

**Adaptive music (`music.gd`):**
- The stage music is two stems that play in sync: **calm** (pads, bass,
  taiko, arpeggio) and **combat** (drums, drive bass, brass, lead). The
  combat stem fades in with the fight: more enemies and a higher combo
  bring it up quickly; it falls back slowly, so a short lull doesn't drop
  the drums.
- The boss crossfades to its own track. Winning or losing plays a stinger
  under the announcer.
- Level-up cards, chests and the revive screen muffle the music with a
  low-pass filter.
- Big moments (synergy, evolution, big explosions, announcer lines) duck
  the music for a moment.

**Built for phone speakers:** phones can't play below about 100 Hz, and
trying to makes them distort. The combat recordings have their sub-bass cut
and their 150–500 Hz punch lifted, and are never saturated. At most 3
explosions play at once (`MAX_AT_ONCE` in `sfx.gd`).

**Why it doesn't get tiring:**
- Long loops: 2 minutes for the stage, in four 16-bar sections with
  different chord progressions, melodies and fills.
- The combat layer changes the arrangement constantly as the fight ebbs and
  flows, so the same 2 minutes never sound the same twice.
- Every sound effect has 2–5 variations plus random pitch, and a minimum gap
  so hundreds of hits per second stay clean.
- Two voice pools: busy combat sounds can't cut off rewards and interface
  sounds. A limiter on the master bus prevents clipping.

## Replacing the music with studio tracks

The built-in music is original but synthesized. For the release, generate
tracks with **Suno** (Pro or Premier plan) or **ElevenLabs Music** (paid
plan). Both grant commercial rights on paid plans; check the current terms
before release.

**How to swap a track in:**
1. Generate the track with the prompt below, as an instrumental.
2. Trim it so it loops cleanly: cut on a downbeat at the start and the end.
   Suno's "extend" helps reach the target length.
3. Export as `.ogg` (or convert with
   `ffmpeg -i in.wav -c:a libvorbis -q:a 5 out.ogg`).
4. Save it as `games/prototype/audio/music/<name>.ogg`, replacing the file
   of the same name, and push. The game picks it up automatically.

For the stage you can either:
- replace both stems (`stage_calm.ogg` and `stage_combat.ogg`, same length
  and tempo, starting on the same beat), which keeps the adaptive layering,
  or
- add one full track as `stage.ogg`. The game then plays it as-is, without
  layering.

### Prompts

All tracks share one musical identity: **D minor, a heroic five-note motif
(D–A–F–E–D), hybrid orchestral and electronic, military percussion.**

**`menu.ogg`, 90 BPM, about 64 s loop**
> Instrumental, cinematic hybrid orchestral, 90 BPM, D minor. Heroic but
> restrained title-screen theme: warm analog synth pads, low strings, distant
> taiko hits, a lone French horn stating a five-note heroic motif (D, A, F,
> E, D), a soft glassy arpeggio entering halfway. Sense of a hero standing
> above a ruined city at dawn. No vocals, no drums kit, seamless loop.

**`stage_calm.ogg` + `stage_combat.ogg`, 128 BPM, 2:00 loop**
> Instrumental, hybrid orchestral electronic action, 128 BPM, D minor,
> chord progression Dm–Bb–F–C then Dm–Gm–Bb–A. Driving taiko and military
> snare, pulsing sidechained synth bass, aggressive brass stabs, staccato
> strings, a heroic synth lead in the second half. Relentless forward energy
> for a top-down shooter fighting an army of tanks and helicopters. No vocals.
> Loopable, consistent tempo.

Then generate the calm stem with the same prompt plus:
> stripped back: only pads, bass and light percussion, no kick drum, no lead.

(Or use Suno's stem separation on the full track: drums, bass and lead
into `stage_combat.ogg`, everything else into `stage_calm.ogg`.)

**`boss.ogg`, 140 BPM, about 55 s loop**
> Instrumental, epic boss battle, 140 BPM, D phrygian (Dm–Eb–Dm–C),
> massive taiko ensemble, distorted synth bass ostinato, huge brass hits on
> every bar, alarm-like high strings, choir "ah" swells, industrial impacts.
> A colossal siege tank is attacking. Intense, no vocals, seamless loop.

**`victory.ogg`, about 6 s, not looped**
> Short triumphant orchestral fanfare in D major, brass and timpani roll,
> ending on a big sustained chord with cymbal swell.

**`defeat.ogg`, about 6 s, not looped**
> Short somber orchestral sting in D minor, descending low brass, one deep
> impact, fading strings.

## Realistic combat sounds

The weapon, impact and explosion sounds come from short Higgsfield video
clips with native audio (Seedance 2.0 Mini, 480p, 5 s, about 2 credits
each; 14 clips in all). `tools/audio/realistic.py` finds each event in a
clip, cuts it out, trims and fades it, and matches its loudness to the sound
it replaces. Each clip gives 3 to 7 variations.

| Clip | Prompt (short) | Becomes |
|---|---|---|
| cannon | battle tank fires its main cannon, explosions downrange | `boom`, `big_boom` |
| rifle | futuristic energy rifle firing rapid plasma bursts | `shot` |
| shotgun | heavy combat shotgun, four blasts with a pump rack | `scatter` |
| rocket | small guided missiles launching one by one | `rocket` |
| railgun | railgun charging and firing with a supersonic crack | `rail` |
| flame | flamethrower, three roaring bursts | `flame` |
| grenade | grenade launcher thunks and distant blasts | `grenade` |
| tesla | giant tesla coil throwing lightning | `zap` |
| drone | combat drone firing laser blaster bursts | `drone` |
| armor | bullets striking a steel armor plate | `hit` |
| depot | fuel depot detonating in one gigantic explosion | `big_boom` |
| explosions | medium explosions one at a time | `boom` |
| siren | air-raid siren and klaxon | `alarm` |
| frost | frost blast freezing water into ice | `freeze` |
| jet | two fighter jets screaming past overhead | `jet` |
| gunship | attack helicopter firing its autocannon in bursts | `gunship` |
| siege | huge siege artillery cannon, three deep thumps | `siege` |

Every prompt ends with "No music, no voices, only ... sound effects", and
asks for pauses between events so they can be cut apart. To redo one: make
the clip, save it as `<clip>.mp4` in a folder, then run
`python3 tools/audio/sfx.py && python3 tools/audio/realistic.py <folder>`.

## Regenerating the built-in audio

```
python3 tools/audio/compose.py        # music (about 30 s)
python3 tools/audio/sfx.py            # sound effects (about 5 s)
```

Both need Python 3 with numpy, and ffmpeg with libvorbis. The output is
deterministic: the same code always renders the same files.

**Sound IDs** that game code can play with `sfx.play(id)`:
- Weapons: `shot`, `scatter`, `rocket`, `rail`, `flame`, `grenade`, `mine`,
  `drone`, `zap`.
- Impacts: `hit`, `boom`, `big_boom`, `hurt`.
- Pickups and rewards: `gem`, `coin`, `level`, `fanfare`, `tick`, `powerup`,
  `freeze`, `heal`, `shield`.
- Big moments: `synergy`, `evolve`, `limit_break`, `alarm`.
- Interface: `card_show`, `card_pick`, `ui_tap`.

Announcer lines play by themselves from HUD banners (see `BANNER_VOICES` in
`sfx.gd`), or directly with `sfx.announce(id)`.
