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

## Not decided

- Whether the addon gets a new name. "pointshop" stops describing it once the shop is one
  of three layers, and every server owner reading the file tree pays that papercut.
- Whether the authority layer replaces ULX or sits beside it. Replacing means bans, groups
  and commands, which is a large piece of work with an existing, battle-tested incumbent.
- Whether chat is a port of betterchat onto `PS.UI` or a rewrite.
