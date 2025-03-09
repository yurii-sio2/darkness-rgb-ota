-- dofile("mqtt-client.lua");

dofile(activeFolder .. "config.lua");
dofile(activeFolder .. "config-wifi.lua");
dofile(activeFolder .. "light-mode-controller.lua");

local lightModeController = LightModeController.init(ledsCnf, lighSensorCnf)

lightModeController:setModeRandomByMove()
-- lightModeController:setModeWhiteByMove()

lightModeController:start()
