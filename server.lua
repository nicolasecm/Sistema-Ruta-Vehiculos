loadstring( exports.Notificaciones:dxGetNotifications( ) )( )

local vehicle
local ped
local pathNodes = {}
local currentNodeIndex = 1
local graphId
local isServerControlling = false
local moveVehicleTimer
local missionTimer
local moneyPickup
local missionInterval = 10 * 60 * 1000
local blipSafe
local rewardAmount
local endMarker 

local routes = {
    {
        start = {1127.1689453125, -1396.32421875, 13.43830871582},
        endPos = {823.10601806641, -1785.0557861328, 13.717483520508},
        rotation_initial = 95,
        reward = 10000
    },
    {
        start = {1962.3802490234, -2163.9533691406, 13.3828125},
        endPos = {1713.5965576172, -1279.8236083984, 13.3828125},
        rotation_initial = 2,
        reward = 12000
    },
}

function startMission()
    if isElement(vehicle) then return end

    local route = routes[math.random(#routes)]
    local startX, startY, startZ = unpack(route.start)
    local endX, endY, endZ = unpack(route.endPos)
    local rotation_vehicle = route.rotation_initial
    rewardAmount = route.reward or 10000

    if not graphId then
        graphId = loadPathGraph("nodes.json")
        if not graphId then
            outputDebugString("Error al cargar el gráfico.")
            return
        end
    end

    findShortestPathBetween(graphId, startX, startY, startZ, endX, endY, endZ, function(nodes)
        if nodes then
            pathNodes = nodes
            currentNodeIndex = 1

            vehicle = createVehicle(428, startX, startY, startZ + 1, 0, 0, rotation_vehicle)
            ped = createPed(71, startX, startY, startZ + 1)
            warpPedIntoVehicle(ped, vehicle)
            setVehicleColor(vehicle, 0, 0, 0, 0, 0, 0)

            addEventHandler("onVehicleDamage", vehicle, function(loss)
                local newLoss = loss * 0.25
                local health = getElementHealth(source)
                setElementHealth(source, health - newLoss)
                
                cancelEvent()
                
                if getElementHealth(source) <= 250 then 
                    endMission(false)
                end
            end)

            blipSafe = createBlipAttachedTo(vehicle, 51, 2, 255, 255, 255, 255)
            setElementData(blipSafe, "description", "Vehículo de seguridad")

            endMarker = createMarker(endX, endY, endZ - 2, "cylinder", 8, 255, 0, 0, 0)

            addEventHandler("onMarkerHit", endMarker, onVehicleReachEnd)

            triggerClientEvent("onServerSendPath", resourceRoot, ped, vehicle, nodes)

            setTimer(checkPlayersNearVehicle, 2000, 0)

            if isTimer(moveVehicleTimer) then killTimer(moveVehicleTimer) end
            moveVehicleTimer = setTimer(serverControlVehicle, 25, 0)

            addNotification(root, "¡Un vehículo blindado ha comenzado su ruta! Deténlo para obtener la recompensa.", "info")
        else
            outputDebugString("No se encontró un camino.")
        end
    end)
end

-- Iniciar la misión cada 10 minutos
missionTimer = setTimer(startMission, missionInterval, 0)
addEventHandler("onResourceStart", resourceRoot, startMission) -- Iniciar misión al arrancar el recurso

-- Función para mover el vehículo desde el servidor
function serverControlVehicle()
    if not isElement(vehicle) then
        if isTimer(moveVehicleTimer) then killTimer(moveVehicleTimer) end
        return
    end

    -- Verificar si el peatón sigue existiendo
    if not isElement(ped) then
        endMission(false)
        return
    end

    if getElementHealth(vehicle) <= 250 then -- Umbral para evitar que siga moviéndose estando en llamas
        endMission(false)
        return
    end

    -- Mover el vehículo a lo largo del camino
    local currentNode = pathNodes[currentNodeIndex]
    local nextNode = pathNodes[currentNodeIndex + 1]


    if not nextNode then
        -- Si no hay un siguiente nodo, mantenemos el vehículo en su posición actual
        return
    end
    
    local x1, y1, z1 = currentNode[1], currentNode[2], currentNode[3]
    local x2, y2, z2 = nextNode[1], nextNode[2], nextNode[3]

    -- Obtener la posición actual del vehículo
    local vx, vy, vz = getElementPosition(vehicle)

    -- Calcular la distancia al siguiente nodo
    local distanceToNextNode = getDistanceBetweenPoints2D(vx, vy, x2, y2)

    -- Si el vehículo está cerca del siguiente nodo, avanzar al siguiente nodo
    if distanceToNextNode < 2 then
        currentNodeIndex = currentNodeIndex + 1
        if currentNodeIndex >= #pathNodes then
            endMission(true)
            return
        end
        -- Actualizar los nodos actuales
        currentNode = pathNodes[currentNodeIndex]
        nextNode = pathNodes[currentNodeIndex + 1]
        x1, y1, z1 = currentNode[1], currentNode[2], currentNode[3]
        x2, y2, z2 = nextNode[1], nextNode[2], nextNode[3]
    end

    -- Calcular el vector de dirección
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    local nodeDistance = math.sqrt(dx * dx + dy * dy + dz * dz)

    -- Calcular el porcentaje de avance entre los nodos
    local t = ((vx - x1) * dx + (vy - y1) * dy) / (nodeDistance^2)
    t = math.min(math.max(t + 0.01, 0), 1) -- Incrementar t ligeramente para avanzar

    -- Calcular la nueva posición
    local nx = x1 + dx * t
    local ny = y1 + dy * t
    local nz = z1 + dz * t + 1 -- Agregar 1 unidad para asegurar que esté sobre el suelo

    -- Calcular la rotación hacia el siguiente punto
    local rotation = findRotation(vx, vy, x2, y2)
    setElementRotation(vehicle, 0, 0, rotation)

    -- Mover el vehículo a la nueva posición
    setElementPosition(vehicle, nx, ny, nz)
end

-- Función para verificar si hay jugadores cerca del vehículo
function checkPlayersNearVehicle()
    if not isElement(vehicle) then return end

    local players = getElementsByType("player")
    local vehiclePos = Vector3(getElementPosition(vehicle))
    local isPlayerNear = false

    for _, player in ipairs(players) do
        if isElement(player) and getElementDimension(player) == getElementDimension(vehicle) then
            local playerPos = Vector3(getElementPosition(player))
            if (vehiclePos - playerPos).length <= 100 then -- Distancia de 100 unidades
                isPlayerNear = true
                break
            end
        end
    end

    if not isPlayerNear and not isServerControlling then
        -- No hay jugadores cerca, el servidor toma el control
        isServerControlling = true
        -- Encontrar el nodo más cercano al vehículo
        updateCurrentNodeIndex()
        if isTimer(moveVehicleTimer) then killTimer(moveVehicleTimer) end
        moveVehicleTimer = setTimer(serverControlVehicle, 25, 0)
        outputDebugString("Servidor tomando control del vehículo.")
    elseif isPlayerNear and isServerControlling then
        -- Hay jugadores cerca, el servidor libera el control
        isServerControlling = false
        if isTimer(moveVehicleTimer) then killTimer(moveVehicleTimer) end
        outputDebugString("Servidor liberando control del vehículo.")
    end
end

-- Función para actualizar currentNodeIndex al nodo más cercano al vehículo
function updateCurrentNodeIndex()
    if not isElement(vehicle) then return end
    local vx, vy, vz = getElementPosition(vehicle)
    local closestDistance = math.huge
    for i = 1, #pathNodes do
        local node = pathNodes[i]
        local distance = getDistanceBetweenPoints3D(vx, vy, vz, node[1], node[2], node[3])
        if distance < closestDistance then
            closestDistance = distance
            currentNodeIndex = i
        end
    end
end

-- Recibir la posición y rotación desde el cliente
addEvent("onClientSendVehicleState", true)
addEventHandler("onClientSendVehicleState", resourceRoot, function(x, y, z, rx, ry, rz, nodeIndex)
    if isElement(vehicle) then
        setElementPosition(vehicle, x, y, z)
        setElementRotation(vehicle, rx, ry, rz)
        currentNodeIndex = nodeIndex or currentNodeIndex
    end
end)

-- Función para finalizar la misión
function endMission(completed)
    if isTimer(moveVehicleTimer) then killTimer(moveVehicleTimer) end
    if isTimer(checkPlayersTimer) then killTimer(checkPlayersTimer) end

    -- Verificar si el vehículo fue destruido o el peatón ya no existe
    if not completed then
        if isElement(vehicle) then
            local x, y, z = getElementPosition(vehicle)
            -- Crear un pickup de dinero
            moneyPickup = createPickup(x, y, z, 3, 1550, 0)
            addEventHandler("onPickupHit", moneyPickup, onMoneyPickupHit)

            -- Enviar mensaje global
            addNotification(root, "¡El vehículo blindado ha sido detenido! Busca la recompensa.", "info")
        end
    else
        addNotification(root, "El vehículo blindado completó su ruta. Nadie obtuvo la recompensa.", "warn")
    end

    -- Eliminar el vehículo y el peatón
    if isElement(vehicle) then destroyElement(vehicle) end
    if isElement(ped) then destroyElement(ped) end
    if isElement(blipSafe) then
        destroyElement(blipSafe)
        blipSafe = nil
    end

    -- Eliminar el marcador si existe
    if isElement(endMarker) then
        destroyElement(endMarker)
        endMarker = nil
    end

    vehicle = nil
    ped = nil
    isServerControlling = false
    currentNodeIndex = 1
    pathNodes = {}
end

-- Evento cuando el vehículo es destruido
addEventHandler("onVehicleExplode", root, function()
    if source == vehicle then
        endMission(false)
    end
end)

-- Evento cuando el peatón muere
addEventHandler("onPedWasted", root, function()
    if source == ped then
        endMission(false)
    end
end)

-- Función cuando un jugador recoge el pickup de dinero
function onMoneyPickupHit(player)
    if getElementType(player) == "player" and isElement(player) then
        -- Dar recompensa al jugador
        givePlayerMoney(player, rewardAmount)
        addNotification(root, getPlayerName(player) .. " ha recogido la recompensa del vehículo blindado.", "success")
        addNotification(player, "has recogido la recompensa del vehículo blindado y has ganado $"..rewardAmount, "success")
        if isElement(moneyPickup) then destroyElement(moneyPickup) end
        moneyPickup = nil
    end
end

function findRotation(x1, y1, x2, y2)
    local t = -math.deg(math.atan2(x2 - x1, y2 - y1))
    return t < 0 and t + 360 or t
end

function onVehicleReachEnd(hitElement)
    if hitElement == vehicle then
        endMission(true)
    end
end

-- Añadir el event handler para reparar las llantas desde el cliente
addEvent("onClientRepairTires", true)
addEventHandler("onClientRepairTires", resourceRoot, function(vehicle)
    if isElement(vehicle) then
        setVehicleWheelStates(vehicle, 0, 0, 0, 0)
    end
end)
