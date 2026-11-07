-- Catboy Egg Farm - experimental client-side helper for Raise A Catboy.
-- This is NOT a verified game-specific exploit. It needs accessible egg prompts
-- and may fail if the server rejects movement, pickup or delivery.
-- No anti-cheat evasion or ban protection is provided.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GAME_ID = 10770707307
local PLACE_ID = 129852792970565
if game.GameId ~= GAME_ID and game.PlaceId ~= PLACE_ID then
    warn("Catboy Egg Farm: this script targets Raise A Catboy; this place is different.")
end

local oldGui = playerGui:FindFirstChild("CatboyEggFarmGUI")
if oldGui then oldGui:Destroy() end

local RARITIES = {
    "Divine", "Super Secret", "Secret", "Ascendant", "Exotic", "Relic",
    "Mythic", "Legendary", "Epic", "Rare", "Common"
}
local settings = {
    running = false,
    mode = "best", -- "best" = highest available rarity/value, "selected" = chosen rarities
    speed = 220, -- studs/second, subject to server physics restrictions.
    height = 45, -- flight altitude, not guaranteed safe from guards
    home = nil,
    selected = { Divine=true, ["Super Secret"]=true, Secret=true },
}
local runId = 0
local flight = nil
local cooldowns = {}

local function characterParts()
    local c = player.Character
    return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local gui = Instance.new("ScreenGui")
gui.Name = "CatboyEggFarmGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function make(class, parent, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local c = function(hex) return Color3.fromRGB(hex[1],hex[2],hex[3]) end
local bg = c({22, 24, 33})
local surface = c({43, 48, 63})
local accent = c({79, 135, 211})
local textColor = c({242, 245, 250})
local muted = c({166, 178, 196})

local main = make("Frame", gui, {
    Size=UDim2.fromOffset(352, 445), Position=UDim2.fromOffset(20,20),
    BackgroundColor3=bg, BorderSizePixel=0, Active=true
})
make("UICorner", main, {CornerRadius=UDim.new(0,13)})
make("UIStroke", main, {Color=c({65,74,96}), Thickness=1})

local title = make("TextLabel", main, {
    Size=UDim2.fromOffset(245,35), Position=UDim2.fromOffset(16,10),
    BackgroundTransparency=1, Text="RAISE A CATBOY  |  EGG FARM",
    TextColor3=textColor, Font=Enum.Font.GothamBold,
    TextSize=15, TextXAlignment=Enum.TextXAlignment.Left
})
local info = make("TextLabel", main, {
    Size=UDim2.fromOffset(320,37), Position=UDim2.fromOffset(16,47),
    BackgroundTransparency=1, Text="Ожидание. Сохрани точку своего кафе.",
    TextColor3=muted, Font=Enum.Font.Gotham, TextSize=12,
    TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left
})
local function setStatus(message)
    if info and info.Parent then info.Text = message end
end

local function roundedButton(parent, name, pos, size)
    local b = make("TextButton", parent, {
        Position=pos, Size=size, BackgroundColor3=surface, BorderSizePixel=0,
        Text=name, Font=Enum.Font.GothamMedium, TextSize=13,
        TextColor3=textColor, AutoButtonColor=true
    })
    make("UICorner", b, {CornerRadius=UDim.new(0,8)})
    return b
end

local modeButton = roundedButton(main, "Режим: самое дорогое", UDim2.fromOffset(16,90), UDim2.fromOffset(320,35))
modeButton.MouseButton1Click:Connect(function()
    settings.mode = settings.mode == "best" and "selected" or "best"
    modeButton.Text = settings.mode == "best" and "Режим: самое дорогое" or "Режим: выбранные редкости"
end)

make("TextLabel", main, {
    Position=UDim2.fromOffset(16,132), Size=UDim2.fromOffset(320,23),
    BackgroundTransparency=1, Text="Редкости (для режима выбора):",
    TextColor3=muted, Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})
