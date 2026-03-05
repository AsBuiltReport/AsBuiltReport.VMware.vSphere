Function Get-PciDeviceDetail {
    <#
    .SYNOPSIS
    Helper function to return PCI Devices Drivers & Firmware information for a specific host.
    .PARAMETER Server
    vCenter VISession object.
    .PARAMETER esxcli
    Esxcli session object associated to the host.
    .PARAMETER VMHost
    VMHost object. Required for ESXi 8.x compatibility where VMkernelName is no longer
    populated in esxcli hardware.pci.list; used to build a PCI address to VMkernel name map.
    .EXAMPLE
    $Credentials = Get-Credential
    $Server = Connect-VIServer -Server vcenter01.example.com -Credentials $Credentials
    $VMHost = Get-VMHost -Server $Server -Name esx01.example.com
    $esxcli = Get-EsxCli -Server $Server -VMHost $VMHost -V2
    Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli -VMHost $VMHost
    Device           : vmhba0
    Model            : Sunrise Point-LP AHCI Controller
    Driver           : vmw_ahci
    Driver Version   : 1.0.0-34vmw.650.0.14.5146846
    Firmware Version : N/A
    VIB Name         : vmw-ahci
    VIB Version      : 1.0.0-34vmw.650.0.14.5146846
    .NOTES
    Author: Erwan Quelin heavily based on the work of the vDocumentation team - https://github.com/arielsanchezmora/vDocumentation/blob/master/powershell/vDocumentation/Public/Get-ESXIODevice.ps1
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        $Server,
        [Parameter(Mandatory = $true)]
        $esxcli,
        [Parameter(Mandatory = $false)]
        $VMHost
    )
    Begin { }

    Process {
        # Build PCI address -> VMkernel name mapping for ESXi 8 compatibility.
        # VMkernelName is no longer populated in esxcli hardware.pci.list on ESXi 8.x,
        # so we derive it from the PowerCLI API using the PCI address as the join key.
        $addrToVmkernel = @{}
        if ($null -ne $VMHost) {
            Get-VMHostNetworkAdapter -VMHost $VMHost -Physical | ForEach-Object {
                if ($_.PciId) { $addrToVmkernel[$_.PciId] = $_.DeviceName }
            }
            Get-VMHostHba -VMHost $VMHost | ForEach-Object {
                if ($_.Pci) { $addrToVmkernel[$_.Pci] = $_.Device }
            }
            (Get-VMHost $VMHost | Get-View -Property Config).Config.GraphicsInfo | ForEach-Object {
                if ($_.pciId) { $addrToVmkernel[$_.pciId] = $_.deviceName }
            }
        }

        $pciDevices = $esxcli.hardware.pci.list.Invoke() | Where-Object {
            $vmkName = if ($_.VMkernelName -match 'vmhba|vmnic|vmgfx') {
                $_.VMkernelName
            } else {
                $addrToVmkernel[$_.Address]
            }
            $vmkName -match 'vmhba|vmnic|vmgfx' -and $_.ModuleName -ne 'None'
        }
        $nicList = $esxcli.network.nic.list.Invoke() | Sort-Object Name
        foreach ($pciDevice in $pciDevices) {
            # Resolve VMkernel name: populated directly on ESXi < 8, address lookup required on ESXi 8+
            $vmkernelName = if ($pciDevice.VMkernelName -match 'vmhba|vmnic|vmgfx') {
                $pciDevice.VMkernelName
            } else {
                $addrToVmkernel[$pciDevice.Address]
            }

            # Reset per-device defaults on every iteration
            $firmwareVersion = 'N/A'
            $driverVib = @{ Name = 'N/A'; Version = 'N/A' }

            $driverVersion = $esxcli.system.module.get.Invoke(@{module = $pciDevice.ModuleName }) | Select-Object -ExpandProperty Version
            # Get NIC Firmware version
            if (($vmkernelName -like 'vmnic*') -and ($nicList.Name -contains $vmkernelName)) {
                $vmnicDetail = $esxcli.network.nic.get.Invoke(@{nicname = $vmkernelName })
                $firmwareVersion = $vmnicDetail.DriverInfo.FirmwareVersion
                # Get NIC driver VIB package version
                $driverVib = $esxcli.software.vib.list.Invoke() | Select-Object -Property Name, Version | Where-Object {
                    $_.Name -eq $vmnicDetail.DriverInfo.Driver -or
                    $_.Name -eq "net-" + $vmnicDetail.DriverInfo.Driver -or
                    $_.Name -eq "net55-" + $vmnicDetail.DriverInfo.Driver
                }
                <#
                If HP Smart Array vmhba* (scsi-hpsa driver) then get Firmware version
                else skip if VMkernnel is vmhba*. Can't get HBA Firmware from
                Powercli at the moment only through SSH or using Putty Plink+PowerCli.
                #>
            } elseif ($vmkernelName -like 'vmhba*') {
                if ($pciDevice.DeviceName -match 'smart array') {
                    $hpsa = $VMHost.ExtensionData.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo | Where-Object { $_.Name -match 'HP Smart Array' }
                    if ($hpsa) {
                        $firmwareVersion = (($hpsa.Name -split 'firmware')[1]).Trim()
                    }
                }
                # Get HBA driver VIB package version
                $vibName = $pciDevice.ModuleName -replace '_', '-'
                $driverVib = $esxcli.software.vib.list.Invoke() | Select-Object -Property Name, Version | Where-Object {
                    $_.Name -eq "scsi-$vibName" -or $_.Name -eq "sata-$vibName" -or $_.Name -eq $vibName
                }
            }
            # Output collected data
            [PSCustomObject]@{
                'Device'           = $vmkernelName
                'Model'            = $pciDevice.DeviceName
                'Driver'           = $pciDevice.ModuleName
                'Driver Version'   = $driverVersion
                'Firmware Version' = $firmwareVersion
                'VIB Name'         = $driverVib.Name
                'VIB Version'      = $driverVib.Version
            }
        }
    }
    End { }
}
