-- Books on map (Forever): options window (book list grouped by set)
local ADDON, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

local WIDTH, HEIGHT = 470, 600
local ROW_H, HEADER_H = 34, 26
local GOAL_NECKLACE, GOAL_RING, GOAL_25 = 10, 20, 25

local SETS = {
  { id = 1, label = "Starting set" },
  { id = 35, label = "Level 35 set" },
  { id = 45, label = "Level 45 set" },
  { id = 60, label = "Level 60 set" },
}

local LANGUAGES = {
  { value = "auto", text = "Automatic (game language)" },
  { value = "enUS", text = "English" },
  { value = "frFR", text = "Français" },
}

local frame

local function iconPath(b)
  return "Interface\\Icons\\" .. (b.icon or "INV_Misc_Book_09")
end

function ns.RefreshOptions()
  if not frame or not frame:IsShown() then return end
  local done = ns.CountDone()

  frame.bar:SetValue(math.min(done, GOAL_25))
  frame.barText:SetText(L["%d / %d books"]:format(done, #BOOKS))
  frame.necklace:SetTextColor(done >= GOAL_NECKLACE and 0.1 or 0.6, done >= GOAL_NECKLACE and 1 or 0.6, done >= GOAL_NECKLACE and 0.1 or 0.6)
  frame.ring:SetTextColor(done >= GOAL_RING and 0.1 or 0.6, done >= GOAL_RING and 1 or 0.6, done >= GOAL_RING and 0.1 or 0.6)
  frame.goal25:SetTextColor(done >= GOAL_25 and 0.1 or 0.6, done >= GOAL_25 and 1 or 0.6, done >= GOAL_25 and 0.1 or 0.6)

  frame.showAll:SetChecked(not ns.db.hidden)
  frame.size:SetValue(ns.db.pinSize or ns.DEFAULT_PIN_SIZE)

  for _, h in ipairs(frame.headers) do
    local n, total = 0, 0
    for _, b in ipairs(BOOKS) do
      if b.set == h.set then
        total = total + 1
        if ns.IsDone(b) then n = n + 1 end
      end
    end
    h.count:SetText(("%d / %d"):format(n, total))
  end

  frame.hideDone:SetChecked(ns.db.hideCollected)
  frame.myLevel:SetChecked(ns.db.myLevelOnly)

  -- layout: filtered rows are hidden, the rest stacked under their header
  local level = UnitLevel("player")
  local y = 0
  for _, h in ipairs(frame.headers) do
    local visible = not ns.db.myLevelOnly or h.set <= level
    h:SetShown(visible)
    if visible then
      h:SetPoint("TOPLEFT", 0, -y)
      y = y + HEADER_H + 2
    end
    for _, row in ipairs(frame.rows) do
      if row.book.set == h.set then
        local show = visible and not (ns.db.hideCollected and ns.IsDone(row.book))
        row:SetShown(show)
        if show then
          row:SetPoint("TOPLEFT", 0, -y)
          y = y + ROW_H
        end
      end
    end
    if visible then y = y + 6 end
  end
  frame.content:SetHeight(math.max(y, 1))

  for _, row in ipairs(frame.rows) do
    local isDone = ns.IsDone(row.book)
    row.check:SetChecked(not isDone)
    row.icon:SetDesaturated(isDone)
    row.icon:SetAlpha(isDone and 0.5 or 1)
    if isDone then
      row.name:SetTextColor(0.5, 0.5, 0.5)
      row.done:Show()
    else
      row.name:SetTextColor(1, 0.82, 0)
      row.done:Hide()
    end
  end
end

-- Rows -------------------------------------------------------------------
local function rowTooltip(self)
  local b = self.book
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(b.name, 1, 0.82, 0)
  for _, loc in ipairs(b.locs) do
    GameTooltip:AddLine(("%s (%.1f, %.1f)"):format(loc[4], loc[2], loc[3]), 1, 1, 1, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Click: open the map there"], 0.5, 1, 0.5)
  if TomTom then GameTooltip:AddLine(L["Right-click: TomTom waypoint"], 0.5, 1, 0.5) end
  GameTooltip:Show()
end

local function createRow(parent, b, y, width)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, ROW_H)
  row:SetPoint("TOPLEFT", 0, -y)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.book = b

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(26, 26)
  row.icon:SetPoint("LEFT", 6, 0)
  row.icon:SetTexture(iconPath(b))
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.done = row:CreateTexture(nil, "OVERLAY")
  row.done:SetSize(18, 18)
  row.done:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 5, -4)
  row.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("RIGHT", -4, 0)
  row.check:SetScript("OnClick", function(self) ns.SetDone(b, not self:GetChecked(), true) end)
  row.check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Show on the map"])
    GameTooltip:Show()
  end)
  row.check:SetScript("OnLeave", function() GameTooltip:Hide() end)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
  row.name:SetPoint("RIGHT", row.check, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.name:SetText(b.name)

  local l = b.locs[1]
  row.where = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.where:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
  row.where:SetPoint("RIGHT", row.check, "LEFT", -4, 0)
  row.where:SetJustifyH("LEFT")
  row.where:SetWordWrap(false)
  row.where:SetTextColor(0.65, 0.65, 0.65)
  row.where:SetText(l and ("%s  |cff808080(%.1f, %.1f)|r"):format(l[4], l[2], l[3]) or L["location unknown"])

  row:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if TomTom and l then TomTom:AddWaypoint(l[1], l[2] / 100, l[3] / 100, { title = b.name }) end
    elseif l then
      if not WorldMapFrame:IsShown() then ToggleWorldMap() end
      WorldMapFrame:SetMapID(l[1])
    end
  end)
  row:SetScript("OnEnter", rowTooltip)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

