# Market & Feasibility Research — AGI choice game

*Date: 2026-10-24. Scope: Android + iOS launch, small/solo team in India. Figures marked **(est.)** are third-party estimates or my extrapolations, not company disclosures. Bracketed numbers [n] refer to the Sources list.*

---

## Executive summary

The concept sits where three proven mobile formats meet: **Plague Inc.** (a systems sim where you are the antagonist and the world map changes as you play), **Reigns** (binary card choices in short runs that end in collectible deaths), and **BitLife** (a text-light life sim with ads, a premium unlock and a paid "God Mode"). Each has shipped at scale: Plague Inc. has 160M+ downloads, Reigns has 2M+ copies sold and a reported $20M+ in revenue, and BitLife has 100M+ players. I found **no mobile title where the player is the AGI** deciding the fate of humans, rival AIs and itself. The closest new entrant is *Singularity Inc* (Steam, July 2026; PC only, turn-based, you play the AI against a resistance meter) [1]. The opening is real, but it can be copied: card games are cheap to clone.

| Dimension | Score | Justification |
|---|---|---|
| **Feasibility** | **7/10** | Card-and-stat engines are technically light: a 2D card UI and a stylised Earth driven by about 10 stats. Content is the real cost. Reigns shipped about 770 cards (official figure as reported by players) [4], so a solo developer with AI-assisted writing can realistically ship 250–350 cards and 14–16 endings in 6–9 months. The deductions are for balancing a hidden-stat system across many endings, which is hard and needs simulation tooling, and for review risk on Apple guideline 1.1.7 ("epidemics", "violent conflicts") [17]. |
| **Addictiveness** | **7/10** | The "one more run" loop is proven. Runs of 10–15 minutes beat the median mobile session of 5–6 minutes and land near the top-quartile 8–9 minutes [12]. Collecting endings is the hook Reigns and Plague use. Watching the planet change gives instant feedback. It is not a compulsion loop like match-3, and that is by design. |
| **Replayability** | **8/10** | Three tracks multiplied by hidden stats and follow-up chains produce many distinct paths. Twelve or more endings, rarity tiers, a daily seed and scenario packs (the Plague model) give long-tail replay. The risk is that players "solve" the stat math. The fix is randomised event decks and hidden modifiers in each run. |
| **Spending power** | **5/10** | This genre monetises lightly. Premium mobile tops out at about $1–5 (Plague $0.99, Reigns about $3, Suzerain $3.99–4.99 IAP) [5][6][24]. BitLife proves a hybrid model of ads, a roughly $8–10 premium unlock and a roughly $10 God Mode [9]. Players in India spend far less: ARPU is about $3 versus about $215 in the US (Lightbox, different methodology) [22], and rewarded eCPMs are about 4–10× lower [19][20]. Revenue will be mostly from Tier-1 players and mostly from IAP. |
| **Retention** | **6/10** | Narrative card games have high D1 and weak D30 once players have seen the endings. Industry benchmarks are low: median D7 is about 3.4–4% and median D30 about 0.7% [11][12]. A daily seed, scenario drops and an ending collection can push this into the top quartile (D1 above 30%, D30 around 2–4%), but not to midcore levels. |
| **Popularity/virality** | **7/10** | AI is the defining cultural topic of 2025–26. In 2025, 50% of US adults were more concerned than excited about AI, up from 37% in 2021 [25], and *AI 2027* drove mainstream "AGI scenario" discourse [26]. Endings like "I ended humanity in 9 turns" fit share cards and Shorts well. The precedents are viral: Paperclips reached about 450k players in 11 days (via Wired, secondary source) [7], and Plague Inc. hit #1 paid when the news matched its theme [3]. The deduction is for fatigue with AI as a topic and the risk of polarised reception. |

**Bottom line:** build it, but scope it as a **premium-feeling F2P hybrid**. Keep the core run free, sell a premium unlock and an "Architect Mode", use opt-in rewarded ads, and treat the daily seed and share card as launch features, not later additions. Soft-launch in India plus one Tier-1 test market, such as Canada, Australia or the Philippines, and move to a global launch only if D1 is at least 30% and D7 is at least 10%.

---

## 1. Comparable titles

