function Get-VMHostNetworkAdapterDP {
    <#
    .SYNOPSIS
    Function to retrieve the Network Adapter CDP or LLDP info of a vSphere host.
    .DESCRIPTION
    Function to retrieve the Network Adapter CDP or LLDP info of a vSphere host.
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    Get-VMHostNetworkAdapterDP -VMHost ESXi01,ESXi02
    .EXAMPLE
    Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkAdapterDP
    #>
    [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]

    Param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$VMHost
    )

    begin {
        $ObjOutput = @()
    }

    process {
        try {
            foreach ($ObjVMHost in $VMHost) {
                $ConfigManagerView = Get-View $ObjVMHost.ExtensionData.ConfigManager.NetworkSystem
                $pNics = $ConfigManagerView.NetworkInfo.Pnic
                foreach ($pNic in $pNics) {
                    $PhysicalNicHintInfo = $ConfigManagerView.QueryNetworkHint($pNic.Device)
                    if ($PhysicalNicHintInfo.ConnectedSwitchPort) {
                        $Object = [PSCustomObject]@{
                            'Host' = $ObjVMHost.Name
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
                        $ObjOutput += $Object
                    }
                    if ($PhysicalNicHintInfo.LldpInfo) {
                        $Object = [PSCustomObject]@{
                            'Host' = $ObjVMHost.Name
                            'Device' = $pNic.Device
                            'ChassisId' = $PhysicalNicHintInfo.LldpInfo.ChassisId
                            'PortId' = $PhysicalNicHintInfo.LldpInfo.PortId
                            'TimeToLive' = $PhysicalNicHintInfo.LldpInfo.TimeToLive
                            'TimeOut' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "TimeOut"}).Value
                            'Samples' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "Samples"}).Value
                            'ManagementAddress' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "Management Address"}).Value
                            'PortDescription' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "Port Description"}).Value
                            'SystemDescription' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "System Description"}).Value
                            'SystemName' = ($PhysicalNicHintInfo.LldpInfo.Parameter | Where-Object {$_.key -eq "System Name"}).Value
                        }
                        $ObjOutput += $Object
                    }
                }
            }
        } catch [Exception] {
            throw 'Unable to retrieve CDP/LLDP info'
        }
    }
    end {
        Write-Output $ObjOutput
    }
}