-- Save your base and teleport to it. Two buttons only.
-- No flight, egg search or inventory edits. Game server may reset a carried egg.
local Players=game:GetService("Players")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")
for _,n in ipairs({"CatboyEggFarmGUI","ManualFlyGUI","TeleportHomeGUI"}) do
 local old=pg:FindFirstChild(n)
 if old then old:Destroy() end
end
local gui=Instance.new("ScreenGui")
gui.Name="TeleportHomeGUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=150
gui.Parent=pg
local function put(t,parent,props)
 local o=Instance.new(t)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent
 return o
end
local frame=put("Frame",gui,{Size=UDim2.fromOffset(284,155),
 Position=UDim2.fromOffset(12,55),BackgroundColor3=Color3.fromRGB(24,27,38),
 BorderSizePixel=0})
put("UICorner",frame,{CornerRadius=UDim.new(0,12)})
put("UIStroke",frame,{Color=Color3.fromRGB(67,85,111),Thickness=1})
local uiScale=put("UIScale",frame,{Scale=1})
local status=put("TextLabel",frame,{Position=UDim2.fromOffset(10,8),
 Size=UDim2.fromOffset(264,31),BackgroundTransparency=1,
 Text="Сначала сохрани точку своей базы",TextWrapped=true,
 TextColor3=Color3.fromRGB(232,237,248),TextSize=12,Font=Enum.Font.GothamMedium})
local function btn(name,y,color)
 local b=put("TextButton",frame,{Position=UDim2.fromOffset(12,y),
 Size=UDim2.fromOffset(260,44),Text=name,
 BackgroundColor3=color,BorderSizePixel=0,
 Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1)})
 put("UICorner",b,{CornerRadius=UDim.new(0,9)})
 return b
end
local save=btn("1. СОХРАНИТЬ БАЗУ",44,Color3.fromRGB(48,105,87))
local tele=btn("2. ТЕЛЕПОРТ ДОМОЙ",99,Color3.fromRGB(68,115,193))
local saved=nil
local busy=false
local function character()
 local c=plr.Character
 local r=c and c:FindFirstChild("HumanoidRootPart")
 local h=c and c:FindFirstChildOfClass("Humanoid")
 if r and h and h.Health>0 then return c,r end
end
local viewportConn
local function fit()
 local cam=workspace.CurrentCamera
 if not cam then return end
 local v=cam.ViewportSize
 local s=math.min(1,math.max(0.55,math.min((v.X-20)/284,(v.Y-20)/155)))
 uiScale.Scale=s
 frame.Position=UDim2.fromOffset(12,math.min(45,math.max(0,v.Y-155*s-4)))
end
local function watch()
 if viewportConn then viewportConn:Disconnect() end
 local cam=workspace.CurrentCamera
 if cam then viewportConn=cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
 fit()
end
local cameraConn=workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
watch()
save.MouseButton1Click:Connect(function()
 if busy then return end
 local _,root=character()
 if not root then status.Text="Персонаж не готов";return end
 saved=root.CFrame
 status.Text="База сохранена. Можешь взять яйцо"
end)
tele.MouseButton1Click:Connect(function()
 if busy then return end
 if not saved then status.Text="Сначала нажми «Сохранить базу»";return end
 local c,root=character()
 if not root then status.Text="Персонаж не готов";return end
 busy=true
 status.Text="Пробую переместиться домой..."
 local goal=saved+Vector3.new(0,2,0)
 local ok,err=pcall(function()
  root.AssemblyLinearVelocity=Vector3.zero
  root.AssemblyAngularVelocity=Vector3.zero
  c:PivotTo(goal)
 end)
 if not ok then
  warn("TeleportHome error",err)
  status.Text="Ошибка телепорта: консоль"
  busy=false
  return
 end
 task.delay(0.8,function()
  if not gui.Parent then return end
  local _,currentRoot=character()
  if currentRoot and (currentRoot.Position-goal.Position).Magnitude<12 then
   status.Text="У базы. Проверь, осталось ли яйцо"
  else
   status.Text="Сервер мог отменить перемещение"
  end
  busy=false
 end)
end)
local spawnConn=plr.CharacterAdded:Connect(function()
 status.Text=saved and "База сохранена" or "Сохрани точку базы"
end)
gui.Destroying:Connect(function()
 if viewportConn then viewportConn:Disconnect() end
 if cameraConn then cameraConn:Disconnect() end
 if spawnConn then spawnConn:Disconnect() end
end)
print("TeleportHome loaded: 2 buttons")
