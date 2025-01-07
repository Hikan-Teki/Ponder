Ponder.Environment = Ponder.SimpleClass()

local function NamedList()
    local ret = {}

    ret.Named = {}
    ret.List  = {}

    function ret:Add(item, name)
        if self:Find(name) then self:RemoveByName(name) end

        self.List[#self.List + 1] = item
        self.Named[name] = item
    end

    function ret:Find(name) return self.Named[name] end

    function ret:RemoveByValue(value)
        table.RemoveByValue(self.List, value)
        table.RemoveByValue(self.Named, value)
        return value
    end

    function ret:RemoveByName(name)
        local retObj = self.Named[name]
        table.RemoveByValue(self.List, self.Named[name])
        self.Named[name] = nil

        return retObj
    end

    function ret:Clear()
        table.Empty(self.List)
        table.Empty(self.Named)
    end

    return ret
end

function Ponder.Environment:__new()
    self.ClientsideModels = NamedList()
    self.NamedTextObjects = NamedList()

    self:SetLookParams(1300, 55, 600, vector_origin)
end

function Ponder.Environment:GetCameraPosAng()
    return self.CameraPosition, self.CameraAngles
end

function Ponder.Environment:LookParamsToPosAng(camDist, rotation, height, lookAt)
    local rads = math.rad(rotation)
    local s, c = math.sin(rads) * camDist, math.cos(rads) * camDist
    local campos = Vector(s, c, height)
    local camang = (lookAt - campos):Angle()

    return campos, camang
end

function Ponder.Environment:SetLookParams(camDist, rotation, height, lookAt)
    local rads = math.rad(rotation)
    local s, c = math.sin(rads) * camDist, math.cos(rads) * camDist
    self:SetCameraPosition(Vector(s, c, height))
    self:SetLookAt(lookAt)
    self:SetCameraFOV(15)
end

function Ponder.Environment:NewModel(mdl, name, dontSpawn)
    if self.ClientsideModels:Find(name) then
        local ent = self.ClientsideModels:RemoveByName(name)
        if IsValid(ent) then ent:Remove() end
    end

    local csModel = ClientsideModel(mdl)

    if dontSpawn ~= true then
        csModel:SetPos(vector_origin)
        csModel:Spawn()
    end

    csModel.IsPonderEntity = true
    csModel:SetNoDraw(true)
    csModel.Name = name

    self.ClientsideModels:Add(csModel, name)
    return csModel
end
function Ponder.Environment:GetNamedModel(name) return self.ClientsideModels:Find(name) end
function Ponder.Environment:RemoveModel(model) self.ClientsideModels:RemoveByValue(model):Remove() end
function Ponder.Environment:RemoveModelByName(name)
    local csModel = self.ClientsideModels:Find(name)
    if not IsValid(csModel) then return end

    self.ClientsideModels:RemoveByName(name):Remove()
end

function Ponder.Environment:NewText(name)
    local csModel = Ponder.TextObject()
    self.NamedTextObjects:Add(csModel, name)
    return csModel
end
function Ponder.Environment:GetNamedText(name) return self.NamedTextObjects:Find(name) end
function Ponder.Environment:RemoveText(model) self.NamedTextObjects:RemoveByValue(model) end
function Ponder.Environment:RemoveTextByName(name)
    local txtObj = self.NamedTextObjects:Find(name)
    if not txtObj then return end

    self.NamedTextObjects:RemoveByName(name)
end

function Ponder.Environment:Free()
    for _, v in ipairs(self.ClientsideModels.List) do v:Remove() end
    self.ClientsideModels:Clear()
    self.NamedTextObjects:Clear()
end

function Ponder.Environment:SetCameraPosition(vPos)
    self.CameraPosition = vPos
end

function Ponder.Environment:SetCameraAngles(aAng)
    self.CameraAngles = aAng
end

function Ponder.Environment:SetLookAt(vLookat)
    self.LastLookat = vLookat
    self.CameraAngles = (vLookat - self.CameraPosition):Angle()
end

function Ponder.Environment:ToString()
    return "Ponder Environment"
end

function Ponder.Environment:SetCameraFOV(nFOV)
    self.CameraFOV = nFOV
end

function Ponder.Environment:BuildCamera()
    self.Camera = {
        x = 0,
        y = 0,
        w = ScrW(),
        h = ScrH(),
        type = "3D",
        origin = self.CameraPosition,
        angles = self.CameraAngles,
        fov = self.CameraFOV
    }
end

function Ponder.Environment:AimVector()
    local mX, mY = input.GetCursorPos()
    local mV = util.AimVector(self.Camera.angles, self.Camera.fov, mX, mY, ScrW(), ScrH())
    return mV
end
function Ponder.Environment:AimEntity()
    local pos = self.Camera.origin
    local dir = self:AimVector()
    local stop = pos + (dir * 10000)

    local ret
    local dist = 1000000000

    for _, v in ipairs(self.ClientsideModels.List) do
        local bMI, bMA = v:GetRenderBounds()
        --render.DrawWireframeBox(v:GetPos(), v:GetAngles(), bMI, bMA)
        local test = util.IntersectRayWithOBB(pos, stop, v:GetPos(), v:GetAngles(), bMI, bMA)
        if test then
            local testDist = test:Distance(pos)
            if testDist < dist then
                dist = testDist
                ret = v
            end
        end
    end

    return ret
end

local magnifier = Material("ponder/ui/icon64/magnifier_no_back.png", "mips smooth")

function Ponder.Environment:Render()
    self:BuildCamera()
    cam.Start(self.Camera)
    self.Rendering3D = true
    if self.Fullbright then
        render.SuppressEngineLighting(true)
    end
    self.AimedEntity = self:AimEntity()
    for _, v in ipairs(self.NamedTextObjects.List) do v:ResolvePos2D() end
    for _, v in ipairs(self.ClientsideModels.List) do
        local c = v:GetColor()
        render.SetColorModulation(c.r / 255, c.g / 255, c.b / 255)
        render.SetBlend(c.a / 255)
        v:DrawModel()
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)
    end
    for _, v in pairs(Ponder.API.RegisteredRenderers) do v:Render3D(self) end
    if self.Render3D then self:Render3D() end

    render.SuppressEngineLighting(false)
    self.Rendering3D = false
    cam.End()

    self.Rendering2D = true
    for _, v in ipairs(self.NamedTextObjects.List) do v:Render() end
    for _, v in pairs(Ponder.API.RegisteredRenderers) do v:Render2D(self) end
    if self.Render2D then self:Render2D() end

    if self.Identifying then
        local mX, mY = input.GetCursorPos()
        surface.SetMaterial(magnifier)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawTexturedRectRotated(mX + 8, mY + 9, 64, 64, 0)

        if self.AimedEntity then
            mX = mX + 32
            local name = self.AimedEntity.Name
            surface.SetFont("Ponder.Text")
            local w, h = surface.GetTextSize(name)
            local p = 8
            surface.SetDrawColor(245, 245, 245, 220)
            surface.DrawRect(mX - p, mY - p, w + (p * 2), h + (p * 2))
            surface.SetDrawColor(25, 25, 25, 255)
            surface.DrawOutlinedRect(mX - p, mY - p, w + (p * 2), h + (p * 2))

            draw.SimpleText(name, "Ponder.Text", mX + (w / 2), mY + (h / 2), Color(25, 25, 25, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    self.Rendering2D = false

    -- surface.SetDrawColor(255,255,255,255)
    -- surface.DrawOutlinedRect(rX, rY, w, h, 2)
end