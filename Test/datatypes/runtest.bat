@echo off
setlocal

set BOOGIEDIR=..\..\Binaries
set BPLEXE=%BOOGIEDIR%\Boogie.exe

for %%f in (t1.bpl) do (
  echo.
  echo -------------------- %%f --------------------
  %BPLEXE% %* /prover:smtlib /typeEncoding:m %%f
)