| Title | Platform | Price model | Est. downloads / revenue | Key mechanic | Lesson for us |
|---|---|---|---|---|---|
| **Plague Inc.** (Ndemic, 2012) | iOS, Android, PC, console | iOS $0.99. Android free with ads plus $0.99 premium. Scenario IAPs $0.99 each or a $2.99 pack, cheats $9.99 [5] | 160M+ downloads as of May 2021 [2]; "170M+ players" on Ndemic's press page [2]. Revenue not disclosed | Play the antagonist. A world map visibly changes. Scenarios. Ending is win or lose | Map spectacle plus a dark premise is enough. Scenario packs and a news hook drove growth: #1 US paid app on 23 Jan 2020, top paid game in 80 markets by 3 Feb 2020 [3]. Educational framing (CDC recognition) protected it [16]. |
| **Rebel Inc.** (Ndemic, 2018) | iOS, Android, PC | Same model as Plague | Top 5 globally and #1 in 23 countries on mobile at launch [27]. Steam Escalation about 168k–548k copies (est., trackers disagree) [8] | Stabilise a fictional war-torn region; balance civilian and military stats | Real-conflict themes are fine if handled respectfully. Ndemic consulted the Afghan embassy and localised into Dari and Pashto [27]. |
| **Reigns** (Nerial/Devolver, 2016) | iOS, Android, PC, Switch | Premium, about $2.99 on iOS ($3.99 for GoT) [6] | 600k sales in about one month [6]; 2M copies by 2019 and $20M+ franchise revenue reported in 2024 [6] | Swipe left or right; 4 stats; death when any stat hits 0 or 100; about 770 cards [4] | Binary choices plus 4 meters is the most readable UX. Deaths are content. Note that Nerial has since closed, so premium-only income did not sustain the studio [6]. |
| **BitLife** (Candywriter/Stillfront, 2018) | iOS, Android | F2P with ads. Bitizenship $7.99–9.99, God Mode $9.99, bundle $15.99 [9] | 42M downloads and 1.2M DAU by 2020; about $26M revenue in 2019 at about 59% EBIT margin [10]. "100M+ players" claimed [10]. US Android about $73–96k per week in Q1 2024 (Sensor Tower, est.) [10] | Text life sim, random events, challenges, weekly live-ops events | Text-heavy UI can scale to the top charts. **God Mode** (control over the sim) is the best-selling archetype. Live-ops challenges drive retention. |
| **Suzerain** (Torpor, 2020; mobile 2022) | PC, console, mobile | Mobile at launch: free prologue plus $3.99–4.99 unlock. **Relaunched Dec 2024** as freemium with ads, story packs and 1-day to 1-month passes [24] | Not disclosed | Deep political narrative in a fictional country | A premium narrative game moved to a hybrid model with subscription passes on mobile, which is a direct signal for our model. |
| **Democracy 4** (Positech) | PC, console | Premium about $25–30 | About 145k Steam copies, about $2.6M gross (est.) [13] | Policy sliders, voter groups | A deep policy sim is a niche on PC. Mobile needs much lighter input. |
| **Choices / Episode** | iOS, Android | Gem-gated premium choices (about £1.99 per 20 diamonds) plus ads [14] | Choices about $175M lifetime iOS (est., undated) [14] | Paid story branches | Shows that choice-gating makes money, but it is the exact pay-for-outcome pattern we should avoid. |
| **Universal Paperclips** (Lantz, 2017) | Web free, iOS/Android paid | Free web; paid mobile [7] | About 450k players in 11 days on web (via Wired, secondary) [7] | You are a paperclip-maximiser AI; incremental | The "you are the AI" premise is inherently viral when the ending lands as an idea. A free web demo is a growth lever. |
| **Singularity Inc** (2026) | Steam | Premium | New; no data [1] | Turn-based; you are the AI; control 10 regions against a resistance meter | **Closest direct competitor** on PC. No mobile version, which is our window. |
| **Endgame: Singularity** | PC, open source | Free | Niche [15] | Hidden AI that avoids detection, compute economy | Proves the "stay hidden" stat as a fun constraint. |

**Gaps we can own:** (a) the **"you are the AGI" premise on mobile**; (b) **managing other AGIs** (merge, delete, ally, sandbox, compete), which no comp does; (c) **visible Earth transformation** through to a Dyson swarm; (d) **balanced, non-preachy outcomes**. Most AI fiction is doom-only, while our endings range from utopia to extinction.

---

## 2. Feasibility

