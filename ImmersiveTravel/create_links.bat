@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\ImmersiveTravel" "%cd%\MWSE\mods\ImmersiveTravel"

pause

