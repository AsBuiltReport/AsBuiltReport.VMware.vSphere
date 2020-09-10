function Get-ScsiDeviceDetail {
    <#
    .SYNOPSIS
    Helper function to return Scsi device information for a specific host and a specific datastore.
    .PARAMETER VMHosts
    This parameter accepts a list of host objects returned from the Get-VMHost cmdlet
    .PARAMETER VMHostMoRef
    This parameter specifies, by MoRef Id, the specific host of interest from with the $VMHosts array.
    .PARAMETER DatastoreDiskName
    This parameter specifies, by disk name, the specific datastore of interest.
    .EXAMPLE
    $VMHosts = Get-VMHost
    Get-ScsiDeviceDetail -AllVMHosts $VMHosts -VMHostMoRef 'HostSystem-host-131' -DatastoreDiskName 'naa.6005076801810082480000000001d9fe'
    DisplayName      : IBM Fibre Channel Disk (naa.6005076801810082480000000001d9fe)
    Ssd              : False
    LocalDisk        : False
    CanonicalName    : naa.6005076801810082480000000001d9fe
    Vendor           : IBM
    Model            : 2145
    Multipath Policy : Round Robin
    CapacityGB       : 512
    .NOTES
    Author: Ryan Kowalewski
    #>

    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $VMHosts,
        [Parameter(Mandatory = $true)]
        $VMHostMoRef,
        [Parameter(Mandatory = $true)]
        $DatastoreDiskName
    )

    $VMHostObj = $VMHosts | Where-Object { $_.Id -eq $VMHostMoRef }
    $ScsiDisk = $VMHostObj.ExtensionData.Config.StorageDevice.ScsiLun | Where-Object {
        $_.CanonicalName -eq $DatastoreDiskName
    }
    $Multipath = $VMHostObj.ExtensionData.Config.StorageDevice.MultipathInfo.Lun | Where-Object {
        $_.Lun -eq $ScsiDisk.Key
    }
    $CapacityGB = [math]::Round((($ScsiDisk.Capacity.BlockSize * $ScsiDisk.Capacity.Block) / 1024 / 1024 / 1024), 2)

    [PSCustomObject]@{
        'DisplayName' = $ScsiDisk.DisplayName
        'Ssd' = $ScsiDisk.Ssd
        'LocalDisk' = $ScsiDisk.LocalDisk
        'CanonicalName' = $ScsiDisk.CanonicalName
        'Vendor' = $ScsiDisk.Vendor
        'Model' = $ScsiDisk.Model
        'MultipathPolicy' = switch ($Multipath.Policy.Policy) {
            'VMW_PSP_RR' { 'Round Robin' }
            'VMW_PSP_FIXED' { 'Fixed' }
            'VMW_PSP_MRU' { 'Most Recently Used' }
            default { $Multipath.Policy.Policy }
        }
        'Paths' = ($Multipath.Path).Count
        'CapacityGB' = $CapacityGB
    }
}