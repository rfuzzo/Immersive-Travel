@ECHO off

rem get the environment variable with name TES3PATH
set "location=%TES3PATH%\Data Files"
set "cd=%CD%"

echo gamepath: %location%

mklink /J "%location%\MWSE\mods\ImmersiveTravelAddonWorld" "%cd%\MWSE\mods\ImmersiveTravelAddonWorld"


pause

