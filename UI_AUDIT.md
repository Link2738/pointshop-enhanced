# UI audit

Audit of the UI code as it stands with the theme/preset/layout work uncommitted. Covers
`cl_theme.lua`, `cl_theme_classic.lua`, `cl_ui.lua`, `cl_layout_owner.lua`, `cl_tune.lua`,
`sv_theme.lua`, `sh_init.lua`, `DPointShopMenu.lua`, `DPointShopTheme.lua`, `DPointShopItem.lua`.

**Status: all eight items fixed, plus both pre-existing findings.** What follows is kept as
the record of what was wrong and why, since most of it was a value living in the wrong place
rather than a mistake in a line of code.

Still open, in four panels neither this work nor the audit touched:
`DPointShopOwnerDefaults`, `DPointShopItemCustomization`, `DPointShopCustomPanels`,
`DPointShopInspector` — 9 `Color()` allocations in paint paths and 11 unguarded seeded
controls. `python3 tools/check.py` lists them.

---

## The rule the findings hang off

Every value in the UI is one of three things, and most of what follows is a value sitting in
the wrong one:

**Hardcoded, in source.** What everyone gets before anybody touches anything. Shipped
palettes, the shipped metrics, a look's definition. Changing it means changing the addon, and
that is correct — it is the baseline a server inherits, not a setting.

**Owner dictated, in `data/` on the server.** One person decides it for everyone connected.
Reaches clients by broadcast and on join. Owner-gated on arrival, validated, bounded.

**User dictated, in `data/` on the client.** Each player decides it for themselves. Never
leaves their machine and never reaches anyone else.

Which one a value belongs in is decided by **who it belongs to**, not by how easy it is to
build:

| Value | Belongs to | Where |
|---|---|---|
| Shipped palette, shipped metrics | nobody — it is the baseline | source |
| A look's definition (Classic, Default) | nobody, until an owner edits it | source, then server `data/` |
| House palette, house window size | owner | server `data/` |
| Item defaults, removal queue | owner | server `data/` |
| Icon offsets | owner | server `data/` — currently convars |
| A player's Custom palette | user | client `data/` |
| Remembered panel positions | user | client `data/` |
| Chosen look | user | client `data/` |

Two rows are wrong today. Icon offsets are convars, which is none of the three (item 3).
Owner edits to a look's colours are console output for hand-copying, which is also none of
them (item 8). Both were built as if the value were too small to deserve a home, and both
already had one available.

---

## Needs changing

### 1. Saving a size deletes the house palette — data loss

`sv_theme.lua`, the `PS_Theme_SetDefault` receiver:

```lua
file.Write(DATA_PATH, raw)
defaultJSON = raw
```

It stores whatever arrived, replacing the entire file. The layout panel now sends
`{ metrics = ... }` only, so **saving a window size silently deletes the stored `colours`
section**. This already happened: `theme_default.json` is down to 161 bytes with no colours
in it.

The client was fixed to treat an absent section as "leave that alone". The server — the half
that actually persists it — was not. Both halves need the same rule.

**Change:** merge sections into the stored blob rather than replacing it. Decode what is on
disk, overwrite only the sections present in the incoming message, re-encode, write.

### 2. Two edit paths switch you to Custom without telling the picker

`DPointShopTheme.lua:833` (toggle rows) and `:863` (slider rows) call `PS.Theme.BeginEdit()`
and do not rebuild the list. `BeginEdit` can change the active look to Custom, so the preset
dropdown goes on naming the look you were on. Only the colour mixer at `:907` rebuilds.

The user gets moved to a different look with no indication it happened.

**Change:** all three paths should behave the same — if `BeginEdit()` returns true, rebuild
the list so the picker shows Custom.

### 3. Icon offsets should be owner data, not convars

`cl_ui.lua:69-95` creates client convars (`ps_icon_*`) under `PS.Config.Debug` so the tuning
panel can drive the icon offsets live, and `cl_tune.lua` reads and writes them throughout.
The panel then prints the values for someone to paste back into `UI.Icons` by hand.

Both halves of that are wrong, and the second is the worse one. This addon already has a
settled pattern for owner-authored data, used three times:

