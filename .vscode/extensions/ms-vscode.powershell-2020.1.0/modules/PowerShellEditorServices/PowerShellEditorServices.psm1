#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

if (!$PSVersionTable.PSEdition -or $PSVersionTable.PSEdition -eq "Desktop") {
    Microsoft.PowerShell.Utility\Add-Type -Path "$PSScriptRoot/bin/Desktop/Microsoft.PowerShell.EditorServices.dll"
    Microsoft.PowerShell.Utility\Add-Type -Path "$PSScriptRoot/bin/Desktop/Microsoft.PowerShell.EditorServices.Host.dll"
}
else {
    Microsoft.PowerShell.Utility\Add-Type -Path "$PSScriptRoot/bin/Core/Microsoft.PowerShell.EditorServices.dll"
    Microsoft.PowerShell.Utility\Add-Type -Path "$PSScriptRoot/bin/Core/Microsoft.PowerShell.EditorServices.Protocol.dll"
    Microsoft.PowerShell.Utility\Add-Type -Path "$PSScriptRoot/bin/Core/Microsoft.PowerShell.EditorServices.Host.dll"
}

function Start-EditorServicesHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $HostName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $HostProfileId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $HostVersion,

        [Parameter(ParameterSetName="Stdio",Mandatory=$true)]
        [switch]
        $Stdio,

        [Parameter(ParameterSetName="NamedPipe",Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LanguageServiceNamedPipe,

        [Parameter(ParameterSetName="NamedPipe")]
        [string]
        $DebugServiceNamedPipe,

        [Parameter(ParameterSetName="NamedPipeSimplex",Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LanguageServiceInNamedPipe,

        [Parameter(ParameterSetName="NamedPipeSimplex",Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LanguageServiceOutNamedPipe,

        [Parameter(ParameterSetName="NamedPipeSimplex")]
        [string]
        $DebugServiceInNamedPipe,

        [Parameter(ParameterSetName="NamedPipeSimplex")]
        [string]
        $DebugServiceOutNamedPipe,

        [ValidateNotNullOrEmpty()]
        [string]
        $BundledModulesPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $LogPath,

        [ValidateSet("Normal", "Verbose", "Error", "Diagnostic")]
        $LogLevel = "Normal",

        [switch]
        $EnableConsoleRepl,

        [switch]
        $DebugServiceOnly,

        [string[]]
        $AdditionalModules = @(),

        [string[]]
        [ValidateNotNull()]
        $FeatureFlags = @(),

        [switch]
        $WaitForDebugger
    )

    $editorServicesHost = $null
    $hostDetails =
        Microsoft.PowerShell.Utility\New-Object Microsoft.PowerShell.EditorServices.Session.HostDetails @(
            $HostName,
            $HostProfileId,
            (Microsoft.PowerShell.Utility\New-Object System.Version @($HostVersion)))

    $editorServicesHost =
        Microsoft.PowerShell.Utility\New-Object Microsoft.PowerShell.EditorServices.Host.EditorServicesHost @(
            $hostDetails,
            $BundledModulesPath,
            $EnableConsoleRepl.IsPresent,
            $WaitForDebugger.IsPresent,
            $AdditionalModules,
            $FeatureFlags)

    # Build the profile paths using the root paths of the current $profile variable
    $profilePaths =
        Microsoft.PowerShell.Utility\New-Object Microsoft.PowerShell.EditorServices.Session.ProfilePaths @(
            $hostDetails.ProfileId,
            [System.IO.Path]::GetDirectoryName($profile.AllUsersAllHosts),
            [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts))

    $editorServicesHost.StartLogging($LogPath, $LogLevel);

    $languageServiceConfig =
        Microsoft.PowerShell.Utility\New-Object Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportConfig

    $debugServiceConfig =
        Microsoft.PowerShell.Utility\New-Object Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportConfig

    switch ($PSCmdlet.ParameterSetName) {
        "Stdio" {
            $languageServiceConfig.TransportType = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::Stdio
            $debugServiceConfig.TransportType    = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::Stdio
            break
        }
        "NamedPipe" {
            $languageServiceConfig.TransportType = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::NamedPipe
            $languageServiceConfig.InOutPipeName = "$LanguageServiceNamedPipe"
            if ($DebugServiceNamedPipe) {
                $debugServiceConfig.TransportType = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::NamedPipe
                $debugServiceConfig.InOutPipeName = "$DebugServiceNamedPipe"
            }
            break
        }
        "NamedPipeSimplex" {
            $languageServiceConfig.TransportType = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::NamedPipe
            $languageServiceConfig.InPipeName = $LanguageServiceInNamedPipe
            $languageServiceConfig.OutPipeName = $LanguageServiceOutNamedPipe
            if ($DebugServiceInNamedPipe -and $DebugServiceOutNamedPipe) {
                $debugServiceConfig.TransportType = [Microsoft.PowerShell.EditorServices.Host.EditorServiceTransportType]::NamedPipe
                $debugServiceConfig.InPipeName = $DebugServiceInNamedPipe
                $debugServiceConfig.OutPipeName = $DebugServiceOutNamedPipe
            }
            break
        }
    }

    if ($DebugServiceOnly.IsPresent) {
        $editorServicesHost.StartDebugService($debugServiceConfig, $profilePaths, $false);
    } elseif($Stdio.IsPresent) {
        $editorServicesHost.StartLanguageService($languageServiceConfig, $profilePaths);
    } else {
        $editorServicesHost.StartLanguageService($languageServiceConfig, $profilePaths);
        $editorServicesHost.StartDebugService($debugServiceConfig, $profilePaths, $true);
    }

    return $editorServicesHost
}

function Compress-LogDir {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Literal path to a log directory.")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    begin {
        function LegacyZipFolder($Path, $ZipPath) {
            if (!(Microsoft.PowerShell.Management\Test-Path($ZipPath))) {
                $zipMagicHeader = "PK" + [char]5 + [char]6 + ("$([char]0)" * 18)
                Microsoft.PowerShell.Management\Set-Content -LiteralPath $ZipPath -Value $zipMagicHeader
                (Microsoft.PowerShell.Management\Get-Item $ZipPath).IsReadOnly = $false
            }

            $shellApplication = Microsoft.PowerShell.Utility\New-Object -ComObject Shell.Application
            $zipPackage = $shellApplication.NameSpace($ZipPath)

            foreach ($file in (Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $Path)) {
                $zipPackage.CopyHere($file.FullName)
                Start-Sleep -MilliSeconds 500
            }
        }
    }

    end {
        $zipPath = ((Microsoft.PowerShell.Management\Convert-Path $Path) -replace '(\\|/)$','') + ".zip"

        if (Get-Command Microsoft.PowerShell.Archive\Compress-Archive) {
            if ($PSCmdlet.ShouldProcess($zipPath, "Create ZIP")) {
                Microsoft.PowerShell.Archive\Compress-Archive -LiteralPath $Path -DestinationPath $zipPath -Force -CompressionLevel Optimal
                $zipPath
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess($zipPath, "Create Legacy ZIP")) {
                LegacyZipFolder $Path $zipPath
                $zipPath
            }
        }
    }
}

function Get-PowerShellEditorServicesVersion {
    $nl = [System.Environment]::NewLine

    $versionInfo = "PSES module version: $($MyInvocation.MyCommand.Module.Version)$nl"

    $versionInfo += "PSVersion:           $($PSVersionTable.PSVersion)$nl"
    if ($PSVersionTable.PSEdition) {
        $versionInfo += "PSEdition:           $($PSVersionTable.PSEdition)$nl"
    }
    $versionInfo += "PSBuildVersion:      $($PSVersionTable.BuildVersion)$nl"
    $versionInfo += "CLRVersion:          $($PSVersionTable.CLRVersion)$nl"

    $versionInfo += "Operating system:    "
    if ($IsLinux) {
        $versionInfo += "Linux $(lsb_release -d -s)$nl"
    }
    elseif ($IsOSX) {
        $versionInfo += "macOS $(lsb_release -d -s)$nl"
    }
    else {
        $osInfo = CimCmdlets\Get-CimInstance Win32_OperatingSystem
        $versionInfo += "Windows $($osInfo.OSArchitecture) $($osInfo.Version)$nl"
    }

    $versionInfo
}

# SIG # Begin signature block
# MIIjigYJKoZIhvcNAQcCoIIjezCCI3cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDR1REVu3GXc3N3
# qzJDWZcPVRVtL7olbpu/BbLfDfMIHqCCDYUwggYDMIID66ADAgECAhMzAAABUptA
# n1BWmXWIAAAAAAFSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTkwNTAyMjEzNzQ2WhcNMjAwNTAyMjEzNzQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCxp4nT9qfu9O10iJyewYXHlN+WEh79Noor9nhM6enUNbCbhX9vS+8c/3eIVazS
# YnVBTqLzW7xWN1bCcItDbsEzKEE2BswSun7J9xCaLwcGHKFr+qWUlz7hh9RcmjYS
# kOGNybOfrgj3sm0DStoK8ljwEyUVeRfMHx9E/7Ca/OEq2cXBT3L0fVnlEkfal310
# EFCLDo2BrE35NGRjG+/nnZiqKqEh5lWNk33JV8/I0fIcUKrLEmUGrv0CgC7w2cjm
# bBhBIJ+0KzSnSWingXol/3iUdBBy4QQNH767kYGunJeY08RjHMIgjJCdAoEM+2mX
# v1phaV7j+M3dNzZ/cdsz3oDfAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU3f8Aw1sW72WcJ2bo/QSYGzVrRYcw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzQ1NDEzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AJTwROaHvogXgixWjyjvLfiRgqI2QK8GoG23eqAgNjX7V/WdUWBbs0aIC3k49cd0
# zdq+JJImixcX6UOTpz2LZPFSh23l0/Mo35wG7JXUxgO0U+5drbQht5xoMl1n7/TQ
# 4iKcmAYSAPxTq5lFnoV2+fAeljVA7O43szjs7LR09D0wFHwzZco/iE8Hlakl23ZT
# 7FnB5AfU2hwfv87y3q3a5qFiugSykILpK0/vqnlEVB0KAdQVzYULQ/U4eFEjnis3
# Js9UrAvtIhIs26445Rj3UP6U4GgOjgQonlRA+mDlsh78wFSGbASIvK+fkONUhvj8
# B8ZHNn4TFfnct+a0ZueY4f6aRPxr8beNSUKn7QW/FQmn422bE7KfnqWncsH7vbNh
# G929prVHPsaa7J22i9wyHj7m0oATXJ+YjfyoEAtd5/NyIYaE4Uu0j1EhuYUo5VaJ
# JnMaTER0qX8+/YZRWrFN/heps41XNVjiAawpbAa0fUa3R9RNBjPiBnM0gvNPorM4
# dsV2VJ8GluIQOrJlOvuCrOYDGirGnadOmQ21wPBoGFCWpK56PxzliKsy5NNmAXcE
# x7Qb9vUjY1WlYtrdwOXTpxN4slzIht69BaZlLIjLVWwqIfuNrhHKNDM9K+v7vgrI
# bf7l5/665g0gjQCDCN6Q5sxuttTAEKtJeS/pkpI+DbZ/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCFVswghVXAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAFSm0CfUFaZdYgAAAAA
# AVIwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJLG
# T/11GRTAww7q9dhcKfqBkiYtrm+ZsRCV6z2asDzWMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAb4c8NkelIo+G18rYppTHiuObVYWBqD/NH2Nw
# W8fxrK0DT4KvhOyHYIARNj1x2E+6AY5y+dQD78mKjJKyso6x+iDGX0TXX+I70SeB
# T3biZMOGAu5G8vJ8i1XlRa1atTFQPwbSYR+VxdixQkbTUaf4f0eZHn7smRTaLsQ0
# sLeSSKmEzVc+ILNWSVjZsktKsLC5AGR8f1q8hK7XnPK4QgtO5FHLp+A70xkGyPdq
# xt/Vi2335xWsyYEGCZOuP2DleMoUyLYGAXEdZdPqwU5zqkS2rYPJ0gj3I1ktxC8q
# wrhV9nSR8/kzax0eliJi7IF+OJz5ZkkMPvsy7UXG1yslY0KW66GCEuUwghLhBgor
# BgEEAYI3AwMBMYIS0TCCEs0GCSqGSIb3DQEHAqCCEr4wghK6AgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCAPMBURWngkcodR28b1lod5m7cbVPwzigFN
# AjqOHKm0XwIGXfuQ8YvtGBMyMDIwMDExMzIzMTU0NS45MzdaMASAAgH0oIHQpIHN
# MIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjoxMkJDLUUzQUUtNzRFQjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDjwwggTxMIID2aADAgECAhMzAAABIfexgZsjRNcMAAAA
# AAEhMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTExMzIxNDA0MloXDTIxMDIxMTIxNDA0MlowgcoxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVy
# aWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjEyQkMtRTNB
# RS03NEVCMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Ah4aX8dhsoAEppJN+m/5YWA
# OKUf1Mtd0UbqWOnc1KVXhyfUTkQ7S4RvgJxHlqyXF49itbTdGH3SSKiCBcEcLj5a
# mESLzBlkqGvIPTnzDKGT2YZtOpYpi7ifl+EJVR4MidCodphAfk6eeY03+Th4VmHR
# hJ8glxjCXI+TJAvVAdLrrnR8vobuR8L1taFxnAXEBGs6y7cxtreJZuo8KMWI2gxf
# f9FuAh6mqcQ//KDxHBgo56zZnDHNF7fWh3Z4EyiFf0y/FDrOaWEy/l/TWmAzuhRY
# AEr31r5Kz+Ns6MRN+qQYQFmsfFIU+uypuPtl68/hTfUTLpADrfi4NZSrBqNnxwID
# AQABo4IBGzCCARcwHQYDVR0OBBYEFIJtosXMbdxf57gMHROp3XbSXvQcMB8GA1Ud
# IwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeGRWh0
# dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKG
# Pmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwDQYJKoZIhvcNAQELBQADggEBAJnIZ6CfVZSKNf8NDkE6qtxiW+AbTrTW93yF
# tSZVOcfNPkDj9iQs0fsB8vnoWuDn3km6wWiOPlylb+2Vm1/QwWF9jSY6UzIBMNR/
# NBYcqoISTzF6f5kG4ZG+lKQkOCpXVZbLwNXtfD+8X7emO5ojPmWJvhiGc7TJEIs5
# 9IQBlTJ2eoVgyAPBWv9WcMRzIh5cwGDwOyWKb1Z36Z2CSH8dJrnvQSONErEFjYk6
# 0O7UyKnfTOSJT2fxsuwKVw0yVq8PqmA4y+cpTfr+rhrAvhVznwM0uAdcY9yg6c/w
# 0WqPNluBm+SCwCgVrL24vjO5fk4z4LhPvrRFwHBCWMA7FvmwYk8wggZxMIIEWaAD
# AgECAgphCYEqAAAAAAACMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBD
# ZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3
# MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RUENWl
# CgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBED/Fg
# iIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeR
# X4FUsc+TTJLBxKZd0WETbijGGvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd/Xcf
# PfBXday9ikJNQFHRD5wGPmd/9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaRtogI
# Neh4HLDpmc085y9Euqf03GS9pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQABo4IB
# 5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvF
# M2hahW1VMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAP
# BgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjE
# MFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kv
# Y3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEF
# BQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSABAf8E
# gZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Pr
# psz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOM
# zPRgEop2zEBAQZvcXBf/XPleFzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCv
# OA8X9S95gWXZqbVr5MfO9sp6AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9Va8v
# /rbljjO7Yl+a21dA6fHOmWaQjP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8+n99
# lmqQeKZt0uGc+R38ONiU9MalCpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+Y1kl
# D3ouOVd2onGqBooPiRa6YacRy5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh2rBQ
# Hm+98eEA3+cxB6STOvdlR3jo+KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRyzR30
# uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoouLGp
# 25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx16HS
# xVXjad5XwdHeMMD9zOZN+w2/XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341Hgi6
# 2jbb01+P3nSISRKhggLOMIICNwIBATCB+KGB0KSBzTCByjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MTJCQy1FM0FF
# LTc0RUIxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoB
# ATAHBgUrDgMCGgMVAK/Gozto6gPrwhnSvhHQV1CqY7tpoIGDMIGApH4wfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDhxwSmMCIY
# DzIwMjAwMTEzMjMwMDU0WhgPMjAyMDAxMTQyMzAwNTRaMHcwPQYKKwYBBAGEWQoE
# ATEvMC0wCgIFAOHHBKYCAQAwCgIBAAICHw0CAf8wBwIBAAICEegwCgIFAOHIViYC
# AQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEK
# MAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQButtF9eWlLcVSMBJKK6pB17fru
# qA+7c8PfXKv2RDrRCvL1SPXkmajA+KH7UtKpJz8uIEZmh9JXbHDxtzQv4NoSSBXQ
# aJI7vz2Ln3pRRbJUAFHi9Lpmq4e5nsYPe/i/ZAFos6ZmFITz/o+VfzZGB37ziAOM
# QvWQtX/rnmN3zdJhpDGCAw0wggMJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwAhMzAAABIfexgZsjRNcMAAAAAAEhMA0GCWCGSAFlAwQCAQUAoIIB
# SjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIKaR
# EA4j0PPhfXcGOaoHaLqeipvE2/mBKG8zOeBYZS8lMIH6BgsqhkiG9w0BCRACLzGB
# 6jCB5zCB5DCBvQQg/hFsk1fpuwAwAZXwRTU7vmo0LfHeZKeO7Wl4aPq052AwgZgw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAASH3sYGbI0TX
# DAAAAAABITAiBCDaRBS7Ynep0iwNU6ECmkaZMU7XSaqF8QSLjWPPa4yTwjANBgkq
# hkiG9w0BAQsFAASCAQBWZkxubFkgJ5tGanCK/4a5Dk1y2BXPymOwbBo8Key3o3Zo
# yp9M05TSPErxNjlKqNrHC7CQFhGWdHTliszTxLahz0Q/kpU0ujW1BODWrc1Er/o0
# YKcrpJ4wu09+6VS5qYSVVIo+H+xjtGBl671UzKHW7ArmN9BDqHpqNubqpm77KLT4
# IuR5W4UGArbsYDgYsQmKD/MPxx900AIH7EvqjbYVNiD6r4Cd1VT9jxqFIEet6oiZ
# sN0PWLPUgTzZmzexjRS65Ph1A3xfNBog0YPu/sUEuBsO7P5/loZAmD3Rxy58Y1Q2
# QssZ4Yrzcs0pv6ZfIAsZWZ8Nkkh2IowigFlQwJ0W
# SIG # End signature block
