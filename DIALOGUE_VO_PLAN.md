# Dialogue and voiceover plan

Status: **plan, not started** (Wednesday, Oct 28, 2026). Nothing in `game/` changes until a phase
below is picked up. Sachin asked: "Also, plan meticulousyl and thoroughly for immaculate, fully
realistic player, and NPC dialogues, during free roam or during missions, and plan voiceovers too
in the late stages of the game. Or see how rockstar and other studios famous for open world games
plan such things and then add the same to our TODO."

How facts are marked in this file:
- **[V]** found in a source, linked beside it. Page fetches were blocked in this session
  (emshort.blog and developer.valvesoftware.com would not resolve), so every [V] rests on search
  excerpts of the linked page, not a full read of it.
- **[U]** unverified: sources disagree, or only weak sources were found.
- **[I]** our own inference or proposal.

Setting note: the brief called Solvera "California-like". `WORLD_BIBLE.md` makes it a Gulf-coast
state; Act 1 is in **Bellerive** (New Orleans-inspired, the Florida-like city in v3), and a
California city is expansion 2 (`TODO.md`). Regional flavour below follows the bible.

## 1. The five decisions that matter most

1. **Every line is data with an ID, from day one.** Mission scripts, barks, phone messages and
   radio all go through one line table. Voice, translations and lip sync attach to the ID later,
   so text-first work is never thrown away. [I]
2. **Pick lines with a rule matcher in the style of Valve's.** Facts about the world, the speaker
   and the event form a query; the most specific rule that fully matches wins; cooldowns and memory
   stop repeats. This is the design behind Left 4 Dead's dialogue and Valve's Response System. [V]
3. **One speech manager decides who may talk.** Mission lines beat player lines, which beat
   reactions, which beat chatter; a bark that would talk over a story line is dropped, and an
   interrupted conversation resumes with a bridging line. [I, built on the resumable-banter idea, §2.5]
4. **Text barks now, non-verbal sounds next, voice last.** Screams, gasps and grunts are
   language-free and cheap; spoken VO comes once Act 1's script is locked. [I]
5. **No cloned or synthetic voice of a real person without written, specific consent and pay**,
   and disclose any AI voice in the store listing. Text-to-speech is a placeholder tool for timing,
   not the shipped cast. [I, grounded in §2.8]

## 2. What the studios do

### 2.1 Scale (for perspective, not a target)

| Game | Dialogue | Cast | Mark |
|---|---|---|---|
| GTA IV (2008) | over 80,000 lines; over 7,000 for Niko; an average pedestrian about 200 lines (range 20-300) | over 740 voices | [V] forum repost of the GamesRadar audio Q&A: https://www.gamesradar.com/grand-theft-auto-iv-audio-qa , https://thegtaplace.com/forums/topic/17019-gamesradar-gta-iv-audio-qa |
| GTA V (2013) | over 150,000 lines (another source: close to 160,000) | about 700 actors | [U] one trade article: https://www.audiotechnology.com/features/grand-theft-audio ; https://www.watchmojo.com/articles/top-10-grand-theft-auto-facts |
| Red Dead Redemption 2 (2018) | 500,000 lines; main script about 2,000 pages | 1,200 actors, 700 of them voiced | [V] secondary reports of Dan Houser's Vulture interview: https://www.gamesradar.com/red-dead-redemption-2-has-a-60-hour-story-500000-lines-of-dialogue , https://www.techspot.com/news/76927-red-dead-redemption-2-details-revealed-60-hours.html |
| Skyrim / Fallout 4 | about 60,000 / over 111,000 voiced lines | Fallout 4's two player voices over 13,000 lines each | [V] https://www.pcgamesn.com/fallout-4/fallout-4-is-going-to-talk-your-ear-off-with-over-111000-lines-of-spoken-dialogue |
| Left 4 Dead 2 | about 10,000 spoken lines | 4 survivors (plus others) | [V] Ruskin's own write-up: http://assemblyrequired.crashworks.org/ai-driven-dynamic-dialog-at-gdc-2012/ |
| Hades (2020) | 21,020 voice lines, 305,433 words | - | [V] https://www.nintendolife.com/news/2020/12/supergiant_shares_hades_voiceover_stats_charon_hardly_gets_a_word_in |
| Watch Dogs: Legion | not published | 50-100 actors for London's crowd, with pitch modulation to stretch them | [V] https://comicbook.com/gaming/news/watch-dogs-legion-npcs-voice-talent , https://blog.bestbuy.ca/video-games/interview-with-watch-dogs-legion-developer-lathieeshe-thillainathan |

What this means for Solvera [I]: a mobile game with a small team cannot match these counts and
should not try. The lesson is in *how* lines are chosen: GTA IV got its streets alive with about
200 lines per pedestrian voice, and Left 4 Dead felt reactive with about 10,000 lines because a
rule system made each line land at the right moment.

