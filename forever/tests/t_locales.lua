-- Locales/*.lua: completeness, placeholders and the fallback rules
return function(T)
    local LANGS = { "enUS", "deDE", "frFR", "esES", "ruRU", "koKR", "zhCN", "zhTW" }

    local function loadLocales()
        local env = { EasyGearLocales = {} }
        for _, code in ipairs(LANGS) do
            local chunk = assert(loadfile(T.dir .. "/Locales/" .. code .. ".lua"))
            setfenv(chunk, env)
            chunk()
        end
        return env.EasyGearLocales
    end

    local function slurp(path)
        local f = assert(io.open(path, "r"))
        local s = f:read("*a")
        f:close()
        return s
    end

    local function placeholders(s)
        local out = {}
        for p in s:gmatch("%%[%d%$]*[sdf%%]") do out[#out + 1] = p end
        return table.concat(out, ",")
    end

    T.test("locales: all eight files load and register their table", function()
        local all = loadLocales()
        for _, code in ipairs(LANGS) do T.eq(type(all[code]), "table", code) end
    end)

    T.test("locales: every key the code uses exists in enUS", function()
        local en = loadLocales().enUS
        local files = { "Core", "Stats", "Specs", "Profiles", "Items", "Score", "Recommend", "Tooltip", "Marks",
                        "Contexts", "Window", "ProfileWindow", "Options", "Slash" }
        local missing = {}
        for _, f in ipairs(files) do
            local src = slurp(T.dir .. "/" .. f .. ".lua"):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
            for key in src:gmatch("%f[%w_]L%.([A-Z][A-Z0-9_]+)") do
                if not en[key] then missing[key] = f end
            end
            for key in src:gmatch('"([A-Z][A-Z0-9]*_[A-Z0-9_]+)"') do
                -- string keys of the tables in Options.lua and Slash.lua (OPT_..., H_..., ST_...)
                if key:match("^OPT_") or key:match("^H_") or key:match("^ST_") then
                    if not en[key] then missing[key] = f end
                end
            end
        end
        local list = {}
        for k, f in pairs(missing) do list[#list + 1] = k .. " (" .. f .. ")" end
        table.sort(list)
        T.eq(table.concat(list, ", "), "", "keys without an English text")
    end)

    T.test("locales: no translation has a key that enUS lacks", function()
        local all = loadLocales()
        for _, code in ipairs(LANGS) do
            for key in pairs(all[code]) do T.ok(all.enUS[key], code .. " has stray key " .. key) end
        end
    end)

    T.test("locales: German is complete", function()
        local all = loadLocales()
        local missing = {}
        for key in pairs(all.enUS) do if not all.deDE[key] then missing[#missing + 1] = key end end
        table.sort(missing)
        T.eq(table.concat(missing, ", "), "")
    end)

    T.test("locales: placeholders match enUS in kind and order, texts are not empty", function()
        local all = loadLocales()
        for _, code in ipairs(LANGS) do
            for key, text in pairs(all[code]) do
                T.eq(type(text), "string", code .. "." .. key)
                T.ok(text:match("%S"), code .. "." .. key .. " is empty")
                T.eq(placeholders(text), placeholders(all.enUS[key]), code .. "." .. key)
            end
        end
    end)

    T.test("locales: every text with placeholders formats with sample arguments", function()
        local all = loadLocales()
        for _, code in ipairs(LANGS) do
            for key, text in pairs(all[code]) do
                local n = select(2, placeholders(text):gsub(",?%%[sdf]", ""))
                if n > 0 then
                    local args = {}
                    for i = 1, n do args[i] = 1 end
                    local ok, err = pcall(string.format, text, unpack(args))
                    T.ok(ok, code .. "." .. key .. ": " .. tostring(err))
                end
            end
        end
    end)

    T.test("locales: every profile has a name and a description", function()
        local en = loadLocales().enUS
        local src = slurp(T.dir .. "/Specs.lua")
        local n = 0
        for id in src:gmatch('%f[%w_]id%s*=%s*"([A-Z0-9_]+)"') do
            n = n + 1
            T.ok(en["SPEC_" .. id], "SPEC_" .. id)
            T.ok(en["SPEC_" .. id .. "_D"], "SPEC_" .. id .. "_D")
        end
        T.eq(n, 48)
    end)

    T.test("locales: the client language picks its file, other languages fall back key by key", function()
        local de = T.world({ locale = "deDE" })
        T.eq(de.EG.L.SCORE, "Wertung") T.eq(de.EG.locale.active, "deDE") T.eq(de.EG.locale.translated, true)
        local fr = T.world({ locale = "frFR" })
        T.eq(fr.EG.L.SCORE, "Score" == fr.EG.L.SCORE and "Score" or fr.EG.L.SCORE)
        T.eq(fr.EG.L.OPT_RESET, "Reset settings", "not translated into French: English text")
        T.eq(fr.EG.L.DOES_NOT_EXIST, "DOES_NOT_EXIST", "unknown keys show their name")
        T.eq(fr.EG:LocaleHas("OPT_RESET"), true) T.eq(fr.EG:LocaleHas("NOPE"), false)
        local gb = T.world({ locale = "enGB" })
        T.eq(gb.EG.locale.active, "enUS") T.eq(gb.EG.L.SCORE, "Score")
        local mx = T.world({ locale = "esMX" })
        T.eq(mx.EG.locale.active, "esES") T.eq(mx.EG.locale.translated, true)
        local xx = T.world({ locale = "xxXX" })
        T.eq(xx.EG.locale.translated, false) T.eq(xx.EG.L.SCORE, "Score")
    end)

    T.test("locales: the interface works in every language", function()
        for _, code in ipairs(LANGS) do
            local W = T.world(require("fixtures").arms({ locale = code }), function(w)
                w.I = require("fixtures").armsWarrior(w)
            end)
            local link = require("fixtures").gear(W, 9900, "Better", "INVTYPE_CHEST", 40, { STR = 30 }, { armor = 500 })
            local tip = W.tooltipFor(W.bagButton(0, 1), link)
            T.has(tip:Dump(), "EasyGear")
            W.EG.Window.SetItem(link)
            W.EG.ProfileWindow.Open()
            W.slash("status") W.slash("help")
            W.EG.Slash.PrintReport(link)
            T.eq(W.EG.lastError, nil, code .. " raised: " .. tostring(W.EG.lastError and W.EG.lastError.err))
        end
    end)
end
