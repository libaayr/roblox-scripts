-- Raise A Catboy: 2-button manual return helper (ground route only).
-- Fast flight caused carried eggs to drop. Do not use LinearVelocity, CFrame teleport,
-- PlatformStand, TweenService, or change WalkSpeed with an egg.
-- This script does not grant inventory items or bypass server pickup rules.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("CatboyEggFarmGUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CatboyEggFarmGUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 80
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for key, value in pairs(properties) do instance[key] = value end
    instance.Parent = parent
    return instance
end

local panel = make("Frame", gui, {
    Size = UDim2.fromOffset(284, 153),
    Position = UDim2.new(0, 12, 0.5, -76),
    BackgroundColor3 = Color3.fromRGB(22, 24, 34),
    BorderSizePixel = 0,
})
make("UICorner", panel, {CornerRadius = UDim.new(0, 12)})
make("UIStroke", panel, {Color = Color3.fromRGB(65, 79, 104), Thickness = 1})
local scale = make("UIScale", panel, {Scale = 1})

local status = make("TextLabel", panel, {
    Position = UDim2.fromOffset(9, 8),
    Size = UDim2.fromOffset(266, 30),
    BackgroundTransparency = 1,
    Text = "Сохрани дом, затем вручную возьми яйцо",
    TextColor3 = Color3.fromRGB(231, 234, 242),
    TextSize = 11,
    TextWrapped = true,
    Font = Enum.Font.GothamMedium,
})

local function button(name, y, color)
    local b = make("TextButton", panel, {
        Position = UDim2.fromOffset(11, y),
        Size = UDim2.fromOffset(262, 44),
        BackgroundColor3 = color,
        Text = name,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    })
    make("UICorner", b, {CornerRadius = UDim.new(0, 9)})
    return b
end

-- Exactly two clickable buttons.
local saveButton = button("1. СОХРАНИТЬ ДОМ", 41, Color3.fromRGB(48, 107, 86))
local homeButton = button("2. ДОМОЙ ПО ЗЕМЛЕ", 97, Color3.fromRGB(68, 116, 189))

local function adapt()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    scale.Scale = math.min(1, math.max(0.35, (v.X - 20) / 284),
        math.max(0.35, (v.Y - 20) / 153))
    panel.Position = UDim2.new(0, 12, 0.5, -76 * scale.Scale)
end
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(adapt)
    end
    adapt()
end
watchCamera()
local cameraChangedConnection =
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

local homePosition = nil
local running = false
local jobId = 0

local function getParts()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if root and humanoid and humanoid.Health > 0 then
        return root, humanoid
    end
end

local function cancel()
    running = false
    jobId += 1
    local root, humanoid = getParts()
    if root then humanoid:MoveTo(root.Position) end
    homeButton.Text = "2. ДОМОЙ ПО ЗЕМЛЕ"
end

local function reach(point, token)
    local root, humanoid = getParts()
    if not root then return false end
    local startDistance = (root.Position - point).Magnitude
    local timeout = math.max(4, startDistance / math.max(6, humanoid.WalkSpeed) * 2.5 + 3)
    humanoid:MoveTo(point)
    local began = os.clock()
    local previous = startDistance
    local stagnant = os.clock()

    while running and token == jobId and humanoid.Health > 0 and gui.Parent do
        local distance = (root.Position - point).Magnitude
        if distance <= 4 then return true end
        if distance < previous - 0.5 then
            previous = distance
            stagnant = os.clock()
        end
        if os.clock() - began > timeout or os.clock() - stagnant > 4 then
            return false
        end
        task.wait(0.08)
    end
    return false
end

local function walkHome(token)
    local root = getParts()
    if not root or not homePosition then return false end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 4
    })
    local ok = pcall(function()
        path:ComputeAsync(root.Position, homePosition)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        status.Text = "Маршрут не найден. Вернись вручную"
        return false
    end

    local waypoints = path:GetWaypoints()
    for index, waypoint in ipairs(waypoints) do
        if not running or jobId ~= token then return false end
        local currentRoot, humanoid = getParts()
        if not currentRoot then return false end
        status.Text = ("Маршрут к дому: %d/%d"):format(index, #waypoints)
        if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
        if not reach(waypoint.Position, token) then
            status.Text = "Путь прерван — попробуй вернуться вручную"
            return false
        end
    end
    return true
end

saveButton.MouseButton1Click:Connect(function()
    if running then return end
    local root = getParts()
    if not root then
        status.Text = "Персонаж ещё не появился"
        return
    end
    homePosition = root.Position
    status.Text = "Дом сохранён. Возьми яйцо вручную"
end)

homeButton.MouseButton1Click:Connect(function()
    if running then
        cancel()
        status.Text = "Маршрут остановлен"
        return
    end
    if not homePosition then
        status.Text = "Сначала сохрани точку дома"
        return
    end
    if not getParts() then
        status.Text = "Персонаж ещё не появился"
        return
    end
    running = true
    jobId += 1
    local token = jobId
    homeButton.Text = "ОСТАНОВИТЬ МАРШРУТ"
    status.Text = "Возвращаюсь по земле, без принудительного полёта"
    task.spawn(function()
        local ok, arrived = pcall(walkHome, token)
        if jobId ~= token then return end
        running = false
        homeButton.Text = "2. ДОМОЙ ПО ЗЕМЛЕ"
        if not ok then
            status.Text = "Ошибка маршрута — проверь консоль"
            warn("Catboy walking route:", arrived)
        elseif arrived then
            status.Text = "У дома. Зачисление яйца контролирует игра"
        end
    end)
end)

local charConnection = player.CharacterAdded:Connect(function()
    cancel()
    status.Text = homePosition and "Дом сохранён. Возьми яйцо" or "Сохрани дом"
end)

gui.Destroying:Connect(function()
    cancel()
    if cameraConnection then cameraConnection:Disconnect() end
    if cameraChangedConnection then cameraChangedConnection:Disconnect() end
    if charConnection then charConnection:Disconnect() end
end)

print("Catboy return updated: two buttons, natural movement only")