local scroll = make("ScrollingFrame", main, {
    Position=UDim2.fromOffset(16,154), Size=UDim2.fromOffset(320,123),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, CanvasSize=UDim2.fromOffset(0,200)
})
make("UIGridLayout", scroll, {
    CellSize=UDim2.fromOffset(150,25), CellPadding=UDim2.fromOffset(8,5),
    SortOrder=Enum.SortOrder.LayoutOrder
})
for i, rarity in ipairs(RARITIES) do
    local b = roundedButton(scroll, rarity, UDim2.new(), UDim2.fromOffset(150,25))
    b.LayoutOrder=i
    b.TextSize=11
    local function refresh()
        local on = settings.selected[rarity] == true
        b.Text = (on and "[x] " or "[ ] ") .. rarity
        b.BackgroundColor3=on and c({47,100,81}) or surface
    end
    b.MouseButton1Click:Connect(function()
        settings.selected[rarity] = not settings.selected[rarity]
        refresh()
    end)
    refresh()
end

local function numericBox(x, caption, value)
    make("TextLabel", main, {
        Position=UDim2.fromOffset(x,286), Size=UDim2.fromOffset(147,20),
        BackgroundTransparency=1, Text=caption, TextColor3=muted,
        TextSize=12, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left
    })
    local box = make("TextBox", main, {
        Position=UDim2.fromOffset(x,306), Size=UDim2.fromOffset(147,32),
        BackgroundColor3=surface, BorderSizePixel=0, Text=tostring(value),
        TextColor3=textColor, Font=Enum.Font.GothamMedium, TextSize=14,
        ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center
    })
    make("UICorner", box, {CornerRadius=UDim.new(0,7)})
    return box
end
local speedBox = numericBox(16,"Скорость (40–400)",settings.speed)
local heightBox = numericBox(189,"Высота (8–150)",settings.height)
local function bindNumber(box, key, minimum, maximum)
    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value then settings[key] = math.clamp(value,minimum,maximum) end
        box.Text = tostring(settings[key])
    end)
end
bindNumber(speedBox,"speed",40,400)
bindNumber(heightBox,"height",8,150)

local homeButton = roundedButton(main,"Запомнить точку кафе",UDim2.fromOffset(16,351),UDim2.fromOffset(320,36))
local startButton = roundedButton(main,"START AUTO EGGS",UDim2.fromOffset(16,397),UDim2.fromOffset(320,39))
startButton.BackgroundColor3=accent

-- Adaptive layout: the entire panel fits portrait and landscape viewports.
-- Tap the minus to minimize; floating button reopens it.
local uiScale = make("UIScale", main, {Scale=1})
local minibar = roundedButton(gui, "EGGS", UDim2.fromOffset(12,72), UDim2.fromOffset(75,40))
minibar.Visible = false
minibar.ZIndex = 20
local minimized = false
local closed = false
local minimizeButton = roundedButton(main, "—", UDim2.fromOffset(270,10), UDim2.fromOffset(29,29))
local closeButton = roundedButton(main, "×", UDim2.fromOffset(306,10), UDim2.fromOffset(29,29))
minimizeButton.ZIndex=5
closeButton.ZIndex=5

local function adapt()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    local scale = math.min(1, (v.X-20)/352, (v.Y-24)/445)
    uiScale.Scale = math.max(0.42,scale)
    local w,h=352*uiScale.Scale,445*uiScale.Scale
    local x=math.clamp(main.Position.X.Offset,0,math.max(0,v.X-w))
    local y=math.clamp(main.Position.Y.Offset,0,math.max(0,v.Y-h))
    main.Position=UDim2.fromOffset(x,y)
end
local cameraConnection
local function watchViewport()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera=workspace.CurrentCamera
    if camera then
        cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(adapt)
    end
    adapt()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
watchViewport()

local function setMinimized(value)
    minimized=value
    main.Visible=not minimized
    minibar.Visible=minimized and not closed
end
minimizeButton.MouseButton1Click:Connect(function() setMinimized(true) end)
minibar.MouseButton1Click:Connect(function() setMinimized(false); adapt() end)

-- Drag with mouse or finger; keep the window inside the screen.
do
    local dragging, startPos, initial
    title.Active=true
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging=input
            startPos=main.Position
            initial=input.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input ~= dragging and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d=input.Position-initial
        main.Position=UDim2.fromOffset(startPos.X.Offset+d.X,startPos.Y.Offset+d.Y)
        adapt()
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input==dragging then dragging=nil end
    end)
