-- Books on map (Forever): slash commands (/bom or /books)
local _, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

SLASH_BOOKSONMAP1, SLASH_BOOKSONMAP2 = "/bom", "/books"
SlashCmdList.BOOKSONMAP = function(msg)
  local db = ns.db
  local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "reset" then
    ns.SetAll(false); print(ns.PREFIX .. L["list reset."])
  elseif cmd == "toggle" then
    db.hidden = not db.hidden; ns.Refresh()
    print(ns.PREFIX .. (db.hidden and L["map icons hidden."] or L["map icons shown."]))
  elseif cmd == "minimap" then
    db.hideMinimap = not db.hideMinimap
    ns.UpdateMinimapButton()
  elseif (cmd == "undo" or cmd == "done") and BOOKS[tonumber(rest) or 0] then
    ns.SetDone(BOOKS[tonumber(rest)], cmd == "done")
  elseif cmd == "route" then
    if rest == "list" then ns.PrintRoute()
    elseif rest == "tomtom" then ns.SendRouteToTomTom()
    else ns.ToggleRoute() end
  elseif cmd == "list" then
    print(ns.PREFIX .. L["%d/%d books collected"]:format(ns.CountDone(), #BOOKS))
    for i, b in ipairs(BOOKS) do
      local l = b.locs[1] or { 0, 0, 0, L["location unknown"] }
      print(("%s%2d. %s|r - %s (%.1f, %.1f)"):format(ns.IsDone(b) and "|cff00ff00" or "|cffff8080", i, b.name, l[4], l[2], l[3]))
    end
  elseif cmd == "ids" then
    -- helper to fill Data.lua: prints the itemID of every item in the bags
    ns.ForEachBagItem(function(link) print(link:match("item:(%d+)"), link) end)
  elseif cmd == "" then
    ns.ToggleOptions()
  else
    print(ns.PREFIX .. L["/bom (options) | list | done N | undo N | route [list|tomtom] | toggle | minimap | reset | ids"])
  end
end
