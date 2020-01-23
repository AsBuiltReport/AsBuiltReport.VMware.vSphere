function Invoke-AsBuiltReport.VMware.vSphere {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        1.1.3
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential,
        [String] $StylePath
    )

    # Import JSON Configuration for Options and InfoLevel
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options

    $TextInfo = (Get-Culture).TextInfo

    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.VMware.vSphere.Style.ps1"
    }

    #region Script Functions
    #---------------------------------------------------------------------------------------------#
    #                                    SCRIPT FUNCTIONS                                         #
    #---------------------------------------------------------------------------------------------#

    function Get-vCenterStats {
        $vCenterStats = @()
        $ServiceInstance = Get-View ServiceInstance -Server $vCenter
        $VCenterStatistics = Get-View ($ServiceInstance).Content.PerfManager
        [int] $CurrentServiceIndex = 2;
        Foreach ($xStatLevel in $VCenterStatistics.HistoricalInterval) {
            Switch ($xStatLevel.SamplingPeriod) {
                300 { $xInterval = '5 Minutes' }
                1800 { $xInterval = '30 Minutes' }
                7200 { $xInterval = '2 Hours' }
                86400 { $xInterval = '1 Day' }
            }
            ## Add the required key/values to the hashtable
            $vCenterStatsHash = @{
                IntervalDuration = $xInterval;
                IntervalEnabled = $xStatLevel.Enabled;
                SaveDuration = $xStatLevel.Name;
                StatsLevel = $xStatLevel.Level;
            }
            ## Add the hash to the array
            $vCenterStats += $vCenterStatsHash;
            $CurrentServiceIndex++
        }
        Write-Output $vCenterStats
    }

    function Get-License {
        <#
    .SYNOPSIS
    Function to retrieve vSphere product licensing information.
    .DESCRIPTION
    Function to retrieve vSphere product licensing information.
    .NOTES
    Version:        0.2.0
    Author:         Tim Carman
    Twitter:        @tpcarman
    Github:         tpcarman
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .PARAMETER vCenter
    A vSphere vCenter Server object
    .PARAMETER Licenses
    All vSphere product licenses
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    PS> Get-License -VMHost ESXi01
    .EXAMPLE
    PS> Get-License -vCenter VCSA
    .EXAMPLE
    PS> Get-License -Licenses
    #>
        [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]

        Param
        (
            [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
            [ValidateNotNullOrEmpty()]
            [PSObject]$vCenter, 
            [PSObject]$VMHost,
            [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
            [Switch]$Licenses
        ) 

        $LicenseObject = @()
        $ServiceInstance = Get-View ServiceInstance -Server $vCenter
        $LicenseManager = Get-View $ServiceInstance.Content.LicenseManager -Server $vCenter
        $LicenseManagerAssign = Get-View $LicenseManager.LicenseAssignmentManager -Server $vCenter
        if ($VMHost) {
            $VMHostId = $VMHost.Extensiondata.Config.Host.Value
            $VMHostAssignedLicense = $LicenseManagerAssign.QueryAssignedLicenses($VMHostId)    
            $VMHostLicense = $VMHostAssignedLicense.AssignedLicense
            $VMHostLicenseExpiration = ($VMHostLicense.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object Value).Value
            if ($VMHostLicense.LicenseKey -and $Options.ShowLicenseKeys) {
                $VMHostLicenseKey = $VMHostLicense.LicenseKey
            } else {
                $VMHostLicenseKey = "*****-*****-*****" + $VMHostLicense.LicenseKey.Substring(17)
            }
            $LicenseObject = [PSCustomObject]@{                               
                Product = $VMHostLicense.Name 
                LicenseKey = $VMHostLicenseKey
                Expiration =
                if ($VMHostLicenseExpiration -eq $null) {
                    "Never" 
                } elseif ($VMHostLicenseExpiration -gt (Get-Date)) {
                    $VMHostLicenseExpiration.ToShortDateString()
                } else {
                    "Expired"
                }
            }
        }
        if ($vCenter) {
            $vCenterAssignedLicense = $LicenseManagerAssign.GetType().GetMethod("QueryAssignedLicenses").Invoke($LicenseManagerAssign, @($_.MoRef.Value)) | Where-Object { $_.EntityID -eq $vCenter.InstanceUuid }
            $vCenterLicense = $vCenterAssignedLicense.AssignedLicense
            $vCenterLicenseExpiration = ($vCenterLicense.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object Value).Value
            if ($vCenterLicense.LicenseKey -and $Options.ShowLicenseKeys) { 
                $vCenterLicenseKey = $vCenterLicense.LicenseKey
            } else {
                $vCenterLicenseKey = "*****-*****-*****" + $vCenterLicense.LicenseKey.Substring(17)
            }
            $LicenseObject = [PSCustomObject]@{                               
                Product = $vCenterLicense.Name
                LicenseKey = $vCenterLicenseKey
                Expiration =
                if ($vCenterLicenseExpiration -eq $null) {
                    "Never" 
                } elseif ($vCenterLicenseExpiration -gt (Get-Date)) {
                    $vCenterLicenseExpiration.ToShortDateString()
                } else {
                    "Expired"
                }
            }
        }
        if ($Licenses) {
            foreach ($License in ($LicenseManager.Licenses | Where-Object { $_.licensekey -ne '' })) {
                $Object = @()
                $LicenseExpiration = $License.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object -ExpandProperty Value
                if ($Options.ShowLicenseKeys) {
                    $LicenseKey = $License.LicenseKey
                } else {
                    $LicenseKey = "*****-*****-*****" + $License.LicenseKey.Substring(17)
                }
                $Object = [PSCustomObject]@{
                    'License' = $License.License                              
                    'Product' = $License.Name
                    'LicenseKey' = $LicenseKey
                    'Total' = $License.Total
                    'Used' = Switch ($License.Used) {
                        $null { "0" }
                        default { $License.Used }
                    }
                    'Expiration' = 
                    if ($LicenseExpiration -eq $null) {
                        "Never"
                    } elseif ($LicenseExpiration -gt (Get-Date)) {
                        $LicenseExpiration.ToShortDateString()
                    } else {
                        "Expired"
                    }
                }
                $LicenseObject += $Object
            }
        }
        Write-Output $LicenseObject
    }

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
    PS> Get-VMHostNetworkAdapterCDP -VMHost ESXi01,ESXi02
    .EXAMPLE
    PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkAdapterCDP
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

    function Get-InstallDate {
        $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
        $thisUUID = $esxcli.system.uuid.get.Invoke()
        $decDate = [Convert]::ToInt32($thisUUID.Split("-")[0], 16)
        $installDate = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($decDate))
        [PSCustomObject][Ordered]@{
            Name = $VMHost.Name
            InstallDate = $installDate
        }
    }

    function Get-Uptime {
        [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]
        Param (
            [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
            [ValidateNotNullOrEmpty()]
            [PSObject]$VMHost, [PSObject]$VM
        )
        $UptimeObject = @()
        $Date = (Get-Date).ToUniversalTime() 
        If ($VMHost) {
            $UptimeObject = Get-View -ViewType hostsystem -Property Name, Runtime.BootTime -Filter @{
                "Name" = "^$($VMHost.Name)$"
                "Runtime.ConnectionState" = "connected"
            } | Select-Object Name, @{L = 'UptimeDays'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalDays), 2) } }, @{L = 'UptimeHours'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalHours), 2) } }, @{L = 'UptimeMinutes'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalMinutes), 2) } }
        }

        if ($VM) {
            $UptimeObject = Get-View -ViewType VirtualMachine -Property Name, Runtime.BootTime -Filter @{
                "Name" = "^$($VM.Name)$"
                "Runtime.PowerState" = "poweredOn"
            } | Select-Object Name, @{L = 'UptimeDays'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalDays), 2) } }, @{L = 'UptimeHours'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalHours), 2) } }, @{L = 'UptimeMinutes'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalMinutes), 2) } }
        }
        Write-Output $UptimeObject
    }

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

    Function Get-PciDeviceDetail {
        <#
    .SYNOPSIS
    Helper function to return PCI Devices Drivers & Firmware information for a specific host.
    .PARAMETER Server
    vCenter VISession object.
    .PARAMETER esxcli
    Esxcli session object associated to the host.
    .EXAMPLE
    $Credentials = Get-Crendentials
    $Server = Connect-VIServer -Server vcenter01.example.com -Credentials $Credentials
    $VMHost = Get-VMHost -Server $Server -Name esx01.example.com
    $esxcli = Get-EsxCli -Server $Server -VMHost $VMHost -V2
    Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli
    VMkernel Name    : vmhba0
    Device Name      : Sunrise Point-LP AHCI Controller
    Driver           : vmw_ahci
    Driver Version   : 1.0.0-34vmw.650.0.14.5146846
    Firmware Version : NA
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
            $pciDevices = $esxcli.hardware.pci.list.Invoke() | Where-Object { $_.VMKernelName -like "vmhba*" -or $_.VMKernelName -like "vmnic*" -or $_.VMKernelName -like "vmgfx*" } | Sort-Object -Property VMKernelName 
            $nicList = $esxcli.network.nic.list.Invoke() | Sort-Object Name
            #$fcoeAdapterList = $esxcli.fcoe.adapter.list.Invoke().PhysicalNIC # Get list of vmnics used for FCoE, because we don't want those vmnics here.
            foreach ($pciDevice in $pciDevices) {
                $driverVersion = $esxcli.system.module.get.Invoke(@{module = $pciDevice.ModuleName }) | Select-Object -ExpandProperty Version
                # Get NIC Firmware version
                #if (($pciDevice.VMKernelName -like 'vmnic*') -and ($fcoeAdapterList -notcontains $pciDevice.VMKernelName) -and ($nicList.Name -contains $pciDevice.VMKernelName) ) {
                if (($pciDevice.VMKernelName -like 'vmnic*') -and ($nicList.Name -contains $pciDevice.VMKernelName) ) {   
                    $vmnicDetail = $esxcli.network.nic.get.Invoke(@{nicname = $pciDevice.VMKernelName })
                    $firmwareVersion = $vmnicDetail.DriverInfo.FirmwareVersion
                    # Get NIC driver VIB package version
                    $driverVib = $esxcli.software.vib.list.Invoke() | Select-Object -Property Name, Version | Where-Object { $_.Name -eq $vmnicDetail.DriverInfo.Driver -or $_.Name -eq "net-" + $vmnicDetail.DriverInfo.Driver -or $_.Name -eq "net55-" + $vmnicDetail.DriverInfo.Driver }
                    <#
                    If HP Smart Array vmhba* (scsi-hpsa driver) then get Firmware version
                    else skip if VMkernnel is vmhba*. Can't get HBA Firmware from 
                    Powercli at the moment only through SSH or using Putty Plink+PowerCli.
                    #>
                } elseif ($pciDevice.VMKernelName -like 'vmhba*') {
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
                    'VMkernel Name' = $pciDevice.VMKernelName
                    'Device Name' = $pciDevice.DeviceName
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
    #endregion Script Functions

    #region Script Body
    #---------------------------------------------------------------------------------------------#
    #                                         SCRIPT BODY                                         #
    #---------------------------------------------------------------------------------------------#
    # Connect to vCenter Server using supplied credentials
    foreach ($VIServer in $Target) { 
        try {
            $vCenter = Connect-VIServer $VIServer -Credential $Credential -ErrorAction Stop
        } catch {
            Write-Error $_
        }
    
        #region Generate vSphere report
        if ($vCenter) {
            # Create a lookup hashtable to quickly link VM MoRefs to Names
            # Exclude VMware Site Recovery Manager placeholder VMs
            $VMs = Get-VM -Server $vCenter | Where-Object {
                $_.ExtensionData.Config.ManagedBy.ExtensionKey -notlike 'com.vmware.vcDr*'
            } | Sort-Object Name
            $VMLookup = @{ }
            foreach ($VM in $VMs) {
                $VMLookup.($VM.Id) = $VM.Name
            }

            # Create a lookup hashtable to link Host MoRefs to Names
            # Exclude VMware HCX hosts and ESX/ESXi versions prior to vSphere 5.0 from VMHost lookup
            $VMHosts = Get-VMHost -Server $vCenter | Where-Object { $_.Model -notlike "*VMware Mobility Platform" -and $_.Version -gt 5 } | Sort-Object Name
            $VMHostLookup = @{ }
            foreach ($VMHost in $VMHosts) {
                $VMHostLookup.($VMHost.Id) = $VMHost.Name
            }

            # Create a lookup hashtable to link Datastore MoRefs to Names
            $Datastores = Get-Datastore -Server $vCenter | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
            $DatastoreLookup = @{ }
            foreach ($Datastore in $Datastores) {
                $DatastoreLookup.($Datastore.Id) = $Datastore.Name
            }

            # Create a lookup hashtable to link VDS Portgroups MoRefs to Names
            $VDPortGroups = Get-VDPortgroup -Server $vCenter | Sort-Object Name
            $VDPortGroupLookup = @{ }
            foreach ($VDPortGroup in $VDPortGroups) {
                $VDPortGroupLookup.($VDPortGroup.Key) = $VDPortGroup.Name
            }

            # Create a lookup hashtable to link EVC Modes to Names
            $SupportedEvcModes = $vCenter.ExtensionData.Capability.SupportedEVCMode
            $EvcModeLookup = @{ }
            foreach ($EvcMode in $SupportedEvcModes) {
                $EvcModeLookup.($EvcMode.Key) = $EvcMode.Label
            }

            $si = Get-View ServiceInstance -Server $vCenter
            $extMgr = Get-View -Id $si.Content.ExtensionManager -Server $vCenter

            #region VMware Update Manager Server Name
            $VumServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcIntegrity' } | 
            Select-Object @{
                N = 'Name'; 
                E = { ($_.Server | Where-Object { $_.Type -eq 'SOAP' -and $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VMware Update Manager Server Name

            #region VxRail Manager Server Name
            $VxRailMgr = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vxrail' } | 
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Type -eq 'HTTPS' } | 
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VxRail Manager Server Name

            #region Site Recovery Manager Server Name
            $SrmServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcDr' } | 
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Company -eq 'VMware, Inc.' } | 
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion Site Recovery Manager Server Name            

            #region vCenter Advanced Settings
            $vCenterAdvSettings = Get-AdvancedSetting -Entity $vCenter
            $vCenterLicense = Get-License -vCenter $vCenter
            $vCenterServerName = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.FQDN' }).Value
            #endregion vCenter Advanced Settings

            $vCenterServerName = $vCenterServerName.ToString().ToLower()
            #region vCenter Server Heading1 Section
            Section -Style Heading1 $vCenterServerName {
                #region vCenter Server Section
                if ($InfoLevel.vCenter -ge 1) {
                    Section -Style Heading2 'vCenter Server' { 
                        Paragraph "The following sections detail the configuration of vCenter Server $vCenterServerName."
                        BlankLine
                        # Gather basic vCenter Server Information
                        $vCenterServerInfo = [PSCustomObject]@{
                            'vCenter Server' = $vCenterServerName
                            'IP Address' = ($vCenterAdvSettings | Where-Object { $_.name -like 'VirtualCenter.AutoManagedIPV4' }).Value
                            'Version' = $vCenter.Version
                            'Build' = $vCenter.Build
                            'OS Type' = $vCenter.ExtensionData.Content.About.OsType
                        }
                        #region vCenter Server Summary & Informative Information
                        if ($InfoLevel.vCenter -le 2) {                   
                            $vCenterServerInfo | Table -Name $vCenterServerName -ColumnWidths 20, 20, 20, 20, 20  
                        }
                        #endregion vCenter Server Informative Information

                        #region vCenter Server Detailed Information
                        if ($InfoLevel.vCenter -ge 3) {
                            #region vCenter Server Detail
                            $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'Product' -Value $vCenterLicense.Product
                            $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'License Key' -Value $vCenterLicense.LicenseKey  
                            $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'License Expiration' -Value $vCenterLicense.Expiration  
                            $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'Instance ID' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'instance.id' }).Value  

                            if ($vCenter.Version -ge 6) {
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'HTTP Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpport' }).Value
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'HTTPS Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpsport' }).Value
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'Platform Services Controller' -Value (($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.sso.admin.uri' }).Value -replace "^https://|/sso-adminserver/sdk/vsphere.local")
                            }
                            if ($VumServer.Name) {
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'Update Manager Server' -Value $VumServer.Name
                            }
                            if ($SrmServer.Name) {
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'Site Recovery Manager Server' -Value $SrmServer.Name
                            }
                            if ($VxRailMgr.Name) {
                                $vCenterServerInfo | Add-Member -MemberType NoteProperty -Name 'VxRail Manager Server' -Value $VxRailMgr.Name
                            }
                            if ($Healthcheck.vCenter.Licensing) {
                                $vCenterServerInfo | Where-Object { $_.'Product' -like '*Evaluation*' } | Set-Style -Style Warning -Property 'Product'
                                $vCenterServerInfo | Where-Object { $_.'Product' -eq $null } | Set-Style -Style Warning -Property 'Product'
                                $vCenterServerInfo | Where-Object { $_.'License Key' -like '*-00000-00000' } | Set-Style -Style Warning -Property 'License Key'
                                $vCenterServerInfo | Where-Object { $_.'License Expiration' -eq 'Expired' } | Set-Style -Style Critical -Property 'License Expiration'
                            }
                            $vCenterServerInfo | Table -Name "$vCenterServerName vCenter Server Detailed Information" -List -ColumnWidths 50, 50
                            #endregion vCenter Server Detail

                            #region vCenter Server Database Settings
                            Section -Style Heading3 'Database Settings' {
                                $vCenterDbInfo = [PSCustomObject]@{
                                    'Database Type' = $TextInfo.ToTitleCase(($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dbtype' }).Value)
                                    'Data Source Name' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dsn' }).Value
                                    'Maximum Database Connection' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.MaxDBConnection' }).Value
                                }
                                $vCenterDbInfo | Table -Name "$vCenterServerName vCenter Server Database Configuration" -List -ColumnWidths 50, 50 
                            }
                            #endregion vCenter Server Database Settings
                    
                            #region vCenter Server Mail Settings
                            Section -Style Heading3 'Mail Settings' {
                                $vCenterMailInfo = [PSCustomObject]@{
                                    'SMTP Server' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.server' }).Value
                                    'SMTP Port' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.port' }).Value
                                    'Mail Sender' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.sender' }).Value
                                }
                                if ($Healthcheck.vCenter.Mail) {
                                    $vCenterMailInfo | Where-Object { !($_.'SMTP Server') } | Set-Style -Style Critical -Property 'SMTP Server'
                                    $vCenterMailInfo | Where-Object { !($_.'SMTP Port') } | Set-Style -Style Critical -Property 'SMTP Port'
                                    $vCenterMailInfo | Where-Object { !($_.'Mail Sender') } | Set-Style -Style Critical -Property 'Mail Sender' 
                                }
                                $vCenterMailInfo | Table -Name "$vCenterServerName vCenter Server Mail Configuration" -List -ColumnWidths 50, 50 
                            }
                            #endregion vCenter Server Mail Settings
                    
                            #region vCenter Server Historical Statistics
                            Section -Style Heading3 'Historical Statistics' {
                                $vCenterHistoricalStats = Get-vCenterStats | Select-Object @{L = 'Interval Duration'; E = { $_.IntervalDuration } }, @{L = 'Interval Enabled'; E = { $_.IntervalEnabled } }, 
                                @{L = 'Save Duration'; E = { $_.SaveDuration } }, @{L = 'Statistics Level'; E = { $_.StatsLevel } } -Unique
                                $vCenterHistoricalStats | Table -Name "$vCenterServerName vCenter Server vHistorical Statistics" -ColumnWidths 25, 25, 25, 25
                            }
                            #endregion vCenter Server Historical Statistics

                            #region vCenter Server Licensing
                            Section -Style Heading3 'Licensing' {
                                $Licenses = Get-License -Licenses | Select-Object Product, @{L = 'License Key'; E = { ($_.LicenseKey) } }, Total, Used, @{L = 'Available'; E = { ($_.total) - ($_.Used) } }, Expiration -Unique
                                if ($Healthcheck.vCenter.Licensing) {
                                    $Licenses | Where-Object { $_.Product -eq 'Product Evaluation' } | Set-Style -Style Warning
                                    $Licenses | Where-Object { $_.Expiration -eq 'Expired' } | Set-Style -Style Critical 
                                }
                                $Licenses | Sort-Object 'Product', 'License Key' | Table -Name 'Licensing' -ColumnWidths 30, 30, 10, 10, 10, 10
                            }
                            #endregion vCenter Server Licensing

                            #region vCenter Server Certificate
                            if ($vCenter.Version -ge 6) {
                                Section -Style Heading3 'Certificate' {
                                    $VcenterCertMgmt = [PSCustomObject]@{
                                        'Country' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.country' }).Value
                                        'Email' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.email' }).Value
                                        'Locality' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.localityName' }).Value
                                        'State' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.state' }).Value
                                        'Organization' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.organizationName' }).Value
                                        'Organization Unit' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.organizationalUnitName' }).Value
                                        'Validity' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.daysValid'}).Value / 365) years"
                                        'Mode' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.mode' }).Value
                                        'Soft Threshold' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.softThreshold'}).Value) days"
                                        'Hard Threshold' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.hardThreshold'}).Value) days"
                                        'Minutes Before' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.minutesBefore' }).Value
                                        'Poll Interval' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.pollIntervalDays'}).Value) days"
                                    }
                                    $VcenterCertMgmt | Table -Name "$vCenter Server Certificate" -List -ColumnWidths 50, 50
                                }
                            }
                            #endregion vCenter Server Certificate

                            #region vCenter Server Roles
                            Section -Style Heading3 'Roles' {
                                $VIRoles = Get-VIRole -Server $vCenter
                                $VCRoles = foreach ($VIRole in $VIRoles) {
                                    [PSCustomObject]@{
                                        'Role' = $VIRole.Name
                                        'System Role' = Switch ($VIRole.IsSystem) {
                                            $true { 'Yes' }
                                            $false { 'No' }
                                        }
                                    }
                                }
                                $VCRoles | Sort-Object Role | Table -Name 'Roles' -ColumnWidths 50, 50 
                            }
                            #endregion vCenter Server Roles

                            #region vCenter Server Tags
                            $Tags = Get-Tag -Server $vCenter
                            if ($Tags) {
                                Section -Style Heading3 'Tags' {
                                    $Tags = $Tags | Select-Object Name, Description, Category
                                    $Tags | Sort-Object Name, Category | Table -Name 'Tags'
                                }
                            }
                            #endregion vCenter Server Tags

                            #region vCenter Server Tag Categories
                            $TagCategories = Get-TagCategory -Server $vCenter
                            if ($TagCategories) {
                                Section -Style Heading3 'Tag Categories' {
                                    $TagCategories = $TagCategories | Select-Object Name, Description, Cardinality -Unique
                                    $TagCategories | Sort-Object Name | Table -Name 'Tag Categories' -ColumnWidths 40, 40, 20
                                }
                            }
                            #endregion vCenter Server Tag Categories
                        
                            #region vCenter Server Tag Assignments
                            $TagAssignments = Get-TagAssignment -Server $vCenter
                            if ($TagAssignments) {
                                Section -Style Heading3 'Tag Assignments' {
                                    $TagAssignments = $TagAssignments | Select-Object Tag, Entity
                                    $TagAssignments | Sort-Object Tag, Entity | Table -Name 'Tag Assignments' -ColumnWidths 50, 50
                                }
                            }
                            #endregion vCenter Server Tag Assignments
                        }
                        #endregion vCenter Server Detailed Information
                    
                        #region vCenter Alarms (Comprehensive Information)
                        if ($InfoLevel.vCenter -ge 5) {
                            Section -Style Heading3 'Alarms' {
                                Paragraph ("The following table details the configuration of the vCenter Server " +
                                    "alarms for $vCenterServerName.")
                                BlankLine
                                $AlarmAction = Get-AlarmAction -Server $vCenter 
                                $AlarmActions = foreach ($Action in $AlarmAction) {
                                    [PSCustomObject]@{
                                        'Alarm Name' = $Action.AlarmDefinition
                                        'Enabled' = Switch ($Action.AlarmDefinition.Enabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'Defined In' = $Action.AlarmDefinition.Entity
                                        'Action Type' = Switch ($Action.ActionType) {
                                            'SendSNMP' { 'Send SNMP traps' }
                                            'SendEmail' { 'Send email notifications' }
                                            'ExecuteScript' { 'Run Script' }
                                        }
                                        'Trigger' = $Action.Trigger -join [Environment]::NewLine
                                    }
                                }
                                $AlarmActions | Sort-Object 'Alarm Name' | Table -Name 'Alarm Actions' #-ColumnWidths 50, 20, 30
                            }
                        }
                        #endregion vCenter Alarms (Comprehensive Information)
                    }
                }
                #endregion vCenter Server Section

                #region Clusters
                if ($InfoLevel.Cluster -ge 1) {
                    $Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
                    if ($Clusters) {
                        #region Cluster Section
                        Section -Style Heading2 'Clusters' {
                            Paragraph "The following sections detail the configuration of vSphere HA/DRS clusters managed by vCenter Server $vCenterServerName."
                            #region Cluster Informative Information   
                            if ($InfoLevel.Cluster -eq 2) {
                                BlankLine
                                $ClusterInfo = foreach ($Cluster in $Clusters) {
                                    [PSCustomObject]@{
                                        'Cluster' = $Cluster.Name
                                        'Datacenter' = $Cluster | Get-Datacenter
                                        '# of Hosts' = $Cluster.ExtensionData.Host.Count 
                                        '# of VMs' = $Cluster.ExtensionData.VM.Count
                                        'vSphere HA' = Switch ($Cluster.HAEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'Virtual SAN' = Switch ($Cluster.VsanEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'EVC Mode' = Switch ($Cluster.EVCMode) {
                                            $null { 'Disabled' }
                                            default { $EvcModeLookup."$($Cluster.EVCMode)" }
                                        }  
                                        'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                            'WithVM' { 'With VM' }
                                            'InHostDatastore' { 'In Host Datastore' }
                                            default { $Cluster.VMSwapfilePolicy }
                                        }                    
                                    }
                                }
                                if ($Healthcheck.Cluster.HAEnabled) {
                                    $ClusterInfo | Where-Object { $_.'vSphere HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere HA'
                                }
                                if ($Healthcheck.Cluster.DrsEnabled) {
                                    $ClusterInfo | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                }
                                if ($Healthcheck.Cluster.VsanEnabled) {
                                    $ClusterInfo | Where-Object { $_.'Virtual SAN' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Virtual SAN'
                                }
                                if ($Healthcheck.Cluster.EvcEnabled) {
                                    $ClusterInfo | Where-Object { $_.'EVC Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'EVC Mode'
                                }
                                $ClusterInfo | Table -Name 'Cluster Information' #-ColumnWidths 15, 15, 8, 11, 11, 11, 11, 10, 8    
                            }
                            #endregion Cluster Informative Information

                            #region Cluster Detailed Information
                            if ($InfoLevel.Cluster -ge 3) {  
                                foreach ($Cluster in ($Clusters)) {
                                    $ClusterDasConfig = $Cluster.ExtensionData.Configuration.DasConfig
                                    $ClusterDrsConfig = $Cluster.ExtensionData.Configuration.DrsConfig
                                    $ClusterConfigEx = $Cluster.ExtensionData.ConfigurationEx
                                    #region Cluster Section
                                    Section -Style Heading3 $Cluster {
                                        Paragraph "The following table details the configuration for cluster $Cluster."
                                        BlankLine
                                        #region Cluster Configuration                                
                                        $ClusterDetail = [PSCustomObject]@{
                                            'Cluster' = $Cluster.Name
                                            'ID' = $Cluster.Id
                                            'Datacenter' = $Cluster | Get-Datacenter
                                            'Number of Hosts' = $Cluster.ExtensionData.Host.Count 
                                            'Number of VMs' = ($Cluster | Get-VM).Count 
                                            'vSphere HA' = Switch ($Cluster.HAEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Virtual SAN' = Switch ($Cluster.VsanEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'EVC Mode' = Switch ($Cluster.EVCMode) {
                                                $null { 'Disabled' }
                                                default { $EvcModeLookup."$($Cluster.EVCMode)" }
                                            } 
                                            'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                                'WithVM' { 'Virtual machine directory' }
                                                'InHostDatastore' { 'Datastore specified by host' }
                                                default { $Cluster.VMSwapfilePolicy }
                                            }   
                                        }                                
                                        if ($Healthcheck.Cluster.HAEnabled) {
                                            $ClusterDetail | Where-Object { $_.'vSphere HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere HA'
                                        }
                                        if ($Healthcheck.Cluster.DrsEnabled) {
                                            $ClusterDetail | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                        }
                                        if ($Healthcheck.Cluster.VsanEnabled) {
                                            $ClusterDetail | Where-Object { $_.'Virtual SAN' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Virtual SAN'
                                        }
                                        if ($Healthcheck.Cluster.EvcEnabled) {
                                            $ClusterDetail | Where-Object { $_.'EVC Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'EVC Mode'
                                        }
                                        #region Cluster Advanced Detailed Information
                                        if ($InfoLevel.Cluster -ge 4) {
                                            $ClusterDetail | ForEach-Object {
                                                $ClusterHosts = $Cluster | Get-VMHost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($ClusterHosts.Name -join ', ')
                                                $ClusterVMs = $Cluster | Get-VM | Sort-Object Name 
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ClusterVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Cluster Advanced Detailed Information
                                        $ClusterDetail | Table -List -Name "$Cluster Detailed Information" -ColumnWidths 50, 50
                                        #endregion Cluster Configuration
                                
                                        #region vSphere HA Cluster Configuration
                                        if ($Cluster.HAEnabled) {
                                            Section -Style Heading4 'vSphere HA Configuration' {
                                                Paragraph "The following section details the vSphere HA configuration for $Cluster cluster."
                                                #region vSphere HA Cluster Failures and Responses
                                                Section -Style Heading5 'Failures and Responses' {
                                                    $HAClusterResponses = [PSCustomObject]@{
                                                        'Host Monitoring' = $TextInfo.ToTitleCase($ClusterDasConfig.HostMonitoring)
                                                    }
                                                    if ($ClusterDasConfig.HostMonitoring -eq 'Enabled') {
                                                        $MemberProps = @{
                                                            'InputObject' = $HAClusterResponses
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        if ($ClusterDasConfig.DefaultVmSettings.RestartPriority -eq 'Disabled') {
                                                            Add-Member @MemberProps -Name 'Host Failure Response' -Value 'Disabled'
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Host Failure Response' -Value 'Restart VMs'
                                                            Switch ($Cluster.HAIsolationResponse) {
                                                                'DoNothing' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Disabled'
                                                                }
                                                                'Shutdown' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Shutdown and restart VMs'
                                                                }
                                                                'PowerOff' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Power off and restart VMs'
                                                                }
                                                            }
                                                            Add-Member @MemberProps -Name 'VM Restart Priority' -Value $Cluster.HARestartPriority
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForPDL) {
                                                                'disabled' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Disabled'
                                                                }
                                                                'warning' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Issue events'
                                                                }
                                                                'restartAggressive' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Power off and restart VMs'
                                                                }
                                                            }
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForAPD) {
                                                                'disabled' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Disabled'
                                                                }
                                                                'warning' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Issue events'
                                                                }
                                                                'restartConservative' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Power off and restart VMs (conservative)'
                                                                }
                                                                'restartAggressive' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Power off and restart VMs (aggressive)'
                                                                }
                                                            }
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmReactionOnAPDCleared) {
                                                                'none' {
                                                                    Add-Member @MemberProps -Name 'APD recovery after APD timeout' -Value 'Disabled'
                                                                }
                                                                'reset' {
                                                                    Add-Member @MemberProps -Name 'APD recovery after APD timeout' -Value 'Reset VMs'
                                                                }
                                                            }
                                                        }
                                                        Switch ($ClusterDasConfig.VmMonitoring) {
                                                            'vmMonitoringDisabled' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'Disabled'
                                                            }
                                                            'vmMonitoringOnly' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'VM monitoring only'
                                                            }
                                                            'vmAndAppMonitoring' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'VM and application monitoring'
                                                            }
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.HostFailureResponse) {
                                                        $HAClusterResponses | Where-Object { $_.'Host Failure Response' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Host Failure Response'
                                                    }
                                                    if ($Healthcheck.Cluster.HostMonitoring) {
                                                        $HAClusterResponses | Where-Object { $_.'Host Monitoring' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Host Monitoring'
                                                    }
                                                    if ($Healthcheck.Cluster.DatastoreOnPDL) {
                                                        $HAClusterResponses | Where-Object { $_.'Datastore with Permanent Device Loss' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Datastore with Permanent Device Loss'
                                                    }
                                                    if ($Healthcheck.Cluster.DatastoreOnAPD) {
                                                        $HAClusterResponses | Where-Object { $_.'Datastore with All Paths Down' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Datastore with All Paths Down'
                                                    }
                                                    if ($Healthcheck.Cluster.APDTimeout) {
                                                        $HAClusterResponses | Where-Object { $_.'APD recovery after APD timeout' -eq 'Disabled' } | Set-Style -Style Warning -Property 'APD recovery after APD timeout'
                                                    }
                                                    if ($Healthcheck.Cluster.vmMonitoring) {
                                                        $HAClusterResponses | Where-Object { $_.'VM Monitoring' -eq 'Disabled' } | Set-Style -Style Warning -Property 'VM Monitoring'
                                                    }
                                                    $HAClusterResponses | Table -Name "$Cluster vSphere HA Failures and Responses Configuration" -List -ColumnWidths 50, 50
                                                }
                                                #endregion vSphere HA Cluster Failures and Responses

                                                #region vSphere HA Cluster Admission Control
                                                Section -Style Heading5 'Admission Control' {
                                                    $HAAdmissionControl = [PSCustomObject]@{
                                                        'Admission Control' = Switch ($Cluster.HAAdmissionControlEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                    if ($Cluster.HAAdmissionControlEnabled) {
                                                        $MemberProps = @{
                                                            'InputObject' = $HAAdmissionControl
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Add-Member @MemberProps -Name 'Host Failures Cluster Tolerates' -Value $Cluster.HAFailoverLevel
                                                        Switch ($ClusterDasConfig.AdmissionControlPolicy.GetType().Name) {
                                                            'ClusterFailoverHostAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Dedicated failover hosts'
                                                            }
                                                            'ClusterFailoverResourcesAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Cluster resource percentage'
                                                            }
                                                            'ClusterFailoverLevelAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Slot policy'
                                                            }
                                                        }
                                                        Switch ($ClusterDasConfig.AdmissionControlPolicy.AutoComputePercentages) {
                                                            $true {
                                                                Add-Member @MemberProps -Name 'Override Calculated Failover Capacity' -Value 'No'
                                                            }
                                                            $false {
                                                                Add-Member @MemberProps -Name 'Override Calculated Failover Capacity' -Value 'Yes'
                                                                Add-Member @MemberProps -Name 'CPU %' -Value $ClusterDasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent
                                                                Add-Member @MemberProps -Name 'Memory %' -Value $ClusterDasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent
                                                            }
                                                        }
                                                        if ($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy) {
                                                            Add-Member @MemberProps -Name 'Slot Policy' -Value 'Fixed slot size'
                                                            Add-Member @MemberProps -Name 'CPU Slot Size' -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Cpu) MHz"
                                                            Add-Member @MemberProps -Name 'Memory Slot Size' -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Memory) MB"
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Slot Policy' -Value 'Cover all powered-on virtual machines'
                                                        }
                                                        if ($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent) {
                                                            Add-Member @MemberProps -Name 'Performance Degradation VMs Tolerate' -Value "$($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent)%"
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.HAAdmissionControl) {
                                                        $HAAdmissionControl | Where-Object { $_.'Admission Control' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Admission Control'
                                                    }
                                                    $HAAdmissionControl | Table -Name "$Cluster vSphere HA Admission Control Configuration" -List -ColumnWidths 50, 50
                                                }
                                                #endregion vSphere HA Cluster Admission Control

                                                #region vSphere HA Cluster Heartbeat Datastores
                                                Section -Style Heading5 'Heartbeat Datastores' {
                                                    $HeartbeatDatastores = [PSCustomObject]@{
                                                        'Heartbeat Selection Policy' = Switch ($ClusterDasConfig.HBDatastoreCandidatePolicy) {
                                                            'allFeasibleDsWithUserPreference' { 'Use datastores from the specified list and complement automatically if needed' }
                                                            'allFeasibleDs' { 'Automatically select datastores accessible from the host' }
                                                            'userSelectedDs' { 'Use datastores only from the specified list' }
                                                            default { $ClusterDasConfig.HBDatastoreCandidatePolicy }
                                                        }
                                                        'Heartbeat Datastores' = try {
                                                            (((Get-View -Id $ClusterDasConfig.HeartbeatDatastore -Property Name).Name | Sort-Object) -join ', ')
                                                        } catch {
                                                            'None specified'
                                                        }
                                                    }
                                                    $HeartbeatDatastores | Table -Name "$Cluster vSphere HA Heartbeat Datastores" -List -ColumnWidths 50, 50
                                                }
                                                #endregion vSphere HA Cluster Heartbeat Datastores

                                                #region vSphere HA Cluster Advanced Options
                                                $HAAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterHA' }
                                                if ($HAAdvancedSettings) {
                                                    Section -Style Heading5 'vSphere HA Advanced Options' {
                                                        $HAAdvancedOptions = @()
                                                        foreach ($HAAdvancedSetting in $HAAdvancedSettings) { 
                                                            $HAAdvancedOption = [PSCustomObject]@{
                                                                'Option' = $HAAdvancedSetting.Name
                                                                'Value' = $HAAdvancedSetting.Value
                                                            }
                                                            $HAAdvancedOptions += $HAAdvancedOption
                                                        }
                                                        $HAAdvancedOptions | Sort-Object Option | Table -Name "$Cluster vSphere HA Advanced Options" -ColumnWidths 50, 50
                                                    }
                                                }
                                                #endregion vSphere HA Cluster Advanced Options
                                            }
                                        }
                                        #endregion vSphere HA Cluster Configuration

                                        #region Proactive HA Configuration
                                        # TODO: Proactive HA Providers
                                        # Proactive HA is only available in vSphere 6.5 and above
                                        if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled -and $vCenter.Version -ge 6.5) {
                                            Section -Style Heading4 'Proactive HA' {
                                                Paragraph "The following section details the Proactive HA configuration for $Cluster cluster."
                                                #region Proactive HA Failures and Responses Section
                                                Section -Style Heading5 'Failures and Responses' {
                                                    $ProactiveHa = [PSCustomObject]@{
                                                        'Proactive HA' = Switch ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                    if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                                                        $ProactiveHaModerateRemediation = Switch ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation) {
                                                            'MaintenanceMode' { 'Maintenance Mode' }
                                                            'QuarantineMode' { 'Quarantine Mode' }
                                                            default { $ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation }
                                                        }
                                                        $ProactiveHaSevereRemediation = Switch ($ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                                            'MaintenanceMode' { 'Maintenance Mode' }
                                                            'QuarantineMode' { 'Quarantine Mode' }
                                                            default { $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $ProactiveHa
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value $ClusterConfigEx.InfraUpdateHaConfig.Behavior
                                                        if ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation -eq $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                                            Add-Member @MemberProps -Name 'Remediation' -Value $ProactiveHaModerateRemediation
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Remediation' -Value 'Mixed Mode'
                                                            Add-Member @MemberProps -Name 'Moderate Remediation' -Value $ProactiveHaModerateRemediation
                                                            Add-Member @MemberProps -Name 'Severe Remediation' -Value $ProactiveHaSevereRemediation
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.ProactiveHA) {
                                                        $ProactiveHa | Where-Object { $_.'Proactive HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Proactive HA'
                                                    }
                                                    $ProactiveHa | Table -Name "$Cluster Proactive HA Configuration" -List -ColumnWidths 50, 50
                                                }
                                                #endregion Proactive HA Failures and Responses Section
                                            }
                                        }
                                        #endregion Proactive HA Configuration

                                        #region vSphere DRS Cluster Configuration
                                        if ($Cluster.DrsEnabled) {
                                            Section -Style Heading4 'vSphere DRS Configuration' {
                                                Paragraph ("The following table details the vSphere DRS configuration " +
                                                    "for cluster $Cluster.")
                                                BlankLine

                                                #region vSphere DRS Cluster Specifications
                                                $DrsCluster = [PSCustomObject]@{
                                                    'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                                        $true { 'Enabled' }
                                                        $false { 'Disabled' }
                                                    }
                                                }
                                                $MemberProps = @{
                                                    'InputObject' = $DrsCluster
                                                    'MemberType' = 'NoteProperty'
                                                }
                                                Switch ($Cluster.DrsAutomationLevel) {
                                                    'Manual' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Manual'
                                                    }
                                                    'PartiallyAutomated' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Partially Automated'
                                                    }
                                                    'FullyAutomated' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Fully Automated'
                                                    }
                                                } 
                                                Add-Member @MemberProps -Name 'Migration Threshold' -Value $ClusterDrsConfig.VmotionRate
                                                Switch ($ClusterConfigEx.ProactiveDrsConfig.Enabled) {
                                                    $false {
                                                        Add-Member @MemberProps -Name 'Predictive DRS' -Value 'Disabled'
                                                    }
                                                    $true {
                                                        Add-Member @MemberProps -Name 'Predictive DRS' -Value 'Enabled'
                                                    }
                                                } 
                                                Switch ($ClusterDrsConfig.EnableVmBehaviorOverrides) {
                                                    $true {
                                                        Add-Member @MemberProps -Name 'Virtual Machine Automation' -Value 'Enabled'
                                                    }
                                                    $false {
                                                        Add-Member @MemberProps -Name 'Virtual Machine Automation' -Value 'Disabled'
                                                    }
                                                }
                                                if ($Healthcheck.Cluster.DrsEnabled) {
                                                    $DrsCluster | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                                }
                                                if ($Healthcheck.Cluster.DrsAutomationLevelFullyAuto) {
                                                    $DrsCluster | Where-Object { $_.'Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'Automation Level'
                                                }
                                                $DrsCluster | Table -Name "$Cluster vSphere DRS Configuration" -List -ColumnWidths 50, 50 
                                                #endregion vSphere DRS Cluster Specfications

                                                #region DRS Cluster Additional Options
                                                $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                                                if ($DrsAdvancedSettings) {    
                                                    Section -Style Heading5 'Additional Options' {
                                                        $DrsAdditionalOptions = [PSCustomObject] @{
                                                            'VM Distribution' = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'TryBalanceVmsPerHost' }).Value) {
                                                                '1' { 'Enabled' }
                                                                $null { 'Disabled' }
                                                            }
                                                            'Memory Metric for Load Balancing' = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'PercentIdleMBInMemDemand' }).Value) {
                                                                '100' { 'Enabled' }
                                                                $null { 'Disabled' }
                                                            }
                                                            'CPU Over-Commitment' = if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                                                'Enabled'
                                                            } else {
                                                                'Disabled'
                                                            }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $DrsAdditionalOptions
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                                            Add-Member @MemberProps -Name 'Over-Commitment Ratio' -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerCore'}).Value):1 (vCPU:pCPU)"
                                                        }
                                                        if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerClusterPct' }).Value) {
                                                            Add-Member @MemberProps -Name 'Over-Commitment Ratio (% of cluster capacity)' -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerClusterPct'}).Value) %"
                                                        }
                                                        $DrsAdditionalOptions | Table -Name "$Cluster DRS Additional Options" -List -ColumnWidths 50, 50
                                                    }
                                                }
                                                #endregion DRS Cluster Additional Options

                                                #region vSphere DPM Configuration
                                                if ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                                                    Section -Style Heading5 'Power Management' {
                                                        $DpmConfig = [PSCustomObject]@{
                                                            'DPM' = Switch ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $DpmConfig
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Switch ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior) {
                                                            'manual' {
                                                                Add-Member @MemberProps -Name 'Automation Level' -Value 'Manual'
                                                            }
                                                            'automated' {
                                                                Add-Member @MemberProps -Name 'Automation Level' -Value 'Automated'
                                                            }
                                                        }
                                                        if ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior -eq 'automated') {
                                                            Add-Member @MemberProps -Name 'DPM Threshold' -Value $ClusterConfigEx.DpmConfigInfo.HostPowerActionRate
                                                        }
                                                        $DpmConfig | Table -Name "$Cluster vSphere DPM Configuration" -List -ColumnWidths 50, 50 
                                                    }
                                                }
                                                #endregion vSphere DPM Configuration

                                                #region vSphere DRS Cluster Advanced Options
                                                $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                                                if ($DrsAdvancedSettings) {
                                                    Section -Style Heading5 'Advanced Options' {
                                                        $DrsAdvancedOptions = @()
                                                        foreach ($DrsAdvancedSetting in $DrsAdvancedSettings) { 
                                                            $DrsAdvancedOption = [PSCustomObject]@{
                                                                'Option' = $DrsAdvancedSetting.Name
                                                                'Value' = $DrsAdvancedSetting.Value
                                                            }
                                                            $DrsAdvancedOptions += $DrsAdvancedOption
                                                        }
                                                        $DrsAdvancedOptions | Sort-Object Option | Table -Name "$Cluster vSphere DRS Advanced Options" -ColumnWidths 50, 50
                                                    }
                                                }
                                                #endregion vSphere DRS Cluster Advanced Options

                                                #region vSphere DRS Cluster Group
                                                $DrsClusterGroups = $Cluster | Get-DrsClusterGroup
                                                if ($DrsClusterGroups) {
                                                    #region vSphere DRS Cluster Group Section 
                                                    Section -Style Heading5 'DRS Cluster Groups' {
                                                        $DrsGroups = foreach ($DrsClusterGroup in $DrsClusterGroups) {
                                                            [PSCustomObject]@{
                                                                'DRS Cluster Group' = $DrsClusterGroup.Name
                                                                'Type' = Switch ($DrsClusterGroup.GroupType) {
                                                                    'VMGroup' { 'VM Group' }
                                                                    'VMHostGroup' { 'Host Group' }
                                                                    default { $DrsClusterGroup.GroupType }
                                                                }
                                                                'Members' = Switch (($DrsClusterGroup.Member).Count -gt 0) {
                                                                    $true { ($DrsClusterGroup.Member | Sort-Object) -join ', ' }
                                                                    $false { "None" }
                                                                }
                                                            }
                                                        }
                                                        $DrsGroups | Sort-Object 'DRS Cluster Group', 'Type' | Table -Name "$Cluster DRS Cluster Groups"
                                                    }
                                                    #endregion vSphere DRS Cluster Group Section 

                                                    #region vSphere DRS Cluster VM/Host Rules
                                                    $DrsVMHostRules = $Cluster | Get-DrsVMHostRule
                                                    if ($DrsVMHostRules) {
                                                        Section -Style Heading5 'DRS VM/Host Rules' {
                                                            $DrsVMHostRuleDetail = foreach ($DrsVMHostRule in $DrsVMHostRules) {
                                                                [PSCustomObject]@{
                                                                    'DRS VM/Host Rule' = $DrsVMHostRule.Name
                                                                    'Type' = Switch ($DrsVMHostRule.Type) {
                                                                        'MustRunOn' { 'Must run on hosts in group' }
                                                                        'ShouldRunOn' { 'Should run on hosts in group' }
                                                                        'MustNotRunOn' { 'Must not run on hosts in group' }
                                                                        'ShouldNotRunOn' { 'Should not run on hosts in group' }
                                                                        default { $DrsVMHostRule.Type }
                                                                    }
                                                                    'Enabled' = Switch ($DrsVMHostRule.Enabled) {
                                                                        $true { 'Yes' }
                                                                        $False { 'No' }
                                                                    }
                                                                    'VM Group' = $DrsVMHostRule.VMGroup
                                                                    'Host Group' = $DrsVMHostRule.VMHostGroup
                                                                }
                                                            }
                                                            if ($Healthcheck.Cluster.DrsVMHostRules) {
                                                                $DrsVMHostRuleDetail | Where-Object { $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Enabled'
                                                            }
                                                            $DrsVMHostRuleDetail | Sort-Object 'DRS VM/Host Rule' | Table -Name "$Cluster DRS VM/Host Rules"
                                                        }
                                                    }
                                                    #endregion vSphere DRS Cluster VM/Host Rules

                                                    #region vSphere DRS Cluster Rules
                                                    $DrsRules = $Cluster | Get-DrsRule
                                                    if ($DrsRules) {
                                                        #region vSphere DRS Cluster Rules Section 
                                                        Section -Style Heading5 'DRS Rules' {
                                                            $DrsRuleDetail = foreach ($DrsRule in $DrsRules) {
                                                                [PSCustomObject]@{
                                                                    'DRS Rule' = $DrsRule.Name
                                                                    'Type' = Switch ($DrsRule.Type) {
                                                                        'VMAffinity' { 'Keep Vitrual Machines Together' }
                                                                        'VMAntiAffinity' { 'Separate Virtual Machines' }
                                                                    }
                                                                    'Enabled' = Switch ($DrsRule.Enabled) {
                                                                        $true { 'Yes' }
                                                                        $False { 'No' }
                                                                    }
                                                                    'Mandatory' = $DrsRule.Mandatory
                                                                    'Virtual Machines' = ($DrsRule.VMIds | ForEach-Object { (Get-View -id $_).name }) -join ', '
                                                                }
                                                                if ($Healthcheck.Cluster.DrsRules) {
                                                                    $DrsRuleDetail | Where-Object { $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Enabled'
                                                                }
                                                            }
                                                            $DrsRuleDetail | Sort-Object Type | Table -Name "$Cluster DRS Rules"
                                                        }
                                                        #endregion vSphere DRS Cluster Rules Section                               
                                                    }
                                                    #endregion vSphere DRS Cluster Rules
                                                }
                                                #endregion vSphere DRS Cluster Group

                                                #region Cluster VM Overrides
                                                $DrsVmOverrides = $Cluster.ExtensionData.Configuration.DrsVmConfig
                                                $DasVmOverrides = $Cluster.ExtensionData.Configuration.DasVmConfig
                                                if ($DrsVmOverrides -or $DasVmOverrides) {
                                                    #region VM Overrides Section
                                                    Section -Style Heading4 'VM Overrides' {
                                                        #region vSphere DRS VM Overrides
                                                        if ($DrsVmOverrides) {
                                                            Section -Style Heading5 'vSphere DRS' {
                                                                $DrsVmOverrideDetails = foreach ($DrsVmOverride in $DrsVmOverrides) {
                                                                    [PSCustomObject]@{
                                                                        'Virtual Machine' = $VMLookup."$($DrsVmOverride.Key.Type)-$($DrsVmOverride.Key.Value)"
                                                                        'vSphere DRS Automation Level' = if ($DrsVmOverride.Enabled -eq $false) {
                                                                            'Disabled'
                                                                        } else {
                                                                            Switch ($DrsVmOverride.Behavior) {
                                                                                'manual' { 'Manual' }
                                                                                'partiallyAutomated' { 'Partially Automated' }
                                                                                'fullyAutomated' { 'Fully Automated' }
                                                                                default { $DrsVmOverride.Behavior }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                                $DrsVmOverrideDetails | Sort-Object 'Virtual Machine' | Table -Name "$Cluster DRS VM Overrides" -ColumnWidths 50, 50
                                                            }
                                                        }
                                                        #endregion vSphere DRS VM Overrides

                                                        #region vSphere HA VM Overrides
                                                        if ($DasVmOverrides) {
                                                            Section -Style Heading5 'vSphere HA' {
                                                                $DasVmOverrideDetails = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                    [PSCustomObject]@{
                                                                        'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                        'VM Restart Priority' = Switch ($DasVmOverride.DasSettings.RestartPriority) {
                                                                            $null { '--' }
                                                                            'lowest' { 'Lowest' }
                                                                            'low' { 'Low' }
                                                                            'medium' { 'Medium' }
                                                                            'high' { 'High' }
                                                                            'highest' { 'Highest' }
                                                                            'disabled' { 'Disabled' }
                                                                            'clusterRestartPriority' { 'Cluster default' }
                                                                        }
                                                                        'VM Dependency Restart Condition Timeout' = Switch ($DasVmOverride.DasSettings.RestartPriorityTimeout) {
                                                                            $null { '--' }
                                                                            '-1' { 'Disabled' }
                                                                            default { "$($DasVmOverride.DasSettings.RestartPriorityTimeout) seconds" }
                                                                        }
                                                                        'Host Isolation Response' = Switch ($DasVmOverride.DasSettings.IsolationResponse) {
                                                                            $null { '--' }
                                                                            'none' { 'Disabled' }
                                                                            'powerOff' { 'Power off and restart VMs' }
                                                                            'shutdown' { 'Shutdown and restart VMs' }
                                                                            'clusterIsolationResponse' { 'Cluster default' }
                                                                        }
                                                                    }
                                                                }
                                                                $DasVmOverrideDetails | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides" -ColumnWidths 25, 25, 25, 25

                                                                #region PDL/APD Protection Settings Section
                                                                Section -Style Heading5 'PDL/APD Protection Settings' {
                                                                    $DasVmOverridePdlApd = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmComponentProtection = $DasVmOverride.DasSettings.VmComponentProtectionSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'PDL Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForPDL) {
                                                                                $null { '--' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartAggressive' { 'Power off and restart VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'APD Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForAPD) {
                                                                                $null { '--' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartConservative' { 'Power off and restart VMs - Conservative restart policy' }
                                                                                'restartAggressive' { 'Power off and restart VMs - Aggressive restart policy' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'VM Failover Delay' = Switch ($DasVmComponentProtection.VmTerminateDelayForAPDSec) {
                                                                                $null { '--' }
                                                                                '-1' { 'Disabled' }
                                                                                default { "$(($DasVmComponentProtection.VmTerminateDelayForAPDSec)/60) minutes" }
                                                                            }
                                                                            'Response Recovery' = Switch ($DasVmComponentProtection.VmReactionOnAPDCleared) {
                                                                                $null { '--' }
                                                                                'reset' { 'Reset VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                                'useClusterDefault' { 'Cluster default' }
                                                                            }
                                                                        }
                                                                    }
                                                                    $DasVmOverridePdlApd | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides PDL/APD Settings" -ColumnWidths 20, 20, 20, 20, 20
                                                                }
                                                                #endregion PDL/APD Protection Settings Section

                                                                #region VM Monitoring Section
                                                                Section -Style Heading5 'VM Monitoring' {
                                                                    $DasVmOverrideVmMonitoring = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmMonitoring = $DasVmOverride.DasSettings.VmToolsMonitoringSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'VM Monitoring' = Switch ($DasVmMonitoring.VmMonitoring) {
                                                                                $null { '--' }
                                                                                'vmMonitoringDisabled' { 'Disabled' }
                                                                                'vmMonitoringOnly' { 'VM Monitoring Only' }
                                                                                'vmAndAppMonitoring' { 'VM and App Monitoring' }
                                                                            }
                                                                            'Failure Interval' = Switch ($DasVmMonitoring.FailureInterval) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.FailureInterval) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Minimum Uptime' = Switch ($DasVmMonitoring.MinUptime) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.MinUptime) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Per-VM Resets' = Switch ($DasVmMonitoring.MaxFailures) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        $DasVmMonitoring.MaxFailures
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Resets Time Window' = Switch ($DasVmMonitoring.MaxFailureWindow) {
                                                                                $null { '--' }
                                                                                '-1' { 'No window' }                                                                
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "Within $(($DasVmMonitoring.MaxFailureWindow)/3600) hrs"
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                    $DasVmOverrideVmMonitoring | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides VM Monitoring"
                                                                }
                                                                #endregion VM Monitoring Section
                                                            }
                                                        }
                                                        #endregion vSphere HA VM Overrides
                                                    }
                                                    #endregion VM Overrides Section
                                                }
                                                #endregion Cluster VM Overrides
                                
                                                #region Cluster VUM Baselines
                                                if ($VUMConnection) {
                                                    $ClusterPatchBaselines = $Cluster | Get-PatchBaseline
                                                    if ($ClusterPatchBaselines) {
                                                        Section -Style Heading4 'Update Manager Baselines' {
                                                            $ClusterBaselines = foreach ($ClusterBaseline in $ClusterPatchBaselines) {
                                                                [PSCustomObject]@{
                                                                    'Baseline' = $ClusterBaseline.Name
                                                                    'Description' = $ClusterBaseline.Description
                                                                    'Type' = $ClusterBaseline.BaselineType
                                                                    'Target Type' = $ClusterBaseline.TargetType
                                                                    'Last Update Time' = ($ClusterBaseline.LastUpdateTime).ToLocalTime()
                                                                    '# of Patches' = $ClusterBaseline.CurrentPatches.Count
                                                                }
                                                            }
                                                            $ClusterBaselines | Sort-Object 'Baseline' | Table -Name "$Cluster Update Manager Baselines"
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.VUMCompliance) {
                                                        $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                        $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                    }
                                                    $ClusterComplianceInfo | Sort-Object Name, Baseline | Table -Name "$Cluster Update Manager Compliance" -ColumnWidths 25, 50, 25
                                                }
                                                #endregion Cluster VUM Baselines

                                                #region Cluster VUM Compliance (Advanced Detail Information)
                                                if ($InfoLevel.Cluster -ge 4 -and $VumServer.Name) {
                                                    $ClusterCompliances = $Cluster | Get-Compliance
                                                    if ($ClusterCompliances) {
                                                        Section -Style Heading4 'Update Manager Compliance' {
                                                            $ClusterComplianceInfo = foreach ($ClusterCompliance in $ClusterCompliances) {
                                                                [PSCustomObject]@{
                                                                    'Entity' = $ClusterCompliance.Entity
                                                                    'Baseline' = $ClusterCompliance.Baseline.Name
                                                                    'Status' = Switch ($ClusterCompliance.Status) {
                                                                        'NotCompliant' { 'Not Compliant' }
                                                                        default { $ClusterCompliance.Status }
                                                                    }
                                                                }
                                                            }
                                                            if ($Healthcheck.Cluster.VUMCompliance) {
                                                                $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                                $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                            }
                                                            $ClusterComplianceInfo | Sort-Object Entity, Baseline | Table -Name "$Cluster Update Manager Compliance" -ColumnWidths 25, 50, 25
                                                        }
                                                    }
                                                }
                                                #endregion Cluster VUM Compliance (Advanced Detail Information)
                
                                                #region Cluster Permissions
                                                Section -Style Heading4 'Permissions' {
                                                    Paragraph "The following table details the permissions assigned to cluster $Cluster."
                                                    BlankLine
                                                    $VIPermissions = $Cluster | Get-VIPermission
                                                    $ClusterVIPermissions = foreach ($VIPermission in $VIPermissions) {
                                                        [PSCustomObject]@{
                                                            'User/Group' = $VIPermission.Principal 
                                                            'Is Group?' = Switch ($VIPermission.IsGroup) {
                                                                $true { 'Yes' }
                                                                $false { 'No' }
                                                            }
                                                            'Role' = $VIPermission.Role
                                                            'Defined In' = $VIPermission.Entity
                                                            'Propagate' = Switch ($VIPermission.Propagate) {
                                                                $true { 'Yes' }
                                                                $false { 'No' }
                                                            }
                                                        }
                                                    }
                                                    $ClusterVIPermissions | Sort-Object 'User/Group' | Table -Name "$Cluster Permissions"
                                                }
                                                #endregion Cluster Permissions
                                            }
                                        }
                                        #endregion vSphere DRS Cluster Configuration
                                    }
                                    #endregion Cluster Section
                                }
                            }
                            #endregion Cluster Detailed Information
                        }
                        #endregion Cluster Section
                    }
                }
                #endregion Clusters   

                #region Resource Pool Section
                if ($InfoLevel.ResourcePool -ge 1) {
                    $ResourcePools = Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
                    if ($ResourcePools) {
                        #region Resource Pools Section
                        Section -Style Heading2 'Resource Pools' {
                            Paragraph "The following sections detail the configuration of resource pools managed by vCenter Server $vCenterServerName."
                            #region Resource Pool Informative Information
                            if ($InfoLevel.ResourcePool -eq 2) {
                                BlankLine
                                $ResourcePoolInfo = foreach ($ResourcePool in $ResourcePools) {
                                    [PSCustomObject]@{
                                        'Resource Pool' = $ResourcePool.Name
                                        'Parent' = $ResourcePool.Parent
                                        'CPU Shares Level' = $ResourcePool.CpuSharesLevel 
                                        'CPU Reservation MHz' = $ResourcePool.CpuReservationMHz 
                                        'CPU Limit MHz' = Switch ($ResourcePool.CpuLimitMHz) {
                                            '-1' { 'Unlimited' }
                                            default { $ResourcePool.CpuLimitMHz }
                                        }
                                        'Memory Shares Level' = $ResourcePool.MemSharesLevel 
                                        'Memory Reservation' = [math]::Round($ResourcePool.MemReservationGB, 2)
                                        'Memory Limit GB' = Switch ($ResourcePool.MemLimitGB) {
                                            '-1' { 'Unlimited' }
                                            default { [math]::Round($ResourcePool.MemLimitGB, 2) }
                                        }
                                    }
                                }
                                $ResourcePoolInfo | Sort-Object Name | Table -Name 'Resource Pool Information' #-ColumnWidths 11,11,13,13,13,13,13,13
                            }                    
                            #endregion Resource Pool Informative Information

                            #region Resource Pool Detailed Information
                            if ($InfoLevel.ResourcePool -ge 3) {
                                foreach ($ResourcePool in $ResourcePools) {
                                    Section -Style Heading3 $ResourcePool.Name {            
                                        $ResourcePoolDetail = [PSCustomObject]@{
                                            'Resource Pool' = $ResourcePool.Name
                                            'ID' = $ResourcePool.Id
                                            'Parent' = $ResourcePool.Parent
                                            'CPU Shares Level' = $ResourcePool.CpuSharesLevel 
                                            'Number of CPU Shares' = $ResourcePool.NumCpuShares 
                                            'CPU Reservation' = "$($ResourcePool.CpuReservationMHz) MHz"
                                            'CPU Expandable Reservation' = Switch ($ResourcePool.CpuExpandableReservation) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'CPU Limit MHz' = Switch ($ResourcePool.CpuLimitMHz) {
                                                '-1' { 'Unlimited' }
                                                default { "$($ResourcePool.CpuLimitMHz) MHz" }
                                            }
                                            'Memory Shares Level' = $ResourcePool.MemSharesLevel 
                                            'Number of Memory Shares' = $ResourcePool.NumMemShares 
                                            'Memory Reservation' = "$([math]::Round($ResourcePool.MemReservationGB, 2)) GB" 
                                            'Memory Expandable Reservation' = Switch ($ResourcePool.MemExpandableReservation) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Memory Limit' = Switch ($ResourcePool.MemLimitGB) {
                                                '-1' { 'Unlimited' }
                                                default { "$([math]::Round($ResourcePool.MemLimitGB, 2)) GB" }
                                            }
                                            'Number of VMs' = $ResourcePool.ExtensionData.VM.Count
                                        }

                                        #region Resource Pool Advanced Detail Information
                                        if ($InfoLevel.ResourcePool -ge 4) {
                                            $ResourcePoolDetail | ForEach-Object {
                                                # Query for VMs by resource pool Id
                                                $ResourcePoolId = $_.Id
                                                $ResourcePoolVMs = $VMs | Where-Object { $_.ResourcePoolId -eq $ResourcePoolId } | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ResourcePoolVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Resource Pool Advanced Detail Information
                                        $ResourcePoolDetail | Table -Name 'Resource Pool Detailed Information' -List -ColumnWidths 50, 50  
                                    }
                                }
                            }
                            #endregion Resource Pool Detailed Information
                        }
                        #endregion Resource Pools Section
                    }
                }
                #endregion Resource Pool Section

                #region ESXi VMHost Section
                if ($InfoLevel.VMHost -ge 1) {
                    if ($VMHosts) {
                        #region Hosts Section
                        Section -Style Heading2 'Hosts' {
                            Paragraph "The following sections detail the configuration of VMware ESXi hosts managed by vCenter Server $vCenterServerName."
                            #region ESXi Host Informative Information
                            if ($InfoLevel.VMHost -eq 2) {
                                BlankLine
                                $VMHostInfo = foreach ($VMHost in $VMHosts) {
                                    [PSCustomObject]@{
                                        'Host' = $VMHost.Name
                                        'Version' = $VMHost.Version
                                        'Build' = $VMHost.Build
                                        'Parent' = $VMHost.Parent
                                        'Connection State' = Switch ($VMHost.ConnectionState) {
                                            'NotResponding' { 'Not Responding' }
                                            default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                                        }
                                        'CPU Sockets' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
                                        'CPU Cores' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
                                        'Memory GB' = [math]::Round($VMHost.MemoryTotalGB, 0)
                                        '# of VMs' = $VMHost.ExtensionData.Vm.Count
                                    }
                                }
                                if ($Healthcheck.VMHost.ConnectionState) {
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Maintenance' } | Set-Style -Style Warning
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Not Responding' } | Set-Style -Style Critical
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Disconnected' } | Set-Style -Style Critical
                                }
                                $VMHostInfo | Table -Name 'ESXi Host Information'
                            }
                            #endregion ESXi Host Informative Information

                            #region ESXi Host Detailed Information
                            if ($InfoLevel.VMHost -ge 3) {
                                #region foreach VMHost Detailed Information loop     
                                foreach ($VMHost in ($VMHosts | Where-Object { $_.ConnectionState -eq 'Connected' -or $_.ConnectionState -eq 'Maintenance' })) {        
                                    #region VMHost Section
                                    Section -Style Heading3 $VMHost {
                                        # TODO: Host Certificate, Swap File Location
                                        #region ESXi Host Hardware Section
                                        Section -Style Heading4 'Hardware' {
                                            Paragraph "The following section details the host hardware configuration for $VMHost."
                                            BlankLine

                                            #region ESXi Host Specifications
                                            $VMHostUptime = Get-Uptime -VMHost $VMHost
                                            $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                            $VMHostHardware = Get-VMHostHardware -VMHost $VMHost
                                            $VMHostLicense = Get-License -VMHost $VMHost
                                            $ScratchLocation = Get-AdvancedSetting -Entity $VMHost | Where-Object { $_.Name -eq 'ScratchConfig.CurrentScratchLocation' }
                                            $VMHostDetail = [PSCustomObject]@{
                                                'Host' = $VMHost.Name
                                                'Connection State' = Switch ($VMHost.ConnectionState) {
                                                    'NotResponding' { 'Not Responding' }
                                                    default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                                                }
                                                'ID' = $VMHost.Id
                                                'Parent' = $VMHost.Parent
                                                'Manufacturer' = $VMHost.Manufacturer
                                                'Model' = $VMHost.Model
                                                'Serial Number' = $VMHostHardware.SerialNumber 
                                                'Asset Tag' = Switch ($VMHostHardware.AssetTag) {
                                                    '' { 'Unknown' }
                                                    default { $VMHostHardware.AssetTag }
                                                }
                                                'Processor Type' = $VMHost.Processortype
                                                'HyperThreading' = Switch ($VMHost.HyperthreadingActive) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                }
                                                'Number of CPU Sockets' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages 
                                                'Number of CPU Cores' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores 
                                                'Number of CPU Threads' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuThreads
                                                'CPU Total / Used' = "$([math]::Round(($VMHost.CpuTotalMhz) / 1000, 2)) GHz / $([math]::Round(($VMHost.CpuUsageMhz) / 1000, 2)) GHz"
                                                'Memory Total / Used' = "$([math]::Round($VMHost.MemoryTotalGB, 2)) GB / $([math]::Round($VMHost.MemoryUsageGB, 2)) GB"
                                                'NUMA Nodes' = $VMHost.ExtensionData.Hardware.NumaInfo.NumNodes 
                                                'Number of NICs' = $VMHostHardware.NicCount 
                                                'Number of Datastores' = $VMHost.ExtensionData.Datastore.Count 
                                                'Number of VMs' = $VMHost.ExtensionData.VM.Count 
                                                'Maximum EVC Mode' = $EvcModeLookup."$($VMHost.MaxEVCMode)"
                                                'Power Management Policy' = $VMHost.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy 
                                                'Scratch Location' = $ScratchLocation.Value 
                                                'Bios Version' = $VMHost.ExtensionData.Hardware.BiosInfo.BiosVersion 
                                                'Bios Release Date' = $VMHost.ExtensionData.Hardware.BiosInfo.ReleaseDate 
                                                'ESXi Version' = $VMHost.Version 
                                                'ESXi Build' = $VMHost.build 
                                                'Product' = $VMHostLicense.Product 
                                                'License Key' = $VMHostLicense.LicenseKey
                                                'License Expiration' = $VMHostLicense.Expiration 
                                                'Boot Time' = ($VMHost.ExtensionData.Runtime.Boottime).ToLocalTime()
                                                'Uptime Days' = $VMHostUptime.UptimeDays
                                            }
                                            if ($Healthcheck.VMHost.ConnectionState) {
                                                $VMHostDetail | Where-Object { $_.'Connection State' -eq 'Maintenance' } | Set-Style -Style Warning -Property 'Connection State'
                                            }
                                            if ($Healthcheck.VMHost.HyperThreading) {
                                                $VMHostDetail | Where-Object { $_.'HyperThreading' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Disabled'
                                            }
                                            if ($Healthcheck.VMHost.Licensing) {
                                                $VMHostDetail | Where-Object { $_.'Product' -like '*Evaluation*' } | Set-Style -Style Warning -Property 'Product'
                                                $VMHostDetail | Where-Object { $_.'License Key' -like '*-00000-00000' } | Set-Style -Style Warning -Property 'License Key'
                                                $VMHostDetail | Where-Object { $_.'License Expiration' -eq 'Expired' } | Set-Style -Style Critical -Property 'License Expiration'
                                            }
                                            if ($Healthcheck.VMHost.ScratchLocation) {
                                                $VMHostDetail | Where-Object { $_.'Scratch Location' -eq '/tmp/scratch' } | Set-Style -Style Warning -Property 'Scratch Location'
                                            }
                                            if ($Healthcheck.VMHost.UpTimeDays) {
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 275 -and $_.'Uptime Days' -lt 365 } | Set-Style -Style Warning -Property 'Uptime Days'
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 365 } | Set-Style -Style Critical -Property 'Uptime Days'
                                            }
                                            $VMHostDetail | Table -Name "$VMHost ESXi Host Detailed Information" -List -ColumnWidths 50, 50 
                                            #endregion ESXi Host Specifications

                                            #region ESXi Host Boot Device
                                            Section -Style Heading5 'Boot Device' {
                                                $ESXiBootDevice = Get-ESXiBootDevice -VMHost $VMHost
                                                $VMHostBootDevice = [PSCustomObject]@{
                                                    'Host' = $ESXiBootDevice.Host
                                                    'Device' = $ESXiBootDevice.Device
                                                    'Boot Type' = $ESXiBootDevice.BootType
                                                    'Vendor' = $ESXiBootDevice.Vendor
                                                    'Model' = $ESXiBootDevice.Model
                                                    'Size' = "$([math]::Round($ESXiBootDevice.SizeMB / 1024, 2)) GB"
                                                    'Is SAS' = $ESXiBootDevice.IsSAS
                                                    'Is SSD' = $ESXiBootDevice.IsSSD
                                                    'Is USB' = $ESXiBootDevice.IsUSB
                                                }
                                                $VMHostBootDevice | Table -Name "$VMHost Boot Device" -List -ColumnWidths 50, 50 
                                            }
                                            #endregion ESXi Host Boot Devices

                                            #region ESXi Host PCI Devices
                                            Section -Style Heading5 'PCI Devices' {
                                                $PciHardwareDevices = $esxcli.hardware.pci.list.Invoke() | Where-Object { $_.VMKernelName -like "vmhba*" -OR $_.VMKernelName -like "vmnic*" -OR $_.VMKernelName -like "vmgfx*" } 
                                                $VMHostPciDevices = foreach ($PciHardwareDevice in $PciHardwareDevices) {
                                                    [PSCustomObject]@{
                                                        'VMkernel Name' = $PciHardwareDevice.VMkernelName 
                                                        'PCI Address' = $PciHardwareDevice.Address 
                                                        'Device Class' = $PciHardwareDevice.DeviceClassName 
                                                        'Device Name' = $PciHardwareDevice.DeviceName 
                                                        'Vendor Name' = $PciHardwareDevice.VendorName 
                                                        'Slot Description' = $PciHardwareDevice.SlotDescription
                                                    }
                                                }
                                                $VMHostPciDevices | Sort-Object 'VMkernel Name' | Table -Name "$VMHost PCI Devices" 
                                            }
                                            #endregion ESXi Host PCI Devices
                            
                                            #region ESXi Host PCI Devices Drivers & Firmware
                                            Section -Style Heading5 'PCI Devices Drivers & Firmware' {
                                                $VMHostPciDevicesDetails = Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli 
                                                $VMHostPciDevicesDetails | Sort-Object 'VMkernel Name' | Table -Name "$VMHost PCI Devices Drivers & Firmware" 
                                            }
                                            #endregion ESXi Host PCI Devices Drivers & Firmware
                                        }
                                        #endregion ESXi Host Hardware Section

                                        #region ESXi Host System Section
                                        Section -Style Heading4 'System' {
                                            Paragraph "The following section details the host system configuration for $VMHost."
                                            #region ESXi Host Profile Information
                                            if ($VMHost | Get-VMHostProfile) {
                                                Section -Style Heading5 'Host Profile' {
                                                    $VMHostProfile = $VMHost | Get-VMHostProfile | Select-Object Name, Description
                                                    $VMHostProfile | Sort-Object Name | Table -Name "$VMHost Host Profile" -ColumnWidths 50, 50 
                                                }
                                            }
                                            #endregion ESXi Host Profile Information

                                            #region ESXi Host Image Profile Information
                                            Section -Style Heading5 'Image Profile' {
                                                $installdate = Get-InstallDate
                                                $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                                $ImageProfile = $esxcli.software.profile.get.Invoke()
                                                $SecurityProfile = [PSCustomObject]@{
                                                    'Image Profile' = $ImageProfile.Name
                                                    'Vendor' = $ImageProfile.Vendor
                                                    'Installation Date' = $InstallDate.InstallDate
                                                }
                                                $SecurityProfile | Table -Name "$VMHost Image Profile" -ColumnWidths 50, 25, 25 
                                            }
                                            #endregion ESXi Host Image Profile Information

                                            #region ESXi Host Time Configuration
                                            Section -Style Heading5 'Time Configuration' {
                                                $VMHostTimeSettings = [PSCustomObject]@{
                                                    'Time Zone' = $VMHost.timezone
                                                    'NTP Service' = Switch ((Get-VMHostService -VMHost $VMHost | Where-Object { $_.key -eq 'ntpd' }).Running) {
                                                        $true { 'Running' }
                                                        $false { 'Stopped' }
                                                    }
                                                    'NTP Server(s)' = (Get-VMHostNtpServer -VMHost $VMHost | Sort-Object) -join ', '
                                                }
                                                if ($Healthcheck.VMHost.NTP) {
                                                    $VMHostTimeSettings | Where-Object { $_.'NTP Service' -eq 'Stopped' } | Set-Style -Style Critical -Property 'NTP Service'
                                                }
                                                $VMHostTimeSettings | Table -Name "$VMHost Time Configuration" -ColumnWidths 30, 30, 40
                                            }
                                            #endregion ESXi Host Time Configuration

                                            #region ESXi Host Syslog Configuration
                                            $SyslogConfig = $VMHost | Get-VMHostSysLogServer
                                            if ($SyslogConfig) {
                                                Section -Style Heading5 'Syslog Configuration' {
                                                    # TODO: Syslog Rotate & Size, Log Directory (Adv Settings)
                                                    $SyslogConfig = $SyslogConfig | Select-Object @{L = 'SysLog Server'; E = { $_.Host } }, Port
                                                    $SyslogConfig | Table -Name "$VMHost Syslog Configuration" -ColumnWidths 50, 50 
                                                }
                                            }
                                            #endregion ESXi Host Syslog Configuration

                                            #region ESXi Update Manager Baseline Information
                                            if ($VumServer.Name) {
                                                $VMHostPatchBaselines = $VMHost | Get-PatchBaseline
                                                if ($VMHostPatchBaselines) {
                                                    Section -Style Heading5 'Update Manager Baselines' {
                                                        $VMHostBaselines = foreach ($VMHostBaseline in $VMHostPatchBaselines) {
                                                            [PSCustomObject]@{
                                                                'Baseline' = $VMHostBaseline.Name
                                                                'Description' = $VMHostBaseline.Description
                                                                'Type' = $VMHostBaseline.BaselineType
                                                                'Target Type' = $VMHostBaseline.TargetType
                                                                'Last Update Time' = $VMHostBaseline.LastUpdateTime
                                                                '# of Patches' = $VMHostBaseline.CurrentPatches.Count
                                                            }
                                                        }
                                                        $VMHostBaselines | Sort-Object 'Baseline' | Table -Name "$VMHost Update Manager Baselines"
                                                    }
                                                }
                                            }
                                            #endregion ESXi Update Manager Baseline Information

                                            #region ESXi Update Manager Compliance Information
                                            if ($VumServer.Name) {
                                                $VMHostCompliances = $VMHost | Get-Compliance
                                                if ($VMHostCompliances) {
                                                    Section -Style Heading5 'Update Manager Compliance' {
                                                        $VMHostComplianceInfo = foreach ($VMHostCompliance in $VMHostCompliances) {
                                                            [PSCustomObject]@{
                                                                'Baseline' = $VMHostCompliance.Baseline.Name
                                                                'Status' = Switch ($VMHostCompliance.Status) {
                                                                    'NotCompliant' { 'Not Compliant' }
                                                                    default { $VMHostCompliance.Status }
                                                                }
                                                            }
                                                        } 
                                                        if ($Healthcheck.VMHost.VUMCompliance) {
                                                            $VMHostComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                            $VMHostComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                        }
                                                        $VMHostComplianceInfo | Sort-Object Baseline | Table -Name "$VMHost Update Manager Compliance" -ColumnWidths 75, 25
                                                    }
                                                }
                                            }
                                            #endregion ESXi Update Manager Compliance Information

                                            #region ESXi Host Comprehensive Information Section
                                            if ($InfoLevel.VMHost -ge 5) {
                                                #region ESXi Host Advanced System Settings
                                                Section -Style Heading5 'Advanced System Settings' {
                                                    $AdvSettings = $VMHost | Get-AdvancedSetting | Select-Object Name, Value
                                                    $AdvSettings | Sort-Object Name | Table -Name "$VMHost Advanced System Settings" -ColumnWidths 50, 50 
                                                }
                                                #endregion ESXi Host Advanced System Settings

                                                #region ESXi Host Software VIBs
                                                Section -Style Heading5 'Software VIBs' {
                                                    $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                                    $VMHostVibs = $esxcli.software.vib.list.Invoke()
                                                    $VMHostVibs = foreach ($VMHostVib in $VMHostVibs) {
                                                        [PSCustomObject]@{
                                                            'VIB' = $VMHostVib.Name
                                                            'ID' = $VMHostVib.Id
                                                            'Version' = $VMHostVib.Version
                                                            'Acceptance Level' = $VMHostVib.AcceptanceLevel
                                                            'Creation Date' = $VMHostVib.CreationDate
                                                            'Install Date' = $VMHostVib.InstallDate
                                                        }
                                                    } 
                                                    $VMHostVibs | Sort-Object 'Install Date' -Descending | Table -Name "$VMHost Software VIBs" -ColumnWidths 15, 25, 15, 15, 15, 15
                                                }
                                                #endregion ESXi Host Software VIBs
                                            }
                                            #endregion ESXi Host Comprehensive Information Section
                                        }
                                        #endregion ESXi Host System Section

                                        #region ESXi Host Storage Section
                                        Section -Style Heading4 'Storage' {
                                            Paragraph "The following section details the host storage configuration for $VMHost."
        
                                            #region ESXi Host Datastore Specifications
                                            $VMHostDatastores = $VMHost | Get-Datastore | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
                                            if ($VMHostDatastores) { 
                                                Section -Style Heading5 'Datastores' {
                                                    $VMHostDsSpecs = foreach ($VMHostDatastore in $VMHostDatastores) {
                                                        [PSCustomObject]@{
                                                            'Datastore' = $VMHostDatastore.Name
                                                            'Type' = $VMHostDatastore.Type
                                                            'Version' = Switch ($VMHostDatastore.FileSystemVersion) {
                                                                $null { '--' }
                                                                default { $VMHostDatastore.FileSystemVersion }
                                                            }
                                                            '# of VMs' = $VMHostDatastore.ExtensionData.VM.Count
                                                            'Total Capacity GB' = [math]::Round($VMHostDatastore.CapacityGB, 2)
                                                            'Used Capacity GB' = [math]::Round((($VMHostDatastore.CapacityGB) - ($VMHostDatastore.FreeSpaceGB)), 2)
                                                            'Free Space GB' = [math]::Round($VMHostDatastore.FreeSpaceGB, 2)
                                                            '% Used' = [math]::Round((100 - (($VMHostDatastore.FreeSpaceGB) / ($VMHostDatastore.CapacityGB) * 100)), 2)
                                                        }
                                                    }
                                                    if ($Healthcheck.Datastore.CapacityUtilization) {
                                                        $VMHostDsSpecs | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical
                                                        $VMHostDsSpecs | Where-Object { $_.'% Used' -ge 75 -and $_.'% Used' -lt 90 } | Set-Style -Style Warning
                                                    }
                                                    $VMHostDsSpecs | Sort-Object 'Datastore' | Table -Name "$VMHost Datastores" #-ColumnWidths 20,10,10,10,10,10,10,10,10
                                                }
                                            }
                                            #endregion ESXi Host Datastore Specifications
        
                                            #region ESXi Host Storage Adapter Information
                                            $VMHostHbas = $VMHost | Get-VMHostHba | Sort-Object Device
                                            if ($VMHostHbas) {
                                                #region ESXi Host Storage Adapters Section
                                                Section -Style Heading5 'Storage Adapters' {
                                                    Paragraph "The following section details the storage adapter configuration for $VMHost."
                                                    foreach ($VMHostHba in $VMHostHbas) {
                                                        $Target = ((Get-View $VMHostHba.VMhost).Config.StorageDevice.ScsiTopology.Adapter | Where-Object {$_.Adapter -eq $VMHostHba.Key}).Target
                                                        $LUNs = Get-ScsiLun -Hba $VMHostHba -LunType "disk" -ErrorAction SilentlyContinue
                                                        $Paths = ($Target | %{$_.Lun.Count} | Measure-Object -Sum)
                                                        Section -Style Heading5 "$($VMHostHba.Device)" {
                                                            $VMHostStorageAdapter = [PSCustomObject]@{
                                                                'Adapter' = $VMHostHba.Device
                                                                'Type' = Switch ($VMHostHba.Type) {
                                                                    'FibreChannel' { 'Fibre Channel' }
                                                                    'IScsi' { 'iSCSI' }
                                                                    'ParallelScsi' { 'Parallel SCSI' }
                                                                    default { $TextInfo.ToTitleCase($VMHostHba.Type) }
                                                                }
                                                                'Model' = $VMHostHba.Model
                                                                'Status' = $TextInfo.ToTitleCase($VMHostHba.Status)
                                                                'Targets' = $Target.Count
                                                                'Devices' = $LUNs.Count
                                                                'Paths' = $Paths.Sum
                                                            }
                                                            $MemberProps = @{
                                                                'InputObject' = $VMHostStorageAdapter
                                                                'MemberType' = 'NoteProperty'
                                                            }
                                                            if ($VMHostStorageAdapter.Type -eq 'iSCSI') {
                                                                $iScsiAuthenticationMethod = Switch ($VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType) {
                                                                    'chapProhibited' { 'None' }
                                                                    'chapPreferred' { 'Use unidirectional CHAP unless prohibited by target' }
                                                                    'chapDiscouraged' { 'Use unidirectional CHAP if required by target' }
                                                                    'chapRequired' { 
                                                                        Switch ($VMHostHba.ExtensionData.AuthenticationProperties.MutualChapAuthenticationType) {
                                                                            'chapProhibited' { 'Use unidirectional CHAP' }
                                                                            'chapRequired' { 'Use bidirectional CHAP' }
                                                                        } 
                                                                    }
                                                                    default { $VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType }
                                                                }
                                                                Add-Member @MemberProps -Name 'iSCSI Name' -Value $VMHostHba.IScsiName
                                                                if ($VMHostHba.IScsiAlias) {
                                                                    Add-Member @MemberProps -Name 'iSCSI Alias' -Value $VMHostHba.IScsiAlias
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'iSCSI Alias' -Value '--'
                                                                }
                                                                if ($VMHostHba.CurrentSpeedMb) {
                                                                    Add-Member @MemberProps -Name 'Speed' -Value "$($VMHostHba.CurrentSpeedMb) Mb"
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Speed' -Value '--'
                                                                }
                                                                if ($VMHostHba.ExtensionData.ConfiguredSendTarget) {
                                                                    Add-Member @MemberProps -Name 'Dynamic Discovery' -Value (($VMHostHba.ExtensionData.ConfiguredSendTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" }) -join [Environment]::NewLine)
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Dynamic Discovery' -Value '--'
                                                                }
                                                                if ($VMHostHba.ExtensionData.ConfiguredStaticTarget) {
                                                                    Add-Member @MemberProps -Name 'Static Discovery' -Value (($VMHostHba.ExtensionData.ConfiguredStaticTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" + "  " + "$($_.IScsiName)" }) -join [Environment]::NewLine)
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Static Discovery' -Value '--'
                                                                }
                                                                if ($iScsiAuthenticationMethod -eq 'None') {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                } elseif ($iScsiAuthenticationMethod -eq 'Use bidirectional CHAP') {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                    Add-Member @MemberProps -Name 'Outgoing CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                                                    Add-Member @MemberProps -Name 'Incoming CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.MutualChapName
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                    Add-Member @MemberProps -Name 'Outgoing CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                                                }
                                                                if ($InfoLevel.VMHost -eq 4) {
                                                                    Add-Member @MemberProps -Name 'Advanced Options' -Value (($VMHostHba.ExtensionData.AdvancedOptions | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join [Environment]::NewLine)
                                                                }
                                                            }
                                                            if ($VMHostStorageAdapter.Type -eq 'Fibre Channel') {
                                                                Add-Member @MemberProps -Name 'Node WWN' -Value (([String]::Format("{0:X}", $VMHostHba.NodeWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                                                Add-Member @MemberProps -Name 'Port WWN' -Value (([String]::Format("{0:X}", $VMHostHba.PortWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                                                Add-Member @MemberProps -Name 'Speed' -Value $VMHostHba.Speed
                                                            }
                                                            $VMHostStorageAdapter | Table -List -Name "$VMHost storage adapter $($VMHostStorageAdapter.Device)" -ColumnWidths 25, 75
                                                        }
                                                    }
                                                }
                                                #endregion ESXi Host Storage Adapters Section
                                            }
                                            #endregion ESXi Host Storage Adapter Information
                                        }
                                        #endregion ESXi Host Storage Section

                                        #region ESXi Host Network Section
                                        Section -Style Heading4 'Network' {
                                            Paragraph "The following section details the host network configuration for $VMHost."
                                            BlankLine
                                            #region ESXi Host Network Configuration
                                            $VMHostNetwork = $VMHost.ExtensionData.Config.Network
                                            $VMHostVirtualSwitch = @()
                                            $VMHostVss = foreach ($vSwitch in $VMHost.ExtensionData.Config.Network.Vswitch) {
                                                $VMHostVirtualSwitch += $vSwitch.Name
                                            }
                                            $VMHostDvs = foreach ($dvSwitch in $VMHost.ExtensionData.Config.Network.ProxySwitch) {
                                                $VMHostVirtualSwitch += $dvSwitch.DvsName
                                            }
                                            $VMHostNetworkDetail = [PSCustomObject]@{
                                                'Host' = $VMHost.Name 
                                                'Virtual Switches' = ($VMHostVirtualSwitch | Sort-Object) -join ', '
                                                'VMKernel Adapters' = ($VMHostNetwork.Vnic.Device | Sort-Object) -join ', '
                                                'Physical Adapters' = ($VMHostNetwork.Pnic.Device | Sort-Object) -join ', '
                                                'VMKernel Gateway' = $VMHostNetwork.IpRouteConfig.DefaultGateway
                                                'IPv6' = Switch ($VMHostNetwork.IPv6Enabled) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                }
                                                'VMKernel IPv6 Gateway' = Switch ($VMHostNetwork.IpRouteConfig.IpV6DefaultGateway) {
                                                    $null { '--' }
                                                    default { $VMHostNetwork.IpRouteConfig.IpV6DefaultGateway }
                                                }
                                                'DNS Servers' = ($VMHostNetwork.DnsConfig.Address | Sort-Object) -join ', ' 
                                                'Host Name' = $VMHostNetwork.DnsConfig.HostName
                                                'Domain Name' = $VMHostNetwork.DnsConfig.DomainName 
                                                'Search Domain' = ($VMHostNetwork.DnsConfig.SearchDomain | Sort-Object) -join ', '
                                            }
                                            if ($Healthcheck.VMHost.IPv6) {
                                                $VMHostNetworkDetail | Where-Object { $_.'IPv6' -eq $false } | Set-Style -Style Warning -Property 'IPv6'
                                            }
                                            $VMHostNetworkDetail | Table -Name "$VMHost Network Configuration" -List -ColumnWidths 50, 50
                                            #endregion ESXi Host Network Configuration

                                            #region ESXi Host Physical Adapters
                                            Section -Style Heading5 'Physical Adapters' {
                                                Paragraph "The following section details the physical network adapter configuration for $VMHost."
                                                $PhysicalNetAdapters = $VMHost.ExtensionData.Config.Network.Pnic | Sort-Object Device
                                                $VMHostPhysicalNetAdapters = foreach ($PhysicalNetAdapter in $PhysicalNetAdapters) {
                                                    [PSCustomObject]@{
                                                        'Adapter' = $PhysicalNetAdapter.Device
                                                        'Status' = Switch ($PhysicalNetAdapter.Linkspeed) {
                                                            $null { 'Disconnected' }
                                                            default { 'Connected' }
                                                        }
                                                        'Virtual Switch' = $(
                                                            if ($VMHost.ExtensionData.Config.Network.Vswitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                                                ($VMHost.ExtensionData.Config.Network.Vswitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).Name
                                                            } elseif ($VMHost.ExtensionData.Config.Network.ProxySwitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                                                ($VMHost.ExtensionData.Config.Network.ProxySwitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).DvsName
                                                            } else {
                                                                '--'
                                                            }
                                                        )
                                                        'MAC Address' = $PhysicalNetAdapter.Mac
                                                        'Actual Speed, Duplex' = Switch ($PhysicalNetAdapter.LinkSpeed.SpeedMb) {
                                                            $null { 'Down' }
                                                            default {
                                                                if ($PhysicalNetAdapter.LinkSpeed.Duplex) {
                                                                    "$($PhysicalNetAdapter.LinkSpeed.SpeedMb) Mb, Full Duplex"
                                                                } else {
                                                                    'Auto negotiate'
                                                                }
                                                            }
                                                        }
                                                        'Configured Speed, Duplex' = Switch ($PhysicalNetAdapter.Spec.LinkSpeed) {
                                                            $null { 'Auto negotiate' }
                                                            default {
                                                                if ($PhysicalNetAdapter.Spec.LinkSpeed.Duplex) {
                                                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mb, Full Duplex"
                                                                } else {
                                                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mb"
                                                                }
                                                            }
                                                        }
                                                        'Wake on LAN' = Switch ($PhysicalNetAdapter.WakeOnLanSupported) {
                                                            $true { 'Supported' }
                                                            $false { 'Not Supported' }
                                                        }
                                                    }
                                                }
                                                if ($InfoLevel.VMHost -ge 4) {
                                                    foreach ($VMHostPhysicalNetAdapter in $VMHostPhysicalNetAdapters) {
                                                        Section -Style Heading5 "$($VMHostPhysicalNetAdapter.Adapter)" {
                                                            $VMHostPhysicalNetAdapter | Table -List -Name "$VMHost Physical Adapter $($VMHostPhysicalNetAdapter.Adapter)" -ColumnWidths 50, 50
                                                        }
                                                    }
                                                } else {
                                                    BlankLine
                                                    $VMHostPhysicalNetAdapters | Table -Name "$VMHost Physical Adapters"
                                                }
                                            }
                                            #endregion ESXi Host Physical Adapters
                            
                                            #region ESXi Host Cisco Discovery Protocol
                                            $VMHostNetworkAdapterCDP = $VMHost | Get-VMHostNetworkAdapterCDP | Where-Object { $_.Status -eq 'Connected' } | Sort-Object Device
                                            if ($VMHostNetworkAdapterCDP) {
                                                Section -Style Heading5 'Cisco Discovery Protocol' {
                                                    Paragraph "The following section details the CDP information for $VMHost."
                                                    if ($InfoLevel.VMHost -ge 4) {
                                                        foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                                            Section -Style Heading5 "$($VMHostNetworkAdapter.Device)" {
                                                                $VMHostCDP = [PSCustomObject]@{
                                                                    'Status' = $VMHostNetworkAdapter.Status
                                                                    'System Name' = $VMHostNetworkAdapter.SystemName
                                                                    'Hardware Platform' = $VMHostNetworkAdapter.HardwarePlatform
                                                                    'Switch ID' = $VMHostNetworkAdapter.SwitchId
                                                                    'Software Version' = $VMHostNetworkAdapter.SoftwareVersion
                                                                    'Management Address' = $VMHostNetworkAdapter.ManagementAddress
                                                                    'Address' = $VMHostNetworkAdapter.Address
                                                                    'Port ID' = $VMHostNetworkAdapter.PortId
                                                                    'VLAN' = $VMHostNetworkAdapter.Vlan
                                                                    'MTU' = $VMHostNetworkAdapter.Mtu
                                                                }
                                                                $VMHostCDP | Table -List -Name "$VMHost Network Adapter $($VMHostNetworkAdapter.Device) CDP Information" -ColumnWidths 50, 50
                                                            }
                                                        }
                                                    } else {
                                                        BlankLine
                                                        $VMHostCDP = foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                                            [PSCustomObject]@{
                                                                'Adapter' = $VMHostNetworkAdapter.Device
                                                                'Status' = $VMHostNetworkAdapter.Status
                                                                'Hardware Platform' = $VMHostNetworkAdapter.HardwarePlatform
                                                                'Switch ID' = $VMHostNetworkAdapter.SwitchId
                                                                'Address' = $VMHostNetworkAdapter.Address
                                                                'Port ID' = $VMHostNetworkAdapter.PortId
                                                            }
                                                        }
                                                        $VMHostCDP | Table -Name "$VMHost Network Adapter CDP Information"
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host Cisco Discovery Protocol

                                            #region ESXi Host VMkernel Adapaters
                                            Section -Style Heading5 'VMkernel Adapters' {
                                                Paragraph "The following section details the VMkernel adapter configuration for $VMHost"
                                                $VMkernelAdapters = $VMHost | Get-View | ForEach-Object -Process {
                                                    $esx = $_
                                                    $netSys = Get-View -Id $_.ConfigManager.NetworkSystem
                                                    $vnicMgr = Get-View -Id $_.ConfigManager.VirtualNicManager
                                                    $netSys.NetworkInfo.Vnic |
                                                    ForEach-Object -Process {
                                                        $device = $_.Device
                                                        [PSCustomObject]@{
                                                            'Adapter' = $_.Device
                                                            'Port Group' = & {
                                                                if ($_.Spec.Portgroup) {
                                                                    $script:pg = $_.Spec.Portgroup
                                                                } else {
                                                                    $script:pg = Get-View -ViewType DistributedVirtualPortgroup -Property Name, Key -Filter @{'Key' = "$($_.Spec.DistributedVirtualPort.PortgroupKey)" } |
                                                                    Select-Object -ExpandProperty Name
                                                                }
                                                                $script:pg
                                                            }
                                                            'Virtual Switch' = & { 
                                                                if ($_.Spec.Portgroup) {
                                                                    (Get-VirtualPortGroup -Standard -Name $script:pg -VMHost $VMHost).VirtualSwitchName
                                                                } else {
                                                                    (Get-VDPortgroup -Name $script:pg).VDSwitch.Name
                                                                }
                                                            }
                                                            'TCP/IP Stack' = Switch ($_.Spec.NetstackInstanceKey) {
                                                                'defaultTcpipStack' { 'Default' }
                                                                'vSphereProvisioning' { 'Provisioning' }
                                                                'vmotion' { 'vMotion' }
                                                                $null { 'Not Applicable' }
                                                                default { $_.Spec.NetstackInstanceKey }
                                                            }
                                                            'MTU' = $_.Spec.Mtu
                                                            'MAC Address' = $_.Spec.Mac
                                                            'DHCP' = Switch ($_.Spec.Ip.Dhcp) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'IP Address' = $_.Spec.IP.IPAddress
                                                            'Subnet Mask' = $_.Spec.IP.SubnetMask
                                                            'Default Gateway' = Switch ($_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway) {
                                                                $null { '--' }
                                                                default { $_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway }
                                                            }
                                                            'vMotion' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vmotion' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'Provisioning' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vSphereProvisioning' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'FT Logging' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'faultToleranceLogging' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'Management' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'management' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSphere Replication' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vSphereReplication' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSphere Replication NFC' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vSphereReplicationNFC' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSAN' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vsan' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSAN Witness' = Switch ((($vnicMgr.Info.NetConfig | where { $_.NicType -eq 'vsanWitness' }).SelectedVnic | % { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                        }
                                                    }
                                                }
                                                foreach ($VMkernelAdapter in ($VMkernelAdapters | Sort-Object 'Adapter')) {
                                                    Section -Style Heading5 "$($VMkernelAdapter.Adapter)" {
                                                        $VMkernelAdapter | Table -List -Name "$VMHost VMkernel Adapter $($VMkernelAdapter.Adapter)" -ColumnWidths 50, 50
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host VMkernel Adapaters

                                            #region ESXi Host Standard Virtual Switches
                                            $VSSwitches = $VMHost | Get-VirtualSwitch -Standard | Sort-Object Name
                                            if ($VSSwitches) {
                                                #region Section Standard Virtual Switches
                                                Section -Style Heading5 'Standard Virtual Switches' {
                                                    Paragraph "The following section details the standard virtual switch configuration for $VMHost."
                                                    Blankline
                                                    $VSSwitchNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                                                    #region ESXi Host Standard Virtual Switch Properties
                                                    $VSSProperties = foreach ($VSSwitchNicTeam in $VSSwitchNicTeaming) {
                                                        [PSCustomObject]@{
                                                            'Virtual Switch' = $VSSwitchNicTeam.VirtualSwitch 
                                                            'MTU' = $VSSwitchNicTeam.VirtualSwitch.Mtu 
                                                            'Number of Ports' = $VSSwitchNicTeam.VirtualSwitch.NumPorts
                                                            'Number of Ports Available' = $VSSwitchNicTeam.VirtualSwitch.NumPortsAvailable
                                                        }
                                                    }
                                                    $VSSProperties | Table -Name "$VMHost Standard Virtual Switch $($VSSGeneral.Name)" #-List -ColumnWidths 50, 50
                                                    #endregion ESXi Host Standard Virtual Switch Properties

                                                    #region ESXi Host Virtual Switch Security Policy
                                                    $VssSecurity = $VSSwitches | Get-SecurityPolicy
                                                    if ($VssSecurity) {
                                                        #region Virtual Switch Security Policy
                                                        Section -Style Heading5 'Virtual Switch Security' {
                                                            $VssSecurity = foreach ($VssSec in $VssSecurity) {
                                                                [PSCustomObject]@{
                                                                    'Virtual Switch' = $VssSec.VirtualSwitch 
                                                                    'Promiscuous Mode' = Switch ($VssSec.AllowPromiscuous) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    }
                                                                    'MAC Address Changes' = Switch ($VssSec.MacChanges) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    } 
                                                                    'Forged Transmits' = Switch ($VssSec.ForgedTransmits) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    } 
                                                                }
                                                            }
                                                            $VssSecurity | Sort-Object 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Security Policy" #-ColumnWidths 25, 25, 25, 25
                                                        }
                                                        #endregion Virtual Switch Security Policy
                                                    }
                                                    #endregion ESXi Host Virtual Switch Security Policy 
                                                    
                                                    #region ESXi Host Virtual Switch Traffic Shaping Policy
                                                    Section -Style Heading5 'Virtual Switch Traffic Shaping' {
                                                        $VssTrafficShapingPolicy = foreach ($VSSwitch in $VSSwitches) {
                                                            [PSCustomObject]@{
                                                                'Virtual Switch' = $VSSwitch.Name
                                                                'Status' = Switch ($VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                                                    $True { 'Enabled' }
                                                                    $False { 'Disabled' }
                                                                }
                                                                'Average Bandwidth (kbit/s)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                                                'Peak Bandwidth (kbit/s)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                                                'Burst Size (KB)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                                            }
                                                        }
                                                        $VssTrafficShapingPolicy | Sort-Object 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Traffic Shaping Policy"
                                                    }
                                                    #endregion ESXi Host Virtual Switch Traffic Shaping Policy

                                                    #region ESXi Host Virtual Switch Teaming & Failover
                                                    $VssNicTeamingPolicy = $VSSwitches | Get-NicTeamingPolicy
                                                    if ($VssNicTeamingPolicy) {
                                                        #region Virtual Switch Teaming & Failover Section
                                                        Section -Style Heading5 'Virtual Switch Teaming & Failover' {
                                                            $VssNicTeaming = foreach ($VssNicTeam in $VssNicTeamingPolicy) {
                                                                [PSCustomObject]@{
                                                                    'Virtual Switch' = $VssNicTeam.VirtualSwitch 
                                                                    'Load Balancing' = Switch ($VssNicTeam.LoadBalancingPolicy) {
                                                                        'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                        'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                        'LoadbalanceIP' { 'Route based on IP hash' }
                                                                        'ExplicitFailover' { 'Explicit Failover' }
                                                                        default { $VssNicTeam.LoadBalancingPolicy }
                                                                    }
                                                                    'Network Failure Detection' = Switch ($VssNicTeam.NetworkFailoverDetectionPolicy) {
                                                                        'LinkStatus' { 'Link status only' }
                                                                        'BeaconProbing' { 'Beacon probing' }
                                                                        default { $VssNicTeam.NetworkFailoverDetectionPolicy }
                                                                    } 
                                                                    'Notify Switches' = Switch ($VssNicTeam.NotifySwitches) {
                                                                        $true { 'Yes' }
                                                                        $false { 'No' }
                                                                    }
                                                                    'Failback' = Switch ($VssNicTeam.FailbackEnabled) {
                                                                        $true { 'Yes' }
                                                                        $false { 'No' }
                                                                    }
                                                                    'Active NICs' = ($VssNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                                                    'Standby NICs' = ($VssNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                                                    'Unused NICs' = ($VssNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                                                }
                                                            }
                                                            $VssNicTeaming | Sort-Object 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Teaming & Failover"
                                                        }
                                                        #endregion Virtual Switch Teaming & Failover Section
                                                    }
                                                    #endregion ESXi Host Virtual Switch Teaming & Failover

                                                    #region ESXi Host Virtual Switch Port Groups
                                                    $VssPortgroups = $VSSwitches | Get-VirtualPortGroup -Standard 
                                                    if ($VssPortgroups) {
                                                        Section -Style Heading5 'Virtual Switch Port Groups' {
                                                            $VssPortgroups = foreach ($VssPortgroup in $VssPortgroups) {
                                                                [PSCustomObject]@{
                                                                    'Port Group' = $VssPortgroup.Name
                                                                    'VLAN ID' = $VssPortgroup.VLanId 
                                                                    'Virtual Switch' = $VssPortgroup.VirtualSwitchName
                                                                    '# of VMs' = ($VssPortgroup | Get-VM).Count
                                                                }
                                                            }
                                                            $VssPortgroups | Sort-Object 'Port Group', 'VLAN ID', 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Port Group Information"
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Groups               

                                                        #region ESXi Host Virtual Switch Port Group Security Policy
                                                        $VssPortgroupSecurity = $VSSwitches | Get-VirtualPortGroup | Get-SecurityPolicy 
                                                        if ($VssPortgroupSecurity) {
                                                            #region Virtual Port Group Security Policy Section
                                                            Section -Style Heading5 'Virtual Switch Port Group Security' {
                                                                $VssPortgroupSecurity = foreach ($VssPortgroupSec in $VssPortgroupSecurity) {
                                                                    [PSCustomObject]@{
                                                                        'Port Group' = $VssPortgroupSec.VirtualPortGroup
                                                                        'Virtual Switch' = $VssPortgroupSec.virtualportgroup.virtualswitchname
                                                                        'Promiscuous Mode' = Switch ($VssPortgroupSec.AllowPromiscuous) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        }
                                                                        'MAC Changes' = Switch ($VssPortgroupSec.MacChanges) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        }
                                                                        'Forged Transmits' = Switch ($VssPortgroupSec.ForgedTransmits) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        } 
                                                                    }
                                                                }
                                                                $VssPortgroupSecurity | Sort-Object 'Port Group', 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Port Group Security Policy" 
                                                            }
                                                            #endregion Virtual Port Group Security Policy Section
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Security Policy 
                                                        
                                                        #region ESXi Host Virtual Switch Port Group Traffic Shaping Policy
                                                        Section -Style Heading5 'Virtual Switch Port Group Traffic Shaping' {    
                                                            $VssPortgroupTrafficShapingPolicy = foreach ($VssPortgroup in $VssPortgroups) {
                                                                [PSCustomObject]@{
                                                                    'Port Group' = $VssPortgroup.Name 
                                                                    'Virtual Switch' = $VssPortgroup.VirtualSwitchName
                                                                    'Status' = Switch ($VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                                                        $True { 'Enabled' }
                                                                        $False { 'Disabled' }
                                                                        $null { 'Inherited' }
                                                                    }
                                                                    'Average Bandwidth (kbit/s)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                                                    'Peak Bandwidth (kbit/s)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                                                    'Burst Size (KB)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                                                }
                                                            }
                                                            $VssPortgroupTrafficShapingPolicy | Sort-Object 'Port Group', 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Port Group Traffic Shaping Policy"
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Traffic Shaping Policy

                                                        #region ESXi Host Virtual Switch Port Group Teaming & Failover
                                                        $VssPortgroupNicTeaming = $VSSwitches | Get-VirtualPortGroup | Get-NicTeamingPolicy 
                                                        if ($VssPortgroupNicTeaming) {
                                                            #region Virtual Switch Port Group Teaming & Failover Section
                                                            Section -Style Heading5 'Virtual Switch Port Group Teaming & Failover' {
                                                                $VssPortgroupNicTeaming = foreach ($VssPortgroupNicTeam in $VssPortgroupNicTeaming) {
                                                                    [PSCustomObject]@{
                                                                        'Port Group' = $VssPortgroupNicTeam.VirtualPortGroup
                                                                        'Virtual Switch' = $VssPortgroupNicTeam.virtualportgroup.virtualswitchname 
                                                                        'Load Balancing' = Switch ($VssPortgroupNicTeam.LoadBalancingPolicy) {
                                                                            'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                            'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                            'LoadbalanceIP' { 'Route based on IP hash' }
                                                                            'ExplicitFailover' { 'Explicit Failover' }
                                                                            default { $VssPortgroupNicTeam.LoadBalancingPolicy }
                                                                        }
                                                                        'Network Failure Detection' = Switch ($VssPortgroupNicTeam.NetworkFailoverDetectionPolicy) {
                                                                            'LinkStatus' { 'Link status only' }
                                                                            'BeaconProbing' { 'Beacon probing' }
                                                                            default { $VssPortgroupNicTeam.NetworkFailoverDetectionPolicy }
                                                                        }  
                                                                        'Notify Switches' = Switch ($VssPortgroupNicTeam.NotifySwitches) {
                                                                            $true { 'Yes' }
                                                                            $false { 'No' }
                                                                        }
                                                                        'Failback' = Switch ($VssPortgroupNicTeam.FailbackEnabled) {
                                                                            $true { 'Yes' }
                                                                            $false { 'No' }
                                                                        } 
                                                                        'Active NICs' = ($VssPortgroupNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                                                        'Standby NICs' = ($VssPortgroupNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                                                        'Unused NICs' = ($VssPortgroupNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                                                    }
                                                                }
                                                                $VssPortgroupNicTeaming | Sort-Object 'Port Group', 'Virtual Switch' | Table -Name "$VMHost Virtual Switch Port Group Teaming & Failover"
                                                            }
                                                            #endregion Virtual Switch Port Group Teaming & Failover Section
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Teaming & Failover
                                                    }
                                                }
                                                #endregion Section Standard Virtual Switches 
                                            }
                                            #endregion ESXi Host Standard Virtual Switches
                                        }                
                                        #endregion ESXi Host Network Section

                                        #region ESXi Host Security Section
                                        Section -Style Heading4 'Security' {
                                            Paragraph "The following section details the host security configuration for $VMHost."
                                            #region ESXi Host Lockdown Mode
                                            if ($VMHost.ExtensionData.Config.LockdownMode -ne $null) {
                                                Section -Style Heading5 'Lockdown Mode' {
                                                    $LockdownMode = [PSCustomObject]@{
                                                        'Lockdown Mode' = Switch ($VMHost.ExtensionData.Config.LockdownMode) {
                                                            'lockdownDisabled' { 'Disabled' }
                                                            'lockdownNormal' { 'Enabled (Normal)' }
                                                            'lockdownStrict' { 'Enabled (Strict)' }
                                                            default { $VMHost.ExtensionData.Config.LockdownMode }
                                                        }
                                                    }
                                                    if ($Healthcheck.VMHost.LockdownMode) {
                                                        $LockdownMode | Where-Object { $_.'Lockdown Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Lockdown Mode'
                                                    }
                                                    $LockdownMode | Table -Name "$VMHost Lockdown Mode" -List -ColumnWidths 50, 50
                                                }
                                            }
                                            #endregion ESXi Host Lockdown Mode

                                            #region ESXi Host Services
                                            Section -Style Heading5 'Services' {
                                                $VMHostServices = $VMHost | Get-VMHostService
                                                $Services = foreach ($VMHostService in $VMHostServices) {
                                                    [PSCustomObject]@{
                                                        'Service' = $VMHostService.Label
                                                        'Daemon' = Switch ($VMHostService.Running) {
                                                            $true { 'Running' }
                                                            $false { 'Stopped' }
                                                        }
                                                        'Startup Policy' = Switch ($VMHostService.Policy) {
                                                            'automatic' { 'Start and stop with port usage' }
                                                            'on' { 'Start and stop with host' }
                                                            'off' { 'Start and stop manually' }
                                                            default { $VMHostService.Policy }
                                                        }
                                                    }
                                                }
                                                if ($Healthcheck.VMHost.NTP) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'NTP Daemon') -and ($_.Daemon -eq 'Stopped') } | Set-Style -Style Critical -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'NTP Daemon') -and ($_.'Startup Policy' -ne 'Start and stop with host') } | Set-Style -Style Critical -Property 'Startup Policy'
                                                }
                                                if ($Healthcheck.VMHost.SSH) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'SSH') -and ($_.Daemon -eq 'Running') } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'SSH') -and ($_.'Startup Policy' -ne 'Start and stop manually') } | Set-Style -Style Warning -Property 'Startup Policy'
                                                }
                                                if ($Healthcheck.VMHost.ESXiShell) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'ESXi Shell') -and ($_.Daemon -eq 'Running') } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'ESXi Shell') -and ($_.'Startup Policy' -ne 'Start and stop manually') } | Set-Style -Style Warning -Property 'Startup Policy'
                                                }
                                                $Services | Sort-Object 'Service' | Table -Name "$VMHost Services" 
                                            }
                                            #endregion ESXi Host Services

                                            #region ESXi Host Advanced Detail Information
                                            if ($InfoLevel.VMHost -ge 4) {
                                                #region ESXi Host Firewall
                                                $VMHostFirewallExceptions = $VMHost | Get-VMHostFirewallException
                                                if ($VMHostFirewallExceptions) {
                                                    #region Friewall Section
                                                    Section -Style Heading5 'Firewall' {
                                                        $VMHostFirewall = foreach ($VMHostFirewallException in $VMHostFirewallExceptions) {
                                                            [PScustomObject]@{
                                                                'Service' = $VMHostFirewallException.Name
                                                                'Status' = Switch ($VMHostFirewallException.Enabled) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Incoming Ports' = $VMHostFirewallException.IncomingPorts
                                                                'Outgoing Ports' = $VMHostFirewallException.OutgoingPorts
                                                                'Protocols' = $VMHostFirewallException.Protocols
                                                                'Daemon' = Switch ($VMHostFirewallException.ServiceRunning) {
                                                                    $true { 'Running' }
                                                                    $false { 'Stopped' }
                                                                    $null { 'N/A' }
                                                                    default { $VMHostFirewallException.ServiceRunning }
                                                                }
                                                            }
                                                        }
                                                        $VMHostFirewall | Sort-Object 'Service' | Table -Name "$VMHost Firewall Configuration" 
                                                    }
                                                    #endregion Friewall Section
                                                }
                                                #endregion ESXi Host Firewall
            
                                                #region ESXi Host Authentication
                                                $AuthServices = $VMHost | Get-VMHostAuthentication
                                                if ($AuthServices.DomainMembershipStatus) {
                                                    Section -Style Heading5 'Authentication Services' {
                                                        $AuthServices = $AuthServices | Select-Object Domain, @{L = 'Domain Membership'; E = { $_.DomainMembershipStatus } }, @{L = 'Trusted Domains'; E = { $_.TrustedDomains } }
                                                        $AuthServices | Table -Name "$VMHost Authentication Services" -ColumnWidths 25, 25, 50 
                                                    }    
                                                }
                                                #endregion ESXi Host Authentication
                                            }
                                            #endregion ESXi Host Advanced Detail Information
                                        }
                                        #endregion ESXi Host Security Section
                                            
                                        #region ESXi Host Virtual Machines Advanced Detail Information
                                        if ($InfoLevel.VMHost -ge 4) {
                                            $VMHostVMs = $VMHost | Get-VM
                                            if ($VMHostVMs) {
                                                #region Virtual Machines Section
                                                Section -Style Heading4 'Virtual Machines' {
                                                    Paragraph "The following section details the virtual machine configuration for $VMHost."
                                                    BlankLine
                                                    #region ESXi Host Virtual Machine Information
                                                    $VMHostVMs = foreach ($VMHostVM in $VMHostVMs) {
                                                        [PSCustomObject]@{
                                                            'Virtual Machine' = $VMHostVM.Name
                                                            'Power State' = Switch ($VMHostVM.PowerState) {
                                                                'PoweredOn' { 'On' }
                                                                'PoweredOff' { 'Off' }
                                                                default { $VMHostVM.PowerState }
                                                            }
                                                            'CPUs' = $VMHostVM.NumCpu
                                                            'Cores per Socket' = $VMHostVM.CoresPerSocket
                                                            'Memory GB' = [math]::Round(($VMHostVM.memoryGB), 2)
                                                            'Provisioned GB' = [math]::Round(($VMHostVM.ProvisionedSpaceGB), 2) 
                                                            'Used GB' = [math]::Round(($VMHostVM.UsedSpaceGB), 2)
                                                            'HW Version' = $VMHostVM.HardwareVersion
                                                            'VM Tools Status' = Switch ($VMHostVM.ExtensionData.Guest.ToolsStatus) {
                                                                'toolsOld' { 'Old' }
                                                                'toolsOK' { 'OK' }
                                                                'toolsNotRunning' { 'Not Running' }
                                                                'toolsNotInstalled' { 'Not Installed' }
                                                                default { $VMHostVM.ExtensionData.Guest.ToolsStatus }
                                                            }
                                                        }
                                                    }
                                                    if ($Healthcheck.VM.VMToolsStatus) {
                                                        $VMHostVMs | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                                    }
                                                    if ($Healthcheck.VM.PowerState) {
                                                        $VMHostVMs | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                                    }
                                                    $VMHostVMs | Sort-Object 'Virtual Machine' | Table -Name "$VMHost Virtual Machines"
                                                    #endregion ESXi Host Virtual Machine Information

                                                    #region ESXi Host VM Startup/Shutdown Information
                                                    $VMStartPolicy = $VMHost | Get-VMStartPolicy | Where-Object { $_.StartAction -ne 'None' }
                                                    if ($VMStartPolicy) {
                                                        #region VM Startup/Shutdown Section
                                                        Section -Style Heading5 'VM Startup/Shutdown' {
                                                            $VMStartPolicies = foreach ($VMStartPol in $VMStartPolicy) {
                                                                [PSCustomObject]@{
                                                                    'Start Order' = $VMStartPol.StartOrder
                                                                    'VM Name' = $VMStartPol.VirtualMachineName
                                                                    'Startup' = Switch ($VMStartPol.StartAction) {
                                                                        'PowerOn' { 'Enabled' }
                                                                        'None' { 'Disabled' }
                                                                        default { $VMStartPol.StartAction }
                                                                    }
                                                                    'Startup Delay' = "$($VMStartPol.StartDelay) seconds"
                                                                    'VMware Tools' = Switch ($VMStartPol.WaitForHeartbeat) {
                                                                        $true { 'Continue if VMware Tools is started' }
                                                                        $false { 'Wait for startup delay' }
                                                                    }
                                                                    'Shutdown Behavior' = Switch ($VMStartPol.StopAction) {
                                                                        'PowerOff' { 'Power Off' }
                                                                        'GuestShutdown' { 'Guest Shutdown' }
                                                                        default { $VMStartPol.StopAction }
                                                                    }
                                                                    'Shutdown Delay' = "$($VMStartPol.StopDelay) seconds"
                                                                }
                                                            }
                                                            $VMStartPolicies | Table -Name "$VMHost VM Startup/Shutdown Policy" 
                                                        }
                                                        #endregion VM Startup/Shutdown Section
                                                    }
                                                    #endregion ESXi Host VM Startup/Shutdown Information
                                                }
                                                #endregion Virtual Machines Section
                                            }
                                        }
                                        #endregion ESXi Host Virtual Machines Advanced Detail Information
                                    }
                                    #endregion VMHost Section
                                }
                                #endregion foreach VMHost Detailed Information loop
                            }
                            #endregion ESXi Host Detailed Information
                        }
                        #endregion Hosts Section
                    }
                }
                #endregion ESXi VMHost Section 

                #region Distributed Switch Section
                if ($InfoLevel.Network -ge 1) {
                    # Create Distributed Switch Section if they exist
                    $VDSwitches = Get-VDSwitch -Server $vCenter
                    if ($VDSwitches) {
                        Section -Style Heading2 'Distributed Switches' {
                            Paragraph "The following sections detail the configuration of distributed switches managed by vCenter Server $vCenterServerName."
                            #region Distributed Switch Informative Information
                            if ($InfoLevel.Network -eq 2) {
                                BlankLine
                                $VDSInfo = foreach ($VDS in $VDSwitches) {
                                    [PSCustomObject]@{
                                        'VDSwitch' = $VDS.Name
                                        'Datacenter' = $VDS.Datacenter
                                        'Manufacturer' = $VDS.Vendor
                                        'Version' = $VDS.Version
                                        '# of Uplinks' = $VDS.NumUplinkPorts
                                        '# of Ports' = $VDS.NumPorts 
                                        '# of Hosts' = $VDS.ExtensionData.Summary.HostMember.Count
                                        '# of VMs' = $VDS.ExtensionData.Summary.VM.Count
                                    }
                                }    
                                $VDSInfo | Table -Name 'Distributed Switch Information'
                            }    
                            #endregion Distributed Switch Informative Information

                            #region Distributed Switch Detailed Information
                            if ($InfoLevel.Network -ge 3) {
                                # TODO: LACP, NetFlow, NIOC
                                foreach ($VDS in ($VDSwitches)) {
                                    #region VDS Section
                                    Section -Style Heading3 $VDS {
                                        #region Distributed Switch General Properties  
                                        $VDSwitchDetail = [PSCustomObject]@{
                                            'Distributed Switch' = $VDS.Name
                                            'ID' = $VDS.Id
                                            'Datacenter' = $VDS.Datacenter
                                            'Manufacturer' = $VDS.Vendor
                                            'Version' = $VDS.Version
                                            'Number of Uplinks' = $VDS.NumUplinkPorts 
                                            'Number of Ports' = $VDS.NumPorts
                                            'Number of Port Groups' = $VDS.ExtensionData.Summary.PortGroupName.Count 
                                            'Number of Hosts' = $VDS.ExtensionData.Summary.HostMember.Count
                                            'Number of VMs' = $VDS.ExtensionData.Summary.VM.Count 
                                            'MTU' = $VDS.Mtu
                                            'Network I/O Control' = Switch ($VDS.ExtensionData.Config.NetworkResourceManagementEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            } 
                                            'Discovery Protocol' = $VDS.LinkDiscoveryProtocol
                                            'Discovery Protocol Operation' = $VDS.LinkDiscoveryProtocolOperation
                                        }

                                        #region Network Advanced Detail Information
                                        if ($InfoLevel.Network -ge 4) {
                                            $VDSwitchDetail | ForEach-Object {
                                                $VDSwitchHosts = $VDS | Get-VMHost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($VDSwitchHosts.Name -join ', ')
                                                $VDSwitchVMs = $VDS | Get-VM | Sort-Object 
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($VDSwitchVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Network Advanced Detail Information
                                        $VDSwitchDetail | Table -Name "$VDS Distributed Switch General Properties" -List -ColumnWidths 50, 50 
                                        #endregion Distributed Switch General Properties

                                        #region Distributed Switch Uplinks
                                        $VdsUplinks = $VDS | Get-VDPortgroup | Where-Object { $_.IsUplink -eq $true } | Get-VDPort
                                        if ($VdsUplinks) {
                                            Section -Style Heading4 'Distributed Switch Uplink Ports' {
                                                $VdsUplinkDetail = foreach ($VdsUplink in $VdsUplinks) {
                                                    [PSCustomObject]@{
                                                        'Distributed Switch' = $VdsUplink.Switch
                                                        'Host' = $VdsUplink.ProxyHost
                                                        'Uplink Name' = $VdsUplink.Name
                                                        'Physical Network Adapter' = $VdsUplink.ConnectedEntity
                                                        'Uplink Port Group' = $VdsUplink.Portgroup
                                                    }
                                                }
                                                $VdsUplinkDetail | Sort-Object 'Distributed Switch', 'Host', 'Uplink Name' | Table -Name "$VDS Distributed Switch Uplink Ports"
                                            }
                                        }
                                        #endregion Distributed Switch Uplinks               
                    
                                        #region Distributed Switch Security
                                        $VDSecurityPolicy = $VDS | Get-VDSecurityPolicy
                                        if ($VDSecurityPolicy) {
                                            Section -Style Heading4 'Distributed Switch Security' {
                                                $VDSecurityPolicyDetail = [PSCustomObject]@{
                                                    'Distributed Switch' = $VDSecurityPolicy.VDSwitch
                                                    'Allow Promiscuous' = Switch ($VDSecurityPolicy.AllowPromiscuous) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                    'Forged Transmits' = Switch ($VDSecurityPolicy.ForgedTransmits) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                    'MAC Address Changes' = Switch ($VDSecurityPolicy.MacChanges) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                }
                                                $VDSecurityPolicyDetail | Table -Name "$VDS Distributed Switch Security" 
                                            }
                                        }
                                        #endregion Distributed Switch Security

                                        #region Distributed Switch Traffic Shaping
                                        $VDSTrafficShaping = @()
                                        $VDSTrafficShapingIn = $VDS | Get-VDTrafficShapingPolicy -Direction In
                                        $VDSTrafficShapingOut = $VDS | Get-VDTrafficShapingPolicy -Direction Out
                                        $VDSTrafficShaping += $VDSTrafficShapingIn
                                        $VDSTrafficShaping += $VDSTrafficShapingOut
                                        if ($VDSTrafficShapingIn -or $VDSTrafficShapingOut) {
                                            Section -Style Heading4 'Distributed Switch Traffic Shaping' {
                                                $VDSTrafficShapingDetail = foreach ($VDSTrafficShape in $VDSTrafficShaping) {
                                                    [PSCustomObject]@{
                                                        'Distributed Switch' = $VDSTrafficShape.VDSwitch
                                                        'Direction' = $VDSTrafficShape.Direction
                                                        'Status' = Switch ($VDSTrafficShape.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Average Bandwidth (kbit/s)' = $VDSTrafficShape.AverageBandwidth
                                                        'Peak Bandwidth (kbit/s)' = $VDSTrafficShape.PeakBandwidth
                                                        'Burst Size (KB)' = $VDSTrafficShape.BurstSize
                                                    }
                                                }
                                                $VDSTrafficShapingDetail | Sort-Object 'Direction' | Table -Name "$VDS Distributed Switch Traffic Shaping"
                                            }
                                        }
                                        #endregion Distributed Switch Traffic Shaping

                                        #region Distributed Switch Port Groups
                                        $VDSPortgroups = $VDS | Get-VDPortgroup
                                        if ($VDSPortgroups) {
                                            Section -Style Heading4 'Distributed Switch Port Groups' {
                                                $VDSPortgroupDetail = foreach ($VDSPortgroup in $VDSPortgroups) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSPortgroup.Name
                                                        'Distributed Switch' = $VDSPortgroup.VDSwitch
                                                        'Datacenter' = $VDSPortgroup.Datacenter
                                                        'VLAN Configuration' = Switch ($VDSPortgroup.VlanConfiguration) {
                                                            $null { '--' }
                                                            default { $VDSPortgroup.VlanConfiguration }
                                                        }
                                                        'Port Binding' = $VDSPortgroup.PortBinding
                                                        '# of Ports' = $VDSPortgroup.NumPorts
                                                    }
                                                }
                                                $VDSPortgroupDetail | Sort-Object 'Port Group' | Table -Name "$VDS Distributed Port Groups" 
                                            }
                                        }
                                        #endregion Distributed Switch Port Groups

                                        #region Distributed Switch Port Group Security
                                        $VDSPortgroupSecurity = $VDS | Get-VDPortgroup | Get-VDSecurityPolicy
                                        if ($VDSPortgroupSecurity) {
                                            Section -Style Heading5 "Distributed Switch Port Group Security" {
                                                $VDSSecurityPolicies = foreach ($VDSSecurityPolicy in $VDSPortgroupSecurity) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSSecurityPolicy.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Allow Promiscuous' = Switch ($VDSSecurityPolicy.AllowPromiscuous) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                        'Forged Transmits' = Switch ($VDSSecurityPolicy.ForgedTransmits) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                        'MAC Address Changes' = Switch ($VDSSecurityPolicy.MacChanges) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                    }
                                                }
                                                $VDSSecurityPolicies | Sort-Object 'Port Group' | Table -Name "$VDS Distributed Switch Port Group Security"
                                            }
                                        }
                                        #endregion Distributed Switch Port Group Security
    
                                        #region Distributed Switch Port Group Traffic Shaping
                                        $VDSPortgroupTrafficShaping = @()
                                        $VDSPortgroupTrafficShapingIn = $VDS | Get-VDPortgroup | Get-VDTrafficShapingPolicy -Direction In
                                        $VDSPortgroupTrafficShapingOut = $VDS | Get-VDPortgroup | Get-VDTrafficShapingPolicy -Direction Out
                                        $VDSPortgroupTrafficShaping += $VDSPortgroupTrafficShapingIn
                                        $VDSPortgroupTrafficShaping += $VDSPortgroupTrafficShapingOut
                                        if ($VDSPortgroupTrafficShaping) {
                                            Section -Style Heading5 "Distributed Switch Port Group Traffic Shaping" {
                                                $VDSPortgroupTrafficShapingDetail = foreach ($VDSPortgroupTrafficShape in $VDSPortgroupTrafficShaping) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSPortgroupTrafficShape.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Direction' = $VDSPortgroupTrafficShape.Direction
                                                        'Status' = Switch ($VDSPortgroupTrafficShape.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Average Bandwidth (kbit/s)' = $VDSPortgroupTrafficShape.AverageBandwidth
                                                        'Peak Bandwidth (kbit/s)' = $VDSPortgroupTrafficShape.PeakBandwidth
                                                        'Burst Size (KB)' = $VDSPortgroupTrafficShape.BurstSize
                                                    }
                                                }
                                                $VDSPortgroupTrafficShapingDetail | Sort-Object 'Port Group', 'Direction', 'Port Group' | Table -Name "$VDS Distributed Switch Port Group Traffic Shaping"

                                            }
                                        }
                                        #endregion Distributed Switch Port Group Traffic Shaping

                                        #region Distributed Switch Port Group Teaming & Failover
                                        $VDUplinkTeamingPolicy = $VDS | Get-VDPortgroup | Get-VDUplinkTeamingPolicy
                                        if ($VDUplinkTeamingPolicy) {
                                            Section -Style Heading5 "Distributed Switch Port Group Teaming & Failover" {
                                                $VDSPortgroupNICTeaming = foreach ($VDUplink in $VDUplinkTeamingPolicy) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDUplink.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Load Balancing' = Switch ($VDUplink.LoadBalancingPolicy) {
                                                            'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                            'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                            'LoadbalanceIP' { 'Route based on IP hash' }
                                                            'ExplicitFailover' { 'Explicit Failover' }
                                                            default { $VDUplink.LoadBalancingPolicy }
                                                        }
                                                        'Network Failure Detection' = Switch ($VDUplink.FailoverDetectionPolicy) {
                                                            'LinkStatus' { 'Link status only' }
                                                            'BeaconProbing' { 'Beacon probing' }
                                                            default { $VDUplink.FailoverDetectionPolicy }
                                                        }
                                                        'Notify Switches' = Switch ($VDUplink.NotifySwitches) {
                                                            $true { 'Yes' }
                                                            $false { 'No' }
                                                        }
                                                        'Failback Enabled' = Switch ($VDUplink.EnableFailback) {
                                                            $true { 'Yes' }
                                                            $false { 'No' }
                                                        }
                                                        'Active Uplinks' = $VDUplink.ActiveUplinkPort -join [Environment]::NewLine
                                                        'Standby Uplinks' = $VDUplink.StandbyUplinkPort -join [Environment]::NewLine
                                                        'Unused Uplinks' = $VDUplink.UnusedUplinkPort -join [Environment]::NewLine
                                                    }
                                                }
                                                $VDSPortgroupNICTeaming | Sort-Object 'Port Group' | Table -Name "$VDS Distributed Switch Port Group Teaming & Failover"
                                            }
                                        }
                                        #endregion Distributed Switch Port Group Teaming & Failover

                                        #region Distributed Switch Private VLANs
                                        $VDSwitchPrivateVLANs = $VDS | Get-VDSwitchPrivateVlan
                                        if ($VDSwitchPrivateVLANs) {
                                            Section -Style Heading4 'Distributed Switch Private VLANs' {
                                                $VDSPvlan = foreach ($VDSwitchPrivateVLAN in $VDSwitchPrivateVLANs) {
                                                    [PSCustomObject]@{
                                                        'Primary VLAN ID' = $VDSwitchPrivateVLAN.PrimaryVlanId
                                                        'Private VLAN Type' = $VDSwitchPrivateVLAN.PrivateVlanType
                                                        'Secondary VLAN ID' = $VDSwitchPrivateVLAN.SecondaryVlanId
                                                    }
                                                }
                                                $VDSPvlan | Sort-Object 'Primary VLAN ID', 'Secondary VLAN ID' | Table -Name "$VDS Distributed Switch Private VLANs"
                                            }
                                        }
                                        #endregion Distributed Switch Private VLANs            
                                    }
                                    #endregion VDS Section
                                }
                            }
                            #endregion Distributed Switch Detailed Information
                        }
                    }
                }
                #endregion Distributed Switch Section

                #region vSAN Section
                if (($InfoLevel.vSAN -ge 1) -and ($vCenter.Version -gt 6)) {
                    $VsanClusters = Get-VsanClusterConfiguration -Server $vCenter | Where-Object { $_.vsanenabled -eq $true } | Sort-Object Name
                    if ($VsanClusters) {
                        Section -Style Heading2 'vSAN' {
                            Paragraph "The following sections detail the configuration of vSAN managed by vCenter Server $vCenterServerName."
                            #region vSAN Cluster Informative Information
                            if ($InfoLevel.vSAN -eq 2) {
                                BlankLine
                                $VsanClusterInfo = foreach ($VsanCluster in $VsanClusters) {
                                    [PSCustomObject]@{
                                        'Cluster' = $VsanCluster.Name
                                        'vSAN Enabled' = $VsanCluster.VsanEnabled
                                        'Stretched Cluster' = Switch ($VsanCluster.StretchedClusterEnabled) {
                                            $true { 'Yes' }
                                            $false { 'No' }
                                        }
                                        'Deduplication & Compression' = Switch ($VsanCluster.SpaceEfficiencyEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'Encryption' = Switch ($VsanCluster.EncryptionEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                            $null { 'Disabled' }
                                        }
                                        'Health Check' = Switch ($VsanCluster.HealthCheckEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                    }
                                }   
                                $VsanClusterInfo | Table -Name 'vSAN Cluster Information'
                            }
                            #endregion vSAN Cluster Informative Information

                            #region vSAN Cluster Detailed Information
                            if ($InfoLevel.vSAN -ge 3) {
                                foreach ($VsanCluster in $VsanClusters) {
                                    #region vSAN Cluster Section
                                    Section -Style Heading3 $VsanCluster.Name {
                                        $VsanDiskGroup = Get-VsanDiskGroup -Cluster $VsanCluster.Cluster
                                        $NumVsanDiskGroup = $VsanDiskGroup.Count
                                        $VsanDisk = Get-VsanDisk -VsanDiskGroup $VsanDiskGroup
                                        $VsanDiskFormat = $VsanDisk.DiskFormatVersion | Select-Object -First 1 -Unique
                                        $NumVsanSsd = ($VsanDisk | Where-Object { $_.IsSsd -eq $true }).Count
                                        $NumVsanHdd = ($VsanDisk | Where-Object { $_.IsSsd -eq $false }).Count
                                        if ($NumVsanHdd -gt 0) {
                                            $VsanClusterType = "Hybrid"
                                        } else {
                                            $VsanClusterType = "All Flash"
                                        }
                                        $VsanClusterDetail = [PSCustomObject]@{
                                            'Cluster' = $VsanCluster.Name
                                            'ID' = $VsanCluster.Id
                                            'Type' = $VsanClusterType
                                            'Stretched Cluster' = Switch ($VsanCluster.StretchedClusterEnabled) {
                                                $true { 'Yes' }
                                                $false { 'No' }
                                            }
                                            'Number of Hosts' = $VsanCluster.Cluster.ExtensionData.Host.Count
                                            'Disk Format Version' = $VsanDiskFormat
                                            'Total Number of Disks' = $NumVsanSsd + $NumVsanHdd
                                            'Total Number of Disk Groups' = $NumVsanDiskGroup
                                            'Disk Claim Mode' = $VsanCluster.VsanDiskClaimMode
                                            'Deduplication & Compression' = Switch ($VsanCluster.SpaceEfficiencyEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Encryption' = Switch ($VsanCluster.EncryptionEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                                $null { 'Disabled' }
                                            }
                                            'Health Check' = Switch ($VsanCluster.HealthCheckEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'HCL Last Updated' = $VsanCluster.TimeOfHclUpdate
                                        }

                                        if ($InfoLevel.vSAN -ge 4) {
                                            $VsanClusterDetail | Add-Member -MemberType NoteProperty -Name 'Hosts' -Value (($VsanDiskGroup.VMHost | Sort-Object Name) -join ', ')
                                        }
                                        $VsanClusterDetail | Table -Name "$($VsanCluster.Name) vSAN Configuration" -List -ColumnWidths 50, 50

                                        Section -Style Heading4 'Disk Groups' {
                                            #foreach ($VMHost in ($VsanDiskGroup.VMHost | Sort-Object | Select-Object -Unique)) {
                                            #Section -Style Heading4 $VMHost.Name {
                                            #$VsanDiskGroups = foreach ($DiskGroup in ($VsanDiskGroup | where { $_.VMHost -eq $VMHost | Sort-Object })) {
                                            $VsanDiskGroups = foreach ($DiskGroup in $VsanDiskGroup) {
                                                $Disks = $DiskGroup | Get-VsanDisk #| Where-Object {$_.IsCacheDisk -eq $false}
                                                [PSCustomObject]@{
                                                    'Disk Group' = $DiskGroup.Uuid
                                                    'Host' = $Diskgroup.VMHost
                                                    '# of Disks' = $Disks.Count
                                                    'State' = Switch ($DiskGroup.IsMounted) {
                                                        $true { 'Mounted' }
                                                        $False { 'Unmounted' }
                                                    }
                                                    'Type' = Switch ($DiskGroup.DiskGroupType) {
                                                        'AllFlash' { 'All Flash' }
                                                        default { $DiskGroup.DiskGroupType }
                                                    }
                                                    'Disk Format Version' = $DiskGroup.DiskFormatVersion
                                                }
                                            }
                                            $VsanDiskGroups | Table -Name "$($VsanCluster.Name) Disk Groups"
                                            #}
                                            #}
                                        }

                                        Section -Style Heading4 'Disks' {
                                            $vDisks = foreach ($Disk in $VsanDisk) {
                                                [PSCustomObject]@{
                                                    'Disk' = $Disk.Name
                                                    'Disk Type' = Switch ($Disk.IsSsd) {
                                                        $true { 'Flash' }
                                                        $false { 'HDD' }
                                                    }
                                                    'Host' = $Disk.VsanDiskGroup.VMHost.Name
                                                    'Disk Tier' = Switch ($Disk.IsCacheDisk) {
                                                        $true { 'Cache' }
                                                        $false { 'Capacity' }
                                                    }
                                                    'Capacity GB' = [math]::Round($Disk.CapacityGB, 2)
                                                    'Serial Number' = $Disk.ExtensionData.SerialNumber
                                                    'Vendor' = $Disk.ExtensionData.Vendor
                                                    'Model' = $Disk.ExtensionData.Model
                                                    'Disk Group' = $Disk.VsanDiskGroup.Uuid
                                                }
                                            }
                                            $vDisks = $vDisks | Sort-Object 'Host', 'Disk Group', 'Disk Tier'
                                            if ($InfoLevel.vSAN -ge 4) {
                                                <#
                                                foreach ($vDisk in ($vDisks)) {
                                                    Section -Style Heading4 $vDisk.Host {
                                                    }
                                                }
                                                #>
                                            } else {
                                                $vDisks | Select-Object 'Disk', 'Disk Group', 'Disk Type', 'Disk Tier', 'Capacity GB', 'Host' | Table -Name 'vSAN Disks'
                                            }
                                        }

                                        $VsanIscsiTargets = Get-VsanIscsiTarget -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue
                                        if ($VsanIscsiTargets) {
                                            Section -Style Heading4 'iSCSI Targets' {
                                                $VsanIscsiTargetInfo = foreach ($VsanIscsiTarget in $VsanIscsiTargets) {
                                                    [PSCustomObject]@{
                                                        'IQN' = $VsanIscsiTarget.IscsiQualifiedName
                                                        'Alias' = $VsanIscsiTarget.Name
                                                        'LUNs' = $VsanIscsiTarget.NumLuns
                                                        'Network Interface' = $VsanIscsiTarget.NetworkInterface
                                                        'I/O Owner Host' = $VsanIscsiTarget.IoOwnerVMHost
                                                        'TCP Port' = $VsanIscsiTarget.TcpPort
                                                        'Health' = $TextInfo.ToTitleCase($VsanIscsiTarget.VsanHealth)
                                                        'Storage Policy' = $VsanIscsiTarget.StoragePolicy.Name
                                                        'Compliance Status' = $TextInfo.ToTitleCase($VsanIscsiTarget.SpbmComplianceStatus)
                                                        'Authentication' = $VsanIscsiTarget.AuthenticationType
                                                    }
                                                }
                                                $VsanIscsiTargetInfo | Table -Name 'vSAN iSCSI Targets' -List -ColumnWidths 50, 50
                                            }
                                        }

                                        $VsanIscsiLuns = Get-VsanIscsiLun -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue | Sort-Object Name, LunId
                                        if ($VsanIscsiLuns) {
                                            Section -Style Heading4 'iSCSI LUNs' {
                                                $VsanIscsiLunInfo = foreach ($VsanIscsiLun in $VsanIscsiLuns) {
                                                    [PSCustomobject]@{
                                                        'LUN' = $VsanIscsiLun.Name
                                                        'LUN ID' = $VsanIscsiLun.LunId
                                                        'Capacity GB' = [math]::Round($VsanIscsiLun.CapacityGB, 2)
                                                        'Used Capacity GB' = [math]::Round($VsanIscsiLun.UsedCapacityGB, 2)
                                                        'State' = Switch ($VsanIscsiLun.IsOnline) {
                                                            $true { 'Online' }
                                                            $false { 'Offline' }
                                                        }
                                                        'Health' = $TextInfo.ToTitleCase($VsanIscsiLun.VsanHealth)
                                                        'Storage Policy' = $VsanIscsiLun.StoragePolicy.Name
                                                        'Compliance Status' = $TextInfo.ToTitleCase($VsanIscsiLun.SpbmComplianceStatus)
                                                    }
                                                }
                                                if ($InfoLevel.vSAN -ge 4) {
                                                    $VsanIscsiLunInfo | Table -List -Name 'iSCSI LUNs' -ColumnWidths 50, 50
                                                } else {
                                                    $VsanIscsiLunInfo | Select-Object 'LUN', 'LUN ID', 'Capacity GB', 'Used Capacity GB', 'State' | Table -Name 'iSCSI LUNs'
                                                }
                                            }
                                        }
                                    }
                                    #endregion vSAN Cluster Section 
                                }      
                            }
                            #endregion vSAN Cluster Detailed Information
                        }
                    }
                }
                #endregion vSAN Section

                #region Datastore Section
                if ($InfoLevel.Datastore -ge 1) {
                    if ($Datastores) {
                        Section -Style Heading2 'Datastores' {
                            Paragraph "The following sections detail the configuration of datastores managed by vCenter Server $vCenterServerName."
                            #region Datastore Infomative Information
                            if ($InfoLevel.Datastore -eq 2) {
                                BlankLine
                                $DatastoreInfo = foreach ($Datastore in $Datastores) {
                                    [PSCustomObject]@{
                                        'Datastore' = $Datastore.Name
                                        'Type' = $Datastore.Type
                                        'Version' = Switch ($Datastore.FileSystemVersion) {
                                            $null { '--' }
                                            default { $Datastore.FileSystemVersion }
                                        }
                                        '# of Hosts' = $Datastore.ExtensionData.Host.Count
                                        '# of VMs' = $Datastore.ExtensionData.VM.Count
                                        'Total Capacity GB' = [math]::Round($Datastore.CapacityGB, 2)
                                        'Used Capacity GB' = [math]::Round((($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)), 2)
                                        'Free Space GB' = [math]::Round($Datastore.FreeSpaceGB, 2)
                                        '% Used' = [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2)
                                    }
                                }
                                if ($Healthcheck.Datastore.CapacityUtilization) {
                                    $DatastoreInfo | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                    $DatastoreInfo | Where-Object { $_.'% Used' -ge 75 -and 
                                        $_.'% Used' -lt 90 } | Set-Style -Style Warning -Property '% Used'
                                }
                                $DatastoreInfo | Sort-Object Name | Table -Name 'Datastore Information'
                            }
                            #endregion Datastore Informative Information

                            #region Datastore Detailed Information
                            if ($InfoLevel.Datastore -ge 3) {
                                foreach ($Datastore in $Datastores) {
                                    #region Datastore Section
                                    Section -Style Heading3 $Datastore.Name {                                
                                        $DatastoreDetail = [PSCustomObject]@{
                                            'Datastore' = $Datastore.Name
                                            'ID' = $Datastore.Id
                                            'Datacenter' = $Datastore.Datacenter
                                            'Type' = $Datastore.Type
                                            'Version' = Switch ($Datastore.FileSystemVersion) {
                                                $null { '--' }
                                                default { $Datastore.FileSystemVersion }
                                            }
                                            'State' = $Datastore.State
                                            'Number of Hosts' = $Datastore.ExtensionData.Host.Count
                                            'Number of VMs' = $Datastore.ExtensionData.VM.Count
                                            'Storage I/O Control' = Switch ($Datastore.StorageIOControlEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Congestion Threshold' = Switch ($Datastore.CongestionThresholdMillisecond) {
                                                $null { '--' }
                                                default { "$($Datastore.CongestionThresholdMillisecond) ms" }
                                            }
                                            'Total Capacity' = "$([math]::Round($Datastore.CapacityGB, 2)) GB"
                                            'Used Capacity' = "$([math]::Round((($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)), 2)) GB"
                                            'Free Space' = "$([math]::Round($Datastore.FreeSpaceGB, 2)) GB"
                                            '% Used' = [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2)
                                        }
                                        if ($Healthcheck.Datastore.CapacityUtilization) {
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 75 -and 
                                                $_.'% Used' -lt 90 } | Set-Style -Style Warning -Property '% Used'
                                        }
                        
                                        #region Datastore Advanced Detailed Information
                                        if ($InfoLevel.Datastore -ge 4) {
                                            $MemberProps = @{
                                                'InputObject' = $DatastoreDetail
                                                'MemberType' = 'NoteProperty'
                                            }
                                            $DatastoreHosts = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                            }
                                            Add-Member @MemberProps -Name 'Hosts' -Value (($DatastoreHosts | Sort-Object) -join ', ')
                                            $DatastoreVMs = foreach ($DatastoreVM in $Datastore.ExtensionData.VM) {
                                                $VMLookup."$($DatastoreVM.Type)-$($DatastoreVM.Value)"
                                            }
                                            Add-Member @MemberProps -Name 'Virtual Machines' -Value (($DatastoreVMs | Sort-Object) -join ', ')
                                        }
                                        #endregion Datastore Advanced Detailed Information

                                        $DatastoreDetail | Sort-Object Datacenter, Name | Table -List -Name 'Datastore Specifications' -ColumnWidths 50, 50

                                        # Get VMFS volumes. Ignore local SCSILuns.
                                        if (($Datastore.Type -eq 'VMFS') -and ($Datastore.ExtensionData.Info.Vmfs.Local -eq $false)) {
                                            #region SCSI LUN Information Section
                                            Section -Style Heading4 'SCSI LUN Information' {
                                                $ScsiLuns = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                    $DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
                                                    $ScsiDeviceDetailProps = @{
                                                        'VMHosts' = $VMHosts
                                                        'VMHostMoRef' = "$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                        'DatastoreDiskName' = $DiskName
                                                    }
                                                    $ScsiDeviceDetail = Get-ScsiDeviceDetail @ScsiDeviceDetailProps

                                                    [PSCustomObject]@{
                                                        'Host' = $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                        'Canonical Name' = $DiskName
                                                        'Capacity GB' = $ScsiDeviceDetail.CapacityGB
                                                        'Vendor' = $ScsiDeviceDetail.Vendor
                                                        'Model' = $ScsiDeviceDetail.Model
                                                        'Is SSD' = $ScsiDeviceDetail.Ssd
                                                        'Multipath Policy' = $ScsiDeviceDetail.MultipathPolicy
                                                        'Paths' = $ScsiDeviceDetail.Paths
                                                    }
                                                }
                                                $ScsiLuns | Sort-Object Host | Table -Name 'SCSI LUN Information'
                                            }
                                            #endregion SCSI LUN Information Section
                                        }
                                    }
                                    #endregion Datastore Section
                                }
                            }
                            #endregion Datastore Detailed Information
                        }
                    }
                }
                #endregion Datastore Section

                #region Datastore Clusters
                if ($InfoLevel.DSCluster -ge 1) {
                    $DSClusters = Get-DatastoreCluster -Server $vCenter
                    if ($DSClusters) {
                        #region Datastore Clusters Section
                        Section -Style Heading2 'Datastore Clusters' {
                            Paragraph "The following sections detail the configuration of datastore clusters managed by vCenter Server $vCenterServerName."
                            #region Datastore Cluster Informative Information
                            if ($InfoLevel.DSCluster -eq 2) {
                                BlankLine
                                $DSClusterInfo = foreach ($DSCluster in $DSClusters) {
                                    [PSCustomObject]@{
                                        'Datastore Cluster' = $DSCluster.Name
                                        'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                            'FullyAutomated' { 'Fully Automated' }
                                            'Manual' { 'Manual' }
                                            default { $DSCluster.SdrsAutomationLevel }
                                        }
                                        'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                        'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                        'Capacity GB' = [math]::Round($DSCluster.CapacityGB, 2)
                                        'Free Space GB' = [math]::Round($DSCluster.FreeSpaceGB, 2)
                                        '% Used' = Switch ($DSCluster.CapacityGB -gt 0) {
                                            $true { [math]::Round((100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2) }
                                            $false { '0' }
                                        }
                                    }
                                }
                                if ($Healthcheck.DSCluster.CapacityUtilization) {
                                    $DSClusterInfo | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                    $DSClusterInfo | Where-Object { $_.'% Used' -ge 75 -and $_.'% Used' -lt 90 } | Set-Style -Style Critical -Property '% Used'
                                }
                                if ($Healthcheck.DSCluster.SDRSAutomationLevelFullyAuto) {
                                    $DSClusterInfo | Where-Object { $_.'SDRS Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                }
                                $DSClusterInfo | Sort-Object Name | Table -Name "$DSCluster Datastore Cluster Information"
                            }
                            #endregion Datastore Cluster Informative Information

                            #region Datastore Cluster Detailed Information
                            if ($InfoLevel.DSCluster -ge 3) {
                                foreach ($DSCluster in $DSClusters) {
                                    # TODO: Space Load Balance Config, IO Load Balance Config, Rules
                                    Section -Style Heading3 $DSCluster.Name {
                                        Paragraph ("The following table details the configuration " +
                                            "for datastore cluster $DSCluster.")
                                        BlankLine

                                        $DSClusterDetail = [PSCustomObject]@{
                                            'Datastore Cluster' = $DSCluster.Name
                                            'ID' = $DSCluster.Id
                                            'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                                'FullyAutomated' { 'Fully Automated' }
                                                'Manual' { 'Manual' }
                                                default { $DSCluster.SdrsAutomationLevel }
                                            }
                                            'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                            'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                            'Capacity' = "$([math]::Round($DSCluster.CapacityGB, 2)) GB"
                                            'Free Space' = "$([math]::Round($DSCluster.FreeSpaceGB, 2)) GB"
                                            '% Used' = Switch ($DSCluster.CapacityGB -gt 0) {
                                                $true { [math]::Round((100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2) }
                                                $false { '0' }
                                            }
                                        }
                
                                        if ($Healthcheck.DSCluster.CapacityUtilization) {
                                            $DSClusterDetail | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                            $DSClusterDetail | Where-Object { $_.'% Used' -ge 75 -and $_.'% Used' -lt 90 } | Set-Style -Style Critical -Property '% Used'
                                        }
                                        if ($Healthcheck.DSCluster.SDRSAutomationLevel) {
                                            $DSClusterDetail | Where-Object { $_.'SDRS Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                        }
                                        $DSClusterDetail | Table -Name "$DSCluster Datastore Cluster Detailed Information" -List -ColumnWidths 50, 50
                
                                        #region SDRS VM Overrides
                                        $StoragePodProps = @{
                                            'ViewType' = 'StoragePod'
                                            'Filter' = @{'Name' = $DSCluster.Name }
                                        }
                                        $StoragePod = Get-View @StoragePodProps
                                        if ($StoragePod) {
                                            $PodConfig = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.PodConfig
                                            # Set default automation value variables
                                            Switch ($PodConfig.DefaultVmBehavior) {
                                                "automated" { $DefaultVmBehavior = "Default (Fully Automated)" }
                                                "manual" { $DefaultVmBehavior = "Default (No Automation (Manual Mode))" }
                                            }
                                            Switch ($PodConfig.DefaultIntraVmAffinity) {
                                                $true { $DefaultIntraVmAffinity = "Default (Yes)" }
                                                $false { $DefaultIntraVmAffinity = "Default (No)" }
                                            }
                                            $VMOverrides = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.VmConfig | Where-Object {
                                                -not (
                                                    ($_.Enabled -eq $null) -and
                                                    ($_.IntraVmAffinity -eq $null)
                                                )
                                            }
                                        }

                                        if ($VMOverrides) {
                                            $VMOverrideDetails = foreach ($Override in $VMOverrides) {
                                                [PSCustomObject]@{
                                                    'Virtual Machine' = $VMLookup."$($Override.Vm.Type)-$($Override.Vm.Value)"
                                                    'SDRS Automation Level' = Switch ($Override.Enabled) {
                                                        $true { 'Fully Automated' }
                                                        $false { 'Disabled' }
                                                        $null { $DefaultVmBehavior }
                                                    }
                                                    'Keep VMDKs Together' = Switch ($Override.IntraVmAffinity) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                        $null { $DefaultIntraVmAffinity }
                                                    }
                                                }
                                            }
                                            Section -Style Heading4 'SDRS VM Overrides' {
                                                $VMOverrideDetails | Sort-Object 'Virtual Machine' | Table -Name 'SDRS VM Overrides'
                                            }
                                        }
                                        #endregion SDRS VM Overrides
                                    }
                                }
                            }
                            #endregion Datastore Cluster Detailed Information
                        }
                        #endregion Datastore Clusters Section
                    }
                }
                #endregion Datastore Clusters     

                #region Virtual Machine Section
                if ($InfoLevel.VM -ge 1) {
                    if ($VMs) {
                        Section -Style Heading2 'Virtual Machines' {
                            Paragraph "The following sections detail the configuration of virtual machines managed by vCenter Server $vCenterServerName."
                            #region Virtual Machine Summary Information
                            if ($InfoLevel.VM -eq 1) {
                                BlankLine
                                $VMSummary = [PSCustomObject]@{
                                    'Total VMs' = $VMs.Count
                                    'Total vCPUs' = ($VMs | Measure-Object -Property NumCpu -Sum).Sum
                                    'Total Memory' = "$([math]::Round(($VMs | Measure-Object -Property MemoryGB -Sum).Sum, 2)) GB"
                                    'Total Provisioned Space' = "$([math]::Round(($VMs | Measure-Object -Property ProvisionedSpaceGB -Sum).Sum, 2)) GB"
                                    'Total Used Space' = "$([math]::Round(($VMs | Measure-Object -Property UsedSpaceGB -Sum).Sum, 2)) GB"
                                    'VMs Powered On' = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                                    'VMs Powered Off' = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count
                                    'VMs Orphaned' = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Orphaned' }).Count
                                    'VMs Inaccessible' = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Inaccessible' }).Count
                                    'VMs Suspended' = ($VMs | Where-Object { $_.PowerState -eq 'Suspended' }).Count
                                    'VMs with Snapshots' = ($VMs | Where-Object { $_.ExtensionData.Snapshot }).Count
                                    'Guest Operating System Types' = (($VMs | Get-View).Summary.Config.GuestFullName | Select-Object -Unique).Count
                                    'VM Tools OK' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOK' }).Count
                                    'VM Tools Old' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOld' }).Count
                                    'VM Tools Not Running' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotRunning' }).Count
                                    'VM Tools Not Installed' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotInstalled' }).Count
                                }
                                $VMSummary | Table -List -Name 'VM Summary' -ColumnWidths 50, 50
                            }
                            #endregion Virtual Machine Summary Information

                            #region Virtual Machine Informative Information
                            if ($InfoLevel.VM -eq 2) {
                                BlankLine
                                $VMSnapshotList = $VMs.Extensiondata.Snapshot.RootSnapshotList
                                $VMInfo = foreach ($VM in $VMs) {
                                    $VMView = $VM | Get-View
                                    [PSCustomObject]@{
                                        'Virtual Machine' = $VM.Name
                                        'Power State' = Switch ($VM.PowerState) {
                                            'PoweredOn' { 'On' }
                                            'PoweredOff' { 'Off' }
                                            default { $VM.PowerState }
                                        }
                                        'Connection State' = $TextInfo.ToTitleCase($VM.ExtensionData.Runtime.ConnectionState)
                                        'IP Address' = Switch ($VMView.Guest.IpAddress) {
                                            $null { '--' }
                                            default { $VMView.Guest.IpAddress }
                                        }
                                        'vCPUs' = $VM.NumCpu
                                        'Memory GB' = [math]::Round(($VM.MemoryGB), 0)
                                        'Provisioned GB' = [math]::Round(($VM.ProvisionedSpaceGB), 2)
                                        'Used GB' = [math]::Round(($VM.UsedSpaceGB), 2)
                                        'HW Version' = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                        'VM Tools Status' = Switch ($VMView.Guest.ToolsStatus) {
                                            'toolsOld' { 'Old' }
                                            'toolsOK' { 'OK' }
                                            'toolsNotRunning' { 'Not Running' }
                                            'toolsNotInstalled' { 'Not Installed' }
                                            default { $VMView.Guest.ToolsStatus }
                                        }         
                                    }
                                }
                                if ($Healthcheck.VM.VMToolsStatus) {
                                    $VMInfo | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                }
                                if ($Healthcheck.VM.PowerState) {
                                    $VMInfo | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                }
                                if ($Healthcheck.VM.ConnectionState) {
                                    $VMInfo | Where-Object { $_.'Connection State' -ne 'Connected' } | Set-Style -Style Critical -Property 'Connection State'
                                }
                                $VMInfo | Table -Name 'VM Informative Information'

                                #region VM Snapshot Information
                                if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                    Section -Style Heading3 'Snapshots' {
                                        $VMSnapshotInfo = foreach ($VMSnapshot in $VMSnapshotList) {
                                            [PSCustomObject]@{
                                                'Virtual Machine' = $VMLookup."$($VMSnapshot.VM)"
                                                'Snapshot Name' = $VMSnapshot.Name
                                                'Description' = $VMSnapshot.Description
                                                'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                            } 
                                        }
                                        if ($Healthcheck.VM.VMSnapshots) {
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning 
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                        }
                                        $VMSnapshotInfo | Table -Name 'VM Snapshot Information'
                                    }
                                }
                                #endregion VM Snapshot Information
                            }
                            #endregion Virtual Machine Informative Information

                            #region Virtual Machine Detailed Information
                            if ($InfoLevel.VM -ge 3) {
                                $VMSpbmConfig = Get-SpbmEntityConfiguration -VM ($VMs) | Where-Object { $_.StoragePolicy -ne $null }
                                if ($InfoLevel.VM -ge 4) {
                                    $VMHardDisks = Get-HardDisk -VM ($VMs) -Server $vCenter
                                }
                                foreach ($VM in $VMs) {
                                    Section -Style Heading3 $VM.name {
                                        $VMUptime = Get-Uptime -VM $VM
                                        $VMSpbmPolicy = $VMSpbmConfig | Where-Object { $_.entity -eq $vm }
                                        $VMView = $VM | Get-View
                                        $VMSnapshotList = $vmview.Snapshot.RootSnapshotList
                                        $VMDetail = [PSCustomObject]@{
                                            'Virtual Machine' = $VM.Name
                                            'ID' = $VM.Id 
                                            'Operating System' = $VMView.Summary.Config.GuestFullName
                                            'Hardware Version' = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                            'Power State' = Switch ($VM.PowerState) {
                                                'PoweredOn' { 'On' }
                                                'PoweredOff' { 'Off' }
                                                default { $TextInfo.ToTitleCase($VM.PowerState) }
                                            }
                                            'Connection State' = $TextInfo.ToTitleCase($VM.ExtensionData.Runtime.ConnectionState)
                                            'VM Tools Status' = Switch ($VMView.Guest.ToolsStatus) {
                                                'toolsOld' { 'Old' }
                                                'toolsOK' { 'OK' }
                                                'toolsNotRunning' { 'Not Running' }
                                                'toolsNotInstalled' { 'Not Installed' }
                                                default { $TextInfo.ToTitleCase($VMView.Guest.ToolsStatus) }
                                            }
                                            'Fault Tolerance State' = Switch ($VMView.Runtime.FaultToleranceState) {
                                                'notConfigured' { 'Not Configured' }
                                                'needsSecondary' { 'Needs Secondary' }
                                                'running' { 'Running' }
                                                'disabled' { 'Disabled' }
                                                'starting' { 'Starting' }
                                                'enabled' { 'Enabled' }
                                                default { $TextInfo.ToTitleCase($VMview.Runtime.FaultToleranceState) }
                                            } 
                                            'Host' = $VM.VMHost.Name
                                            'Parent' = $VM.VMHost.Parent.Name
                                            'Parent Folder' = $VM.Folder.Name
                                            'Parent Resource Pool' = $VM.ResourcePool.Name
                                            'vCPUs' = $VM.NumCpu
                                            'Cores per Socket' = $VM.CoresPerSocket
                                            'CPU Shares' = "$($VM.VMResourceConfiguration.CpuSharesLevel) / $($VM.VMResourceConfiguration.NumCpuShares)"
                                            'CPU Reservation' = $VM.VMResourceConfiguration.CpuReservationMhz
                                            'CPU Limit' = "$($VM.VMResourceConfiguration.CpuReservationMhz) MHz" 
                                            'CPU Hot Add' = Switch ($VMView.Config.CpuHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'CPU Hot Remove' = Switch ($VMView.Config.CpuHotRemoveEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            } 
                                            'Memory Allocation' = "$([math]::Round(($VM.memoryGB), 2)) GB" 
                                            'Memory Shares' = "$($VM.VMResourceConfiguration.MemSharesLevel) / $($VM.VMResourceConfiguration.NumMemShares)"
                                            'Memory Hot Add' = Switch ($VMView.Config.MemoryHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'vNICs' = $VMView.Summary.Config.NumEthernetCards
                                            'DNS Name' = if ($VMView.Guest.HostName) {
                                                $VMView.Guest.HostName
                                            } else {
                                                '--'
                                            }
                                            'Networks' = if ($VMView.Guest.Net.Network) {
                                                (($VMView.Guest.Net | Where-Object { $_.Network -ne $null } | Select-Object Network | Sort-Object Network).Network -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'IP Address' = if ($VMView.Guest.Net.IpAddress) {
                                                (($VMView.Guest.Net | Where-Object { ($_.Network -ne $null) -and ($_.IpAddress -ne $null) } | Select-Object IpAddress | Sort-Object IpAddress).IpAddress -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'MAC Address' = if ($VMView.Guest.Net.MacAddress) {
                                                (($VMView.Guest.Net | Where-Object { $_.Network -ne $null } | Select-Object -Property MacAddress).MacAddress -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'vDisks' = $VMView.Summary.Config.NumVirtualDisks
                                            'Provisioned Space' = "$([math]::Round(($VM.ProvisionedSpaceGB), 2)) GB"
                                            'Used Space' = "$([math]::Round(($VM.UsedSpaceGB), 2)) GB"
                                            'Changed Block Tracking' = Switch ($VMView.Config.ChangeTrackingEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Storage Based Policy' = Switch ($VMSpbmPolicy.StoragePolicy.Name) {
                                                $null { '--' }
                                                default { $TextInfo.ToTitleCase($VMSpbmPolicy.StoragePolicy.Name) }
                                            }
                                            'Storage Based Policy Compliance' = Switch ($VMSpbmPolicy.ComplianceStatus) {
                                                $null { '--' }
                                                'compliant' { 'Compliant' } 
                                                'nonCompliant' { 'Non Compliant' }
                                                'unknown' { 'Unknown' }
                                                default { $TextInfo.ToTitleCase($VMSpbmPolicy.ComplianceStatus) }
                                            }
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $VMDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        #if ($VMView.Config.CreateDate) {
                                        #    Add-Member @MemberProps -Name 'Creation Date' -Value ($VMView.Config.CreateDate).ToLocalTime()
                                        #}
                                        if ($VM.Notes) {
                                            Add-Member @MemberProps -Name 'Notes' -Value $VM.Notes  
                                        }
                                        if ($VMView.Runtime.BootTime) {
                                            Add-Member @MemberProps -Name 'Boot Time' -Value ($VMView.Runtime.BootTime).ToLocalTime()
                                        }
                                        if ($VMUptime.UptimeDays) {
                                            Add-Member @MemberProps -Name 'Uptime Days' -Value $VMUptime.UptimeDays
                                        }

                                        #region VM Health Checks
                                        if ($Healthcheck.VM.VMToolsStatus) {
                                            $VMDetail | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                        }
                                        if ($Healthcheck.VM.PowerState) {
                                            $VMDetail | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                        }
                                        if ($Healthcheck.VM.ConnectionState) {
                                            $VMDetail | Where-Object { $_.'Connection State' -ne 'Connected' } | Set-Style -Style Critical -Property 'Connection State'
                                        }
                                        if ($Healthcheck.VM.CpuHotAdd) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Add'
                                        }
                                        if ($Healthcheck.VM.CpuHotRemove) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Remove' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Remove'
                                        } 
                                        if ($Healthcheck.VM.MemoryHotAdd) {
                                            $VMDetail | Where-Object { $_.'Memory Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'Memory Hot Add'
                                        } 
                                        if ($Healthcheck.VM.ChangeBlockTracking) {
                                            $VMDetail | Where-Object { $_.'Changed Block Tracking' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Changed Block Tracking'
                                        } 
                                        if ($Healthcheck.VM.SpbmPolicyCompliance) {
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Unknown' } | Set-Style -Style Warning -Property 'Storage Based Policy Compliance'
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Non Compliant' } | Set-Style -Style Critical -Property 'Storage Based Policy Compliance'
                                        }
                                        #endregion VM Health Checks

                                        $VMDetail | Table -Name "$($VM.Name) Detailed Information" -List -ColumnWidths 50, 50

                                        if ($InfoLevel.VM -ge 4) {
                                            $VMnics = $VM.Guest.Nics | Where-Object { $_.Device -ne $null } | Sort-Object Device
                                            $VMHdds = $VMHardDisks | Where-Object { $_.ParentId -eq $VM.Id } | Sort-Object Name
                                            $SCSIControllers = $VMView.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -match "SCSI Controller" }
                                            $VMGuestVols = $VM.Guest.Disks | Sort-Object Path
                                            if ($VMnics) {
                                                Section -Style Heading4 "Network Adapters" {
                                                    $VMnicInfo = foreach ($VMnic in $VMnics) {
                                                        [PSCustomObject]@{
                                                            'Adapter' = $VMnic.Device
                                                            'Connected' = $VMnic.Connected
                                                            'Network Name' = Switch -wildcard ($VMnic.NetworkName) {
                                                                'dvportgroup*' { $VDPortgroupLookup."$($VMnic.NetworkName)" }
                                                                default { $VMnic.NetworkName }
                                                            }
                                                            'Adapter Type' = $VMnic.Device.Type
                                                            'IP Address' = $VMnic.IpAddress -join [Environment]::NewLine
                                                            'MAC Address' = $VMnic.Device.MacAddress
                                                        }
                                                    }
                                                    $VMnicInfo | Table -Name "$($VM.Name) Network Adapters"
                                                }
                                            }
                                            if ($SCSIControllers) {
                                                Section -Style Heading4 "SCSI Controllers" {
                                                    $VMScsiControllers = foreach ($VMSCSIController in $SCSIControllers) {
                                                        [PSCustomObject]@{
                                                            'Device' = $VMSCSIController.DeviceInfo.Label
                                                            'Controller Type' = $VMSCSIController.DeviceInfo.Summary
                                                            'Bus Sharing' = Switch ($VMSCSIController.SharedBus) {
                                                                'noSharing' { 'None' }
                                                                default { $VMSCSIController.SharedBus }
                                                            }
                                                        }
                                                    }
                                                    $VMScsiControllers | Sort-Object 'Device' | Table -Name "$($VM.Name) SCSI Controllers"
                                                }
                                            }
                                            if ($VMHdds) {
                                                Section -Style Heading4 "Hard Disks" {
                                                    If ($InfoLevel.VM -eq 4) {
                                                        $VMHardDiskInfo = foreach ($VMHdd in $VMHdds) {
                                                            $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                            $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                            [PSCustomObject]@{
                                                                'Disk' = $VMHdd.Name
                                                                'Datastore' = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                                'Capacity' = "$([math]::Round(($VMHdd.CapacityGB), 2)) GB"
                                                                'Disk Provisioning' = Switch ($VMHdd.StorageFormat) {
                                                                    'EagerZeroedThick' { 'Thick Eager Zeroed' }
                                                                    'LazyZeroedThick' { 'Thick Lazy Zeroed' }
                                                                    $null { '--' }
                                                                    default { $VMHdd.StorageFormat }
                                                                }
                                                                'Disk Type' = Switch ($VMHdd.DiskType) {
                                                                    'RawPhysical' { 'Physical RDM' }
                                                                    'RawVirtual' { "Virtual RDM" }
                                                                    'Flat' { 'VMDK' }
                                                                    default { $VMHdd.DiskType }
                                                                }
                                                                'Disk Mode' = Switch ($VMHdd.Persistence) {
                                                                    'IndependentPersistent' { 'Independent - Persistent' }
                                                                    'IndependentNonPersistent' { 'Independent - Nonpersistent' }
                                                                    'Persistent' { 'Dependent' }
                                                                    default { $VMHdd.Persistence }
                                                                }
                                                            }
                                                        }
                                                        $VMHardDiskInfo | Table -Name "$($VM.Name) Hard Disk Information"
                                                    } else {
                                                        foreach ($VMHdd in $VMHdds) {
                                                            Section -Style Heading5 "$($VMHdd.Name)" {
                                                                $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                                $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                                $VMHardDiskInfo = [PSCustomObject]@{
                                                                    'Datastore' = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                                    'Capacity' = "$([math]::Round(($VMHdd.CapacityGB), 2)) GB"
                                                                    'Disk Path' = $VMHdd.Filename.Substring($VMHdd.Filename.IndexOf("]") + 2)
                                                                    'Disk Shares' = "$($TextInfo.ToTitleCase($VMHdd.ExtensionData.Shares.Level)) / $($VMHdd.ExtensionData.Shares.Shares)"
                                                                    'Disk Limit IOPs' = Switch ($VMHdd.ExtensionData.StorageIOAllocation.Limit) {
                                                                        '-1' { 'Unlimited' }
                                                                        default { $VMHdd.ExtensionData.StorageIOAllocation.Limit }
                                                                    }
                                                                    'Disk Provisioning' = Switch ($VMHdd.StorageFormat) {
                                                                        'EagerZeroedThick' { 'Thick Eager Zeroed' }
                                                                        'LazyZeroedThick' { 'Thick Lazy Zeroed' }
                                                                        $null { '--' }
                                                                        default { $VMHdd.StorageFormat }
                                                                    }
                                                                    'Disk Type' = Switch ($VMHdd.DiskType) {
                                                                        'RawPhysical' { 'Physical RDM' }
                                                                        'RawVirtual' { "Virtual RDM" }
                                                                        'Flat' { 'VMDK' }
                                                                        default { $VMHdd.DiskType }
                                                                    }
                                                                    'Disk Mode' = Switch ($VMHdd.Persistence) {
                                                                        'IndependentPersistent' { 'Independent - Persistent' }
                                                                        'IndependentNonPersistent' { 'Independent - Nonpersistent' }
                                                                        'Persistent' { 'Dependent' }
                                                                        default { $VMHdd.Persistence }
                                                                    }
                                                                    'SCSI Controller' = $SCSIController.DeviceInfo.Label
                                                                    'SCSI Address' = "$($SCSIController.BusNumber):$($VMHdd.ExtensionData.UnitNumber)"
                                                                }
                                                                $VMHardDiskInfo | Table -List "$($VM.Name) $($VMHdd.Name) Information" -ColumnWidths 25, 75
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($VMGuestVols) {
                                                Section -Style Heading4 "Guest Volumes" {
                                                    $VMGuestDiskInfo = foreach ($VMGuestVol in $VMGuestVols) {
                                                        [PSCustomObject]@{
                                                            'Path' = $VMGuestVol.Path
                                                            'Capacity' = "$([math]::Round(($VMGuestVol.CapacityGB), 2)) GB"
                                                            'Used Space' = "$([math]::Round((($VMGuestVol.CapacityGB) - ($VMGuestVol.FreeSpaceGB)), 2)) GB"
                                                            'Free Space' = "$([math]::Round($VMGuestVol.FreeSpaceGB, 2)) GB"
                                                        }
                                                    }
                                                    $VMGuestDiskInfo | Table -Name "$($VM.Name) Guest Volumes" -ColumnWidths 25, 25, 25, 25
                                                }
                                            }
                                        }

                                        
                                        if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                            Section -Style Heading4 "Snapshots" {
                                                $VMSnapshots = foreach ($VMSnapshot in $VMSnapshotList) {
                                                    [PSCustomObject]@{
                                                        'Snapshot Name' = $VMSnapshot.Name
                                                        'Description' = $VMSnapshot.Description
                                                        'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                                    } 
                                                }
                                                if ($Healthcheck.VM.VMSnapshots) {
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning 
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                                }
                                                $VMSnapshots | Table -Name "$($VM.Name) Snapshots"
                                            }
                                        }
                                    }
                                }
                            }
                            #endregion Virtual Machine Detailed Information
                        }
                    }
                }
                #endregion Virtual Machine Section

                #region VMware Update Manager Section
                if ($InfoLevel.VUM -ge 1 -and $VumServer.Name) {
                    $VUMBaselines = Get-PatchBaseline -Server $vCenter
                    if ($VUMBaselines) {
                        Section -Style Heading2 'VMware Update Manager' {
                            Paragraph "The following sections detail the configuration of VMware Update Manager managed by vCenter Server $vCenterServerName."
                            #region VUM Baseline Detailed Information
                            if ($InfoLevel.VUM -ge 2) {
                                Section -Style Heading3 'Baselines' {
                                    $VUMBaselineInfo = foreach ($VUMBaseline in $VUMBaselines) {
                                        [PSCustomObject]@{
                                            'Baseline' = $VUMBaseline.Name
                                            'Description' = $VUMBaseline.Description
                                            'Type' = $VUMBaseline.BaselineType
                                            'Target Type' = $VUMBaseline.TargetType
                                            'Last Update Time' = ($VUMBaseline.LastUpdateTime).ToLocalTime()
                                            '# of Patches' = $VUMBaseline.CurrentPatches.Count
                                        }
                                    }
                                    $VUMBaselineInfo | Sort-Object Baseline | Table -Name 'VMware Update Manager Baseline Information'
                                }
                            }
                            #endregion VUM Baseline Detailed Information

                            #region VUM Comprehensive Information
                            $VUMPatches = Get-Patch -Server $vCenter | Sort-Object -Descending ReleaseDate
                            if ($VUMPatches -and $InfoLevel.VUM -ge 5) {
                                BlankLine
                                Section -Style Heading3 'Patches' {
                                    $VUMPatchInfo = foreach ($VUMPatch in $VUMPatches) {
                                        [PSCustomObject]@{
                                            'Patch' = $VUMPatch.Name
                                            'Product' = ($VUMPatch.Product).Name
                                            'Description' = $VUMPatch.Description
                                            'Release Date' = $VUMPatch.ReleaseDate
                                            'Vendor ID' = $VUMPatch.IdByVendor
                                        }
                                    }
                                    $VUMPatchInfo | Table -Name 'VMware Update Manager Patch Information'
                                }
                            }
                            #endregion VUM Comprehensive Information
                        }
                    }
                }
                #endregion VMware Update Manager Section
            }
            #endregion vCenter Server Heading1 Section
                
            # Disconnect vCenter Server
            $Null = Disconnect-VIServer -Server $VIServer -Confirm:$false -ErrorAction SilentlyContinue
        } # End of If $vCenter
        #endregion Generate vSphere report

        #region Variable cleanup
        Clear-Variable -Name vCenter
        #endregion Variable cleanup

    } # End of Foreach $VIServer
    #endregion Script Body
} # End Invoke-AsBuiltReport.VMware.vSphere function