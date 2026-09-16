# Pointshop Enhanced — Audit Findings

Full logic pass across 26 Lua source files. September 2026.

---

## Critical

### 1. json/mysql/tmysql providers — GiveItem reads ply.PS_Items instead of stored data

**Files:** `providers/json.lua:50` · `providers/mysql.lua:177` · `providers/tmysql.lua:105`

The pdata and flatfile providers were patched to read-modify-write against *stored* data so that a save landing before the load callback completes cannot wipe the player's inventory. The json, mysql, and tmysql providers still do `table.Copy(ply.PS_Items)`, which is the exact bug the other two were fixed for. If an equip fires before the load callback populates `ply.PS_Items`, the save writes an inventory containing only the one item being saved and destroys everything else the player owns.

```lua
-- All three still do this (mysql shown):
function PROVIDER:GiveItem(ply, item_id, data)
    local tmp = table.Copy(ply.PS_Items)  -- nil or partial = data loss
    tmp[item_id] = data
    ...
end
```

### 2. tmysql.lua SetData — items argument passed unescaped into SQL

**File:** `providers/tmysql.lua:117`

`PROVIDER:SetData` formats `items` directly into the query string without calling `db:Escape()`. Every other write path in the same file does escape. Since `items` is a JSON blob from `util.TableToJSON`, a crafted item name containing a single quote would break out of the string literal. SetData is called from GivePoints/TakePoints and admin paths, so it is reachable.

```lua
-- GiveItem escapes:
db:Escape(util.TableToJSON(tmp))

-- SetData does not:
string.format("... VALUES ( '%s', '%s', '%s' ) ...",
    ply:UniqueID(), points, items)  -- raw items
```

### 3. sv_movement.lua — COREFW:Dbg crashes the net handler on non-COREFW gamemodes

**File:** `sv_movement.lua:161, 177`

The `PS_Movement_Set` handler and the rejection path both call `COREFW:Dbg("MOVE", ...)`. `COREFW` is Bear Hunt's framework table and does not exist on any other gamemode. When a non-owner tries to change movement (the reject path) or an owner successfully changes a value, the handler errors on the `COREFW` index and the entire net.Receive silently dies — the value is never applied, never saved, and no error reaches the owner.

```lua
-- Line 161 (reject path):
COREFW:Dbg("MOVE", "Rejected movement change from non-owner " .. ply:Nick())

-- Line 177 (success path):
COREFW:Dbg("MOVE", ply:Nick() .. " set " .. key .. " = " .. current[key])

-- Fix: guard or replace
if COREFW and COREFW.Dbg then COREFW:Dbg(...) end
-- or just use print() like the rest of the addon
```

---

## High

### 4. mysql/tmysql TakePoints can push balance negative

**Files:** `providers/mysql.lua:146–170` · `providers/tmysql.lua:97`

The pdata provider clamps to `math.max(0, ...)` on every write. The MySQL and tMySQL providers use `points = points - VALUES(points)` in raw SQL with no floor. A player with 50 points buying a 100-point item (possible if two purchases race on a slow connection) ends up at −50 in the database. The in-memory `PS_Points` is validated on read, but the stored value stays negative and survives a rejoin.

### 5. DPointShopPreview DrawOtherModels — nil ITEM crash on removed items

**File:** `vgui/DPointShopPreview.lua:240`

Line 240 indexes `ITEM.Attachment` and `ITEM.Bone` without first checking whether `ITEM` is nil. If a clientside model lingers for an item that was removed from `PS.Items` (hot-reload, addon update mid-session), this errors inside Paint and takes out the entire preview panel each frame.

```lua
-- Current:
local ITEM = PS.Items[item_id]
if not ITEM.Attachment and not ITEM.Bone then ...

-- Fix:
local ITEM = PS.Items[item_id]
if not ITEM then PS.ClientsideModels[ply][item_id] = nil continue end
if not ITEM.Attachment and not ITEM.Bone then ...
```

### 6. cl_player_extension.lua PS_BuyItem — no item-existence check before price calc

**File:** `cl_player_extension.lua:22`

`Player:PS_BuyItem` calls `PS.Config.CalculateBuyPrice(self, PS.Items[item_id])` without checking whether `PS.Items[item_id]` exists. If the client's item table is stale or the id is invalid, `CalculateBuyPrice` tries to read `item.Price` on nil and errors, preventing the buy with no user-facing feedback.

---

## Medium

### 7. Preview handler bypasses ITEM-specific bodygroup/skin bounds

**File:** `ps_backend_unified.lua:405–416`

