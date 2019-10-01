echo "--- system details"
$Properties = 'Caption', 'CSName', 'Version', 'BuildType', 'OSArchitecture'
Get-CimInstance Win32_OperatingSystem | Select-Object $Properties | Format-Table -AutoSize

# Set-Item -Path Env:Path -Value ($Env:Path + ";C:\Program Files\Git\mingw64\bin;C:\Program Files\Git\usr\bin") 
$Env:Path="C:\Program Files\Git\mingw64\bin;C:\Program Files\Git\usr\bin;C:\ruby26\bin;C:\ci-studio-common\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\ProgramData\chocolatey\bin;C:\Program Files\Git\cmd;C:\Users\ContainerAdministrator\AppData\Local\Microsoft\WindowsApps;C:\Go\bin;C:\Users\ContainerAdministrator\go\bin"


ruby -v
bundle --version
gem -v
bundle env

echo "--- bundle install"
bundle install --jobs=7 --retry=3 --without docs debug

echo "+++ bundle exec rake acceptance "
bundle exec cucumber --color --format progress --strict

exit $LASTEXITCODE