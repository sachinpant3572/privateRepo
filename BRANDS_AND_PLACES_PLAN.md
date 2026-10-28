# Enterable places and brands: recommendation

Sachin's ask (2026-10-28): "Build some enterable buildings too after
expanding Belleriv, one for every major category. Put them in strategic
locations, in every district. We will then have to create brands for
different things, several brands will be there for every category, similar
to real world, like 1-2 high luxury clothing brands, 3-4 mix luxury, 6-8
fast fashion cheap brands that too in different price points and different
clothing being offered. Same for others type of things too. Research well
and then recommend."

This document is the recommendation. Nothing in it is built yet. It extends
`INTERIORS_SERVICES_PLAN.md`: that plan covers the systems (menus, wardrobe,
respray, weapons, schools), and this one covers which buildings, where, and
under which brand.

**Research behind it.** Two research passes ran on 2026-10-28:
- one on places: which shop categories games make enterable, and where real
  shops stand by income and district type;
- one on brands: real-world tiers and price points per category, the
  fictional rosters of GTA, Saints Row and Cyberpunk, and trademark-safe
  naming.

The findings are summarised here. Figures marked [V] were checked against a
cited source; [E] marks an estimate or a judgement. The full notes, with
about 120 sources, are kept outside the repo because of their size; ask if
you want them committed.

**Limits.**
- No trademark knockout search has been run on the names below. They are
  invented to avoid sound-alikes of famous marks, but each needs a search
  before it is locked (section 6).
- Two GTA wikis were blocked by the network, so some game rosters come
  from search summaries.

---

## 1. Recommendation in short

1. **Categories.** 19 categories in all:
   - **13 must-have:** corner store, fast food/diner, restaurant/café,
     supermarket, petrol, clothing, barber/salon, body and mod shop, gym
     and fight school, weapons with range, clinic/hospital, police, and
     bar/club;
   - **6 nice-to-have:** hotel/motel, pawn/check cashing, tattoo, car
     dealer, feed/bait store, and transit hall.
2. **Option A, recommended: about 42 enterable anchor places.** Every
   category gets at least one enterable building, and every one of the 17
   districts gets at least one (1 in the small bayou towns, 3-5 in the
   city). The full map of about 145 places stays the long-term target; the
   rest come from the block roll or later phases.
3. **Brands.** Name and register about 220 fictional brands now, in a data
   file with tier, price multiplier, colours and style. Storefronts and
   interiors are built only for the brands on enterable places. The rest
   appear on billboards, NPC clothing, cars and radio until later cities
   need them. This is how GTA does it: 3-6 enterable clothing chains per
   city, while many more brands live only on signs [V].
4. **Clothing**, as you described it:
   - 2 top luxury houses;
   - 4 mixed luxury brands (bridge and contemporary);
   - 7 cheap fast-fashion brands at four price points with different
     clothes;
   - plus streetwear, athleisure, western/work, department stores,
     off-price and thrift: 27 clothing brands in all;
   - 7 of them enterable in Bellerive.
5. **How the player reads tier.** First from the district (the richest
   districts hold the luxury shops), then from the storefront and interior,
   then from the price tag. GTA uses this order [V]. Brands repeat across
   districts only for the chains (fast food, fuel, supermarkets); locals
   appear once.
6. **Order.** Build the anchors after the 0.20 hand-over, in the order of
   the interiors plan: food and daily life first, looks second.

---

## 2. Categories

