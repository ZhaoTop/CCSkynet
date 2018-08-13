local proto = require "proto"
local sproto = require "sproto"
local bit  = require "bit"
local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))
local SimpleTCP = require "SimpleTCP"

local MainScene = class("MainScene", cc.load("mvc").ViewBase)

function MainScene:onCreate()
    -- add background image
    display.newSprite("HelloWorld.png")
        :move(display.center)
        :addTo(self)

    -- add HelloWorld label
    cc.Label:createWithSystemFont("Hello World", "Arial", 40)
        :move(display.cx, display.cy + 200)
        :addTo(self)

    if not self._socket then
		self._socket = SimpleTCP.new("192.168.0.170", 8888, handler(self, self.onTCPEvent))
    	--self._socket = SocketTCP.new("192.168.0.170",8888, false)
        -- self._socket:addEventListener(SocketTCP.EVENT_CLOSE, handler(self,self.onStatus))
        -- self._socket:addEventListener(SocketTCP.EVENT_CLOSED, handler(self,self.onStatus))
        -- self._socket:addEventListener(SocketTCP.EVENT_CONNECT_FAILURE, handler(self,self.onStatus))
        -- self._socket:addEventListener(SocketTCP.EVENT_DATA, handler(self,self.onData))
    end
    self._socket:connect()

end

function MainScene:onTCPEvent(even, data)
	if even == SimpleTCP.EVENT_DATA then
		print("==receive data:", data)
		self:onData(data)
	elseif even == SimpleTCP.EVENT_CONNECTING then
		print("==connecting")
		self.onStatus(even,data)
	elseif even == SimpleTCP.EVENT_CONNECTED then
		print("==connected")
		--self._socket:send("Hello server, i'm SimpleTCP")
		self.onStatus(even,data)
	elseif even == SimpleTCP.EVENT_CLOSED then
		print("==closed")
		self.onStatus(even,data)
		-- you can call self.stcp:connect() again or help user exit game.
	elseif even == SimpleTCP.EVENT_FAILED then
		print("==failed")
		self.onStatus(even,data)
		-- you can call self.stcp:connect() again or help user exit game.
	end
end


local last = ""

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s+2 then
        return nil, text
    end

    return text:sub(3,2+s), text:sub(3+s)
end
local function recv_package(last)
    local result
    result, last = unpack_package(last)
    if result then
        return result, last
    end
    local r = socket.recv(fd)
    if not r then
        return nil, last
    end
    if r == "" then
        error "Server closed"
    end
    return unpack_package(last .. r)
end

local function dispatch_package()
    while true do
        local v
        v, last = recv_package(last)
        if not v then
            break
        end
        print_package(host:dispatch(v))
    end
end

local function print_request(name, args)
    print("REQUEST", name)
    if args then
        for k,v in pairs(args) do
            print(k,v)
        end
    end
end

local function print_response(session, args)
    print("RESPONSE", 0)
    if args then
        for k,v in pairs(args) do
            print(k,v)
        end
    end
end

local function print_package(t, ...)
    if t == "REQUEST" then
        print_request(...)
    else
        assert(t == "RESPONSE")
        print_response(...)
    end
end
local session = 0

local function extract( n, i, j )
    local rNum = bit.rshift(n,i)
    local num = 1
    local sub = bit.band(rNum,bit.lshift(num,j)-1)

    return bit.tobit(sub)
end

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
  	socket.send(fd, package)
end

local function send_request(name, args)
    session = session + 1
    local str = request(name, args, session)
    send_package(fd, str)
    print("Request:", session)
end

print(extract(11,1,1))
print(extract(11,1,2))
print(extract(11,1,4))
function MainScene:onData(__event)
    --local maxLen,version,messageId,msg = self:unpackMessage(__event.data)
    --dispatch_package()
    --dump(__event)
    local data = unpack_package(__event)
    --local data = unpack_package(__event.data)
    print_package(host:dispatch(data))
    print("onData",data)
    -- session = session +1
    -- local str = request("get",{ what = "hello" }, session)
    -- local size = #str
    -- local pack = string.char(extract(size,8,8)) .. string.char(extract(size,0,8)).. str
   
    --self._socket:send(pack)
    session = session + 1
    local str = request("get",{ what = "hello" }, session)
    local size = #str
    local pack = string.char(extract(size,8,8)) .. string.char(extract(size,0,8)) .. str
    print("pack",pack,size,#pack)
    --local package = string.pack(">s2", pack)
    --socket.send(fd, package)

    self._socket:send(pack)
    --print("socket receive raw data:", maxLen,version,messageId,msg)
end

--给服务器发送消息
function MainScene:onStatus(_event)
    print("onStatus",_event)

    if _event == SimpleTCP.EVENT_CONNECTED then
	    session = session + 1
	    local str = request("handshake")
	    local size = #str
	    local pack = string.char(extract(size,8,8)) .. string.char(extract(size,0,8)) .. str
	    print("pack",pack,size,#pack)
	    self._socket:send(pack)
    end


    --local socket = require "clientsocket"
    --local proto = require "proto"
    --local sproto = require "sproto"

    -- local host = sproto.new(proto.s2c):host "package"
    -- local request = host:attach(sproto.new(proto.c2s))
    -- local function send_package(fd, pack)
    --     local package = string.pack(">s2", pack)
    --  socket.send(fd, package)
    -- end

    -- local function send_request(name, args)
    --     session = session + 1
    --     local str = request(name, args, session)
    --     send_package(fd, str)
    --     print("Request:", session)
    -- end
    -- --local fd = self._socket
    -- send_request("handshake")
    -- send_request("set", { what = "hello", value = "world" })
    -- while true do
    --     dispatch_package()
    --     local cmd = socket.readstdin()
    --     if cmd then
    --         send_request("get", { what = cmd })
    --     else
    --         socket.usleep(100)
    --     end
    -- end

    -- local message = self:getProcessMessage (1,1003,stringbuffer)
    -- self._socket:send(message:getPack())
end

function MainScene:sendData( ... )
	-- body

end

return MainScene
