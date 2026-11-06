# GTA systems research: Vice City, GTA IV, and series-wide factions, services, transport and NPCs

Written Oct 27, 2026 for Solvera (four themed cities plus countryside). This
covers Vice City (2002) with Vice City Stories, GTA IV (2008), and the
systems across the series. It does not repeat `INTERIORS_SERVICES_PLAN.md`,
which already plans shops, garages, fuel, gyms, police stations and the first
transit pieces; this file says how GTA did those things and what they cost.

"GTA 8" does not exist. It is read as GTA VI, which this file does not cover:
its map belongs to the San Andreas, GTA V and GTA VI topic.

## How this was researched, and its limits

- **Access:** every direct page fetch was blocked here. WebFetch could not
  resolve Wikipedia, the GTA Wiki (fandom), grandtheftwiki.com or
  rockstargames.com; curl got 403; web.archive.org was refused. **Every fact
  comes from WebSearch result summaries** that quote and link the pages in
  Sources. No page was read in full.
- **Budget:** the 200-search budget (shared by all agents this turn) ran out
  partway; topics marked **NOT RESEARCHED** never got a search.
- **Labels:** **verified** = two or more independent sites agree (e.g. the
  fandom GTA Wiki and Grand Theft Wiki, or a wiki and a guide site);
  **single source**; **conflict** = sources disagree, both values given;
  **memory** = my prior knowledge, unchecked, kept only where leaving it out
  would mislead; **inferred** = a design reading from verified facts.
- Most sources are fan wikis and guides. The only developer-primary item is
  Obbe Vermeij on GTA IV's ferries.

---

## 1. Maps

### 1.1 Vice City (2002; Vice City Stories 2006)

| Item | Finding | Label |
|---|---|---|
| Basis | Miami, set in 1986 (Vice City Stories: 1984) | verified (Giant Bomb, Grand Theft Wiki) |
| Size | About 9.11 km² (3.52 sq mi), only slightly bigger than GTA III's 8.12 km². Complex's rough land-area figure is 3.5 sq mi | verified (Insider Gaming, TheGamer, Complex), approximate |
| Layout | Two main islands. **West (mainland)**: Downtown, Little Haiti, Little Havana, Viceport, the army base, Escobar International Airport. **East (beach)**: Ocean Beach, Washington Beach, Vice Point | verified (fandom Vice City wiki, Giant Bomb) |
| Middle islands | Starfish Island (the rich island, with the Vercetti Estate), Prawn Island (InterGlobal film studios) and Leaf Links (golf). The islands are linked by bridges: one freestanding bridge, plus a chain of bridges hopping across the small islands | verified. **Conflict** on the count: "2 large + 3 small" against "2 major + 6 small" |
| Districts | About 12 (one source); others don't give a count | single source |
| Transit | No railway or rapid transit. All islands are joined by road bridges | single source (Grand Theft Wiki) |
| Gating | At the start the bridges are closed by a **hurricane warning**. The eastern Island Bridge section (Washington Beach/Vice Point to Starfish) opens after "Guardian Angels"; the western sections (Little Havana to Starfish, and North Bridge) open after "Phnom Penh '86", about 13 missions in, which opens the whole map. A pier glitch lets players cross early | verified (GTA Wiki, Grand Theft Wiki, iGrandTheftAuto) |

**District themes.** Ocean Beach is "an upper-class tourist district" with a
few skyscrapers and many low-rises, based directly on South Beach (Art Deco),
and is where the player starts (Ocean View Hotel). Starfish Island is "where
the wealthiest… dwell". *Verified (fandom VC wiki, Giant Bomb).* The theme
words for the other districts (Little Havana Cuban, Little Haiti Haitian,
Downtown towers) come from the district names and the gang placement below;
none of the summaries described them in detail. *Inferred.*

**Factions by district:**

| Faction | Turf | Game | Label |
|---|---|---|---|
| Cubans | Little Havana | VC, VCS | verified |
| Haitians | Little Haiti; rivals of the Cubans over the poor districts | VC | verified |
| Cholos | Little Haiti and parts of Little Havana; gone by 1986, replaced by the Haitians | VCS | verified (GTA Wiki, Sportskeeda) |
| Vice City Bikers | Downtown | VC/VCS | single source (GTABase) |
| Sharks | Ocean Beach and Washington Beach | VCS | single source (GTABase) |
| Diaz gang | Diaz mansion on Starfish Island | VC | single source |
| Mendez Cartel | city-wide drug kingpins Diego and Armando Mendez | VCS | verified |
| Streetwannabes | listed as enemies of the Vercetti gang; no district found | VC | single source |

The district gives each gang its turf, and the wealth of a district matches
who lives there: poor districts are contested by ethnic street gangs, rich
islands hold a single drug lord's mansion. *Inferred.*

**Vice City assets (buy, then collect income):** the Malibu Club makes
$10,000 a day, Kaufman Cabs $5,000, the Cherry Popper ice-cream factory
$3,000. Sunshine Autos rises from $1,500 to $9,000 a day as you finish its
car lists. *Single source (GTABase); GTAIntel's figures conflict.* Prices
also **conflict**: Malibu $120,000 (GTAIntel, a Spanish guide), Kaufman Cabs
$40,000 (StrategyWiki), Cherry Popper $20,000 ($10,000 on mobile), and
Sunshine Autos $50,000 ($25,000 on mobile). Each asset is unlocked by its own
short mission strand and then pays out at the building. *Memory, for the
strand detail.*

**Vice City Stories "Empire Building":** 6 business types (Protection,
Loan Shark, Prostitution, Drugs, Smuggling, Robbery) in 3 sizes
(Small-Time, Medium Venture, High-Roller). *Verified (GrandTheftWiki,
GTABase, StrategyWiki).* About 30 sites (*single source*). Prices
**conflict**: $6,000 / $11,900 / $17,800 (GTABase) against $1,500 / $2,900
/ $4,400 for Protection (GrandTheftWiki). Businesses earn passive income and
**rival gangs attack them**; "Blitzkrieg" needs at least 5 owned and has the
Mendez Cartel hit them. *Verified.*

