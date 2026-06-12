# PointShop Enhanced — Code Review Brief

This document gives the reviewer immediate context so no time is spent reverse-engineering intent.

---

## What This Is

A heavily customised Garry's Mod PointShop addon (Lua, server+client) built for a Bear Hunt community server. It sits on top of the original PointShop by Adam Burton and replaces large portions of the networking, UI, and data layers. The addon is in active development — the 10-commit history represents a clean rewrite from the original, not a long-lived project.

---

## Architecture in One Paragraph

A global `PS` table owns everything. `sh_init.lua` bootstraps shared state and scans `items/*/` directories at load time; `sv_init.lua` registers net handlers and attaches per-message rate limiters; `cl_init.lua` loads VGUI panels. Player state (points, owned items, equipped items, customisations) is stored server-side and synced to the owning client only — not broadcast. Customisation data flows through `ps_backend_unified.lua` which routes to either `ps_backend_accessory.lua` or `ps_backend_playermodel.lua` depending on item type, sanitises the payload, and writes to SQL.

---

## Key Design Decisions to Know Before Reviewing

| Decision | Rationale |
|---|---|
| `net.Send(ply)` everywhere instead of `net.Broadcast()` | 92% bandwidth reduction; original PS was broadcasting full inventories to everyone |
| 3-layer customisation resolution (SQL → `DefaultModifications` → hardcoded) | Items ship with sensible defaults; per-player overrides layer on top without requiring a DB row to exist |
| Playermodel reset goes to clean baseline (skin 0, white, bodygroups 0), ignoring `DefaultModifications` | Items often ship pre-tinted; reset should be neutral, not the tinted default |
| `_example.lua` files skipped by item loader | Prefix `_` signals template-only; the loader explicitly filters these out in `sh_init.lua` |
| Team-gated categories (`CATEGORY.AllowedTeams`) | Prevents players from equipping wrong-team models mid-round by switching teams |
| Rate limiter kick threshold (10 violations) | Hardened in `37564b2` to handle spam/exploit attempts |

---

## Files Most Worth Scrutinising

- **[lua/pointshop/sv_init.lua](lua/pointshop/sv_init.lua)** — all net handlers, rate limiters, payload size guard (`PS_MAX_MODIFY_BITS = 16384`)
- **[lua/autorun/ps_backend_unified.lua](lua/autorun/ps_backend_unified.lua)** — `SanitizeCustomizationData()` is the trust boundary for all incoming customisation payloads
- **[lua/pointshop/sv_player_extension.lua](lua/pointshop/sv_player_extension.lua)** — points arithmetic and item ownership mutations; any logic error here has economy impact
- **[lua/pointshop/sh_init.lua](lua/pointshop/sh_init.lua)** — item loader and `PS:CanEquipForTeam()` team gate
- **[lua/vgui/DPointShopItemCustomization.lua](lua/vgui/DPointShopItemCustomization.lua)** — unified customisation panel; recent refactor replaced `ang` with pitch/roll/yaw system (`ce50054`)
- **[lua/pointshop/vgui/DPointShopInspector.lua](lua/pointshop/vgui/DPointShopInspector.lua)** — clientside model preview with `calcview` hook; check for hook cleanup on panel close

---

## Recent Changes (What's Still Warm)

| Commit | What changed |
|---|---|
| `ce50054` | Replaced single `ang` field with discrete `pitch`/`roll`/`yaw` fields in customisation panel |
| `022e94c` | Playermodel reset now targets clean baseline, not `DefaultModifications` |
| `3e984eb` | Added reset button to playermodel customisation UI |
| `ae8cf8c` | Fixed team-gate bypass: `SetModel` in customisation path now checks `AllowedTeams` |
| `37564b2` | Hardened net handlers: payload size guard, kick after 10 rate violations |

---

## What We're Looking For

- **Correctness** — logic bugs in economy math, item state transitions, team-gate enforcement
- **Security** — anything that survives `SanitizeCustomizationData()` that shouldn't; net handler edge cases; admin permission checks
- **Resource leaks** — VGUI panels that register hooks (`calcview`, `Think`, etc.) without cleaning up on `Remove()`
- **Networking** — any remaining broadcast patterns that should be targeted; unnecessary full-state resyncs
- **Pitch/roll/yaw refactor** — confirm `ce50054` is consistent across send, receive, sanitise, apply, and reset paths
- **General Lua hygiene** — globals leaking from item files, `pairs` vs `ipairs` misuse, missing `IsValid()` guards

## Out of Scope

- Item balance (prices, point costs) — community decision, not a code issue
- Data provider implementations other than PData — MySQL/JSON backends are used in non-default configs only
- UI aesthetic feedback
