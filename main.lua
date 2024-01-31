ffi = require("ffi")

--- create a pointer to a ffi data object
---@param data ffi.cdata*
local function createPointer(data)
    local ptr = ffi.new("void*", data)
    return tonumber(ffi.cast("uint64_t", ptr))
end

local communicators = {}
local receivers = {}

function NewThreadCommunicator(thread)
    local t = {
        thread = thread,
        sendChannel = love.thread.newChannel(),
        receiveChannel = love.thread.newChannel(),

        receivingSharedData = {}, -- only allows receiving from the thread
        sendingSharedData = {},   -- only allows sending to the thread
        sharedData = {},          -- allows both sending and receiving but can be blocked by the thread for memory safety

    }

    table.insert(communicators, t)
    return t
end

--- create a new shared ffi data object
---@param self any
---@param type "send" | "receive" | "shared"
---@param data ffi.cdata*
---@param ffiType string
---@param name string
function NewSharedFFIData(self, type, data, ffiType, name)
    local ptr = createPointer(data)

    assert(type == "send" or type == "receive" or type == "shared", "invalid type")

    local sharedData = { type = type, ptr = ptr, data = data, name = name, ffiType = ffiType }
    if type == "send" then
        table.insert(self.sendingSharedData, sharedData)
    elseif type == "receive" then
        table.insert(self.receivingSharedData, sharedData)
    elseif type == "shared" then
        table.insert(self.sharedData, sharedData)
    end

    self.thread:send(sharedData)
end

function UpdateThreadPointerData()
    for _, self in ipairs(communicators) do
        -- create connections
        local msg = self.receiveChannel:pop()
        while msg do
            local ptr = msg.ptr
            ptr = ffi.cast("void*", ptr)
            ptr = ffi.new(msg.ffiType, ptr)
            local data = { ptr = ptr, data = ptr, name = msg.name, ffiType = msg.ffiType, type = msg.type }

            if msg.type == "send" then
                table.insert(self.sendingSharedData, data)
            elseif msg.type == "receive" then
                table.insert(self.receivingSharedData, data)
            elseif msg.type == "shared" then
                table.insert(self.sharedData, data)
            end
            msg = self.receiveChannel:pop()
        end
    end
end

function NewThreadReceiver(send, receive)
    local t = {
        sendChannel = send,
        receiveChannel = receive,
    }

    table.insert(receivers, t)
    return t
end
