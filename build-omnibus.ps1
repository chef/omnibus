# can be called form SSH like so:
# powershell C:\omnibus\build-omnibus.ps1 'chef-client' 'opscode-full-stack' 'ACCESS_KEY' 'SECRET_KEY'

# legacy chef-full name should be chef-client
if ($args[0] -eq "chef-full") {
  $project_name = "chef-client"
} else {
  $project_name = $args[0]
}
$bucket_name = $args[1]
$s3_access_key = $args[2]
$s3_secret_key = $args[3]
$current_dir = (Split-Path ((Get-Variable MyInvocation -Scope 0).Value).MyCommand.Path) -replace "\\$", ""

Write-Output "Starting omnibus build of $project_name"

$json_attribs = @"
{
  "aws": {
    "access_key": "$s3_access_key",
    "secret_access_key": "$s3_secret_key"
  },
  "omnibus": {
    "$project_name": {
      "version": "10.16.4",
      "iteration": "1",
      "bucket_name": "$bucket_name"
    }
  },
  "run_list": [
    "recipe[omnibus::default]"
  ]
}
"@

Write-Output "Creating JSON file"

$json_attribs | Out-File -Encoding ASCII $current_dir\chef-repo\.chef\omnibus.json

# clean up build related directories if they exist
Write-Output "Cleaning up temporary directories"
@"
C:\opscode
C:\omnibus\pkg
"@ -split "`r`n" | Foreach-Object {
  if ((Test-Path $_) -eq $True) {
    Write-Output "  Removing $_"
    Remove-Item $_ -force -recurse
  }
}

Write-Output "Preparing script"
# (FU) MS - we have to use a script block since Write-Host output doesn't go to STDERR or STDOUT
# https://connect.microsoft.com/PowerShell/feedback/details/283088/script-logging-needs-to-be-improved
$script = {
  param([string] $solo_path)
  Start-Process -FilePath 'git' 'pull' -WorkingDirectory "C:\omnibus" -Wait -NoNewWindow
  Start-Process -FilePath 'chef-solo' "-c $solo_path\solo.rb -j $solo_path\omnibus.json" -Wait -NoNewWindow
}

Write-Output "Executing chef-solo build"
PowerShell -Command $script -args "$current_dir\chef-repo\.chef" >> $ENV:TEMP\omnibus.out 2>&1

Write-Output "Finished build of $project_name"