The `PS_ItemCustomization_PreviewUpdate` handler validates bodygroups as `bgID < 32` and `bgValue < 16`, but the save path in `PS_SanitizeCustomizationData` narrows these to the ITEM's declared `Bodygroups` and `SkinCount`. A client can preview bodygroups/skins the item doesn't declare. The effect is transient (next ApplyAppearance overwrites it), but it lets a player flash bodygroups on themselves that the item explicitly disallows.

### 8. PS_Movement_Get and PS_Theme_Request — no rate limiting

**Files:** `sv_movement.lua:154` · `sv_theme.lua:93`

`PS_Movement_Get` sends four floats + four strings to any client that asks, with no throttle. `PS_Theme_Request` sends the entire theme JSON blob. A malicious client script spamming either in a tight loop generates sustained outbound net traffic. Compare with `PS_Customization_PING`, which does rate-limit.

### 9. Item hook registration captures varargs incorrectly

**File:** `sh_init.lua:629`

Item hooks are registered with `unpack({...})`, which wraps the varargs in a table and unpacks it. This discards any trailing `nil` arguments from hook calls. If an engine hook passes `(arg1, nil, arg3)`, the item callback sees `(arg1)` only. Additionally, `ply.PS_Items[item.ID].Modifiers` is indexed without a nil check on the PS_Items entry.

### 10. Log rotation reads the entire 8 MB file synchronously

**File:** `sh_init.lua:48–54`

When the debug log exceeds `LogMaxBytes` (8 MB), `PS:LogFlush` reads the full file into memory, writes it back as `.old`, then truncates and appends the new buffer. That is a synchronous 8 MB read + 8 MB write inside the game tick. A simpler rotation — just truncate and start fresh, or write sequentially named files — would avoid the copy entirely.

### 11. flatfile.lua and json.lua are exact duplicates

**Files:** `providers/flatfile.lua` · `providers/json.lua`

These two files are byte-for-byte identical (same format, same paths, same logic), except json.lua still has the unfixed `ply.PS_Items` bug in GiveItem/TakeItem. One should redirect to the other, or one should be removed.

---

## Low

### 12. sh_config.lua defines PS_GetUsergroup behind a guard that never fires

**Files:** `sh_config.lua:5` · `sh_player_extension.lua:5`

The metatable method is defined with `if not meta.PS_GetUsergroup then` in sh_config.lua, but sh_player_extension.lua (included immediately after by sh_init.lua) unconditionally defines the real version. The config fallback is always overwritten and never runs.

### 13. mysql.lua ships with hardcoded root / empty-password defaults

**File:** `providers/mysql.lua:33–37`

The credentials at the top are `root` / `''` / `localhost`. A runtime warning on startup when the password is empty would be harder to miss than the comment.

### 14. PS.Config.Debug is shipped as true

**File:** `sh_config.lua:13`

Every server running this addon out of the box is writing debug dumps to `data/bear_debug/`, hooking the global `print` function, and flushing to disk every 2 seconds. This should default to `false`.

### 15. sh_accessory_base.lua type-checks with tostring(type())

**File:** `sh_accessory_base.lua:125, 139`

Lines check `tostring(type(off)) == "Vector"` and `tostring(type(aang)) == "Angle"`. `type()` already returns a string — the `tostring()` is redundant. The standard GMod pattern is `isvector(off)` / `isangle(aang)`.

### 16. HoverModel branch in DPointShopPreview — no nil guard on ITEM

**File:** `vgui/DPointShopPreview.lua:272–275`

`PS.HoverModel` is set then `ITEM.NoPreview` is read with no nil check. If `PS.HoverModel` points to an id that doesn't exist in `PS.Items`, the preview panel errors each frame.

---

---

# UI / VGUI Audit — September 2026

Deep pass across all 12 UI/VGUI files after the facelift. Covers panel lifecycle, rendering correctness, hook cleanup, layout, and the theme/framework layers.

**Files audited:** `cl_ui.lua`, `cl_framework.lua`, `cl_theme.lua`, `cl_theme_crimson.lua`, `cl_init.lua`, `DPointShopMenu.lua`, `DPointShopItem.lua`, `DPointShopInspector.lua`, `DPointShopItemCustomization.lua`, `DPointShopAdmin.lua`, `DPointShopTheme.lua`, `DPointShopLoadouts.lua`, `DPointShopGivePoints.lua`, `DPointShopAuthModule.lua`, `DPointShopOwnerDefaults.lua`, `DPointShopFrameworkTest.lua`, `DPointShopPreview.lua`

---

## High

### UI-1. PSOwnerDefaultsPanel — Discard button bypasses OnClose, leaking hooks and preview models

**File:** `vgui/DPointShopOwnerDefaults.lua:268–270`

