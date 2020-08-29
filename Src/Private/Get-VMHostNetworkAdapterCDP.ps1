function Get-VMHostNetworkAdapterCDP {
    <#
    .SYNOPSIS
    Function to retrieve the Network Adapter CDP info of a vSphere host.
    .DESCRIPTION
    Function to retrieve the Network Adapter CDP info of a vSphere host.
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    Get-VMHostNetworkAdapterCDP -VMHost ESXi01,ESXi02
    .EXAMPLE
    Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkAdapterCDP
    #>
    [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]

    Param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$VMHosts   
    )    

    begin {
        $CDPObject = @()
    }

    process {
        try {
            foreach ($VMHost in $VMHosts) {
                $ConfigManagerView = Get-View $VMHost.ExtensionData.ConfigManager.NetworkSystem
                $pNics = $ConfigManagerView.NetworkInfo.Pnic
                foreach ($pNic in $pNics) {
                    $PhysicalNicHintInfo = $ConfigManagerView.QueryNetworkHint($pNic.Device)
                    $Object = [PSCustomObject]@{                            
                        'Host' = $VMHost.Name
                        'Device' = $pNic.Device
                        'Status' = if ($PhysicalNicHintInfo.ConnectedSwitchPort) {
                            'Connected'
                        } else {
                            'Disconnected'
                        }
                        'SwitchId' = $PhysicalNicHintInfo.ConnectedSwitchPort.DevId
                        'Address' = $PhysicalNicHintInfo.ConnectedSwitchPort.Address
                        'VLAN' = $PhysicalNicHintInfo.ConnectedSwitchPort.Vlan
                        'MTU' = $PhysicalNicHintInfo.ConnectedSwitchPort.Mtu
                        'SystemName' = $PhysicalNicHintInfo.ConnectedSwitchPort.SystemName
                        'Location' = $PhysicalNicHintInfo.ConnectedSwitchPort.Location
                        'HardwarePlatform' = $PhysicalNicHintInfo.ConnectedSwitchPort.HardwarePlatform
                        'SoftwareVersion' = $PhysicalNicHintInfo.ConnectedSwitchPort.SoftwareVersion
                        'ManagementAddress' = $PhysicalNicHintInfo.ConnectedSwitchPort.MgmtAddr
                        'PortId' = $PhysicalNicHintInfo.ConnectedSwitchPort.PortId
                    }
                    $CDPObject += $Object
                }
            }
        } catch [Exception] {
            throw 'Unable to retrieve CDP info'
        }
    }
    end {
        Write-Output $CDPObject
    }
}