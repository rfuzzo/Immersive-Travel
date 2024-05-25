@ECHO off

rem get the environment variable with name TES3PATH
set "location=%TES3PATH%\Data Files"
set "cd=%CD%"

echo gamepath: %location%

mklink /J "%location%\MWSE\mods\ImmersiveVehicles" "%cd%\MWSE\mods\ImmersiveVehicles"

set "modname=Immersive Vehicles"
echo mo2mods: %MO2MODS%
mklink /J "%MO2MODS%\%modname%" "%cd%"

pause