| | net message | gate | stored at |
|---|---|---|---|
| `sv_theme.lua` | `PS_Theme_SetDefault` | `PS_IsItemDefaultOwner` | `pointshop/theme_default.json` |
| `ps_item_defaults.lua` | `PS_ItemDefault_Set` | same | `pointshop/item_defaults.json` |
| `ps_removal_queue.lua` | `PS_RemovalQueue_Mark` | same | `pointshop/removal_queue.json` |

All three: owner-gated receiver, validate, write JSON to `data/`, broadcast, re-send on
`PlayerInitialSpawn`. The tuning panel is already owner-only — it registers through
`PS_CollectOwnerTools` — so it is the same kind of thing being edited by the same kind of
person, and it is the one that persists nowhere.

**Change:** icon offsets follow the existing pattern. Panel edits apply live, saving sends
them owner-gated, the server stores them in `data/pointshop/` and broadcasts, clients apply
on join. Convars disappear as a side effect rather than as the point, and so does the
paste-it-back-into-source step.

### 4. `cl_tune.lua:129` has no seeding guard

```lua
sl:SetValue(cv:GetInt())
...
sl.OnValueChanged = function(_, v) ... end
```

`DNumSlider` fires `OnValueChanged` a frame after `SetValue`, once its internal slider
settles — which is after the callback is assigned. Seeding the panel therefore reads as the
user having moved every slider on it.

Harmless *here* (it writes the same value back), but this is the exact mechanism that made
adjusting Classic's size switch the whole look, and it is the last place in code we own that
still has it.

**Change:** the `_seeding` flag pattern used everywhere else — set before `SetValue`, cleared
on `timer.Simple(0, ...)`, checked at the top of the callback.

### 5. Dead code

- `T.IsCustom` — added for the three-look model, never called.
- `T.ClearCustomMetrics` — same.
- `T.IsDerived` — pre-existing, never called.

**Change:** delete, or wire up if there was an intended caller.

### 6. Stale reasoning in `sv_theme.lua`

The comment justifying the 8192-byte cap says "a palette is well under a kilobyte". The real
palette blob was **3182 bytes** — over 3× that. The cap is still large enough, but the number
it is reasoned from is wrong, which is how a cap gets tightened incorrectly later.

**Change:** correct the comment to the measured size, and note that per-look metrics sections
add to it.

### 7. `PS.Theme.ShowAdvanced` is an undeclared field

`DPointShopTheme.lua` assigns `PS.Theme.ShowAdvanced = on` and reads it, but nothing declares
it in `cl_theme.lua`. It works — it is nil until the checkbox is touched, and nil is the right
default — but it is the only field living on the theme table that the theme file has never
heard of.

**Change:** declare it in `cl_theme.lua` beside the other state, or move it onto the panel.

### 8. Author mode is the same mistake as the convars

`ps_look_author` and `ps_look_dump` were built on the reasoning item 3 just discarded: tune a
look live, print the values, paste them into `cl_theme_classic.lua` by hand, restart. The
comment in `T.BeginEdit` even states it as a virtue — "nothing persists".

That is a worse fit than the icon offsets, because a look is *more* obviously owner data. It
is server-wide, it is authored once by the person who runs the server, and it is exactly what
`theme_default.json` already exists to hold. The paste-back step is not a safety property, it
is the absence of persistence dressed up as one.

It also produces a split that will not hold: a look's **size** is already saved properly
through the layout panel and the owner-data path, while a look's **colours** from the same
session have to be copied out of console output into source. Two halves of one look, two
completely different ways of keeping them.

**Change:** authoring a look saves through the same owner-gated path as everything else —
server-stored, broadcast, applied on join. The shipped looks stay in source as the values a
server gets before an owner touches anything, exactly as `T.Metrics` does now; owner edits
layer over them.

Once that exists, `ps_look_dump` is only useful for moving a look *into* source permanently —
turning a tuned look into a new shipped preset — which is a genuine but much narrower job than
the one it currently does. `ps_look_author` stops being needed at all: if edits to a look
persist for the owner, there is nothing to divert them away from.

---

## Pre-existing, not from this work

Listed because they were found, not because they are urgent.