### 1.2 GTA IV: Liberty City (2008)

| Item | Finding | Label |
|---|---|---|
| Basis | New York City | verified |
| Size | About 16.1 km² (6.2 sq mi), about twice GTA III's. Complex's rough land figure is 6.8 sq mi. **Smaller than San Andreas**, made up for by density, with no "wasted" countryside or desert | verified (Insider Gaming, Complex, GTA Wiki, TheGTAPlace) |
| Boroughs | **Broker** = Brooklyn, **Dukes** = Queens, **Algonquin** = Manhattan, **Bohan** = Bronx, plus the separate state of **Alderney** = New Jersey. There is no Staten Island (reportedly judged not fun to play). Each borough is its own island, except Broker and Dukes, which share one | verified (GTA Wiki, TheGTAPlace, StrategyWiki) |
| Gating | The bridges are locked down by a **terrorist threat** early on. Crossing them brings constant police pursuit. The blockades lift as the story advances | verified |
| Year | 2008 (Wikipedia) against 2007 (another site) | conflict |
| Dan Houser quote | "New York had never been done to the level we were envisioning" is widely quoted, but no original transcript was found | unverified |

**Borough character.** No summary described each borough in detail. From
memory (*unverified*): Broker is working class (Russian and Jamaican
scenes, the Coney Island boardwalk); Dukes has the airport and Italian and
Irish suburbs; Algonquin is towers, Times Square and finance; Bohan is poor
(Hispanic and Spanish Lords turf); Alderney is industrial and suburban.
The Pegorino and Ancelotti bases in Alderney are *verified* (2.3).

**Subway (LTA):** 4 lines in the fan wiki (Algonquin Outer, Algonquin
Inner, Broker, Bohan), run as loops (K and E clockwise, C and B
counter-clockwise). Underground stations have several street stairways; all
stations share one design. The ticket machines don't work; one wiki says the
fare "is deducted after the trip", and the same summary called riding
"effectively free" (*unclear*). **No subway at 3+ wanted stars.** A 2008
transit blog called it small, "bearing little relation to New York's" map.
*Single source each.*

**Helicopter tours (Higgins Helitours):** $150 per tour from a heliport off
Fishmarket South, Algonquin; routes over Broker and Dukes, West and North
Algonquin, and the bridges; flying all earns "Sightseer". *Verified.*

**Ferries were cut.** The first trailer showed a "Liberty Ferry"; the final
game has none you can ride. Technical director **Obbe Vermeij**: they were
meant to move "back and forth kinda like a train" and were cut late over
"the collision and AI of peds and vehicles sitting on top of another
vehicle", meaning physics and boarding queues, not performance. Leftovers:
NPCs spawn at the Alderney terminal, and an Algonquin terminal interior
exists. *Verified (Gameranx, 80.lv, Gamereactor, LevelUp).* Liberty City
Stories (2005) did ship ferries, boarded at a dock marker. *Single source.*

---

## 2. Factions

### 2.1 Cults

**Epsilon Program (GTA V; referenced in SA per *memory*).** An optional
strand for Michael, not needed for 100%, opened after "Father and Son" by an
online quiz whose answers don't matter. It is a **money sink**: a $500
donation, robes for $25,000 worn for 10 cumulative in-game days, $50,000
for the final mission, about $90,500 in all. One step is **walking 5 miles
through the desert in the robes**. The finale, "Unknowing the Truth", lets
you steal the cult's money, up to about $2.1M. *Verified (GTABase, PowerPyx,
GamesRadar, Gamer Guides).*

**The Altruists (GTA V).** A hill-camp cult in the Chiliad wilderness.
Trevor can drive hitchhikers and random-event people there for about
**$1,000 each** (taking them home usually pays more). After 4 deliveries,
Trevor is led in at gunpoint and fights out, and can take 5 briefcases of
$25,000. *Verified (Grand Theft Wiki, TheGamer, Steam forum).*

*Inferred pattern:* a cult is a long, weird side strand with escalating
money sinks and a payout heist, plus a countryside location that random
events feed into.

### 2.2 Unions and labour rackets: what exists

| Game | Content | Label |
|---|---|---|
| **Liberty City Stories (1998 setting)** | The **Liberty City Trade Union** is central early on. Ferry workers led by **Jane Hopper** strike when the mayor won't guarantee the Harwood–Staunton ferry, threatened by the new Porter Tunnel and Callahan Bridge. Harbour workers picket in sympathy, and the strike shuts Portland Harbor. Salvatore Leone wants the docks open | verified (GTA Wiki, Grand Theft Wiki, Giant Bomb) |
| LCS missions | **"Ho Selecta!"**: bring at least 6 prostitutes to the picket line in a time limit to break it up. **"Frighteners"**: chase down and beat 3 union bosses. A bribe-delivery mission also exists, where Hopper takes the money and sends thugs | verified (Grand Theft Wiki, iGrandTheftAuto) |
| Hopper's character | Publicly pro-worker, privately corrupt, after bribes | single source |
| GTA IV | "Union Drive" (a Bernie Crane mission) is blackmail, not labour. *The Ballad of Gay Tony* has a **union official working for the Messina family** (a minor character) | single source each |
| GTA V | No union mission line was found. Michael and Trevor do work the docks as cover ("Scouting the Port"), *memory, unverified* | not found |

So GTA has exactly one real union storyline: the LCS dock and ferry strike.
There, **the union is a gate, not a gang**: its strike physically closes a
transport link and the harbour until the player breaks it. *Inferred from
verified facts.*

### 2.3 Drug cartels and Mafia families

