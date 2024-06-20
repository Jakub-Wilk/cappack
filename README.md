# cappack

Collection of ComputerCraft packages. Designed to be used with the [tets](https://github.com/Jakub-Wilk/tets) package manager.

## Redserver

An HTTP-inspired very simple server. Usage example:

```lua
require("redserver")

function state_name()
    return { message = "My name is RedServer!" }
end

function print_message(payload)
    print(payload.message)
    return {}
end

server = RedServer:new()

-- supports get endpoints that serve content to the consumer
server:register("name", "get", state_name)

-- supports post endpoints that accept data from the consumer
server:register("message", "post", print_message)

-- supports domain-like addressing - for example the get endpoint would be "example_server.example_domain/name":
server:listen("back", "example_server.example_domain")

```

## Redclient

A request library made to interface with Redserver. Usage example:

```lua
require("redclient")

client = RedClient:new()
client:set_modem("left")

-- request a resource from the server (the example server would return "My name is RedServer!"):
name = client:get("example_server.example_domain/name").payload.message

-- upload a resource to the server (the example server would then print this message):
message = { message = string.format("Hello %s, my name is RedClient!", name) }
client:post("example_server.example_domain/message", message)

```