| # | Category | What the player does there | M/N | Interiors plan phase |
|---|---|---|---|---|
| 1 | Corner store / 24-7 / liquor | Snacks (heal, or carry 3), fuel can, repair kit; till robbery | M | 0-1 |
| 2 | Fast food / diner / po'boy | Cheap full heal; meet-ups | M | 0-1 |
| 3 | Restaurant / café (café, bistro, fine dining) | Heal plus a timed buff; mission meetings; shows wealth | M | 1 |
| 4 | Supermarket | Bulk food, the cheapest heal per dollar | M | 1 |
| 5 | Petrol station (+ mini-mart, car wash) | Fuel, car wash, snacks; robbable | M | 1 |
| 6 | Clothing (value, mid, luxury, vintage, beach) | Outfits; wardrobe collection | M | 2 |
| 7 | Barber / salon | Hair and colour | M | 2 |
| 8 | Body and mod shop | Repair, respray, parts. Proposal: a respray clears stars if no police saw the car go in | M | 3 |
| 9 | Gym and fight school | Stats; the four styles (D6) | M | 4 |
| 10 | Weapons shop with range | Guns, ammo, range challenges | M | 6 |
| 11 | Clinic / hospital | Wasted respawn; paid heal | M | 5 |
| 12 | Police precinct | Busted respawn, fines, impound, bounty board | M | 5 |
| 13 | Bar / jazz club / nightclub | Mission hub, drinks, pool and darts, later laundering | M | new |
| 14 | Hotel / motel | Rented safehouse: save, sleep, change clothes | N | new |
| 15 | Pawn / check cashing | Sell loot, cheap used guns, launder small sums | N | new |
| 16 | Tattoo | Cosmetic, next to the barber | N | new (with 2) |
| 17 | Car / bike dealer | Buy in person, test drive | N | new (with 3) |
| 18 | Feed / hardware / bait | Rural store: tools, bait, workwear | N | new |
| 19 | Transit hall | Fast travel | N | 5 |

**Why the bar is a must-have.** Two districts are built around nightlife:
jazz in the Lantern Quarter and clubs in Brisa. In San Andreas, GTA IV,
Mafia II and Yakuza, bars are mission and minigame hubs [V].

---

## 3. Where they go

### 3.1 Placement rules (from real retail siting)

- **Corner stores** stand on residential corners, not the main road. There
  is one every 4-6 blocks in the poor districts and fewer elsewhere.
- **Fast food** stands on the district's main road. It is densest in poor
  districts, with one at each highway exit.
- **Restaurants** cluster 2-4 together on the high street.
- **Supermarkets** anchor the end of a suburban strip, with parking in
  front. There are **none in the Wards or the East side**: that is the real
  food-desert pattern [V], and in play it means the cheapest heal there is
  snacks.
- **Petrol stations** stand on the corner of a signalled junction, on the
  "going home" side, and at every highway exit.
- **Clothing** clusters by tier:
  - luxury on the Gilt boulevard and in the Magnolia village;
  - mid-range in the Midtown mall;
  - streetwear in the Wards;
  - vintage in the Lantern Quarter;
  - beachwear in Brisa and the Shore.
- **Body shops, gun shops and dealers** sit on the industrial edge or an
  arterial strip. They are never in the luxury or tourist cores.
- **Barbers** stand mid-block beside the Wards street court, where they act
  as a social hub. Salons go on the luxury shopping streets.

### 3.2 Option A: the anchor set (about 42 enterable places)

Notes on the table:
- Brand names come from section 5.
- **(exists)** marks a place or landmark that is already in the game and
  only needs its brand and its interior.
- The existing generic corner stores and diners stay where they are. They
  take chain brands in the first build session.

| District | Wealth | Enterable anchors (category: brand) |
|---|---|---|
| Gilt District | Luxury | Clothing: **Maison Velasque** flagship. Restaurant: **Prime & Sterling** steakhouse. Gym: **Axis Club** (kickboxing, D6). Police: **Central Precinct** (exists). Hotel: **The Gilded Heron**, with a lobby bar. Transit: **Union Station** (exists) |
| Midtown | Mid | Clothing: **Harlow & Pike** and **Runway Nine**, side by side in the mall. Fast food: **Burger Barge**. Clinic: **Bellerive General** (exists) |
| Lantern Quarter | Mid, tourist | Clothing: **Second Line Thrift** (vintage). Restaurant: **Marchand's** (Creole). Bar: **The Copper Horn** (jazz). Gym: karate dojo (D6). Tattoo: **Flash & Bone** |
| Floodline Wards | Poor | Barber: **Fade Kings**. Clothing: **Corner Fly** (urban value). Fast food: **Cayenne Coop** (spicy chicken). Gym: kung fu school (D6) |
| Ironwharf | Industrial | Body and mod: **Ironwharf Customs**. Weapons: **Breakwater Arms**, with a range. Gym: **The Pit** (exists). Bar: **The Bilge** (dock bar) |
| Morrow Point | Mid / value | Petrol: **Pelican Petroleum**, at the bridgehead. Diner (exists, rebranded) |
| Magnolia Heights | Luxury | Supermarket: **Greenleaf Provisions** (organic). Clothing: **Orsatti** boutique. Salon: **Maison Lisse** |
| Blackwater Bayou | Rural poor | Bar: **The Rusty Pirogue** roadhouse |
| The Fringe | Mid / value | Supermarket: **Harvest Square**. Dealer: **Columbia Motors** on the auto row. Petrol: **Redline** |
| East side | Poorest | Pawn: **Second Chance Pawn & Cash**. Liquor: **Proof & Barrel**. Clinic: **Eastside Community Clinic** |
| Brisa Beach | Tourist premium | Hotel: **The Coral Arms** (Deco). Bar: **Neon Tide** nightclub. Clothing: **Sandbar Surf & Swim**. Café: **Ventanita Brisa** (Cuban walk-up) |
| The Shore | Upper-mid | Petrol: **Tidewater**. Bar: **The Mooring** (marina bar) |
| Larkspur | Boutique town | Restaurant: **Vine & Vesper** (wine bar and bistro) |
| Wheaton | Rural | Feed store: **Wheaton Feed & Seed**. Diner: **Sunny Plate** |
| Ridley Crossing | Highway | Petrol: **Big Gator Travel Center** (truck stop). Motel: **Sleep Cheap Motor Inn**. Police: sheriff's office |
| Cypress Bend | Bayou | Bar: **Juke Joint** (no brand) |
| Gator Point | Bayou | Feed/bait: **Gator Point Bait & Fuel** dock |

