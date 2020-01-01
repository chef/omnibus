echo "--- system details"
$Properties = 'Caption', 'CSName', 'Version', 'BuildType', 'OSArchitecture'
Get-CimInstance Win32_OperatingSystem | Select-Object $Properties | Format-Table -AutoSize

$Env:Path +=";C:\Program Files\Git\usr\bin"

ruby -v
bundle --version
gem -v
bundle env
tar --version

echo "--- bundle install"
bundle install --jobs=7 --retry=3 --without docs debug

echo "+++ bundle exec rake functional "
bundle exec rake functional

exit $LASTEXITCODE