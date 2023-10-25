--[[
@author James Bradbury
@description ReaCoMa Installer
@version 0.0.3
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

function getTempDirUnix()
	local handle = io.popen('echo $TMPDIR')
	local result = handle:read('*a')
	return string.gsub(result, "\n", "")
end

function cli(parts)
	local invocation = ''
	for i=1, #parts do invocation = invocation .. parts[i] .. ' ' end
	local shellOutput = r.ExecProcess(invocation, 0)
	if shellOutput == nil then
		return {
			code = -999,
			stdout = 'Shell output failed in REAPER ExecProcess'
		}
	end
	local result = splitLine(shellOutput)
	local returnCode = tonumber(result[1]) or -999
	local returnOutput = ''
	for i=2, #result do
		returnOutput = returnOutput .. result[i]
	end
	return {
		code = returnCode,
		stdout = returnOutput
	}
end

-- Constants
local resourcePath = r.GetResourcePath()
local scriptPath = string.format('%s/Scripts', resourcePath)

-- Get user consent
local consent = r.ShowMessageBox(
	'ReaCoMa Installer will now download and install the ReaCoMa package. This will require an internet connection and may take a moment.\n\nIt will download the ReaCoMa repository and copy it to the REAPER resource path and remove any existing versions of ReaCoMa. If you have any modifications or unsaved changes to the code, please cancel this script.',
	'ReaCoMa Installer',
	1
)
if consent == 2 then 
	return
end

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
	local outputPath = getTempDirUnix()..'reacoma.dmg'
	local checkCurlExists = cli({
		'/usr/bin/which',
		'curl'
	})
	if checkCurlExists.code ~= 0 then
		reaper.ShowMessageBox(
			'The curl command line executable does not exist on this machine or is in a non-standard location. It is needed to download ReaCoMa.',
			'ReaCoMa Installation',
			0
		)
		return
	end
	local downloadCmd = cli({
		'/usr/bin/curl',
		'-L',
		'https://github.com/ReaCoMa/ReaCoMa-2.0/releases/download/2.10.2/ReaCoMa.2.0.dmg',
		'--output',
		doubleQuotePath(outputPath)
	})

	if downloadCmd.code ~= 0 then
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
		doubleQuotePath(outputPath)
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
		doubleQuotePath(outputPath)
	})
elseif os == 'Win64' then
	local outputPath = string.format('%s/reacoma.zip', scriptPath)
	local checkCurlExists = cli({'curl', '--version'})
	if checkCurlExists.code ~= 0 then
		reaper.ShowMessageBox(
			'The curl command line executable does not exist on this machine or is in a non-standard location. It is needed to download ReaCoMa.',
			'ReaCoMa Installation',
			0
		)
		return
	end

	local downloadCmd = cli({
		'curl.exe',
		'-L',
		'https://github.com/ReaCoMa/ReaCoMa-2.0/releases/download/2.10.2/ReaCoMa.2.0.zip',
		'--output',
		doubleQuotePath(outputPath)
	})

	if downloadCmd.code ~= 0 then
		reaper.ShowMessageBox(
			'The installer failed to download the ReaCoMa release.',
			'ReaCoMa Installation',
			0
		)
		return
	end

	local unzipArchive = cli({
		'powershell.exe',
		'Expand-Archive',
		'-Path',
		doubleQuotePath(outputPath),
		'-DestinationPath',
		doubleQuotePath(scriptPath)
	})

	if unzipArchive.code ~= 0 then
		print('failed to unzip')
		return
	end

	local downloadedZipOutput = string.format('%s/ReaCoMa 2.0/ReaCoMa 2.0', scriptPath)
	local moveFiles = cli({
		'powershell.exe',
		'Copy-Item',
		'-Path',
		doubleQuotePath(downloadedZipOutput),
		'-Destination',
		doubleQuotePath(scriptPath),
		'-Recurse'
	})
elseif os == 'Other' then
	reaper.ShowMessageBox(
		'This installation method is not yet supported on Linux.',
		'ReaCoMa Installation',
		'0'
	)
	return
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
	'ReaCoMa was successfully installed. For each tool an action has been added to the action list.',
	'ReaCoMa Installation',
	0
)
