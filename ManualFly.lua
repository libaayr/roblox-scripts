-- Manual Fly for Roblox. Independent of egg farming.
-- Game servers may restrict flight; carrying an egg may trigger an automatic drop.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
for _,name in ipairs({"CatboyEggFarmGUI","ManualFlyGUI"}) do
    local old=playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local gui=Instance.new("ScreenGui")
gui.Name="ManualFlyGUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=120
gui.Parent=playerGui

local function new(cls,parent,props)
    local o=Instance.new(cls)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local frame=new("Frame",gui,{
    Size=UDim2.fromOffset(232,202),
    Position=UDim2.new(1,-246,0,50),
    BackgroundColor3=Color3.fromRGB(22,26,37),
    BorderSizePixel=0,Active=true
})
new("UICorner",frame,{CornerRadius=UDim.new(0,12)})
new("UIStroke",frame,{Color=Color3.fromRGB(70,85,108),Thickness=1})
local scale=new("UIScale",frame,{Scale=1})
local heading=new("TextLabel",frame,{
    Size=UDim2.fromOffset(212,26),Position=UDim2.fromOffset(10,5),
    Text="MANUAL FLY • двигай окно",
    BackgroundTransparency=1,
    TextColor3=Color3.fromRGB(229,238,249),
    TextSize=12,Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,Active=true
})
local function button(caption,x,y,w,h,color)
    local b=new("TextButton",frame,{
        Size=UDim2.fromOffset(w,h),
        Position=UDim2.fromOffset(x,y),
        Text=caption,TextSize=14,
        TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.GothamBold,
        BackgroundColor3=color,BorderSizePixel=0
    })
    new("UICorner",b,{CornerRadius=UDim.new(0,8)})
    return b
end
local toggle=button("ВКЛЮЧИТЬ ПОЛЁТ",10,35,212,39,Color3.fromRGB(66,118,192))
local minus=button("−",10,104,47,34,Color3.fromRGB(60,66,85))
local plus=button("+",175,104,47,34,Color3.fromRGB(60,66,85))
local up=button("↑ ВВЕРХ",10,148,101,43,Color3.fromRGB(49,105,89))
local down=button("↓ ВНИЗ",121,148,101,43,Color3.fromRGB(106,72,96))
local speedLabel=new("TextLabel",frame,{
    Size=UDim2.fromOffset(115,54),
    Position=UDim2.fromOffset(59,83),
    BackgroundTransparency=1,
    Text="Скорость\n100",
    TextSize=14,TextColor3=Color3.fromRGB(228,235,248),
    Font=Enum.Font.GothamSemibold,TextWrapped=true
})

local speed=100
local active=false
local flying=nil
local heartbeat=nil
local touchesUp,touchesDown={},{}
local connections={}
local cameraConn
local function resize()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local v=camera.ViewportSize
    local s=math.max(0.42,math.min(1,(v.X-20)/232,(v.Y-20)/202))
    scale.Scale=s
    local w,h=232*s,202*s
    local x=frame.Position.X.Scale*v.X+frame.Position.X.Offset
    local y=frame.Position.Y.Scale*v.Y+frame.Position.Y.Offset
    frame.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,v.X-w)),math.clamp(y,0,math.max(0,v.Y-h)))
end
local function onCamera()
    if cameraConn then cameraConn:Disconnect() end
    local camera=workspace.CurrentCamera
    if camera then cameraConn=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
table.insert(connections,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(onCamera))
onCamera()
do
    local dragging,startPos,oldPos
    heading.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=input
            startPos=input.Position
            oldPos=frame.Position
        end
    end)
    table.insert(connections,UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input~=dragging and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local delta=input.Position-startPos
        frame.Position=UDim2.fromOffset(oldPos.X.Offset+delta.X,oldPos.Y.Offset+delta.Y)
        resize()
    end))
    table.insert(connections,UIS.InputEnded:Connect(function(input)
        if dragging==input then dragging=nil end
    end))
end

local function hold(button,storage)
    button.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch
            or input.UserInputType==Enum.UserInputType.MouseButton1 then
            storage[input]=true
        end
    end)
