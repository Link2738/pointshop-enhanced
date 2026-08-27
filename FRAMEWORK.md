# One roof: shop, chat, authority

Direction note. Nothing here is built yet beyond what the "Already in place" section says.

## The idea

Three layers in one addon, written for each other rather than negotiating across addon
boundaries:

- **Shop** — items, categories, points, inventory, the menu.
- **Chat** — replaces betterchat. Channels, tags, formatting.
- **Authority** — who may do what. Groups, permissions, admin tools.

Each can be switched off. The shop must run with the other two disabled, because that is the
common case for a server that just wants a pointshop.

They share what already exists: `PS.Theme`, `PS.UI`, the client settings store
(`pointshop/theme.json` — palette, panel positions, preset), `PS_CollectOwnerTools`, and the
gamemode profiles in `pointshop/gamemodes/`.

## Why one addon rather than three that cooperate

Because "cooperate" is what we have now and it costs something every time. betterchat carries
its own colour system, its own preferences panel and its own settings file, all doing roughly
what the framework already does. ULX carries XGUI. A player who themes the shop finds chat
unchanged. Nothing is shared because nothing was built to be.

Written together, a palette change reaches all three, an owner tool registers once, and a
panel opens where the player last dragged it regardless of which layer owns it.

## Points belong to the shop

Not a core service. If the shop is disabled, points go with it. Nothing in chat or authority
should grow a dependency on `PS_GetPoints`.

## The owner gate

The one real cross-layer dependency, because owner-only features exist in the core: the owner
button in the shop header, the movement panel, the UI tuning panel, and the server-default
palette.

**Decision: the authority layer answers it when present; `ply:IsSuperAdmin()` when it is
not.**

```lua
function PS.IsOwner(ply)
    if not IsValid(ply) then return false end
    if PS.Authority and PS.Authority.IsOwner then
        return PS.Authority.IsOwner(ply)
    end
    return ply:IsSuperAdmin()
end
```

The fallback is deliberately loose. Superadmin is widely inherited in ULX and is not the same
as owner — that is exactly why the current `PS_IsItemDefaultOwner` reads the ULX `owner`
group and refuses to fall back to `IsSuperAdmin()`. Accepting it here is a trade: a server
running the shop alone has no group system to ask, and the alternative is that nobody can set
a house palette.

Anything gated this way is presentation and server-wide defaults. Nothing that grants points
or items should ever use it.

`PS_IsItemDefaultOwner` becomes a thin wrapper over `PS.IsOwner` so existing call sites keep
working.

## Disabling a layer

A layer being off means its files do not load, not that they load and hide. Same rule the
gamemode profiles already follow for categories: an item that does not exist cannot be bought
by accident.

Every cross-layer reference must therefore be guarded, and the guard must be a real fallback
rather than an early return that quietly removes a feature.

## Already in place

- `PS.Theme` — palette, metrics, painters, presets, per-player + server default
- `PS.UI` — Frame, Button, IconButton, Tab, Scroll, List, Confirm, GlyphIcon, RememberPosition
- Client settings store, one file, holding palette, panel positions and preset
- `PS_CollectOwnerTools` — anything registers a panel into the shop header, owner only
- `PS_CollectAppearanceProviders` — anything registers rows into the appearance menu
- `pointshop/gamemodes/<name>.lua` — per-gamemode behaviour, missing file changes nothing
- Owner gate, currently ULX `owner` via `PS_IsItemDefaultOwner`

## The authority layer replaces ULX, bans included

**Decided.** Not a wrapper over ULib, not ULib kept underneath for the hard parts. The point
of one roof is owning every backend piece, and a dependency nobody on the server can read is
worth less than one we wrote.

The counter-argument was that ULib's ban handling represents years of accumulated edge cases
worth inheriting. An audit says otherwise, and the audit took minutes.

### What the ban audit found

`ulib/lua/ulib/server/bans.lua` is 316 lines, roughly a third comments and a migration path
from a pre-2.7 text file. The whole system:

- One SQLite table, `ulib_bans`, steamid64 as INTEGER primary key
- `ULib.bans` held in memory, refilled from the table on `Initialize`
- `hook.Add("CheckPassword", ..., HOOK_LOW)` returning `false, message` to refuse a connect
- `ULib.addBan` kicks the player, then *also* fires `kickid` at the console in case they are
  mid-join, then `REPLACE INTO` the table
- `ULib.unban` fires `removeid` + `writeid` to clear the engine's own banlist, then deletes
  the row

**The check has no expiry.** `checkBan` (bans.lua:52) looks up the steamid and refuses the
connection if a row exists. It never compares `unban` against `os.time()`. A ban row is a ban,
full stop.

**Expiry lives in the admin GUI.** `ulx/lua/ulx/xgui/server/sv_bans.lua:259` runs a poll every
3600 seconds; for each ban whose `unban` falls inside the next hour it creates a one-shot
timer that calls `ULib.unban`. That module also monkey-patches `ULib.unban` to tear its own
timer down.

So the authoritative gate does not know bans end, and the thing that ends them is a GUI
module on an hourly cycle. Disable XGUI and every temp ban on the server becomes permanent.
That is a layering mistake that survived because nobody read it, not a hard-won edge case.

### What ours must get right

Taken from the audit, so the replacement is not a reimplementation of the same shape:

- **Expiry belongs in the check.** `IsBanned(steamid)` compares against `os.time()` and
  returns false for an elapsed ban. A sweep that deletes stale rows is housekeeping, never
  the mechanism.
- **The gate is server-side and works with the UI absent.** No admin panel is load-bearing.
- **Refuse at `CheckPassword`,** which runs before the player entity exists — the kick path
  is a fallback for someone already in, not the primary.
- **Store steamid64,** and pick one representation for the whole layer rather than converting
  at every boundary the way ULib does.
- **Persist synchronously on write.** A ban must survive a crash one second later.
- **Keep the engine banlist out of it,** or own it deliberately. ULib writes to both and the
  two can disagree.

### Migration

Reading `ulib_bans` is a `SELECT` against a table whose schema is six lines above. Import it
once and keep ULib's table untouched so a rollback is just re-enabling the addon.

## Not decided

- Whether the addon gets a new name. "pointshop" stops describing it once the shop is one
  of three layers, and every server owner reading the file tree pays that papercut.
- Whether chat is a port of betterchat onto `PS.UI` or a rewrite.
- Order of work. Chat is lowest-risk (already ours, no upstream). Authority is the larger
  piece and bans are the part that must be right on the first try, since the failure modes
  are a banned player walking in or a legitimate one locked out.