### 2.2 Rule-based line selection (Valve)

- Elan Ruskin, GDC 2012, "AI-driven Dynamic Dialog through Fuzzy Pattern Matching": hundreds of
  facts about the world are matched against a database of thousands of lines; characters remember
  history; rules cascade from special cases to general ones; writers add special cases without
  programmers changing code. [V] https://www.gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through ,
  slides https://cdn.akamai.steamstatic.com/apps/valve/2012/GDC2012_Ruskin_Elan_DynamicDialog.pdf ,
  video https://www.youtube.com/watch?v=tAbBID3N64A
- Valve's Response System, the shipped form of it: a *concept* names what kind of line is wanted;
  each rule has criteria; a failed *required* criterion rules it out; the highest-scoring rule
  wins; responses have `weight`, `respeakdelay` (cooldown), `speakonce`, and groups have `norepeat`;
  speaking can set *contexts* (facts) that later rules test. [V]
  https://developer.valvesoftware.com/wiki/Response_System ,
  https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Response_System
  (search excerpts; the two pages disagree on whether every criterion must match. [U])
- Ties between equally specific rules are picked at random in a third-party port. [U]
  https://github.com/lukecarr/mimir

### 2.3 Rockstar's ambient speech

- GTA V's engine plays ambient lines by **context name** plus speech parameters, e.g.
  `PLAY_PED_AMBIENT_SPEECH_NATIVE(ped, speechName, speechParam)`, with a check
  `DOES_CONTEXT_EXIST_FOR_THIS_PED`; a shouted variant exists (`SPEECH_PARAMS_SHOUTED`). [V]
  https://www.lcpdfr.com/resources/nativedb/index/audio/page/2/?d=39 ,
  https://forum.cfx.re/t/3-in-1-problems-deal-using-audio-playpedambientspeechnative-issues-store-peds/5294143
- RDR2 modders list context names such as `PANIC_HELP`, `GENERIC_FRIGHTENED_HIGH`,
  `INTIMIDATED_GEN`, shared across NPC types. [V] https://rdr2mods.com/forums/topic/467-making-npcs-speak-solved
  The commonly quoted GTA names `GENERIC_HI`, `GENERIC_INSULT`, `BUMP` were not confirmed. [U]
- A Game Developer analysis (its author calls it an educated inference, not official) says GTA V
  ties dialogue to pedestrian archetypes and avoided location-specific pedestrian lines so a
  limited set of voices covers the whole map. [U]
  https://gamedeveloper.com/design/breaking-down-gta-v-s-pedestrian-dialogue-system-an-analysis-with-speculative-examples
- GTA IV's team said earlier games had peds chatting to themselves at random, and they made it
  more realistic; each studio session had a Rockstar director, and casting ran while the script was
  still being written. [V] https://www.gamesradar.com/grand-theft-auto-iv-audio-qa
- GTA V's writer-producer Lazlow Jones hired real gang members for ambient characters, and some
  flagged lines they would not say. [V] https://mcvuk.com/development-news/gta-v-voiced-by-real-criminals/

### 2.4 Player-chosen lines (RDR2)

- Aiming the interact button at any character gives **Greet** or **Antagonize**; after antagonizing,
  **Defuse** or push further; with a weapon, Threaten, Rob and others. Options depend on distance,
  line of sight, weapon state and what the NPC is doing. [V]
  https://www.gamespot.com/articles/red-dead-redemption-2-lets-you-talk-your-way-out-o/1100-6461058/ ,
  https://segmentnext.com/2018/08/30/red-dead-redemption-2-interaction-system/
- It grew out of Bully's social interactions. [V]
  https://www.gamesradar.com/how-red-dead-redemption-2-built-on-bullys-social-interactions-to-deliver-the-most-fun-you-can-have-in-video-games
- NPC scripts in RDR2 reportedly ran to 80 pages each. [U]
  https://wccftech.com/rockstar-worked-100-hours-weeks-rdr2/

### 2.5 Interrupting and resuming conversations

- Dragon Age: The Veilguard added "resumable banter", taken from State of Decay; in Inquisition a
  combat interruption lost the conversation for good. [V]
  https://www.gamesradar.com/games/dragon-age/dragon-age-the-veilguard-director-says-the-first-thing-he-asked-for-was-a-state-of-decay-inspired-qol-feature-that-fixes-a-long-running-party-chat-issue
- Firewatch (GDC 2017, "Do You Copy?") began as an interrupt-heavy bark system and shipped long,
  restarting conversations the player can interrupt at any time. [V]
  https://gdcvault.com/play/1024000/Do-You-Copy-Dialog-System