end
hold(up,touchesUp)
hold(down,touchesDown)
table.insert(connections,UIS.InputEnded:Connect(function(input)
    touchesUp[input]=nil
    touchesDown[input]=nil
end))
local function changeSpeed(amount)
    speed=math.clamp(speed+amount,25,400)
    speedLabel.Text="Скорость\n"..tostring(speed)
end
minus.MouseButton1Click:Connect(function() changeSpeed(-25) end)
plus.MouseButton1Click:Connect(function() changeSpeed(25) end)

local controls
task.spawn(function()
    local ok,result=pcall(function()
        local pm=require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
        return pm:GetControls()
    end)
    if ok then controls=result end
end)

local function horizontal()
    if controls then
        local ok,m=pcall(function() return controls:GetMoveVector() end)
        local cam=workspace.CurrentCamera
        if ok and typeof(m)=="Vector3" and cam then
            local r=cam.CFrame.RightVector
            local f=cam.CFrame.LookVector
            r=Vector3.new(r.X,0,r.Z)
            f=Vector3.new(f.X,0,f.Z)
            if r.Magnitude>0.01 and f.Magnitude>0.01 then
                local dir=r.Unit*m.X-f.Unit*m.Z
                return dir.Magnitude>1 and dir.Unit or dir
            end
        end
    end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.MoveDirection or Vector3.zero
end
local function vertical()
    local u=next(touchesUp)~=nil or UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E)
    local d=next(touchesDown)~=nil or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.RightControl) or UIS:IsKeyDown(Enum.KeyCode.Q)
    return (u and 1 or 0)-(d and 1 or 0)
end

local function stop()
    active=false
    if heartbeat then heartbeat:Disconnect();heartbeat=nil end
    local f=flying
    flying=nil
    if f then
        if f.lv then f.lv:Destroy() end
        if f.ao then f.ao:Destroy() end
        if f.attachment then f.attachment:Destroy() end
        if f.hum and f.hum.Parent then
            f.hum.AutoRotate=f.rotation
            if f.hum.Health>0 then f.hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end
    table.clear(touchesUp)
    table.clear(touchesDown)
    toggle.Text="ВКЛЮЧИТЬ ПОЛЁТ"
    toggle.BackgroundColor3=Color3.fromRGB(66,118,192)
end
local function start()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then return end
    local a=Instance.new("Attachment")
    a.Name="ManualFlyAttachment"
    a.Parent=root
    local lv=Instance.new("LinearVelocity")
    lv.Attachment0=a
    lv.RelativeTo=Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    lv.ForceLimitsEnabled=false
    lv.VectorVelocity=Vector3.zero
    lv.Parent=root
    local ao=Instance.new("AlignOrientation")
    ao.Attachment0=a
    ao.Mode=Enum.OrientationAlignmentMode.OneAttachment
    ao.Responsiveness=18
    ao.MaxTorque=1e7
    ao.CFrame=root.CFrame
    ao.Parent=root
    flying={root=root,hum=hum,rotation=hum.AutoRotate,lv=lv,ao=ao,attachment=a}
    hum.AutoRotate=false
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    active=true
    toggle.Text="ВЫКЛЮЧИТЬ ПОЛЁТ"
    toggle.BackgroundColor3=Color3.fromRGB(174,65,87)
    heartbeat=RunService.Heartbeat:Connect(function()
        local f=flying
        if not f or not f.root.Parent or not f.lv.Parent or f.hum.Health<=0 then
            stop()
            return
        end
        local move=horizontal()
        local target=move+Vector3.new(0,vertical(),0)
        if target.Magnitude>1 then target=target.Unit end
        f.lv.VectorVelocity=target*speed
        if move.Magnitude>0.1 then
            f.ao.CFrame=CFrame.lookAt(Vector3.zero,move.Unit)
        end
    end)
end
toggle.MouseButton1Click:Connect(function()
    if active then stop() else start() end
end)
table.insert(connections,player.CharacterAdded:Connect(stop))
gui.Destroying:Connect(function()
    stop()
    if cameraConn then cameraConn:Disconnect() end
    for _,con in ipairs(connections) do con:Disconnect() end
end)
print("Manual Fly loaded: joystick/WASD, hold UP/DOWN, speed plus/minus")