| Group | Game | Facts | Label |
|---|---|---|---|
| **Mendez Cartel** (Diego and Armando) | VCS | The most powerful kingpins of 1984. They ally with the Vances to build a drug empire, then demand the Vances hand it over and leave town. They attack the businesses ("Blitzkrieg", "Blitzkrieg Strikes Again") | verified |
| **Madrazo Cartel** (Martin Madrazo) | V | Based at La Fuente Blanca ranch, Senora Rd, Vinewood Hills. "Caída Libre": shoot down a plane carrying Javier (cousin or nephew: conflict). Trevor kidnaps Madrazo's wife Patricia | verified |
| **Colombian Cartel** | III (and SA via Catalina) | III's main antagonists, producing the drug SPANK. In SA, Catalina, later its leader in III, appears in Red County. **No Colombian cartel faction in SA was found** | verified for III; SA faction not found |
| **Leone, Sindacco, Forelli** | III era, SA | The three families invest together in Caligula's Palace casino in Las Venturas and split the profits three ways. The Sindaccos are from Liberty City and also based in Las Venturas | verified |
| **The Commission** (Gambetti, Pavano, Lupisella, Messina, Ancelotti) | IV era | Rankings conflict between sources. Turf: Gambetti in Broker, Dukes and Algonquin; Pavano in Algonquin; Lupisella in Bohan; Messina in Algonquin and Dukes; Ancelotti in Alderney (Acter) and Little Italy | single source per item; ranks conflict |
| **Pegorino family** | IV, TLAD | Based in Alderney; not on the Commission | verified |

### 2.4 Syndicates: the Loco Syndicate (San Andreas)

Three members, each from a different social layer: **Mike Toreno** (the
brains, secretly a government agent), **T-Bone Mendez** (the muscle, leader
of the San Fierro Rifa) and **Jizzy B.** (the face, a pimp and club owner).
Based in San Fierro, with a cocaine plant in an old Doherty factory. Big
Smoke's crack empire buys from them through Ryder, tying in the Ballas. CJ
kills Ryder, Jizzy and T-Bone. *Verified (Grand Theft Wiki, GTAIntel).*
*Inferred:* a syndicate is a cross-city supply chain, so taking it apart
sends the player through a club, a street gang and the government.

### 2.5 Corporates and agencies (GTA V)

- **Merryweather Security:** a private military contractor (Don Percival)
  with a guard division (dogs) and a paramilitary division; it guards the
  Port of Los Santos. "The Merryweather Heist" steals a device (described as
  a weapon or warhead) from a Merryweather ship, by a port approach or an
  offshore one whose location **conflicts**. *Verified.*