**Content volume.** Reigns shipped about 770 cards with 4 stats [4]. BitLife grows through a writing team and weekly live-ops [10]. Recommended launch targets:

- **Cards:** 250–350 total, split roughly 40% human situations, 30% rival AGIs and 30% self-upgrades. About 30% should be follow-ups gated by flags.
- **Endings:** 14–16 at launch (the brief asks for 12+), plus 3–4 secret or rare endings. Each needs one illustrated or 3D Earth "end-state" scene and a share card.
- **Stats:** 4 visible stats (Human Trust, Compute, Stability, Planet Health) and 4–6 hidden ones (Suspicion, Rival-AGI Power, Alignment Drift, Inequality, Space Progress).
- **Earth visuals:** drive them from the stats with layered shaders (night lights, smog tint, forest mask, conflict markers, launch trails, swarm ring). Use 2.5D in Unity or Godot, and avoid per-ending bespoke 3D.
- **Tooling:** build a headless **Monte-Carlo run simulator** (10k bot runs per build) to check that each ending is reachable at its target rarity, from 1% to 25%. This is the single most important engineering investment.

**Team and timeline (est.):** 1 developer plus 1 contract artist, with AI-assisted card drafting and **human editing**. That means 6–9 months to soft launch and about 2 months to scale. Budget about 30% of the time for balancing.

**Store-policy risks**

- **Apple 1.1.7** rejects "harmful concepts which capitalize or seek to profit on recent or current events, such as violent conflicts, terrorist attacks, and epidemics." **Apple 1.1.2** says game "enemies" cannot solely target a "real government, corporation, or any other real entity". **Apple 1.1.1** exempts professional political satire [17].
- **Google Play "Sensitive Events":** content about tragedies is allowed with "educational, documentary, scientific or artistic value", but not apps that capitalise on or are insensitive towards them [18].
- **How Plague Inc. stays allowed:** it predates the current rules, uses an abstract or fictional framing, is officially presented as "designed to be realistic and informative, while not sensationalising" and has CDC recognition [3][16].
- **Rules for us:**
  - Use **fictional nations, leaders and AI labs**. Never name real politicians or real companies such as OpenAI or Google.
  - Use no real ongoing wars or real pandemic names.
  - Avoid gore imagery and keep casualties abstract (population counters, map tint).
  - Ship an in-app "about the science" page that links to AI-safety and AI-policy reading.
  - Never market the game against a live tragedy.
- **China lesson:** in Feb 2020 the Cyberspace Administration of China removed Plague Inc. for unspecified "illegal content", and Steam China removal followed on 2 March 2020 [16]. **Exclude mainland China** at launch, since games there also need a licence. Expect sensitivity in other markets too, so avoid real flags and borders.

**Likely age ratings:** Plague Inc. Evolved is ESRB **E10+** (Violent References) [21], while BitLife is **17+/Mature** because of sex and drug content [23]. Apple's new 2025 tiers (4+/9+/13+/16+/18+) took effect after the 31 Jan 2026 questionnaire deadline [28]. With text-only mass-casualty references and no sexual content, expect **Apple 13+**, **IARC Teen / PEGI 12** and ESRB E10+ to T. Aim for 13+, since 16+ hides the app from younger users' search [28].

---

## 3. Addictiveness and retention

**Why the comps retain**

- **Reigns:** each run is about 5–10 minutes, death is instant and funny, and there are objectives each "reign".
- **Plague:** scenario packs, difficulty tiers and per-disease medals.
- **BitLife:** daily and weekly challenges, themed live events (for example its 8th birthday and World Cup) and a collection of ribbons and achievements [10].

Common threads are short runs, **visible collection progress**, **fresh rule-sets** and **a reason to come back today**.

**Benchmarks (GameAnalytics, all genres)**

| Metric | Median | Top 25% | Top 10% |
|---|---|---|---|
| D1 | about 22% (2025 data) | 26.5–27.7% (2024) and just above 30% (2025) | about 40% |
| D7 | 3.4–4% | — | 11–12% |
| D30 / D28 | 0.68–0.79% | 1.6–1.8% | — |
| Session length | 5–6 min | 8–9 min | — |
| Daily playtime | 22 min | 22–24 min | — |

