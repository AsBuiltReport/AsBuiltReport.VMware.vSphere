Function Get-PciDeviceDetail {
    <#
    .SYNOPSIS
    Helper function to return PCI Devices Drivers & Firmware information for a specific host.
    .PARAMETER Server
    vCenter VISession object.
    .PARAMETER esxcli
    Esxcli session object associated to the host.
    .EXAMPLE
    $Credentials = Get-Credential
    $Server = Connect-VIServer -Server vcenter01.example.com -Credentials $Credentials
    $VMHost = Get-VMHost -Server $Server -Name esx01.example.com
    $esxcli = Get-EsxCli -Server $Server -VMHost $VMHost -V2
    Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli
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
        $esxcli
    )
    Begin { }

    Process {
        # Set default results
        $firmwareVersion = "N/A"
        $vibName = "N/A"
        $driverVib = @{
            Name = "N/A"
            Version = "N/A"
        }
        $pciDevices = $esxcli.hardware.pci.list.Invoke() | Where-Object { $_.VMkernelName -match 'vmhba|vmnic|vmgfx' -and $_.ModuleName -ne 'None'} | Sort-Object -Property VMkernelName 
        $nicList = $esxcli.network.nic.list.Invoke() | Sort-Object Name
        foreach ($pciDevice in $pciDevices) {
            $driverVersion = $esxcli.system.module.get.Invoke(@{module = $pciDevice.ModuleName }) | Select-Object -ExpandProperty Version
            # Get NIC Firmware version
            if (($pciDevice.VMkernelName -like 'vmnic*') -and ($nicList.Name -contains $pciDevice.VMkernelName) ) {   
                $vmnicDetail = $esxcli.network.nic.get.Invoke(@{nicname = $pciDevice.VMkernelName })
                $firmwareVersion = $vmnicDetail.DriverInfo.FirmwareVersion
                # Get NIC driver VIB package version
                $driverVib = $esxcli.software.vib.list.Invoke() | Select-Object -Property Name, Version | Where-Object { $_.Name -eq $vmnicDetail.DriverInfo.Driver -or $_.Name -eq "net-" + $vmnicDetail.DriverInfo.Driver -or $_.Name -eq "net55-" + $vmnicDetail.DriverInfo.Driver }
                <#
                If HP Smart Array vmhba* (scsi-hpsa driver) then get Firmware version
                else skip if VMkernnel is vmhba*. Can't get HBA Firmware from 
                Powercli at the moment only through SSH or using Putty Plink+PowerCli.
                #>
            } elseif ($pciDevice.VMkernelName -like 'vmhba*') {
                if ($pciDevice.DeviceName -match "smart array") {
                    $hpsa = $vmhost.ExtensionData.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo | Where-Object { $_.Name -match "HP Smart Array" }
                    if ($hpsa) {
                        $firmwareVersion = (($hpsa.Name -split "firmware")[1]).Trim()
                    }
                }
                # Get HBA driver VIB package version
                $vibName = $pciDevice.ModuleName -replace "_", "-"
                $driverVib = $esxcli.software.vib.list.Invoke() | Select-Object -Property Name, Version | Where-Object { $_.Name -eq "scsi-" + $VibName -or $_.Name -eq "sata-" + $VibName -or $_.Name -eq $VibName }
            }
            # Output collected data
            [PSCustomObject]@{
                'Device' = $pciDevice.VMkernelName
                'Model' = $pciDevice.DeviceName
                'Driver' = $pciDevice.ModuleName
                'Driver Version' = $driverVersion
                'Firmware Version' = $firmwareVersion
                'VIB Name' = $driverVib.Name
                'VIB Version' = $driverVib.Version
            }
        } 
    }
    End { }
}