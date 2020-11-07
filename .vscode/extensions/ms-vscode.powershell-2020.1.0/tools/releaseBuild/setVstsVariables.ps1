$vstsVariables = @{
    PSES_BRANCH = 'release/1.13.3'
}

# Use VSTS's API to set an env vars
foreach ($var in $vstsVariables.Keys)
{
    if (Get-Item "env:$var" -ErrorAction Ignore)
    {
        continue
    }

    $val = $vstsVariables[$var]
    Write-Host "Setting var '$var' to value '$val'"
    Write-Host "##vso[task.setvariable variable=$var]$val"
}