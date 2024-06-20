require("cap_utils")

RedServerErrors = {
    callback_invalid = "Endpoint registration failed: callback of type %s is not a function",
    endpoint_exists = "Endpoint registration failed: endpoint %s already exists",
    method_invalid = "Endpoint registration failed: method invalid; must be `get` or `post`; received %s",
    modem_not_found = "Server startup failed: modem %s not found",
    address_invalid = "Server startup failed: address %s is not a valid address",
    malformed_request = "Received malformed request:\n%s"
}

RedServer = { get = {}, post = {} }
RedServer.__index = RedServer

function RedServer:new()
    o = {}
    setmetatable(o, RedServer)
    return o
end

function RedServer:_error(err_name, arg, critical)
    critical = critical or true
    print(string.format(RedServerErrors[err_name], arg))
    if critical then
        error()
    end
end

function RedServer:register(endpoint, method, callback)
    if type(callback) ~= "function" then
        self:_error("callback_invalid", type(callback))
    end
    if method == "get" then
        if self.get[endpoint] ~= nil then
            self:_error("endpoint_exists", method .. ":" .. endpoint)
        end
        self.get[endpoint] = callback
    elseif method == "post" then
        if self.post[endpoint] ~= nil then
            self:_error("endpoint_exists", method .. ":" .. endpoint)
        end
        self.post[endpoint] = callback
    else
        self:_error("method_invalid", method)
    end
end

function RedServer:_construct_response(success, payload)
    local response = {}
    response.success = success
    if type(payload) == "string" then
        response.payload = { message = payload }
    else
        response.payload = payload
    end
    response.payload = textutils.serialiseJSON(response.payload)
    response.checksum = cap_utils.sha256(self.hostname .. response.payload)
    return response
end

function RedServer:_process_get(request)
    if self.get[request.endpoint] == nil then
        return self:_construct_response(false, string.format("Method not allowed on endpoint %s", request.endpoint))
    end
    if request.checksum ~= cap_utils.sha256(self.hostname .. request.endpoint) then
        return self:_construct_response(false, "Checksum malformed")
    end
    return self:_construct_response(true, self.get[request.endpoint]())
end

function RedServer:_process_post(request)
    if self.post[request.endpoint] == nil then
        return self:_construct_response(false, string.format("Method not allowed on endpoint %s", request.endpoint))
    end
    if request.checksum ~= cap_utils.sha256(self.hostname .. request.payload) then
        return self:_construct_response(false, "Checksum malformed")
    end
    return self:_construct_response(true, self.post[request.endpoint](textutils.unserialiseJSON(request.payload)))
end

function RedServer:listen(modem, address)
    local address_parts = cap_utils.split_str(address, ".")
    if #address_parts ~= 2 then
        self:_error("address_invalid", address)
    end
    self.domain = address_parts[2]
    self.hostname = address_parts[1]
    if not peripheral.isPresent(modem) then
        self:_error("modem_not_found", modem)
    end
    rednet.open(modem)
    rednet.host(self.domain, self.hostname)
    while (true) do
        local id, request = rednet.receive(self.domain)
        if request.endpoint == nil or request.method == nil or request.checksum == nil then
            self:_error("malformed_request", request, false)
            rednet.send(id, self:_construct_response(false, "Request malformed"))
        end
        if request.method == "get" then
            rednet.send(id, self:_process_get(request))
        elseif request.method == "post" then
            if request.payload == nil then
                self:_error("malformed_request", request, false)
                rednet.send(id, self:_construct_response(false, "Request malformed"))
            end
            rednet.send(id, self:_process_post(request))
        else
            self:_error("malformed_request", request, false)
            rednet.send(id, self:_construct_response(false, "Request malformed"))
        end
    end
end
