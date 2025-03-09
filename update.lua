 local http = require("http")
 local cjson = require("cjson")

 local UPDATE_BASE_URL = "http://your-server.com/update/"
 local VERSION_FILE = "version.txt"
 local ACTIVE_FOLDER_FILE = "/active_folder.txt"
 local version_a = "version_a"
 local version_b = "version_b"

 local function getActiveFolder()
     local activeFolder = "version_a"
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
         if not downloadFile(UPDATE_BASE_URL .. filename, folder .. "/" .. filename) then
             success = false
             break
         end

         -- Check the size of the downloaded file
         local fileSize = file.stat(folder .. "/" .. filename).size
         if fileSize ~= expectedSize then
             print("File size mismatch for " .. filename .. ". Expected: " .. expectedSize .. ", Got: " .. fileSize)
             success = false
             break
         end
     end
     return success
 end

 local function update()
     print("Checking for updates...")

     local activeFolder = getActiveFolder()
     local inactiveFolder = (activeFolder == "version_a") and "version_b" or "version_a"

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

 update()