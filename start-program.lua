-- dofile("mqtt-client.lua");

dofile("config.lua");
dofile("config-wifi.lua");
dofile("light-mode-controller.lua");

local lightModeController = LightModeController.init(ledsCnf, lighSensorCnf)

lightModeController:setModeRandomByMove()
-- lightModeController:setModeWhiteByMove()

lightModeController:start()
