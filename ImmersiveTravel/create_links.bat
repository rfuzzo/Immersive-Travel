@ECHO off

rem get the environment variable with name TES3PATH
set "location=%TES3PATH%\Data Files"
set "cd=%CD%"

echo gamepath: %location%

mklink /J "%location%\MWSE\mods\ImmersiveTravel" "%cd%\00 Core\MWSE\mods\ImmersiveTravel"

mklink /J "%location%\MWSE\mods\ImmersiveTravelEditor" "%cd%\99 Editor\MWSE\mods\ImmersiveTravelEditor"

set "modname=ImmersiveTravel"
echo mo2mods: %MO2MODS%
mklink /J "%MO2MODS%\%modname%" "%cd%\00 Core"

pause

