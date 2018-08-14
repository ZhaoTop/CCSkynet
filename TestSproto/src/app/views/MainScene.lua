local proto = require "proto"
local sproto = require "sproto"
local bit  = require "bit"
local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))
local SessionTCP = require "app.utils.SessionTCP"

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

    local session = SessionTCP:getInstance()
    session:connect()
end


return MainScene
