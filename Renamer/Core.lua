local names = {}

local function printf(fmt, ...)
    print("|cff00ff00[Renamer]|r " .. fmt:format(...))
end

local function rebuildNames()
    wipe(names)
    if RenamerDB and RenamerDB.names then
        for k, v in pairs(RenamerDB.names) do names[k] = v end
    end
end

local function lookup(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local n = UnitName(unit)
    return n and names[n] or nil
end

local function countTable(t)
    local c = 0
    if t then for _ in pairs(t) do c = c + 1 end end
    return c
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Parses CSV in the format: DiscordName,Char1,Char2,...
-- Lines starting with # are comments. Empty lines and empty fields are skipped.
local function parseCSV(text)
    local result = {}
    local count = 0
    local errors = {}
    local lineNo = 0
    for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        lineNo = lineNo + 1
        local stripped = trim(line)
        if stripped ~= "" and stripped:sub(1, 1) ~= "#" then
            local fields = {}
            for field in (stripped .. ","):gmatch("([^,]*),") do
                fields[#fields + 1] = trim(field)
            end
            local discord = fields[1]
            local added = 0
            if not discord or discord == "" then
                errors[#errors + 1] = "line " .. lineNo .. ": missing discord name"
            else
                for i = 2, #fields do
                    local char = fields[i]
                    if char ~= "" then
                        result[char] = discord
                        count = count + 1
                        added = added + 1
                    end
                end
                if added == 0 then
                    errors[#errors + 1] = "line " .. lineNo .. ": no characters listed for " .. discord
                end
            end
        end
    end
    return result, count, errors
end

------------------------------------------
-- Blizzard CompactRaidFrames
------------------------------------------
if CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if not frame or not frame.unit or not frame.name then return end
        local nick = lookup(frame.unit)
        if nick then
            frame.name:SetText(nick)
        end
    end)
end

------------------------------------------
-- ElvUI / oUF custom tags
------------------------------------------
local function registerCustomTags()
    local ElvUF = _G.ElvUF
    if not ElvUF or not ElvUF.Tags or not ElvUF.Tags.Methods then return end

    local function makeTag(maxLen)
        return function(unit)
            if not unit then return "" end
            local n = UnitName(unit)
            if not n then return "" end
            local out = names[n] or n
            if maxLen and #out > maxLen then out = out:sub(1, maxLen) end
            return out
        end
    end

    ElvUF.Tags.Methods["name:discord"]         = makeTag(nil)
    ElvUF.Tags.Methods["name:discord:short"]   = makeTag(4)
    ElvUF.Tags.Methods["name:discord:medium"]  = makeTag(8)
    ElvUF.Tags.Methods["name:discord:long"]    = makeTag(20)
    if ElvUF.Tags.Events then
        local events = "UNIT_NAME_UPDATE PARTY_MEMBERS_CHANGED GROUP_ROSTER_UPDATE PLAYER_TARGET_CHANGED"
        ElvUF.Tags.Events["name:discord"]        = events
        ElvUF.Tags.Events["name:discord:short"]  = events
        ElvUF.Tags.Events["name:discord:medium"] = events
        ElvUF.Tags.Events["name:discord:long"]   = events
    end
end

-- Register at file-load time. ElvUI loads alphabetically before Renamer, so
-- this catches the normal case before any frames compile their tag strings.
registerCustomTags()

------------------------------------------
-- Import UI
------------------------------------------
local importFrame
local function createImportFrame()
    if importFrame then return importFrame end

    local frame = CreateFrame("Frame", "RenamerImportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Renamer — Import CSV")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText("Format per line: DiscordName,Char1,Char2,...   (# comment)")

    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 16, -56)
    box:SetPoint("BOTTOMRIGHT", -16, 70)
    box:EnableMouse(true)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        box:SetBackdropColor(0, 0, 0, 0.7)
    end

    local scroll = CreateFrame("ScrollFrame", "RenamerImportScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", "RenamerImportEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(scroll:GetWidth())
    edit:SetHeight(2000)
    edit:SetMaxLetters(0)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnCursorChanged", function(self, _, y, _, h)
        self.cursorOffset = y
        self.cursorHeight = h
    end)
    edit:SetScript("OnTextChanged", function(self)
        ScrollingEdit_OnTextChanged(self, scroll)
    end)
    scroll:SetScrollChild(edit)

    box:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", 16, 40)
    status:SetPoint("BOTTOMRIGHT", -16, 40)
    status:SetJustifyH("LEFT")

    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 22)
    importBtn:SetPoint("BOTTOMLEFT", 16, 12)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local text = edit:GetText() or ""
        local parsed, count, errors = parseCSV(text)
        RenamerDB = RenamerDB or {}
        RenamerDB.names = parsed
        rebuildNames()
        local msg = "Imported " .. count .. " characters."
        if #errors > 0 then
            msg = msg .. " " .. #errors .. " error(s) — see chat."
            for _, e in ipairs(errors) do
                printf("|cffff5555%s|r", e)
            end
        end
        status:SetText(msg)
        printf("%s", msg)
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(120, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    frame:Hide()
    importFrame = frame
    return frame
end

------------------------------------------
-- Slash commands
------------------------------------------
SLASH_RENAMER1 = "/renamer"
SlashCmdList["RENAMER"] = function(msg)
    msg = trim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "import" then
        createImportFrame():Show()
    elseif cmd == "count" then
        printf("%d entries loaded.", countTable(names))
    elseif cmd == "clear" then
        RenamerDB = { names = {} }
        rebuildNames()
        printf("SavedVars cleared.")
    elseif cmd == "test" then
        local arg = (rest ~= "" and rest) or "player"
        local asUnit = UnitName(arg)
        if asUnit then
            printf("unit %s -> name %s -> %s", arg, asUnit, tostring(names[asUnit]))
        else
            printf("raw lookup names[%s] = %s", arg, tostring(names[arg]))
        end
    elseif cmd == "dump" then
        local total = countTable(names)
        local n = 0
        for k, v in pairs(names) do
            print("  " .. k .. " -> " .. v)
            n = n + 1
            if n >= 10 then
                if total > 10 then print("  ...(" .. (total - 10) .. " more)") end
                break
            end
        end
    else
        printf("commands: import | count | clear | test [unit] | dump")
    end
end

------------------------------------------
-- Events
------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "Renamer" then
            rebuildNames()
        elseif addon == "ElvUI" then
            registerCustomTags()
        end
    end
end)
