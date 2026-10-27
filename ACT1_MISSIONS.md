# Act 1 missions: Homecoming

Status: **draft**, Oct 26, 2026. Act 1 of the story spine in `WORLD_BIBLE.md`,
set in Bellerive. Mission locations are in `game/data/missions_act1.json`
(stops are map landmarks), drawn on `bellerive_map.svg` and the Solvera Atlas.

**In the demo (Oct 27, 2026)**: missions 1-3 are playable in `game/`
(`game/scripts/missions/`). Small changes from the outline below, made for
the demo map:
- **Homecoming**: the crew's car is a maroon pickup.
- **Empty Rooms**: the clues are searched around the outside of Teo's
  building; interiors come later. Nia hands over the phone at the door.
- **Lantern Lights** is played at night. The Aurum ambush always wrecks the
  car, so Jules has to carjack another and lose a two-star wanted level with
  Marcel aboard.

## Shape of the act

- **13 story missions, about 4-6 hours.** Each one teaches a system in play
  rather than in a menu, so the act doubles as the tutorial.
- **Stakes rise** from a pickpocket chase to a citywide manhunt: street (1-4),
  factions (5-8), the ledger (9-12), the choice (13).
- **Missions with an approach choice** (4, 10, 12) can be played stealth, loud
  or with a vehicle. Every other mission has at least two ways to finish a
  fight or a chase.
- **Choices with consequences**: mission 6 (who gets the car) and mission 13
  (who gets the ledger) change reputation and set the opening of act 2.
- **Gaps between missions** are filled by the side content listed at the end,
  so there's always something nearby to do.

New characters for act 1, added to the cast in `WORLD_BIBLE.md`:
- **Nia Batiste**: leader of High Water, Teo's partner, sharp and stubborn.
- **Celeste Durand**: owns the Blue Lantern jazz club; knows everyone's
  secrets.
- **Pops**: old fixer who runs the Wharfside Courts; information for a price.
- **Simone Kessler**: Victor Hale's fixer; polite, never makes threats twice.
- **Dex**: High Water lieutenant; sold Teo out to Aurum.

## Overview

| # | Mission | Giver | Where | Teaches | Unlocks |
|---|---|---|---|---|---|
| 1 | Homecoming | Story | Union Station → Lantern Quarter → Moreau House | Moving, punching, chases, driving | The map |
| 2 | Empty Rooms | Nia | Moreau House → Teo's Apartment → Floodline Clinic | Phone, clue search | Phone |
| 3 | Lantern Lights | Celeste | Blue Lantern → Precinct → ambush on the main road | Carjacking, wanted level, losing the police | Taxi side job |
| 4 | Wharf Rats | Nia | Warehouse 9 (Ironwharf) | Cover, stealth takedowns | Courier side job |
| 5 | Krewe Business | Mama Odette | Krewe Stilt Hall, Blackwater Bayou | Boats | Airboat, Krewe reputation |
| 6 | Gilded Invitation | Simone (Aurum) | Aurum Tower → High Water garage → Union Station | Reputation, choices | Aurum reputation |
| 7 | Street Business | Nia | Floodline food stand | Street business, turf defence | First business, safehouse, wardrobe |
| 8 | Hoops | Pops | Wharfside Courts | Basketball | Streetball league, boxing |
| 9 | Floodwater | Story | Drowned Streetcar → Old Streetcar Depot | Storms, legends | First half of the ledger |
| 10 | Magnolia | Celeste | Hale Estate (Magnolia Heights) | Disguises, safe cracking | Second half of the ledger |
| 11 | Crescent Bridge | Story | Hale Estate → Crescent Bridge → Bayou | Wanted level 3 | Captain Reyes as a contact |
| 12 | Cargo | Pops | Aurum Cargo Hangar (airport) | Escort | Teo rescued |
| 13 | Two Crowns | Jules's choice | Aurum Tower, Stilt Hall or Union Station | Everything | Act 2 opening for the chosen path |

## Missions

### 1. Homecoming
Jules steps off the train at **Union Station** twelve years after the Great
Storm. Before they're out of the station, a kid on a scooter snatches their
bag. Chase on foot, steal a scooter, and weave through the **Lantern Quarter**
crowds to **Lantern Square**, where the kid's crew decides to fight. Win, take
their car, and drive to **Moreau House** in the Floodline Wards. Nobody's home,
and Teo's room is empty.
- **Hook in the first 10 minutes**: a chase, a fight and a car, with no
  tutorial screens.
- **Ways through**: catch the thief on foot (fast route through alleys) or on
  the scooter (safe route along the streets).

