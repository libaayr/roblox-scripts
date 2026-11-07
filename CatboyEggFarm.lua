-- Raise A Catboy: manual egg pickup -> one-tap return home.
-- Exactly two buttons: Save Home and Fly Home.
-- This is client-side movement only. The server controls whether an egg stays carried.
-- No automatic egg search, pickup, inventory edits, or anti-cheat bypass.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OPTIONS = {
    LIFT_HEIGHT = 65,       -- studs above the higher of player/home
    UP_SPEED = 330,        -- vertical studs per second (requested)
    CRUISE_SPEED = 430,    -- horizontal studs per second (requested)
    DOWN_SPEED = 250,      -- near home
    ARRIVE_RADIUS = 3.5,
}

-- Close earlier versions. Their GUI Destroying handler stops their flight.
local previous = playerGui:FindFirstChild("CatboyEggFarmGUI")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CatboyEggFarmGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 80
gui.Parent = playerGui

local homePosition = nil
local inFlight = false
local runId = 0
local active = nil

local function ui(className, parent, properties)
    local instance = Instance.new(className)
    for property, value in pairs(properties) do instance[property] = value end
    instance.Parent = parent
    return instance
end

local panel = ui("Frame", gui, {
    Size = UDim2.fromOffset(282, 146),
    Position = UDim2.new(0, 12, 0.5, -73),
    BackgroundColor3 = Color3.fromRGB(22, 24, 34),
    BorderSizePixel = 0,
})
ui("UICorner", panel, {CornerRadius = UDim.new(0, 12)})
ui("UIStroke", panel, {Color = Color3.fromRGB(65, 79, 104), Thickness = 1})
local scale = ui("UIScale", panel, {Scale = 1})

local status = ui("TextLabel", panel, {
    Position = UDim2.fromOffset(12, 8),
    Size = UDim2.fromOffset(258, 28),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = "Сначала сохрани точку дома",
    TextSize = 12,
    TextColor3 = Color3.fromRGB(220, 229, 243),
    TextXAlignment = Enum.TextXAlignment.Center,
    TextWrapped = true,
})

local function button(text, y, color)
    local b = ui("TextButton", panel, {
        Position = UDim2.fromOffset(12, y),
        Size = UDim2.fromOffset(258, 43),
        BackgroundColor3 = color,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = text,
        TextSize = 15,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = true,
        BorderSizePixel = 0,
    })
    ui("UICorner", b, {CornerRadius = UDim.new(0, 9)})
    return b
end

-- These are the ONLY two buttons.
local saveButton = button("1. СОХРАНИТЬ ДОМ", 39, Color3.fromRGB(50, 107, 91))
local flyButton = button("2. БЫСТРО ДОМОЙ", 91, Color3.fromRGB(70, 117, 190))

local function updateLayout()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local size = camera.ViewportSize
    scale.Scale = math.min(1, math.max(0.55,
        (size.X - 24) / 282), math.max(0.55, (size.Y - 24) / 146))
    panel.Position = UDim2.new(0, 12, 0.5, -73 * scale.Scale)
end
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
    end
    updateLayout()
end
attachCamera()
local cameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)

local function getParts()
    local character = player.Character
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    return root, humanoid
end

local function cleanup()
    local f = active
    active = nil
    if not f then return end
    if f.velocity then f.velocity:Destroy() end
    if f.attachment then f.attachment:Destroy() end
    if f.humanoid and f.humanoid.Parent then
        f.humanoid.AutoRotate = f.oldAutoRotate
    end
end

local function makeFlight()
    local root, humanoid = getParts()
    if not root then return nil end

    local attachment = Instance.new("Attachment")
    attachment.Name = "CatboyReturnAttachment"
    attachment.Parent = root

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "CatboyReturnVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled = false
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root

    active = {
        root = root,
        humanoid = humanoid,
        attachment = attachment,
        velocity = velocity,
        oldAutoRotate = humanoid.AutoRotate,
    }
    -- Do NOT use PlatformStand, which may interfere with carrying eggs.
    humanoid.AutoRotate = false
    return active
