function Invoke-AsBuiltReport.VMware.vSphere {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        1.0.1
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
        [String]$StylePath
    )

    # Import JSON Configuration for Options and InfoLevel
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options

    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.VMware.vSphere.Style.ps1"
    }

    #endregion Configuration Settings

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
    Version:        0.1.2
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
            if ($VMHostLicense.LicenseKey -and $Options.ShowLicenseKeys) {
                $VMHostLicenseKey = $VMHostLicense.LicenseKey
            } else {
                $VMHostLicenseKey = "*****-*****-*****" + $VMHostLicense.LicenseKey.Substring(17)
            }
            $LicenseObject = [PSCustomObject]@{                               
                Product = $VMHostLicense.Name 
                LicenseKey = $VMHostLicenseKey                   
            }
        }
        if ($vCenter) {
            $vCenterAssignedLicense = $LicenseManagerAssign.GetType().GetMethod("QueryAssignedLicenses").Invoke($LicenseManagerAssign, @($_.MoRef.Value)) | Where-Object { $_.EntityID -eq $vCenter.InstanceUuid }
            $vCenterLicense = $vCenterAssignedLicense.AssignedLicense
            if ($vCenterLicense.LicenseKey -and $Options.ShowLicenseKeys) { 
                $vCenterLicenseKey = $vCenterLicense.LicenseKey
            } else {
                $vCenterLicenseKey = "*****-*****-*****" + $vCenterLicense.LicenseKey.Substring(17)
            }
            $LicenseObject = [PSCustomObject]@{                               
                Product = $vCenterLicense.Name
                LicenseKey = $vCenterLicenseKey                    
            }
        }
        if ($Licenses) {
            foreach ($License in $LicenseManager.Licenses) {
                if ($Options.ShowLicenseKeys) {
                    $LicenseKey = $License.LicenseKey
                } else {
                    $LicenseKey = "*****-*****-*****" + $License.LicenseKey.Substring(17)
                }
                $Object = [PSCustomObject]@{                               
                    'Product' = $License.Name
                    'LicenseKey' = $LicenseKey
                    'Total' = $License.Total
                    'Used' = $License.Used                     
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
                            'VMHost' = $VMHost.Name
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
        $esxcli = Get-EsxCli -V2 -VMHost $vmhost -Server $vCenter
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
                $bootType = "stateless"
            }
            $bootType = $optionValue.StringValue
        }

        # Loop through all storage devices to identify boot device
        $devices = $esxcli.storage.core.device.list.Invoke()
        $foundBootDevice = $false
        foreach ($device in $devices) {
            if ($device.IsBootDevice -eq $true) {
                $foundBootDevice = $true

                if ($device.IsLocal -eq $true -and $networkBoot -and $bootType -ne "stateful") {
                    $bootType = "stateless caching"
                } elseif ($device.IsLocal -eq $true -and $networkBoot -eq $false) {
                    $bootType = "local"
                } elseif ($device.IsLocal -eq $false -and $networkBoot -eq $false) {
                    $bootType = "remote"
                }

                $bootDevice = $device.Device
                $bootModel = $device.Model
                $bootVendor = $device.VEndor
                $bootSize = $device.Size
                $bootIsSAS = $device.IsSAS
                $bootIsSSD = $device.IsSSD
                $bootIsUSB = $device.IsUSB
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
        switch ($Multipath.Policy.Policy) {
            'VMW_PSP_RR' { $MultipathPolicy = 'Round Robin' }
            'VMW_PSP_FIXED' { $MultipathPolicy = 'Fixed' }
            'VMW_PSP_MRU' { $MultipathPolicy = 'Most Recently Used' }
            default { $MultipathPolicy = $Multipath.Policy.Policy }
        }
        $CapacityGB = [math]::Round((($ScsiDisk.Capacity.BlockSize * $ScsiDisk.Capacity.Block) / 1024 / 1024 / 1024), 2)

        [PSCustomObject]@{
            'DisplayName' = $ScsiDisk.DisplayName
            'Ssd' = $ScsiDisk.Ssd
            'LocalDisk' = $ScsiDisk.LocalDisk
            'CanonicalName' = $ScsiDisk.CanonicalName
            'Vendor' = $ScsiDisk.Vendor
            'Model' = $ScsiDisk.Model
            'MultipathPolicy' = $MultipathPolicy
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
            foreach ($pciDevice in $pciDevices) {
                $driverVersion = $esxcli.system.module.get.Invoke(@{module = $pciDevice.ModuleName }) | Select-Object -ExpandProperty Version
                # Get NIC Firmware version
                if ($pciDevice.VMKernelName -like 'vmnic*') {
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
        #region vCenter Server Section
        try {
            $vCenter = Connect-VIServer $VIServer -Credential $Credential -ErrorAction Stop
        } catch {
            Write-Error $_
        }
    
        # Generate report if connection to vCenter Server is successful
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

            # Create a lookup hashtable to quickly link Host MoRefs to Names
            $VMHosts = Get-VMHost -Server $vCenter | Sort-Object Name
            $VMHostLookup = @{ }
            foreach ($VMHost in $VMHosts) {
                $VMHostLookup.($VMHost.Id) = $VMHost.Name
            }

            # Get VMware Update Manager Server Name
            $si = Get-View ServiceInstance -Server $vCenter
            $extMgr = Get-View -Id $si.Content.ExtensionManager -Server $vCenter
            $VumServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcIntegrity' } | 
            Select-Object @{
                N = 'Name'; 
                E = { ($_.Server | Where-Object { $_.Type -eq 'SOAP' -and $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            } 

            # Get vCenter Advanced Settings
            $vCenterAdvSettings = Get-AdvancedSetting -Entity $vCenter
            $vCenterLicense = Get-License -vCenter $vCenter
            $vCenterServerName = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.FQDN' }).Value
            $vCenterServerName = $vCenterServerName.ToString().ToLower()
            #region vCenter Server Heading1 Section
            Section -Style Heading1 $vCenterServerName {
                #region vCenter Server Section
                if ($InfoLevel.vCenter -ge 1) {
                    Section -Style Heading2 'vCenter Server' { 
                        Paragraph ("The following section provides information on the configuration of vCenter " +
                            "Server $vCenterServerName.")
                        BlankLine

                        #region vCenter Server Informative Information
                        if ($InfoLevel.vCenter -eq 2) {                   
                            $vCenterSummary = [PSCustomObject]@{
                                'Name' = $vCenterServerName
                                'IP Address' = ($vCenterAdvSettings | Where-Object { $_.name -like 'VirtualCenter.AutoManagedIPV4' }).Value
                                'Version' = $vCenter.Version
                                'Build' = $vCenter.Build
                                'OS Type' = $vCenter.ExtensionData.Content.About.OsType
                            }
                            $vCenterSummary | Table -Name $vCenterServerName -ColumnWidths 20, 20, 20, 20, 20  
                        }
                        #endregion vCenter Server Informative Information

                        #region vCenter Server Detailed Information
                        if ($InfoLevel.vCenter -ge 3) { 
                            $vCenterDetail = [PSCustomObject]@{
                                'Name' = $vCenterServerName
                                'IP Address' = ($vCenterAdvSettings | Where-Object { $_.name -like 'VirtualCenter.AutoManagedIPV4' }).Value
                                'Version' = $vCenter.Version
                                'Build' = $vCenter.Build
                                'OS Type' = $vCenter.ExtensionData.Content.About.OsType
                                'Product' = $vCenterLicense.Product
                                'License Key' = $vCenterLicense.LicenseKey
                                'Instance ID' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'instance.id' }).Value
                            }
                            $MemberProps = @{
                                'InputObject' = $vCenterDetail
                                'MemberType' = 'NoteProperty'
                            }
                            if ($vCenter.Version -gt 6) {
                                Add-Member @MemberProps -Name 'HTTP Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpport' }).Value
                                Add-Member @MemberProps -Name 'HTTPS Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpsport' }).Value
                                Add-Member @MemberProps -Name 'Platform Services Controller' -Value (($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.sso.admin.uri' }).Value -replace "^https://|/sso-adminserver/sdk/vsphere.local")
                            }
                            if ($VumServer.Name) {
                                Add-Member @MemberProps -Name 'Update Manager Server' -Value $VumServer.Name
                            }  

                            if ($Healthcheck.vCenter.Licensing) {
                                $vCenterDetail | Where-Object { $_.'Product' -like '*Evaluation*' } | Set-Style -Style Warning -Property 'Product'
                                $vCenterDetail | Where-Object { $_.'Product' -eq $null } | Set-Style -Style Warning -Property 'Product'
                                $vCenterDetail | Where-Object { $_.'License Key' -like '*-00000-00000' } | Set-Style -Style Warning -Property 'License Key'
                            }
                            $vCenterDetail | Table -Name "$vCenterServerName vCenter Server Detailed Information" -List -ColumnWidths 50, 50

                            #region vCenter Server Database Settings
                            Section -Style Heading3 'Database Settings' {
                                $vCenterDbInfo = [PSCustomObject]@{
                                    'Database Type' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dbtype' }).Value
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
                                $Licenses = Get-License -Licenses | Select-Object Product, @{L = 'License Key'; E = { ($_.LicenseKey) } }, Total, Used, @{L = 'Available'; E = { ($_.total) - ($_.Used) } } -Unique
                                if ($Healthcheck.vCenter.Licensing) {
                                    $Licenses | Where-Object { $_.Product -eq 'Product Evaluation' } | Set-Style -Style Warning 
                                }
                                $Licenses | Sort-Object Product | Table -Name 'Licensing' -ColumnWidths 32, 32, 12, 12, 12
                            }
                            #endregion vCenter Server Licensing

                            <#
                            #region vCenter Server SSL Certificate
                            Section -Style Heading3 'SSL Certificate' {
                                $VcSslCertHash = @{
                                    Country          = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.country'}).Value
                                    Email            = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.email'}).Value
                                    Locality         = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.localityName'}).Value
                                    State            = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.state'}).Value
                                    Organization     = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.organizationName'}).Value
                                    OrganizationUnit = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.organizationalUnitName'}).Value
                                    DaysValid        = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.daysValid'}).Value
                                    Mode             = ($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.mode'}).Value
                                }
                                $VcSslCertificate = $VcSslCertHash | Select-Object @{L = 'Country'; E = {$_.Country}}, @{L = 'State'; E = {$_.State}}, @{L = 'Locality'; E = {$_.Locality}}, 
                                @{L = 'Organization'; E = {$_.Organization}}, @{L = 'Organizational Unit'; E = {$_.OrganizationUnit}}, @{L = 'Email'; E = {$_.Email}}, @{L = 'Validity'; E = {"$($_.DaysValid / 365) Years"}}  
                                $VcSslCertificate | Table -Name "$vCenter SSL Certificate" -List -ColumnWidths 50, 50
                            }
                            #endregion vCenter Server SSL Certificate
                            #>
                    
                            #region vCenter Server Roles
                            Section -Style Heading3 'Roles' {
                                $VIRoles = Get-VIRole -Server $vCenter
                                $VCRoles = foreach ($VIRole in $VIRoles) {
                                    [PSCustomObject]@{
                                        'Name' = $VIRole.Name
                                        'System Role' = Switch ($VIRole.IsSystem) {
                                            $true { 'Yes' }
                                            $false { 'No' }
                                        }
                                    }
                                }
                                $VCRoles | Sort-Object Name | Table -Name 'Roles' -ColumnWidths 50, 50 
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
                    
                        #region vCenter Alarms
                        if ($InfoLevel.vCenter -ge 5) {
                            Section -Style Heading3 'Alarms' {
                                Paragraph ("The following table details the configuration of the vCenter Server " +
                                    "alarms for $vCenterServerName.")
                                BlankLine
                                $AlarmActions = Get-AlarmAction -Server $vCenter 
                                $Alarms = foreach ($AlarmAction in $AlarmActions) {
                                    [PSCustomObject]@{
                                        'Alarm Definition' = $AlarmAction.AlarmDefinition 
                                        'Action Type' = Switch ($AlarmAction.ActionType) {
                                            'SendSNMP' { 'Send SNMP traps' }
                                            'SendEmail' { 'Send email notifications' }
                                            'ExecuteScript' { 'Run Script' }
                                        }
                                        'Trigger' = $AlarmAction.Trigger -join [Environment]::NewLine
                                    }
                                }
                                $Alarms | Sort-Object 'Alarm Definition' | Table -Name 'Alarms' -ColumnWidths 50, 20, 30
                            }
                        }
                        #endregion vCenter Alarms
                    }
                }
                #endregion vCenter Server Section

                #region Cluster Section
                if ($InfoLevel.Cluster -ge 1) {
                    $Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
                    if ($Clusters) {
                        Section -Style Heading2 'Clusters' {
                            Paragraph ("The following section provides information on the configuration of each " +
                                "vSphere HA/DRS cluster managed by vCenter Server $vCenterServerName.")

                            #region Cluster Informative Information   
                            if ($InfoLevel.Cluster -eq 2) {
                                BlankLine
                                $ClusterInfo = foreach ($Cluster in $Clusters) {
                                    [PSCustomObject]@{
                                        'Name' = $Cluster.Name
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
                                            default { $Cluster.EVCMode }
                                        }  
                                        'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                            'WithVM' { 'With VM' }
                                            'InHostDatastore' { 'In Host Datastore' }
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
                                    Section -Style Heading3 $Cluster {
                                        Paragraph "The following table details the configuration for cluster $Cluster."
                                        BlankLine
                                        #region Cluster Configuration                                
                                        $ClusterDetail = [PSCustomObject]@{
                                            'Name' = $Cluster.Name
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
                                                default { $Cluster.EVCMode }
                                            } 
                                            'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                                'WithVM' { 'Virtual machine directory' }
                                                'InHostDatastore' { 'Datastore specified by host' }
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
                                        if ($InfoLevel.Cluster -ge 4) {
                                            $ClusterDetail | ForEach-Object {
                                                $ClusterHosts = $Cluster | Get-VMHost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($ClusterHosts.Name -join ', ')
                                                $ClusterVMs = $Cluster | Get-VM | Sort-Object Name 
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ClusterVMs.Name -join ', ')
                                            }
                                        }
                                        $ClusterDetail | Table -List -Name "$Cluster Detailed Information" -ColumnWidths 50, 50
                                        #endregion Cluster Configuration
                                
                                        #region vSphere HA Cluster Configuration
                                        if ($Cluster.HAEnabled) {
                                            Section -Style Heading4 'vSphere HA Configuration' {
                                                Paragraph ("The following sections detail the vSphere HA configuration " +
                                                    "for cluster $Cluster.")

                                                #region vSphere HA Cluster Failures and Responses
                                                Section -Style Heading5 'Failures and Responses' {
                                                    $HAClusterResponses = [PSCustomObject]@{
                                                        'Host Monitoring' = Switch ($ClusterDasConfig.HostMonitoring) {
                                                            'disabled' { 'Disabled' }
                                                            'enabled' { 'Enabled' }
                                                        }
                                                    }
                                                    if ($ClusterDasConfig.HostMonitoring -eq 'enabled') {
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
                                        ##TODO: Proactive HA Providers
                                        # Proactive HA is only available in vSphere 6.5 and above
                                        if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled -and $vCenter.Version -ge 6.5) {
                                            Section -Style Heading4 'Proactive HA' {
                                                Paragraph ("The following sections detail the Proactive HA configuration " +
                                                    "for cluster $Cluster.")

                                                #region Proactive HA Failures and Responses
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
                                                        }
                                                        $ProactiveHaSevereRemediation = Switch ($ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                                            'MaintenanceMode' { 'Maintenance Mode' }
                                                            'QuarantineMode' { 'Quarantine Mode' }
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
                                                    Section -Style Heading5 'DRS Cluster Groups' {
                                                        $DrsGroups = foreach ($DrsClusterGroup in $DrsClusterGroups) {
                                                            [PSCustomObject]@{
                                                                'Name' = $DrsClusterGroup.Name
                                                                'Group Type' = $DrsClusterGroup.GroupType
                                                                'Members' = ($DrsClusterGroup.Member | Sort-Object) -join ', '
                                                            }
                                                            $DrsGroups | Sort-Object GroupType, Name | Table -Name "$Cluster DRS Cluster Groups"
                                                        }
                                                    }
                                                    #endregion vSphere DRS Cluster Group  

                                                    #region vSphere DRS Cluster VM/Host Rules
                                                    $DrsVMHostRules = $Cluster | Get-DrsVMHostRule
                                                    if ($DrsVMHostRules) {
                                                        Section -Style Heading5 'DRS VM/Host Rules' {
                                                            $DrsVMHostRuleDetail = foreach ($DrsVMHostRule in $DrsVMHostRules) {
                                                                [PSCustomObject]@{
                                                                    'Name' = $DrsVMHostRule.Name
                                                                    'Type' = $DrsVMHostRule.Type
                                                                    'Enabled' = Switch ($DrsVMHostRule.Enabled) {
                                                                        $true { 'Yes' }
                                                                        $False { 'No' }
                                                                    }
                                                                    'VM Group' = $DrsVMHostRule.VMGroup
                                                                    'VMHost Group' = $DrsVMHostRule.VMHostGroup
                                                                }
                                                            }
                                                            if ($Healthcheck.Cluster.DrsVMHostRules) {
                                                                $DrsVMHostRuleDetail | Where-Object { $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Enabled'
                                                            }
                                                            $DrsVMHostRuleDetail | Sort-Object Name | Table -Name "$Cluster DRS VM/Host Rules"
                                                        }
                                                    }
                                                    #endregion vSphere DRS Cluster VM/Host Rules

                                                    #region vSphere DRS Cluster Rules
                                                    $DrsRules = $Cluster | Get-DrsRule
                                                    if ($DrsRules) {
                                                        Section -Style Heading5 'DRS Rules' {
                                                            $DrsRuleDetail = foreach ($DrsRule in $DrsRules) {
                                                                [PSCustomObject]@{
                                                                    'Name' = $DrsRule.Name
                                                                    'Type' = $DrsRule.Type
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
                                                                $DrsRuleDetail | Sort-Object Type | Table -Name "$Cluster DRS Rules"
                                                            }
                                                        }
                                                        #endregion vSphere DRS Cluster Rules                                
                                                    }
                                                }
                                                #endregion DRS Cluster Configuration

                                                #region Cluster VM Overrides
                                                $DrsVmOverrides = $Cluster.ExtensionData.Configuration.DrsVmConfig
                                                $DasVmOverrides = $Cluster.ExtensionData.Configuration.DasVmConfig
                                                if ($DrsVmOverrides -or $DasVmOverrides) {
                                                    Section -Style Heading4 'VM Overrides' {
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
                                                        if ($DasVmOverrides) {
                                                            Section -Style Heading5 'vSphere HA' {
                                                                $DasVmOverrideDetails = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                    [PSCustomObject]@{
                                                                        'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                        'VM Restart Priority' = Switch ($DasVmOverride.DasSettings.RestartPriority) {
                                                                            $null { '-' }
                                                                            'lowest' { 'Lowest' }
                                                                            'low' { 'Low' }
                                                                            'medium' { 'Medium' }
                                                                            'high' { 'High' }
                                                                            'highest' { 'Highest' }
                                                                            'disabled' { 'Disabled' }
                                                                            'clusterRestartPriority' { 'Cluster default' }
                                                                        }
                                                                        'VM Dependency Restart Condition Timeout' = Switch ($DasVmOverride.DasSettings.RestartPriorityTimeout) {
                                                                            $null { '-' }
                                                                            '-1' { 'Disabled' }
                                                                            default { "$($DasVmOverride.DasSettings.RestartPriorityTimeout) seconds" }
                                                                        }
                                                                        'Host Isolation Response' = Switch ($DasVmOverride.DasSettings.IsolationResponse) {
                                                                            $null { '-' }
                                                                            'none' { 'Disabled' }
                                                                            'powerOff' { 'Power off and restart VMs' }
                                                                            'shutdown' { 'Shutdown and restart VMs' }
                                                                            'clusterIsolationResponse' { 'Cluster default' }
                                                                        }
                                                                    }
                                                                }
                                                                $DasVmOverrideDetails | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides" -ColumnWidths 25, 25, 25, 25

                                                                Section -Style Heading5 'PDL/APD Protection Settings' {
                                                                    $DasVmOverridePdlApd = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmComponentProtection = $DasVmOverride.DasSettings.VmComponentProtectionSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'PDL Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForPDL) {
                                                                                $null { '-' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartAggressive' { 'Power off and restart VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'APD Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForAPD) {
                                                                                $null { '-' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartConservative' { 'Power off and restart VMs - Conservative restart policy' }
                                                                                'restartAggressive' { 'Power off and restart VMs - Aggressive restart policy' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'VM Failover Delay' = Switch ($DasVmComponentProtection.VmTerminateDelayForAPDSec) {
                                                                                $null { '-' }
                                                                                '-1' { 'Disabled' }
                                                                                default { "$(($DasVmComponentProtection.VmTerminateDelayForAPDSec)/60) minutes" }
                                                                            }
                                                                            'Response Recovery' = Switch ($DasVmComponentProtection.VmReactionOnAPDCleared) {
                                                                                $null { '-' }
                                                                                'reset' { 'Reset VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                                'useClusterDefault' { 'Cluster default' }
                                                                            }
                                                                        }
                                                                    }
                                                                    $DasVmOverridePdlApd | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides PDL/APD Settings" -ColumnWidths 20, 20, 20, 20, 20
                                                                }

                                                                Section -Style Heading5 'VM Monitoring' {
                                                                    $DasVmOverrideVmMonitoring = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmMonitoring = $DasVmOverride.DasSettings.VmToolsMonitoringSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'VM Monitoring' = Switch ($DasVmMonitoring.VmMonitoring) {
                                                                                $null { '-' }
                                                                                'vmMonitoringDisabled' { 'Disabled' }
                                                                                'vmMonitoringOnly' { 'VM Monitoring Only' }
                                                                                'vmAndAppMonitoring' { 'VM and App Monitoring' }
                                                                            }
                                                                            'Failure Interval' = Switch ($DasVmMonitoring.FailureInterval) {
                                                                                $null { '-' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '-'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.FailureInterval) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Minimum Uptime' = Switch ($DasVmMonitoring.MinUptime) {
                                                                                $null { '-' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '-'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.MinUptime) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Per-VM Resets' = Switch ($DasVmMonitoring.MaxFailures) {
                                                                                $null { '-' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '-'
                                                                                    } else {
                                                                                        $DasVmMonitoring.MaxFailures
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Resets Time Window' = Switch ($DasVmMonitoring.MaxFailureWindow) {
                                                                                $null { '-' }
                                                                                '-1' { 'No window' }                                                                
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '-'
                                                                                    } else {
                                                                                        "Within $(($DasVmMonitoring.MaxFailureWindow)/3600) hrs"
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                    $DasVmOverrideVmMonitoring | Sort-Object 'Virtual Machine' | Table -Name "$Cluster HA VM Overrides VM Monitoring"
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                #endregion Cluster VM Overrides
                                
                                                #region Cluster VUM Baselines
                                                if ($VUMConnection) {
                                                    $ClusterPatchBaselines = $Cluster | Get-PatchBaseline
                                                    if ($ClusterPatchBaselines) {
                                                        Section -Style Heading4 'Update Manager Baselines' {
                                                            $ClusterBaselines = foreach ($ClusterBaseline in $ClusterPatchBaselines) {
                                                                [PSCustomObject]@{
                                                                    'Name' = $ClusterBaseline.Name
                                                                    'Description' = $ClusterBaseline.Description
                                                                    'Type' = $ClusterBaseline.BaselineType
                                                                    'Target Type' = $ClusterBaseline.TargetType
                                                                    'Last Update Time' = $ClusterBaseline.LastUpdateTime
                                                                    '# of Patches' = $ClusterBaseline.CurrentPatches.Count
                                                                }
                                                            }
                                                            $ClusterBaselines | Sort-Object 'Name' | Table -Name "$Cluster Update Manager Baselines"
                                                        }
                                                    }
                                                }
                                                #endregion Cluster VUM Baselines

                                                #region Cluster VUM Compliance
                                                if ($InfoLevel.Cluster -ge 4 -and $VumServer.Name) {
                                                    $ClusterCompliances = $Cluster | Get-Compliance
                                                    if ($ClusterCompliances) {
                                                        Section -Style Heading4 'Update Manager Compliance' {
                                                            $ClusterComplianceInfo = foreach ($ClusterCompliance in $ClusterCompliances) {
                                                                [PSCustomObject]@{
                                                                    'Name' = $ClusterCompliance.Entity
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
                                                            $ClusterComplianceInfo | Sort-Object Name, Baseline | Table -Name "$Cluster Update Manager Compliance" -ColumnWidths 25, 50, 25
                                                        }
                                                    }
                                                }
                                                #endregion Cluster VUM Compliance
                
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
                                    }
                                    #endregion Cluster Detailed Information
                                }
                            }
                            #endregion Cluster Detailed Information
                        }
                    }
                }
                #endregion Cluster Section   

                #region Resource Pool Section
                if ($InfoLevel.ResourcePool -ge 1) {
                    $ResourcePools = Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
                    if ($ResourcePools) {
                        Section -Style Heading2 'Resource Pools' {
                            Paragraph ("The following section provides information on the configuration of " +
                                "resource pools managed by vCenter Server $vCenterServerName.")

                            if ($InfoLevel.ResourcePool -eq 2) {
                                BlankLine
                                #region Resource Pool Informative Information
                                $ResourcePoolInfo = foreach ($ResourcePool in $ResourcePools) {
                                    [PSCustomObject]@{
                                        'Name' = $ResourcePool.Name
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

                            if ($InfoLevel.ResourcePool -ge 3) {
                                #region Resource Pool Detailed Information
                                foreach ($ResourcePool in $ResourcePools) {
                                    Section -Style Heading3 $ResourcePool.Name {            
                                        $ResourcePoolDetail = [PSCustomObject]@{
                                            'Name' = $ResourcePool.Name
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

                                        # Set InfoLevel to 4 or above to provide information for associated VMs
                                        if ($InfoLevel.ResourcePool -ge 4) {
                                            $ResourcePoolDetail | ForEach-Object {
                                                # Query for VMs by resource pool Id
                                                $ResourcePoolId = $_.Id
                                                $ResourcePoolVMs = $VMs | Where-Object { $_.ResourcePoolId -eq $ResourcePoolId } | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ResourcePoolVMs.Name -join ', ')
                                            }
                                        }
                                        $ResourcePoolDetail | Table -Name 'Resource Pool Detailed Information' -List -ColumnWidths 50, 50  
                                    }
                                }
                                #endregion Resource Pool Detailed Information
                            }
                        }
                    }
                }
                #endregion Resource Pool Section

                #region ESXi VMHost Section
                if ($InfoLevel.VMHost -ge 1) {
                    if ($VMHosts) {
                        #region Hosts Section
                        Section -Style Heading2 'Hosts' {
                            Paragraph ("The following section provides information on the configuration of VMware " +
                                "ESXi hosts managed by vCenter Server $vCenterServerName.")

                            #region ESXi Host Informative Information
                            if ($InfoLevel.VMHost -eq 2) {
                                BlankLine
                                $VMHostInfo = foreach ($VMHost in $VMHosts) {
                                    [PSCustomObject]@{
                                        'Name' = $VMHost.Name
                                        'Version' = $VMHost.Version
                                        'Build' = $VMHost.Build
                                        'Parent' = $VMHost.Parent
                                        'Connection State' = Switch ($VMHost.ConnectionState) {
                                            'NotResponding' { 'Not Responding' }
                                            default { $VMHost.ConnectionState }
                                        }
                                        'CPU Usage MHz' = $VMHost.CpuUsageMhz
                                        'Memory Usage GB' = [math]::Round($VMHost.MemoryUsageGB, 2)
                                    }
                                }
                                if ($Healthcheck.VMHost.ConnectionState) {
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Maintenance' } | Set-Style -Style Warning
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Not Responding' } | Set-Style -Style Critical
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Disconnected' } | Set-Style -Style Critical
                                }
                                $VMHostInfo | Table -Name 'ESXi Host Information' #-ColumnWidths 23, 10, 12, 12, 14, 10, 10, 9
                            }
                            #endregion ESXi Host Informative Information

                            #region ESXi Host Detailed Information
                            if ($InfoLevel.VMHost -ge 3) {       
                                foreach ($VMHost in ($VMHosts | Where-Object { $_.ConnectionState -eq 'Connected' -or $_.ConnectionState -eq 'Maintenance' })) {        
                                    #region VMHost Section
                                    Section -Style Heading3 $VMHost {
                                        ### TODO: Host Certificate, Swap File Location
                                        #region ESXi Host Hardware Section
                                        Section -Style Heading4 'Hardware' {
                                            Paragraph ("The following section provides information on the host " +
                                                "hardware configuration of $VMHost.")
                                            BlankLine

                                            #region ESXi Host Specifications
                                            $VMHostUptime = Get-Uptime -VMHost $VMHost
                                            $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                            $VMHostHardware = Get-VMHostHardware -VMHost $VMHost
                                            $VMHostLicense = Get-License -VMHost $VMHost
                                            $ScratchLocation = Get-AdvancedSetting -Entity $VMHost | Where-Object { $_.Name -eq 'ScratchConfig.CurrentScratchLocation' }
                                            $VMHostDetail = [PSCustomObject]@{
                                                'Name' = $VMHost.Name
                                                'Connection State' = Switch ($VMHost.ConnectionState) {
                                                    'NotResponding' { 'Not Responding' }
                                                    default { $VMHost.ConnectionState }
                                                }
                                                'ID' = $VMHost.Id
                                                'Parent' = $VMHost.Parent
                                                'Manufacturer' = $VMHost.Manufacturer
                                                'Model' = $VMHost.Model
                                                'Serial Number' = $VMHostHardware.SerialNumber 
                                                'Asset Tag' = $VMHostHardware.AssetTag 
                                                'Processor Type' = $VMHost.Processortype
                                                'HyperThreading' = Switch ($VMHost.HyperthreadingActive) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                }
                                                'Number of CPU Sockets' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages 
                                                'Number of CPU Cores' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores 
                                                'Number of CPU Threads' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuThreads
                                                'CPU Speed' = "$([math]::Round(($VMHost.ExtensionData.Hardware.CpuInfo.Hz) / 1000000000, 2)) GHz" 
                                                'Memory' = "$([math]::Round($VMHost.MemoryTotalGB, 0)) GB" 
                                                'NUMA Nodes' = $VMHost.ExtensionData.Hardware.NumaInfo.NumNodes 
                                                'Number of NICs' = $VMHostHardware.NicCount 
                                                'Number of Datastores' = $VMHost.ExtensionData.Datastore.Count 
                                                'Number of VMs' = $VMHost.ExtensionData.VM.Count 
                                                'Maximum EVC Mode' = $VMHost.MaxEVCMode 
                                                'Power Management Policy' = $VMHost.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy 
                                                'Scratch Location' = $ScratchLocation.Value 
                                                'Bios Version' = $VMHost.ExtensionData.Hardware.BiosInfo.BiosVersion 
                                                'Bios Release Date' = $VMHost.ExtensionData.Hardware.BiosInfo.ReleaseDate 
                                                'ESXi Version' = $VMHost.Version 
                                                'ESXi Build' = $VMHost.build 
                                                'Product' = $VMHostLicense.Product 
                                                'License Key' = $VMHostLicense.LicenseKey 
                                                'Boot Time' = $VMHost.ExtensionData.Runtime.Boottime 
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
                                            }
                                            if ($Healthcheck.VMHost.ScratchLocation) {
                                                $VMHostDetail | Where-Object { $_.'Scratch Location' -eq '/tmp/scratch' } | Set-Style -Style Warning -Property 'Scratch Location'
                                            }
                                            if ($Healthcheck.VMHost.UpTimeDays) {
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 275 -and $_.'Uptime Days' -lt 365 } | Set-Style -Style Warning -Property 'Uptime Days'
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 365 } | Set-Style -Style Warning -Property 'Uptime Days'
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
                                                    'Size' = "$([math]::Round($ESXiBootDevice.SizeMB / 1024), 2) GB"
                                                    'Is SAS' = Switch ($ESXiBootDevice.IsSAS) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                    }
                                                    'Is SSD' = Switch ($ESXiBootDevice.IsSSD) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                    }
                                                    'Is USB' = Switch ($ESXiBootDevice.IsUSB) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                    }
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
                                            Paragraph "The following section provides information on the host system configuration of $VMHost."

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
                                                if ($Healthcheck.VMHost.TimeConfig) {
                                                    $VMHostTimeSettings | Where-Object { $_.'NTP Service' -eq 'Stopped' } | Set-Style -Style Critical -Property 'NTP Service'
                                                }
                                                $VMHostTimeSettings | Table -Name "$VMHost Time Configuration" -ColumnWidths 30, 30, 40
                                            }
                                            #endregion ESXi Host Time Configuration

                                            #region ESXi Host Syslog Configuration
                                            $SyslogConfig = $VMHost | Get-VMHostSysLogServer
                                            if ($SyslogConfig) {
                                                Section -Style Heading5 'Syslog Configuration' {
                                                    ### TODO: Syslog Rotate & Size, Log Directory (Adv Settings)
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
                                                                'Name' = $VMHostBaseline.Name
                                                                'Description' = $VMHostBaseline.Description
                                                                'Type' = $VMHostBaseline.BaselineType
                                                                'Target Type' = $VMHostBaseline.TargetType
                                                                'Last Update Time' = $VMHostBaseline.LastUpdateTime
                                                                '# of Patches' = $VMHostBaseline.CurrentPatches.Count
                                                            }
                                                        }
                                                        $VMHostBaselines | Sort-Object Name | Table -Name "$VMHost Update Manager Baselines"
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

                                            #region ESXi Host InfoLevel 5 Section
                                            # Set InfoLevel to 5 to provide advanced system information for VMHosts
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
                                                            'Name' = $VMHostVib.Name
                                                            'ID' = $VMHostVib.Id
                                                            'Version' = $VMHostVib.Version
                                                            'Acceptance Level' = $VMHostVib.AcceptanceLevel
                                                            'Creation Date' = $VMHostVib.CreationDate
                                                            'Install Date' = $VMHostVib.InstallDate
                                                        }
                                                    } 
                                                    $VMHostVibs | Sort-Object 'Install Date' -Descending | Table -Name "$VMHost Software VIBs" -ColumnWidths 10, 25, 20, 10, 15, 10, 10
                                                }
                                                #endregion ESXi Host Software VIBs
                                            }
                                            #endregion ESXi Host InfoLevel 5 Section
                                        }
                                        #endregion ESXi Host System Section

                                        #region ESXi Host Storage Section
                                        Section -Style Heading4 'Storage' {
                                            Paragraph "The following section provides information on the host storage configuration of $VMHost."
        
                                            #region ESXi Host Datastore Specifications
                                            $VMHostDatastores = $VMHost | Get-Datastore
                                            if ($VMHostDatastores) { 
                                                Section -Style Heading5 'Datastores' {
                                                    $VMHostDsSpecs = foreach ($VMHostDatastore in $VMHostDatastores) {
                                                        [PSCustomObject]@{
                                                            'Name' = $VMHostDatastore.Name
                                                            'Type' = $VMHostDatastore.Type
                                                            'Version' = $VMHostDatastore.FileSystemVersion
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
                                                    $VMHostDsSpecs | Sort-Object Name | Table -Name "$VMHost Datastores" #-ColumnWidths 20,10,10,10,10,10,10,10,10
                                                }
                                            }
                                            #endregion ESXi Host Datastore Specifications
        
                                            #region ESXi Host Storage Adapter Information
                                            $VMHostHba = $VMHost | Get-VMHostHba | Where-Object { $_.type -eq 'FibreChannel' -or $_.type -eq 'iSCSI' }
                                            if ($VMHostHba) {
                                                Section -Style Heading5 'Storage Adapters' {
                                                    $VMHostHbaFC = $VMHost | Get-VMHostHba -Type FibreChannel
                                                    if ($VMHostHbaFC) {
                                                        Paragraph "The following table details the fibre channel storage adapters for $VMHost."
                                                        BlankLine
                                                        $VMHostHbaFC = $VMHost | Get-VMHostHba -Type FibreChannel | Select-Object Device, Type, Model, Driver, 
                                                        @{L = 'Node WWN'; E = { ([String]::Format("{0:X}", $_.NodeWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":" } }, 
                                                        @{L = 'Port WWN'; E = { ([String]::Format("{0:X}", $_.PortWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":" } }, speed, status
                                                        $VMHostHbaFC | Sort-Object Device | Table -Name "$VMHost FC Storage Adapters"
                                                    }

                                                    $VMHostHbaIScsi = $VMHost | Get-VMHostHba -Type iSCSI
                                                    if ($VMHostHbaFC -and $VMHostHbaIScsi) {
                                                        BlankLine
                                                    }
                                                    if ($VMHostHbaIScsi) {
                                                        Paragraph "The following table details the iSCSI storage adapters for $VMHost."
                                                        BlankLine
                                                        $VMHostHbaIScsi = $VMHost | Get-VMHostHba -Type iSCSI | Select-Object Device, @{L = 'iSCSI Name'; E = { $_.IScsiName } }, Model, Driver, @{L = 'Speed'; E = { $_.CurrentSpeedMb } }, status
                                                        $VMHostHbaIScsi | Sort-Object Device | Table -Name "$VMHost iSCSI Storage Adapters" -List -ColumnWidths 25, 75
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host Storage Adapater Information
                                        }
                                        #endregion ESXi Host Storage Section

                                        #region ESXi Host Network Section
                                        Section -Style Heading4 'Network' {
                                            Paragraph "The following section provides information on the host network configuration of $VMHost."
                                            BlankLine
                                            #region ESXi Host Network Configuration
                                            $VMHostNetwork = $VMHost.ExtensionData.Config.Network
                                            $VMHostNetworkDetail = [PSCustomObject]@{
                                                'VMHost' = $VMHost.Name 
                                                'Virtual Switches' = ($VMHostNetwork.Vswitch.Name | Sort-Object) -join ', '
                                                'VMKernel Adapters' = ($VMHostNetwork.Vnic.Device | Sort-Object) -join ', '
                                                'Physical Adapters' = ($VMHostNetwork.Pnic.Device | Sort-Object) -join ', '
                                                'VMKernel Gateway' = $VMHostNetwork.IpRouteConfig.DefaultGateway
                                                'IPv6 Enabled' = Switch ($VMHostNetwork.IPv6Enabled) {
                                                    $true { 'Yes' }
                                                    $false { 'No' }
                                                }
                                                'VMKernel IPv6 Gateway' = $VMHostNetwork.IpRouteConfig.IpV6DefaultGateway
                                                'DNS Servers' = ($VMHostNetwork.DnsConfig.Address | Sort-Object) -join ', ' 
                                                'Host Name' = $VMHostNetwork.DnsConfig.HostName
                                                'Domain Name' = $VMHostNetwork.DnsConfig.DomainName 
                                                'Search Domain' = ($VMHostNetwork.DnsConfig.SearchDomain | Sort-Object) -join ', '
                                            }
                                            if ($Healthcheck.VMHost.IPv6Enabled) {
                                                $VMHostNetworkDetail | Where-Object { $_.'IPv6 Enabled' -eq 'No' } | Set-Style -Style Warning -Property 'IPv6 Enabled'
                                            }
                                            $VMHostNetworkDetail | Table -Name "$VMHost Network Configuration" -List -ColumnWidths 50, 50
                                            #endregion ESXi Host Network Configuration

                                            #region ESXi Host Physical Adapters
                                            Section -Style Heading5 'Physical Adapters' {
                                                Paragraph ("The following table details the physical network " +
                                                    "adapters for $VMHost.")
                                                BlankLine

                                                $PhysicalNetAdapters = $VMHost.ExtensionData.Config.Network.Pnic
                                                $VMHostPhysicalNetAdapter = foreach ($PhysicalNetAdapter in $PhysicalNetAdapters) {
                                                    [PSCustomObject]@{
                                                        'Device' = $PhysicalNetAdapter.Device
                                                        'Status' = Switch ($PhysicalNetAdapter.Linkspeed) {
                                                            $null { 'Disconnected' }
                                                            default { 'Connected' }
                                                        }
                                                        'vSwitch' = foreach ($vSwitch in $VMHost.ExtensionData.Config.Network.Vswitch) {
                                                            foreach ($pNic in $vSwitch.Pnic) {
                                                                if ($pNic -eq $PhysicalNetAdapter.Key) {
                                                                    $vSwitch.Name
                                                                }
                                                            }
                                                        }
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
                                                    $VMHostPhysicalNetAdapter | Sort-Object 'Device' | Table -List -Name "$VMHost Network Physical Adapters" -ColumnWidths 50, 50
                                                } else {
                                                    $VMHostPhysicalNetAdapter | Sort-Object 'Device' | Table -Name "$VMHost Network Physical Adapters"
                                                }
                                            }
                                            #endregion ESXi Host Physical Adapters
                            
                                            #region ESXi Host Cisco Discovery Protocol
                                            $VMHostNetworkAdapterCDP = $VMHost | Get-VMHostNetworkAdapterCDP | Where-Object { $_.Status -eq 'Connected' }
                                            if ($VMHostNetworkAdapterCDP) {
                                                Section -Style Heading5 'Cisco Discovery Protocol' {
                                                    if ($InfoLevel.VMHost -ge 4) {
                                                        $VMHostCDP = $VMHostNetworkAdapterCDP | Select-Object Device, Status, @{L = 'Hardware Platform'; E = { $_.HardwarePlatform } },
                                                        @{L = 'Software Version'; E = { $_.SoftwareVersion } }, @{L = 'Switch'; E = { $_.SwitchId } }, @{L = 'Management Address'; E = { $_.ManagementAddress } }, @{L = 'Switch ID'; E = { $_.SwitchId } }, Address, @{L = 'Port ID'; E = { $_.PortId } }, VLAN, MTU
                                                        $VMHostCDP | Sort-Object Device | Table -List -Name "$VMHost Network Adapter CDP Information" -ColumnWidths 50, 50
                                                    } else {
                                                        $VMHostCDP = $VMHostNetworkAdapterCDP | Select-Object Device, Status, @{L = 'Hardware Platform'; E = { $_.HardwarePlatform } },
                                                        @{L = 'Switch'; E = { $_.SwitchId } }, @{L = 'Management Address'; E = { $_.ManagementAddress } }, @{L = 'Port ID'; E = { $_.PortId } }
                                                        $VMHostCDP | Sort-Object Device | Table -Name "$VMHost Network Adapter CDP Information" #-ColumnWidths 20, 20, 20, 20, 20
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host Cisco Discovery Protocol

                                            #region ESXi Host VMkernel Adapaters
                                            Section -Style Heading5 'VMkernel Adapters' {
                                                Paragraph "The following table details the VMkernel adapters for $VMHost"
                                                BlankLine

                                                $VMkernelAdapters = $VMHost | Get-VMHostNetworkAdapter -VMKernel
                                                $VMHostVmkAdapters = foreach ($VMkernelAdapter in $VMkernelAdapters) {
                                                    [PSCustomObject]@{
                                                        'Device' = $VMkernelAdapter.DeviceName 
                                                        'Port Group' = $VMkernelAdapter.PortGroupName 
                                                        'MTU' = $VMkernelAdapter.Mtu 
                                                        'MAC Address' = $VMkernelAdapter.Mac
                                                        'IP Address' = $VMkernelAdapter.IP 
                                                        'Subnet Mask' = $VMkernelAdapter.SubnetMask 
                                                        'vMotion Traffic' = Switch ($VMkernelAdapter.vMotionEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'FT Logging' = Switch ($VMkernelAdapter.FaultToleranceLoggingEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Management Traffic' = Switch ($VMkernelAdapter.ManagementTrafficEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'vSAN Traffic' = Switch ($VMkernelAdapter.VsanTrafficEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                }
                                                $VMHostVmkAdapters | Sort-Object 'Device' | Table -Name "$VMHost VMkernel Adapters" -List -ColumnWidths 50, 50 
                                
                                                <#
                                                $VMkernelAdapters = $VMHost.ExtensionData.Config.Network.Vnic
                                                $VMHostVmkAdapters = foreach ($VMkernelAdapter in $VMkernelAdapters) {
                                                    [PSCustomObject]@{
                                                        'Device' = $VMkernelAdapter.Device
                                                        'Port Group' = Switch ($VMkernelAdapter.Spec.PortGroup) {
                                                            $null {$VMkernelAdapter.Spec.DistributedVirtualPort}
                                                            default {$VMkernelAdapter.Spec.PortGroup}
                                                        }
                                                        'TCP/IP stack' = Switch ($VMkernelAdapter.Spec.NetStackInstanceKey) {
                                                            'defaultTcpipStack' {'Default'}
                                                            'vmotion' {'vMotion'}
                                                            'vSphereProvisioning' {'Provisioning'}
                                                            default {$VMkernelAdapter.Spec.NetStackInstanceKey}
                                                        }
                                                        'MTU' = $VMkernelAdapter.Spec.Mtu
                                                        'MAC Address' = $VMkernelAdapter.Mac
                                                        'DHCP' = Switch ($VMkernelAdapter.Spec.IP.Dhcp) {
                                                            $true {'Enabled'}
                                                            $false {'Disabled'}
                                                        }
                                                        'IP Address' = $VMkernelAdapter.Spec.IP.IPAddress
                                                        'Subnet Mask' = $VMkernelAdapter.Spec.IP.SubnetMask
                                                    }
                                                }
                                                $VMHostVmkAdapters | Sort-Object 'Device' | Table -Name "$VMHost VMkernel Adapters" -List -ColumnWidths 50, 50 
                                                #>
                                            }
                                            #endregion ESXi Host VMkernel Adapaters

                                            #region ESXi Host Virtual Switches
                                            $VSSwitches = $VMHost | Get-VirtualSwitch -Standard | Sort-Object Name
                                            if ($VSSwitches) {
                                                #region ESXi Host Standard Virtual Switch Properties
                                                Section -Style Heading5 'Standard Virtual Switches' {
                                                    Paragraph ("The following sections detail the standard virtual " +
                                                        "switch configuration for $VMHost.")
                                                    BlankLine
                                                    $VSSwitchNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                                                    $VSSGeneral = foreach ($VSSwitchNicTeam in $VSSwitchNicTeaming) {
                                                        [PSCustomObject]@{
                                                            'Name' = $VSSwitchNicTeam.VirtualSwitch 
                                                            'MTU' = $VSSwitchNicTeam.VirtualSwitch.Mtu 
                                                            'Number of Ports' = $VSSwitchNicTeam.VirtualSwitch.NumPorts
                                                            'Number of Ports Available' = $VSSwitchNicTeam.VirtualSwitch.NumPortsAvailable 
                                                            'Load Balancing' = Switch ($VSSwitchNicTeam.LoadBalancingPolicy) {
                                                                'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                'LoadbalanceIP' { 'Route based on IP hash' }
                                                                'ExplicitFailover' { 'Explicit Failover' }
                                                            }
                                                            'Failover Detection' = Switch ($VSSwitchNicTeam.NetworkFailoverDetectionPolicy) {
                                                                'LinkStatus' { 'Link Status' }
                                                                'BeaconProbing' { 'Beacon Probing' }
                                                            } 
                                                            'Notify Switches' = Switch ($VSSwitchNicTeam.NotifySwitches) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'Failback' = Switch ($VSSwitchNicTeam.FailbackEnabled) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            } 
                                                            'Active NICs' = (($VSSwitchNicTeam.ActiveNic | Sort-Object) -join ', ') 
                                                            'Standby NICs' = (($VSSwitchNicTeam.StandbyNic | Sort-Object) -join ', ')
                                                            'Unused NICs' = (($VSSwitchNicTeam.UnusedNic | Sort-Object) -join ', ')
                                                        }
                                                    }
                                                    $VSSGeneral | Table -Name "$VMHost Standard Virtual Switches" -List -ColumnWidths 50, 50
                                                }
                                                #endregion ESXi Host Standard Virtual Switch Properties

                                                #region ESXi Host Virtual Switch Security Policy
                                                $VssSecurity = $VSSwitches | Get-SecurityPolicy
                                                if ($VssSecurity) {
                                                    Section -Style Heading5 'Virtual Switch Security Policy' {
                                                        $VssSecurity = foreach ($VssSec in $VssSecurity) {
                                                            [PSCustomObject]@{
                                                                'vSwitch' = $VssSec.VirtualSwitch 
                                                                'MAC Address Changes' = Switch ($VssSec.MacChanges) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                } 
                                                                'Forged Transmits' = Switch ($VssSec.ForgedTransmits) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                } 
                                                                'Promiscuous Mode' = Switch ($VssSec.AllowPromiscuous) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                            }
                                                        }
                                                        $VssSecurity | Sort-Object 'vSwitch' | Table -Name "$VMHost vSwitch Security Policy" #-ColumnWidths 25, 25, 25, 25
                                                    }
                                                }
                                                #endregion ESXi Host Virtual Switch Security Policy                  

                                                #region ESXi Host Virtual Switch NIC Teaming
                                                $VssPortgroupNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                                                if ($VssPortgroupNicTeaming) {
                                                    Section -Style Heading5 'Virtual Switch NIC Teaming' {
                                                        $VssPortgroupNicTeaming = foreach ($VssPortgroupNicTeam in $VssPortgroupNicTeaming) {
                                                            [PSCustomObject]@{
                                                                'vSwitch' = $VssPortgroupNicTeam.VirtualSwitch 
                                                                'Load Balancing' = Switch ($VssPortgroupNicTeam.LoadBalancingPolicy) {
                                                                    'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                    'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                    'LoadbalanceIP' { 'Route based on IP hash' }
                                                                    'ExplicitFailover' { 'Explicit Failover' }
                                                                }
                                                                'Failover Detection' = Switch ($VssPortgroupNicTeam.NetworkFailoverDetectionPolicy) {
                                                                    'LinkStatus' { 'Link Status' }
                                                                    'BeaconProbing' { 'Beacon Probing' }
                                                                } 
                                                                'Notify Switches' = Switch ($VssPortgroupNicTeam.NotifySwitches) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Failback' = Switch ($VssPortgroupNicTeam.FailbackEnabled) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Active NICs' = (($VssPortgroupNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine)
                                                                'Standby NICs' = (($VssPortgroupNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine)
                                                                'Unused NICs' = (($VssPortgroupNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine)
                                                            }
                                                        }
                                                        $VssPortgroupNicTeaming | Sort-Object 'vSwitch' | Table -Name "$VMHost vSwitch NIC Teaming"
                                                    }
                                                }
                                                #endregion ESXi Host Virtual Switch NIC Teaming                       
                
                                                #region ESXi Host Virtual Switch Port Groups
                                                $VssPortgroups = $VSSwitches | Get-VirtualPortGroup -Standard 
                                                if ($VssPortgroups) {
                                                    Section -Style Heading5 'Virtual Port Groups' {
                                                        $VssPortgroups = foreach ($VssPortgroup in $VssPortgroups) {
                                                            [PSCustomObject]@{
                                                                'vSwitch' = $VssPortgroup.VirtualSwitchName 
                                                                'Port Group' = $VssPortgroup.Name 
                                                                'VLAN ID' = $VssPortgroup.VLanId 
                                                                '# of VMs' = ($VssPortgroup | Get-VM).Count
                                                            }
                                                        }
                                                        $VssPortgroups | Sort-Object 'vSwitch', 'Port Group' | Table -Name "$VMHost vSwitch Port Group Information"
                                                    }
                                                }
                                                #endregion ESXi Host Virtual Switch Port Groups                
                
                                                #region ESXi Host Virtual Switch Port Group Security Poilicy
                                                $VssPortgroupSecurity = $VSSwitches | Get-VirtualPortGroup | Get-SecurityPolicy 
                                                if ($VssPortgroupSecurity) {
                                                    Section -Style Heading5 'Virtual Port Group Security Policy' {
                                                        $VssPortgroupSecurity = foreach ($VssPortgroupSec in $VssPortgroupSecurity) {
                                                            [PSCustomObject]@{
                                                                'vSwitch' = $VssPortgroupSec.virtualportgroup.virtualswitchname 
                                                                'Port Group' = $VssPortgroupSec.VirtualPortGroup 
                                                                'MAC Changes' = Switch ($VssPortgroupSec.MacChanges) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Forged Transmits' = Switch ($VssPortgroupSec.ForgedTransmits) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                } 
                                                                'Promiscuous Mode' = Switch ($VssPortgroupSec.AllowPromiscuous) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                            }
                                                        }
                                                        $VssPortgroupSecurity | Sort-Object 'vSwitch', 'Port Group' | Table -Name "$VMHost vSwitch Port Group Security Policy" 
                                                    }
                                                }
                                                #endregion ESXi Host Virtual Switch Port Group Security Poilicy                 

                                                #region ESXi Host Virtual Switch Port Group NIC Teaming
                                                $VssPortgroupNicTeaming = $VSSwitches | Get-VirtualPortGroup | Get-NicTeamingPolicy 
                                                if ($VssPortgroupNicTeaming) {
                                                    Section -Style Heading5 'Virtual Port Group NIC Teaming' {
                                                        $VssPortgroupNicTeaming = foreach ($VssPortgroupNicTeam in $VssPortgroupNicTeaming) {
                                                            [PSCustomObject]@{
                                                                'vSwitch' = $VssPortgroupNicTeam.virtualportgroup.virtualswitchname 
                                                                'Port Group' = $VssPortgroupNicTeam.VirtualPortGroup 
                                                                'Load Balancing' = Switch ($VssPortgroupNicTeam.LoadBalancingPolicy) {
                                                                    'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                    'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                    'LoadbalanceIP' { 'Route based on IP hash' }
                                                                    'ExplicitFailover' { 'Explicit Failover' }
                                                                }
                                                                'Failover Detection' = Switch ($VssPortgroupNicTeam.NetworkFailoverDetectionPolicy) {
                                                                    'LinkStatus' { 'Link Status' }
                                                                    'BeaconProbing' { 'Beacon Probing' }
                                                                }  
                                                                'Notify Switches' = Switch ($VssPortgroupNicTeam.NotifySwitches) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Failback' = Switch ($VssPortgroupNicTeam.FailbackEnabled) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                } 
                                                                'Active NICs' = (($VssPortgroupNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine)
                                                                'Standby NICs' = (($VssPortgroupNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine)
                                                                'Unused NICs' = (($VssPortgroupNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine)
                                                            }
                                                        }
                                                        $VssPortgroupNicTeaming | Sort-Object 'vSwitch', 'Port Group' | Table -Name "$VMHost vSwitch Port Group NIC Teaming"
                                                    }
                                                }
                                                #endregion ESXi Host Virtual Switch Port Group NIC Teaming                      
                                            }
                                            #endregion ESXi Host Standard Virtual Switches
                                        }                
                                        #endregion ESXi Host Network Section

                                        #region ESXi Host Security Section
                                        Section -Style Heading4 'Security' {
                                            Paragraph ("The following section provides information on the host " +
                                                "security configuration of $VMHost.")
                            
                                            #region ESXi Host Lockdown Mode
                                            if ($VMHost.ExtensionData.Config.LockdownMode -ne $null) {
                                                Section -Style Heading5 'Lockdown Mode' {
                                                    $LockdownMode = [PSCustomObject]@{
                                                        'Lockdown Mode' = Switch ($VMHost.ExtensionData.Config.LockdownMode) {
                                                            'lockdownDisabled' { 'Disabled' }
                                                            'lockdownNormal' { 'Enabled (Normal)' }
                                                            'lockdownStrict' { 'Enabled (Strict)' }
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
                                                        'Name' = $VMHostService.Label
                                                        'Daemon' = Switch ($VMHostService.Running) {
                                                            $true { 'Running' }
                                                            $false { 'Stopped' }
                                                        }
                                                        'Startup Policy' = Switch ($VMHostService.Policy) {
                                                            'automatic' { 'Start and stop with port usage' }
                                                            'on' { 'Start and stop with host' }
                                                            'off' { 'Start and stop manually' }
                                                        }
                                                    }
                                                }
                                                if ($Healthcheck.VMHost.Services) {
                                                    $Services | Where-Object { $_.'Name' -eq 'SSH' -and $_.Daemon -eq 'Running' } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { $_.'Name' -eq 'ESXi Shell' -and $_.Daemon -eq 'Running' } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { $_.'Name' -eq 'NTP Daemon' -and $_.Daemon -eq 'Stopped' } | Set-Style -Style Critical -Property 'Daemon'
                                                    $Services | Where-Object { $_.'Name' -eq 'NTP Daemon' -and $_.'Startup Policy' -ne 'Start and stop with host' } | Set-Style -Style Critical -Property 'Startup Policy'
                                                }
                                                $Services | Sort-Object Name | Table -Name "$VMHost Services" 
                                            }
                                            #endregion ESXi Host Services

                                            if ($InfoLevel.VMHost -ge 4) {
                                                #region ESXi Host Firewall
                                                $VMHostFirewallExceptions = $VMHost | Get-VMHostFirewallException
                                                if ($VMHostFirewallExceptions) {
                                                    Section -Style Heading5 'Firewall' {
                                                        $VMHostFirewall = foreach ($VMHostFirewallException in $VMHostFirewallExceptions) {
                                                            [PScustomObject]@{
                                                                'Name' = $VMHostFirewallException.Name
                                                                'Enabled' = Switch ($VMHostFirewallException.Enabled) {
                                                                    $true { 'Yes' }
                                                                    $false { 'No' }
                                                                }
                                                                'Incoming Ports' = $VMHostFirewallException.IncomingPorts
                                                                'Outgoing Ports' = $VMHostFirewallException.OutgoingPorts
                                                                'Protocols' = $VMHostFirewallException.Protocols
                                                                'Service Running' = Switch ($VMHostFirewallException.ServiceRunning) {
                                                                    $true { 'Yes' }
                                                                    $false { 'No' }
                                                                }
                                                            }
                                                        }
                                                        $VMHostFirewall | Sort-Object 'Name' | Table -Name "$VMHost Firewall Configuration" 
                                                    }
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
                                        }
                                        #endregion ESXi Host Security Section
                                            

                                        #region ESXi Host Virtual Machines Section
                                        if ($InfoLevel.VMHost -ge 4) {
                                            $VMHostVMs = $VMHost | Get-VM
                                            if ($VMHostVMs) {
                                                Section -Style Heading4 'Virtual Machines' {
                                                    Paragraph ("The following section provides information on the " +
                                                        "virtual machine settings for $VMHost.")
                                                    BlankLine
                                                    #region ESXi Host Virtual Machine Information
                                                    $VMHostVMs = foreach ($VMHostVM in $VMHostVMs) {
                                                        [PSCustomObject]@{
                                                            'Name' = $VMHostVM.Name
                                                            'Power State' = Switch ($VMHostVM.PowerState) {
                                                                'PoweredOn' { 'Powered On' }
                                                                'PoweredOff' { 'Powered Off' }
                                                            }
                                                            'CPUs' = $VMHostVM.NumCpu
                                                            'Cores per Socket' = $VMHostVM.CoresPerSocket
                                                            'Memory GB' = [math]::Round(($VMHostVM.memoryGB), 2)
                                                            'Provisioned GB' = [math]::Round(($VMHostVM.ProvisionedSpaceGB), 2) 
                                                            'Used GB' = [math]::Round(($VMHostVM.UsedSpaceGB), 2)
                                                            'HW Version' = $VMHostVM.HardwareVersion
                                                            'VM Tools Status' = Switch ($VMHostVM.ExtensionData.Guest.ToolsStatus) {
                                                                'toolsOld' { 'Tools Old' }
                                                                'toolsOk' { 'Tools OK' }
                                                                'toolsNotRunning' { 'Tools Not Running' }
                                                                'toolsNotInstalled' { 'Tools Not Installed' }
                                                            }
                                                        }
                                                    }
                                                    if ($Healthcheck.VM.VMToolsOK) {
                                                        $VMHostVMs | Where-Object { $_.'VM Tools Status' -eq 'Tools Not Installed' -or $_.'VM Tools Status' -eq 'Tools Old' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                                    }
                                                    if ($Healthcheck.VM.PoweredOn) {
                                                        $VMHostVMs | Where-Object { $_.'Power State' -ne 'Powered On' } | Set-Style -Style Warning -Property 'Power State'
                                                    }
                                                    $VMHostVMs | Sort-Object 'Name' | Table -Name "$VMHost Virtual Machines"
                                                    #endregion ESXi Host Virtual Machine Information

                                                    #region ESXi Host VM Startup/Shutdown Information
                                                    $VMStartPolicy = $VMHost | Get-VMStartPolicy | Where-Object { $_.StartAction -ne 'None' }
                                                    if ($VMStartPolicy) {
                                                        Section -Style Heading5 'VM Startup/Shutdown' {
                                                            $VMStartPolicies = foreach ($VMStartPol in $VMStartPolicy) {
                                                                [PSCustomObject]@{
                                                                    'Start Order' = $VMStartPol.StartOrder
                                                                    'VM Name' = $VMStartPol.VirtualMachineName
                                                                    'Startup' = Switch ($VMStartPol.StartAction) {
                                                                        'PowerOn' { 'Enabled' }
                                                                        'None' { 'Disabled' }
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
                                                    }
                                                    #endregion ESXi Host VM Startup/Shutdown Information
                                                }
                                            }
                                        }
                                        #endregion ESXi Host Virtual Machines Section
                                    }
                                    #endregion VMHost Section
                                } #end foreach VMhost Detailed Information loop
                            }
                            #endregion ESXi Host Detailed Information
                        }
                        #endregion Hosts Section
                    }
                }
                #endregion ESXi VMHost Section 

                #region Distributed Switch Section
                if ($InfoLevel.Network -ge 1) {
                    # Create Distributed Virtual Switch Section if they exist
                    $VDSwitches = Get-VDSwitch -Server $vCenter
                    if ($VDSwitches) {
                        Section -Style Heading2 'Distributed Virtual Switches' {
                            Paragraph ("The following section provides information on the Distributed Virtual " +
                                "Switches managed by vCenter Server $vCenterServerName.")

                            #region Distributed Virtual Switch Informative Information
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
                                $VDSInfo | Table -Name 'Distributed Virtual Switch Information'
                            }    
                            #endregion Distributed Virtual Switch Informative Information

                            if ($InfoLevel.Network -ge 3) {
                                #region Distributed Virtual Switch Detailed Information
                                ## TODO: LACP, NetFlow, NIOC
                                foreach ($VDS in ($VDSwitches)) {
                                    Section -Style Heading3 $VDS {
                                        #region Distributed Virtual Switch General Properties  
                                        Section -Style Heading4 'General Properties' {
                                            $VDSwitchDetail = [PSCustomObject]@{
                                                'Name' = $VDS.Name
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

                                            if ($InfoLevel.Network -ge 4) {
                                                $VDSwitchDetail | ForEach-Object {
                                                    $VDSwitchHosts = $VDS | Get-VMHost | Sort-Object Name
                                                    Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($VDSwitchHosts.Name -join ', ')
                                                    $VDSwitchVMs = $VDS | Get-VM | Sort-Object 
                                                    Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($VDSwitchVMs.Name -join ', ')
                                                }
                                            }
                                            $VDSwitchDetail | Table -Name "$VDS General Properties" -List -ColumnWidths 50, 50 
                                        }
                                        #endregion Distributed Virtual Switch General Properties

                                        #region Distributed Virtual Switch Uplinks
                                        $VdsUplinks = $VDS | Get-VDPortgroup | Where-Object { $_.IsUplink -eq $true } | Get-VDPort
                                        if ($VdsUplinks) {
                                            Section -Style Heading4 'Uplinks' {
                                                $VdsUplinkDetail = foreach ($VdsUplink in $VdsUplinks) {
                                                    [PSCustomObject]@{
                                                        'VDSwitch' = $VdsUplink.Switch
                                                        'VM Host' = $VdsUplink.ProxyHost
                                                        'Uplink Name' = $VdsUplink.Name
                                                        'Physical Network Adapter' = $VdsUplink.ConnectedEntity
                                                        'Uplink Port Group' = $VdsUplink.Portgroup
                                                    }
                                                }
                                                $VdsUplinkDetail | Sort-Object 'VDSwitch', 'VM Host', 'Uplink Name' | Table -Name "$VDS Uplinks"
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Uplinks               
                    
                                        #region Distributed Virtual Switch Security
                                        $VDSecurityPolicy = $VDS | Get-VDSecurityPolicy
                                        if ($VDSecurityPolicy) {
                                            Section -Style Heading4 'Security' {
                                                $VDSecurityPolicyDetail = [PSCustomObject]@{
                                                    'VDSwitch' = $VDSecurityPolicy.VDSwitch
                                                    'Allow Promiscuous' = Switch ($VDSecurityPolicy.AllowPromiscuous) {
                                                        $true { 'Enabled' }
                                                        $false { 'Disabled' }
                                                    }
                                                    'Forged Transmits' = Switch ($VDSecurityPolicy.ForgedTransmits) {
                                                        $true { 'Enabled' }
                                                        $false { 'Disabled' }
                                                    }
                                                    'MAC Address Changes' = Switch ($VDSecurityPolicy.MacChanges) {
                                                        $true { 'Enabled' }
                                                        $false { 'Disabled' }
                                                    }
                                                }
                                                $VDSecurityPolicyDetail | Table -Name "$VDS Security" 
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Security

                                        #region Distributed Virtual Switch Traffic Shaping
                                        $VDSTrafficShaping = $VDS | Get-VDTrafficShapingPolicy -Direction Out
                                        if ($VDSTrafficShaping) {
                                            Section -Style Heading4 'Traffic Shaping' {
                                                [Array]$VDSTrafficShaping += $VDS | Get-VDTrafficShapingPolicy -Direction In
                                                $VDSTrafficShapingDetail = foreach ($VDSTrafficShape in $VDSTrafficShaping) {
                                                    [PSCustomObject]@{
                                                        'VDSwitch' = $VDSTrafficShape.VDSwitch
                                                        'Direction' = $VDSTrafficShape.Direction
                                                        'Enabled' = Switch ($VDSTrafficShape.Enabled) {
                                                            $true { 'Yes' }
                                                            $false { 'No' }
                                                        }
                                                        'Average Bandwidth (kbit/s)' = $VDSTrafficShape.AverageBandwidth
                                                        'Peak Bandwidth (kbit/s)' = $VDSTrafficShape.PeakBandwidth
                                                        'Burst Size (KB)' = $VDSTrafficShape.BurstSize
                                                    }
                                                }
                                                $VDSTrafficShapingDetail | Sort-Object 'Direction' | Table -Name "$VDS Traffic Shaping"
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Traffic Shaping

                                        #region Distributed Virtual Switch Port Groups
                                        $VDSPortgroups = $VDS | Get-VDPortgroup
                                        if ($VDSPortgroups) {
                                            Section -Style Heading4 'Port Groups' {
                                                $VDSPortgroupDetail = foreach ($VDSPortgroup in $VDSPortgroups) {
                                                    [PSCustomObject]@{
                                                        'VDSwitch' = $VDSPortgroup.VDSwitch
                                                        'Port Group' = $VDSPortgroup.Name
                                                        'Datacenter' = $VDSPortgroup.Datacenter
                                                        'VLAN Configuration' = $VDSPortgroup.VlanConfiguration
                                                        'Port Binding' = $VDSPortgroup.PortBinding
                                                        '# of Ports' = $VDSPortgroup.NumPorts
                                                    }
                                                }
                                                $VDSPortgroupDetail | Sort-Object 'VDSwitch', 'Port Group' | Table -Name "$VDS Port Group Information" 
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Port Groups

                                        #region Distributed Virtual Switch Port Group Security
                                        $VDSPortgroupSecurity = $VDS | Get-VDPortgroup | Get-VDSecurityPolicy
                                        if ($VDSPortgroupSecurity) {
                                            Section -Style Heading5 "Port Group Security" {
                                                $VDSecurityPolicies = foreach ($VDSecurityPolicy in $VDSPortgroupSecurity) {
                                                    [PSCustomObject]@{
                                                        'VDSwitch' = $VDS.Name
                                                        'Port Group' = $VDSecurityPolicy.VDPortgroup
                                                        'Allow Promiscuous' = Switch ($VDSecurityPolicy.AllowPromiscuous) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Forged Transmits' = Switch ($VDSecurityPolicy.ForgedTransmits) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'MAC Address Changes' = Switch ($VDSecurityPolicy.MacChanges) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                }
                                                $VDSecurityPolicies | Sort-Object 'VDSwitch', 'Port Group' | Table -Name "$VDS Port Group Security"
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Port Group Security
    
                                        #region Distributed Virtual Switch Port Group NIC Teaming
                                        $VDUplinkTeamingPolicy = $VDS | Get-VDPortgroup | Get-VDUplinkTeamingPolicy
                                        if ($VDUplinkTeamingPolicy) {
                                            Section -Style Heading5 "Port Group NIC Teaming" {
                                                $VDSPortgroupNICTeaming = foreach ($VDUplink in $VDUplinkTeamingPolicy) {
                                                    [PSCustomObject]@{
                                                        'VDSwitch' = $VDS.Name
                                                        'Port Group' = $VDUplink.VDPortgroup
                                                        'Load Balancing' = Switch ($VDUplink.LoadBalancingPolicy) {
                                                            'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                            'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                            'LoadbalanceIP' { 'Route based on IP hash' }
                                                            'ExplicitFailover' { 'Explicit Failover' }
                                                        }
                                                        'Failover Detection' = Switch ($VDUplink.FailoverDetectionPolicy) {
                                                            'LinkStatus' { 'Link Status' }
                                                            'BeaconProbing' { 'Beacon Probing' }
                                                        }
                                                        'Notify Switches' = Switch ($VDUplink.NotifySwitches) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Failback Enabled' = Switch ($VDUplink.EnableFailback) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Active Uplinks' = $VDUplink.ActiveUplinkPort -join [Environment]::NewLine
                                                        'Standby Uplinks' = $VDUplink.StandbyUplinkPort -join [Environment]::NewLine
                                                        'Unused Uplinks' = $VDUplink.UnusedUplinkPort -join [Environment]::NewLine
                                                    }
                                                }
                                                $VDSPortgroupNICTeaming | Sort-Object 'VDSwitch', 'Port Group' | Table -Name "$VDS Port Group NIC Teaming" #-ColumnWidths 12,11,11,11,11,11,11,11,11
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Port Group NIC Teaming

                                        #region Distributed Virtual Switch Private VLANs
                                        $VDSwitchPrivateVLANs = $VDS | Get-VDSwitchPrivateVLAN
                                        if ($VDSwitchPrivateVLANs) {
                                            Section -Style Heading4 'Private VLANs' {
                                                $VDSPvlan = foreach ($VDSwitchPrivateVLAN in $VDSwitchPrivateVLANs) {
                                                    [PSCustomObject]@{
                                                        'Primary VLAN ID' = $VDSwitchPrivateVLAN.PrimaryVlanId
                                                        'Private VLAN Type' = $VDSwitchPrivateVLAN.PrivateVlanType
                                                        'Secondary VLAN ID' = $VDSwitchPrivateVLAN.SecondaryVlanId
                                                    }
                                                }
                                                $VDSPvlan | Sort-Object 'Primary VLAN ID', 'Secondary VLAN ID' | Table -Name "$VDS Private VLANs"
                                            }
                                        }
                                        #endregion Distributed Virtual Switch Private VLANs            
                                    }
                                }
                                #endregion Distributed Virtual Switch Detailed Information
                            }
                        }
                    }
                }
                #endregion Distributed Switch Section

                #region vSAN Section
                if (($InfoLevel.Vsan -ge 1) -and ($vCenter.Version -gt 6)) {
                    $VsanClusters = Get-VsanClusterConfiguration -Server $vCenter | Where-Object { $_.vsanenabled -eq $true } | Sort-Object Name
                    if ($VsanClusters) {
                        Section -Style Heading2 'vSAN' {
                            Paragraph ("The following section provides information on the vSAN managed " +
                                "by vCenter Server $vCenterServerName.")
        
                            #region vSAN Cluster Informative Information
                            if ($InfoLevel.Vsan -eq 2) {
                                BlankLine
                                $VsanClusterInfo = foreach ($VsanCluster in $VsanClusters) {
                                    [PSCustomObject]@{
                                        'Name' = $VsanCluster.Name
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
                            if ($InfoLevel.Vsan -ge 3) {
                                foreach ($VsanCluster in $VsanClusters) {
                                    Section -Style Heading3 $VsanCluster.Name {
                                        $VsanDiskGroup = Get-VsanDiskGroup -Cluster $VsanCluster.Cluster
                                        $NumVsanDiskGroup = $VsanDiskGroup.Count
                                        $VsanDisk = Get-vSanDisk -VsanDiskGroup $VsanDiskGroup
                                        $VsanDiskFormat = $VsanDisk.DiskFormatVersion | Select-Object -First 1 -Unique
                                        $NumVsanSsd = ($VsanDisk | Where-Object { $_.IsSsd -eq $true }).Count
                                        $NumVsanHdd = ($VsanDisk | Where-Object { $_.IsSsd -eq $false }).Count
                                        if ($NumVsanHdd -gt 0) {
                                            $VsanClusterType = "Hybrid"
                                        } else {
                                            $VsanClusterType = "All-Flash"
                                        }
                                        $VsanClusterDetail = [PSCustomObject]@{
                                            'Name' = $VsanCluster.Name
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
                                        #endregion vSAN Cluster Detailed Information

                                        #region vSAN Cluster Adv Detailed Information
                                        if ($InfoLevel.Vsan -ge 4) {
                                            Add-Member -InputObject $VsanClusterDetail -MemberType NoteProperty -Name 'Hosts' -Value (($VsanDiskGroup.VMHost | Sort-Object Name) -join ', ')
                                        }
                                        #endregion vSAN Cluster Adv Detailed Information
                                        $VsanClusterDetail | Table -Name "$($VsanCluster.Name) vSAN Configuration" -List -ColumnWidths 50, 50
                                    }  
                                }      
                            }
                        }
                    }
                }
                #endregion vSAN Section

                #region Datastore Section
                if ($InfoLevel.Datastore -ge 1) {
                    $Datastores = Get-Datastore -Server $vCenter | Where-Object { $_.State -eq 'Available' } | Sort-Object Name
                    if ($Datastores) {
                        Section -Style Heading2 'Datastores' {
                            Paragraph ("The following section provides information on datastores managed " +
                                "by vCenter Server $vCenterServerName.")

                            #region Datastore Infomative Information
                            if ($InfoLevel.Datastore -eq 2) {
                                BlankLine
                                $DatastoreInfo = foreach ($Datastore in $Datastores) {
                                    [PSCustomObject]@{
                                        'Name' = $Datastore.Name
                                        'Type' = $Datastore.Type
                                        '# of Hosts' = $Datastore.ExtensionData.Host.Count
                                        '# of VMs' = $Datastore.ExtensionData.VM.Count
                                        'Total Capacity GB' = [math]::Round($Datastore.CapacityGB, 2)
                                        'Used Capacity GB' = [math]::Round(
                                            (($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)), 2
                                        )
                                        'Free Space GB' = [math]::Round($Datastore.FreeSpaceGB, 2)
                                        '% Used' = [math]::Round(
                                            (100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2
                                        )
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
                                    Section -Style Heading3 $Datastore.Name {                                
                                        $DatastoreDetail = [PSCustomObject]@{
                                            'Name' = $Datastore.Name
                                            'ID' = $Datastore.Id
                                            'Datacenter' = $Datastore.Datacenter
                                            'Type' = $Datastore.Type
                                            'Version' = $Datastore.FileSystemVersion
                                            'State' = $Datastore.State
                                            'Number of Hosts' = $Datastore.ExtensionData.Host.Count
                                            'Number of VMs' = $Datastore.ExtensionData.VM.Count
                                            'Storage I/O Control' = Switch ($Datastore.StorageIOControlEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Congestion Threshold' = "$($Datastore.CongestionThresholdMillisecond) ms"
                                            'Total Capacity' = "$([math]::Round($Datastore.CapacityGB, 2)) GB"
                                            'Used Capacity' = "$([math]::Round((($Datastore.CapacityGB) - 
                                                            ($Datastore.FreeSpaceGB)), 2)) GB"
                                            'Free Space' = "$([math]::Round($Datastore.FreeSpaceGB, 2)) GB"
                                            '% Used' = [math]::Round(
                                                (100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2
                                            )
                                        }
                                        if ($Healthcheck.Datastore.CapacityUtilization) {
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 75 -and 
                                                $_.'% Used' -lt 90 } | Set-Style -Style Warning -Property '% Used'
                                        }
                        
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
                                        $DatastoreDetail | Sort-Object Datacenter, Name | Table -List -Name 'Datastore Specifications' -ColumnWidths 50, 50

                                        # Get VMFS volumes. Ignore local SCSILuns.
                                        if (($Datastore.Type -eq 'VMFS') -and
                                            ($Datastore.ExtensionData.Info.Vmfs.Local -eq $false)) {
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
                                                    }
                                                }
                                                $ScsiLuns | Sort-Object Host | Table -Name 'SCSI LUN Information'
                                            }
                                        }
                                    }
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
                        Section -Style Heading2 'Datastore Clusters' {
                            Paragraph ("The following section provides information on datastore clusters " +
                                "managed by vCenter Server $vCenterServerName.")

                            #region Datastore Cluster Informative Information
                            if ($InfoLevel.DSCluster -eq 2) {
                                BlankLine
                                $DSClusterInfo = foreach ($DSCluster in $DSClusters) {
                                    [PSCustomObject]@{
                                        'Name' = $DSCluster.Name
                                        'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                            'FullyAutomated' { 'Fully Automated' }
                                            'Manual' { 'Manual' }
                                        }
                                        'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                        'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                        'Capacity GB' = [math]::Round($DSCluster.CapacityGB, 2)
                                        'FreeSpace GB' = [math]::Round($DSCluster.FreeSpaceGB, 2)
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

                            if ($InfoLevel.DSCluster -ge 3) {
                                #region Datastore Cluster Detailed Information
                                foreach ($DSCluster in $DSClusters) {
                                    ## TODO: Space Load Balance Config, IO Load Balance Config, Rules
                                    Section -Style Heading3 $DSCluster.Name {
                                        Paragraph ("The following table details the configuration " +
                                            "for datastore cluster $DSCluster.")
                                        BlankLine

                                        $DSClusterDetail = [PSCustomObject]@{
                                            'Name' = $DSCluster.Name
                                            'ID' = $DSCluster.Id
                                            'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                                'FullyAutomated' { 'Fully Automated' }
                                                'Manual' { 'Manual' }
                                            }
                                            'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                            'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                            'Capacity' = "$([math]::Round($DSCluster.CapacityGB, 2)) GB"
                                            'FreeSpace' = "$([math]::Round($DSCluster.FreeSpaceGB, 2)) GB"
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
                                #endregion Datastore Cluster Detailed Information
                            }
                        }
                    }
                }
                #endregion Datastore Clusters     

                #region Virtual Machine Section
                if ($InfoLevel.VM -ge 1) {
                    if ($VMs) {
                        Section -Style Heading2 'Virtual Machines' {
                            Paragraph ("The following section provides information on Virtual Machines " +
                                "managed by vCenter Server $vCenterServerName.")

                            #region Virtual Machine Informative Information
                            if ($InfoLevel.VM -eq 2) {
                                BlankLine
                                $VMInfo = foreach ($VM in $VMs) {
                                    [PSCustomObject]@{
                                        'Name' = $VM.Name
                                        'Power State' = Switch ($VM.PowerState) {
                                            'PoweredOn' { 'Powered On' }
                                            'PoweredOff' { 'Powered Off' }
                                        }
                                        'vCPUs' = $VM.NumCpu
                                        'Cores per Socket' = $VM.CoresPerSocket
                                        'Memory GB' = [math]::Round(($VM.MemoryGB), 2)
                                        'Provisioned GB' = [math]::Round(($VM.ProvisionedSpaceGB), 2)
                                        'Used GB' = [math]::Round(($VM.UsedSpaceGB), 2)
                                        'HW Version' = $VM.HardwareVersion
                                        'VM Tools Status' = Switch ($VM.ExtensionData.Guest.ToolsStatus) {
                                            'toolsOld' { 'Tools Old' }
                                            'toolsOk' { 'Tools OK' }
                                            'toolsNotRunning' { 'Tools Not Running' }
                                            'toolsNotInstalled' { 'Tools Not Installed' }
                                        }         
                                    }
                                }
                                if ($Healthcheck.VM.VMToolsOK) {
                                    $VMInfo | Where-Object { $_.'VM Tools Status' -ne 'Tools OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                }
                                if ($Healthcheck.VM.PoweredOn) {
                                    $VMInfo | Where-Object { $_.'Power State' -ne 'Powered On' } | Set-Style -Style Warning -Property 'Power State'
                                }
                                $VMInfo | Table -Name 'VM Informative Information'
                            }
                            #endregion Virtual Machine Informative Information

                            #region Virtual Machine Detailed Information
                            if ($InfoLevel.VM -ge 3) {
                                ## TODO: More VM Details to Add
                                $VMSpbmConfig = Get-SpbmEntityConfiguration -VM ($VMs) | Where-Object { $_.StoragePolicy -ne $null }
                                foreach ($VM in $VMs) {
                                    Section -Style Heading3 $VM.name {
                                        $VMUptime = Get-Uptime -VM $VM
                                        $VMSpbmPolicy = $VMSpbmConfig | Where-Object { $_.entity -eq $vm }
                                        $VMDetail = [PSCustomObject]@{
                                            'Name' = $VM.Name
                                            'ID' = $VM.Id 
                                            'Operating System' = $VM.ExtensionData.Summary.Config.GuestFullName
                                            'Hardware Version' = $VM.HardwareVersion
                                            'Power State' = Switch ($VM.PowerState) {
                                                'PoweredOn' { 'Powered On' }
                                                'PoweredOff' { 'Powered Off' }
                                            }
                                            'VM Tools Status' = Switch ($VM.ExtensionData.Guest.ToolsStatus) {
                                                'toolsOld' { 'Tools Old' }
                                                'toolsOk' { 'Tools OK' }
                                                'toolsNotRunning' { 'Tools Not Running' }
                                                'toolsNotInstalled' { 'Tools Not Installed' }
                                            }
                                            'Fault Tolerance State' = Switch ($VM.ExtensionData.Runtime.FaultToleranceState) {
                                                'notConfigured' { 'Not Configured' }
                                                'needsSecondary' { 'Needs Secondary' }
                                                'running' { 'Running' }
                                                'disabled' { 'Disabled' }
                                                'starting' { 'Starting' }
                                                'enabled' { 'Enabled' }
                                            } 
                                            'Host' = $VM.VMHost.Name
                                            'Parent' = $VM.VMHost.Parent.Name
                                            'Parent Folder' = $VM.Folder.Name
                                            'Parent Resource Pool' = $VM.ResourcePool.Name
                                            'vCPUs' = $VM.NumCpu
                                            'Cores per Socket' = $VM.CoresPerSocket
                                            'CPU Resources' = "$($VM.VMResourceConfiguration.CpuSharesLevel) / $($VM.VMResourceConfiguration.NumCpuShares)"
                                            'CPU Reservation' = $VM.VMResourceConfiguration.CpuReservationMhz
                                            'CPU Limit' = "$($VM.VMResourceConfiguration.CpuReservationMhz) MHz" 
                                            'CPU Hot Add' = Switch ($VM.ExtensionData.Config.CpuHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'CPU Hot Remove' = Switch ($VM.ExtensionData.Config.CpuHotRemoveEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            } 
                                            'Memory Allocation' = "$([math]::Round(($VM.memoryGB), 2)) GB" 
                                            'Memory Resources' = "$($VM.VMResourceConfiguration.MemSharesLevel) / $($VM.VMResourceConfiguration.NumMemShares)"
                                            'Memory Hot Add' = Switch ($VM.ExtensionData.Config.MemoryHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'vDisks' = $VM.ExtensionData.Summary.Config.NumVirtualDisks
                                            'Used Space' = "$([math]::Round(($VM.UsedSpaceGB), 2)) GB"
                                            'Provisioned Space' = "$([math]::Round(($VM.ProvisionedSpaceGB), 2)) GB"
                                            'Changed Block Tracking' = Switch ($VM.ExtensionData.Config.ChangeTrackingEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Storage Based Policy' = Switch ($VMSpbmPolicy.StoragePolicy.Name) {
                                                $null { 'Not Applicable' }
                                                default { $VMSpbmPolicy.StoragePolicy.Name }
                                            }
                                            'Storage Based Policy Compliance' = Switch ($VMSpbmPolicy.ComplianceStatus) {
                                                $null { 'Not Applicable' }
                                                'compliant' { 'Compliant' } 
                                                'nonCompliant' { 'Non Compliant' }
                                                'unknown' { 'Unknown' }
                                            }
                                            'vNICs' = $VM.ExtensionData.Summary.Config.NumEthernetCards
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $VMDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        if ($VM.Notes) {
                                            Add-Member @MemberProps -Name 'Notes' -Value $VM.Notes  
                                        }
                                        if ($VM.PowerState -eq 'PoweredOn') {
                                            Add-Member @MemberProps -Name 'Boot Time' -Value $VM.ExtensionData.Runtime.BootTime
                                            Add-Member @MemberProps -Name 'Uptime Days' -Value $VMUptime.UptimeDays
                                        }  
                                        if ($Healthcheck.VM.VMToolsOK) {
                                            $VMDetail | Where-Object { $_.'VM Tools Status' -ne 'Tools OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                        }
                                        if ($Healthcheck.VM.PoweredOn) {
                                            $VMDetail | Where-Object { $_.'Power State' -ne 'Powered On' } | Set-Style -Style Warning -Property 'Power State'
                                        }
                                        if ($Healthcheck.VM.CpuHotAddEnabled) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Add'
                                        }
                                        if ($Healthcheck.VM.CpuHotRemoveEnabled) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Remove' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Remove'
                                        } 
                                        if ($Healthcheck.VM.MemoryHotAddEnabled) {
                                            $VMDetail | Where-Object { $_.'Memory Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'Memory Hot Add'
                                        } 
                                        if ($Healthcheck.VM.ChangeBlockTrackingEnabled) {
                                            $VMDetail | Where-Object { $_.'Changed Block Tracking' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Changed Block Tracking'
                                        } 
                                        if ($Healthcheck.VM.SpbmPolicyCompliance) {
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Unknown' } | Set-Style -Style Warning -Property 'Storage Based Policy Compliance'
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Non Compliant' } | Set-Style -Style Critical -Property 'Storage Based Policy Compliance'
                                        } 
                                        $VMDetail | Table -Name 'VM Detailed Information' -List -ColumnWidths 50, 50

                                        $VMSnapshots = $VM | Get-Snapshot
                                        if ($VMSnapshots -and $Options.ShowVMSnapshots) {
                                            Section -Style Heading4 "Snapshots" {
                                                $VMSnapshots = foreach ($VMSnapshot in $VMSnapshots) {
                                                    [PSCustomObject]@{
                                                        'Snapshot Name' = $VMSnapshot.Name
                                                        'Description' = $VMSnapshot.Description
                                                        'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.Created).Days
                                                    } 
                                                }
                                                if ($Healthcheck.VM.VMSnapshots) {
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning 
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                                }
                                                $VMSnapshots | Table -Name "$VM Snapshots"
                                            }
                                        }
                                    }
                                } 
                            }
                            #endregion Virtual Machine Detailed Information

                            #region VM Snapshot Information
                            if ($InfoLevel.VM -eq 2) {
                                $VMSnapshots = $VMs | Get-Snapshot 
                                if ($VMSnapshots -and $Options.ShowVMSnapshots) {
                                    Section -Style Heading3 'Snapshots' {
                                        $VMSnapshotInfo = foreach ($VMSnapshot in $VMSnapshots) {
                                            [PSCustomObject]@{
                                                'Virtual Machine' = $VMSnapshot.VM
                                                'Snapshot Name' = $VMSnapshot.Name
                                                'Description' = $VMSnapshot.Description
                                                'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.Created).Days
                                            } 
                                        }
                                        if ($Healthcheck.VM.VMSnapshots) {
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning 
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                        }
                                        $VMSnapshotInfo | Table -Name 'VM Snapshot Information'
                                    }
                                }
                            }
                            #endregion VM Snapshot Information
                        }
                    }
                }
                #endregion Virtual Machine Section

                #region VMware Update Manager Section
                if ($InfoLevel.VUM -ge 1 -and $VumServer.Name) {
                    $VUMBaselines = Get-PatchBaseline -Server $vCenter
                    if ($VUMBaselines) {
                        Section -Style Heading2 'VMware Update Manager' {
                            Paragraph ("The following section provides information on VMware Update Manager " +
                                "managed by vCenter Server $vCenterServerName.")
            
                            #region VUM Baseline Detailed Information
                            if ($InfoLevel.VUM -ge 2) {
                                Section -Style Heading3 'Baselines' {
                                    $VUMBaselineInfo = foreach ($VUMBaseline in $VUMBaselines) {
                                        [PSCustomObject]@{
                                            'Name' = $VUMBaseline.Name
                                            'Description' = $VUMBaseline.Description
                                            'Type' = $VUMBaseline.BaselineType
                                            'Target Type' = $VUMBaseline.TargetType
                                            'Last Update Time' = $VUMBaseline.LastUpdateTime
                                            '# of Patches' = $VUMBaseline.CurrentPatches.Count
                                        }
                                    }
                                    $VUMBaselineInfo | Sort-Object Name | Table -Name 'VMware Update Manager Baseline Information'
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
                                            'Name' = $VUMPatch.Name
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

        #region Variable cleanup
        Clear-Variable -Name vCenter
        #endregion Variable cleanup

    } # End of Foreach $VIServer
    #endregion Script Body
} # End Invoke-AsBuiltReport.VMware.vSphere function