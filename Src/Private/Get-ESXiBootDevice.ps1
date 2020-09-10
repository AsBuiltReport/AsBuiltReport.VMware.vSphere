function Get-ESXiBootDevice {
    <#
    .NOTES
    ===========================================================================
        Created by:    William Lam
        Organization:  VMware
        Blog:          www.virtuallyghetto.com
        Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function identifies how an ESXi host was booted up along with its boot
        device (if applicable). This supports both local installation to Auto Deploy as
        well as Boot from SAN.
    .PARAMETER VMHostname
        The name of an individual ESXi host managed by vCenter Server
    .EXAMPLE
        Get-ESXiBootDevice
    .EXAMPLE
        Get-ESXiBootDevice -VMHost esxi-01
    #>
    param(
        [Parameter(Mandatory = $false)][PSObject]$VMHost
    )

    $results = @()
    $esxcli = Get-EsxCli -V2 -VMHost $VMHost -Server $vCenter
    $bootDetails = $esxcli.system.boot.device.get.Invoke()

    # Check to see if ESXi booted over the network
    $networkBoot = $false
    if ($bootDetails.BootNIC) {
        $networkBoot = $true
        $bootDevice = $bootDetails.BootNIC
    } elseif ($bootDetails.StatelessBootNIC) {
        $networkBoot = $true
        $bootDevice = $bootDetails.StatelessBootNIC
    }

    # If ESXi booted over network, check to see if deployment
    # is Stateless, Stateless w/Caching or Stateful
    if ($networkBoot) {
        $option = $esxcli.system.settings.advanced.list.CreateArgs()
        $option.option = "/UserVars/ImageCachedSystem"
        try {
            $optionValue = $esxcli.system.settings.advanced.list.Invoke($option)
        } catch {
            $bootType = "Stateless"
        }
        $bootType = $optionValue.StringValue
    }

    # Loop through all storage devices to identify boot device
    $devices = $esxcli.storage.core.device.list.Invoke()
    $foundBootDevice = $false
    foreach ($device in $devices) {
        if ($device.IsBootDevice -eq $true) {
            $foundBootDevice = $true

            if ($device.IsLocal -eq $true -and $networkBoot -and $bootType -ne "Stateful") {
                $bootType = "Stateless Caching"
            } elseif ($device.IsLocal -eq $true -and $networkBoot -eq $false) {
                $bootType = "Local"
            } elseif ($device.IsLocal -eq $false -and $networkBoot -eq $false) {
                $bootType = "Remote"
            }

            $bootDevice = $device.Device
            $bootModel = $device.Model
            $bootVendor = $device.VEndor
            $bootSize = $device.Size
            $bootIsSAS = $TextInfo.ToTitleCase($device.IsSAS)
            $bootIsSSD = $TextInfo.ToTitleCase($device.IsSSD)
            $bootIsUSB = $TextInfo.ToTitleCase($device.IsUSB)
        }
    }

    # Pure Stateless (e.g. No USB or Disk for boot)
    if ($networkBoot -and $foundBootDevice -eq $false) {
        $bootModel = "N/A"
        $bootVendor = "N/A"
        $bootSize = "N/A"
        $bootIsSAS = "N/A"
        $bootIsSSD = "N/A"
        $bootIsUSB = "N/A"
    }

    $tmp = [PSCustomObject]@{
        Host = $vmhost.Name;
        Device = $bootDevice;
        BootType = $bootType;
        Vendor = $bootVendor;
        Model = $bootModel;
        SizeMB = $bootSize;
        IsSAS = $bootIsSAS;
        IsSSD = $bootIsSSD;
        IsUSB = $bootIsUSB;
    }
    $results += $tmp
    $results
}