- **An unregistered net message — this one is a live error.** `sh_accessory_base.lua:41` calls
  `net.Start("PS_AccessoryCustomization_Request")` and nothing anywhere calls
  `util.AddNetworkString` for that name. A `net.Start` on an unregistered string errors, so
  this fails every time that path runs. It is the only one of the addon's 27 net messages
  missing a registration.
- **An accidental global.** `items/powerups/supersmall.lua:5` sets `smallsize = 0.8` with no
  `local`, leaking that name into the shared global table for every addon on the server. The
  surrounding code is odd too: team 2 gets a hardcoded `0.8` and everyone else gets
  `smallsize`, which is the same number.

- **`DPointShopOwnerDefaults.lua` allocates in paint** — 9 `Color()` constructions inside
  paint functions (lines 270, 272, 286, 288, 306, 308, 384, 387, 391). Every one is garbage
  per frame per panel, and `cl_theme.lua`'s own header documents this as the thing not to do.
- **Unguarded control seeding** in `DPointShopInspector.lua:345`,
  `DPointShopCustomPanels.lua:94`, `DPointShopItemCustomization.lua` (295, 305, 320, 416, 426)
  and `DPointShopOwnerDefaults.lua` (164, 226-230). Same mechanism as item 4.

---

## Verified clean

Every check below is now in `tools/check.py` and runs over the whole `lua/` tree, not just
the files this work touched. `python3 tools/check.py` reproduces this section and the
findings above; it exits non-zero on any of them.

Two of its checks were wrong on the first run and reported working code as broken — matching
only double-quoted `AddNetworkString` (26 false alarms, because `sv_init.lua` uses single
quotes) and reading a mis-indented table field as a global assignment. Both are fixed. Worth
recording because a checker that cries wolf gets ignored, and then it is worse than nothing.

- **Structure** — nesting depth balanced in every file; no function swallowing the next.
  (Worth noting this check exists because total open/close counts once balanced perfectly on a
  file that would not load: an `end` had migrated rather than vanished.)
- **Member resolution** — every `PS.Theme.*` and `PS.UI.*` reference resolves to a definition.
- **Palette reachability** — all 97 colour tokens are read by something.
- **Metrics reachability** — all 38 read, including the three consumed via `METRIC_BASE`
  inside `T.Scale()` rather than through `T.Metrics`.
- **Paint allocation** — no `Color()` construction in any paint path in code we wrote.
- **Timer safety** — every `timer.Simple` capturing a panel guards with `IsValid`.
- **Client delivery** — every new file is both `include`d and `AddCSLuaFile`'d.
- **Custom slot invariants** — `BeginEdit` persists nothing without an explicit save;
  `SetPreset(CUSTOM)` with no stored palette falls back to empty; the picker only offers
  Custom when one exists; `seededFrom` clears on an explicit pick.
- **Metrics referenced** — every `M.x` / `Metrics.x` read resolves to a defined metric. A
  missing one reads as nil and the next thing done with it is arithmetic, so it crashes a
  layout or paint function rather than being quietly wrong.
- **Widget styles** — every colour a `T.Selectable` or `T.Action` entry references exists. A
  style holding nil hands nil to `surface.SetDrawColor` the first time that state draws.
- **Net messages** — all 27 registered, bar the one listed above.
- **Console commands** — no two share a name; a duplicate silently replaces the first.
- **Hooks** — no two `hook.Add` calls share an event and an identifier, which would also
  silently replace.
- **Globals** — no accidental ones in code we wrote. The `PS_*` globals are the addon's
  deliberate cross-file interface.

---

## Known design edges, deliberate

Not bugs, but they will look like bugs to someone who did not choose them.

- **A house size set on Default applies to Default only.** It is keyed per look. A look that
  specifies its own size overrides it; Default has nothing of its own to override with, so it
  takes the house size. That is the feature working.
- **Picking a look discards nothing, but the Custom slot is single.** Editing while on a
  read-only look seeds Custom from what is on screen. Saving then replaces whatever Custom
  held before, which is why the save warns.
- **Author mode persists nothing.** `ps_look_author` lets edits land on the selected look so
  it can be tuned; `T.Save` still only writes Custom, so the look reverts on reconnect and
  `ps_look_dump` is how a value becomes permanent.
