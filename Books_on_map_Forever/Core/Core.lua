-- Books on map (Forever): constants, saved state, collection API, startup
local ADDON, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

ns.ICON = "Interface\\Icons\\INV_Misc_Book_09"
ns.ADDON_ICON = "Interface\\AddOns\\Books_on_map_Forever\\adds\\icon"
ns.PREFIX = "|cff33ff99Books on map|r: "

-- display names/places in the chosen language (once, at load)
local function localizeBooks()
  if not ns.IS_FRENCH then return end
  for _, b in ipairs(BOOKS) do
    b.name = b.frName or b.name
    for _, loc in ipairs(b.locs) do loc[4] = loc[5] or loc[4] end
  end
end

-- Collection state -------------------------------------------------------
function ns.IsDone(b) return ns.db.collected[b.key] end

function ns.CountDone()
  local n = 0
  for _, b in ipairs(BOOKS) do if ns.IsDone(b) then n = n + 1 end end
  return n
end

function ns.Refresh()
  if not ns.db then return end
  ns.RefreshMap()
  ns.RefreshOptions()
  ns.RefreshRoute()
end

function ns.SetDone(b, value, silent)
  if (ns.db.collected[b.key] or false) == value then return end
  ns.db.collected[b.key] = value or nil
  if not silent then
    print(ns.PREFIX .. ("%s %s (%d/%d)"):format(b.name,
      value and L["|cff00ff00collected|r"] or L["|cffff5555shown on map again|r"], ns.CountDone(), #BOOKS))
  end
  ns.Refresh()
end

function ns.SetAll(collected)
  for _, b in ipairs(BOOKS) do ns.db.collected[b.key] = collected or nil end
  ns.Refresh()
end

-- Startup ----------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    BooksOnMapForeverDB = BooksOnMapForeverDB or {}
    ns.db = BooksOnMapForeverDB
    ns.db.collected = ns.db.collected or {}
    ns.ApplyLanguage(ns.db.lang)
    localizeBooks()
  elseif event == "PLAYER_LOGIN" then
    ns.InitMap()
    ns.InitMinimapButton()
    ns.InitDetection()
    ns.InitRoute()
  end
end)