The Discard button calls `self:RestoreOriginal()` then `self:Remove()`. `Remove()` does not call `OnClose()` — it triggers `OnRemove()`, which this panel does not define. All cleanup lives in `OnClose()` (lines 355–366): removing the `ShouldDrawLocalPlayer` hook, stopping the shared orbit camera, and removing the preview clientside model.

Clicking Discard leaks a permanent `ShouldDrawLocalPlayer` hook that forces the local player to always render in third person, and leaks the clientside model entity.

The Close button (the DFrame X) works correctly because `DFrame:Close()` calls `OnClose()` before `Remove()`.

```lua
-- Current (line 268):
discardBtn.DoClick = function()
    self:RestoreOriginal()
    self:Remove()       -- OnClose never fires
end

-- Fix: call Close() instead of Remove(), or move cleanup to OnRemove:
discardBtn.DoClick = function()
    self:RestoreOriginal()
    self:Close()        -- fires OnClose → cleanup → Remove
end
```

### UI-2. DPointShopPreview — non-outfit accessories draw without per-accessory color modulation

**File:** `vgui/DPointShopPreview.lua:236–268`

The outfit code path uses `DrawAccessory()` (line 171), which correctly reads each accessory's `model:GetColor()` and calls `render.SetColorModulation()` per-accessory, then resets it (lines 205–213). The comment on line 200 explicitly explains the bug: DModelPanel sets render modulation once for the whole 3D block from `colColor`, so an accessory colored through `SetColor` (which is every non-proxy item) draws in the *panel's* color rather than its own.

The legacy non-outfit path at lines 236–268 — the one that runs in the normal shop and customization panel — does not apply this fix. It calls `model:DrawModel()` directly after `ModifyClientsideModel`, so every accessory using `SetColor` (most of them) renders with the panel's base color instead of its own.

```lua
-- After line 267, add color modulation like DrawAccessory does:
local c = model:GetColor()
render.SetColorModulation(c.r / 255, c.g / 255, c.b / 255)

model:DrawModel()

local base = self.colColor
render.SetColorModulation(base.r / 255, base.g / 255, base.b / 255)
```

Or better: refactor lines 236–268 to call `DrawAccessory()` the same way the outfit path does, eliminating the duplicated attachment/bone logic entirely.

---

## Medium

### UI-3. DPointShopAdmin — column header offsets hardcode gap = 8

**File:** `vgui/DPointShopAdmin.lua:167, 217–225`

The header row draws "Actions" at `w - 288`. The action buttons are laid out from the right with `(at + 1) * (btnW + gap)` where `gap = PS.Theme.Metrics.Gap`. Three buttons × (88 + 8) = 288 — the header aligns only when gap is exactly 8. If a theme preset or resolution scaling changes `Metrics.Gap`, the buttons drift away from their column header.

Either derive the header offset from `Metrics.Gap` the same way the buttons do, or derive the buttons from the header's fixed offsets.

### UI-4. DPointShopPreview — non-outfit DrawOtherModels duplicates DrawAccessory inline

**File:** `vgui/DPointShopPreview.lua:236–268 vs 171–213`

