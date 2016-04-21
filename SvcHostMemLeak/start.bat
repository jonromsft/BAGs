%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Noninteractive -Command "Set-ExecutionPolicy Unrestricted" >> TestResults.log 
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Noninteractive -Command ".\SetupScavengerBitAndRemove.ps1" >> TestResults.log
echo Test exited with exit code %errorlevel%