- GTA's habit of pausing a drive-and-talk when the player leaves the car and picking it up later
  is widely remembered but no source was found. [U]

### 2.6 Cinematic dialogue at scale (CD Projekt)

- The Witcher 3 had 1,463 systemic dialogue scenes and only about 2.5 hours of hand-made
  cutscenes; a generator made the first pass of each scene (cameras, gestures) from actor data and
  the voice files, and designers then refined it by hand (CDPR corrected reports that "math" did it
  all). A core team of 14 built the system. [V]
  https://pcgamer.com/most-of-the-witcher-3s-dialogue-scenes-was-animated-by-an-algorithm ,
  https://www.gdcvault.com/play/1022988/The-Witcher-3-Wild-Hunt
- Cyberpunk 2077 lip-synced 10 languages procedurally from audio plus tagged transcripts (JALI),
  with no facial motion capture, and animators could key-frame over the result. [V]
  https://www.engadget.com/cyberpunk-2077-dialogue-language-lip-sync-artificial-intelligence-dubbing-154523977.html

### 2.7 Writing tools and repetition

- Ubisoft's Ghostwriter (2023, La Forge) drafts variations of barks only (not cinematics or lore)
  from a writer's character and situation; the writer picks and edits. Many writers reacted badly.
  [V] https://news.ubisoft.com/en-us/article/7Cm07zbBGy4Xml6WgYi25d/the-convergence-of-ai-and-creativity-introducing-ghostwriter%E2%80%8B ,
  https://gamedeveloper.com/production/ubisoft-s-aims-to-support-its-scriptwriters-with-ai-ghostwriter-tool
- Skyrim's "arrow in the knee" guard line became a meme because guards shared it and repeated it;
  Bethesda's audio director described guard dialogue as procedural and tied to player behaviour.
  [V] https://en.wikipedia.org/wiki/Arrow_in_the_knee ,
  https://medium.com/spirit-ai/arrow-to-the-knee-dynamic-dialog-variation-in-immersive-games-634b54e5609e
- Hades' exact priority rules were not found from Supergiant. [U]

### 2.8 AI voices, unions and stores

- SAG-AFTRA's 2025 Interactive Media Agreement (ratified July 2025, 95.04% yes) requires
  separate, written, specific consent before a digital replica is made or used, a usage and pay
  report to the performer, and lets performers suspend consent during a strike. [V]
  https://technologylaw.fkks.com/post/102mewu/inside-the-new-sag-aftra-interactive-media-agreement-new-standards-for-ai-and-di ,
  https://www.pcgamer.com/gaming-industry/the-videogame-voice-actors-strike-officially-ends-as-performers-ratify-agreement-between-sag-aftra-and-publishers
- SAG-AFTRA's January 2024 deal with Replica Studios licensed AI voices with consent and minimum
  rates; many actors objected. NAVA publishes an AI rider. [V]
  https://www.nbcnews.com/tech/video-games/sag-aftra-replica-studios-voice-actors-video-games-rcna133162 ,
  https://www.axios.com/2024/01/09/actor-union-deal-ai-voice
- Cyberpunk 2077: Phantom Liberty recreated a late Polish actor's voice with Respeecher, a new
  actor performing and the tool converting, with the family's permission; whether the family was
  paid is unclear. [V] https://pcgamer.com/cyberpunk-2077-phantom-liberty-used-ai-to-reproduce-late-polish-voice-actors-performance-as-viktor-vektor-with-the-familys-blessing
- The Finals (2023) used text-to-speech for contestant barks and commentators; actors and players
  criticised it, and Embark said its TTS is based on real, paid voices. [V]
  https://www.gamespot.com/articles/the-finals-dev-defends-ai-voices-says-its-not-trying-to-replace-humans/1100-6518802/ ,
  https://www.axios.com/2023/10/31/the-finals-embark-ai-voice
- Steam (Jan 2024) requires developers to disclose pre-generated AI content and the guardrails on
  live-generated content, and shows it on the store page. [V]
  https://gameworldobserver.com/2024/01/10/steam-ai-games-new-rules-pre-generated-live-generated
- Equity (UK) guidance and Google Play's AI rules were not found in this research. [U]

### 2.9 Subtitles

- Xbox Accessibility Guideline 104: name the speaker when a new one starts; captions also cover
  important sounds. [V] https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/104
