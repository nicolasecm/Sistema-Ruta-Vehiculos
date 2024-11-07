function GetMarrot(angle, rz)
    local marrot = 0
    if(angle > rz) then
        marrot = -(angle - rz)
    else
        marrot = rz - angle
    end

    if(marrot > 180) then
        marrot = marrot - 360
    elseif(marrot < -180) then
        marrot = marrot + 360
    end
    return marrot
end

function findRotation(x1, y1, x2, y2)
    local t = -math.deg(math.atan2(x2 - x1, y2 - y1))
    return t < 0 and t + 360 or t
end

local currentNodeIndex = 1
local nodes = {}
local thePed, theVehicle
local isControlling = false
local followPathTimer

addEvent("onServerSendPath", true)
addEventHandler("onServerSendPath", resourceRoot, function(ped, vehicle, pathNodes)
    thePed = ped
    theVehicle = vehicle
    nodes = pathNodes
    currentNodeIndex = 1
    isControlling = true
    if isTimer(followPathTimer) then killTimer(followPathTimer) end
    followPathTimer = setTimer(followPath, 50, 0)
end)

-- Función para actualizar el bot
function followPath()
    if not isControlling then return end

    if currentNodeIndex <= #nodes then
        -- Actualizar la posición y rotación del jugador y del vehículo
        local target = nodes[currentNodeIndex]
        local px, py, pz  = target[1], target[2], target[3]
        local vx, vy, vz = getElementPosition(theVehicle)
        local vrx, vry, vrz = getElementRotation(theVehicle)
        local brakes = false
        local maxspd = 40
        local vehreverse = false
        local distance = getDistanceBetweenPoints2D(px, py, vx, vy)
        if distance < 8 then
            currentNodeIndex = currentNodeIndex + 1
            if currentNodeIndex > #nodes then
                setPedControlState(thePed, "handbrake", true)
                setPedAnalogControlState(thePed, "accelerate", 0)
                setPedAnalogControlState(thePed, "brake_reverse", 0)
                isControlling = false
                return
            else
                px, py, pz = nodes[currentNodeIndex][1], nodes[currentNodeIndex][2], nodes[currentNodeIndex][3]
            end
        end

        -- Aplicar lógica de frenado o movimiento según la distancia
        if brakes then
            setPedAnalogControlState(thePed, "accelerate", 0)
            setPedAnalogControlState(thePed, "brake_reverse", 0)
            setPedControlState(thePed, "handbrake", true)
            setElementVelocity(theVehicle, 0, 0, 0)
        else
            -- Calcular velocidad y rotación necesaria
            local vxv, vyv, vzv = getElementVelocity(theVehicle)
            local s = (vxv^2 + vyv^2 + vzv^2)^(0.5) * 156 -- Velocidad
            local rot = GetMarrot(findRotation(vx, vy, px, py), vrz)

            -- Ajustar la dirección y velocidad del vehículo
            if rot > 80 then 
                if rot > 100 then vehreverse = true end
                rot = 20 
            elseif rot < -20 then 
                if rot < -80 then vehreverse = true end
                rot = -20 
            end

            if vehreverse then
                setPedAnalogControlState(thePed, "brake_reverse", 1 - (s * 1 / maxspd))
                setPedAnalogControlState(thePed, "accelerate", 0)
                setPedControlState(thePed, "handbrake", false)
                if s > 10 then
                    setPedControlState(thePed, "handbrake", true)
                else
                    if rot > 0 then
                        setPedAnalogControlState(thePed, "vehicle_left", (rot) / 20)
                    else
                        setPedAnalogControlState(thePed, "vehicle_right", -(rot) / 20)
                    end
                end
            else
                if rot > 0 then
                    setPedControlState(thePed, "handbrake", true)
                    setPedAnalogControlState(thePed, "vehicle_right", (rot) / 20)
                else
                    setPedControlState(thePed, "handbrake", true)
                    setPedAnalogControlState(thePed, "vehicle_left", -(rot) / 20)
                end

                setPedAnalogControlState(thePed, "brake_reverse", 0)
                setPedControlState(thePed, "handbrake", false)
                if s < maxspd then 
                    setPedAnalogControlState(thePed, "accelerate", 1 - (s * 1 / maxspd))
                else
                    setPedAnalogControlState(thePed, "accelerate", 0)
                    setPedAnalogControlState(thePed, "brake_reverse", (s / maxspd) - 1)
                end
            end
        end
    else
        -- Si no hay más nodos, detener el seguimiento
        if isTimer(followPathTimer) then killTimer(followPathTimer) end
    end
end

-- Llamar a followPath cada 50 milisegundos
addEvent("followPath", true)
addEventHandler("followPath", getRootElement(), followPath)

-- Sincronizar posición al servidor cuando el jugador sale del stream del vehículo
addEventHandler("onClientElementStreamOut", root, function()
    if source == theVehicle then
        -- Enviar la posición y rotación actuales al servidor
        local x, y, z = getElementPosition(theVehicle)
        local rx, ry, rz = getElementRotation(theVehicle)
        triggerServerEvent("onClientSendVehicleState", resourceRoot, x, y, z, rx, ry, rz, currentNodeIndex)
        isControlling = false
    end
end)

-- Resetear variables cuando el vehículo es destruido
addEventHandler("onClientElementDestroy", root, function()
    if source == theVehicle then
        isControlling = false
        if isTimer(followPathTimer) then killTimer(followPathTimer) end
    end
end)

addEventHandler("onClientVehicleDamage", root, function(attacker, weapon, loss, x, y, z, tyreID)
    if source == theVehicle and isElement(theVehicle) then
        if tyreID ~= -1 then
            -- Una llanta fue dañada; repararla inmediatamente
            setVehicleWheelStates(theVehicle, 0, 0, 0, 0)
            -- Notificar al servidor para sincronizar el estado de las llantas
            triggerServerEvent("onClientRepairTires", resourceRoot, theVehicle)
        end
    end
end)

-- Función para dibujar el camino
function drawPath()
    if #nodes > 1 then
        for i = 1, #nodes - 1 do
            local x1, y1, z1 = nodes[i][1], nodes[i][2], nodes[i][3]
            local x2, y2, z2 = nodes[i + 1][1], nodes[i + 1][2], nodes[i + 1][3]
            dxDrawLine3D(x1, y1, z1, x2, y2, z2, tocolor(255, 0, 0, 255), 2)
        end
    end
end
addEventHandler("onClientRender", root, drawPath)