end

homeButton.MouseButton1Click:Connect(function()
    local _, root = characterParts()
    if root then
        settings.home = root.Position
        setStatus("Кафе сохранено. Теперь выбери яйца и нажми START.")
    else
        setStatus("Персонаж ещё не появился.")
    end
end)

-- Read visible labels and attributes only. Internal egg names vary by game version.
local function rarityOf(text)
    text = string.lower(tostring(text))
    for i, rarity in ipairs(RARITIES) do
        if string.find(text,string.lower(rarity),1,true) then
            return rarity, #RARITIES - i + 1
        end
    end
    return nil,0
end
local function promptPosition(prompt)
    local part=prompt.Parent
    if part and part:IsA("Attachment") then return part.WorldPosition end
    while part and part ~= workspace do
        if part:IsA("BasePart") then return part.Position end
        part=part.Parent
    end
    return nil
end
-- Ignore eggs displayed in public spawn/lobby/showcase areas.
-- Names are heuristics because the game's internal hierarchy is not public.
local SPAWN_NAMES = {
    spawn=true, spawns=true, spawnarea=true, spawnzone=true,
    lobby=true, showcase=true, display=true, preview=true,
    eggdisplay=true, eggshowcase=true, exhibition=true,
    витрина=true, спавн=true, лобби=true
}
local PLAYER_BASE_NAMES = {
    base=true, bases=true, plot=true, plots=true,
    tycoon=true, cafe=true, cafes=true,
    база=true, кафе=true
}
local function classifyLocation(instance)
    local isSpawn, isPlayerBase = false, false
    local node=instance
    for _=1,12 do
        if not node or node==workspace then break end
        local name=node.Name:lower():gsub("[^%w_]", "")
        if SPAWN_NAMES[name] then isSpawn=true end
        if PLAYER_BASE_NAMES[name] then isPlayerBase=true end
        for _,key in ipairs({"Owner","OwnerName","PlayerName","UserId","OwnerUserId"}) do
            if node:GetAttribute(key)~=nil then isPlayerBase=true end
        end
        node=node.Parent
    end
    return isSpawn and not isPlayerBase, isPlayerBase
end

local function getCandidate(prompt)
    if not prompt.Enabled or (cooldowns[prompt] or 0)>os.clock() then return nil end
    local pos=promptPosition(prompt)
    if not pos then return nil end
    local onSpawn, onBase=classifyLocation(prompt)
    if onSpawn then return nil end
    local labels={prompt.Name,prompt.ActionText,prompt.ObjectText}
    local price=nil
    local node=prompt.Parent
    for _=1,5 do
        if not node or node==workspace then break end
        table.insert(labels,node.Name)
        for _,key in ipairs({"Rarity","Tier","EggType","Type","Name"}) do
            local v=node:GetAttribute(key)
            if v~=nil then table.insert(labels,tostring(v)) end
            local child=node:FindFirstChild(key)
            if child and child:IsA("ValueBase") then
                table.insert(labels,tostring(child.Value))
            end
        end
        for _,key in ipairs({"Income","CashPerSecond","Price","Value","Cost"}) do
            local v=node:GetAttribute(key)
            if typeof(v)=="number" then price=math.max(price or 0,v) end
            local child=node:FindFirstChild(key)
            if child and child:IsA("NumberValue") then
                price=math.max(price or 0,child.Value)
            end
        end
        node=node.Parent
    end
    local all=table.concat(labels," ")
    local lower=all:lower()
    local action=prompt.ActionText:lower()
    for _,prohibited in ipairs({"buy","purchase","robux","r$","skip","gamepass","купить","покупка"}) do
        if action:find(prohibited,1,true) then return nil end
    end
    local rarity,rank=rarityOf(all)
    local isEgg=(rarity~=nil)
    for _,word in ipairs({"egg","яйц","steal","collect","grab","pickup"}) do
        if lower:find(word,1,true) then isEgg=true; break end
    end
    if not isEgg then return nil end
    local stealAction = action:find("steal",1,true)
        or action:find("rob",1,true)
        or action:find("укра",1,true)
    return {prompt=prompt,pos=pos,rarity=rarity,rank=rank,
        value=price or 0,playerBase=onBase,stealAction=not not stealAction}
