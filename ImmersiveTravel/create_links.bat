@ECHO off

set "location=C:\games\Morrowind\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\ImmersiveTravel" "%cd%\MWSE\mods\ImmersiveTravel"

pause

