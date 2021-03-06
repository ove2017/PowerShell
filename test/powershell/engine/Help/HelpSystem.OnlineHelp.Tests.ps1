# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Describe 'Online help tests for PowerShell Core Cmdlets' -Tags "CI" {

    # The csv files (V2Cmdlets.csv and V3Cmdlets.csv) contain a list of cmdlets and expected HelpURIs.
    # The HelpURI is part of the cmdlet metadata, and when the user runs 'get-help <cmdletName> -online'
    # the browser navigates to the address in the HelpURI. However, if a help file is present, the HelpURI
    # on the file take precedence over the one in the cmdlet metadata.

    BeforeAll {
        $SavedProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"

        # Enable the test hook. This does the following:
        # 1) get-help will not find a help file; instead, it will generate a metadata driven object.
        # 2) get-help -online <cmdletName>  will return the helpuri instead of opening the default web browser.
        [system.management.automation.internal.internaltesthooks]::SetTestHook('BypassOnlineHelpRetrieval', $true)
    }

    AfterAll {

        # Disable the test hook
        [system.management.automation.internal.internaltesthooks]::SetTestHook('BypassOnlineHelpRetrieval', $false)
        $ProgressPreference = $SavedProgressPreference
    }

    foreach ($filePath in @("$PSScriptRoot\assets\HelpURI\V2Cmdlets.csv", "$PSScriptRoot\assets\HelpURI\V3Cmdlets.csv"))
    {
        $cmdletList = Import-Csv $filePath -ea Stop

        foreach ($cmdlet in $cmdletList)
        {
            # If the cmdlet is not preset in CoreCLR, skip it.
            $skipTest = $null -eq (Get-Command $cmdlet.TopicTitle -ea SilentlyContinue)

            # TopicTitle - is the cmdlet name in the csv file
            # HelpURI - is the expected help URI in the csv file

            It "Validate 'get-help $($cmdlet.TopicTitle) -Online'" -Skip:$skipTest {
                $actualURI = Get-Help $cmdlet.TopicTitle -Online
                $actualURI = $actualURI.Replace("Help URI: ","")
                $actualURI | Should -Be $cmdlet.HelpURI
            }
        }
    }
}

Describe 'Get-Help -Online opens the default web browser and navigates to the cmdlet help content' -Tags "Feature" {

    $skipTest = [System.Management.Automation.Platform]::IsIoT -or
                [System.Management.Automation.Platform]::IsNanoServer

    # this code is a workaround for issue: https://github.com/PowerShell/PowerShell/issues/3079
    if((-not ($skipTest)) -and $IsWindows)
    {
        $skipTest = $true
        $regKey = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"

        try
        {
            $progId = (Get-ItemProperty $regKey).ProgId
            if($progId)
            {
                if (-not (Test-Path 'HKCR:\'))
                {
                    New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR | Should NotBeNullOrEmpty
                }
                $browserExe = ((Get-ItemProperty "HKCR:\$progId\shell\open\command")."(default)" -replace '"', '') -split " "
                if ($browserExe.count -ge 1)
                {
                    if($browserExe[0] -match '.exe')
                    {
                        $skipTest = $false
                    }
                }
            }
        }
        catch
        {
            # We are not able to access Registry, skipping test.
        }
    }

    It "Get-Help get-process -online" -skip:$skipTest {
        { Get-Help get-process -online } | Should -Not -Throw
    }
}

Describe 'Get-Help -Online is not supported on Nano Server and IoT' -Tags "CI" {

    $skipTest = -not ([System.Management.Automation.Platform]::IsIoT -or [System.Management.Automation.Platform]::IsNanoServer)

    It "Get-help -online <cmdletName> throws InvalidOperation." -skip:$skipTest {

        try
        {
            Get-Help Get-Help -Online
            throw "Execution should not have succeeded"
        }
        catch
        {
            $_.FullyQualifiedErrorId | Should -Be "InvalidOperation,Microsoft.PowerShell.Commands.GetHelpCommand"
        }
    }
}