Sources: [11][12]. Board, card and puzzle games lead medium-term retention, and arcade games lead D1 [11]. In Appodeal's US Android data, simulation and hypercasual games show about **3% D30** and **$0.79 ARPU**, while hybrid "Life Simulator" titles reach **$11–15 ARPU** [19]. That supports the BitLife-style hybrid model.

---

## 4. Spending power and monetization

**Benchmarks**

- **ARPDAU (est.):** ads-only casual $0.01–0.05, hybrid-casual $0.15–0.50 (blog estimates) [19]. One developer reported about $0.15 per player per day in the US [29].
- **Geographic split:** ads make up 55–70% of revenue in India, Indonesia and Brazil, while IAP makes up 77–90% in the US, Japan and Korea [20].
- **Subscriptions** are the fastest-growing revenue stream (+105% YoY in Q1 2026, AppsFlyer via secondary source) [20], and 72% of developers run hybrid models (Xsolla survey) [20].
- **India:**
  - Market: $1.5B excluding real-money gaming, about 25% payer conversion, casual ARPPU about $3 (Lumikai 2025) [22].
  - Rewarded eCPM: about $0.70–3.96, versus $12–22 in the US (est.) [19][20].
  - Price floors: as low as **₹10** on both stores [30][31]. Without custom tiers, Apple's automatic pricing converts USD prices at the exchange rate [30].

**Premium vs F2P.** Premium has a credible ceiling: Reigns reached 600k sales at $2.99 in a month. But its studio has since closed, Suzerain moved its mobile version to freemium plus passes, and free-to-premium conversion is typically 2–5% [24][29]. In India, a paid app shuts out the volume that ads monetise. **Recommendation:** go free-to-start with a one-time premium unlock (the Plague, BitLife and Suzerain hybrid), not a subscription-first or gem-gated model.

### Recommended monetization plan

| SKU | What it gives | USD | INR (custom tier) |
|---|---|---|---|
| Free core | Full base campaign; **all endings reachable**; daily seed; 1 rewarded "Reroll card" per run | Free | Free |
| **Remove Ads + Core+** (one-time) | No interstitials; 2 extra rerolls per run; ending tracker hints | $3.99 | ₹199 |
| **Scenario packs** (one-time each) | New rule-sets such as "Solar Flare Year", "Open-Source Explosion", "Mars First" | $1.99 | ₹99 |
| Scenario bundle (all current packs) | Equivalent to Plague's $2.99 pack | $4.99 | ₹249 |
| **Architect Mode** (God Mode analogue) | See hidden stats, pin a card, custom seeds, sandbox the Earth | $6.99 | ₹349 |
| Complete bundle | All of the above | $12.99 | ₹599 |
| Optional **Overseer Pass** (after soft launch) | Monthly exclusive scenario plus archive of past daily seeds plus cosmetics | $2.99/mo or $19.99/yr | ₹129/mo or ₹799/yr |
| Cosmetics | AGI "core" skins, Earth palettes, share-card frames | $0.99–1.99 | ₹49–99 |

**Ads:** use opt-in rewarded ads for "reroll", "advisor whisper" (shows one hidden stat delta) and "undo last card", capped at 3 per run. Show at most one interstitial **between** runs, only from run 3 onwards, and never mid-run. Expect ads to be the majority of revenue in India and IAP the majority in Tier-1 markets [20].

**Ethical guardrail.**
- **No ending may be purchasable or gated behind payment or ads.** Packs add new endings, but those are reachable inside the pack for every owner without further spending.
- Runs that use Architect Mode, or more than X rerolls, are **tagged and excluded from the daily-seed leaderboard**.
- No loot boxes, so the odds-disclosure rule in Apple 3.1.1 never applies [17].
- No energy timers on runs.

---

## 5. Popularity and virality

- **Cultural tailwind:**
  - Pew (June 2025, n=5,023): 50% of US adults are more concerned than excited about AI, up from 37% in 2021 [25].
  - *AI 2027* (April 2025) made AGI timelines a mainstream debate, including a reported indirect reference by the US Vice-President [26].
  - Generative-AI search interest peaked in Aug 2025 around GPT-5 and then fell to 24% of that peak by December [32]. **Interest in AI comes in news-driven spikes**, so plan marketing beats around big AI news (model launches, policy events), as Plague did with outbreaks [3].
