@echo off

set PATH=%cd%\lib\wxlua;%cd%\lib\mecab\bin;%cd%\lib\;%cd%\lib\libvips;%PATH%

wxlua ./src/main.lua