local function createHeader(parent, set, y, width)
  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, HEADER_H)
  h:SetPoint("TOPLEFT", 0, -y)
  h.set = set.id

  local bg = h:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.12)

  local line = h:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetColorTexture(1, 0.82, 0, 0.5)

  h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h.label:SetPoint("LEFT", 8, 0)
  h.label:SetText(L[set.label])

  h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h.count:SetPoint("RIGHT", -10, 0)
  return h
end

-- Window -----------------------------------------------------------------
local function createButton(parent, text, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(130, 24)
  btn:SetText(text)
  btn:SetScript("OnClick", onClick)
  return btn
end

local function create()
  local f = CreateFrame("Frame", "BooksOnMapForeverOptions", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  tinsert(UISpecialFrames, f:GetName()) -- close with Escape

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  -- Header: addon icon + title
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(40, 40)
  logo:SetPoint("TOPLEFT", 16, -14)
  logo:SetTexture(ns.ADDON_ICON)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -4)
  title:SetText("Books on map (Forever)")

  local version = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  version:SetText("v" .. (getMeta(ADDON, "Version") or "?"))

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetTextColor(0.7, 0.7, 0.7)
  sub:SetText(L["Library books of WoW Forever"])

  -- Progress bar (toward the 25-book reward)
  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetPoint("TOPLEFT", 18, -66)
  f.bar:SetPoint("TOPRIGHT", -18, -66)
  f.bar:SetHeight(16)
  f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.bar:SetStatusBarColor(0.85, 0.65, 0.1)
  f.bar:SetMinMaxValues(0, GOAL_25)
  local barBg = f.bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetColorTexture(0, 0, 0, 0.6)
  -- markers at the necklace and ring goals
  for _, goal in ipairs({ GOAL_NECKLACE, GOAL_RING }) do
    local mark = f.bar:CreateTexture(nil, "OVERLAY")
    mark:SetSize(2, 16)
    mark:SetColorTexture(1, 1, 1, 0.7)
    mark:SetPoint("LEFT", f.bar, "LEFT", (WIDTH - 36) * goal / GOAL_25, 0)
  end
  f.barText = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.barText:SetPoint("CENTER")

  f.necklace = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.necklace:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -4)
  f.necklace:SetText(L["10 books: necklace"])
  f.ring = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.ring:SetPoint("TOP", f.bar, "BOTTOM", 0, -4)
  f.ring:SetText(L["20 books: ring"])
  f.goal25 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.goal25:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -4)
  f.goal25:SetText(L["25 books: bow, crest or light"])

  -- Settings: show icons + icon size
  f.showAll = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  f.showAll:SetSize(26, 26)
  f.showAll:SetPoint("TOPLEFT", 14, -104)
  f.showAll.text = f.showAll:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.showAll.text:SetPoint("LEFT", f.showAll, "RIGHT", 2, 0)
  f.showAll.text:SetText(L["Show on the map"])
  f.showAll:SetScript("OnClick", function(self) ns.db.hidden = not self:GetChecked(); ns.Refresh() end)

  f.size = CreateFrame("Slider", "BooksOnMapForeverSizeSlider", f, "OptionsSliderTemplate")
  f.size:SetPoint("TOPRIGHT", -24, -112)
  f.size:SetWidth(170)
  f.size:SetMinMaxValues(10, 40)
  f.size:SetValueStep(1)
  if f.size.SetObeyStepOnDrag then f.size:SetObeyStepOnDrag(true) end
  _G[f.size:GetName() .. "Low"]:SetText("10")
  _G[f.size:GetName() .. "High"]:SetText("40")
  f.size:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(L["Map icon size: %d"]:format(value))
    if ns.db.pinSize ~= value then
      ns.db.pinSize = value
      ns.RefreshMap()
    end
  end)

  -- Filters
  local function filterCheck(label, key, anchor, x)
    local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", x, -136)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.text:SetText(label)
    c:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() or nil; ns.RefreshOptions() end)
    return c
  end
  f.hideDone = filterCheck(L["Hide collected books"], "hideCollected", nil, 14)
  f.myLevel = filterCheck(L["Only sets for my level"], "myLevelOnly", nil, 230)

  -- Language (reloads the UI: names are localized at load)
  StaticPopupDialogs.BOOKSONMAPFOREVER_RELOAD = {
    text = L["The interface will be reloaded to apply the language."],
    button1 = OKAY, button2 = CANCEL,
    OnAccept = function(_, lang) ns.db.lang = lang; ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  local langLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  langLabel:SetText(L["Language"])
  local lang = CreateFrame("Frame", "BooksOnMapForeverLangDropDown", f, "UIDropDownMenuTemplate")
  lang:SetPoint("TOPRIGHT", -18, -34)
  langLabel:SetPoint("BOTTOMLEFT", lang, "TOPLEFT", 20, 0)
  UIDropDownMenu_SetWidth(lang, 90)
  local function current()
    local v = ns.db.lang or "auto"
    for _, o in ipairs(LANGUAGES) do if o.value == v then return L[o.text] end end
  end
  UIDropDownMenu_Initialize(lang, function()
    for _, o in ipairs(LANGUAGES) do
      local info = UIDropDownMenu_CreateInfo()
      info.text, info.value = L[o.text], o.value
      info.checked = (ns.db.lang or "auto") == o.value
      info.func = function()
        CloseDropDownMenus()
        if (ns.db.lang or "auto") ~= o.value then
          local d = StaticPopup_Show("BOOKSONMAPFOREVER_RELOAD")
          if d then d.data = o.value end
        end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  UIDropDownMenu_SetText(lang, current())

  -- Book list (scrollable)
  local listBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
  listBg:SetPoint("TOPLEFT", 14, -164)
  listBg:SetPoint("BOTTOMRIGHT", -14, 48)
  listBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  listBg:SetBackdropColor(0, 0, 0, 0.5)
  listBg:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)

  local scroll = CreateFrame("ScrollFrame", "BooksOnMapForeverScroll", listBg, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -28, 6)

  local contentWidth = WIDTH - 28 - 34
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(contentWidth, 1)
  scroll:SetScrollChild(content)
  f.content = content

  -- positions are set by RefreshOptions (filters)
  f.headers, f.rows = {}, {}
  for _, set in ipairs(SETS) do
    f.headers[#f.headers + 1] = createHeader(content, set, 0, contentWidth)
    for _, b in ipairs(BOOKS) do
      if b.set == set.id then
        f.rows[#f.rows + 1] = createRow(content, b, 0, contentWidth)
      end
    end
  end

  -- Footer
  local showBtn = createButton(f, L["Show all"], function() ns.SetAll(false) end)
  showBtn:SetPoint("BOTTOMLEFT", 16, 16)
  local hideBtn = createButton(f, L["Hide all"], function() ns.SetAll(true) end)
  hideBtn:SetPoint("LEFT", showBtn, "RIGHT", 8, 0)
  local routeBtn = createButton(f, L["Optimized route"], function() ns.ToggleRoute() end)
  routeBtn:SetPoint("BOTTOMRIGHT", -16, 16)

  f:SetScript("OnShow", ns.RefreshOptions)
  f:Hide()
  return f
end

function ns.ToggleOptions()
  frame = frame or create()
  frame:SetShown(not frame:IsShown())
end
