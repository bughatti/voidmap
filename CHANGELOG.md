# VoidMap Changelog

## 0.2.5

- **Fixed: right-clicking another quest in VoidQuest now moves the map too.** With the map already open, the quest's page changed but the map stayed on the first quest's zone.

## 0.2.4

- **Fixed: box borders missing a side.** Depending on where a window sat on screen, its left, right or bottom line could vanish. Borders are now exactly one screen pixel and can't round away.

## 0.2.3

- **Room for plug-ins:** another Void addon can now add a button to VoidMap's title bar and use the side area beside the map. The first one is VoidDungeon (coming soon): dungeon maps, quests, loot and boss tips for WoW Forever, right inside VoidMap. Nothing changes if you don't have it.

## 0.2.2

- **Fixed: abandoning a quest from its page.** The page now goes back to your quest list once the quest is gone (it used to sit on "no longer in your log"), and opening another quest right after works without closing the map. Abandon also warns about the quest's items, like the game's own button.

## 0.2.1

- **Fixed:** a flood of Lua errors from trail recording during fights, when the game hides your movement speed. VoidMap now pauses recording until it can read it again.

## 0.2.0

The map gets a window of its own.

- **New window, same map.** VoidMap now has its own window, title bar, toolbar and footer. Inside it is the full world map with every pin, from Blizzard and from your other addons.
- **World / Continent / Zone navigation** with a menu at each level to pick another map, plus a **Floor** picker on maps with levels.
- **Filter and Pin**: Blizzard's map filters and map-pin button, in VoidMap's toolbar. **Zoom** buttons.
- **Your quests beside the map**, the ones on the map you're looking at first. Hover for objectives (the quest lights up on the map), shift-click to link it, right-click to stop tracking it. Replaces Blizzard's quest log panel. **L** opens the map with the list.
- **Read the whole quest:** click a quest in the list for its objectives, full text and rewards, with Track, Share and Abandon. Ctrl-click tracks it straight away.
- **Fold the quest list away** with the arrow tab on the map's right edge (or the Quests button), like Blizzard's map.
- **Drag the corner to size the window.** The map keeps its shape. **Big / Small** switch.
- **Coordinates** for you and the cursor at the bottom. With TomTom installed, TomTom's map coordinates are hidden because they'd show twice.
- **Trails:** VoidMap records the paths you walk, for VoidGPS's walking routes. Count at the bottom right; you can turn it off in Settings.

## 0.1.0

First version (not released): moved and sized Blizzard's map window.