**Coverage.** All 19 categories appear at least once. Every district has
at least one enterable place, with 3-6 in each city district. 36 places
are named in the table; with the clinic, shop and police repeats that fill
gaps, the set comes to about 42.

**Story fit.**
- The poor districts get the "survival" categories: corner stores,
  chicken, pawn, liquor.
- The rich districts get the "status" categories: boutiques, the organic
  grocer, fine dining.
- Ironwharf holds the illegal-adjacent strip: body shop, gun shop and The
  Pit.
- The Lantern Quarter stays neutral ground, with no gun shop and no pawn.

The full long-term matrix (about 145 places, 17 districts by 19 categories)
is in the research notes. Option C below builds all of it.

---

## 4. Build options with rough cost

One session is about 4-6 hours of build, by the interiors plan's own
estimate. These are estimates [E].

| Option | What | Rough cost | Notes |
|---|---|---|---|
| **A (recommended)** | About 42 anchors, all 19 categories, every district. Each category gets one interior template, dressed per brand (sign, colours, stock, prices). A working shop menu wherever the inventory supports it (food, snacks, fuel can, simple items). The deeper systems (outfits worn, respray, guns, schools) stay in their interiors-plan phases and plug into these rooms. | **about 5 sessions (20-30 h)** | 17 new interior templates (2 exist), placed in the generator for suburbs and towns, plus tests and screenshots |
| B (cheaper) | The 13 must-have categories only, about 20 places: city districts plus Fringe, Brisa and East side. The towns wait. | about 3 sessions (12-18 h) | Does not meet "in every district" |
| C (bigger) | The full matrix: about 145 places, including the rolled extras | about 9-10 sessions (40-55 h) | More tiles carry places, which costs memory and frame time on phones; only worth it after A is played |

**Brands:**

| Option | What | Rough cost |
|---|---|---|
| **B1 (recommended)** | All about 220 names in `game/data/brands.json` (category, tier, price multiplier, two colours, style line, districts). Storefront signs only for the enterable set; the rest go on billboards and NPC outfits. | about 1 session (4-6 h) |
| B2 | Only the about 45 brands with enterable places now; the rest when later cities need them | about half a session |
| Knockout search | Search every name on the USPTO register and the web before it is locked | about 1 session; needed before public release, not before play-testing |

**My pick: A with B1, about 6 sessions in all.** Choose B or B2 to save
about 3 sessions.

---

## 5. Brand roster (fictional)

Every name below is invented for Solvera. Names that started from a real
analogue changed both the name and the look. No name sounds like a famous
mark (section 6). Prices are in-game dollars, set near real US prices so
that tiers read clearly.

### 5.1 Clothing (27 brands)

**Top luxury (2).** These sell in the richest districts only. Their shops
unlock after a story beat, as Didier Sachs did in San Andreas [V].

