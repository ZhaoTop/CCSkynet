local proto = require "proto"
local sproto = require "sproto"
local bit  = require "bit"
local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))
local SimpleTCP = require "SimpleTCP"
 
local sessionTab = {}               -- 记录函数调用名
local callbackTab = {}              -- 回调函数tab
local listenerTab = {}              -- 监听函数tab
SessionTCP = {}
function SessionTCP:new(o)
	o = o or {}
	setmetatable(o,self)
	self.__index = self
	return o
end
 
function SessionTCP:getInstance()
	if self.instance == nil then
		self.instance = self:new()
	end
	return self.instance
end

function SessionTCP:connect()
    if not self._socket then
        self._socket = SimpleTCP.new("192.168.8.105", 8888, handler(self, self.onTCPEvent))
    end
    self._socket:connect()
    self:addListener("heartbeat",self.heartbeat)
end

-- 注册监听
function SessionTCP:addListener(name, func)
    if listenerTab[name] then
        return 0
    else
        listenerTab[name] = func
    end
    return 1
end

function SessionTCP:onTCPEvent(even, data)
	if even == SimpleTCP.EVENT_DATA then
		print("==receive data:", data)
		self:onData(data)
	elseif even == SimpleTCP.EVENT_CONNECTING then
		print("==connecting")
		self:onStatus(even,data)
	elseif even == SimpleTCP.EVENT_CONNECTED then
		print("==connected")
		--self._socket:send("Hello server, i'm SimpleTCP")
		self:onStatus(even,data)
	elseif even == SimpleTCP.EVENT_CLOSED then
		print("==closed")
		self:onStatus(even,data)
		-- you can call self.stcp:connect() again or help user exit game.
	elseif even == SimpleTCP.EVENT_FAILED then
		print("==failed")
		self:onStatus(even,data)
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
    local func = listenerTab[name]
    if args then
        for k,v in pairs(args) do
            print(k,v)
        end
    end
    --函数调用
    if func then
        func(args)
    else
        print("request ".. name.." not add listener")
    end
end

local function print_response(_session, args)
    print("RESPONSE", _session)
    print("name: ", sessionTab["p".. _session])
    local name = sessionTab["p".. _session]
    local func = callbackTab[name]
    if args then
        for k,v in pairs(args) do
            print(k,v)
        end
    end
    -- 函数调用
    if func then
        func(args)
    else
        print("response ".. name.." not callback")
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
function SessionTCP:onData(_data)

    local data = unpack_package(_data)
    print_package(host:dispatch(data))
    print("onData",data)

    if session > 5 then
        return
    end

    self:sendData("get", { what = "hello" })
end

--给服务器发送消息
function SessionTCP:onStatus(_event)
    print("onStatus",_event)

    if _event == SimpleTCP.EVENT_CONNECTED then
        self:sendData("handshake", nil)
    end
end

function SessionTCP:sendData( name, tabData ,func)
	-- body
    session = session + 1
    local str = request(name,tabData, session)
    local size = #str
    local pack = string.char(extract(size,8,8)) .. string.char(extract(size,0,8)) .. str
    self._socket:send(pack)
    sessionTab["p".. session] = name
    callbackTab[name] = func
    print("session: ", session)
end

--
function SessionTCP:heartbeat()
    print("心跳包")
end

return SessionTCP
