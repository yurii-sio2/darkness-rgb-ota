local http = require("http")
local cjson = require("cjson")

local UPDATE_BASE_URL = "https://yurii-sio2.github.io/darkness-rgb-ota/"
local VERSION_FILE = "version.txt"
local ACTIVE_FOLDER_FILE = "active_folder.txt"
local version_a = "a"
local version_b = "b"

local function getActiveFolder()
    local activeFolder = version_a
    if file.open(ACTIVE_FOLDER_FILE, "r") then
        activeFolder = file.readline():gsub("\n", "")
        file.close()
    end
    return activeFolder
end

local function setActiveFolder(folder)
    file.open(ACTIVE_FOLDER_FILE, "w")
    file.writeline(folder)
    file.close()
end

local function getLocalVersion()
    local version = "0"
    if file.open(VERSION_FILE, "r") then
        version = file.readline():gsub("\n", "")
        file.close()
    end
    return version
end

local function setLocalVersion(version)
    file.open(VERSION_FILE, "w")
    file.writeline(version)
    file.close()
end

local function downloadFile(url, filename)
    print("Downloading: " .. url .. " to " .. filename)
    local success = false
    http.get(url, nil, function(code, data)
        if code < 0 then
            print("Download failed for " .. url)
            return false
        end
        file.open(filename, "w")
        file.write(data)
        file.close()
        print("Downloaded: " .. url .. " to " .. filename)
        success = true
    end)
    return success
end

local function downloadFiles(folder, files)
    local success = true
    for _, fileInfo in ipairs(files) do
        local filename = fileInfo.name
        local expectedSize = fileInfo.size
        if not downloadFile(UPDATE_BASE_URL .. filename, folder .. "_" .. filename) then
            success = false
            break
        end

        local fileSize = file.stat(folder .. "_" .. filename).size
        if fileSize ~= expectedSize then
            print("File size mismatch for " .. filename .. ". Expected: " .. expectedSize .. ", Got: " .. fileSize)
            success = false
            break
        end
    end
    return success
end

local function checkFreeSpace(minRequiredKB)
    local fsInfo = file.fsinfo()
    if fsInfo.free < minRequiredKB * 1024 then
        print("Not enough free space. Required: " .. minRequiredKB .. "KB, Available: " .. (fsInfo.free / 1024) .. "KB")
        return false
    end
    return true
end

local function syncTime()
    sntp.sync("pool.ntp.org", function(sec, us, server, info)
            print ("Seconds: "..sec.." Server: "..server.." Stratum: "..info.stratum)
        end,
        function(errorcode, info)
            print ("SNTP errorcode: "..errorcode.." Info: "..info)
        end,
    true)
end

local function cleanFolder(folder)
    local list = file.list()
    for filename, _ in pairs(list) do
        if string.sub(filename, 1, #folder + 2) == folder .. "_" then
            print("Deleting: " .. filename)
            file.remove(filename)
        end
    end
end

local function update()
    print("Checking for updates...")

    local activeFolder = getActiveFolder()
    local inactiveFolder = (activeFolder == version_a) and version_b or version_a

    if not checkFreeSpace(100) then
        print("Not enough free space to proceed with the update.")
        return
    end

    cleanFolder(inactiveFolder)

    -- Fetch the file list from the server
    http.get(UPDATE_BASE_URL .. "file-list.json", nil, function(code, data)
        if code < 0 then
            print("Failed to check for updates")
            return
        end

        local fileListData = cjson.decode(data)
        local remoteVersion = fileListData.version
        local filesToDownload = fileListData.fileList

        local localVersion = getLocalVersion()

        print("Remote version: " .. remoteVersion)
        print("Local version: " .. localVersion)

        if remoteVersion ~= localVersion then
            print("New update available. Downloading...")

            if downloadFiles(inactiveFolder, filesToDownload) then
                print("All files downloaded successfully. Updating version and rebooting...")
                setLocalVersion(remoteVersion)
                setActiveFolder(inactiveFolder)
                node.restart()
            else
                print("Failed to download all files. Aborting update.")
            end
        else
            print("No new updates available.")
        end
    end)
end

local wifiTimer = tmr.create()
wifiTimer:alarm(1000, 1, function()
    if wifi.sta.getip() == nil then
        print("Obtaining IP...")
    else
        wifiTimer:stop()
        wifiTimer:unregister()
        print("Got IP. "..wifi.sta.getip())

        syncTime()

        -- Wait for time synchronization to complete before proceeding with the update
        local syncTimer = tmr.create()
        syncTimer:alarm(5000, 1, function()
            if rtctime.get() > 0 then
                syncTimer:stop()
                syncTimer:unregister()
                print("Time synchronized. Proceeding with update...")
                update()
            end
        end)
    end
end)
