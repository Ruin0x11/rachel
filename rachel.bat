@echo off

set PATH=%cd%\lib\wxlua;%cd%\lib\mecab\bin;%cd%\lib\;%PATH%

wxlua ./src/main.lua
rem C:\Users\yuno\build\wxlua\wxLua\outd\bin\Debug\wxLua.exe ./src/main.lua
