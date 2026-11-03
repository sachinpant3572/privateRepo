# TODO

## Tuesday, Oct 27, 2026, 1:00 PM IST: Civilization Tech game idea

Status: **not started**. Research is on hold until the weekly usage limit resets on Tuesday.

### The idea (as described)

A 2D game where the player gives advanced technologies to a species or society
at different points in its history, then watches what happens.

- **Human mode**: give tech to human societies at different periods.
- **Species mode**: give tech to other species, such as Neanderthals, reptiles,
  dinosaurs, and later the creatures considered the next smartest after humans.
  The player decides what the species does with the tech.
- **Consequences**: every action has consequences, from very rewarding to
  catastrophic. They could be shown as cards (but better than plain cards) or as
  full 2D animation.
- **Tech tree and crafting**: players unlock new technologies, and some can be
  combined into completely new tech. All of it follows real, current science.
- **Create or destroy**: tech can be used to build or destroy things, people and
  buildings.
- **Scenarios**: the game sets scenarios for using the tech. The results of each
  scenario add up to the ending.
- **Progression**: runs up to a starfaring civilization. There are several
  starfaring endings, depending on which technologies were used. A civilization
  can also destroy itself well before that, by misusing tech or failing to use it
  properly.
- **References**: Age of Empires + a basic SimCity + Stickman Wars + TABS +
  Detroit: Become Human (for choices and consequences), all in 2D.
- **AI in the engine (optional)**: use the Claude API to generate results or
  new tech combinations only if its cost is very low compared with expected
  revenue. Otherwise build it without AI in the game engine.
- **Content rule**: no religious figures, to avoid controversy or bans.
- **Launch scope**: humans from different periods first, then other species.

### Agenda for Tuesday

1. [ ] **Originality check**: search thoroughly across Steam, Epic, itch.io,
   console stores, iOS/Android, and web/Poki/CrazyGames for any existing game
   with this concept. Look for anything close: tech-gifting, uplift,
   alternate-history or "what if" civilization sims, and tech-combination crafting
   (for example Doodle God/Little Alchemy-style games).
2. [ ] **TABS check**: does TABS (Totally Accurate Battle Simulator) allow or
   cover this concept, through its mechanics, mods/workshop, or IP/EULA? How is
   our idea the same as TABS, and how is it different?
3. [ ] **Assessment**: rate how valid, impressive, expansive, feasible,
   addictive and replayable the idea is, and how ambitious it is, with critical
   feedback.
4. [ ] **Claude can do it all?**: can Claude handle research, the feasibility
   study, implementation, testing, fixing, QA, and many high-quality animated 2D
   models, with the user making decisions from the options Claude gives? Be
   honest about what needs outside tools, assets or people (for example art and
   animation pipelines, and store publishing).
5. [ ] **AI cost model**: Claude API cost per player/session against projected
   revenue, to decide between using AI and no AI.
6. [ ] **Next steps**: choose engine/tech stack, MVP scope (human mode, a few
   eras), and art style.

### Godot resources to review (added Nov 3, 2026)

If we build with Godot, check the official **Godot Asset Store** for assets and
plugins before making our own:
<https://store.godotengine.org/search/?query=%233d> (that link filters by the
`#3d` tag; look at the 2D tags as well, since launch scope is 2D).

- [ ] Browse it for art, animation, UI and tool plugins that fit the art style.
- [ ] Check each asset's license (MIT / CC0 / CC-BY) before using it in a
  commercial release.
- [ ] Note: paid assets were reported as "planned", not live. Confirm the
  current status on the site.

**What the store had on Nov 3, 2026 (in beta):** 378 results for `#3d` and 298
for `#2d`. Every asset is a free download, and some link to a donation page.
Filters: license (MIT, CC0, Apache 2.0, GPL v3) and **Uses AI / No AI**.
Each asset lists the Godot versions it supports. Some assets use custom or
proprietary licenses, so read each LICENSE.

Shortlist for buildings and environments:

| Asset | Publisher / license | Why it matters |
| --- | --- | --- |
| Medieval Village MegaKit | Quaternius / CC0 | 300+ grid-snapping modular walls, floors, roofs and stairs. The free "Standard" build is a subset; the full version is on quaternius.com |
| Modular Sci-Fi MegaKit | Quaternius / CC0 | The same modular approach for late-game or starfaring eras |
| Fantasy Props MegaKit, Stylized Nature MegaKit | Quaternius / CC0 | Props, trees, rocks and plants to fill scenes |
| Free Fantasy Medieval Houses and Props Pack | EmacE Art / custom license | Houses and inns with 3 LODs and colliders. Has no approved version yet |
| Kominka Modular Home Pack, Lowpoly Street Props | Rice Studio Lab, Polybuild / MIT | Modular Japanese homes and modern street furniture |
| Egyptian Temple, Chinese pavilion and garden wall | Shimon Ayalon (CC BY 4.0), VVaytoyek (CC0) | Historical-era set pieces |
| Starter Kit City Builder | Kenney / MIT | City-builder template: placement, GridMap/MeshLibrary, save/load |
| Modular Builder, CSG Blockout, MeshBuilder | various / CC0, MIT | Snap-together building and graybox tools inside the editor |
| Terrain3D, Sky3D, ProtonScatter, Road Generator | various / MIT | Terrain, day/night sky, procedural scattering, roads |
| RTS Camera 3D | Alfred Reinold Baudisch / MIT | Strategy-style camera |
| Universal Animation Library | Quaternius / CC0 | 120+ retargetable humanoid animations |
| Global Illumination, Decals, Tonemapping, HLOD demos | Godot Foundation / MIT | Official references for lighting and performance |
| dddpix PixelArt Renderer | 888wing / MIT | Renders 3D as pixel art, for the "3D rendered as 2D" route |

For the 2D launch, `#2d` has Aseprite importers, Lit (2D lighting),
SmartShape2D, Breakable 2D Sprites and a few medieval and RPG sprite packs.
