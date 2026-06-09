
# PointShop (Enhanced Edition)

A heavily customized version of the PointShop addon for Garry's Mod, featuring a complete UI overhaul, network optimizations, and enhanced customization capabilities.

**Based on:** [Original PointShop](https://github.com/adamdburton/pointshop) by Adam Burton

**This Version:** Custom offshoot with significant modifications (not a fork)

## Features

### Core Functionality
- **Point-Based Economy** - Players earn and spend points on items
- **Multiple Item Types** - Accessories, player models, trails, weapons, and more
- **Persistent Storage** - PData, MySQL, and JSON provider support
- **Admin Controls** - Set prices, grant items, manage player points
- **Category System** - Organize items into customizable categories

### Enhanced UI (v2.0)
- **Modern Design** - Rounded corners, gradients, and smooth animations
- **Responsive Layout** - Auto-sizing panels with 4-column grid system
- **Item Preview** - 3D inspector with camera controls and rotation
- **Live Customization** - Real-time preview of accessories and playermodel modifications
- **Color Coding** - Intuitive action colors (green=buy/apply, red=sell/close, blue=equip)
- **Styled Dialogs** - Custom confirmation popups matching the theme

### Advanced Customization
- **Accessory Positioning** - Offset (X/Y/Z), rotation, scale, and axis controls
- **Color Customization** - RGB color picker with alpha support for accessories
- **Playermodel Options** - Skin selection, bodygroup controls, and player color
- **Unified Panel** - Single interface for all item customization
- **Preset Support** - Save and load custom configurations per item

### Network Optimization
- **Targeted Updates** - Points and items sent only to owner (92% bandwidth reduction)
- **On-Demand Loading** - Fresh data requested when opening shop
- **Late-Joiner Sync** - Automatic broadcasting of equipped items to new players
- **Efficient Protocols** - Minimal overhead for customization updates

## Quick Start

### Installation


**Note:** This is a modified version with custom enhancements. It may not be compatible with vanilla PointShop items or configurations.


```

### Configuration

Edit `lua/pointshop/sh_config.lua` to customize:

```lua
PS.Config = {
    -- Currency name
    PointsName = "points",
    
    -- Starting points for new players
    StartingPoints = 100,
    
    -- Points earned per second
    PointsPerKill = 10,
    PointsPerDeath = 0,
    
    -- Data provider (pdata, mysql, json, flatfile, tmysql)
    DataProvider = "pdata",
    
    -- Sell price multiplier
    SellMultiplier = 0.75,
}
```

### Adding Items

Create items in `lua/pointshop/items/` following the template:

```lua
ITEM.Name = "Example Hat"
ITEM.Price = 500
ITEM.Model = "models/props/de_tides/vending_hat.mdl"
ITEM.Bone = "ValveBiped.Bip01_Head1"
ITEM.TYPE = "accessory" or "playermodel"
ITEM.Bodygroups = {
    ["bodygroup 1"] = { id = 1, values = { 0} },
    ["bodygroup 2"] = { id = 2, values = { 0, 1 } },
    ["bodygroup 3"] = { id = 3, values = { 0, 1, 2} },
    ["bodygroup etc"] = { id = etc, values = { etc } },

} -- This is written for playermodels, it populates the customization panel

for k, v in pairs(BASE) do
    ITEM[k] = v
end
```

## Customization Data Model (Placement Resolution)

Both accessories and playermodels resolve their appearance (placement, skin, color, bodygroups) through **three layers**, highest priority first:

1. **SQL — per-player override.** A saved row in `ps_accessory_customization` / `ps_playermodel_customization`: exactly what this player set for this item.
2. **Item file — designer default.** `ITEM.DefaultModifications` in the item's `.lua`: the intended placement/skin/color shipped with the item.
3. **Hardcoded fallback — code default.** Sane built-in values so an item with no `DefaultModifications` still renders sensibly and nothing crashes.

Resolution order is **SQL → item default → hardcoded**; the first layer with data wins. This is implemented in:

- `PS_GetAccessoryCustomization(ply, model)` — `lua/pointshop/ps_backend_accessory.lua`
- `PS_GetPlayerModelCustomization(ply, itemID)` — `lua/autorun/ps_backend_playermodel.lua`

### Gotcha: a saved row beats the item default

Once a player saves a placement, their SQL row takes priority — so **editing `ITEM.DefaultModifications` later will NOT move the item for players who already customized it.** To get back to defaults:

- **Accessories:** the **Reset Values** button (`ResetSliders()`) restores the item's `DefaultModifications`, falling back to hardcoded defaults; then Apply/Save to persist.
- **Playermodels:** the **Reset** button (`ResetPlayermodel()`) resets skin, bodygroups and color to a clean baseline — skin 0, bodygroups 0, white color (intentionally *not* the item default, which often ships a tinted color); then Apply/Save to persist.
- **Admins:** clear the saved row — e.g. the `ps_clear_items` server console command, or delete the player's row from the relevant customization table.

## API Reference

### Player Functions

#### Points Management
```lua
ply:PS_GetPoints()                    -- Returns player's current points
ply:PS_GivePoints(amount)             -- Adds points to player
ply:PS_TakePoints(amount)             -- Removes points from player
ply:PS_SetPoints(amount)              -- Sets exact point value
ply:PS_HasPoints(amount)              -- Returns true if player has enough points
```

#### Item Management
```lua
ply:PS_GetItems()                     -- Returns table of owned items
ply:PS_HasItem(item_id)              -- Returns true if player owns item
ply:PS_GiveItem(item_id)             -- Grants item to player
ply:PS_TakeItem(item_id)             -- Removes item from player
ply:PS_BuyItem(item_id)              -- Purchase item (deducts points)
ply:PS_SellItem(item_id)             -- Sells item (refunds points)
```

#### Equipment Functions
```lua
ply:PS_EquipItem(item_id)            -- Equips owned item
ply:PS_HolsterItem(item_id)          -- Unequips item
ply:PS_HasItemEquipped(item_id)      -- Returns true if item is equipped
```

#### Network Functions (Server-Side)
```lua
ply:PS_SendPoints()                   -- Sends current points to client
ply:PS_SendItems()                    -- Sends owned items to client
ply:PS_ToggleMenu(show)              -- Opens/closes shop for player
ply:PS_Notify(...)                    -- Sends notification to player
```

### Client Functions

```lua
LocalPlayer():PS_GetPoints()          -- Returns cached points value
LocalPlayer():PS_GetItems()           -- Returns cached items table
PS:ToggleMenu(forceOpen)             -- Opens/closes shop menu
PS:SetHoverItem(item_id)             -- Preview item on hover
PS:RemoveHoverItem()                  -- Clears preview
```

### Configuration Hooks

```lua
-- Custom buy price calculation
PS.Config.CalculateBuyPrice = function(ply, item)
    return item.Price
end

-- Custom sell price calculation
PS.Config.CalculateSellPrice = function(ply, item)
    return math.floor(item.Price * PS.Config.SellMultiplier)
end

-- Custom item sorting
PS.Config.SortItemsBy = "Price"  -- or "Name"
```

## File Structure

```
pointshop/
├── lua/
│   ├── autorun/
│   │   ├── pointshop.lua                      # Main loader
│   │   ├── ps_backend_unified.lua             # Unified customization backend
│   │   ├── ps_backend_playermodel.lua         # Playermodel backend
│   │   ├── ps_client_accessory.lua            # Accessory client handler
│   │   └── server/
│   │       └── ps_accessory_customization_autorun.lua
│   ├── pointshop/
│   │   ├── sh_config.lua                      # Configuration
│   │   ├── sh_init.lua                        # Shared initialization
│   │   ├── cl_init.lua                        # Client initialization
│   │   ├── sv_init.lua                        # Server initialization
│   │   ├── sv_manifest.lua                    # File loading
│   │   ├── sv_player_extension.lua            # Player functions
│   │   ├── ps_backend_accessory.lua           # Accessory server logic
│   │   ├── items/                             # Item definitions
│   │   │   ├── accessories/
│   │   │   ├── playermodels/
│   │   │   ├── trails/
│   │   │   └── ...
│   │   ├── providers/                         # Data storage backends
│   │   │   ├── pdata.lua
│   │   │   ├── mysql.lua
│   │   │   └── json.lua
│   │   └── vgui/                              # UI panels
│   │       ├── DPointShopMenu.lua             # Main shop interface
│   │       ├── DPointShopItem.lua             # Item card display
│   │       ├── DPointShopInspector.lua        # 3D preview panel
│   │       ├── DPointShopItemCustomization.lua # Unified customization
│   │       └── DPointShopCustomPanels.lua     # Custom selector widgets
│   └── vgui/
│       └── DPointShopCustomPanels.lua
└── data/
    └── pointshop_build.txt                    # Build information
```

## Data Storage

### PData (Default)
- Built-in GMod persistence
- Per-player file storage
- No external dependencies

### MySQL
Configure in `sh_config.lua`:
```lua
PS.Config.DataProvider = "mysql"
PS.Config.MysqlHost = "localhost"
PS.Config.MysqlUsername = "root"
PS.Config.MysqlPassword = ""
PS.Config.MysqlDatabase = "pointshop"
PS.Config.MysqlPort = 3306
```

### JSON
- File-based storage in `data/pointshop/`
- Human-readable format
- Easy backup/restore

## Network Traffic

### Optimized Performance
- **SQL Storage**: ~220 KB for 40 players, 30 items
- **Active Server**: ~3.4 MB/hour bandwidth
- **Per Join**: ~1.5 KB data transfer
- **Per Shop Open**: <1 KB (on-demand request)
- **Per Transaction**: ~2.7 KB (vs ~60 KB pre-optimization)

### Bandwidth Savings
- 92% reduction on points/items sync (targeted net.Send)
- Late-joiner sync uses minimal broadcasts (~14 KB)
- Customization updates: ~180 bytes per change

## Development Notes

If modifying this version, follow these conventions:

1. **File Naming**: Follow `ps_backend_*`, `ps_client_*`, `DPointShop*` conventions
2. **Network Optimization**: Use `net.Send(ply)` for private data, not `net.Broadcast()`
3. **UI Consistency**: Match existing gradient/rounded corner design (8px radius, blue accents)
4. **Testing**: Verify with multiple players and data providers (PData, MySQL, JSON)
5. **Backward Compatibility**: Original PointShop item files should still work with minimal modification

## Troubleshooting

### Items Not Loading
- Check `lua/pointshop/items/` folder structure
- Verify item files have proper `ITEM.` syntax
- Check server console for Lua errors

### Points Not Saving
- Confirm data provider is configured correctly
- For MySQL: verify connection credentials
- Check file permissions for PData/JSON

### Customization Not Syncing
- Ensure `ps_backend_accessory.lua` is loaded
- Check network for `PS_Accessory_Customization` messages
- Verify SQL table `ps_accessory_customization` exists (MySQL only)

## Version Information

**Current Version:**  (Enhanced Edition)

This custom version uses its own versioning independent from the original PointShop repository.

- **(Enhanced Edition)** (February 2026): Complete UI overhaul, network optimizations, unified customization system
- **Based on:** Original PointShop codebase by Adam Burton

For the original PointShop versioning and releases, see: [https://github.com/adamdburton/pointshop](https://github.com/adamdburton/pointshop)

## Credits & Attribution

### Original PointShop
**Adam Burton** (Original Creator)
+ [http://burt0n.net](http://burt0n.net/)
+ [https://github.com/adamdburton](https://github.com/adamdburton)
+ [Original Repository](https://github.com/adamdburton/pointshop)

**Matt Stevens** (Original Maintainer)
+ [https://github.com/HandsomeMatt](https://github.com/HandsomeMatt)

### This Enhanced Version
This is a custom offshoot featuring:
- Complete UI redesign with modern styling
- Network protocol optimizations
- Unified customization system
- Enhanced preview and inspection tools
- Performance improvements

**Note:** This version is not affiliated with or maintained by the original authors.

## What's Different? 

This custom version includes extensive modifications from the original PointShop:

### Visual Overhaul
- Modern gradient-based interface with rounded corners (8px radius)
- Consistent blue accent color scheme (60, 120, 180 RGB)
- Smooth 60fps hover animations and transitions using Lerp()
- Custom styled confirmation dialogs replacing default Derma popups
- Dynamic panel sizing based on content
- Text shadows and gradient overlays for improved readability

### Functional Improvements
- Unified customization panel for all item types (accessories + playermodels)
- Real-time preview system with camera controls (rotation, height, zoom)
- On-demand data refresh when opening shop (eliminates race conditions)
- Late-joiner sync for equipped item visibility

### Network Optimization
- 92% bandwidth reduction on item synchronization
- Changed PS_SendPoints() and PS_SendItems() to use net.Send(self) instead of broadcast
- Targeted updates reduce server traffic from ~60 KB to ~2.7 KB per transaction

### Code Organization
- Renamed files following consistent convention: `ps_backend_*`, `ps_client_*`, `DPointShop*`
- Removed 4 obsolete/duplicate files
- Cleaned up redundant customization systems

## License

Based on PointShop, originally created by Adam Burton.

**Original PointShop:** Copyright 2014-2018 Adam Burton under [the MIT license](LICENSE)

**This Modified Version:** Maintains MIT license compatibility. Modifications and enhancements created February 2026.