end

local function findTarget()
    local _,root=characterParts()
    if not root then return nil end
    local best,bestScore,bestDist=nil,-math.huge,math.huge
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local egg=getCandidate(obj)
            if egg and (settings.mode=="best" or settings.selected[egg.rarity]==true) then
                local distance=(egg.pos-root.Position).Magnitude
                -- Highest rarity first; numeric value breaks ties where present.
                local score=egg.rank*1e12+egg.value + (egg.stealAction and 1e15 or 0) + (egg.playerBase and 1e14 or 0)
                if score>bestScore or (score==bestScore and distance<bestDist) then
                    best,bestScore,bestDist=egg,score,distance
                end
            end
        end
    end
    return best
end

local function stopFlight()
    if not flight then return end
    local f=flight
    flight=nil
    if f.velocity then f.velocity:Destroy() end
    if f.orientation then f.orientation:Destroy() end
    if f.attachment then f.attachment:Destroy() end
    if f.root and f.root.Parent then f.root.AssemblyLinearVelocity=Vector3.zero end
    if f.hum and f.hum.Parent then
        f.hum.PlatformStand=f.platformStand
        f.hum.AutoRotate=f.autoRotate
        if f.hum.Health>0 then f.hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end
local function ensureFlight()
    local _,root,hum=characterParts()
    if not root or not hum or hum.Health<=0 then return nil end
    if flight and flight.root==root and flight.velocity.Parent then return flight end
    stopFlight()
    local a=Instance.new("Attachment")
    a.Name="CatboyFlightAttachment"
    a.Parent=root
    local lv=Instance.new("LinearVelocity")
    lv.Name="CatboyFlightVelocity"
    lv.Attachment0=a
    lv.RelativeTo=Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    lv.ForceLimitsEnabled=false
    lv.VectorVelocity=Vector3.zero
    lv.Parent=root
    local ao=Instance.new("AlignOrientation")
    ao.Name="CatboyFlightOrientation"
    ao.Attachment0=a
    ao.Mode=Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque=1e7
    ao.Responsiveness=15
    ao.CFrame=root.CFrame
    ao.Parent=root
    flight={root=root,hum=hum,attachment=a,velocity=lv,orientation=ao,
        platformStand=hum.PlatformStand,autoRotate=hum.AutoRotate}
    hum.PlatformStand=true
    hum.AutoRotate=false
    return flight
end

local function flyTo(goal,id)
    local f=ensureFlight()
    if not f then return false end
    local starting=(f.root.Position-goal).Magnitude
    local deadline=os.clock()+math.max(6,starting/settings.speed*3+6)
    local lastProgress=os.clock()
    local previous=starting
    while settings.running and runId==id and gui.Parent do
        if not f.root.Parent or f.hum.Health<=0 then return false end
        local offset=goal-f.root.Position
        local distance=offset.Magnitude
        if distance<=2.7 then
            f.velocity.VectorVelocity=Vector3.zero
            return true
        end
        if os.clock()>deadline or os.clock()-lastProgress>5 then
            f.velocity.VectorVelocity=Vector3.zero
            return false
        end
        if distance<previous-0.7 then previous=distance;lastProgress=os.clock() end
        local currentSpeed=math.min(settings.speed,math.max(24,distance*7))
        f.velocity.VectorVelocity=offset.Unit*currentSpeed
        local flat=Vector3.new(offset.X,0,offset.Z)
        if flat.Magnitude>0.1 then
            f.orientation.CFrame=CFrame.lookAt(Vector3.zero,flat.Unit)
        end
        RunService.Heartbeat:Wait()
    end
    if flight and flight.velocity.Parent then flight.velocity.VectorVelocity=Vector3.zero end
    return false
end

local function flyHighTo(dest,token,approachHeight)
    local _,root=characterParts()
    if not root then return false end
    local top=math.max(root.Position.Y,dest.Y,settings.home.Y)+settings.height
    local up=Vector3.new(root.Position.X,top,root.Position.Z)
    local across=Vector3.new(dest.X,top,dest.Z)
    if not flyTo(up,token) then return false end
    if not flyTo(across,token) then return false end
    return flyTo(dest+Vector3.new(0,approachHeight or 2,0),token)
