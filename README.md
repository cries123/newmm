# newmm

An objective-based escape horror game for Roblox (Murder Mystery–inspired, not a clone).

Code is written in this repo with [Rojo](https://rojo.space/) and synced into Roblox Studio.

## What's included

### Phase 1
- **Lobby / intermission** — waits for minimum players, then starts a countdown
- **Role assignment** — Sheriff, Murderers (1–2 based on lobby size), Innocents
- **Round loop** — role reveal → 6-minute round → win screen → repeat
- **Client UI** — timer, role reveal, end-of-round message

### Phase 2 — Combat
- **Murderer — Assassinate** — hidden kill ability with cooldown (`Q` or button)
- **Sheriff — Revolver** — limited ammo; shoot murderers to eliminate them (`E` or button)
- **Sheriff — Arrest** — stun a player for 5 seconds instead of shooting (`R` or button)
- **Friendly fire** — sheriff can accidentally shoot innocents
- **Gun drop** — if the sheriff dies, the revolver drops for any innocent to pick up
- **Death / spectator** — eliminated players spectate until the next round (arrow keys to switch)
- **Instant win** — innocents win immediately when all murderers are eliminated

### Phase 3 — Power & Doors
- **Fuel cells** — pick up yellow cells, bring to generator (2 required)
- **Generator** — deposit cells, hold to boot power (10 sec)
- **Power decay** — power turns off after 2 minutes unless maintained
- **Murderer sabotage** — murderers can shut down power at generator
- **Office key** — pick up in office zone
- **Main door** — needs power ON + key to unlock (walk north through door)
- **Objectives UI** — top-left panel shows fuel/power/key status

### Coming next
- **Phase 4** — escape zone and full win conditions

---

## Prerequisites

1. [Roblox Studio](https://create.roblox.com/) installed
2. [Aftman](https://github.com/LPGhatguy/aftman) (recommended) or install Rojo manually

---

## One-time setup

### 1. Install tools

**With Aftman (recommended):**

```bash
# Install aftman: https://github.com/LPGhatguy/aftman#installation
aftman install
```

This installs Rojo `7.4.4` from `aftman.toml`.

**Without Aftman:** download Rojo from [GitHub releases](https://github.com/rojo-rbx/rojo/releases) and add it to your PATH.

### 2. Install the Rojo Studio plugin

In Roblox Studio:

1. Open the [Rojo plugin page](https://create.roblox.com/marketplace/asset/1390826536/Rojo)
2. Click **Install**
3. Or in Studio: **Plugins → Manage Plugins → Search "Rojo"**

### 3. Create your Roblox place

1. Open Roblox Studio → **New** → Baseplate (or Empty)
2. **File → Publish to Roblox** (save it so you have a game to connect to)

---

## Daily workflow (Cursor → Studio)

### Terminal 1 — start Rojo

From this repo root:

```bash
rojo serve
```

You should see something like:

```
Rojo server listening:
  Address: localhost
  Port:    34872
```

Leave this running while you work.

### Roblox Studio — connect

1. Open your place in Studio
2. **Plugins → Rojo → Connect**
3. Click **Connect** in the dialog (default `localhost:34872`)

Studio now mirrors this repo. Edits in Cursor appear in Studio when you save files.

### Edit code in Cursor

| File | Becomes in Studio |
|------|-------------------|
| `src/server/*.server.lua` | `ServerScriptService.Server` → Script |
| `src/client/*.client.lua` | `StarterPlayer.StarterPlayerScripts.Client` → LocalScript |
| `src/shared/*.lua` | `ReplicatedStorage.Shared` → ModuleScript |

**Naming rules:**

- `Something.server.lua` → server Script
- `Something.client.lua` → client LocalScript
- `Something.lua` → ModuleScript

---

## Project structure

```
newmm/
├── default.project.json   # Maps folders → Roblox services
├── aftman.toml            # Pins Rojo version
├── src/
│   ├── server/
│   │   ├── GameManager.server.lua    # Server entry point
│   │   ├── CombatService.lua         # Combat logic (kill, shoot, arrest)
│   │   └── MapBuilder.lua            # Auto-generates the facility map
│   ├── client/
│   │   ├── ClientUI.client.lua       # Timer + role UI
│   │   ├── CombatClient.client.lua   # Ability buttons + keybinds
│   │   └── SpectatorClient.client.lua
│   └── shared/
│       ├── GameConfig.lua              # Tunable constants
│       ├── Remotes.lua                 # RemoteEvent setup
│       ├── RoleManager.lua             # Role assignment
│       ├── RoundManager.lua            # Round state machine
│       └── PlayerUtils.lua             # Alive/stun helpers
```

---

## Testing

1. Run `rojo serve` and connect Studio
2. In Studio: **Test → Start** (or F5)
3. For multiplayer testing: **Test → Clients and Servers** → add 2–3 players
4. You need **4+ players** (or fake clients) for rounds to start — edit `MinPlayers` in `GameConfig.lua` to `1` for solo testing

### Phase 2 controls

| Role | Action | Key |
|------|--------|-----|
| Murderer | Assassinate (melee, in front of you) | `Q` |
| Sheriff / gun holder | Shoot | `E` |
| Sheriff only | Arrest (5s stun) | `R` |
| Dead player | Cycle spectate target | `←` / `→` |

---

## Map (auto-generated)

The map is **built automatically** when you press Play — no manual building required.

`MapBuilder.lua` creates a full test facility under `Workspace.Map`:

| Area | What's there |
|------|----------------|
| **Lobby** | 8 spawn points |
| **Office** | Key on desk |
| **Storage** | FuelCell1 |
| **Cafeteria** | FuelCell2 |
| **Generator Room** | Generator (Phase 3 hooks here) |
| **Back Hall** | FuelCell3, blocked by MainDoor |
| **Hallway** | Connects everything together |

Objectives are tagged with **CollectionService** (`FuelCell`, `Generator`, `Key`, `Door`, `Spawn`) so Phase 3 scripts can find them.

To customize the layout later, edit `src/server/MapBuilder.lua`.

---

## Building a .rbxl place file (optional)

To export a standalone place file without live sync:

```bash
rojo build -o newmm.rbxl
```

Open `newmm.rbxl` in Studio. Re-run after code changes.

---

## Tuning the game

Edit `src/shared/GameConfig.lua`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MinPlayers` | 4 | Players needed to start |
| `IntermissionDuration` | 20 | Lobby countdown (seconds) |
| `RoundDuration` | 360 | Round length (6 min) |
| `MurdererCount` | 2 | Murderers when 8+ players |
| `SheriffAmmo` | 5 | Shots per round |
| `AssassinateCooldown` | 10 | Seconds between kills |
| `ArrestStunDuration` | 5 | Arrest stun length (seconds) |

---

## Next steps

1. **Phase 3** — Fuel cells, generator, power decay, locked doors
2. **Phase 4** — Escape zone and full win table
3. **Phase 5** — Hiding, perks, atmosphere

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Rojo won't connect | Ensure `rojo serve` is running; check firewall isn't blocking the port |
| Scripts don't appear | Reconnect Rojo plugin; confirm `default.project.json` paths match `src/` |
| "Shared not found" | Connect Rojo first so `ReplicatedStorage.Shared` syncs in |
| Round never starts | Need `MinPlayers` (default 4); lower it in `GameConfig` for solo test |
| Changes not syncing | Save the file in Cursor; check Rojo terminal for errors |

---

## Links

- [Rojo docs](https://rojo.space/docs/v7/)
- [Roblox Creator Hub](https://create.roblox.com/docs)
- [Luau type checking](https://create.roblox.com/docs/luau/typechecking)