Lines 236–268 manually repeat the same attachment lookup → bone fallback → position → draw sequence that `DrawAccessory` (lines 171–213) already does, minus the color modulation fix and with the nil-ITEM crash (existing finding #5). The outfit path calls `DrawAccessory`; the non-outfit path does not. Refactoring to share the method would fix UI-2 and the nil-ITEM crash in one change:

```lua
-- Replace lines 236-268 with:
if PS.ClientsideModels[ply] then
    for item_id, model in pairs(PS.ClientsideModels[ply]) do
        local ITEM = PS.Items[item_id]
        if not ITEM then PS.ClientsideModels[ply][item_id] = nil continue end
        self:DrawAccessory(ITEM, model)  -- uses DrawAccessory's existing nil-safe, color-aware path
    end
end
```

### UI-5. DPointShopGivePoints — slider max snapshots points at open, no live update

**File:** `vgui/DPointShopGivePoints.lua:43`

`max = LocalPlayer():PS_GetPoints()` is set once in Init. If the player earns or spends points while the dialog is open, the slider's range is stale. The validation in `checkDisabled` (line 71) does re-read `PS_GetPoints()` on every state change, so submitting more than you have is blocked — the visual range is just misleading.

Low risk because the server validates, but a Think that updates the slider max would remove the visual lie.

### UI-6. DPointShopOwnerDefaults — Color() allocations per-frame in Paint functions

**File:** `vgui/DPointShopOwnerDefaults.lua:256–298, 372–381`

Every Paint function on the Save, Discard, Clear buttons and the panel body creates fresh `Color()` tables each frame. The panel is deliberately unthemed (comment on line 5 explains why), so these can't use PS.Theme tokens, but they can be hoisted to file-scope locals:

```lua
-- At file scope:
local COL_BODY   = Color(28, 28, 32, 255)
local COL_BORDER = Color(180, 140, 30, 120)
-- etc.
```

Not a correctness bug, but unnecessary GC pressure on a panel that stays open while positioning accessories.

---

## Low

### UI-7. Test panels ship with console commands in production

**Files:** `vgui/DPointShopFrameworkTest.lua:140` · `vgui/DPointShopAuthModule.lua:133`

Both register `concommand.Add` for `ps_framework_test` and `ps_auth_test`. These are proof-of-concept panels with mock data and `print()` callbacks. Any player can open them. They don't do anything harmful, but they're dead weight in production and visible to anyone poking around in the console.

Gate them behind a debug flag or remove them from the include list.

### UI-8. DPointShopTheme — preset set() walks all world panel children

**File:** `vgui/DPointShopTheme.lua:225–229`

When the preset dropdown fires `set()`, it locates itself by iterating `vgui.GetWorldPanel():GetChildren()` looking for `ClassName == "DPointShopTheme"`. This is O(n) over every panel in the game. It only runs on a click, not per-frame, so it's not a performance problem — but passing `self` into the closure or storing a reference would be cleaner and avoid the walk entirely.

---

## Architecture Notes (UI)

- **Facelift is well-executed.** The refactored panels consistently use `PS.UI.SetupFrame`, `PS.UI.Scroll`, `PS.UI.ContentBox`, themed painters, and the flexbox layout engine. The old hand-drawn chrome, written-down offsets, and duplicated close-button rendering are gone. The new layer is cohesive.
- **Seeding pattern is sound.** Every place a programmatic `SetValue`/`SetColor`/`SetChecked` would trigger a callback uses the `_seeding` flag + `timer.Simple(0)` pattern consistently. No feedback loops found.
- **DFrame.Think chaining is correct.** Admin, Loadouts, and Theme all call `self.BaseClass.Think(self)` before their own logic, preserving drag and resize. Earlier code did not, and the audit comments note that.
- **Scroll panel architecture is correct.** Every scrollable list adds its layout container to the scroll panel's CANVAS via `AddItem()` rather than parenting it directly. The comments document why: a direct parent makes it a sibling of the canvas, `Dock(FILL)` pins it to the viewport, and the list cannot scroll. This was a real bug before the facelift.
- **Provider validation is thorough.** The theme editor's `Validate()` and `ValidRow()` check every field type, pcall providers that error during build, and skip bad rows individually rather than discarding the whole provider. Third-party providers with typos get a console warning and the menu stays up.
- **PSOwnerDefaultsPanel is deliberately unthemed.** The comment block at lines 5–18 explains the design decision. It's the tool you reach for when a theme has gone wrong, so it must not be broken by the theme it exists to fix. The `Color()` literals are intentional.
- **Loadout panel sibling ordering is correct and documented.** `MoveToBack` + `MoveToFront` works because both the shop and the loadout panel are non-popup siblings. The comment block at lines 256–268 explains why parenting cannot work (child clipping), and the slide animation uses offset lerping rather than `MoveTo` because the destination moves when the shop is dragged.
- **Crimson preset is well-structured.** Only entries that differ from the default are listed. Category variants are spelled out rather than left to derive, because the derived offsets were measured against the default's blue hue. The comment explains this.

---

## Summary

| Pass | Critical | High | Medium | Low | Total |
|------|----------|------|--------|-----|-------|
| Backend (first audit) | 3 | 3 | 5 | 5 | 16 |
| UI (this audit) | 0 | 2 | 4 | 2 | 8 |
| **Combined** | **3** | **5** | **9** | **7** | **24** |

---

## Architecture Notes (not bugs)

- **Colour rule is well-enforced.** The dual-channel system (modulation vs. proxy) and the clearing of the unused channel is correct and consistent.
- **Delta protocol is solid.** Bit-packed, bitmask headers, self-test vectors, round-trip comparator. Does not need touching.
- **Gamemode profile system is sound.** Clean separation of "what game" from "what items". Missing profile = unchanged behaviour.
- **Legacy providers are unmaintained copies.** pdata and flatfile got careful patches. mysql, tmysql, and json are PS1-era copies that received none of them. If you support any provider beyond pdata, they need the same treatment. If you don't, mark them unsupported.
- **Theme sync is over-engineered for scale.** SHA256 hash handshake saves a few KB per join on a 30-player server. Clean code, but more machinery than the scale needs.