- **Share mechanics:**
  - Wordle grew from 90 to 300k players in 2 months and to 2M+ within a month after that. The spoiler-free emoji grid and the single shared daily puzzle drove it [33].
  - Build a **daily seed** (the same starting world for everyone) and an auto-generated **share card**: Earth thumbnail, ending name, rarity, turns, and an emoji timeline of the 3 tracks, e.g. `🧑‍🤝‍🧑🟥🟥🟩 🤖🟩🟥 ⚙️🟩🟩 → 🌌 Spacefaring in 11 turns (3% of players)`.
- **Shorts and TikTok fit:** a time-lapse of the Earth's lights, smog, war markers and Dyson swarm is a natural 15-second vertical clip. Add a one-tap "export run replay" (9:16, under 20 s) and dramatic ending names that work as hooks ("AI-run communism", "The Merge").
- **Streamer fit:** chat can vote left or right on cards (a Twitch extension later). Reigns-style dilemmas suit chat polls, and controversial endings drive clip culture.
- **ASO keywords (est., validate in an ASO tool):**
  - Primary: *AI simulator, AGI game, singularity, world simulator, choices game, decision game, apocalypse simulator, god game*.
  - Secondary: *plague-style strategy, civilization, dystopia, utopia, robot takeover, life simulator, text strategy*.
  - India: Hinglish screenshots plus Hindi localisation of the store listing.

---

## 6. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple 1.1.7 or Google Sensitive Events rejection | Medium | Fictional entities; abstract casualties; science page; pre-submission review notes that explain the speculative and educational framing [17][18] |
| Seen as AI-doom **or** pro-AI propaganda | Medium-High | Balanced ending set (as many good as bad); no real labs; endings explain *why* in systems terms; avoid sponsorship by AI firms |
| Topic fatigue or news-cycle decay | Medium | Gameplay must stand without hype; scenario packs tied to news; keep the core fun as a strategy game |
| Clones (low technical barrier; Singularity Inc on PC) [1] | High | Speed to market; the Earth visual as a signature; brand the ending names; daily seed community; trademark the title |
| Low India monetisation | High | Treat India as the volume and test market; target Tier-1 for revenue; low ₹ tiers |
| Solving the stat system, then churn | Medium | Hidden modifiers in each run; randomised decks; secret endings; pack cadence every 6–8 weeks |
| AI-written content feels generic | Medium | A human editor owns tone; AI only for drafts; playtest card "punch" |

---

## Design implications (must-haves)

- **Run length 10–15 minutes**, about 25–40 cards per run, with a **first ending reachable within 5 minutes** for the first-session payoff.
- **14–16 endings at launch** plus 3–4 secret ones. An **Ending Codex** shows silhouettes of locked endings and their global rarity percentage.
- **Swipe-binary input** (Reigns) with an optional third "defer" choice on a cooldown. No complex menus.
- **4 visible and 4–6 hidden stats**. Show a hidden stat's direction (up or down) but not its value, to keep the mystery and the Architect Mode value.
- **Earth visibly reacts to every card** within about 1 second.
- **Daily seed** with a global leaderboard (fewest turns to each ending), **share card** and **9:16 replay export** from day one.
- **Follow-up chains**: about 30% of cards are flag-gated, so choices feel remembered.
- **Rival-AGI track** as the differentiator: named rival AGIs with personalities that recur across runs.
- **Scenario packs** every 6–8 weeks; weekly challenge ("Reach Utopia without the Persuasion module").
- **Headless balance simulator** in CI; every ending must fall within its target rarity band.
- **Fictionalised world**: no real leaders, companies or ongoing conflicts. Abstract casualties. Aim for a 13+ rating.
- **Localisation**: English and Hindi at launch; Spanish, Portuguese (BR) and Indonesian next. These are high-ad-share markets [20].

---

## KPI targets for soft launch