- **FIB against IAA:** corrupt FIB agent Steve Haines (on billionaire Devin
  Weston's payroll) coerces Michael and Dave Norton into pulling a suspect
  out of IAA headquarters ("Three's Company"); "Monkey Business" steals a
  chemical weapon from an IAA lab; a Kortz Center standoff has rogue FIB,
  the IAA and Merryweather shooting each other. *Verified.*
- **Stock market:** LCN (offline, moved by the player's actions) and BAWSAQ
  (online). Lester's 5 assassinations (1 story, 4 optional) each kill an
  executive and move rival companies' shares, e.g. Betta Pharmaceuticals
  against Bilkinton Research. *Verified (GTABase, SegmentNext, Prima).*
- **Lifeinvader, Union Depository:** *NOT RESEARCHED.* From memory
  (unverified): a Facebook parody whose CEO is killed with a booby-trapped
  phone, and the gold vault robbed in the final heist.

*Inferred:* corporates act through security forces, money and agencies. They
give missions and are heist targets, not turf holders.

### 2.6 Riots: the San Andreas Los Santos riots

- **Trigger:** Officer Tenpenny is acquitted at the start of "Riot", the
  third-to-last mission. The riots last until the final mission, "End of
  the Line", whose reward lists "end of the riots"; failing "Riot" doesn't
  stop them. *Verified (StrategyWiki, Grand Theft Wiki, gta.wiki, GTABase).*
- **World changes:** peds attack each other and CJ unprovoked and carjack
  more; cars burn, buildings smoke, fires start at random; police
  helicopters circle and crowds chant; looters carry CRT TVs, and Sweet says
  "even old ladies are robbing stores". The rioters are ordinary peds, not
  gangs. *Verified.*
- **Scope:** the effects are **on only between missions**, inside **an
  invisible boundary** in Los Santos (a spot one block north of Ammu-Nation
  in Market is just outside). *Single source (gta.wiki).* Whether gang wars
  or shops switch off was **not found**; guides advise skipping side
  missions.

*Inferred:* the riot is a **city-state switch**: tuning overrides (ped
aggression, carjack rate, fires, looter props, police helicopters) inside
one polygon until a story flag clears it. No new map was built.

### 2.7 Turf: how SA's gang territories work

- Only Los Santos has territory wars: the Grove Street Families (green) take
  **Ballas (purple)** and **Vagos (yellow)** zones. *Verified (GTABase, Grand
  Theft Wiki, GTA Wiki).*
- **Start:** on foot in an enemy zone, kill **3 enemy gang members**; the
  zone flashes red on the radar. **Win:** beat **3 waves**, each better armed
  (Micro SMGs, SMGs and pistols, then MP5s and AK-47s). *Verified.* One site
  claims some big zones have 4 waves (*single source*).
- **Defend:** rivals periodically attack your zones (flashing red), which
  are lost if not defended. *Verified.* "Every few in-game days" is single
  source.
- **Payoff:** territory raises **Respect**, and **money builds up at the
  Johnson house** on Grove Street for pickup. **Recruit** up to **7**
  followers, capped by Respect. *Verified.*
- **Lock-out:** after "The Green Sabre" CJ loses all territory until "Home
  Coming". *Verified.* The territory count ("53") and Respect percentages
  were **not confirmed**.

**Saints Row 2 (peer):** 45 neighbourhoods; story missions gated by
**Respect from side activities**; multi-stage **stronghold** assaults take a
neighbourhood (e.g. rough up Chinatown shop owners until they pay the Saints
instead of the Brotherhood). *Single source each (Gaming Nexus, Wikipedia via
search).*

**Mafia, Sleeping Dogs, RDR2:** *NOT RESEARCHED* (search budget ran out).

---

## 3. Services (what each costs and gives)

| Service | Game | Cost | What it gives | Label |
|---|---|---|---|---|
| Hospital ("Wasted") | SA | flat **$100** | respawn; **all weapons lost**, unless dating nurse Katie Zhan | $100 verified; Katie: single source |
| Police ("Busted") | 3D era (III, VC, SA) | fine by stars: **$100 / $200 / $400 / $600 / $900 / $1,500** for 1–6 stars | weapons confiscated; dating cop Barbara Schternvart keeps them | verified |
| Busted | V | bail fee | only **ammo and body armour** taken, plus the weapon in your hand | single source (GTA Wiki) |
| Wasted | V | small fee (a 2017 forum says $500; disputed) | respawn at hospital; no confirmed $5,000 bill | conflict |
| Fast food | SA | Cluckin' Bell: $2 small, $5 big, $10 huge, $10 salad | +1%, +2%, +3% fat; salad 0%. Eating fills hunger and health | verified (Grand Theft Wiki, TheGTAPlace) |
| Hunger | SA | — | eat at least every 3 days. After **48 h** without food fat drops 2.5%/h, after **74 h** muscle drops 2.5%/h; with no fat left, health drains | verified |
| Vending machines | SA | **$1** | about **+50% of base health**, and fully resets hunger for 3 days. Two kinds, snack and drink. In VC the Sprunk machines are decorative | verified (Grand Theft Wiki, gta.wiki) |
| Gyms | SA | gym use | dumbbells and bench build muscle (and stamina). Need **35% muscle** to face the trainer; **beat the trainer** to learn the style. Ganton (LS) **boxing**; Cobra (SF) **kung fu**; Below the Belt (LV) **kickboxing**, or Muay Thai (conflict) | verified for boxing and kung fu; LV style conflicts |
| Pay 'n' Spray | series | free if the car is undamaged or lightly damaged; the SA price was **not found** | full repair, respray, and losing the wanted level after a short "probation" during which a new crime brings it back. Some vehicles are refused (police Cheetah, FBI cars, ladder truck, bicycles) | single source for most details |
| TransFender | SA | wheels $620–1,560, paint $500, stereo $100, hydraulics $1,500 | about 65 car models; nitrous 2×, 5× or 10× | verified (Grand Theft Wiki, gta.wiki) |
| Loco Low Co. | SA | as above | **8 lowriders** (Blade, Broadway, Remington, Savanna, Slamvan, Tahoma, Tornado, Voodoo): hydraulics, nitrous, lowrider parts | verified |
| Wheel Arch Angels | SA | as above | **6 tuners** (Elegy, Flash, Jester, Stratum, Sultan, Uranus): 3 vinyls, Alien and X-Flow body kits, 10 wheel types, nitrous | verified |
| Los Santos Customs | V | about $40–50K to fully upgrade one car (2013 guide) | replaces Pay 'n' Spray: repair first, then cosmetic and performance mods. Entering unseen by police clears the wanted level | single source each |
| Benny's | V | — | *NOT RESEARCHED* (from memory: lowrider and custom conversions, added in a 2015 update; unverified) | — |
| Clothes | SA | Binco cheapest, up to Didier Sachs (Tuxedo $7,000, +20% Respect, +25% Sex Appeal; 31 items) | 6 chains: Binco, Sub Urban, ProLaps, Zip, Victim, Didier Sachs. Each unlocks through a story mission. Clothing counts **4% toward Respect and 50% toward Sex Appeal** | single source (Grand Theft Wiki) |
| Barbers | SA | $50 (Caesar) to $500 (Flattop, Cornrows); Elvis $1,000 | Respect and Sex Appeal per style; 7 barbers. One wiki says a barber visit **clears the wanted level** | single source |
| Tattoos | SA | $25–720; removal $400 | at most +3% Respect or Sex Appeal each | single source |
| Ammu-Nation | SA | *NOT RESEARCHED* | — | — |

Each SA service is tied to a stat (fat, muscle, stamina, Respect, Sex
Appeal, a driving or flying skill), and the stats unlock things: trainers
need muscle, gang recruits need Respect, girlfriends need Sex Appeal and fat
levels. Cheap services exist so that you keep visiting. *Inferred from
verified rows.*

---

## 4. Transport you can use

### 4.1 Paid and scheduled rides

| Mode | Game | How it works | Label |
|---|---|---|---|
| **Taxi** | IV | Whistle for a cab on foot (not while wanted), sit in the back, pick a destination; the fare depends on distance. In the cab: **hurry**, **exit** or **skip at extra cost** (instant arrival, "tens of dollars"). Roman's car service is down between "Roman's Sorrow" and "Blow Your Cover" | verified (GTABase, Grand Theft Wiki); skip price single source |
| Taxi | V | *NOT RESEARCHED* in this session. From memory, it has the same hail, ride and skip-for-a-fee design; unverified | — |
| **Subway** | IV | see 1.2; locked at 3+ stars | single source |
| **Metro** | V | LS Transit: ticket machines are decorative, so riding is free. Board when the train stops and opens its doors. Stations include LSIA (2), Del Perro, Portola Drive, Burton, Strawberry, Puerto Del Sol, Pillbox South and Little Seoul; the line loops at LSIA and Davis. Pillbox North is closed. Mocked in-world as "for losers" | single source (gta.wiki) |
| **Trains** | SA | The **Brown Streak** passenger train and **freight trains** run a full loop of the state, 24 h, on two tracks. The passenger coach is **free**. Trains leave about 30 s after reaching a platform. You can ride on a freight flatcar or hijack the locomotive. Stations include Unity (LS, Union Station parody), Market (LS), Cranberry (SF), Linden and Yellow Bell (LV); 5 or 6 in total (conflict). "Freight Date" achievement: ride a train to the next city | verified (StrategyWiki, GTABase, Grand Theft Wiki) |
| **Scheduled flights** | SA | **Confirmed: yes.** Buy a ticket (**$500**) at the airport ticket machine to fly between **Los Santos International, Easter Bay (SF) and Las Venturas**. It plays a cutscene of an **AT-400** taking off and flying over; you **can bail out** mid-flight or skip the cutscene. **No flight leaves unless you buy a ticket.** The routes open with story progress. Verdant Meadows is not a destination | verified (GTA Wiki LSIA and LV airport pages, GTAForums, Neoseeker) |
| **Helicopter tours** | IV | $150 per tour, several routes (see 1.2) | verified |
| Blimp ride | V | The Atomic Blimp is called by phone and picked up at the Vinewood Racetrack or LSIA. Originally a pre-order or special-edition bonus; included by default in later versions | single source |
| **Ferries** | IV | Cut (see 1.2). LCS shipped them | verified |
| Boat rentals | — | *NOT RESEARCHED* | — |

### 4.2 Vehicles by type and handling

| Type | Examples and handling | Label |
|---|---|---|
| Planes (SA) | Beagle, Cropduster, Dodo, Hydra, Nevada, Rustler, Shamal, Skimmer, Stuntplane, AT-400, Andromada. SA was the first game where rolls and loops were practical; its flying school teaches them | verified |
| Seaplane, VTOL, jets (SA) | **Skimmer** floats on water. **Hydra** is a VTOL jet (Harrier-like). **Shamal** is a balanced business jet about as fast as the Rustler. **AT-400** and **Andromada** are big, sluggish and slow to respond; the AT-400 and Hydra are the only aircraft that reach the height ceiling, and the AT-400 is found only in the Las Venturas hangar | single source each |
| Planes (V) | **Mallard** ($250,000) a stunt plane with tight turns and barrel rolls; **Cuban 800** ($240,000) good handling and speed; **Velum** mid-range, jet-like; **Shamal** fast but "little traction or braking"; **Luxor** better traction; **Duster** ($275,000) crop duster at Sandy Shores and McKenzie Field. Propeller planes are nose-heavy and feel turbulence (one wiki page) | single source (Prima, Game8, Grand Theft Wiki) |
| Helicopters | handling *NOT RESEARCHED* | — |
| Blimp (V) | **Atomic Blimp** handles like a helicopter, not a slow airship; the throttle makes it climb rather than move forward; fragile, it explodes on a bump into a building or car. No drivable blimp found in vanilla SA (the results were mods) | single source (gta.wiki) |
| Speedboats | **Jetmax** and **Squalo** are the fastest in VC and SA. The Jetmax turns badly ("limited to straight racing"); the Squalo "turns on a dime" under throttle. Which is faster **conflicts**. **Speeder** (V): high top speed and acceleration | single source each |
| Yachts | **Tropic** is one of the slowest boats (like the Marquis and the Rio) and turns poorly, but its pump-jets cross shallow water. **Marquis** does about 26 mph (V Online) | single source |
| Hovercraft (SA) | **Vortex** works on land and water, has little grip, and the ground surface doesn't change its top speed. It brakes with reverse fan thrust, so a handbrake 180 is often quicker than braking | single source (gta.wiki) |
| Jetski (V) | **Seashark**: strong acceleration, very tight turns, works in shallow water; slower than the Speeder or Jetmax; riders are thrown off in hard crashes | single source |
| Submarines (V) | **Submersible** is crushed below about **150 m (492 ft)**: pressure warning, then implosion. **Kraken** about 152 m (500 ft); unlocked by the **Wildlife Photography** challenge (20 animal photos), docks at Cape Catfish pier, or bought for $1,325,000. The heist submersible is tougher and reaches the seabed | verified for depth |
| Sailboats, wind, Dinghy | *not found* | — |

### 4.3 Vehicle schools (SA)

| School | Lessons | Rewards (bronze / silver / gold in all) | Notes | Label |
|---|---|---|---|---|
| **Pilot** (Verdant Meadows tower, the desert airstrip CJ buys) | 10: takeoff, landing, circling, helicopter takeoff and landing, target shooting, loop-the-loop and others | **Rustler / Stuntplane / Hunter** | **Bronze in all is required for the story** (the only such school). The **pilot's licence** opens airports; finishing unlocks Victim stores and the **6-star wanted level** | verified (GTABase, StrategyWiki, Grand Theft Wiki, iGTA) |
| **Boat** (Bayside) | 5: Basic Seamanship, Plot a Course, Fresh Slalom, Flying Fish, Land, Sea and Air (Coastguard, Dinghy, Vortex) | **Marquis / Squalo / Jetmax** | needed for 100%, not the story; entering before the Gant Bridge opens gives **4 stars** | verified |
| Driving, bike | — | — | exist (*memory*) | memory |

---

## 5. NPC spread

- **SA `popcycle.dat`** controls the population mix per region type
  ("business areas, entertainment zones, shopping zones"), with a ped-density
  table per zone type (Business, Countryside, …). Densities are relative; a
  total under 100% crashes the game in that region. `pedgrp.dat` defines ped
  groups (57 groups of 21 peds, per one modding guide), and `cargrp.dat`
  gives each group its cars (for example `POPCYCLE_GROUP_BUSINESS`,
  `_CLUBBERS`, `_FARMERS`). The mission script binds a group to each named
  zone (opcode 0767, zones such as `MARKST`, `UNITY`, `LAIR1`). *Verified
  (GTAMods Wiki, GTAForums, SA Modding Book).* The tables are split by time
  band (*memory*); mods describe "fewer cars and people at night" (*mod
  pages only*).
- **Country and desert:** Montgomery (Red County) residents are "working
  class whites and rednecks"; Red County is forest and farms, Bone County is
  desert. *Single source (fan wiki).*
- **GTA V:** `popgroups.ymt` lists the ped groups that spawn (*verified from
  mod docs*). How zones map to wealth ("scumminess") and density was **not
  found**.
- **Random encounters (V):** **58 Strangers and Freaks** missions
  (Franklin's 20 needed for 100%); **57 random events** at launch, plus 3 in
  the PS4, Xbox One and PC versions (one site says none: conflict); any 14
  count toward 100%. *Verified (Grand Theft Wiki, GTABase, GTAIntel).* The
  Altruist deliveries (2.1) show random events feeding a faction.
- **Street vendors, hookers, dealers:** *NOT RESEARCHED* (budget). From
  memory, unverified: SA hookers restore health above 100% for a fee; IV
  hot-dog and nut vendors restore health for a few dollars; drug dealers
  drop cash when killed; Chinatown Wars has a buy-low, sell-high drug trade
  with prices that vary by neighbourhood.
- **Riot override** (2.6): inside the riot zone the same peds turn
  aggressive and carjack more. *Verified.*

---

## 6. Lessons for Solvera, ranked by life per effort

For a top-down mobile game with four cities and countryside. Each lesson
names the fact it rests on.

1. **One population table per zone type and time band** (SA popcycle and
   cargrp). Give each district a zone type (Business, Tourist, Poor
   residential, Industrial, Gang turf, Farm, Desert), each with a ped-group
   and car-group mix per time band. "City condition" becomes data: the
   desolate city gets mostly derelict tables with few cars, the Vegas city
   gets tourist and clubber tables at night. It is the cheapest life there
   is, because no new art is needed.
2. **Travel as a cutscene or fade, not simulation.** GTA IV's ferries were
   cut because peds and cars riding a moving vehicle broke physics and
   queuing (Vermeij). SA flights are a $500 cutscene with a bail-out; IV
   taxis offer skip-for-a-fee; trains and metros are free. So scheduled
   flights, ships, ferries, trains and taxis between Solvera's cities
   should be a kiosk, a short cutscene or fade, and arrival at the
   destination terminal, with an optional mid-route bail-out into the
   countryside.
3. **Story-gated cities with a reason in the world** (VC hurricane, IV
   terror lockdown, SA wanted stars for early entry). Ship city 1, then
   open the next with a closure the story explains; crossing early is
   possible but brings stars. A **union strike** (LCS) is a ready-made gate
   that shuts a ferry or rail link until it is broken or settled.
4. **Turf as a coloured overlay with a short war loop** (SA): kill 3 to
   start, beat 3 escalating waves, rivals counter-attack on a timer, income
   builds up at one pickup, and Respect caps the follower count. Keep wars
   to one or two cities, as SA kept them to Los Santos.
5. **Cheap stat services with one number each** (SA vending: $1 for about
   50% health; food: price per fat point; barbers and tattoos: Respect and
   Sex Appeal; gyms: 35% muscle, then beat the trainer). Vending machines
   cost one model and one prompt; make them sparse or broken in the
   desolate city (*inferred*).
6. **Businesses that earn and get attacked** (VC assets pay daily; VCS has 6
   types in 3 sizes, raided by the rival cartel). This gives the mafia,
   cartel and syndicate factions a systemic job.
7. **City-state switches for riots and events** (SA riot: ped aggression,
   carjacking, fires, looters and police helicopters inside one boundary,
   switched on between missions and cleared by a story flag). Reuse it for
   the desolate city's bad night or a Vegas blackout, with no new geometry.
8. **Schools that gate exotic vehicles and pay out vehicles** (SA pilot
   school: Rustler, Stuntplane, Hunter and an airport licence; boat school:
   Marquis, Squalo, Jetmax). One school per family (planes, helicopters,
   boats, airships) teaches each physics and paces access.
9. **Handling by archetype, not by model.** GTA's useful contrasts: the
   straight-line speedboat (Jetmax) against the nimble one (Squalo); the
   slow yacht that crosses shallows (Tropic); the gripless land-and-water
   hovercraft (Vortex); the tight-turning jetski that throws its rider
   (Seashark); stunt plane, heavy airliner, seaplane and VTOL; the fragile,
   helicopter-like blimp; the submarine with a crush depth. About 8–10
   profiles cover Sachin's list.
10. **Cults and corporates as side strands, not turf holders.** Epsilon:
    escalating money sinks (donation, robes, a desert walk) ending in a
    payout heist. Altruists: a countryside camp fed by random-event
    hitchhikers. Corporates act through a security force (Merryweather), a
    stock market moved by assassinations, and agency rivalry (FIB against
    IAA).
11. **Random encounters in volume** (V: about 57–60 random events, 58
    Strangers and Freaks). For mobile, 20–30 short street events weighted by
    zone type (muggings in poor zones, breakdowns in the countryside) give
    density cheaply (*inferred*).

**Cheaper option for items 4 and 6:** territory as flavour only
(colour-coded gang peds, no wars), which saves the wave AI and the attack
timers.

---

## Not researched, or could not open

- **Blocked** (direct fetch): en.wikipedia.org, gta.fandom.com,
  grandtheftwiki.com, rockstargames.com, web.archive.org. Their facts came
  only through search summaries.
- **Search budget used up before:** Mafia, Sleeping Dogs, RDR2; street
  vendors, hookers and dealers; Chinatown Wars' drug trade; GTA IV friends
  and activities; GTA V taxis; helicopter handling; Ammu-Nation prices; the
  SA Pay 'n' Spray price; Benny's; Lifeinvader and the Union Depository;
  borough-by-borough character in GTA IV; SA car groups per area.
- **Searched but not found:** a vanilla SA blimp; a GTA V union mission
  line; a Colombian cartel faction in SA; GTA V's zone-wealth mapping; the
  SA territory count.

## Sources

All were reached through WebSearch result summaries, not opened directly.

- Vice City map, districts and gangs: https://rockstargamesgtavicecity.fandom.com/wiki/Vice_City · https://giantbomb.com/wiki/Locations/Vice_City · https://www.grandtheftwiki.com/Vice_City_in_GTA_Vice_City · https://www.grandtheftwiki.com/Gangs_in_GTA_Vice_City · https://www.gtabase.com/gta-vice-city-stories/gangs/ · https://sportskeeda.com/gta/a-complete-list-gangs-disappeared-gta-vice-city-stories-vice-city · VC bridges and unlocks: https://gta.fandom.com/wiki/Island_Bridge · https://www.grandtheftwiki.com/Island_Bridge · https://www.grandtheftwiki.com/North_Bridge · https://www.igrandtheftauto.com/gtavc/guides/helicopters-and-planes · https://www.igrandtheftauto.com/gtavc/guides/pier-glitch-get-to-other-islands-early
- Map sizes: https://insider-gaming.com/a-list-of-every-gta-map-and-its-size/ · https://www.thegamer.com/which-grand-theft-auto-has-the-biggest-world-map/ · https://www.complex.com/pop-culture/2013/09/grand-theft-auto-v-size-scale · VC assets: https://www.gtabase.com/gta-vice-city/properties/ · https://strategywiki.org/wiki/Grand_Theft_Auto:_Vice_City/Assets_&_Safe_House · https://gtaintel.com/news/vice-city-property-empire-guide · https://bloxodes.com/gta/wiki/gta-vice-city/assets
- VCS Empire and Mendez: https://www.gtabase.com/gta-vice-city-stories/side-missions/empire-building · https://www.grandtheftwiki.com/Empire_Building · https://strategywiki.org/wiki/Grand_Theft_Auto:_Vice_City_Stories/Empire_building · https://www.igrandtheftauto.com/gtavcs/guides/empire-building · https://gta.fandom.com/wiki/Diego_Mendez · https://www.grandtheftwiki.com/Blitzkrieg · GTA IV Liberty City: https://gta.fandom.com/wiki/Liberty_City_in_GTA_IV_era · https://www.thegtaplace.com/gta4/liberty-city · https://strategywiki.org/wiki/Grand_Theft_Auto_IV/Locations
- IV subway: https://www.grandtheftwiki.com/Subway_(GTA_IV) · https://gta.fandom.com/wiki/Routes_K_%2B_E · https://gta.fandom.com/wiki/San_Quentin_Avenue_Station · https://secondavenuesagas.com/2008/03/28/appreciating-the-subways-through-grand-theft-auto/ · IV helicopter tours: https://www.grandtheftwiki.com/Higgins_Helitours · https://www.grandtheftwiki.com/Heli-tours
- IV taxis: https://gtabase.com/articles/how-to-teleport-in-gta-iv-without-mods-by-using-taxis · https://www.grandtheftwiki.com/Taxi_Rides · IV ferries (Vermeij): https://gameranx.com/updates/id/562012/article/gta-iv-technical-director-obbe-vermeij-explained-why-the-ferries-got-cut/ · https://80.lv/articles/former-rockstar-dev-solved-a-16-year-mystery-in-gta-iv · https://www.gamereactor.eu/did-gta-iv-have-ferry-transportation-at-one-point/ · https://www.levelup.com/noticias/576574/Grand-Theft-Auto-IV-pudo-tener-un-sistema-de-ferris-funcional
- Epsilon: https://www.gtabase.com/grand-theft-auto-v/gangs/epsilon-cult · https://powerpyx.com/guide/grand-theft-auto-v-kifflom-trophy-achievement-guide.html · https://gamesradar.com/gta-5-kifflom-guide · https://gamerguides.com/grand-theft-auto-v/guide/strangers-and-freaks/epsilon/unknowing-the-truth · Altruists: https://www.grandtheftwiki.com/The_Altruists · https://www.thegamer.com/grand-theft-auto-v-10-things-you-never-knew-about-the-altruist-cult/ · https://steamcommunity.com/app/271590/discussions/0/133261370010013976
- Unions: https://gta.fandom.com/wiki/Liberty_City_Trade_Union · https://www.grandtheftwiki.com/Liberty_City_Trade_Union · https://gta.fandom.com/wiki/Portland_Harbor · https://gta.fandom.com/wiki/Union_Official · https://www.grandtheftwiki.com/Ho_Selecta! · https://www.grandtheftwiki.com/Frighteners · https://www.igrandtheftauto.com/gtalcs/guides/frighteners · https://www.giantbomb.com/wd/3030-6731 · Mafia families: https://www.grandtheftwiki.com/Cosa_Nostra · https://www.grandtheftwiki.com/Sindacco_Family · https://www.gtabase.com/grand-theft-auto-iv/gangs/ancelotti-crime-family · https://gta.fandom.com/wiki/Pavano_Crime_Family
- Madrazo: https://www.grandtheftwiki.com/Madrazo_Cartel · https://www.grandtheftwiki.com/La_Fuente_Blanca · https://gta.fandom.com/wiki/Patricia_Madrazo · https://www.gtabase.com/grand-theft-auto-v/missions/caida-libre · Colombian Cartel: https://www.gtabase.com/gta-3/gangs/colombian-cartel · https://gta.wiki/w/Catalina
- Loco Syndicate: https://www.grandtheftwiki.com/Loco_Syndicate · https://www.grandtheftwiki.com/Mike_Toreno · https://gtaintel.com/games/san-andreas/missions/t-bone-mendez-sa · Merryweather, FIB and IAA: https://www.gtabase.com/grand-theft-auto-v/gangs/merryweather-security · https://gta.wiki/w/Merryweather · https://www.grandtheftwiki.com/The_Merryweather_Heist · https://www.grandtheftwiki.com/Three%27s_Company · https://www.gtabase.com/grand-theft-auto-v/characters/steve-haines · https://villains.fandom.com/wiki/International_Affairs_Agency
- Stock market: https://www.gtabase.com/grand-theft-auto-v/side-missions/gta-5-lester-s-assassinations-guide-how-to-make-2-billion-with-stock-market · https://segmentnext.com/gta-v-stock-market-exploits-money-farming-lcn-bawsaq-stock-trading-tips/ · SA riots: https://strategywiki.org/wiki/Grand_Theft_Auto:_San_Andreas/Riot · https://www.grandtheftwiki.com/Riot_(GTA_SA) · https://gta.wiki/w/Los_Santos_Riots · https://www.gtabase.com/gta-san-andreas/missions/end-of-the-line · https://sportskeeda.com/gta/why-los-santos-riots-gta-san-andreas-memorable · https://www.gamepressure.com/editorials/rap-riots-and-gangs-of-la-true-story-behind-gta-san-andreas/the-city-on-fire/z723b
- SA turf: https://www.grandtheftwiki.com/Gang_Warfare_in_GTA_San_Andreas · https://gtabase.com/gta-san-andreas/gangs · https://www.grandtheftwiki.com/Recruiting · https://gta.fandom.com/wiki/Gangs_in_GTA_San_Andreas · https://gtaintel.com/news/san-andreas-territory-war-mechanics · Saints Row 2: https://www.gamingnexus.com/Article/1999/Saints-Row-2 · https://en.wikipedia.org/wiki/Saints_Row
- Death and arrest: https://www.grandtheftwiki.com/Hospitals · https://www.grandtheftwiki.com/Death · https://gta.wiki/w/Busted · https://steamcommunity.com/app/271590/discussions/0/3182216552774669794 · Food, vending, gyms: https://www.grandtheftwiki.com/Restaurants_in_GTA_San_Andreas · https://www.grandtheftwiki.com/Eating · https://thegtaplace.com/news/736/gamespots-san-andreas-food-preview/ · https://www.grandtheftwiki.com/Vending_Machines · https://gta.wiki/w/Snacks · https://www.igrandtheftauto.com/gtasa/guides/gym-fighting · https://www.grandtheftwiki.com/Below_the_Belt_Gym · https://gta.wiki/w/Cobra_Marital_Arts
- Car shops: https://www.grandtheftwiki.com/Mod_Garages · https://gta.wiki/w/Mod_Garages · https://gta.wiki/w/Pay_%27n%27_Spray · https://www.grandtheftwiki.com/Spray_Shop · https://www.gtaboom.com/los-santos-customs-eba4 · https://en.m.wikigta.org/wiki/Los_Santos_Customs · https://www.supercheats.com/grand-theft-auto-5/wiki/los-santos-customs-10-g · Clothes, barbers, tattoos: https://www.grandtheftwiki.com/Clothing_in_GTA_San_Andreas · https://www.igrandtheftauto.com/gtasa/guides/didier-sachs-clothing · https://www.grandtheftwiki.com/Old_Reece%27s_Hair_%26_Facial_Studio · https://www.grandtheftwiki.com/Tattoo_Parlors
- SA flights: https://gta.fandom.com/wiki/Los_Santos_International_Airport_(3D_Universe) · https://gta.fandom.com/wiki/Las_Venturas_Airport · https://www.grandtheftwiki.com/Airports · https://gtaforums.com/topic/241346-plane-ticket/ · https://www.neoseeker.com/forums/6506/t456115-airport-tickets/ · SA trains: https://strategywiki.org/wiki/Grand_Theft_Auto:_San_Andreas/Freight · https://www.gtabase.com/gta-san-andreas/side-missions/freight-train-challenge · https://www.grandtheftwiki.com/Freight_Train_Challenge · https://www.trueachievements.com/a193977/freight-date-achievement
- V metro: https://gta.wiki/w/Los_Santos_Transit_Metro · https://www.grandtheftwiki.com/Rockford_Hills_Metro_Station · Schools: https://www.gtabase.com/gta-san-andreas/side-missions/flying-school · https://strategywiki.org/wiki/Grand_Theft_Auto:_San_Andreas/Learning_to_Fly · https://www.igrandtheftauto.com/gtasa/guides/pilot-school · https://www.gtabase.com/gta-san-andreas/side-missions/boat-school · https://www.igrandtheftauto.com/gtasa/guides/boat-school · https://gta.wiki/w/Flight_School
- Aircraft, boats, blimp, subs: https://www.grandtheftwiki.com/Fixed-Wing_Aircraft · https://gta.wiki/w/Airplanes · https://www.grandtheftwiki.com/AT-400 · https://primagames.com/news/grand-theft-auto-v-aircraft-guide · https://gta.wiki/w/Atomic_Blimp · https://www.gtabase.com/grand-theft-auto-v/vehicles/blimp · https://gta.wiki/w/Vortex · https://gta.wiki/w/Seashark_(lifeguard) · https://gta.wiki/w/Squalo_(3D_Universe) · https://gta.fandom.com/Jetmax · https://gta.wiki/w/Kraken · https://gta.wiki/w/Submersible · https://www.digitalcameraworld.com/news/gta-wildlife-photography-challenge-could-unlock-you-a-submarine · NPC zones: https://gtamods.com/wiki/Popcycle.dat · https://gtaforums.com/topic/618278-opcode-0767-setting-zones-for-peds-and-cars/ · https://pdfcoffee.com/gta-sa-modding-book-10-pdf-free.html · https://gta.fandom.com/wiki/Palomino_Creek · https://giantbomb.com/wiki/Locations/Bone_County · https://www.gta5-mods.com/tools/addon-peds-spawner
- Random events and Strangers and Freaks: https://www.grandtheftwiki.com/Random_Events · https://www.grandtheftwiki.com/Strangers_and_Freaks · https://gtaintel.com/news/gta-5-random-events-complete-list · https://www.gtabase.com/grand-theft-auto-v/guides/gta-5-100-completion-guide-checklist