end

local function goTo(goal, maximumSpeed, token)
    local f = active
    if not f then return false end
    local startDistance = (goal - f.root.Position).Magnitude
    local deadline = os.clock() + math.max(3, startDistance / maximumSpeed * 3 + 2)
    local previousDistance = startDistance
    local lastProgressAt = os.clock()

    while token == runId and gui.Parent and f.root.Parent
        and f.humanoid.Health > 0 do
        local offset = goal - f.root.Position
        local distance = offset.Magnitude

        if distance <= OPTIONS.ARRIVE_RADIUS then
            f.velocity.VectorVelocity = Vector3.zero
            return true
        end

        if distance < previousDistance - 0.5 then
            previousDistance = distance
            lastProgressAt = os.clock()
        end
        if os.clock() > deadline or os.clock() - lastProgressAt > 2 then
            break
        end

        -- Continuous velocity, with braking only as the destination approaches.
        local requestedSpeed = math.min(maximumSpeed, math.max(18, distance * 12))
        f.velocity.VectorVelocity = offset.Unit * requestedSpeed
        RunService.Heartbeat:Wait()
    end

    if f.velocity and f.velocity.Parent then
        f.velocity.VectorVelocity = Vector3.zero
    end
    return false
end

saveButton.MouseButton1Click:Connect(function()
    if inFlight then return end
    local root = getParts()
    if not root then
        status.Text = "Персонаж ещё не появился"
        return
    end
    homePosition = root.Position
    status.Text = "Точка дома сохранена"
end)

flyButton.MouseButton1Click:Connect(function()
    if inFlight then return end
    if not homePosition then
        status.Text = "Сначала нажми «Сохранить дом»"
        return
    end
    if not getParts() then
        status.Text = "Персонаж ещё не появился"
        return
    end

    inFlight = true
    runId += 1
    local token = runId
    flyButton.Text = "ЛЕЧУ ДОМОЙ..."

    task.spawn(function()
        local completed = false
        local ok, err = pcall(function()
            local f = makeFlight()
            if not f then return end
            local top = math.max(f.root.Position.Y, homePosition.Y) + OPTIONS.LIFT_HEIGHT

            -- 1. Immediately rise out of the guarded area.
            status.Text = "Подъём..."
            if not goTo(Vector3.new(f.root.Position.X, top, f.root.Position.Z),
                OPTIONS.UP_SPEED, token) then return end

            -- 2. Fly directly over the saved home.
            status.Text = "Перелёт к дому..."
            if not goTo(Vector3.new(homePosition.X, top, homePosition.Z),
                OPTIONS.CRUISE_SPEED, token) then return end

            -- 3. Descend only after reaching home.
            status.Text = "Спуск у дома..."
            completed = goTo(homePosition, OPTIONS.DOWN_SPEED, token)
        end)

        cleanup()
        inFlight = false
        flyButton.Text = "2. БЫСТРО ДОМОЙ"
        if not ok then
            warn("Catboy return error:", err)
            status.Text = "Ошибка полёта — смотри консоль"
        elseif completed then
            status.Text = "Ты у дома. Зачёт яйца решает игра"
        else
            status.Text = "Полёт прерван или ограничен сервером"
        end
    end)
end)

player.CharacterAdded:Connect(function()
    runId += 1
    cleanup()
    inFlight = false
    flyButton.Text = "2. БЫСТРО ДОМОЙ"
    status.Text = homePosition and "Дом сохранён. Можно лететь" or "Сохрани точку дома"
end)

gui.Destroying:Connect(function()
    runId += 1
    cleanup()
    if viewportConnection then viewportConnection:Disconnect() end
    if cameraChanged then cameraChanged:Disconnect() end
end)

print("Catboy manual return loaded: Save Home / Fly Home")