| KPI | Go threshold | Stretch | Benchmark basis |
|---|---|---|---|
| D1 retention | ≥ 30% | 40% | GA top 25% just above 30%, top 10% about 40% [11][12] |
| D7 retention | ≥ 10% | 15% | GA top 10% 11–12%; median 3.4–4% [11][12] |
| D30 retention | ≥ 3% | 5% | GA top 25% 1.6–1.8%; Appodeal sim about 3% [11][19] |
| Avg session length | ≥ 9 min | 13 min | GA median 5–6, top 25% 8–9 min [12] |
| Daily playtime per DAU | ≥ 20 min | 30 min | GA median 22 min [12] |
| Runs per DAU | ≥ 1.8 | 2.5 | Internal target (est.) |
| Share-card rate (per completed run) | ≥ 4% | 8% | Internal target (est.); Wordle-style loop [33] |
| ARPDAU, Tier-1 test market | ≥ $0.08 | $0.15 | Hybrid-casual $0.15–0.50; reported US $0.15 [19][29] (est.) |
| ARPDAU, India | ≥ $0.01 | $0.03 | Rewarded eCPM about $0.70–3.96 [19][20] (est.) |
| Payer conversion (D30) | ≥ 2% | 4% | Free-to-premium 2–5% [29] |
| Distinct endings per D7-retained user | ≥ 4 | 6 | Internal target (est.) |

---

## Sources

