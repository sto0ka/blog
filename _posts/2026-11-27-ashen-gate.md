---
title: "Building Ashen Gate — A Dark-Fantasy FPS in Godot 4.7"
date: 2026-11-27 23:30:00 +0800
categories: [GameDev, Projects]
tags: [Godot, Vulkan, GDScript, GLSL, Linux, FPS, Physics, Testing]
comments: true
media_subpath: /assets/img/ashen-gate
image:
  path: preview.png
  alt: Arriving at the Sunken Court overlooking the Gatehouse viaduct in Ashen Gate
---

For the past week I’ve been building **Ashen Gate**, a native Linux dark-fantasy FPS in **Godot 4.7.2 (Forward+ Vulkan)**.

The goal was simple to describe and tricky to pull off: take the movement speed and interconnected gothic hubs of 1990s dark-fantasy shooters, pair them with *Half-Life*-style first-person storytelling where the camera never cuts away, add real rigid-body physics puzzles and elemental combat, and render the whole thing through modern Vulkan lighting, volumetric fog, and sculpted 2.5D sprites.

Act I is now playable from start to finish across three physically connected chapters, backed by ~25,000 lines of GDScript and GLSL and four headless automated test suites. Source is up at [github.com/sto0ka/ashen-gate](https://github.com/sto0ka/ashen-gate).

## The premise and rules

Seven years after helping forge King Vaelor’s resonance locks, exiled Bell-Wright **Caelen** returns along the east road after a desperate writ from **Archivist Seraphina**. The Great Bell has cracked, its lock has inverted, and the Lower Ward is emptying — not into graves, but into iron.

Three design rules shaped everything:

1. **No cutscenes or camera hijacks.** Characters walk, gesture, speak in spatial 3D, and react across grates, speaking tubes, and balconies while you stay in full control.
2. **No floating level portals.** Every chapter transition is a physical threshold — bronze Keep doors at the end of a causeway, a splintered belfry drop shaft landing on an ash heap below, and an archive service stair linking back up.
3. **Treat a 3D FPS like testable software.** Campaign progression, combat/physics, narrative beats, and 3D level geometry all run under headless Godot regression suites.

## Chapter I — The Sunken Court

You spawn at the top of the approach viaduct looking down at the Gatehouse, Torin’s lantern, and the distant Upper City skyline. Inside the Gatehouse, **Archivist Seraphina** watches from behind the observation cell bars while wounded Bell-Watch guard **Brother Torin** slowly loses his nouns every time the cracked bell tolls.

![Archivist Seraphina at the Gatehouse grate](ch1_gatehouse_seraphina.png)
_Archivist Seraphina behind the Gatehouse cell grate. All dialogue, gestures, and world events play out diegetically with zero camera lock._

Past the Gatehouse, the Court opens into a hub with two distinct wings:

- **West Cistern ("The Quay of Bundles")** — Empty shoes at the water’s edge and chalked boarding rows mark where the ward waited for rafts that never came. Unpicking your master’s padlock on the sluice chain floods the cistern and floats real `RigidBody3D` buoyant timber rafts up to the west parapet, leading to King Vaelor’s mural, the **Heart of Vaelor** relic, and the **Briar Arbalest (`2`)**.
- **East Ossuary ("Watchmen’s Rest")** — Beneath a vaulted bone-niche crypt, the torches drop into blackout and **Keeper Avun** — a blind, sound-reactive **Bell-Bound Stalker** — hunts your footsteps and thrown urns through the dark.

![The flooded West Cistern and buoyant timber rafts](ch1_west_cistern.png)
_The flooded West Cistern from the upper parapet: buoyant timber rafts rising on the water surface, vaulted stone ribs overhead, and Seraphina’s archive window in the far wall._

![The vaulted East Ossuary corridor](ch1_east_ossuary.png)
_The vaulted East Ossuary entry corridor descending into the lantern-lit bone-niche crypt._

Back in the **Court of Seals**, you freeze a rushing water channel with **Frost (`RMB`)** to weight twin pressure plates, shoot down a suspended iron counterweight cage, seat the gearbox crank to raise the hydraulic **North Portcullis**, and walk the **Bell Causeway** straight through the Keep’s bronze doors.

![Court of Seals and North Portcullis](ch1_basin_portcullis.png)
_The Court of Seals: volumetric light shafts, rushing water channel, suspended counterweight cage, and a Shrieker guarding the North Portcullis._

## Chapter II — The Bell Tower

Stepping through the Keep doors puts you inside the vaulted **Lower Nave**, lit by cyan and violet stained-glass god-rays under hanging bronze bells and an iron chandelier.

![Lower Nave cathedral hall with stained-glass god-rays](ch2_lower_nave.png)
_The Lower Nave with the Voltaic Tuning Fork (`4`) equipped, stained-glass volumetric god-rays, hanging bells, and the counterweight lift ahead._

Three wards hold the upper Belfry shut, and each wing mixes combat with a physical mechanism:

- **Clockwork Gallery (West)** — Claim the **Voltaic Tuning Fork (`4`)**, freeze a leaking steam pipe to stop a spinning escapement cogwheel, and charge the floor conduit powering the Nave’s **Counterweight Lift** (which jams mid-ride until you shoot the brass pawl).
- **Pendulum Foundry (East)** — Claim the **Cinder Thurible (`3`)** and pump a real `PinJoint3D` bronze clapper with **Telekinetic Repulse (`Q`)** until it smashes through a fissured brick wall.
- **Choir Loft** — Confront **Lord Malcor** across the vigil altar and ring the three **Harmonic Chimes** (*Moon, Crown, Skull*) in sequence — or wake the Choir with a false note.

![Pendulum Foundry balcony with PinJoint3D clapper](ch2_pendulum_foundry.png)
_The Pendulum Foundry balcony: an Acolyte beside the `PinJoint3D` bronze clapper poised in front of the glowing fissured brick wall._

![Choir Loft with Harmonic Chimes and sealed Belfry arch](ch2_choir_loft.png)
_The Choir Loft looking north past the Harmonic Chimes toward the grand staircase and the violet Belfry seal._

Shattering all three wards snaps the overhead ward chains and opens the open-sky **Belfry Sanctum**. Under the colossal Crown Bell, **Lord Malcor (Bell Warden)** fights inside a breakable 3D **Resonant Aegis** dome that you strip with Voltaic shocks, Repulse reflections, or timed parries (`X` / `MMB`). Once he falls, the bell crashes through the floorboards and opens the **Belfry Shaft** down into the furnace below.

![Open-sky Belfry Sanctum boss fight against Lord Malcor](ch2_belfry_boss.png)
_Lord Malcor — Bell Warden in the open-sky Belfry Sanctum, shielded by his 3D Resonant Aegis dome beneath the Crown Bell._

## Chapter III — The Kiln of Ash

You land on an ash heap along the **Foundry Rim**, where Seraphina waits at the rail overlooking the furnace caldera. Far below, the cracked Great Bell sits embedded in basalt between twin molten slag rivers and towering racks of glowing violet **Name-Vessels** — glass-and-iron canisters stamped with the names of everyone drained from the ward.

![Foundry Rim overlooking the Kiln of Ash with Seraphina](ch3_foundry_rim.png)
_Reuniting with Archivist Seraphina on the Foundry Rim overlooking the subterranean furnace._

To forge the **Ashen Key** from a mold marked *"DO NOT POUR — C."* in Caelen’s own hand:

- **Frozen Aqueduct (West)** — Zap the pump conduit with Voltaic lightning to flood the quench trough and freeze falling water spouts into 12-second ice stepping stones.
- **Deep Smeltery (East)** — Launch a heavy name-ash ore cart down iron rails with **Repulse (`Q`)** to smash the slag dam, waking dormant Ash Sentinels and triggering the **Rising Slag Meltdown**.

Tempering the key brings out **The Ladle — Crucible Colossus**, marching down the vessel-lined Crucible Hall. Dropping overhead slag cauldrons onto its shoulders and shocking its armor cracks open its glowing chest core for weakpoint criticals.

![Crucible Hall facing The Ladle — Crucible Colossus](ch3_crucible_colossus.png)
_The Ladle — Crucible Colossus advancing down the Crucible Hall between twin racks of glowing Name-Vessels and the flooded quench trough._

With the Colossus down, three turns of the key part the bronze-and-obsidian leaves of the **Great Ashen Gate**, opening onto the pale-violet abyss of **The Hollow Beyond**.

![The Great Ashen Gate unsealed looking onto The Hollow Beyond](ch3_great_ashen_gate.png)
_The Great Ashen Gate unsealed, framing the pale-violet horizon of The Hollow Beyond where Act II will pick up._

## Under the hood

### Sculpted 2.5D enemies (`shaders/sprite_lit.gdshader` + `scripts/meshes_3d.gd`)

Flat billboard sprites look pasted-on under modern PBR lighting, while pure procedural low-poly rigs tend to look stiff. Instead, hand-painted dark-fantasy character art (`art/*.png`) runs through a custom 187-line GLSL shader (`sprite_lit.gdshader`) that derives distance-field normal and material relief maps for view-dependent parallax, Fresnel rim highlights, emissive armor cracks, and dynamic Vulkan point-light shading.

On top of that, `meshes_3d.gd` drives alternating UV leg-stride animation, recoil, attack wind-ups, parry glints, 3D slash arcs, floor-pinned soft contact shadows, and 3D overlays like Malcor’s swirling Resonant Aegis dome.

### Diegetic story director (`scripts/story_director.gd` + `scripts/narrative.gd`)

The 3,315-line `StoryDirector` drives every chapter’s narrative beats without touching camera control:

- **`await_look` beats** hold a sequence until the player actually glances toward a window breach or crumbling arch, with timeouts so nothing can stall.
- **Spatial NPC choreography** walks Torin, Seraphina, and Malcor along authored routes with limps, gestures, speaking-tube lines, torch blackouts, falling chandeliers, and persistent `story_world` state across save/load reloads.
- **Priority subtitle and bark queues** keep key dialogue legible without colliding with checkpoint toasts or combat banners.

### Combat, physics, and elemental combos (`scripts/combat_systems.gd` + `scripts/physics_sandbox.gd`)

| System | Role |
|---|---|
| Weapons `1–4` | **Runed Cleaver-Axe** (3-hit cleave restoring Blue Mana), **Briar Arbalest** (weakpoint crits), **Cinder Thurible** (burning ground patches), **Voltaic Tuning Fork** (chain lightning across water & clockwork conduits) |
| Elemental combos | **Frost (`RMB`)** + **Fire** triggers **Thermal Shock**; **Voltaic (`4`)** chains through wet zones and strips shields/Aegis |
| Kinetic tools | **Timed Parry (`X` / `MMB`)** stuns attackers and refunds `+25 Blue Mana`; **Telekinetic Grasp (`G`)** lifts urns/blocks/casks or rips tower shields off Executioners; **Repulse (`Q`)** wall-slams foes, reflects orbs, pumps the Foundry pendulum, and launches the Smeltery ore cart |
| Spatial audio | `scripts/audio_3d.gd` synthesizes 77 spatial cues and per-chapter synchronized multi-stem music tracks on background threads at boot |

## Testing a 3D FPS like production software

Procedural 3D level geometry has a nasty failure mode: one `0.3 m` offset between a staircase and a parapet guard leaves an invisible drop crack, or a wall starting at `Y = 0` above a `Y = -0.7` slag bed leaves a glowing horizontal gap all the way around a room.

My first real playtest hit all three classics at once — slipping off into decorative water below the viaduct, spotting wall seams, and realizing falling didn’t kill you. Rather than only patching them by eye, I added fall damage, water cushioning, chapter-specific abyss kill planes, and a permanent **four-suite headless Godot 4.7.2 regression harness** (`1,447` lines under `tests/`):

| Suite | Coverage |
|---|---|
| `tests/smoke.gd` | Full 3-chapter Act I progression, set-pieces, Crucible Colossus, and checkpoint save/load |
| `tests/physics_magic.gd` | Enemy grounding, Axe combos, dual-hand casting, fire patches, Voltaic targets, Warden Aegis breaks, and physics sandbox checks |
| `tests/story_beats.gd` | 9/9 Act I `StoryDirector` acceptance checks across cold open, Cistern, chandelier drop, Malcor vigil, Kiln meltdown, and Act I ending |
| `tests/geometry_audit.gd` | **13,152 water/slag floor samples**, 30,000+ walkable flood-fill cells across initial and progressed states asserting **0 void-drop edges**, 16-way indoor ray sweeps asserting **0 unintended sky leaks**, real `CharacterBody3D` capsule stair round-trips, fall damage, abyss kill-planes, and checkpoint recovery |

The capsule traversal test paid for itself on the very first run: it caught a stair banister overlap in the West Cistern (`cistern_entry_steps` clipping `arbalest_altar_steps`) and a subtle upper-landing lip on the Kiln’s rim stairs that raycasts alone wouldn’t have flagged.

## Running it

*Ashen Gate* runs natively on Linux with Forward+ Vulkan:

```bash
git clone https://github.com/sto0ka/ashen-gate.git
cd ashen-gate
./run.sh
```

And to run all four headless regression suites:

```bash
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/smoke.gd
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/physics_magic.gd
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/story_beats.gd
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/geometry_audit.gd
```

Act I ends with the Great Ashen Gate open and ash drifting in from the Hollow Beyond. With the story director, combat sandbox, volumetric 2.5D pipeline, and geometry audit harness in place, Act II has solid stone to build on.