end

-- A successful input call is not proof that the server awarded an egg.
local function pickupConfirmed(prompt)
    if not prompt or not prompt.Parent then return true end
    -- A disabled prompt alone does not reliably prove successful pickup.
    local char = player.Character
    if not char then return false end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("egg",1,true)
            or obj.Name:lower():find("яйц",1,true)) then
            return true
        end
    end
    return false
end

local function interact(prompt,token)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end
    if not settings.running or runId~=token then return false end
    for attempt=1,2 do
        if not settings.running or token~=runId then return false end
        local _,root=characterParts()
        local pos=promptPosition(prompt)
        if not root or not pos or (root.Position-pos).Magnitude > prompt.MaxActivationDistance+1 then
            setStatus("Слишком далеко от яйца: подбираю позицию.")
            return false
        end
        local ok=pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.clamp(prompt.HoldDuration+0.1,0.1,5))
            prompt:InputHoldEnd()
        end)
        -- Some environments expose this API; no guarantee that the server accepts it.
        if not pickupConfirmed(prompt) and type(fireproximityprompt)=="function" then
            pcall(function() fireproximityprompt(prompt) end)
        end
        for _=1,9 do
            if pickupConfirmed(prompt) then return true end
            task.wait(0.12)
        end
        if not ok then warn("Egg prompt input failed") end
    end
    return false
end

local function farm(token)
    while settings.running and runId==token and gui.Parent do
        if not settings.home then
            setStatus("Сначала сохрани точку кафе.")
            task.wait(0.8)
        else
            local egg=findTarget()
            if not egg then
                setStatus("Подходящих яиц вне спавна не найдено. Проверь зону игроков.")
                task.wait(1.5)
            else
                setStatus("Лечу к яйцу: " .. (egg.rarity or "без редкости"))
                local maxDist=egg.prompt.MaxActivationDistance
                local pickupHeight=math.max(0.5,math.min(2,maxDist*0.45))
                if flyHighTo(egg.pos,token,pickupHeight) then
                    setStatus("Пробую взять яйцо...")
                    local used=interact(egg.prompt,token)
                    if used and settings.running and runId==token then
                        setStatus("Возвращаюсь в кафе...")
                        flyHighTo(settings.home,token,1.5)
                        task.wait(0.6)
                    else
                        setStatus("Подбор не подтверждён игрой; пропускаю это яйцо.")
                    end
                else
                    setStatus("Перемещение не удалось / заблокировано сервером.")
                end
                cooldowns[egg.prompt]=os.clock()+ (settings.running and 8 or 3)
            end
        end
    end
    stopFlight()
end

local function stop()
    settings.running=false
    runId=runId+1
    stopFlight()
    startButton.Text="START AUTO EGGS"
    startButton.BackgroundColor3=accent
end

startButton.MouseButton1Click:Connect(function()
    if settings.running then
        stop()
        setStatus("Остановлено.")
        return
    end
    if not settings.home then
        setStatus("Сначала встань в своём кафе и сохрани точку.")
        return
    end
    settings.running=true
    runId=runId+1
    startButton.Text="STOP AUTO EGGS"
    startButton.BackgroundColor3=c({177,70,84})
    local token=runId
    task.spawn(function()
        local ok,err=pcall(farm,token)
        if not ok then
            warn("Catboy Egg Farm error: ",err)
            setStatus("Ошибка скрипта. См. консоль F9.")
            stop()
        end
    end)
end)

closeButton.MouseButton1Click:Connect(function()
    closed=true
    stop()
    if cameraConnection then cameraConnection:Disconnect() end
    gui:Destroy()
end)

player.CharacterAdded:Connect(function()
    if settings.running then
        stop()
        setStatus("Персонаж возродился. Запусти заново.")
    end
end)
gui.Destroying:Connect(function() stop() end)

print("Catboy Egg Farm loaded. Speed=220, height=45. Compact UI for phone landscape.")