- Common practice: at most 2 lines, about 38 characters per line (BBC's figure, cited in Ian
  Hamilton's 2019 GDC talk), a semi-opaque background box, player choice of size; one source
  suggests at least 46 px at 1080p. [V] https://80.lv/articles/10-golden-rules-on-subtitles-for-games ,
  https://gameaccessibilityguidelines.com/if-any-subtitles-captions-are-used-present-them-in-a-clear-easy-to-read-way/

### 2.10 What Godot gives us

- Translations from CSV or gettext PO; PO is friendlier to git and is the only one with plurals;
  pseudolocalization keeps placeholders working; the language changes at run time. [V]
  https://docs.godotengine.org/en/4.5/tutorials/i18n/localization_using_gettext.html
- **Trap**: Godot imports every `.csv` under `res://` as a translation table and reads each
  column header as a locale. Dialogue tables must not be `.csv` files in the project. [V]
  https://uhiyama-lab.com/en/notes/godot/translation-server-i18n/
- Localization remaps swap any resource per language, voices included. [V]
  https://docs.godotengine.org/en/4.7/tutorials/i18n/internationalizing_games.html
- Audio: WAV for short repeated effects; Ogg Vorbis for speech and music; MP3 is larger at equal
  quality but cheaper on the CPU. [V]
  https://docs.godotengine.org/de/4.5/tutorials/assets_pipeline/importing_audio_samples.html
- Built-in text-to-speech (`DisplayServer.tts_speak`, off by default under Audio > General) works
  on Android but with noticeable lag; one report of a crash on phones without a TTS engine. [V]
  https://docs.godotengine.org/de/4.5/tutorials/audio/text_to_speech.html ,
  https://godotforums.org/d/42556-displayservertts-get-voices-crashes-on-android-without-tts
- Google Play Asset Delivery: on-demand and fast-follow packs up to 512 MB each, install-time
  packs 1 GB in total, 2 GB for all packs. [V] https://developer.android.com/guide/playcore/asset-delivery
- Rhubarb Lip Sync turns audio (plus optional text) into 6-9 cartoon mouth shapes; its recogniser
  is English-only, and its licence must be checked at the source before use. [V/U]
  https://github.com/meshonline/rhubarb-lip-sync

## 3. What Solvera has today (read from the code)

- `missions/mission.gd`: `say([[speaker, text], ...], hold)` plays lines one after another and
  `line(speaker, text)` shows one without waiting. Speaker names and text are English literals in
  the mission scripts (m01-m03).
- `hud.gd`: one dialogue box at the bottom centre; each line holds `1.6 + 0.045 x characters`
  seconds (about 5 s for 76 characters), and a tap skips.
- `phone.gd`: Messages threads (Teo, Nia, Celeste) are hard-coded strings, shown by mission
  progress.
- `senses.gd`: events (`gunshot`, `explosion`, `aim`, `car_threat`, `crash`, `fight`, `scream`,
  `car_on_sidewalk`, `body`, `horn`, `siren`, `car_close`, `wanted`, `sprint_past`, `rain`) reach
  every person in range; `choose()` turns category (general, office, worker, tourist, gang,
  elderly, athlete, shopkeeper, medic, cop) and personality (calm, brave, timid, curious) into a
  reaction (`shout`, `call`, `cheer`, `film`, `flee`...). These are the natural bark triggers.
- `atmosphere.gd`: `hour` and `weather` (clear, cloudy, rain, storm). `mission_manager.gd` saves
  done missions, cash, settings and the bag to `user://solvera_save.json`.
- No audio files, no `tr()` calls, no subtitle settings yet.

## 4. Architecture

### 4.1 The line table

Writers work in a spreadsheet; a tool (`tools/dialogue_build.py`, later) exports it to
`game/data/dialogue/*.json` (one file per bank: `ambient`, `jules`, `m01`... ) and the English
`.po`. Keeping JSON matches `missions_act1.json` and `world_map.json`, and avoids the `.csv` trap. [I]

| Field | Meaning | Example |
|---|---|---|
| `id` | Stable key; also the translation key and the audio file name | `amb.tourist.gunshot.03` |
| `concept` | What kind of moment (Valve's concept) | `gunshot`, `bumped`, `greet`, `m02.door` |
| `who` | Speaker: a cast id or a voice type | `nia`, `ped.tourist.f` |
| `if` | Criteria on facts (equal, range, not, any-of) | `{"near": true, "hour": "night", "wanted": ">=2"}` |
| `text` | English line (source text) | "Was that a gun? Was that a GUN?" |
| `weight` | Relative chance among equally specific matches | `1.0` |
| `priority` | `story` 4, `player` 3, `reaction` 2, `chatter` 1 | `2` |
| `cooldown` | Seconds before this line may play again (plus group and speaker cooldowns) | `600` |
| `once` | Never again in this save | `false` |
| `set` | Facts written after it plays (Valve's contexts) | `{"nia.mentioned_dex": true}` |
| `then` | A reply concept for another speaker | `{"concept": "reply_insult", "to": "listener"}` |
| `lang` | Profanity level 0 clean, 1 mild, 2 strong | `1` |
| `clean` | ID of the authored clean alternate, when `lang` is 2 | `amb.gang.bumped.04c` |
| `note` | Context for actors and translators; max length if tight | "Shouted across the street" |
| `vo` | Later: audio status (`none`, `temp`, `final`) and take | `none` |

### 4.2 Facts and memory

The query is one flat dictionary built when a concept fires [I]:
- **World**: `hour` bucket (morning, day, evening, night), `weather`, `district`, player `wanted`
  level, `in_vehicle`, current mission and its step, story flags (`done.m03`), faction reputation.
- **Speaker**: category, personality, voice type, faction, mood, `knows_jules`, times greeted,
  last line time.
- **Event**: concept, distance, `source_is_player`, vehicle class, damage, who else is near.
- **Memory**: per speaker (short-term, dies with the NPC); per player (lines heard and when, for
  repeat control); per save (story `set` facts and `once` lines, saved beside done missions).

### 4.3 The selector

1. Rules are grouped by concept at load and sorted by number of criteria, most first.
2. Walk the list: skip rules on cooldown, already `once`-spent or heard by the player within the
   repeat window; the first fully matching rule sets the score tier.
3. Gather every match in that tier, pick one by `weight`. If all are spent, drop to the next tier
   (the general fallback). If nothing matches, stay silent: silence beats a wrong line.
4. Hand it to the speech manager; when it plays, apply `set`, stamp memory, fire `then`, and log
   a `speech` event in `game_log.gd` (line id, speaker, concept) for play-test analysis.

Cost [I]: a concept has tens to a few hundred rules; a linear scan a few times a second is far
below a millisecond, so no indexing is needed on phones. Load banks by district or act to keep
memory small.

### 4.4 The speech manager

- Channels: `story` (missions, cutscenes, calls), `player` (Jules), `ambient` (peds, cops,
  shopkeepers), `radio`. At most one story line, one Jules line and two ambient barks at once.
- A higher priority line interrupts a lower one; an ambient bark never starts while a story line
  is showing; ambient barks keep a global gap (start at 4 s) and only play within about 25 m of the
  player and on screen. Numbers are first guesses for play-tests to tune. [I]
- **Conversations** (a list of line IDs with optional branches) remember the next line. When
  interrupted (combat, the player leaving the car, a call), they pause; on resume they play a
  bridging line ("Anyway, where was I...") and continue; if the gap passes a limit or the mission
  moves on, they end with a closing line. [I, after §2.5]

### 4.5 Subtitles and speech bubbles

- Story box: the existing HUD box, with speaker name in the character's colour, at most 2 lines
  of about 38 characters (writers' limit checked by the build tool).
- Ambient barks: a small bubble over the speaker's head, which suits the top-down camera and keeps
  the story box clear; off-screen speakers get an arrow at the screen edge. [I]
- Settings (a Dialogue group on the Game tab): subtitles on or off for story and for barks
  separately, size S/M/L/XL, background opacity, speaker names, reading speed, language level
  (full, mild, clean), and later voice volume and voice language.

### 4.6 Text first, voice later

Audio attaches by ID: `res://vo/<lang>/<bank>/<id>.ogg`, found through a manifest, so missing VO
falls back to text silently. Line length drives the hold time until audio exists; then the audio
length does. [I]

## 5. Free-roam ambient speech

Situations come from `senses.gd` kinds plus a few new concepts (in bold).

| Situation | Typical speakers and reaction | Notes |
|---|---|---|
| `gunshot`, `explosion` | everyone: scream, "Get down!"; gang (brave): taunt; cop: "Shots fired!" | Non-verbal screams carry most of it |
| `aim` at someone | civilians: plead; gang: dare | Hands-up animation already exists |
| `car_threat`, `car_close`, `car_on_sidewalk` | "Whoa, whoa!", "Learn to drive!" | Speaker must be the one dodging |
| `crash` (seen) | tourists film and comment; elderly tut; workers "You okay?" | `film` and `call` reactions exist |
| `fight`, `body` | "Somebody call someone!", medics "Give him room" | |
| `horn`, `siren` | annoyed or nervous one-liners | low priority |
| `wanted` (player seen) | "Isn't that the one from the news?" at 2+ stars | ties to radio news |
| `rain` start, storm | "Here we go again", storm-scar remarks in the Floodline Wards | Bellerive's Great Storm memory |
| **`bumped`** | first bump: "Hey, careful"; second within a minute: angrier; third: shove | memory per NPC |
| **`greeted`**, **`antagonized`** | see §6 | |
| **`carjacked`** | victim: "That's my car!", runs, calls police | |
| **`idle_chatter`** | phone talk, two-person conversations (A/B pairs) | GTA IV-style overheard talk |
| **`news_reaction`** | after a mission, peds talk about it ("Aurum vans shot up the main road") | story flags in the query |
| **`shop`** | shopkeeper greet, sale, theft, robbery (robbery plan in TODO) | interiors phase 0 has staff |

Overheard conversations carry lore at low cost [I]: the Drowned Streetcar, the Solvera Line
buying up blocks, Aurum's "charity", Mama Odette's Krewe. Each is 4-8 lines between two voice
types, played once per save unless marked repeatable, and only near the right district.

First ambient budget for Act 1 [I]: 10 categories x 2 voice variants x about 40 concepts x 3
variants is about 2,400 short lines, plus about 40 overheard conversations. GTA IV's average of
about 200 lines per pedestrian voice is the yardstick (§2.1).

## 6. Player lines and player-chosen interactions

- **Jules's barks**: carjacking, crashing, losing the police, being hit, picking up cash, rain,
  getting in a taxi, idle comments when standing still. Jules has a stake (Teo) and sarcasm only as
  flavour, per the Chinatown Wars lessons in `TODO.md`.
- **Greet / Antagonize** [after §2.4]: standing near a person shows two buttons in place of the
  context button's usual label (one tap each, matching TODO's one-tap rule): GREET and PROVOKE.
  After a provoke the NPC answers by type: shopkeepers argue, gang members square up, elderly
  people scold, cops warn then cite. A second button, CALM DOWN, appears for a few seconds to
  defuse. Later options: ASK (rumours and directions, using overheard lore) and, with a weapon
  out, THREATEN.
- **Memory and reputation**: NPCs remember Jules for the rest of their life on the street;
  faction members in their own district remember across saves through reputation (High Water,
  Marrow Krewe, Aurum). Greeting people in the Wards slowly lifts High Water standing. [I]
- **Choices in missions** (6 and 13 in `ACT1_MISSIONS.md`): a choice panel with 2-3 short options
  and no timer (a timer punishes slow readers and touch players). [I]

## 7. Mission dialogue and in-engine cutscenes

Kinds of mission dialogue [I]:
- **Scene**: player held, camera framed (existing `say(lines, true)`).
- **Drive-and-talk / walk-and-talk**: player free, interruptible, resumable (§4.4).
- **Call**: through the phone (§8).
- **Mission barks**: directions and alerts ("Left at the church!", "Black vans behind us!"),
  picked by rules with mission facts, so Marcel reacts to the car taking damage or the wanted
  level rising.
- **Retry lines**: on a retry, skip the long intro and play a short variant ("Again. Faster this
  time.").

Changes to the mission code when phase 2 starts: `say()` takes line IDs (`say_ids(["m02.nia.door.01",
...])`); `line()` becomes `bark(concept)` for mission barks; the HUD box reads the speaker name and
colour from the cast table, not the script.

Act 1 fit:

| # | Mission | Dialogue needs |
|---|---|---|
| 1 | Homecoming | Jules's opening scene; thief taunts during the chase; crew trash talk in the fight |
| 2 | Empty Rooms | Nia door scene (anger at Jules leaving); clue lines; clinic scene |
| 3 | Lantern Lights | Celeste scene; Reyes at the precinct; Marcel drive-and-talk interrupted by the ambush; Marcel barks while losing the police |
| 4 | Wharf Rats | guard chatter and alert barks by approach (stealth, loud, vehicle) |
| 5 | Krewe Business | Mama Odette scene cut by the raid; airboat chase barks |
| 6 | Gilded Invitation | Simone's message and Hale's office scene; the choice; Nia's reaction either way |
| 7 | Street Business | customers at the food stand (ambient rules with a stand fact); thugs' threats |
| 8 | Hoops | Pops's terms; streetball trash talk and Dex's team (plant Dex fairly) |
| 9 | Floodwater | storm barks; Teo's recorded message (first voiced line if VO starts early) |
| 10 | Magnolia | party guests' overheard talk (clues), valet small talk, guards |
| 11 | Crescent Bridge | police radio and roadblock barks; Reyes's bridge scene |
| 12 | Cargo | Nia's crew barks; injured Teo during the escort |
| 13 | Two Crowns | three finales: the choice scene plus a closing scene for each branch |

**In-engine cutscenes**: a small shot generator in the spirit of The Witcher 3 (§2.6): from the
speakers' positions it picks a closer, lower camera, a two-shot, and a cut on each speaker change;
gestures from the existing `Rig` set (talk, point, shrug); a hand-tuned override per scene where it
matters. Every scene skippable; skipped scenes leave the key lines in the phone's mission log. [I]

## 8. Phone, messages and radio

- **Calls**: incoming call card (answer, decline); a declined story call comes back as a message.
  Calls play as subtitles while the player keeps driving, on the `story` channel, and pause for a
  scene. Contacts per `ACT1_MISSIONS.md` (Nia, Celeste, Pops, Reyes after mission 11).
- **Messages**: move the hard-coded threads in `phone.gd` into the line table (bank `phone`), so
  they translate and can react to facts (a message from Nia after Jules provokes High Water).
- **Radio** (`MVP_DESIGN.md`: three stations with DJ chatter): DJ links, ads for fictional brands
  and a news bulletin are line rules too, so news can mention the player's last mission or wanted
  spree, the weather and the Solvera Line. Whether GTA's news reacts to missions was not checked. [U]

## 9. Writing and style guide

General rules [I]:
- Barks: 2-8 words. Story lines: one subtitle (at most 2 lines of about 38 characters); longer
  thoughts become two lines.
- People talk past each other, interrupt, use contractions and leave things unsaid. No one
  explains what both speakers already know.
- Every recurring character has a want, a fear and a line they won't cross (TODO's Chinatown Wars
  list); every scene changes something between the speakers.
- Write 3-5 variants of anything that can repeat; vary the structure, not just the words.
- Humour from character and satire of money and power (WORLD_BIBLE tone), never from punching
  down. No real brands, people, religious figures or institutions; no slurs at any setting.
- A crew's speech is never a stand-in for an ethnic group (WORLD_BIBLE rule).

Voice sheets (first drafts, to grow into one page per character):

| Character | Voice |
|---|---|
| Jules Moreau | Dry, quick, watchful; jokes to cover guilt about leaving; drops the jokes about Teo |
| Nia Batiste | Blunt, impatient, protective of the Wards; short sentences; never says "please" first |
| Celeste Durand | Warm, musical, knows more than she says; answers questions with questions |
| Pops | Slow, transactional, sports metaphors; every favour has a price |
| Mama Odette | Formal, old-fashioned, unhurried; calls the city "out there" |
| Victor Hale | Charming, generous phrasing, never a direct threat; talks about "the community" |
| Simone Kessler | Polite to the point of chill; says each threat once |
| Captain Dana Reyes | Tired, procedural, honest; police shorthand |
| Dex | Friendly, eager, a little too helpful (plant the betrayal fairly) |
| Marcel | Theatrical bandleader; panics in style |

Regional flavour for Bellerive [I, proposals for Sachin]: storm-time references ("before the
water", "storm year"), local place shorthand ("the Wards", "the Quarter", "the Wharf"), street food
and music, river and streetcar talk, Aurum men called "gold collars". Keep invented slang light and
consistent; a glossary file lists every coined word and what it means, for writers and translators.

**Language setting**: lines carry a level (0 clean, 1 mild, 2 strong). The setting full / mild /
clean picks the highest level allowed; strong lines must have an authored clean alternate, never
an automatic bleep. Default to mild until the store rating is decided. [I]

## 10. Localization

- English is the source. Every line ID becomes a gettext message; UI strings move to `tr()`.
- PO files per language under `game/i18n/` (git-friendly, plurals); the build tool writes the POT
  with each line's `note`, speaker and length limit as translator comments.
- Pseudolocalization in a test run catches clipped boxes and hard-coded strings (§2.10).
- Fonts: the dialogue font needs fallbacks for any non-Latin script chosen later.
- Voice languages: subtitles first for every language; dubbing only for the biggest markets once
  sales data exists. Localized audio uses Godot remaps or the `res://vo/<lang>/` path.
- Which languages first is open: decide from target-market data (not researched here). [U]

## 11. Voiceover, late stages

### 11.1 When

After Act 1's script is locked and play-tested in text (phases 0-6), so actors never record lines
that change. Non-verbal sounds come earlier because they never change.

### 11.2 Casting and recording [I, practice reported by Rockstar in §2.3]

- Cast the 10-12 Act 1 speaking roles from audition reads of real scene lines; cast ambient voices
  as types (for example 10 categories x 2-3 voices), each actor covering several types with
  direction, not pitch-shifting alone (Watch Dogs: Legion used modulation to stretch a 50-100
  voice cast, §2.1).
- Session pack per actor: their lines in order of scene, with context notes, the previous line,
  intensity (whisper, normal, shout) and max length; a director on every session; record 2-3 takes
  of key lines and the efforts set (hits, falls, running, panting) for each voice.
- Pick-ups session after the edit for changed and missing lines.
- Contracts state the use, the platforms, and that no synthetic replica is made of the voice.

### 11.3 Files, size and streaming on Android

- Format: Ogg Vorbis, mono, 22.05-24 kHz for barks and 44.1 kHz for main-cast scenes; WAV only for
  short, very frequent efforts (§2.10). Loudness-normalise every line in the build tool.
- Size estimate [I, arithmetic]: mono Vorbis at about 48 kbps is 6 KB per second; a 2.5 s average
  line is about 15 KB; 10,000 lines are about 150 MB per language.
- Delivery: English VO in an install-time or fast-follow asset pack; each extra voice language as
  an on-demand pack (512 MB cap per pack, §2.10).
- Playback: stream from disk, never preload a bank; a pool of 3-4 voice players
  (`AudioStreamPlayer3D` for ambient, 2D for story and radio); duck music and radio under story
  lines.

### 11.4 Lip sync

The camera looks down from far away, so faces are small most of the time [I]:
- Free roam: a jaw flap driven by the line's loudness (cheap, language-free).
- Cutscene close-ups: mouth shapes from a tool such as Rhubarb Lip Sync baked at build time
  (English only; other languages fall back to the flap), after checking its licence.
- Full procedural facial animation (JALI-style, §2.6) is out of scope.

### 11.5 Budget tiers

Rates for actors and studios were not researched; get at least three quotes before choosing. [U]

| Tier | What ships | Cost | Risk |
|---|---|---|---|
| A | Text and speech bubbles, non-verbal efforts only | lowest | players expect some voice in a crime game |
| B | A plus voiced story scenes for the main cast (Act 1 roles) | moderate | needs script lock |
| C | B plus voiced ambient barks from a small cast of type voices | higher | repetition shows sooner with audio; needs §12 metrics |
| D | C plus dubs in 1-3 languages | highest | multiplies every pick-up |
| AI option | licensed synthetic voices built from consenting, paid performers, for ambient barks only | low per line | backlash (The Finals), union terms, store disclosure; never for the main cast, never a clone without consent (§2.8) |

Recommendation [I]: tier A through Act 1's development, prototype timing with Godot's built-in TTS
in debug builds only, then tier B at the late stage, tier C if play-tests show silent streets hurt,
and decide on any AI voices with Sachin and a lawyer, case by case.

## 12. Testing

Automated, in `game/tests/run.sh` [I]:
- **Lint**: every ID unique; every `who` and `then` valid; text within the length limit; every
  strong line has a clean alternate; every criterion uses a known fact; no rule unreachable
  (criteria that can never be true together).
- **Coverage**: for each category x each senses kind x near/far, at least 2 eligible lines; for
  each mission step that calls a concept, at least one line.
- **Repetition**: a headless soak that fires a scripted mix of events for 2 simulated hours and
  reports distinct lines per hour, the shortest gap between two plays of the same line (target
  above 10 minutes for barks), and the share of events that got silence.
- **Missions**: each mission's dialogue runs to the end with skips, interruptions and a retry.
- **Localization**: a pseudolocalized run with screenshots of every dialogue surface, read through
  contact sheets.

By hand: play-test notes on lines that feel wrong, read from the `speech` events in the game log.

## 13. Roadmap

Effort in sessions, rough, the way `TODO.md` sizes work. [I]

| Phase | What | Effort |
|---|---|---|
| 0 | Line table and build tool, fact store, selector, speech manager, story box with names and colours, bark bubbles, Dialogue settings; m01-m03 moved to line IDs with no change in text | 3-4 |
| 1 | Ambient barks wired to `senses.gd` for all categories; bump and carjack concepts; overheard two-person conversations; repetition metrics and lint in tests | 3 |
| 2 | Conversations with interrupt and resume; mission barks; phone calls and messages from the table; retry variants | 2-3 |
| 3 | Jules's barks; GREET / PROVOKE / CALM DOWN; NPC memory and faction reputation hooks | 2-3 |
| 4 | Writing pass for all of Act 1: voice sheets, glossary, missions 4-13 scenes, ambient banks, language levels; Sachin reviews | 4-6 |
| 5 | Shot generator for in-engine scenes; choice panel for missions 6 and 13 | 2-3 |
| 6 | Localization pipeline (POT, PO, `tr()` for UI, pseudolocalization) and a first language | 2, plus translator time |
| 7 | Non-verbal efforts (screams, gasps, grunts) for every voice type; radio DJ and news rules | 2 |
| 8 | VO pilot: TTS timing pass in debug, casting, main cast for missions 1-3, Ogg pipeline, asset pack, jaw flap | 3-4, plus studio time |
| 9 | Full Act 1 VO (tier B or C), cutscene mouth shapes, dubs if chosen | external, months |

## 14. Open questions for Sachin

- Rating target, which sets the default language level.
- Which languages after English, and which, if any, get voice.
- Budget tier for VO, and the stance on AI voices (the plan's default: none for the main cast).
- Whether Jules is fixed or customisable: a custom Jules needs gender-neutral lines or two voices.
