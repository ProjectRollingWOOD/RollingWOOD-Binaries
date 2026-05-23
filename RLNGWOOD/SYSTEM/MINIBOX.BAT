@echo off

set LANGPATH=%LANG%

:Locate
if "%LANGPATH%" == "" set LANGPATH=EN
if exist C:\UTIL\MINIBOX\%LANGPATH%\MINIBOX.EXE goto Launch
if "%LANGPATH%" == "EN" goto Failed
set LANGPATH=
goto Locate

:Failed
echo Unable to locate Minibox
rem maybe set an errorlevel here for any dependent batch files or programs.
rem verrlvl 1
goto Done

:Launch
C:\UTIL\MINIBOX\%LANGPATH%\MINIBOX.EXE %1 %2 %3 %4 %5 %6 %7 %8 %9

:Done
set LANGPATH=