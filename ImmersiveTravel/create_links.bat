@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\ImmersiveTravel" "%cd%\00 Core\MWSE\mods\ImmersiveTravel"

mklink /J "%location%\MWSE\mods\ImmersiveTravelEditor" "%cd%\99 Editor\MWSE\mods\ImmersiveTravelEditor"


pause

