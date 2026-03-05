BeforeAll {
    # Import the module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere\AsBuiltReport.VMware.vSphere.psd1'
    $ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere'
    try {
        Import-Module $ModulePath -Force -ErrorAction Stop
    } catch {
        # Fallback: import .psm1 directly when required module dependencies are not available
        $PsmPath = Join-Path -Path $ModuleRoot -ChildPath 'AsBuiltReport.VMware.vSphere.psm1'
        Import-Module $PsmPath -Force
    }
}

Describe 'AsBuiltReport.VMware.vSphere Module Tests' {
    Context 'Module Manifest' {
        BeforeAll {
            $ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere\AsBuiltReport.VMware.vSphere.psd1'
            # Use Import-PowerShellDataFile so tests pass even when required modules are not installed
            $ManifestData = Import-PowerShellDataFile -Path $ManifestPath -ErrorAction Stop
        }

        It 'Should have a valid module manifest' {
            $ManifestData | Should -Not -BeNullOrEmpty
        }

        It 'Should have the correct module name' {
            [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath) | Should -Be 'AsBuiltReport.VMware.vSphere'
        }

        It 'Should have a valid GUID' {
            $ManifestData.GUID | Should -Be 'e1cbf1ce-cf01-4b6e-9cc2-56323da3c351'
        }

        It 'Should have a valid version' {
            $ManifestData.ModuleVersion | Should -Not -BeNullOrEmpty
            [version]::TryParse($ManifestData.ModuleVersion, [ref]$null) | Should -Be $true
        }

        It 'Should have version 2.0.0 or higher' {
            [version]$ManifestData.ModuleVersion | Should -BeGreaterOrEqual ([version]'2.0.0')
        }

        It 'Should have a valid author' {
            $ManifestData.Author | Should -Not -BeNullOrEmpty
        }

        It 'Should have a valid description' {
            $ManifestData.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have CompatiblePSEditions defined' {
            $ManifestData.CompatiblePSEditions | Should -Not -BeNullOrEmpty
        }

        It 'Should support Desktop PSEdition' {
            $ManifestData.CompatiblePSEditions | Should -Contain 'Desktop'
        }

        It 'Should support Core PSEdition' {
            $ManifestData.CompatiblePSEditions | Should -Contain 'Core'
        }

        It 'Should require AsBuiltReport.Core' {
            $RequiredModuleNames = $ManifestData.RequiredModules | ForEach-Object {
                if ($_ -is [hashtable]) { $_['ModuleName'] }
                else { $_ }
            }
            $RequiredModuleNames | Should -Contain 'AsBuiltReport.Core'
        }

        It 'Should export Invoke-AsBuiltReport.VMware.vSphere' {
            $ManifestData.FunctionsToExport | Should -Contain 'Invoke-AsBuiltReport.VMware.vSphere'
        }
    }

    Context 'Module Structure' {
        BeforeAll {
            $ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere'
        }

        It 'Should have Language directory' {
            $LangPath = Join-Path -Path $ModuleRoot -ChildPath 'Language'
            Test-Path $LangPath | Should -Be $true
        }

        It 'Should have en-US language folder' {
            $EnUsPath = Join-Path -Path $ModuleRoot -ChildPath 'Language\en-US'
            Test-Path $EnUsPath | Should -Be $true
        }

        It 'Should have en-US VMwarevSphere.psd1 language file' {
            $LangFile = Join-Path -Path $ModuleRoot -ChildPath 'Language\en-US\VMwarevSphere.psd1'
            Test-Path $LangFile | Should -Be $true
        }

        It 'Should have Src/Private directory' {
            $PrivatePath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Private'
            Test-Path $PrivatePath | Should -Be $true
        }

        It 'Should have Src/Public directory' {
            $PublicPath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Public'
            Test-Path $PublicPath | Should -Be $true
        }

        It 'Should have the Invoke- public function file' {
            $InvokePath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Public\Invoke-AsBuiltReport.VMware.vSphere.ps1'
            Test-Path $InvokePath | Should -Be $true
        }
    }

    Context 'Private Functions' {
        BeforeAll {
            $ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere'
            $PrivatePath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Private'
        }

        $ExpectedFunctions = @(
            'Convert-DataSize',
            'Get-ESXiBootDevice',
            'Get-InstallDate',
            'Get-License',
            'Get-PciDeviceDetail',
            'Get-ScsiDeviceDetail',
            'Get-Uptime',
            'Get-vCenterStats',
            'Get-VMHostNetworkAdapterDP',
            'Get-AbrVSpherevCenter',
            'Get-AbrVSphereCluster',
            'Get-AbrVSphereClusterHA',
            'Get-AbrVSphereClusterProactiveHA',
            'Get-AbrVSphereClusterDRS',
            'Get-AbrVSphereResourcePool',
            'Get-AbrVSphereVMHost',
            'Get-AbrVSphereVMHostHardware',
            'Get-AbrVSphereVMHostSystem',
            'Get-AbrVSphereVMHostStorage',
            'Get-AbrVSphereVMHostNetwork',
            'Get-AbrVSphereVMHostSecurity',
            'Get-AbrVSphereNetwork',
            'Get-AbrVSpherevSAN',
            'Get-AbrVSphereDatastore',
            'Get-AbrVSphereDSCluster',
            'Get-AbrVSphereVM',
            'Get-AbrVSphereVUM'
        )

        foreach ($FunctionName in $ExpectedFunctions) {
            It "Should have a .ps1 file for function '$FunctionName'" -TestCases @(@{ FunctionName = $FunctionName }) {
                param($FunctionName)
                $FilePath = Join-Path -Path $PrivatePath -ChildPath "$FunctionName.ps1"
                Test-Path $FilePath | Should -Be $true -Because "Expected file '$FunctionName.ps1' in Src/Private/"
            }
        }
    }

    Context 'Module Import' {
        It 'Should import without errors' {
            $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere\AsBuiltReport.VMware.vSphere.psm1'
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'PSScriptAnalyzer' {
        BeforeDiscovery {
            $AnalyzerAvailable = $null -ne (Get-Module -Name PSScriptAnalyzer -ListAvailable | Select-Object -First 1)
        }
        BeforeAll {
            $ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\AsBuiltReport.VMware.vSphere'
            $AnalyzerAvailable = $null -ne (Get-Module -Name PSScriptAnalyzer -ListAvailable | Select-Object -First 1)
        }

        It 'PSScriptAnalyzer should be available' {
            $AnalyzerAvailable | Should -Be $true
        }

        It 'Public functions should pass PSScriptAnalyzer' -Skip:(-not $AnalyzerAvailable) {
            $PublicPath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Public'
            $Results = Invoke-ScriptAnalyzer -Path $PublicPath -Recurse -Severity Error
            $Results | Should -BeNullOrEmpty -Because (($Results | ForEach-Object { "$($_.RuleName): $($_.Message) at $($_.ScriptName):$($_.Line)" }) -join "`n")
        }

        It 'Private functions should pass PSScriptAnalyzer' -Skip:(-not $AnalyzerAvailable) {
            $PrivatePath = Join-Path -Path $ModuleRoot -ChildPath 'Src\Private'
            $Results = Invoke-ScriptAnalyzer -Path $PrivatePath -Recurse -Severity Error
            $Results | Should -BeNullOrEmpty -Because (($Results | ForEach-Object { "$($_.RuleName): $($_.Message) at $($_.ScriptName):$($_.Line)" }) -join "`n")
        }
    }
}
