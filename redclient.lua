require("cap_utils")

RedClient = {}
RedClient.__index = RedClient

function RedClient:new()
    o = {}
    setmetatable(o, RedClient)
    return o
end

function RedClient:set_modem(modem)
    self.modem = modem
end

function RedClient:_extract_address(address)
    local address_parts_1 = cap_utils.split_str(address, ".")
    if #address_parts_1 ~= 2 then
        error(string.format("Address invalid: %s", address))
    end
    local hostname = address_parts_1[1]
    local address_parts_2 = cap_utils.split_str(address_parts_1[2], "/")
    if #address_parts_2 ~= 2 then
        error(string.format("Address invalid: %s", address))
    end
    local domain = address_parts_2[1]
    local endpoint = address_parts_2[2]
    return hostname, domain, endpoint
end

function RedClient:_transmit(modem, request, hostname, domain)
    rednet.open(modem)
    local id = rednet.lookup(domain, hostname)
    if id ~= nil then
        print(string.format("Target server offline: %s", hostname .. "." .. domain))
    end
    rednet.send(id, request, domain)
    local _, response = rednet.receive(domain, 5)
    rednet.close(modem)
    return response
end

function RedClient:get(address)
    if self.modem == nil then
        error("Modem not set")
    end
    local hostname, domain, endpoint = self:_extract_address(address)
    local checksum = cap_utils.sha256(hostname .. endpoint)
    local request = { endpoint = endpoint, method = "get", checksum = checksum }
    local response = self:_transmit(self.modem, request, hostname, domain)
    if response == nil then
        return { success = false, payload = { message = "No response received" } }
    end
    if response.checksum ~= cap_utils.sha256(hostname .. response.payload) then
        return { success = false, payload = { message = "Checksum invalid" } }
    end
    return { success = response.success, payload = textutils.unserialiseJSON(response.payload) }
end

function RedClient:post(address, payload)
    if self.modem == nil then
        error("Modem not set")
    end
    local hostname, domain, endpoint = self:_extract_address(address)
    payload = textutils.serialiseJSON(payload)
    local checksum = cap_utils.sha256(hostname .. payload)
    local request = { endpoint = endpoint, method = "post", payload = payload, checksum = checksum }
    local response = self:_transmit(self.modem, request, hostname, domain)
    if response == nil then
        return { success = false, payload = { message = "No response received" } }
    end
    if response.checksum ~= cap_utils.sha256(hostname .. response.payload) then
        return { success = false, payload = { message = "Checksum invalid" } }
    end
    return { success = response.success, payload = textutils.unserialiseJSON(response.payload) }
end