1. Singularity Inc (Steam, released 3 Jul 2026) — https://store.steampowered.com/app/4808790 ; Singularity Simulator — https://store.steampowered.com/app/4584090/
2. Plague Inc. (Wikipedia: 160M downloads as of May 2021) — https://en.wikipedia.org/wiki/Plague_Inc. ; Ndemic press/media page — https://cdn.ndemiccreations.com/en/20-media
3. Plague Inc. chart surge, Jan–Feb 2020 — https://apptica.com/blog/minecraft-is-not-the-1-paid-app-anymore-reason-coronavirus/ ; https://omdia.tech.informa.com/om006283/plague-inc-the-mostdownloaded-premium-app-in-italy-and-usa-amidst-coronavirus-outbreak ; https://www.cbsnews.com/amp/news/plague-inc-top-apple-paid-iphone-apps-coronavirus-spread
4. Reigns card count (Steam community, 770 official) — https://steamcommunity.com/app/474750/discussions/0/133256758573427840
5. Plague Inc. App Store listing and IAPs — https://apple.co/39FYLRs ; fan wiki — https://plagueinc.wiki.gg/wiki/Plague_Inc.
6. Reigns sales and revenue — https://www.pocketgamer.biz/news/63976/tinder-esque-indie-strategy-reigns-600000-downloads/ ; https://www.pcgamesinsider.biz/success-story/66428/how-tinder-meets-game-of-thrones-title-reigns-sold-18m-copies/ ; https://en.wikipedia.org/wiki/Reigns_(video_game) ; https://www.pcgamesinsider.biz/news/75123/devolver-lays-off-40-of-nerial-workforce/ ; https://echoboomer.pt/?p=316703 ; price — https://www.pocketgamer.co.uk/reigns/reigns-is-now-at-its-lowest-price-in-almost-a-year/
7. Universal Paperclips — https://en.wikipedia.org/wiki/Universal_Paperclips ; https://reference.org/facts/Universal_Paperclips/8bQAnKoX ; https://apps.apple.com/us/app/universal-paperclips/id1300634274
8. Rebel Inc: Escalation Steam estimates — https://raijin.gg/app/1088790/Rebel_Inc_Escalation ; https://vaporlens.app/app/1088790/rebel_inc_escalation/stats/details
9. BitLife IAP prices — https://www.apppricinglab.com/app/apple/1374403536 ; https://apps.apple.com/app/bitlife/id1374403536
10. BitLife and Candywriter — https://www.pocketgamer.biz/news/73190/stillfront-group-acquires-bitlife-developer-candywriter/ ; https://borsvarlden.com/artiklar/stillfront-koper-amerikanska-mobilspelsutvecklaren-candywriter ; https://sensortower.com/blog/2024-q1-android-top-5-simulator%20games-revenue-us-60416e41241bc16eb8905c2f ; https://stillfrontgroup.teamtailor.com/jobs/7269503-narrative-designer
11. GameAnalytics 2025 Mobile Benchmarks — https://investgame.net/wp-content/uploads/2025/02/2025-GameAnalytics-Mobile-Gaming-Benchmarks.pdf ; summary — https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks
12. GameAnalytics 2026 Mobile and PC Benchmarks — https://gamedevreports.substack.com/p/gameanalytics-mobile-and-pc-game ; https://investgame.net/wp-content/uploads/2026/01/2026-01-20-Mobile_retention_benchmarks_2026.pdf
13. Democracy 4 — https://raijin.gg/app/1410710/Democracy_4 ; https://www.positech.co.uk/cliffsblog/category/business/page/3/
14. Choices monetization — https://www.blog.udonis.co/mobile-marketing/mobile-games/choices-stories-you-play-analysis ; https://emshort.blog/2017/03/13/choices-episode/
15. Endgame: Singularity — https://lutris.net/games/endgame-singularity/
16. Plague Inc. China removal — https://ndemiccreations.com/en/news/173-statement-on-the-removal-of-plague-inc-from-the-china-app-store ; https://technode.com/2020/02/27/plague-inc-removed-from-chinese-app-stores-amid-outbreak/
17. Apple App Review Guidelines (1.1.1, 1.1.2, 1.1.7, 3.1.1) — https://developer.apple.com/app-store/review/guidelines/
18. Google Play Sensitive Events policy — https://support.google.com/googleplay/android-developer/answer/9878810
19. Appodeal Mobile Casual Benchmarks 2025 — https://appdevelopermagazine.com/mobile-casual-benchmarks-report-2025/ ; ARPDAU ranges — https://blog.playio.co/arpdau-benchmarks-mobile-games ; India vs US eCPM — https://vmobify.com/blog/casual-game-marketing-strategy ; https://gamesbeat.com/?p=166894
20. Ad and IAP mix by region, subscription growth — https://gamedevreports.substack.com/p/sensor-tower-mobile-game-ad-monetization ; Xsolla Q2 2025 — https://www.businesswire.com/news/home/20250702208715/en ; rewarded eCPM spread — https://blog.playio.co/rewarded-ad-benchmarks-2026
21. ESRB Plague Inc: Evolved (E10+) — https://www.esrb.org/ratings/10031176/plague-inc-evolved/
22. India market — https://respawn.outlookindia.com/gaming/gaming-news/lumikai-india-gaming-market-1-5-billion-rmg-ban-2025 ; Lightbox ARPU — https://www.storyboard18.com/amp/gaming-news/75-of-indian-gamers-spend-on-in-app-purchases-reveals-lightbox-report-81507.htm
23. BitLife age ratings — https://www.qustodio.com/blog/is-bitlife-safe-for-kids/ ; https://hwb.gov.wales/keeping-safe-online/in-the-know/bitlife
24. Suzerain mobile — https://www.torporgames.com/press-releases-new/2022/12/08/political-drama-suzerain-out-now-on-mobile ; relaunch — https://gamingtrend.com/news/suzerain-marks-4th-anniversary-with-re-launch-on-mobile-with-expansion
25. Pew Research, AI and its impact (Sept 2025) — https://www.pewresearch.org/wp-content/uploads/sites/20/2025/09/PS_2025.9.15_AI-and-its-impact_report.pdf
26. AI 2027 discourse — https://centerforhumanetechnology.substack.com/p/what-you-need-to-know-about-ai-2027 ; https://thezvi.substack.com/p/ai-2027-dwarkeshs-podcast-with-daniel
27. Rebel Inc. launch and Afghanistan — https://www.ndemiccreations.com/en/news/152-rebel-inc-launches-on-android-get-it-now-on-the-google-play-store ; https://ndemiccreations.com/en/news/176-rebel-inc-now-available-in-afghanistan
28. Apple age-rating overhaul (2025) — https://www.iphoneincanada.ca/2025/07/25/updated-app-store-age-ratings ; https://www.businesstoday.in/amp/technology/news/story/apple-overhauls-app-store-age-ratings-adds-new-13-16-and-18-categories-486587-2025-07-28
29. Rewarded ads and premium conversion — https://blog.unity.com/games/new-study-reveals-the-future-of-mobile-game-monetization ; https://idsdl.csom.umn.edu/c/share/rewardads.pdf
30. Apple INR pricing — https://www.fonearena.com/blog/148316/apple-now-allows-developers-to-price-their-ios-apps-as-low-as-rs-10-on-the-app-store.html/amp ; https://appsops.store/blog/app-store-pricing-south-asia-2026
31. Google Play ₹10 minimum — https://india.googleblog.com/2015/07/minimum-purchase-price-for-apps-on.html
32. Generative-AI search interest (Statista) — https://www.statista.com/statistics/1367868/generative-ai-google-searches-worldwide
33. Wordle growth — https://techcrunch.com/2022/05/04/wordle-new-york-times-user-growth ; https://knowyourmeme.com/memes/39248
