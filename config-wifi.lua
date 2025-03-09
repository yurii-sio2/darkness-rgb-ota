wifi.sta.autoconnect(1)
wifi.setmode(wifi.STATION, true)
wifi.sta.sleeptype(wifi.MODEM_SLEEP)

station_cfg = {}
station_cfg.ssid = wifiCnf.ssid
station_cfg.pwd = wifiCnf.pwd
-- to enable wifi uncomment this line
wifi.sta.config(station_cfg)