### 2. Empty Rooms
**Nia Batiste** turns up at the door, angry that Jules left twelve years ago.
Teo has been gone four days. At **Teo's Apartment**, search the ransacked
rooms for clues (the phone's camera highlights them), then visit the
**Floodline Clinic**, where a High Water kid was beaten by men asking about
Teo.
- **Unlocks the phone**: contacts, map, messages. Teo's last messages
  mention "the river crates" and "the man in gold".

### 3. Lantern Lights
**Celeste Durand** knew Jules's parents. Her bandleader was arrested on a
made-up charge; pick him up from the **Lantern Quarter Precinct**, where Jules
first meets **Captain Dana Reyes**. On the way back, Aurum security ambushes
the car on the main road. Lose the car, take another, and shake the police.
- **Teaches**: carjacking, the first wanted level, breaking line of sight.
- **Ways through**: outrun them, or hide in the Quarter's alleys on foot.

### 4. Wharf Rats
Teo's phone last connected near **Warehouse 9** in Ironwharf. Get inside,
find out who Teo was working for, and get out.
- **Stealth**: in through the river side, avoid the guards' lights, take
  guards down quietly.
- **Loud**: through the front gate in a fight.
- **Vehicle**: ram the loading gate with a truck from the yard and grab the
  evidence before backup arrives.
- **Finds**: Marrow Krewe crates and Teo's jacket. Teo was running river
  cargo for the Krewe.

### 5. Krewe Business
The Krewe catches Jules leaving the warehouse and takes them to the
**Krewe Stilt Hall** in Blackwater Bayou. **Mama Odette** knew Jules's
parents too, and says Teo stole something from Aurum, not from her. Aurum
boats raid the hall mid-conversation: take an airboat and fight them off in a
chase through the bayou channels.
- **Teaches**: boats. **Unlocks**: the airboat and Marrow Krewe reputation.

### 6. Gilded Invitation
A polite message: **Simone Kessler** invites Jules to **Aurum Tower**. Victor
Hale offers to help find Teo if Jules does one favour: recover a "stolen" car
from a **High Water garage** and bring it to **Union Station**. The car turns
out to be High Water's own.
- **Choice**: deliver it (Aurum reputation up, High Water down, Nia furious)
  or return it to High Water (the opposite, and Aurum starts watching Jules).
- **Teaches**: reputation and mission choices.

### 7. Street Business
High Water needs money and Jules needs a base. Open a **food stand** in the
Floodline Wards, then defend it when Aurum-paid thugs come to burn it down.
- **Unlocks**: the first street business (passive income, occasional raids),
  **Moreau House** as a safehouse (save point, garage, wardrobe).
- **Teaches**: turf defence, which repeats later as a side activity.

### 8. Hoops
**Pops** runs the **Wharfside Courts** and knows where Teo was sleeping. He
trades information for a win: a 3v3 streetball game against Dex's team.
- **Teaches**: basketball. **Unlocks**: the weekly streetball league, and
  boxing at **The Pit** in Ironwharf as a side activity.
- **Clue**: Teo talked about "the streetcar that comes back on flood nights".

### 9. Floodwater
A storm floods the Floodline Wards. On the flooded streets, a lit
streetcar glides past: **the Drowned Streetcar** from the legend. Follow it
through the rising water to the **Old Streetcar Depot**, Teo's hideout. Inside:
half of Teo's ledger, and a recorded message. The other half is in Victor
Hale's safe.
- **Teaches**: storms (weather changes driving and visibility) and how
  legends lead to secrets.

### 10. Magnolia
Celeste can get Jules into Victor Hale's garden party at the **Hale Estate**.
Open the safe and take the second half of the ledger.
- **Stealth**: work the party as a valet, slip upstairs, crack the safe.
- **Loud**: storm the house.
- **Vehicle**: crash a delivery truck through the gate and grab the safe
  whole.
- **Reputation**: Aurum drops sharply whichever way it's done.

### 11. Crescent Bridge
Aurum security and every patrol car in the city chase Jules from Magnolia
Heights to the **Crescent Bridge** and into the bayou. First taste of wanted
level 3: roadblocks on the bridge. Captain Reyes corners Jules at the far end
of the bridge, reads one page of the ledger and lets them go.
- **Ways through**: through the roadblock, or off the bridge into the river
  and away by boat.
- **Unlocks**: Captain Reyes as a phone contact.

### 12. Cargo
Pops found Teo: Aurum is holding him at its **Cargo Hangar** at Bellerive
International, ready to fly him out tonight. Dex sold him out.
- **Stealth**: in with the night cargo trucks.
- **Loud**: through the fence with Nia's crew.
- **Vehicle**: block the runway with a fuel truck so the plane can't leave.
- **Then**: escort the injured Teo back to Moreau House while Aurum gives
  chase.

### 13. Two Crowns
Teo is safe, and Jules holds the whole ledger: proof that Aurum bribed
half the city, Reyes's superiors included. Both Mama Odette and Victor Hale
want it. At Moreau House, Jules chooses:
- **Side with the Krewe: Tower Run**. Hand the ledger to Mama Odette and help
  the Krewe raid **Aurum Tower**'s garage vault.
- **Side with Aurum: Stilt Hall**. Sell the ledger to Victor Hale and lead
  Aurum's raid on the **Krewe Stilt Hall**.
- **Play both: Union Station**. Promise the ledger to both, arrange the swap
  at **Union Station**, and let them destroy each other while High Water walks
  away with the money.

Each branch is its own finale mission and sets act 2's opening in Concordia and the Keys
(see `WORLD_BIBLE.md`, story spine; Porto Brisa, the act's old setting, is now expansion 1).

## Side content available during act 1

| Unlocked by | Activity | Where |
|---|---|---|
| Mission 3 | Taxi side job | Anywhere |
| Mission 4 | Courier deliveries | Anywhere |
| Mission 7 | Street business raids and supply runs; turf defence | Floodline Wards |
| Mission 8 | Streetball league (weekly) | Wharfside Courts |
| Mission 8 | Boxing ladder | The Pit, Ironwharf |
| From the start | Street races, random events, collectibles (hidden packages, graffiti tags, landmark photos) | Citywide |
| From the start | Hints of other legends (radio, graffiti, old photos): the Sentinel's Light, the Silver Train | Citywide |
