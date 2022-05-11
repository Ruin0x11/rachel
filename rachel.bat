@echo off

set PATH=%cd%\lib\wxlua;%cd%\lib\mecab\bin;%cd%\lib\;%PATH%

wxlua ./src/main.lua
