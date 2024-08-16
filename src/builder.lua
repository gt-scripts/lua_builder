local config = {
    preCode = '',
    compileServerClient = false
}
local patternKeys = {
    server_scripts = 'server',
    server_script = 'server',
    client_scripts = 'client',
    client_script = 'client',
    shared_scripts = 'shared',
    shared_script = 'shared'
}

local pluralKeys = {
    server_script = 'server_scripts',
    client_script = 'client_scripts',
    shared_script = 'shared_scripts',
    file = 'files',
    ignore_server_script = 'ignore_server_scripts',
    ignore_client_script = 'ignore_client_scripts',
    ignore_shared_script = 'ignore_shared_scripts',
    ignore_file = 'ignore_files'
}

local singularKeys = {
    server_scripts = 'server_script',
    client_scripts = 'client_script',
    shared_scripts = 'shared_script',
    files = 'file',
    ignore_server_scripts = 'ignore_server_script',
    ignore_client_scripts = 'ignore_client_script',
    ignore_shared_scripts = 'ignore_shared_script',
    ignore_files = 'ignore_file'
}

local directoryKeys = {
    server_scripts = true,
    server_script = true,
    client_scripts = true,
    client_script = true,
    shared_scripts = true,
    shared_script = true,
    files = true,
    ignore_server_scripts = true,
    ignore_server_script = true,
    ignore_client_scripts = true,
    ignore_client_script = true,
    ignore_shared_scripts = true,
    ignore_shared_script = true,
    ignore_files = true,
    transfer = true
}

local function toString(o)
    if type(o) == 'table' then
        local parts = {}
        for k, v in pairs(o) do
            local key = type(k) == 'number' and '[' .. k .. ']' or '["' .. tostring(k) .. '"]'
            table.insert(parts, key .. ' = ' .. toString(v))
        end
        return '{ ' .. table.concat(parts, ', ') .. ' }'
    else
        return tostring(o)
    end
end

