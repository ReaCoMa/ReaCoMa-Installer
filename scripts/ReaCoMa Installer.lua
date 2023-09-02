--[[
@author James Bradbury
@description ReaCoMa Installer
@version 0.0.2
@provides
	[main] ReaCoMa Installer.lua
@about
	# ReaCoMa Installer

	A ReaPacka page that provides a script to install ReaCoMa automatically.
]]

local r = reaper
function print(p)
	r.ShowConsoleMsg(p)
	r.ShowConsoleMsg('\n')
end

-- A bunch of functions to make life simple
function doubleQuotePath(path)
	return '"'..path..'"'
end

function getFileExtension(filePath)
    return filePath:match("%.([^.]+)$") or ''
end

function splitLine(string)
    -- Splits an <input_string> seperated by line endings into a table
    local t = {}
    for split in string.gmatch(string, "(.-)\r?\n") do
        table.insert(t, split)
    end
    return t
end

function cli(parts)
	local invocation = ''
	for i=1, #parts do invocation = invocation .. parts[i] .. ' ' end
	local shellOutput = r.ExecProcess(invocation, 0)
	local result = splitLine(shellOutput)
	return {
		code = result[1],
		stdout = result[2]
	}
end

-- Constants
local resourcePath = r.GetResourcePath()
local scriptPath = resourcePath .. '/Scripts'
local reacomaVersion = '2.10.0'

-- Check that ImGui is installed
if not r.APIExists('ImGui_GetVersion') then
	r.ShowMessageBox(
		'ReaImGui needs to be installed. You can install it through ReaPack. ReaPack will now be opened.',
		'ReaCoMa Installation Error!',
		0
	)
	r.ReaPack_BrowsePackages('ReaImGui: ReaScript binding for Dear ImGui')
	return
end

-- Now check operating system and install
local os = r.GetOS()
if os == 'macOS-arm64' or os == 'OSX64' then
	local outputPath = doubleQuotePath(scriptPath..'/output.dmg')
	local downloadCmd = cli({
		'/usr/bin/curl',
		'-L',
		'https://github.com/ReaCoMa/ReaCoMa-2.0/releases/download/2.10.0/ReaCoMa.2.0.dmg',
		'--output',
		outputPath
	})

	if downloadCmd.code == 0 then
		reaper.ShowMessageBox(
			'The installer failed to download the ReaCoMa release.',
			'ReaCoMa Installation',
			0
		)
		return
	end

	cli({
		'/usr/bin/hdiutil',
		'attach',
		outputPath
	})

	cli({
		'/bin/cp',
		'-r',
		doubleQuotePath('/Volumes/ReaCoMa/ReaCoMa 2.0'),
		doubleQuotePath(scriptPath)
	})

	cli({
		'/usr/bin/hdiutil',
		'detach',
		'/Volumes/ReaCoMa'
	})

	cli({
		'/bin/rm',
		outputPath
	})
elseif os == 'Win64' then
	reaper.ShowMessageBox(
		'This installation method is not yet supported on Windows.',
		'ReaCoMa Installation',
		'0'
	)
elseif os == 'Other' then
	reaper.ShowMessageBox(
		'This installation method is not yet supported on Linux.',
		'ReaCoMa Installation',
		'0'
	)
end

-- Register ReaCoMa scripts as actions
local reacomaPath = string.format('%s/ReaCoMa 2.0', scriptPath)

local i = 0
repeat
	local retval = reaper.EnumerateFiles( reacomaPath, i )
	if retval and getFileExtension(retval) == 'lua' then
		local luaScriptPath = string.format('%s/%s', reacomaPath, retval)
		reaper.AddRemoveReaScript(true, 0, luaScriptPath, true)
	end
	i = i + 1
until not retval

reaper.ShowMessageBox(
	'ReaCoMa was successfully installed.',
	'ReaCoMa Installation',
	0
)
