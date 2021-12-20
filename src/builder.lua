function loadManifest() -- load manifest as a normal code
    local code = readFile('resource/fxmanifest.lua')
    local manifestCommands = {} -- all commands in manifest

    function registerManifestCommand(key,firstCommand)
        manifestCommands[key] = {firstCommand}
    end

    function registerSecondaryManifestCommand(key, secondCommand)
        manifestCommands[key][2] = secondCommand
    end

    local clone = table.clone(_G)
    local metatable = { -- creating a magic method system do detect manifest commands
        __index = function(t,k,v)
            if clone[k] then
                return clone[k] -- also returns the same value
            else
                return function(firstCommand) -- value that ll be returned to function in manifest
                    registerManifestCommand(k, firstCommand)
                    return function(secondCommand) -- This function is for manifest commands that sucks (data_files, my_data)
                        registerSecondaryManifestCommand(k, secondCommand)
                    end
                end
            end
        end
    }
    setmetatable(_G, metatable)

    load(code)()

    setmetatable(_G, nil) -- removing the magic method system do detect manifest

    createFolder('dist') -- Creating the result folder

    createDocument('dist/fxmanifest.lua') -- Creating the base manifest

    createDocument('dist/script.lua') -- Creating the base script code

    writeManifestContent(manifestCommands) -- Writing commands into manifest
end

local patternKeys = {
    server_scripts = true,
    server_script = true,
    client_scripts = true,
    client_script = true,
    shared_scripts = true,
    shared_script = true
}

function writeManifestContent(manifestCommands)
    local manifestContent = 'fx_version ' -- Creating base string

    manifestContent = manifestContent..writeText(manifestCommands.fx_version[1])..'\n' -- Base start into manifest
    manifestContent = manifestContent..'game '..writeText(manifestCommands.game[1])..'\n' -- Base start into manifest

    manifestCommands.fx_version = nil
    manifestCommands.game = nil

    for k,v in pairs(manifestCommands) do
        if not patternKeys[k] then
            manifestContent = manifestContent .. k .. ' '        
            for _,dir in ipairs(v) do
                manifestContent = manifestContent .. writeText(dir) .. ' '
            end
        end
        manifestContent = manifestContent .. '\n'
    end

    print(manifestContent)
    writeFile('dist/fxmanifest.lua', manifestContent)
end

function writeText(o)
    if type(o) == 'table' then
        local baseString = '{\n'
        for _,v in ipairs(o) do
            baseString = baseString..'    '..writeText(v)..',\n'
        end
        baseString = '\n'..baseString..'}'
        return baseString
    end
    return '"' .. tostring(o) .. '"'
end

function createFolder(name, dir) -- dir beeing nil, will create on the exacly same dir that run the entire program
    if dir then
        os.execute('cd '..dir..' && mkdir ' .. name)
    else
        os.execute('mkdir ' .. name)
    end
end

function createDocument(name)
    local file = io.open(name, "w") 
    file:close()
end

function readFile(dir)
    local file = io.open(dir,"r")
    local content = file:read("*a")
    io.close(file)
    return content
end

function writeFile(name, text)
    local file = io.open(name, "w")
    print(2,file:read("*a"))
    file:write(text)
    file:close()
end

function table:clone()
	local instance = {}
	for k,v in pairs(self) do
		if type(v) == 'table' and self ~= _G and self ~= _ENV and self ~= v then
			instance[k] = table.clone(v)
		else
			instance[k] = v
		end
	end
	return instance
end

function table:dump()
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(self) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(self) do
            if (cache[self] == nil) or (cur_index >= cache[self]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,self)
                    table.insert(stack,v)
                    cache[self] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
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
    table.insert(output,output_str)
    output_str = table.concat(output)

    print(output_str)
end

loadManifest() -- reading the manifest