function tableInsert(table, value)
    table[#table + 1] = value
end

function loadManifest() -- load manifest as a normal code
    print('\27[32mStarting build!')
    print('\27[34m')
    local code = readFile('resource/fxmanifest.lua')
    local manifestCommands = {} -- all commands in manifest

    function registerManifestCommand(key, firstCommand)
        if pluralKeys[key] then
            insertInManifestCommands(pluralKeys[key], firstCommand) -- this freaking thing is because fivem sucks on manifest by permitting singulars and plural calls (im just transforming them into plural, its better XD)
        else
            insertInManifestCommands(key, firstCommand)
        end
    end

    function insertInManifestCommands(key, command)
        -- create, if does not exist, a plural command, because singular commands will be called here by being plural commands
        if singularKeys[key] and not manifestCommands[key] then
            manifestCommands[key] = {{}}
        end
        if singularKeys[key] and type(command) == 'string' then -- If true, OBVIOUSLY IS A SINGULAR COMMAND THAT WAS PASSED (OR IF THE FUCKING USER FOLLOW WRONG STRUCTURE ON MANIFEST)
            tableInsert(manifestCommands[key][1], command)
        elseif singularKeys[key] then -- also a table in the commands on singularKeys
            for _, dir in ipairs(command) do
                tableInsert(manifestCommands[key][1], dir)
            end
        else
            manifestCommands[key] = {command}
        end
    end

    function registerSecondaryManifestCommand(key, secondCommand)
        manifestCommands[key][2] = secondCommand
    end

    local clone = table.clone(_G)
    local metatable = { -- creating a magic method system do detect manifest commands
        __index = function(t, k, v)
            if clone[k] then
                return clone[k] -- also returns the same value
            else
                return function(firstCommand) -- value that ll be returned to function in manifest
                    registerManifestCommand(k, firstCommand)
                    return
                        function(secondCommand) -- This function is for manifest commands that sucks (data_files, my_data)
                            registerSecondaryManifestCommand(k, secondCommand)
                        end
                end
            end
        end
    }
    setmetatable(_G, metatable)

    load(code)()

    setmetatable(_G, nil) -- removing the magic method system do detect manifest

    createFolder('dist') -- creating the result folder

    createDocument('dist/fxmanifest.lua') -- creating the base manifest

    if config.compileServerClient then
        createDocument('dist/script.lua') -- creating the base shared (compiled server and client) script code
    else
        createDocument('dist/_server.lua') -- creating the base server script code
        createDocument('dist/_client.lua') -- creating the base client script code
    end

    local manifestCommandsHandled = handleManifestCommands(manifestCommands)

    writeScriptContent(manifestCommandsHandled) -- write into script.lua server, client and also shared

    transferIgnoredDirs(manifestCommandsHandled)

    writeManifestContent(manifestCommandsHandled) -- writing commands into manifest
end

function transferIgnoredDirs(manifestCommands)
    for command, v in pairs(manifestCommands) do
        if command:sub(1, 7) == 'ignore_' then
            local rCommand = command:sub(8)
            local ignoredDirs = v[1]
            for _, dir in pairs(ignoredDirs) do
                transferFiles({
                    files = {{dir}}
                })
                if not manifestCommands[rCommand] then
                    manifestCommands[rCommand] = {{}}
                end
                table.insert(manifestCommands[rCommand][1], dir)
            end
        end
    end
end

function writeManifestContent(manifestCommands)
    local manifestContent = {'fx_version', writeText(manifestCommands.fx_version[1]), '', 'game',
                             writeText(manifestCommands.game[1]), ''}

    manifestCommands.fx_version = nil
    manifestCommands.game = nil

    for k, v in pairs(manifestCommands) do
        if not patternKeys[k] or k:sub(1, 7) == 'ignore_' then
            local command = k
            if k:sub(1, 7) == 'ignore_' then
                command = k:sub(8)
            end
            table.insert(manifestContent, command)
            for _, dir in ipairs(v) do
                table.insert(manifestContent, writeText(dir))
            end
            table.insert(manifestContent, '\n\n')
        end
    end

    if config.compileServerClient then
        table.insert(manifestContent, 'shared_script "script.lua"')
    else
        table.insert(manifestContent, 'server_script "_server.lua"\n\nclient_script "_client.lua"')
    end

    writeFile('dist/fxmanifest.lua', table.concat(manifestContent, ' '))
end

function writeScriptContent(manifestCommands)
    local serverCodes = getAllSideCode(manifestCommands, 'server')
    local clientCodes = getAllSideCode(manifestCommands, 'client')
    local sharedCodes = getAllSideCode(manifestCommands, 'shared')

    local sharedCode = constructText(sharedCodes)
    local serverCode = constructText(serverCodes)
    local clientCode = constructText(clientCodes)

    local token = string.random(40)

    local baseScriptCode = 'Citizen.CreateThreadNow(function() \n' .. pText(sharedCode)
    local serverScriptCode = baseScriptCode .. pText(serverCode) .. '\nend)'
    local clientScriptCode = baseScriptCode .. pText(clientCode) .. '\nend)'

    serverScriptCode = serverScriptCode:gsub('__isAuth__ = true', '')
    serverScriptCode = config.preCode .. '\n\n' .. serverScriptCode:gsub('__isAuth__', token)

    writeFile('dist/_server.lua', serverScriptCode)
    writeFile('dist/_client.lua', clientScriptCode)

    transferFiles(manifestCommands)

    print('\27[32m\n\n\n\n')
    print('\27[32mYour script was successfully built!')
    print('\27[32mCheck releases on https://github.com/SuricatoX/lua_builder')
end

function transferFiles(manifestCommands)
    local function transferFilesInternal(files)
        if type(files) ~= 'table' then
            return
        end
        for _, dir in pairs(files[1]) do
            local o = dir:split('/')
            local sDirectory = 'dist/'
            for i, value in ipairs(o) do
                if i < #o then
                    if not value:find('@') and not sDirectory:find('@') then
                        createFolder(value, sDirectory)
                    end
                    sDirectory = sDirectory .. value .. '/'
                end
            end
            transferFile('./resource/' .. dir, './dist/' .. dir)
            if dir and dir:endsWith('.lua') and not dir:find('@') then
                handleFile('./dist/' .. dir)
            end
        end
    end

    transferFilesInternal(manifestCommands.files)
    transferFilesInternal(manifestCommands.transfer)
end

function constructText(sideCodes)
    local text = {}
    for _, v in ipairs(sideCodes) do
        table.insert(text, string.format([[_G[%s] = function()
%s
end
_G[%s]()]], writeText(v.name), pText(v.code), writeText(v.name)))
    end
    return table.concat(text, "\n\n")
end

function getAllSideCode(manifestCommands, side)
    local sideCode = {}
    local keysToProcess = {}

    -- Identificar chaves para processamento com base no lado
    for k, v in pairs(manifestCommands) do
        if patternKeys[k] == side then
            table.insert(keysToProcess, k)
        end
    end

    -- Processar chaves identificadas
    for _, key in ipairs(keysToProcess) do
        local dirs = manifestCommands[key][1]
        for _, dir in ipairs(dirs) do
            if not dir:find('@') then
                local name, extension = dir:getFileNameExtension()
                if extension == 'lua' then
                    table.insert(sideCode, {
                        name = dir,
                        code = handleModule(readFile('resource/' .. dir))
                    })
                else
                    transferFiles({
                        files = {dir}
                    })
                    addOnFile('dist/fxmanifest.lua', singularKeys[key] .. ' ' .. writeText(dir))
                end
            end
        end
    end

    return sideCode
end

function handleManifestCommands(manifestCommands)
    local manifestCommandsHandled = {}

    for command, v in pairs(manifestCommands) do
        if directoryKeys[command] then -- Se for um comando de diretório
            local handledDirs = {}
            for _, dir in ipairs(v[1]) do
                local dirs = handleDir(dir)
                for _, handledDir in ipairs(dirs) do
                    table.insert(handledDirs, handledDir)
                end
            end
            manifestCommandsHandled[command] = {handledDirs}
        else
            manifestCommandsHandled[command] = v
        end
    end

    return manifestCommandsHandled
end

function handleDir(_dir)
    local dirs = {
        [_dir] = true
    }
    if _dir:find('%*') then

        local function multipleFolders()
            for dir in pairs(dirs) do
                if dir:find('%*%*') then
                    local preDir, posDir = dir:match('(.-/)%*%*(/.+)')
                    local allFiles = findAllFiles(preDir)
                    local hasFolder = false
                    for f in allFiles:lines() do
                        if f:isAFolder() then
                            hasFolder = true
                            dirs[preDir .. f .. posDir] = true
                            dirs[dir] = nil
                        end
                    end
                    if not hasFolder then
                        dirs[dir] = nil
                    end
                end
            end
        end

        while hasArrayBadDir(dirs, '%*%*') do
            print('[hasArrayBadDir1] Wait loading!')
            table.dump(dirs)
            multipleFolders()
        end

        local function multipleFiles()
            for dir in pairs(dirs) do
                if dir:find('%*%.%*') then
                    local preDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local allFiles = findAllFiles(preDir)
                    local hasFile = false
                    for f in allFiles:lines() do
                        if not f:isAFolder() then
                            hasFile = true
                            dirs[preDir .. f] = true
                            dirs[dir] = nil
                        end
                    end
                    if not hasFile then -- there is no file on the folder, so it need to be ignored, because its tasking all files from the folder, but there is no file on the folder
                        dirs[dir] = nil
                    end
                end
            end
        end

        while hasArrayBadDir(dirs, '%*%.%*') do
            table.dump(dirs)
            print('[hasArrayBadDir2] Wait loading!')
            multipleFiles()
        end

        local function multipleFilesSameExtension()
            for dir, _ in pairs(dirs) do
                if dir:find('%*%.') then
                    local preDir, posDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local _, extension = posDir:getFileNameExtension()
                    local filesInDir = findAllFiles(preDir)
                    for file in filesInDir:lines() do
                        if not file:isAFolder() then
                            local _, fileExtension = file:getFileNameExtension()
                            if fileExtension == extension then
                                dirs[preDir .. file] = true
                            end
                        end
                    end
                    dirs[dir] = nil
                end
            end
        end

        while hasArrayBadDir(dirs, '%*%.') do
            print('[hasArrayBadDir3] Wait loading!')
            multipleFilesSameExtension()
        end

        local function multipleFilesSameName()
            for dir, _ in pairs(dirs) do
                if not dir:find('%.%*') then
                    local preDir, posDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local name, extension = posDir:getFileNameExtension()
                    local filesInDir = findAllFiles(preDir)
                    local fileWithSameNameFound = false
                    for file in filesInDir:lines() do
                        if not file:isAFolder() then
                            local fileName, fileExtension = file:getFileNameExtension()
                            if fileName == name then
                                fileWithSameNameFound = true
                                dirs[preDir .. file] = true
                            end
                        end
                    end
                    if not fileWithSameNameFound then
                        dirs[dir] = nil
                    end
                end
            end
        end

        while hasArrayBadDir(dirs, '%.%*') do
            print('[hasArrayBadDir4] Wait loading!')
            multipleFilesSameName()
        end

        print('Wait loading!')

        return table.invert(dirs)
    end
    return table.invert(dirs)
end

function hasArrayBadDir(arr, badDir)
    for dir in pairs(arr) do
        if dir:find(badDir) then
            return true
        end
    end
    return false
end

function findAllFiles(dir)
    local i, t = 0, {}
    local pFile = io.popen('cd "resource/' .. dir .. '" && ls -1A') -- Linux
    return pFile
end

function writeText(o)
    if type(o) == 'table' then
        local baseString = '{\n'
        for _, v in ipairs(o) do
            baseString = baseString .. p() .. writeText(v) .. ',\n'
        end
        baseString = baseString .. '}'
        return baseString
    end
    return '"' .. tostring(o) .. '"'
end

function p()
    return '    '
end

function pText(text)
    local newString = p()
    for i = 1, #text do
        local c = text:sub(i, i)
        if c:byte() == 10 then
            newString = newString .. c .. p()
        else
            newString = newString .. c
        end
    end
    return newString
end

function handleModule(text)
    return text:gsub('module%(([^,]-)%)', '_G[%1..".lua"]()'):gsub('require%(([^,]-)%)', '_G[%1..".lua"]()')
end

function createFolder(name, dir) -- dir beeing nil, will create on the exacly same dir that run the entire program
    if dir then
        os.execute('cd ' .. dir .. ' && mkdir ' .. name)
    else
        os.execute('mkdir ' .. name)
    end
end

function createDocument(name)
    local file = io.open(name, "w")
    file:close()
end

function readFile(dir)
    local file = io.open(dir, "r")
    if not file then
        error('\27[31m' .. tostring(dir) .. ' this directory doesnt exist')
    end
    local content = file:read("*a")
    io.close(file)
    return content
end

function writeFile(name, text)
    local file = io.open(name, "w")
    file:write(text)
    file:close()
end

function addOnFile(name, text)
    local file2 = io.open(name, "r")
    local content = file2:read("*a")
    local file = io.open(name, "w+")
    file:write(content .. '\n' .. text)
    file:close(file)
    file2:close(file2)
end

function handleFile(name)
    local file2 = io.open(name, "r")
    local content = file2:read("*a")
    local handledContent = handleModule(content)
    file2:close()
    local file = io.open(name, "w")
    file:write(handledContent)
    file:close()
end

function transferFile(oldPath, newPath)
    os.rename(oldPath, newPath)
end

function table:clone()
    local instance = {}
    for k, v in pairs(self) do
        if type(v) == 'table' and self ~= _G and self ~= _ENV and self ~= v then
            instance[k] = table.clone(v)
        else
            instance[k] = v
        end
    end
    return instance
end

function table:dump()
    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k, v in pairs(self) do
            size = size + 1
        end

        local cur_index = 1
        for k, v in pairs(self) do
            if (cache[self] == nil) or (cur_index >= cache[self]) then

                if (string.find(output_str, "}", output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str, "\n", output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                tableInsert(output, output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "[" .. tostring(k) .. "]"
                else
                    key = "['" .. tostring(k) .. "']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = " .. tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = {\n"
                    tableInsert(stack, self)
                    tableInsert(stack, v)
                    cache[self] = cur_index + 1
                    break
                else
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = '" .. tostring(v) .. "'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
        end

        if (#stack > 0) then
            self = stack[#stack]
            stack[#stack] = nil
            depth = cache[self] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    tableInsert(output, output_str)
    output_str = table.concat(output)
end

function string:split(sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for self in string.gmatch(self, "([^" .. sep .. "]+)") do
        t[i] = self
        i = i + 1
    end
    return t
end

function string:isAFolder()
    return not self:find('%.')
end

function string:getFileNameExtension()
    return self:match("(.+)%.(.+)")
end

function table:invert()
    local instance = {}
    for k, v in pairs(self) do
        tableInsert(instance, k)
    end
    return instance
end

local charset = {}

for i = 48, 57 do
    tableInsert(charset, string.char(i))
end
for i = 65, 90 do
    tableInsert(charset, string.char(i))
end
for i = 97, 122 do
    tableInsert(charset, string.char(i))
end

function string.random(length)
    math.randomseed(os.time())
    if length > 0 then
        return '_' .. string.random(length - 1) .. charset[math.random(1, #charset)]
    else
        return ""
    end
end

loadManifest() -- reading the manifest