| Brand | Style | Price cue | Where |
|---|---|---|---|
| Maison Velasque | French quiet luxury: tailoring, cashmere, leather goods, no logos | tee $520, suit $4,800, bag $6,200 | Gilt flagship |
| Orsatti | Italian maximalist: prints, gold hardware, logo-forward | tee $680, jacket $3,900, sneakers $890 | Magnolia village, Gilt |

**Mixed luxury, bridge and contemporary (4).**

| Brand | Style | Price cue | Where |
|---|---|---|---|
| Harlow & Pike | American preppy: polos, chinos, blazers (bridge) | polo $120, blazer $450 | Midtown mall, Gilt |
| Calder Row | Minimal city tailoring (contemporary) | knit $280, blazer $650 | Gilt |
| Sabline | Parisian womenswear-led contemporary | dress $380, coat $720 | Gilt, Brisa |
| Rook & Rivet | Rock and leather: jackets, boots, black denim | jacket $550, boots $320 | Lantern Quarter, Brisa |

**Cheap fast fashion (7, four price points).**

| Price point | Brand | Style | Price cue | Where |
|---|---|---|---|---|
| Premium fast | Runway Nine | Runway copies, new drops every two weeks | tee $29, jeans $60, coat $80 | Midtown mall |
| Premium fast | Plainwell | Tech basics: plain tees, puffers, chinos | tee $15, jeans $40, puffer $70 | Midtown, Shore |
| Mass | Trendo | Cheap trend pieces for the young | tee $9, jeans $35 | Midtown, Fringe |
| Mass | Bayside Basics | Family value: cargo shorts, flag tees, kids' wear | tee $8, jeans $30 | Fringe, Shore |
| Ultra-cheap | ZipDrop | Online-first; a pop-up kiosk and parcel lockers | tee $4, jeans $15 | Kiosks in the mall and at the Fringe |
| Ultra-cheap | Penny Rack | Bare-bones store, piles of basics | tee $4, jeans $17 | Fringe, East side |
| Urban value | Corner Fly | Bright tees, costume chains, track sets | tee $6, jeans $18, chain $12 | Wards, East side |

**Other clothing (14).**

| Tier | Brands | Style and price |
|---|---|---|
| Streetwear (2) | Levee Kings (local skate and street: tee $40, hoodie $85); Halfmoon Club (hype drops, queues on drop days: hoodie $240) | Lantern and Wards edge |
| Athleisure (2) | Stridewell (premium leggings $110); Courtside (mass sportswear: hoodie $60) | Gilt; Midtown and Fringe |
| Western / work (2) | Ridgeline Workwear (duck jacket $140); Tin Star Boots & Western (boots $180) | Fringe, Ridley, Wheaton |
| Department stores (3) | Beaumont & Hale (luxury); Gaspard's (mid, Southern); Holloway's (moderate) | Gilt; Midtown; Fringe |
| Off-price (2) | Markdown Mile; Second Tag ("20-60% off") | Fringe, East side |
| Thrift and resale (2) | Second Line Thrift (vintage, tee $5); Velvet Rope Resale (designer consignment) | Lantern; Magnolia |
| Beach (1) | Sandbar Surf & Swim (boardshorts $45, bikinis) | Brisa, Shore |

Enterable in option A: Maison Velasque, Orsatti, Harlow & Pike, Runway
Nine, Corner Fly, Second Line Thrift and Sandbar Surf & Swim. That gives
seven shops, one per clothing story.

### 5.2 Footwear (11)

| Tier | Brands |
|---|---|
| Athletic giants (2) | Velocity (running tech); Hightop Heritage (basketball and retro) |
| Challengers (2) | Cloudline (comfort running); Northpaw (dad-shoe heritage) |
| Skate / canvas (1) | Grindwell |
| Luxury shoes | Sold inside Maison Velasque and Orsatti |
| Heritage boot (1) | Ironsole Boots |
| Mall sneaker chains (2) | Sneaker Vault; Kicks Locker District |
| Resale boutique (1) | Deadstock Exchange (hype pairs at 1.5-5 times retail) |
| Family discount (1) | Shoe Barn |

### 5.3 Jewellery and watches (15)

| Tier | Brands |
|---|---|
| High jewellery | Aurelien Joaillier |
| Branded luxury (2) | Celeste & Co. (emerald-green box, not blue); Rivoire |
| Accessible / mall (2) | Kingsley Jewelers; Bridal Point |
| Fashion (1) | Charmwell |
| Custom gold and grills (2, local) | Golden Grin Grillz (Wards); Bayou Gold Exchange (East side) |
| Watches, haute (1) | Valtier Genève |
| Watches, luxury (2) | Kronholt; Marinier |
| Watches, entry luxury (1) | Aviateur |
| Watches, fashion (2) | Tikk; Quartzline |
| Authorised dealer (1) | Hour & Carat (Gilt) |

### 5.4 Barbers, salons, beauty and tattoo (14)

| Tier | Brands |
|---|---|
| Value cut chain (2) | Snip City; Clip & Go |
| Premium men's (1) | Gentry Barber Club, with a bar inside |
| Local barbers (2) | Fade Kings (Wards); Mr. Lucien's (Lantern) |
| Salons (3) | Maison Lisse (luxury); Mane Street (mid); Polish Bar (nails) |
| Beauty retail (3) | Lustre (prestige); Glow Depot (masstige); Crown Beauty Supply (hair, wigs, extensions) |
| Tattoo (3) | Flash & Bone (walk-in flash); Inkwell Atelier (custom fine art); Black Pearl Tattoo (Brisa boardwalk) |

### 5.5 Grocery, convenience and liquor (18)

| Tier | Brands |
|---|---|
| Premium organic | Greenleaf Provisions |
| Specialty value | Little Basket |
| Mainstream (2) | Harvest Square; FreshFare |
| Regional "local hero" | Thibodeaux Market (Cajun, local foods; Gulf flavour) |
| Hard discount | Thrifty Cart |
| Supercenters (2) | MegaMart (value); Brightway (premium-leaning) |
| Warehouse club | Pallet Club (membership, fuel island) |
| Dollar stores (2) | Buck Stop; Every Dollar |
| Convenience (3) | Lucky 7 Grocery (existing); Night Owl Mart (existing); Levee Mart (existing) |
| Highway megastore | Big Gator Travel Center (gator mascot, green and orange) |
| Liquor | Proof & Barrel |
| Drive-thru daiquiri (2) | Frozen Levee; Spin Cycle Daiquiris (legal with the lid on and no straw, which is real Louisiana law [V]) |

### 5.6 Restaurants (26)

QSR chains repeat across districts; local places appear once.

| Segment | Brands |
|---|---|
| Burger (3) | Burger Barge (value menu, riverboat theme); Carhop Charlie's (drive-in); Two Hands Burger Co. (better burger) |
| Chicken (3) | Cayenne Coop (spicy Louisiana: the Gulf signature); Granny Pearl's Fried Chicken (heritage); Pump & Cluck (petrol-station chicken) |
| Pizza (2) | Slice Squad ($8 hot and ready); Mama Lucia's (delivery, "better ingredients") |
| Mexican (2) | Taco Tornado (QSR); Rancho Bowl (fast casual) |
| Sandwich (2) | Sub Marine (sub chain); Aunt Fifi's Po-Boys (local) |
| Coffee (3) | Steamline Coffee (national premium); Daybreak Donuts (value); Chicory Corner (local chicory and beignets) |
| Casual dining (3) | Bayou Bill's Grill & Bar; Tuscan Table; Big Sky Steakhouse |
| Diners (2) | Allnighter Waffles (24/7, highway exits); Sunny Plate (family chain) |
| Creole and seafood (3, local) | Marchand's (Creole grand dame); Oyster Row (raw bar); Mud Bug Shack (crawfish) |
| Cuban (1) | Ventanita Brisa (walk-up window, cafecito $2) |
| Fine dining (2) | Prime & Sterling (steakhouse); Seventeen (chef's tasting menu, Gilt) |

### 5.7 Cars and motorcycles (22 makers)

The game's existing car kinds map onto these makers: compact, sedan,
crossover, SUV, pickup, van, EV, luxury, sports, super, muscle, scooter and
motorbike. Each maker gets a country-of-origin design language, which is
how GTA keeps 30 or more makers readable [V].

| Tier | Maker (origin) | Kinds | Design cue |
|---|---|---|---|
| Hypercar | Valtorre (Italy) | super | Wedge, centre-lock wheels |
| Supercar | Monteverra (Italy); Aldridge (UK) | super, sports | Sharp scoops; long-bonnet GT |
| Ultra-luxury | Sovereign (UK) | luxury | Upright grille, two-tone |
| Luxury | Kessler (Germany); Brandt Motorwerke (Germany); Kaito (Japan); Prescott (USA) | luxury, SUV, sedan | Twin-kidney-free grilles; each gets its own lamp signature |
| Near-luxury | Arden (USA); Seiryu (Japan) | sedan, crossover | Chrome-light, soft lines |
| Mainstream | Columbia Motors (USA); Thunderline (USA: trucks and muscle); Hanami (Japan); Sorano (Japan); Hanseong (Korea); Volterra (Europe) | compact to pickup | Plain, honest shapes |
| Budget | Pico | compact | Tall, narrow, steel wheels |
| EV | Ohmic | EV | Smooth panels, light bar |
| Motorcycles (5) | Freeway Iron (US cruiser); Kazeyama and Tenryu (Japan); Rossetti (Italian sport); Nordwand (European adventure) | motorbike, scooter | - |

**Dealers.**
- One exotic showroom in Gilt.
- An auto row at the Fringe with 6-8 mainstream and near-luxury makers;
  Columbia Motors is the enterable one.
- One used-car chain, Carousel Cars.
- 2-3 buy-here-pay-here lots in the East side.

### 5.8 Fuel and car service (16)

| Tier | Brands |
|---|---|
| Fuel majors (4) | Pelican Petroleum; Tidewater; Redline; Sunfield |
| Convenience fuel / megastore | Lucky 7 (fuel version); Big Gator Travel Center |
| Quick lube (2) | Lube Lane; Ten-Minute Oil |
| Tyres (2) | Treadmark Tires; a used-tyre shop (local, no brand) |
| Repair | Brake & Muffler Masters |
| Body shop | Fender Bender Body |
| Tuning / customs (2) | Ironwharf Customs (the mod shop); Low & Slow Customs (lowriders and donks, a Gulf-coast staple) |
| Car wash (2) | Bubble Run Express; Glasswork Detailing |
| Parts | Gearbox Auto Parts |

### 5.9 Gyms (9)

| Tier | Brands |
|---|---|
| Luxury club | Axis Club ($250 a month; Gilt kickboxing) |
| Resort club | Sanctuary Life Club (pools and courts; Magnolia) |
| Mid full-service | Iron Republic Fitness |
| Budget (2) | Ten Buck Gym; FlexBox |
| Boutique (2) | Pulse HIIT; Spoke & Breath (cycling and yoga) |
| Boxing / MMA | The Pit (gritty, already in the game); Southpaw Boxing Club (franchise) |
| Outdoor | The Iron Pen, Brisa (free muscle beach) |

### 5.10 Electronics and phones (13)

| Tier | Brands |
|---|---|
| Big-box | Circuit Planet |
| Phone makers (3) | Plume (premium; a feather logo, not a fruit); Novak (Android premium); Zeta (budget) |
| Carriers (5) | Signal One; Tower Mobile; Wavelink; prepaid Prepaid Pronto and Bolt Talk |
| Gaming store | Save Point Games |
| Repair (2) | Cracked Screen Co. (chain); Unlock Hut (independent, sells burners) |
| PC maker | Kernel Systems (hacking flavour) |

Jules's in-game phone becomes a Plume or a Zeta, depending on cash.

### 5.11 Lighter categories (about 50, mostly signage)

| Category | Brands |
|---|---|
| Banks | Harbor National, Levee Savings, Southern Ledger Bank, Pelican Credit Union, Quill Private Bank |
| Check cashing / pawn | QuickCash Corner, Second Chance Pawn & Cash, TitleNow Loans |
| Pharmacy | Wellspring Pharmacy, MedPoint, Doc Arceneaux's (local) |
| Hardware | Hammer Yard, BuildRight, Corner Hardware, Bargain Tool |
| Furniture | Flatbox (value), Comfort Row (mid), Arbor & Oak (premium), RentRight (rent-to-own) |
| Hotels | The Gilded Heron (luxury), Halcyon House (upper upscale), Courtline Inn (upscale), Stayfare (upper midscale), Wayfarer Lodge (midscale), Sleep Cheap Motor Inn (economy), The Coral Arms and The Flamingo Deco (boutique) |
| Cinemas | MegaScreen 16; Reel & Dine; The Rialto Deco (Brisa) |
| Sports and guns | Field & Fairway Sports; Big Outdoors; Breakwater Arms (range); Bayou Tactical |
| Soda | Fizzco Cola; Red Clay Cola; Dr. Bramble (pepper-style); Zest Lemon-Lime; Bellerive Root Beer (regional) |
| Beer | Featherlight (light lager); Cerveza Marea (Mexican-style); Big Can (cheap tallboy); Levee Brewing and Swamp Gas IPA (local craft) |
| Energy | Voltage; Rhino Rush; Halo Fizz |
| Spirits | Gator Tears Rum; Old Ironwharf Bourbon; Agave Sol Tequila; Belle Rive Cognac |

---

## 6. Naming rules (practical, not legal advice)

1. **No sound-alikes.** Do not use a name one or two letters off a famous
   brand in the same category, or one that rhymes with it. Satire of the
   category ("Pump & Cluck") is safer than a pun on one brand.
2. **Change the look too.** Logo shape, colour pair, mascot and building
   style are protected trade dress. Examples: no red roof, golden arches,
   swoosh-like tick, green siren circle, or blue box for jewellery.
3. **Same-category risk is highest.** Check each name against its own goods
   class.
4. **No tarnishment.** Never tie crime, drugs or sex to a look that points
   at one real brand.
5. **Merch changes the law.** Once a Solvera brand is sold on real goods (a
   tee or a cup), the artistic-expression shield no longer applies (*Jack
   Daniel's v. VIP*, 2023 [V]). Clear any brand that might become merch as
   if it were a real trademark.
6. **Knockout search** each name on the USPTO search, the web and the app
   stores before locking it. Keep a register: name, inspiration, search
   date, result.
7. **No real local businesses.** In a New Orleans-flavoured city, do not
   reuse real restaurant, bar or shop names.

**Existing names to fix.** These are in `game/scripts/places.gd` today and
break rule 7 or come close:

| Name | Problem |
|---|---|
| "Morning Call" | A real New Orleans coffee stand |
| "Ruby's" | A real diner chain |
| "Quik Stop" | A real convenience chain |
| "Blue Plate" | A real New Orleans food brand |
| "Dixie Diner" | Evokes a real beer brand, and the name is loaded |

Rename them in the first build session.

---

## 7. How brands show in play

- **Price.** A brand's tier sets its price multiplier against a base price
  per item. Measured off a mass-market tee:
  - ultra-cheap 0.5x;
  - mass 1x;
  - premium fast fashion 3x;
  - bridge 12x;
  - luxury 60x or more.
- **District.** NPCs wear brands from their district's tier. That reuses
  the clothing models, recolours them, and makes the ladder visible on the
  street.
- **Status.** Luxury outfits raise respect, and luxury cars draw police
  attention in poor districts. This works like San Andreas's clothing
  stats [V].
- **Continuity.** Keep the roster stable and reuse it in later cities, as
  GTA does with Burger Shot and Cluckin' Bell [V].

---

## 8. Decisions taken (each can be overruled)

1. **A over B or C.** A is the smallest set that meets "one for every major
   category ... in every district". C costs about twice as much before
   anyone has played A.
2. **Name every brand now, build storefronts only for enterable ones
   (B1).** The roster is cheap and keeps the world consistent; storefronts
   are the expensive part.
3. **Clothing counts:** 2 top luxury, 4 mixed luxury and 7 cheap. You asked
   for 1-2 / 3-4 / 6-8; these are the top of each range, so the tiers read
   clearly.
4. **No supermarket in the Wards or the East side,** following the real
   food-desert pattern; corner stores and chicken fill the gap.
5. **No gun shop or pawn in the Lantern Quarter,** which stays neutral
   ground.
6. **Respray clears stars when unseen.** This is a proposal from the
   research and is not built.

## 9. Open questions for Sachin

1. Option A, B or C, and B1 or B2?
2. Should luxury clothing unlock by story beat (as in San Andreas) or by
   cash alone?
3. Should the mall be one enterable interior holding several shops, or
   separate storefronts? One interior costs about one extra session but
   looks more real.
4. Do you want any brand to become real merch one day? If so, run the
   knockout search on that brand first.
