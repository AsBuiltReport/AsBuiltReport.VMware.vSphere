function Invoke-AsBuiltReport.VMware.vSphere {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware vSphere infrastucture in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.2.2
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        Jake Rutski (@jrutski) - VMware vSphere Documentation Script Concept
    .LINK
        https://github.com/tpcarman/As-Built-Report
        https://github.com/iainbrighton/PScribo
    #>

    param (
        [string[]] $Target,
        [pscredential] $Credential,
		$StyleName
    )

    $InfoLevel = $Global:ReportConfig.InfoLevel

    # If custom style not set, use default style
    if (!$StyleName) {
        & "$PSScriptRoot\..\Assets\DefaultStyle.ps1"
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
                300 {$xInterval = '5 Minutes'}
                1800 {$xInterval = '30 Minutes'}
                7200 {$xInterval = '2 Hours'}
                86400 {$xInterval = '1 Day'}
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

    function Get-vCenterLicense {
        $LicenseObject = @()
        $ServiceInstance = Get-View ServiceInstance -Server $vCenter
        $LicenseManager = Get-View $ServiceInstance.Content.LicenseManager
        foreach ($License in $LicenseManager.Licenses) {
            if ($Options.ShowLicenses) {
                $LicenseKey = $License.LicenseKey
            } else { 
                $LicenseKey = "*****-*****-*****" + $License.LicenseKey.Substring(17)
            }
            $Object = [pscustomobject]@{                               
                Key = $LicenseKey
                Type = $License.Name
                Total = $License.Total
                Used = $License.Used                     
            }
            $LicenseObject += $Object
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
            [PSObject[]]$VMHost    
        )    

        begin {
        
            $CDPObject = @()
        }

        process {

            try {
                foreach ($ESXiHost in $VMHost) {

                    if ($ESXiHost.GetType().Name -eq 'string') {
                    
                        try {
                            $ESXiHost = Get-VMHost $ESXiHost -ErrorAction Stop
                        } catch [Exception] {
                            Write-Warning "VMHost $ESXiHost does not exist"
                        }
                    }
                    
                    elseif ($ESXiHost -isnot [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]) {
                        Write-Warning 'You did not pass a string or a VMHost object'
                        Return
                    }

                    $ConfigManagerView = Get-View $ESXiHost.ExtensionData.ConfigManager.NetworkSystem
                    $PNICs = $ConfigManagerView.NetworkInfo.Pnic

                    foreach ($PNIC in $PNICs) {

                        $PhysicalNicHintInfo = $ConfigManagerView.QueryNetworkHint($PNIC.Device)

                        if ($PhysicalNicHintInfo.ConnectedSwitchPort) {

                            $Connected = $true
                        } else {
                            $Connected = $false
                        }

                        $Object = [pscustomobject]@{                        
                        
                            VMHost = $ESXiHost.Name
                            NIC = $PNIC.Device
                            Connected = $Connected
                            Switch = $PhysicalNicHintInfo.ConnectedSwitchPort.DevId
                            HardwarePlatform = $PhysicalNicHintInfo.ConnectedSwitchPort.HardwarePlatform
                            SoftwareVersion = $PhysicalNicHintInfo.ConnectedSwitchPort.SoftwareVersion
                            MangementAddress = $PhysicalNicHintInfo.ConnectedSwitchPort.MgmtAddr
                            PortId = $PhysicalNicHintInfo.ConnectedSwitchPort.PortId

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
        Get-VMHost $VMhost | Sort-Object Name | ForEach-Object {
            $esxcli = Get-EsxCli -VMHost $_.name -V2 -Server $vCenter
            $thisUUID = $esxcli.system.uuid.get.Invoke()
            $decDate = [Convert]::ToInt32($thisUUID.Split("-")[0], 16)
            $installDate = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($decDate))
            [pscustomobject][ordered]@{
                Name = "$($_.name)"
                InstallDate = $installDate
            } # end custom object
        } # end host loop
    }

    function Get-VMHostUptime {
        [CmdletBinding()] 
        Param (
            [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)][Alias('Name')][string]$VMHosts,
            [string]$Cluster
        )
        Process {
            If ($VMHosts) {
                foreach ($VMHost in $VMHosts) {Get-View -ViewType hostsystem -Property name, runtime.boottime -Filter @{'name' = "$VMHost"} | Select-Object Name, @{L = 'UptimeDays'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalDays), 1)}}, @{L = 'UptimeHours'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalHours), 1)}}, @{L = 'UptimeMinutes'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalMinutes), 1)}}
                }
            }
    
            elseif ($Cluster) {
                foreach ($VMHost in (Get-VMHost -Location $Cluster)) {Get-View -ViewType hostsystem -Property name, runtime.boottime -Filter @{'name' = "$VMHost"} | Select-Object Name, @{L = 'UptimeDays'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalDays), 1)}}, @{L = 'UptimeHours'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalHours), 1)}}, @{L = 'UptimeMinutes'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalMinutes), 1)}}
                }
            }
    
            else {
                Get-View  -ViewType hostsystem -Property name, runtime.boottime | Select-Object Name, @{L = 'UptimeDays'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalDays), 1)}}, @{L = 'UptimeHours'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalHours), 1)}}, @{L = 'UptimeMinutes'; E = {[math]::round((((Get-Date) - ($_.Runtime.BootTime)).TotalMinutes), 1)}}
            }
        }
        <#
    .Synopsis
    Shows the uptime of VMHosts
    .Description
    Calculates the uptime of VMHosts provided, or VMHosts in the cluster provided
    .Parameter VMHosts
    The VMHosts you want to get the uptime of. Can be a single host or multiple hosts provided by the pipeline
    .Example
    Get-VMHostUptime
    Shows the uptime of all VMHosts in your vCenter
    .Example
    Get-VMHostUptime vmhost1
    Shows the uptime of vmhost1
    .Example
    Get-VMHostUptime -cluster cluster1
    Shows the uptime of all vmhosts in cluster1
    .Example
    Get-VMHost -location folder1 | Get-VMHostUptime
    Shows the uptime of VMHosts in folder1
    .Link
    http://cloud.kemta.net
    #>
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
            Get-ESXiBootDevice -VMHostname esxi-01
        #>
        param(
            [Parameter(Mandatory = $false)][String]$VMHostname
        )

        if ($VMHostname) {
            $vmhosts = Get-VMhost -Name $VMHostname
        } else {
            $vmhosts = Get-VMHost
        }

        $results = @()
        foreach ($vmhost in ($vmhosts | Sort-Object -Property Name)) {
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

            $tmp = [pscustomobject] @{
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
        }
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

        $PolicyLookup = @{
            'VMW_PSP_RR' = 'Round Robin'
            'VMW_PSP_FIXED' = 'Fixed'
            'VMW_PSP_MRU' = 'Most Recently Used'
        }
        $VMHostObj = $VMHosts | Where-Object {$_.Id -eq $VMHostMoRef}
        $ScsiDisk = $VMHostObj.ExtensionData.Config.StorageDevice.ScsiLun | Where-Object {
            $_.CanonicalName -eq $DatastoreDiskName
        }
        $Multipath = $VMHostObj.ExtensionData.Config.StorageDevice.MultipathInfo.Lun | Where-Object {
            $_.Lun -eq $ScsiDisk.Key
        }
        $MultipathPolicy = $PolicyLookup."$($Multipath.Policy.Policy)"
        $CapacityGB = [math]::Round((($ScsiDisk.Capacity.BlockSize * $ScsiDisk.Capacity.Block) / 1024 / 1024 / 1024), 2)

        [PSCustomObject] @{
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
    #endregion Script Functions

    #region Script Body
    #---------------------------------------------------------------------------------------------#
    #                                         SCRIPT BODY                                         #
    #---------------------------------------------------------------------------------------------#

    # Connect to vCenter Server using supplied credentials
    foreach ($VIServer in $Target) {
        #region vCenter Server Section
        $vCenter = Connect-VIServer $VIServer -Credential $Credential
        
        # Create a lookup hashtable to quickly link VM MoRefs to Names
        # Exclude VMware Site Recovery Manager placeholder VMs
        $VMs = Get-VM -Server $vCenter | Where-Object {
            $_.ExtensionData.Config.ManagedBy.ExtensionKey -notlike 'com.vmware.vcDr*'
        } | Sort-Object Name
        $VMLookup = @{}
        foreach ($VM in $VMs) {
            $VMLookup.($VM.Id) = $VM.Name
        }

        # Create a lookup hashtable to quickly link Host MoRefs to Names
        $VMHosts = Get-VMHost -Server $vCenter | Sort-Object Name
        $VMHostLookup = @{}
        foreach ($VMHost in $VMHosts) {
            $VMHostLookup.($VMHost.Id) = $VMHost.Name
        }

        $VCAdvSettings = Get-AdvancedSetting -Entity $vCenter
        $VCServerFQDN = ($VCAdvSettings | Where-Object {$_.name -eq 'VirtualCenter.FQDN'}).Value
        $VCAdvSettingsHash = @{
            FQDN = $VCServerFQDN
            IPv4 = ($VCAdvSettings | Where-Object {$_.name -like 'VirtualCenter.AutoManagedIPV4'}).Value
            Version = $vCenter.Version
            Build = $vCenter.Build
            OsType = $vCenter.ExtensionData.Content.About.OsType
            HttpPort = ($VCAdvSettings | Where-Object {$_.name -eq 'config.vpxd.rhttpproxy.httpport'}).Value
            HttpsPort = ($VCAdvSettings | Where-Object {$_.name -eq 'config.vpxd.rhttpproxy.httpsport'}).Value

            InstanceId = ($VCAdvSettings | Where-Object {$_.name -eq 'instance.id'}).Value
            PasswordExpiry = ($VCAdvSettings | Where-Object {$_.name -eq 'VirtualCenter.VimPasswordExpirationInDays'}).Value
            PlatformServicesController = ($VCAdvSettings | Where-Object {$_.name -eq 'config.vpxd.sso.admin.uri'}).Value
        }
        Section -Style Heading1 $VCServerFQDN {
            if ($InfoLevel.vCenter -ge 1) {
                Section -Style Heading2 'vCenter Server' { 
                    Paragraph ("The following section provides information on the configuration of vCenter " +
                        "Server $VCServerFQDN.")
                    BlankLine  

                    if ($InfoLevel.vCenter -eq 2) {
                        #region vCenter Server Condensed Information
                        $vCenterSettings = $VCAdvSettingsHash | Select-Object @{L = 'Name'; E = {$_.FQDN}}, @{L = 'IP Address'; E = {$_.IPv4}}, @{L = 'Version'; E = {$_.Version}}, @{L = 'Build'; E = {$_.Build}}, @{L = 'OS Type'; E = {$_.OsType}} 
                        $vCenterSettings | Table -Name $VCServerFQDN -ColumnWidths 20, 20, 20, 20, 20
                        #endregion vCenter Server Condensed Information
                    }
                    if ($InfoLevel.vCenter -ge 3) {
                        #region vCenter Server Detailed Information
                        $vCenterSettings = $VCAdvSettingsHash | Select-Object @{L = 'Name'; E = {$_.FQDN}}, @{L = 'IP Address'; E = {$_.IPv4}}, @{L = 'Version'; E = {$_.Version}}, @{L = 'Build'; E = {$_.Build}}, @{L = 'OS Type'; E = {$_.OsType}}, 
                        @{L = 'Instance Id'; E = {$_.InstanceId}}, @{L = 'Password Expiry in Days'; E = {$_.PasswordExpiry}}, @{L = 'HTTP Port'; E = {$_.httpport}}, @{L = 'HTTPS Port'; E = {$_.httpsport}}, 
                        @{L = 'Platform Services Controller'; E = {($_.PlatformServicesController) -replace "^https://|/sso-adminserver/sdk/vsphere.local"}} 
                        $vCenterSettings | Table -Name $VCServerFQDN -List -ColumnWidths 50, 50 
                        Section -Style Heading3 'Database Settings' {
                            $VCDBSettingsHash = @{
                                DbType = ($VCAdvSettings | Where-Object {$_.name -eq 'config.vpxd.odbc.dbtype'}).Value
                                Dsn = ($VCAdvSettings | Where-Object {$_.name -eq 'config.vpxd.odbc.dsn'}).Value
                                MaxDbConnections = ($VCAdvSettings | Where-Object {$_.name -eq 'VirtualCenter.MaxDBConnection'}).Value
                            }
                            $VCDBSettings = $VCDBSettingsHash | Select-Object @{L = 'Database Type'; E = {$_.dbtype}}, @{L = 'Data Source Name'; E = {$_.dsn}}, @{L = 'Maximum Database Connections'; E = {$_.MaxDbConnections}}
                            $VCDBSettings | Table -Name 'vCenter Database Settings' -List -ColumnWidths 50, 50 
                        }
                        #endregion vCenter Server Detailed Information
                        
                        #region vCenter Server Mail Settings
                        Section -Style Heading3 'Mail Settings' {
                            $VCMailSettingsHash = @{
                                SmtpServer = ($VCAdvSettings | Where-Object {$_.name -eq 'mail.smtp.server'}).Value
                                SmtpPort = ($VCAdvSettings | Where-Object {$_.name -eq 'mail.smtp.port'}).Value
                                MailSender = ($VCAdvSettings | Where-Object {$_.name -eq 'mail.sender'}).Value
                            }
                            $VCMailSettings = $VCMailSettingsHash | Select-Object @{L = 'SMTP Server'; E = {$_.SmtpServer}}, @{L = 'SMTP Port'; E = {$_.SmtpPort}}, @{L = 'Mail Sender'; E = {$_.mailSender}}
                            if ($Healthcheck.vCenter.Mail) {
                                $VCMailSettings | Where-Object {!($_.'SMTP Server')} | Set-Style -Style Critical -Property 'SMTP Server'
                                $VCMailSettings | Where-Object {!($_.'SMTP Port')} | Set-Style -Style Critical -Property 'SMTP Port'
                                $VCMailSettings | Where-Object {!($_.'Mail Sender')} | Set-Style -Style Critical -Property 'Mail Sender' 
                            }
                            $VCMailSettings | Table -Name 'vCenter Mail Settings' -List -ColumnWidths 50, 50 
                        }
                        #endregion vCenter Server Mail Settings
                        
                        #region vCenter Server Historical Statistics
                        Section -Style Heading3 'Historical Statistics' {
                            $vCenterHistoricalStats = Get-vCenterStats | Select-Object @{L = 'Interval Duration'; E = {$_.IntervalDuration}}, @{L = 'Interval Enabled'; E = {$_.IntervalEnabled}}, 
                            @{L = 'Save Duration'; E = {$_.SaveDuration}}, @{L = 'Statistics Level'; E = {$_.StatsLevel}} -Unique
                            $vCenterHistoricalStats | Table -Name 'Historical Statistics' -ColumnWidths 25, 25, 25, 25
                        }
                        #endregion vCenter Server Historical Statistics

                        #region vCenter Server Licensing
                        Section -Style Heading3 'Licensing' {
                            $Licenses = Get-vCenterLicense | Select-Object @{L = 'Product Name'; E = {($_.type)}}, @{L = 'License Key'; E = {($_.key)}}, Total, Used, @{L = 'Available'; E = {($_.total) - ($_.Used)}} -Unique
                            if ($Healthcheck.vCenter.Licensing) {
                                $Licenses | Where-Object {$_.'Product Name' -eq 'Product Evaluation'} | Set-Style -Style Warning 
                            }
                            $Licenses | Table -Name 'Licensing' -ColumnWidths 32, 32, 12, 12, 12
                        }
                        #endregion vCenter Server Licensing

                        <#
                        #region vCenter Server SSL Certificate
                        Section -Style Heading3 'SSL Certificate' {
                            $VcSslCertHash = @{
                                Country          = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.country'}).Value
                                Email            = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.email'}).Value
                                Locality         = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.localityName'}).Value
                                State            = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.state'}).Value
                                Organization     = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.organizationName'}).Value
                                OrganizationUnit = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.cn.organizationalUnitName'}).Value
                                DaysValid        = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.daysValid'}).Value
                                Mode             = ($VCAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.mode'}).Value
                            }
                            $VcSslCertificate = $VcSslCertHash | Select-Object @{L = 'Country'; E = {$_.Country}}, @{L = 'State'; E = {$_.State}}, @{L = 'Locality'; E = {$_.Locality}}, 
                            @{L = 'Organization'; E = {$_.Organization}}, @{L = 'Organizational Unit'; E = {$_.OrganizationUnit}}, @{L = 'Email'; E = {$_.Email}}, @{L = 'Validity'; E = {"$($_.DaysValid / 365) Years"}}  
                            $VcSslCertificate | Table -Name "$vCenter SSL Certificate" -List -ColumnWidths 50, 50
                        }
                        #endregion vCenter Server SSL Certificate
                        #>
                        
                        #region vCenter Server Roles
                        Section -Style Heading3 'Roles' {
                            $VCRoles = Get-VIRole -Server $vCenter | Sort-Object Name | Select-Object Name, @{L = 'System Role'; E = {$_.IsSystem}}
                            $VCRoles | Table -Name 'Roles' -ColumnWidths 50, 50 
                        }
                        #endregion vCenter Server Roles

                        #region vCenter Server Tags
                        $Tags = Get-Tag -Server $vCenter
                        if ($Tags) {
                            Section -Style Heading3 'Tags' {
                                $Tags = $Tags | Sort-Object Name, Category | Select-Object Name, Description, Category
                                $Tags | Table -Name 'Tags'
                            }
                        }
                        #endregion vCenter Server Tags

                        #region vCenter Server Tag Categories
                        $TagCategories = Get-TagCategory 
                        if ($TagCategories) {
                            Section -Style Heading3 'Tag Categories' {
                                $TagCategories = $TagCategories | Sort-Object name | Select-Object Name, Description, Cardinality -Unique
                                $TagCategories | Table -Name 'Tag Categories' -ColumnWidths 40, 40, 20
                            }
                        }
                        #endregion vCenter Server Tag Categories
                            
                        #region vCenter Server Tag Assignments
                        $TagAssignments = Get-TagAssignment 
                        if ($TagAssignments) {
                            Section -Style Heading3 'Tag Assignments' {
                                $TagAssignments = $TagAssignments | Sort-Object Tag | Select-Object Tag, Entity
                                $TagAssignments | Table -Name 'Tag Assignments' -ColumnWidths 50, 50
                            }
                        }
                        #endregion vCenter Server Tag Assignments
                    }
                        
                    #region vCenter Alarms
                    # To add alarm configuration to the report, set vCenter info level to 5 or above in report JSON file.
                    if ($InfoLevel.vCenter -ge 5) {
                        Section -Style Heading3 'Alarms' {
                            Paragraph ("The following table details the configuration of the vCenter Server " +
                                "alarms for $VCServerFQDN.")
                            BlankLine
                            $Alarms = Get-AlarmAction -Server $vCenter | Sort-Object AlarmDefinition | Select-Object @{L = 'Alarm Definition'; E = {$_.AlarmDefinition}}, @{L = 'Action Type'; E = {$_.ActionType}}, @{L = 'Trigger'; E = {$_.Trigger -join [Environment]::NewLine}}
                            $Alarms | Table -Name 'Alarms' -ColumnWidths 50, 20, 30
                        }
                    }
                    #endregion vCenter Alarms
                }
            }
            if ($InfoLevel.vCenter -ge 3) {
                PageBreak
            }
            #endregion vCenter Server Section

            #region Cluster Section
            if ($InfoLevel.Cluster -ge 1) {
                $Script:Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
                if ($Clusters) {
                    Section -Style Heading2 'Clusters' {
                        Paragraph ("The following section provides information on the configuration of each " +
                            "vSphere HA/DRS cluster managed by vCenter Server $VCServerFQDN.")
                        BlankLine

                        #region Cluster Condensed Information   
                        if ($InfoLevel.Cluster -eq 2) {
                            $ClusterSummary = $Clusters | Select-Object name, @{L = 'Datacenter'; E = {($_ | Get-Datacenter)}}, @{L = '# of Hosts'; E = {($_ | Get-VMhost).count}}, 
                            @{L = '# of VMs'; E = {($_ | Get-VM).count}}, @{L = 'HA Enabled'; E = {($_.haenabled)}}, @{L = 'DRS Enabled'; E = {($_.drsenabled)}}, 
                            @{L = 'vSAN Enabled'; E = {($_.vsanenabled)}}, @{L = 'EVC Mode'; E = {($_.EVCMode)}}, @{L = 'VM Swap File Policy'; E = {($_.VMSwapfilePolicy)}} 
                            if ($Healthcheck.Cluster.HAEnabled) {
                                $ClusterSummary | Where-Object {$_.'HA Enabled' -eq $False} | Set-Style -Style Warning -Property 'HA Enabled'
                            }
                            if ($Healthcheck.Cluster.DrsEnabled) {
                                $ClusterSummary | Where-Object {$_.'DRS Enabled' -eq $False} | Set-Style -Style Warning -Property 'DRS Enabled'
                            }
                            if ($Healthcheck.Cluster.EvcEnabled) {
                                $ClusterSummary | Where-Object {!($_.'EVC Mode')} | Set-Style -Style Warning -Property 'EVC Mode'
                            }
                            $ClusterSummary | Table -Name 'Cluster Summary' #-ColumnWidths 15, 15, 8, 11, 11, 11, 11, 10, 8
                        }
                        #endregion Cluster Condensed Information

                        if ($InfoLevel.Cluster -ge 3) {
                            #region Cluster Detailed Information
                            foreach ($Cluster in ($Clusters)) {
                                Section -Style Heading3 $Cluster {
                                    Paragraph "The following table details the configuration for cluster $Cluster."
                                    BlankLine
                                    #region Cluster Configuration
                                    $ClusterSpecs = $Cluster | Select-Object name, id, @{L = 'Datacenter'; E = {($_ | Get-Datacenter)}}, @{L = 'Number of Hosts'; E = {($_ | Get-VMhost).Count}}, 
                                    @{L = 'Number of VMs'; E = {($_ | Get-VM).Count}}, @{L = 'HA Enabled'; E = {($_.haenabled)}}, @{L = 'DRS Enabled'; E = {($_.drsenabled)}}, 
                                    @{L = 'vSAN Enabled'; E = {($_.vsanenabled)}}, @{L = 'EVC Mode'; E = {($_.EVCMode)}}, @{L = 'VM Swap File Policy'; E = {($_.VMSwapfilePolicy)}} 
                                    if ($Healthcheck.Cluster.HAEnabled) {
                                        $ClusterSpecs | Where-Object {$_.'HA Enabled' -eq $False} | Set-Style -Style Warning -Property 'HA Enabled'
                                    }
                                    if ($Healthcheck.Cluster.DrsEnabled) {
                                        $ClusterSpecs | Where-Object {$_.'DRS Enabled' -eq $False} | Set-Style -Style Warning -Property 'DRS Enabled'
                                    }
                                    if ($Healthcheck.Cluster.EvcEnabled) {
                                        $ClusterSpecs | Where-Object {!($_.'EVC Mode')} | Set-Style -Style Warning -Property 'EVC Mode'
                                    }
                                    # Set InfoLevel to 4 or above to provide information for associated VMhosts & VMs
                                    if ($InfoLevel.Cluster -ge 4) {
                                        $ClusterSpecs | ForEach-Object {
                                            $ClusterHosts = $Cluster | Get-VMhost | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($ClusterHosts.Name -join ", ")
                                            $ClusterVMs = $Cluster | Get-VM | Sort-Object Name 
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ClusterVMs.Name -join ", ")
                                        }
                                    }
                                    $ClusterSpecs | Table -List -Name "$Cluster Information" -ColumnWidths 50, 50 
                                    #endregion Cluster Configuration

                                    #region HA Cluster Configuration
                                    Section -Style Heading4 'HA Configuration' {
                                        Paragraph ("The following table details the vSphere HA configuration " +
                                            "for cluster $Cluster.")
                                        BlankLine

                                        ### TODO: HA Advanced Settings, Proactive HA
                        
                                        $HACluster = $Cluster | Select-Object @{L = 'HA Enabled'; E = {($_.HAEnabled)}}, @{L = 'HA Admission Control Enabled'; E = {($_.HAAdmissionControlEnabled)}}, @{L = 'HA Failover Level'; E = {($_.HAFailoverLevel)}}, 
                                        @{L = 'HA Restart Priority'; E = {($_.HARestartPriority)}}, @{L = 'HA Isolation Response'; E = {($_.HAIsolationResponse)}}, @{L = 'Heartbeat Selection Policy'; E = {$_.ExtensionData.Configuration.DasConfig.HBDatastoreCandidatePolicy}}, 
                                        @{L = 'Heartbeat Datastores'; E = {($_.ExtensionData.Configuration.DasConfig.HeartbeatDatastore | ForEach-Object {(get-view -id $_).name}) -join ", "}}
                                        if ($Healthcheck.Cluster.HAEnabled) {
                                            $HACluster | Where-Object {$_.'HA Enabled' -eq $False} | Set-Style -Style Warning -Property 'HA Enabled'
                                        }
                                        if ($Healthcheck.Cluster.HAAdmissionControl) {
                                            $HACluster | Where-Object {$_.'HA Admission Control Enabled' -eq $False} | Set-Style -Style Warning -Property 'HA Admission Control Enabled'
                                        }
                                        $HACluster | Table -Name "$Cluster HA Configuration" -List -ColumnWidths 50, 50 
                                    }
                                    #endregion HA Cluster Configuration

                                    #region DRS Cluster Configuration
                                    Section -Style Heading4 'DRS Configuration' {
                                        Paragraph ("The following table details the vSphere DRS configuration " +
                                            "for cluster $Cluster.")
                                        BlankLine

                                        ## TODO: DRS Advanced Settings, VM Overrides

                                        $DRSCluster = $Cluster | Select-Object @{L = 'DRS Enabled'; E = {($_.DrsEnabled)}}, @{L = 'DRS Automation Level'; E = {($_.DrsAutomationLevel)}}, @{L = 'DRS Migration Threshold'; E = {($_.ExtensionData.Configuration.DrsConfig.VmotionRate)}}
                                        if ($Healthcheck.Cluster.DrsEnabled) {
                                            $DRSCluster | Where-Object {$_.'DRS Enabled' -eq $False} | Set-Style -Style Warning -Property 'DRS Enabled'
                                        }
                                        if ($Healthcheck.Cluster.DrsAutomationLevel) {
                                            $DRSCluster | Where-Object {$_.'DRS Automation Level' -ne $Healthcheck.Cluster.DrsAutomationLevelSetting} | Set-Style -Style Warning -Property 'DRS Automation Level'
                                        }
                                        $DRSCluster | Table -Name "$Cluster DRS Configuration" -List -ColumnWidths 50, 50 
                                        BlankLine

                                        #region DRS Cluster Additional Options
                                        $DRSAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object {$_.Type -eq 'ClusterDRS'}
                                        $DRSAdditionalOptionsHash = @{
                                            VMDistribution = ($DRSAdvancedSettings | Where-Object {$_.name -eq 'TryBalanceVmsPerHost'}).Value
                                            MemoryMetricLB = ($DRSAdvancedSettings | Where-Object {$_.name -eq 'PercentIdleMBInMemDemand'}).Value
                                            CpuOverCommit = ($DRSAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerClusterPct'}).Value
                                        }
                                        $DRSAdditionalOptions = $DRSAdditionalOptionsHash | Select-Object @{L = 'VM Distribution'; E = {$_.VMDistribution}}, @{L = 'Memory Metric for Load Balancing'; E = {$_.MemoryMetricLB}}, @{L = 'CPU Over-Commitment'; E = {$_.CpuOverCommit}}
                                        $DRSAdditionalOptions | Table -Name "$Cluster DRS Additional Options" -List -ColumnWidths 50, 50
                                        #endregion DRS Cluster Additional Options

                                        #region DRS Cluster Group
                                        $DRSGroups = $Cluster | Get-DrsClusterGroup
                                        if ($DRSGroups) {
                                            Section -Style Heading5 'DRS Cluster Groups' {
                                                $DRSGroups = $DRSGroups | Sort-Object GroupType, Name | Select-Object Name, @{L = 'Group Type'; E = {$_.GroupType}}, @{L = 'Members'; E = {$_.Member -join ", "}}
                                                $DRSGroups | Table -Name "$Cluster DRS Cluster Groups"
                                            }
                                        }
                                        #endregion DRS Cluster Group  

                                        #region DRS Cluster VM/Host Rules
                                        $DRSVMHostRules = $Cluster | Get-DrsVMHostRule
                                        if ($DRSVMHostRules) {
                                            Section -Style Heading5 'DRS VM/Host Rules' {
                                                $DRSVMHostRules = $DRSVMHostRules | Sort-Object Name | Select-Object Name, Type, Enabled, @{L = 'VM Group'; E = {$_.VMGroup}}, @{L = 'VMHost Group'; E = {$_.VMHostGroup}}
                                                if ($Healthcheck.Cluster.DrsVMHostRules) {
                                                    $DRSVMHostRules | Where-Object {$_.Enabled -eq $False} | Set-Style -Style Warning -Property Enabled
                                                }
                                                $DRSVMHostRules | Table -Name "$Cluster DRS VM/Host Rules"
                                            }
                                        }
                                        #endregion DRS Cluster VM/Host Rules

                                        #region DRS Cluster Rules
                                        $DRSRules = $Cluster | Get-DrsRule
                                        if ($DRSRules) {
                                            Section -Style Heading5 'DRS Rules' {
                                                $DRSRules = $DRSRules | Sort-Object Type | Select-Object Name, Type, Enabled, Mandatory, @{L = 'Virtual Machines'; E = {($_.VMIds | ForEach-Object {(get-view -id $_).name}) -join ", "}}
                                                if ($Healthcheck.Cluster.DrsRules) {
                                                    $DRSRules | Where-Object {$_.Enabled -eq $False} | Set-Style -Style Warning -Property Enabled
                                                }
                                                $DRSRules | Table -Name "$Cluster DRS Rules"
                                            }
                                        }
                                        #endregion DRS Cluster Rules                                
                                    }
                                    
                                    #region Cluster VUM Baselines
                                    $ClusterBaselines = $Cluster | Get-PatchBaseline
                                    if ($ClusterBaselines) {
                                        Section -Style Heading4 'Update Manager Baselines' {
                                            $ClusterBaselines = $ClusterBaselines | Sort-Object Name | Select-Object Name, Description, @{L = 'Type'; E = {$_.BaselineType}}, @{L = 'Target Type'; E = {$_.TargetType}}, @{L = 'Last Update Time'; E = {$_.LastUpdateTime}}, @{L = '# of Patches'; E = {($_.CurrentPatches).count}}
                                            $ClusterBaselines | Table -Name "$Cluster Update Manager Baselines"
                                        }
                                    }
                                    #endregion Cluster VUM Baselines

                                    #region Cluster VUM Compliance
                                    # Set InfoLevel to 4 or above to provide information for VMware Update Manager compliance
                                    if ($InfoLevel.Cluster -ge 4) {
                                        $ClusterCompliance = $Cluster | Get-Compliance
                                        if ($ClusterCompliance) {
                                            Section -Style Heading4 'Update Manager Compliance' {
                                                $ClusterCompliance = $ClusterCompliance | Sort-Object Entity, Baseline | Select-Object @{L = 'Name'; E = {$_.Entity}}, @{L = 'Baseline'; E = {($_.Baseline).Name -join ", "}}, Status
                                                if ($Healthcheck.Cluster.VUMCompliance) {
                                                    $ClusterCompliance | Where-Object {$_.Status -eq 'Unknown'} | Set-Style -Style Warning
                                                    $ClusterCompliance | Where-Object {$_.Status -eq 'NotCompliant' -or $_.Status -eq 'Incompatible'} | Set-Style -Style Critical
                                                }
                                                $ClusterCompliance | Table -Name "$Cluster Update Manager Compliance" -ColumnWidths 25, 50, 25
                                            }
                                        }
                                    }
                                    #endregion Cluster VUM Compliance
                    
                                    #region Cluster Permissions
                                    Section -Style Heading4 'Permissions' {
                                        Paragraph ("The following table details the permissions assigned " +
                                            "to cluster $Cluster.")
                                        BlankLine

                                        $VIPermission = $Cluster | Get-VIPermission | Select-Object @{L = 'User/Group'; E = {$_.Principal}}, @{L = 'Is Group?'; E = {$_.IsGroup}}, Role, @{L = 'Defined In'; E = {$_.Entity}}, Propagate
                                        $VIPermission | Table -Name "$Cluster Permissions"
                                    }
                                    #endregion Cluster Permissions
                                }
                                #endregion DRS Cluster Configuration
                            }
                            #endregion Cluster Detailed Information
                        }
                    }
                    if ($InfoLevel.Cluster -ge 3) {
                        PageBreak
                    }
                }
            }
            #endregion Cluster Section   

            #region Resource Pool Section
            if ($InfoLevel.ResourcePool -ge 1) {
                $Script:ResourcePools = Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
                if ($ResourcePools) {
                    Section -Style Heading2 'Resource Pools' {
                        Paragraph ("The following section provides information on the configuration of " +
                            "resource pools managed by vCenter Server $VCServerFQDN.")
                        BlankLine
                        if ($InfoLevel.ResourcePool -eq 2) {
                            #region Resource Pool Condensed Information
                            $ResourcePoolSummary = $ResourcePools | Select-Object Name, Parent, @{L = 'CPU Shares Level'; E = {$_.CpuSharesLevel}}, @{L = 'CPU Reservation MHz'; E = {$_.CpuReservationMHz}}, 
                            @{L = 'CPU Limit MHz'; E = {if ($_.CpuLimitMHz -eq -1) {"Unlimited"} else {$_.CpuLimitMHz}}}, @{L = 'Memory Shares Level'; E = {$_.MemSharesLevel}}, 
                            @{L = 'Memory Reservation'; E = {[math]::Round($_.MemReservationGB, 2)}}, @{L = 'Memory Limit GB'; E = {if ($_.MemLimitGB -eq -1) {"Unlimited"} else {[math]::Round($_.MemLimitGB, 2)}}}
                            $ResourcePoolSummary | Table -Name 'Resource Pool Summary' #-ColumnWidths 11,11,13,13,13,13,13,13
                        }                    
                        #endregion Resource Pool Condensed Information

                        if ($InfoLevel.ResourcePool -ge 3) {
                            #region Resource Pool Detailed Information
                            foreach ($ResourcePool in $ResourcePools) {
                                Section -Style Heading3 $ResourcePool.Name {
                                    $ResourcePoolSpecs = $ResourcePool | Select-Object Name, id, Parent, @{L = 'CPU Shares Level'; E = {$_.CpuSharesLevel}}, @{L = 'Number of CPU Shares'; E = {$_.NumCpuShares}}, 
                                    @{L = 'CPU Reservation'; E = {"$($_.CpuReservationMHz) MHz"}}, @{L = 'CPU Expandable Reservation'; E = {$_.CpuExpandableReservation}}, @{L = 'CPU Limit'; E = {if ($_.CpuLimitMHz -eq -1) {"Unlimited"} else {"$($_.CpuLimitMHz) MHz"}}}, 
                                    @{L = 'Memory Shares Level'; E = {$_.MemSharesLevel}}, @{L = 'Number of Memory Shares'; E = {$_.NumMemShares}}, @{L = 'Memory Reservation'; E = {"$([math]::Round($_.MemReservationGB, 2)) GB"}}, 
                                    @{L = 'Memory Expandable Reservation'; E = {$_.MemExpandableReservation}}, @{L = 'Memory Limit'; E = {if ($_.MemLimitGB -eq -1) {"Unlimited"} else {"$([math]::Round($_.MemLimitGB, 2)) GB"}}}, @{L = 'Number of VMs'; E = {($_ | Get-VM).count}}
                
                                    # Set InfoLevel to 4 or above to provide information for associated VMs
                                    if ($InfoLevel.ResourcePool -ge 4) {
                                        $ResourcePoolSpecs | ForEach-Object {
                                            # Query for VMs by resource pool Id
                                            $ResourcePoolId = $_.Id
                                            $ResourcePoolVMs = Get-VM | Where-Object { $_.ResourcePoolId -eq $ResourcePoolId } | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ResourcePoolVMs.Name -join ", ")
                                        }
                                    }
                                    $ResourcePoolSpecs | Table -Name 'Resource Pools' -List -ColumnWidths 50, 50  
                                }
                            }
                            #endregion Resource Pool Detailed Information
                        }
                    }
                    if ($InfoLevel.ResourcePool -ge 3) {
                        PageBreak
                    }
                }
            }
            #endregion Resource Pool Section

            #region ESXi VMHost Section
            if ($InfoLevel.VMHost -ge 1) {
                if ($VMhosts) {
                    Section -Style Heading2 'Hosts' {
                        Paragraph ("The following section provides information on the configuration of VMware " +
                            "ESXi hosts managed by vCenter Server $VCServerFQDN.")
                        BlankLine
        
                        #region ESXi Host Condensed Information
                        if ($InfoLevel.VMHost -eq 2) {
                            $VMHostSummary = $VMhosts | Select-Object name, version, build, parent, @{L = 'Connection State'; E = {$_.ConnectionState}}, @{L = 'CPU Usage MHz'; E = {$_.CpuUsageMhz}}, @{L = 'Memory Usage GB'; E = {[math]::Round($_.MemoryUsageGB, 2)}}
                            if ($Healthcheck.VMHost.ConnectionState) {
                                $VMHostSummary | Where-Object {$_.'Connection State' -eq 'Maintenance'} | Set-Style -Style Warning
                                $VMHostSummary | Where-Object {$_.'Connection State' -eq 'Disconnected'} | Set-Style -Style Critical
                            }
                            $VMHostSummary | Table -Name 'Host Summary' #-ColumnWidths 23, 10, 12, 12, 14, 10, 10, 9
                        }
                        #endregion ESXi Host Condensed Information

                        if ($InfoLevel.VMHost -ge 3) {
                            #region ESXi Host Detailed Information
                            foreach ($VMhost in ($VMhosts | Where-Object {$_.ConnectionState -eq 'Connected' -or $_.ConnectionState -eq 'Maintenance'})) {        
                                Section -Style Heading3 $VMhost {

                                    ### TODO: Host Certificate, Swap File Location
                            
                                    Section -Style Heading4 'Hardware' {
                                        Paragraph ("The following section provides information on the host " +
                                            "hardware configuration of $VMhost.")
                                        BlankLine

                                        #region ESXi Host Specifications
                                        $uptime = Get-VMHostUptime $VMhost
                                        $esxcli = Get-EsxCli -VMHost $VMhost -V2 -Server $vCenter
                                        $VMHostHardware = Get-VMHostHardware -VMHost $VMhost
                                        $ScratchLocation = Get-AdvancedSetting -Entity $VMhost | Where-Object {$_.Name -eq 'ScratchConfig.CurrentScratchLocation'}
                                        $VMHostSpecs = $VMhost | Sort-Object name | Select-Object name, id, parent, manufacturer, model, @{L = 'Serial Number'; E = {$VMHostHardware.SerialNumber}}, @{L = 'Asset Tag'; E = {$VMHostHardware.AssetTag}}, 
                                        @{L = 'Processor Type'; E = {($_.processortype)}}, @{L = 'HyperThreading'; E = {($_.HyperthreadingActive)}}, @{L = 'Number of CPU Sockets'; E = {$_.ExtensionData.Hardware.CpuInfo.NumCpuPackages}}, 
                                        @{L = 'Number of CPU Cores'; E = {$_.ExtensionData.Hardware.CpuInfo.NumCpuCores}}, @{L = 'Number of CPU Threads'; E = {$_.ExtensionData.Hardware.CpuInfo.NumCpuThreads}}, 
                                        @{L = 'CPU Speed'; E = {"$([math]::Round(($_.ExtensionData.Hardware.CpuInfo.Hz) / 1000000000, 2)) GHz"}}, @{L = 'Memory'; E = {"$([math]::Round($_.memorytotalgb, 0)) GB"}}, 
                                        @{L = 'NUMA Nodes'; E = {$_.ExtensionData.Hardware.NumaInfo.NumNodes}}, @{L = 'Number of NICs'; E = {$VMHostHardware.NicCount}}, @{L = 'Number of Datastores'; E = {($_.DatastoreIdList).Count}}, @{L = 'Number of VMs'; E = {($_ | Get-VM).count}},  
                                        @{L = 'Maximum EVC Mode'; E = {$_.MaxEVCMode}}, @{L = 'Power Management Policy'; E = {$_.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy}}, @{L = 'Scratch Location'; E = {$ScratchLocation.Value}}, 
                                        @{L = 'Bios Version'; E = {$_.ExtensionData.Hardware.BiosInfo.BiosVersion}}, @{L = 'Bios Release Date'; E = {$_.ExtensionData.Hardware.BiosInfo.ReleaseDate}}, @{L = 'ESXi Version'; E = {$_.version}}, 
                                        @{L = 'ESXi Build'; E = {$_.build}}, @{L = 'Uptime Days'; E = {$uptime.UptimeDays}}                                   
                                        if ($Healthcheck.VMHost.ScratchLocation) {
                                            $VMHostSpecs | Where-Object {$_.'Scratch Location' -eq '/tmp/scratch'} | Set-Style -Style Warning -Property 'Scratch Location'
                                        }
                                        if ($Healthcheck.VMHost.UpTimeDays) {
                                            $VMHostSpecs | Where-Object {$_.'Uptime Days' -ge 275 -and $_.'Uptime Days' -lt 365} | Set-Style -Style Warning -Property 'Uptime Days'
                                            $VMHostSpecs | Where-Object {$_.'Uptime Days' -ge 365} | Set-Style -Style Warning -Property 'Uptime Days'
                                        }
                                        $VMHostSpecs | Table -Name "$VMhost Specifications" -List -ColumnWidths 50, 50 
                                        #endregion ESXi Host Specifications

                                        #region ESXi Host Boot Devices
                                        Section -Style Heading5 'Boot Devices' {
                                            $BootDevice = Get-ESXiBootDevice -VMHostname $VMhost | Select-Object Host, Device, @{L = 'Boot Type'; E = {$_.BootType}}, Vendor, Model, @{L = 'Size MB'; E = {$_.SizeMB}}, @{L = 'Is SAS'; E = {$_.IsSAS}}, @{L = 'Is SSD'; E = {$_.IsSSD}}, 
                                            @{L = 'Is USB'; E = {$_.IsUSB}}
                                            $BootDevice | Table -Name "$VMhost Boot Devices" -List -ColumnWidths 50, 50 
                                        }
                                        #endregion ESXi Host Boot Devices

                                        #region ESXi Host PCI Devices
                                        Section -Style Heading5 'PCI Devices' {
                                            $PciHardwareDevice = $esxcli.hardware.pci.list.Invoke() | Where-Object {$_.VMKernelName -like "vmhba*" -OR $_.VMKernelName -like "vmnic*" -OR $_.VMKernelName -like "vmgfx*"} 
                                            $VMhostPciDevices = $PciHardwareDevice | Sort-Object VMkernelName | Select-Object @{L = 'VMkernel Name'; E = {$_.VMkernelName}}, @{L = 'PCI Address'; E = {$_.Address}}, @{L = 'Device Class'; E = {$_.DeviceClassName}}, 
                                            @{L = 'Device Name'; E = {$_.DeviceName}}, @{L = 'Vendor Name'; E = {$_.VendorName}}, @{L = 'Slot Description'; E = {$_.SlotDescription}}
                                            $VMhostPciDevices | Table -Name "$VMhost PCI Devices" 
                                        }
                                        #endregion ESXi Host PCI Devices
                                    }

                                    #region ESXi Host System Section
                                    Section -Style Heading4 'System' {
                                        Paragraph ("The following section provides information on the host " +
                                            "system configuration of $VMhost.")

                                        #region ESXi Host Licensing Information
                                        Section -Style Heading5 'Licensing' {
                                            $ServiceInstance = Get-View ServiceInstance
                                            $LicenseManager = Get-View $ServiceInstance.Content.LicenseManager
                                            $LicenseManagerAssign = Get-View $LicenseManager.LicenseAssignmentManager
                                            $VMHostView = $VMhost | Get-View
                                            $VMhostID = $VMHostView.Config.Host.Value
                                            $VMHostLM = $LicenseManagerAssign.QueryAssignedLicenses($VMhostID)
                                            $LicenseType = $VMHostView | Select-Object @{L = 'License Type'; E = {$VMHostLM.AssignedLicense.Name | Select-Object -Unique}}
                                            if ($Options.ShowLicenses) {
                                                $Licenses = $VMHost | Select-Object @{L = 'License Type'; E = {$LicenseType.'License Type'}}, @{L = 'License Key'; E = {$_.LicenseKey}}
                                            } else {
                                                $Licenses = $VMHost | Select-Object @{L = 'License Type'; E = {$LicenseType.'License Type'}}, @{L = 'License Key'; E = {'*****-*****-*****' + ($_.LicenseKey).Substring(17)}}
                                            }
                                            if ($Healthcheck.VMhost.Licensing) {
                                                $Licenses | Where-Object {$_.'License Type' -eq 'Evaluation Mode'} | Set-Style -Style Warning 
                                            }
                                            $Licenses | Table -Name "$VMhost Licensing" -ColumnWidths 50, 50 
                                        }
                                        #endregion ESXi Host Licensing Information
                    
                                        #region ESXi Host Profile Information
                                        if ($VMhost | Get-VMHostProfile) {
                                            Section -Style Heading5 'Host Profile' {
                                                $VMHostProfile = $VMhost | Get-VMHostProfile | Select-Object Name, Description
                                                $VMHostProfile | Table -Name "$VMhost Host Profile" -ColumnWidths 50, 50 
                                            }
                                        }
                                        #endregion ESXi Host Profile Information

                                        #region ESXi Host Image Profile Information
                                        Section -Style Heading5 'Image Profile' {
                                            $installdate = Get-InstallDate
                                            $esxcli = Get-ESXCli -VMHost $VMhost -V2 -Server $vCenter
                                            $ImageProfile = $esxcli.software.profile.get.Invoke()
                                            $SecurityProfile = $ImageProfile | Select-Object @{L = 'Image Profile'; E = {$_.Name}}, Vendor, @{L = 'Installation Date'; E = {$installdate.InstallDate}}
                                            $SecurityProfile | Table -Name "$VMhost Image Profile" -ColumnWidths 50, 25, 25 
                                        }
                                        #endregion ESXi Host Image Profile Information

                                        #region ESXi Host Time Configuration
                                        Section -Style Heading5 'Time Configuration' {
                                            $VMHostTimeSettingsHash = @{
                                                NtpServer = @($VMhost | Get-VMHostNtpServer) -join ", "
                                                Timezone = $VMhost.timezone
                                                NtpService = ($VMhost | Get-VMHostService | Where-Object {$_.key -eq 'ntpd'}).Running
                                            }
                                            $VMHostTimeSettings = $VMHostTimeSettingsHash | Select-Object @{L = 'Time Zone'; E = {$_.Timezone}}, @{L = 'NTP Service Running'; E = {$_.NtpService}}, @{L = 'NTP Server(s)'; E = {$_.NtpServer}}
                                            if ($Healthcheck.VMHost.TimeConfig) {
                                                $VMHostTimeSettings | Where-Object {$_.'NTP Service Running' -eq $False} | Set-Style -Style Critical -Property 'NTP Service Running'
                                            }
                                            $VMHostTimeSettings | Table -Name "$VMhost Time Configuration" -ColumnWidths 30, 30, 40
                                        }
                                        #endregion ESXi Host Time Configuration

                                        #region ESXi Host Syslog Configuration
                                        $SyslogConfig = $VMhost | Get-VMHostSysLogServer
                                        if ($SyslogConfig) {
                                            Section -Style Heading5 'Syslog Configuration' {
                                                ### TODO: Syslog Rotate & Size, Log Directory (Adv Settings)
                                                $SyslogConfig = $SyslogConfig | Select-Object @{L = 'SysLog Server'; E = {$_.Host}}, Port
                                                $SyslogConfig | Table -Name "$VMhost Syslog Configuration" -ColumnWidths 50, 50 
                                            }
                                        }
                                        #endregion ESXi Host Syslog Configuration

                                        #region ESXi Update Manager Baseline Information
                                        $VMHostBaselines = $VMhost | Get-PatchBaseline
                                        if ($VMHostBaselines) {
                                            Section -Style Heading5 'Update Manager Baselines' {
                                                $VMHostBaselines = $VMHostBaselines | Sort-object Name | Select-Object Name, Description, @{L = 'Type'; E = {$_.BaselineType}}, @{L = 'Target Type'; E = {$_.TargetType}}, @{L = 'Last Update Time'; E = {$_.LastUpdateTime}}, @{L = '# of Patches'; E = {($_.CurrentPatches).count}}
                                                $VMHostBaselines | Table -Name "$VMhost Update Manager Baselines"
                                            }
                                        }
                                        #endregion ESXi Update Manager Baseline Information

                                        #region ESXi Update Manager Compliance Information
                                        $VMhostCompliance = $VMhost | Get-Compliance
                                        if ($VMhostCompliance) {
                                            Section -Style Heading5 'Update Manager Compliance' {
                                                $VMhostCompliance = $VMhostCompliance | Sort-object Baseline | Select-Object @{L = 'Baseline'; E = {($_.Baseline).Name}}, Status
                                                if ($Healthcheck.VMHost.VUMCompliance) {
                                                    $VMhostCompliance | Where-Object {$_.Status -eq 'Unknown'} | Set-Style -Style Warning
                                                    $VMhostCompliance | Where-Object {$_.Status -eq 'NotCompliant' -or $_.Status -eq 'Incompatible'} | Set-Style -Style Critical
                                                }
                                                $VMhostCompliance | Table -Name "$VMhost Update Manager Compliance" -ColumnWidths 75, 25
                                            }
                                        }
                                        #endregion ESXi Update Manager Compliance Information

                                        # Set InfoLevel to 5 to provide advanced system information for VMhosts
                                        if ($InfoLevel.VMHost -ge 5) {
                                            #region ESXi Host Advanced System Settings
                                            Section -Style Heading5 'Advanced System Settings' {
                                                $AdvSettings = $VMHost | Get-AdvancedSetting | Sort-Object Name | Select-Object Name, Value
                                                $AdvSettings | Table -Name "$VMhost Advanced System Settings" -ColumnWidths 50, 50 
                                            }
                                            #endregion ESXi Host Advanced System Settings

                                            #region ESXi Host Software VIBs
                                            Section -Style Heading5 'Software VIBs' {
                                                $esxcli = Get-ESXCli -VMHost $VMhost -V2 -Server $vCenter
                                                $VMhostVibs = $esxcli.software.vib.list.Invoke()
                                                $VMhostVibs = $VMhostVibs | Sort-Object InstallDate -Descending | Select-Object Name, ID, Version, Vendor, @{L = 'Acceptance Level'; E = {$_.AcceptanceLevel}}, 
                                                @{L = 'Creation Date'; E = {$_.CreationDate}}, @{L = 'Install Date'; E = {$_.InstallDate}}
                                                $VMhostVibs | Table -Name "$VMhost Software VIBs" -ColumnWidths 10, 25, 20, 10, 15, 10, 10
                                            }
                                            #endregion ESXi Host Software VIBs
                                        }
                                    }
                                    #endregion ESXi Host System Section

                                    #region ESXi Host Storage Section
                                    Section -Style Heading4 'Storage' {
                                        Paragraph ("The following section provides information on the host " +
                                            "storage configuration of $VMhost.")
                    
                                        #region ESXi Host Datastore Specifications
                                        Section -Style Heading5 'Datastores' {
                                            $VMhostDS = $VMhost | Get-Datastore | Sort-Object name | Select-Object name, type, @{L = 'Version'; E = {$_.FileSystemVersion}}, 
                                            @{L = '# of VMs'; E = {(($_ | Get-VM).count)}}, @{L = 'Total Capacity GB'; E = {[math]::Round($_.CapacityGB, 2)}}, 
                                            @{L = 'Used Capacity GB'; E = {[math]::Round((($_.CapacityGB) - ($_.FreeSpaceGB)), 2)}}, @{L = 'Free Space GB'; E = {[math]::Round($_.FreeSpaceGB, 2)}}, 
                                            @{L = '% Used'; E = {[math]::Round((100 - (($_.FreeSpaceGB) / ($_.CapacityGB) * 100)), 2)}}          
                                            if ($Healthcheck.Datastore.CapacityUtilization) {
                                                $VMhostDS | Where-Object {$_.'% Used' -ge 90} | Set-Style -Style Critical
                                                $VMhostDS | Where-Object {$_.'% Used' -ge 75 -and $_.'% Used' -lt 90} | Set-Style -Style Warning
                                            }
                                            $VMhostDS | Table -Name "$VMhost Datastores" #-ColumnWidths 20,10,10,10,10,10,10,10,10
                                        }
                                        #endregion ESXi Host Datastore Specifications
                    
                                        #region ESXi Host Storage Adapater Information
                                        $VMHostHba = $VMhost | Get-VMHostHba | Where-Object {$_.type -eq 'FibreChannel' -or $_.type -eq 'iSCSI' }
                                        if ($VMHostHba) {
                                            Section -Style Heading5 'Storage Adapters' {
                                                $VMHostHbaFC = $VMhost | Get-VMHostHba -Type FibreChannel
                                                if ($VMHostHbaFC) {
                                                    Paragraph ("The following table details the fibre channel " +
                                                        "storage adapters for $VMhost.")
                                                    Blankline
                                                    $VMHostHbaFC = $VMhost | Get-VMHostHba -Type FibreChannel | Sort-Object Device | Select-Object Device, Type, Model, Driver, 
                                                    @{L = 'Node WWN'; E = {([String]::Format("{0:X}", $_.NodeWorldWideName) -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":" }}, 
                                                    @{L = 'Port WWN'; E = {([String]::Format("{0:X}", $_.PortWorldWideName) -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":" }}, speed, status
                                                    $VMHostHbaFC | Table -Name "$VMhost FC Storage Adapters"
                                                }

                                                $VMHostHbaISCSI = $VMhost | Get-VMHostHba -Type iSCSI
                                                if ($VMHostHbaISCSI) {
                                                    Paragraph ("The following table details the iSCSI storage " +
                                                        "adapters for $VMhost.")
                                                    Blankline
                                                    $VMHostHbaISCSI = $VMhost | Get-VMHostHba -Type iSCSI | Sort-Object Device | Select-Object Device, @{L = 'iSCSI Name'; E = {$_.IScsiName}}, Model, Driver, @{L = 'Speed'; E = {$_.CurrentSpeedMb}}, status
                                                    $VMHostHbaISCSI | Table -Name "$VMhost iSCSI Storage Adapters" -List -ColumnWidths 30, 70
                                                }
                                            }
                                        }
                                        #endregion ESXi Host Storage Adapater Information
                                    }
                                    #endregion ESXi Host Storage Section

                                    #region ESXi Host Network Section
                                    Section -Style Heading4 'Network' {
                                        Paragraph ("The following section provides information on the host " +
                                            "network configuration of $VMhost.")
                                        BlankLine
                                        #region ESXi Host Network Configuration
                                        $VMHostNetwork = $VMhost | Get-VMHostNetwork | Select-Object  VMHost, @{L = 'Virtual Switches'; E = {($_.VirtualSwitch) -join ", "}}, @{L = 'VMKernel Adapters'; E = {($_.VirtualNic) -join ", "}}, 
                                        @{L = 'Physical Adapters'; E = {($_.PhysicalNic) -join ", "}}, @{L = 'VMKernel Gateway'; E = {$_.VMKernelGateway}}, @{L = 'IPv6 Enabled'; E = {$_.IPv6Enabled}}, 
                                        @{L = 'VMKernel IPv6 Gateway'; E = {$_.VMKernelV6Gateway}}, @{L = 'DNS Servers'; E = {($_.DnsAddress) -join ", "}}, @{L = 'Host Name'; E = {$_.HostName}}, 
                                        @{L = 'Domain Name'; E = {$_.DomainName}}, @{L = 'Search Domain'; E = {($_.SearchDomain) -join ", "}}
                                        if ($Healthcheck.VMHost.IPv6Enabled) {
                                            $VMHostNetwork | Where-Object {$_.'IPv6 Enabled' -eq $false} | Set-Style -Style Warning -Property 'IPv6 Enabled'
                                        }
                                        $VMHostNetwork | Table -Name "$VMhost Host Network Configuration" -List -ColumnWidths 50, 50
                                        #endregion ESXi Host Network Configuration

                                        #region ESXi Host Physical Adapters
                                        Section -Style Heading5 'Physical Adapters' {
                                            Paragraph ("The following table details the physical network " +
                                                "adapters for $VMhost.")
                                            BlankLine

                                            $PhysicalAdapter = $VMhost | Get-VMHostNetworkAdapter -Physical | Select-Object @{L = 'Device Name'; E = {$_.DeviceName}}, @{L = 'MAC Address'; E = {$_.Mac}}, @{L = 'Bitrate/Second'; E = {$_.BitRatePerSec}}, 
                                            @{L = 'Full Duplex'; E = {$_.FullDuplex}}, @{L = 'Wake on LAN Support'; E = {$_.WakeOnLanSupported}}
                                            $PhysicalAdapter | Table -Name "$VMhost Physical Adapters" -ColumnWidths 20, 20, 20, 20, 20
                                        }
                                        #endregion ESXi Host Physical Adapters
                                        
                                        #region ESXi Host Cisco Discovery Protocol
                                        $CDPInfo = $VMhost | Get-VMHostNetworkAdapterCDP | Where-Object {$_.Connected -eq $true}
                                        if ($CDPInfo) {
                                            Section -Style Heading5 'Cisco Discovery Protocol' {
                                                $CDPInfo = $CDPInfo | Select-Object NIC, Connected, Switch, @{L = 'Hardware Platform'; E = {$_.HardwarePlatform}}, @{L = 'Port ID'; E = {$_.PortId}}
                                                $CDPInfo | Table -Name "$VMhost CDP Information" -ColumnWidths 20, 20, 20, 20, 20
                                            }
                                        }
                                        #endregion ESXi Host Cisco Discovery Protocol

                                        #region ESXi Host VMkernel Adapaters
                                        Section -Style Heading5 'VMkernel Adapters' {
                                            Paragraph "The following table details the VMkernel adapters for $VMhost"
                                            BlankLine

                                            $VMHostNetworkAdapter = $VMhost | Get-VMHostNetworkAdapter -VMKernel | Sort-Object DeviceName | Select-Object @{L = 'Device Name'; E = {$_.DeviceName}}, @{L = 'Network Label'; E = {$_.PortGroupName}}, @{L = 'MTU'; E = {$_.Mtu}}, 
                                            @{L = 'MAC Address'; E = {$_.Mac}}, @{L = 'IP Address'; E = {$_.IP}}, @{L = 'Subnet Mask'; E = {$_.SubnetMask}}, 
                                            @{L = 'vMotion Traffic'; E = {$_.vMotionEnabled}}, @{L = 'FT Logging'; E = {$_.FaultToleranceLoggingEnabled}}, 
                                            @{L = 'Management Traffic'; E = {$_.ManagementTrafficEnabled}}, @{L = 'vSAN Traffic'; E = {$_.VsanTrafficEnabled}}
                                            $VMHostNetworkAdapter | Table -Name "$VMhost VMkernel Adapters" -List -ColumnWidths 50, 50 
                                        }
                                        #endregion ESXi Host VMkernel Adapaters

                                        #region ESXi Host Virtual Switches
                                        $VSSwitches = $VMhost | Get-VirtualSwitch -Standard | Sort-Object Name
                                        if ($VSSwitches) {
                                            Section -Style Heading5 'Standard Virtual Switches' {
                                                Paragraph ("The following sections detail the standard virtual " +
                                                    "switch configuration for $VMhost.")
                                                BlankLine
                                                $VSSGeneral = $VSSwitches | Get-NicTeamingPolicy | Select-Object @{L = 'Name'; E = {$_.VirtualSwitch}}, @{L = 'MTU'; E = {$_.VirtualSwitch.Mtu}}, @{L = 'Number of Ports'; E = {$_.VirtualSwitch.NumPorts}}, 
                                                @{L = 'Number of Ports Available'; E = {$_.VirtualSwitch.NumPortsAvailable}}, @{L = 'Load Balancing'; E = {$_.LoadBalancingPolicy}}, @{L = 'Failover Detection'; E = {$_.NetworkFailoverDetectionPolicy}}, 
                                                @{L = 'Notify Switches'; E = {$_.NotifySwitches}}, @{L = 'Failback Enabled'; E = {$_.FailbackEnabled}}, @{L = 'Active NICs'; E = {($_.ActiveNic) -join ", "}}, 
                                                @{L = 'Standby NICs'; E = {($_.StandbyNic) -join ", "}}, @{L = 'Unused NICs'; E = {($_.UnusedNic) -join ", "}}
                                                $VSSGeneral | Table -Name "$VMhost Standard Virtual Switches" -List -ColumnWidths 50, 50
                                            }
                                            #region ESXi Host Virtual Switch Security Policy
                                            $VSSSecurity = $VSSwitches | Get-SecurityPolicy
                                            if ($VSSSecurity) {
                                                Section -Style Heading5 'Virtual Switch Security Policy' {
                                                    $VSSSecurity = $VSSSecurity | Select-Object @{L = 'vSwitch'; E = {$_.VirtualSwitch}}, @{L = 'MAC Address Changes'; E = {$_.MacChanges}}, @{L = 'Forged Transmits'; E = {$_.ForgedTransmits}}, 
                                                    @{L = 'Promiscuous Mode'; E = {$_.AllowPromiscuous}} | Sort-Object vSwitch
                                                    $VSSSecurity | Table -Name "$VMhost vSwitch Security Policy" 
                                                }
                                            }
                                            #endregion ESXi Host Virtual Switch Security Policy                  

                                            #region ESXi Host Virtual Switch NIC Teaming
                                            $VSSPortgroupNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                                            if ($VSSPortgroupNicTeaming) {
                                                Section -Style Heading5 'Virtual Switch NIC Teaming' {
                                                    $VSSPortgroupNicTeaming = $VSSPortgroupNicTeaming | Select-Object @{L = 'vSwitch'; E = {$_.VirtualSwitch}}, @{L = 'Load Balancing'; E = {$_.LoadBalancingPolicy}}, 
                                                    @{L = 'Failover Detection'; E = {$_.NetworkFailoverDetectionPolicy}}, @{L = 'Notify Switches'; E = {$_.NotifySwitches}}, @{L = 'Failback Enabled'; E = {$_.FailbackEnabled}}, @{L = 'Active NICs'; E = {($_.ActiveNic) -join [Environment]::NewLine}}, 
                                                    @{L = 'Standby NICs'; E = {($_.StandbyNic) -join [Environment]::NewLine}}, @{L = 'Unused NICs'; E = {($_.UnusedNic) -join [Environment]::NewLine}} | Sort-Object vSwitch
                                                    $VSSPortgroupNicTeaming | Table -Name "$VMhost vSwitch NIC Teaming" #-ColumnWidths 12,16,12,12,12,12,12,12
                                                }
                                            }
                                            #endregion ESXi Host Virtual Switch NIC Teaming                       
                            
                                            #region ESXi Host Virtual Switch Port Groups
                                            $VSSPortgroups = $VSSwitches | Get-VirtualPortGroup -Standard
                                            if ($VSSPortgroups) {
                                                Section -Style Heading5 'Virtual Port Groups' {
                                                    $VSSPortgroups = $VSSPortgroups | Select-Object @{L = 'vSwitch'; E = {$_.VirtualSwitchName}}, @{L = 'Portgroup'; E = {$_.Name}}, @{L = 'VLAN ID'; E = {$_.VLanId}}, @{L = '# of VMs'; E = {(($_ | Get-VM).count)}} | Sort-Object vSwitch, Portgroup
                                                    $VSSPortgroups | Table -Name "$VMhost vSwitch Port Group Information" 
                                                }
                                            }
                                            #endregion ESXi Host Virtual Switch Port Groups                
                            
                                            #region ESXi Host Virtual Switch Port Group Security Poilicy
                                            $VSSPortgroupSecurity = $VSSwitches | Get-VirtualPortGroup | Get-SecurityPolicy 
                                            if ($VSSPortgroupSecurity) {
                                                Section -Style Heading5 'Virtual Port Group Security Policy' {
                                                    $VSSPortgroupSecurity = $VSSPortgroupSecurity | Select-Object @{L = 'vSwitch'; E = {$_.virtualportgroup.virtualswitchname}}, @{L = 'Portgroup'; E = {$_.VirtualPortGroup}}, @{L = 'MAC Changes'; E = {$_.MacChanges}}, 
                                                    @{L = 'Forged Transmits'; E = {$_.ForgedTransmits}}, @{L = 'Promiscuous Mode'; E = {$_.AllowPromiscuous}} | Sort-Object vSwitch, VirtualPortGroup
                                                    $VSSPortgroupSecurity | Table -Name "$VMhost vSwitch Port Group Security Policy" 
                                                }
                                            } 
                                            #endregion ESXi Host Virtual Switch Port Group Security Poilicy                 

                                            #region ESXi Host Virtual Switch Port Group NIC Teaming
                                            $VSSPortgroupNicTeaming = $VSSwitches | Get-VirtualPortGroup  | Get-NicTeamingPolicy 
                                            if ($VSSPortgroupNicTeaming) {
                                                Section -Style Heading5 'Virtual Port Group NIC Teaming' {
                                                    $VSSPortgroupNicTeaming = $VSSPortgroupNicTeaming | Select-Object @{L = 'vSwitch'; E = {$_.virtualportgroup.virtualswitchname}}, @{L = 'Portgroup'; E = {$_.VirtualPortGroup}}, @{L = 'Load Balancing'; E = {$_.LoadBalancingPolicy}}, 
                                                    @{L = 'Failover Detection'; E = {$_.NetworkFailoverDetectionPolicy}}, @{L = 'Notify Switches'; E = {$_.NotifySwitches}}, @{L = 'Failback Enabled'; E = {$_.FailbackEnabled}}, @{L = 'Active NICs'; E = {($_.ActiveNic) -join [Environment]::NewLine}}, 
                                                    @{L = 'Standby NICs'; E = {($_.StandbyNic) -join [Environment]::NewLine}}, @{L = 'Unused NICs'; E = {($_.UnusedNic) -join [Environment]::NewLine}} | Sort-Object vSwitch, VirtualPortGroup
                                                    $VSSPortgroupNicTeaming | Table -Name "$VMhost vSwitch Port Group NIC Teaming" #-ColumnWidths 11,12,11,11,11,11,11,11,11
                                                }
                                            }  
                                            #endregion ESXi Host Virtual Switch Port Group NIC Teaming                      
                                        }
                                        #endregion ESXi Host Standard Virtual Switches
                                    }                
                                    #endregion ESXi Host Network Configuration

                                    #region ESXi Host Security Section
                                    Section -Style Heading4 'Security' {
                                        Paragraph ("The following section provides information on the host " +
                                            "security configuration of $VMhost.")
                                        
                                        #region ESXi Host Lockdown Mode
                                        Section -Style Heading5 'Lockdown Mode' {
                                            $LockDownMode = $VMhost | Get-View | Select-Object @{L = 'Lockdown Mode'; E = {$_.Config.AdminDisabled}}
                                            $LockDownMode | Table -Name "$VMhost Lockdown Mode" -List -ColumnWidths 50, 50
                                        }
                                        #endregion ESXi Host Lockdown Mode

                                        #region ESXi Host Services
                                        Section -Style Heading5 'Services' {
                                            $Services = $VMhost | Get-VMHostService | Sort-Object Key | Select-Object @{L = 'Name'; E = {$_.Key}}, Label, Policy, Running, Required
                                            if ($Healthcheck.VMhost.Services) {
                                                $Services | Where-Object {$_.'Name' -eq 'TSM-SSH' -and $_.Running} | Set-Style -Style Warning
                                                $Services | Where-Object {$_.'Name' -eq 'TSM' -and $_.Running} | Set-Style -Style Warning
                                                $Services | Where-Object {$_.'Name' -eq 'ntpd' -and $_.Running -eq $False} | Set-Style -Style Critical
                                            }
                                            $Services | Table -Name "$VMhost Services" 
                                        }
                                        #endregion ESXi Host Services

                                        if ($InfoLevel.VMhost -ge 4) {
                                            #region ESXi Host Firewall
                                            Section -Style Heading5 'Firewall' {
                                                $Firewall = $VMhost | Get-VMHostFirewallException | Sort-Object Name | Select-Object Name, Enabled, @{L = 'Incoming Ports'; E = {$_.IncomingPorts}}, @{L = 'Outgoing Ports'; E = {$_.OutgoingPorts}}, Protocols, @{L = 'Service Running'; E = {$_.ServiceRunning}}
                                                $Firewall | Table -Name "$VMhost Firewall Configuration" 
                                            }
                                            #endregion ESXi Host Firewall
                                        }
                        
                                        #region ESXi Host Authentication
                                        $AuthServices = $VMhost | Get-VMHostAuthentication
                                        if ($AuthServices.DomainMembershipStatus) {
                                            Section -Style Heading5 'Authentication Services' {
                                                $AuthServices = $AuthServices | Select-Object Domain, @{L = 'Domain Membership'; E = {$_.DomainMembershipStatus}}, @{L = 'Trusted Domains'; E = {$_.TrustedDomains}}
                                                $AuthServices | Table -Name "$VMhost Authentication Services" -ColumnWidths 25, 25, 50 
                                            }    
                                        }
                                        #endregion ESXi Host Authentication
                                    }
                                    #endregion ESXi Host Security Section

                                    #region ESXi Host Virtual Machines Section
                                    if ($InfoLevel.VMhost -ge 4) {
                                        $VMHostVM = $VMhost | Get-VM
                                        if ($VMHostVM) {
                                            Section -Style Heading4 'Virtual Machines' {
                                                Paragraph ("The following section provides information on the " +
                                                    "virtual machine settings for $VMhost.")
                                                Blankline
                                                #region ESXi Host Virtual Machine Summary Information
                                                $VMHostVM = $VMHostVM | Sort-Object Name | Select-Object Name, @{L = 'Power State'; E = {$_.powerstate}}, @{L = 'CPUs'; E = {$_.NumCpu}}, @{L = 'Cores per Socket'; E = {$_.CoresPerSocket}}, @{L = 'Memory GB'; E = {[math]::Round(($_.memoryGB), 2)}}, @{L = 'Provisioned GB'; E = {[math]::Round(($_.ProvisionedSpaceGB), 2)}}, 
                                                @{L = 'Used GB'; E = {[math]::Round(($_.UsedSpaceGB), 2)}}, @{L = 'HW Version'; E = {$_.version}}, @{L = 'VM Tools Status'; E = {$_.ExtensionData.Guest.ToolsStatus}}
                                                if ($Healthcheck.VM.VMTools) {
                                                    $VMHostVM | Where-Object {$_.'VM Tools Status' -eq 'toolsNotInstalled' -or $_.'VM Tools Status' -eq 'toolsOld'} | Set-Style -Style Warning -Property 'VM Tools Status'
                                                }
                                                $VMHostVM | Table -Name "$VMhost VM Summary" #-ColumnWidths 15,10,10,10,10,10,10,10,15
                                                #endregion ESXi Host Virtual Machine Summary Information

                                                #region ESXi Host VM Startup/Shutdown Information
                                                $VMStartPolicy = $VMhost | Get-VMStartPolicy | Where-Object {$_.StartAction -ne 'None'}
                                                if ($VMStartPolicy) {
                                                    Section -Style Heading5 'VM Startup/Shutdown' {
                                                        $VMStartPolicies = $VMStartPolicy | Select-Object @{L = 'VM Name'; E = {$_.VirtualMachineName}}, @{L = 'Start Action'; E = {$_.StartAction}}, 
                                                        @{L = 'Start Delay'; E = {$_.StartDelay}}, @{L = 'Start Order'; E = {$_.StartOrder}}, @{L = 'Stop Action'; E = {$_.StopAction}}, @{L = 'Stop Delay'; E = {$_.StopDelay}}, 
                                                        @{L = 'Wait for Heartbeat'; E = {$_.WaitForHeartbeat}}
                                                        $VMStartPolicies | Table -Name "$VMhost VM Startup/Shutdown Policy" 
                                                    }
                                                }
                                                #endregion ESXi Host VM Startup/Shutdown Information
                                            }
                                        }
                                    }
                                    #endregion ESXi Host Virtual Machines Section
                                }
                            }
                            #endregion ESXi Host Detailed Information
                        }
                    }
                    if ($InfoLevel.VMHost -ge 3) {
                        PageBreak
                    }    
                }
            }
            #endregion ESXi VMHost Section 

            #region Distributed Switch Section
            if ($InfoLevel.Network -ge 1) {
                # Create Distributed Virtual Switch Section if they exist
                $Script:VDSwitches = Get-VDSwitch -Server $vCenter
                if ($VDSwitches) {
                    Section -Style Heading2 'Distributed Virtual Switches' {
                        Paragraph ("The following section provides information on the Distributed Virtual " +
                            "Switches managed by vCenter Server $VCServerFQDN.")
                        BlankLine
                        
                        #region Distributed Virtual Switch Condensed Information
                        if ($InfoLevel.Network -eq 2) {
                            $VDSSummary = $VDSwitches | Select-Object @{L = 'VDSwitch'; E = {$_.Name}}, Datacenter, @{L = 'Manufacturer'; E = {$_.Vendor}}, Version, @{L = '# of Uplinks'; E = {$_.NumUplinkPorts}}, @{L = '# of Ports'; E = {$_.NumPorts}}, 
                            @{L = '# of Hosts'; E = {(($_ | Get-VMhost).count)}}, @{L = '# of VMs'; E = {(($_ | Get-VM).count)}}       
                            $VDSSummary | Table -Name 'Distributed Virtual Switch Summary'
                        }    
                        #endregion Distributed Virtual Switch Condensed Information

                        if ($InfoLevel.Network -ge 3) {
                            #region Distributed Virtual Switch Detailed Information
                            ## TODO: LACP, NetFlow, NIOC
                            foreach ($VDS in ($VDSwitches)) {
                                Section -Style Heading3 $VDS {
                                    #region Distributed Virtual Switch General Properties  
                                    Section -Style Heading4 'General Properties' {
                                        $VDSwitchSpecs = Get-VDSwitch $VDS | Select-Object Name, id, Datacenter, @{L = 'Manufacturer'; E = {$_.Vendor}}, Version, @{L = 'Number of Uplinks'; E = {$_.NumUplinkPorts}}, 
                                        @{L = 'Number of Ports'; E = {$_.NumPorts}}, @{L = 'Number of Hosts'; E = {($_ | Get-VMhost).count}}, @{L = 'Number of VMs'; E = {($_ | Get-VM).count}}, 
                                        @{L = 'MTU'; E = {$_.Mtu}}, @{L = 'Network I/O Control Enabled'; E = {$_.ExtensionData.Config.NetworkResourceManagementEnabled}}, 
                                        @{L = 'Discovery Protocol'; E = {$_.LinkDiscoveryProtocol}}, @{L = 'Discovery Protocol Operation'; E = {$_.LinkDiscoveryProtocolOperation}}
                                        if ($InfoLevel.Network -ge 3) {
                                            $VDSwitchSpecs | ForEach-Object {
                                                $VDSwitchHosts = $VDS | Get-VMhost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($VDSwitchHosts.Name -join ", ")
                                                $VDSwitchVMs = $VDS | Get-VM | Sort-Object Name 
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($VDSwitchVMs.Name -join ", ")
                                            }
                                        }
                                        $VDSwitchSpecs | Table -Name "$VDS General Properties" -List -ColumnWidths 50, 50 
                                    }
                                    #endregion Distributed Virtual Switch General Properties

                                    #region Distributed Virtual Switch Uplinks
                                    $VdsUplinks = $VDS | Get-VDPortgroup | Where-Object {$_.IsUplink -eq $true} | Get-VDPort
                                    if ($VdsUplinks) {
                                        Section -Style Heading4 'Uplinks' {
                                            $VdsUplinks = $VdsUplinks | Sort-Object Switch, ProxyHost, Name | Select-Object @{L = 'VDSwitch'; E = {$_.Switch}}, @{L = 'VM Host'; E = {$_.ProxyHost}}, @{L = 'Uplink Name'; E = {$_.Name}}, @{L = 'Physical Network Adapter'; E = {$_.ConnectedEntity}}, @{L = 'Uplink Port Group'; E = {$_.Portgroup}}
                                            $VdsUplinks | Table -Name "$VDS Uplinks"
                                        }
                                    }
                                    #endregion Distributed Virtual Switch Uplinks               
                                    
                                    #region Distributed Virtual Switch Security
                                    Section -Style Heading4 'Security' {
                                        $VDSSecurity = $VDS | Get-VDSecurityPolicy | Select-Object VDSwitch, @{L = 'Allow Promiscuous'; E = {$_.AllowPromiscuous}}, @{L = 'Forged Transmits'; E = {$_.ForgedTransmits}}, @{L = 'MAC Address Changes'; E = {$_.MacChanges}}
                                        $VDSSecurity | Table -Name "$VDS Security" 
                                    }
                                    #endregion Distributed Virtual Switch Security

                                    #region Distributed Virtual Switch Traffic Shaping
                                    Section -Style Heading4 'Traffic Shaping' {
                                        $VDSTrafficShaping = $VDS | Get-VDTrafficShapingPolicy -Direction Out
                                        [Array]$VDSTrafficShaping += $VDS | Get-VDTrafficShapingPolicy -Direction In
                                        $VDSTrafficShaping = $VDSTrafficShaping | Sort-Object Direction | Select-Object VDSwitch, Direction, Enabled, @{L = 'Average Bandwidth (kbit/s)'; E = {$_.AverageBandwidth}}, @{L = 'Peak Bandwidth (kbit/s)'; E = {$_.PeakBandwidth}}, @{L = 'Burst Size (KB)'; E = {$_.BurstSize}}
                                        $VDSTrafficShaping | Table -Name "$VDS Traffic Shaping"
                                    }
                                    #endregion Distributed Virtual Switch Traffic Shaping

                                    #region Distributed Virtual Switch Port Groups
                                    Section -Style Heading4 'Port Groups' {
                                        $VDSPortgroups = $VDS | Get-VDPortgroup | Sort-Object Name | Select-Object VDSwitch, @{L = 'Portgroup'; E = {$_.Name}}, Datacenter, @{L = 'VLAN Configuration'; E = {$_.VlanConfiguration}}, @{L = 'Port Binding'; E = {$_.PortBinding}}, @{L = '# of Ports'; E = {$_.NumPorts}}
                                        $VDSPortgroups | Table -Name "$VDS Port Group Information" 
                                    }
                                    #endregion Distributed Virtual Switch Port Groups

                                    #region Distributed Virtual Switch Port Group Security
                                    Section -Style Heading5 "Port Group Security" {
                                        $VDSPortgroupSecurity = $VDS | Get-VDPortgroup | Get-VDSecurityPolicy | Select-Object @{L = 'VDSwitch'; E = {($VDS.Name)}} , @{L = 'Port Group'; E = {$_.VDPortgroup}}, @{L = 'Allow Promiscuous'; E = {$_.AllowPromiscuous}}, @{L = 'Forged Transmits'; E = {$_.ForgedTransmits}}, @{L = 'MAC Address Changes'; E = {$_.MacChanges}}
                                        $VDSPortgroupSecurity | Table -Name "$VDS Portgroup Security"
                                    }
                                    #endregion Distributed Virtual Switch Port Group Security
                    
                                    #region Distributed Virtual Switch Port Group NIC Teaming
                                    Section -Style Heading5 "Port Group NIC Teaming" {
                                        $VDSPortgroupNICTeaming = $VDS | Get-VDPortgroup | Get-VDUplinkTeamingPolicy | Sort-Object VDPortgroup | Select-Object @{L = 'VDSwitch'; E = {($VDS.Name)}} , @{L = 'Port Group'; E = {$_.VDPortgroup}}, @{L = 'Load Balancing'; E = {$_.LoadBalancingPolicy}}, @{L = 'Failover Detection'; E = {$_.FailoverDetectionPolicy}}, 
                                        @{L = 'Notify Switches'; E = {$_.NotifySwitches}}, @{L = 'Failback Enabled'; E = {$_.EnableFailback}}, @{L = 'Active Uplinks'; E = {($_.ActiveUplinkPort) -join [Environment]::NewLine}}, @{L = 'Standby Uplinks'; E = {($_.StandbyUplinkPort) -join [Environment]::NewLine}}, @{L = 'Unused Uplinks'; E = {@($_.UnusedUplinkPort) -join [Environment]::NewLine}}
                                        $VDSPortgroupNICTeaming | Table -Name "$VDS Portgroup NIC Teaming" #-ColumnWidths 12,11,11,11,11,11,11,11,11
                                    }
                                    #endregion Distributed Virtual Switch Port Group NIC Teaming

                                    #region Distributed Virtual Switch Private VLANs
                                    $VDSPvlan = $VDS | Get-VDSwitchPrivateVLAN | Sort-Object PrimaryVlanId, PrivateVlanType, SecondaryVlanId | Select-Object @{L = 'Primary VLAN ID'; E = {$_.PrimaryVlanId}}, @{L = 'Private VLAN Type'; E = {$_.PrivateVlanType}}, @{L = 'Secondary VLAN ID'; E = {$_.SecondaryVlanId}}
                                    if ($VDSPvlan) {
                                        Section -Style Heading4 'Private VLANs' {
                                            $VDSPvlan | Table -Name "$VDS Private VLANs"
                                        }
                                    }
                                    #endregion Distributed Virtual Switch Private VLANs            
                                }
                            }
                            #endregion Distributed Virtual Switch Detailed Information
                        }
                    }
                    if ($InfoLevel.Network -ge 3) {
                        PageBreak
                    }
                }
            }
            #endregion Distributed Switch Section

            #region vSAN Section
            if ($InfoLevel.Vsan -ge 1) {
                $Script:VsanClusters = Get-VsanClusterConfiguration -Server $vCenter | Where-Object {$_.vsanenabled -eq $true}
                if ($VsanClusters) {
                    Section -Style Heading2 'vSAN' {
                        Paragraph ("The following section provides information on the vSAN managed " +
                            "by vCenter Server $VCServerFQDN.")
                        BlankLine

                        #region vSAN Cluster Condensed Information
                        if ($InfoLevel.Vsan -eq 2) {
                            $VsanClusterSummary = $VsanClusters | Select-Object Name, @{L = 'vSAN Enabled'; E = {$_.VsanEnabled}}, @{L = 'Stretched Cluster Enabled'; E = {$_.StretchedClusterEnabled}},
                            @{L = 'Space Efficiency Enabled'; E = {$_.SpaceEfficiencyEnabled}}, @{L = 'Encryption Enabled'; E = {$_.EncryptionEnabled}}, @{L = 'Health Check Enabled'; E = {$_.HealthCheckEnabled}}
                            $VsanClusterSummary | Table -Name 'vSAN Cluster Summary'
                        }
                        #endregion vSAN Cluster Condensed Information

                        if ($InfoLevel.Vsan -ge 3) {
                            #region vSAN Cluster Detailed Information
                            foreach ($VsanCluster in $VsanClusters) {
                                $VsanClusterName = $VsanCluster.Name
                                Section -Style Heading3 $VsanClusterName {
                                    $VsanDiskGroup = Get-VsanDiskGroup -Cluster $VsanClusterName
                                    $NumVsanDiskGroup = $VsanDiskGroup.Count
                                    $VsanDisk = Get-vSanDisk -VsanDiskGroup $VsanDiskGroup
                                    $VsanDiskFormat = $VsanDisk.DiskFormatVersion | Select-Object -First 1 -Unique
                                    $NumVsanDisk = ($VsanDisk | Where-Object {$_.IsSsd -eq $true}).Count
                                    if ($VsanDisk.IsSsd -eq $true -and $VsanDisk.IsCacheDisk -eq $false) {
                                        $VsanClusterType = "All-Flash"
                                    } else {
                                        $VsanClusterType = "Hybrid"
                                    }
                                    $VsanHashTable += [PSCustomObject]@{
                                        'Name' = $VsanClusterName
                                        'Id' = $VsanCluster.Id
                                        'VsanClusterType' = $VsanClusterType
                                        #'Version'                 = ((Get-VsanView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system").VsanVcClusterQueryVerifyHealthSystemVersions(($VsanCluster).Id)).VcVersion
                                        'StretchedClusterEnabled' = $VsanCluster.StretchedClusterEnabled
                                        'HostCount' = ($VsanDiskGroup.VMHost).Count
                                        'DiskFormat' = $VsanDiskFormat
                                        'NumVsanDisk' = $NumVsanDisk
                                        'NumVsanDiskGroup' = $NumVsanDiskGroup
                                        'VsanDiskClaimMode' = $VsanCluster.VsanDiskClaimMode
                                        'SpaceEfficiencyEnabled' = $VsanCluster.SpaceEfficiencyEnabled
                                        'EncryptionEnabled' = $VsanCluster.EncryptionEnabled
                                        'HealthCheckEnabled' = $VsanCluster.HealthCheckEnabled
                                        'TimeOfHclUpdate' = $VsanCluster.TimeOfHclUpdate
                                    }
                                    $VsanClusterSpecs = $VsanHashTable | Select-Object Name, Id, @{L = 'Type'; E = {$_.VsanClusterType}}, Version, @{L = 'Number of Hosts'; E = {$_.HostCount}}, @{L = 'Stretched Cluster'; E = {$_.StretchedClusterEnabled}}, @{L = 'Disk Format Version'; E = {$_.DiskFormat}}, 
                                    @{L = 'Total Number of Disks'; E = {$_.NumVsanDisk}}, @{L = 'Total Number of Disk Groups'; E = {$_.NumVsanDiskGroup}}, @{L = 'Disk Claim Mode'; E = {$_.VsanDiskClaimMode}}, @{L = 'Deduplication and Compression'; E = {$_.SpaceEfficiencyEnabled}}, 
                                    @{L = 'Encryption Enabled'; E = {$_.EncryptionEnabled}}, @{L = 'Health Check Enabled'; E = {$_.HealthCheckEnabled}}, @{L = 'HCL Last Updated'; E = {$_.TimeOfHclUpdate}}
                                    # Set InfoLevel to 4 or above to provide information for associated VMHosts
                                    if ($InfoLevel.Vsan -ge 4) {
                                        Add-Member -InputObject $VsanClusterSpecs -MemberType NoteProperty -Name 'Hosts' -Value (($VsanDiskGroup.VMHost | Sort-Object VMHost) -join ", ")
                                    }
                                    $VsanClusterSpecs | Table -Name "$VsanClusterName vSAN Configuration" -List -ColumnWidths 50, 50
                                }  
                            }
                            #endregion vSAN Cluster Detailed Information
                        }
                    }
                    if ($InfoLevel.Vsan -ge 3) {
                        PageBreak
                    }
                }
            }
            #endregion vSAN Section

            #region Datastore Section
            if ($InfoLevel.Datastore -ge 1) {
                $Script:Datastores = Get-Datastore -Server $vCenter | Where-Object {$_.Accessible -eq $true}
                if ($Datastores) {
                    Section -Style Heading2 'Datastores' {
                        Paragraph ("The following section provides information on datastores managed " +
                            "by vCenter Server $VCServerFQDN.")
                        BlankLine

                        #region Datastore Condensed Information
                        if ($InfoLevel.Datastore -eq 2) {
                            $DatastoreSummary = foreach ($Datastore in $Datastores) {
                                [PSCustomObject] @{
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
                                foreach ($DatastoreSumm in $DatastoreSummary) {
                                    if ($DatastoreSumm.'% Used' -ge 90) {
                                        $DatastoreSumm | Set-Style -Style Critical -Property '% Used'
                                    } elseif ($DatastoreSumm.'% Used' -ge 75 -and 
                                        $DatastoreSumm.'% Used' -lt 90) {
                                        $DatastoreSumm | Set-Style -Style Warning -Property '% Used'
                                    }
                                }
                            }
                            $DatastoreSummary | Sort-Object Name | Table -Name 'Datastore Summary'
                        }
                        #endregion Datastore Condensed Information
                        
                        #region Datastore Detailed Information
                        if ($InfoLevel.Datastore -ge 3) {
                            foreach ($Datastore in $Datastores) {
                                Section -Style Heading3 $Datastore.Name {                                
                                    $DatastoreSpecs = [PSCustomObject] @{
                                        'Name' = $Datastore.Name
                                        'Id' = $Datastore.Id
                                        'Datacenter' = $Datastore.Datacenter
                                        'Type' = $Datastore.Type
                                        'Version' = $Datastore.FileSystemVersion
                                        'State' = $Datastore.State
                                        'Number of Hosts' = $Datastore.ExtensionData.Host.Count
                                        'Number of VMs' = $Datastore.ExtensionData.VM.Count
                                        'SIOC Enabled' = $Datastore.StorageIOControlEnabled
                                        'Congestion Threshold (ms)' = $Datastore.CongestionThresholdMillisecond
                                        'Total Capacity' = "$([math]::Round($Datastore.CapacityGB, 2)) GB"
                                        'Used Capacity' = "$([math]::Round((($Datastore.CapacityGB) - 
                                                                            ($Datastore.FreeSpaceGB)), 2)) GB"
                                        'Free Space' = "$([math]::Round($Datastore.FreeSpaceGB, 2)) GB"
                                        '% Used' = [math]::Round(
                                            (100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2
                                        )
                                    }
                                    if ($Healthcheck.Datastore.CapacityUtilization) {
                                        foreach ($DatastoreSpec in $DatastoreSpecs) {
                                            if ($DatastoreSpec.'% Used' -ge 90) {
                                                $DatastoreSpec | Set-Style -Style Critical -Property '% Used'
                                            } elseif ($DatastoreSpec.'% Used' -ge 75 -and 
                                                $DatastoreSpec.'% Used' -lt 90) {
                                                $DatastoreSpec | Set-Style -Style Warning -Property '% Used'
                                            }
                                        }
                                    }
                                    # Set InfoLevel to 4 or above to provide information for associated VMHosts & VMs
                                    if ($InfoLevel.Datastore -ge 4) {
                                        $MemberProps = @{
                                            'InputObject' = $DatastoreSpecs
                                            'MemberType' = 'NoteProperty'
                                        }
                                        $DatastoreHosts = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                            $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                        }
                                        Add-Member @MemberProps -Name 'Hosts' -Value ($DatastoreHosts -join ', ')
                                        $DatastoreVMs = foreach ($DatastoreVM in $Datastore.ExtensionData.VM) {
                                            $VMLookup."$($DatastoreVM.Type)-$($DatastoreVM.Value)"
                                        }
                                        Add-Member @MemberProps -Name 'Virtual Machines' -Value ($DatastoreVMs -join ', ')
                                    }
                                    $TableProps = @{
                                        'Name' = 'Datastore Specifications'
                                        'List' = $true
                                        'ColumnWidths' = 50, 50
                                    }
                                    $DatastoreSpecs | Sort-Object Datacenter, Name | Table @TableProps

                                    # Get VMFS volumes. Ignore local SCSILuns.
                                    if (($Datastore.Type -eq 'VMFS') -and
                                        ($Datastore.ExtensionData.Info.Vmfs.Local -eq $false)) {
                                        Section -Style Heading4 'SCSI LUN Information' {
                                            $ScsiLuns = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                $DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
                                                $ScsiDeviceDetailProps = @{
                                                    'VMHosts' = $VMhosts
                                                    'VMHostMoRef' = "$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                    'DatastoreDiskName' = $DiskName
                                                }
                                                $ScsiDeviceDetail = Get-ScsiDeviceDetail @ScsiDeviceDetailProps

                                                [PSCustomObject] @{
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
                    if ($InfoLevel.Datastore -ge 3) {
                        PageBreak
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
                            "managed by vCenter Server $VCServerFQDN.")
                        BlankLine

                        #region Datastore Cluster Condensed Information
                        if ($InfoLevel.DSCluster -eq 2) {
                            $DSClusterSummary = foreach ($DSCluster in $DSClusters) {
                                [PSCustomObject] @{
                                    'Name' = $DSCluster.Name
                                    'SDRS Automation Level' = $DSCluster.SdrsAutomationLevel
                                    'Space Utilization Threshold %' = $DSCluster.SpaceUtilizationThresholdPercent
                                    'I/O Load Balance Enabled' = $DSCluster.IOLoadBalanceEnabled
                                    'I/O Latency Threshold (ms)' = $DSCluster.IOLatencyThresholdMillisecond
                                    'Capacity GB' = [math]::Round($DSCluster.CapacityGB, 2)
                                    'FreeSpace GB' = [math]::Round($DSCluster.FreeSpaceGB, 2)
                                    '% Used' = [math]::Round(
                                        (100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2
                                    )
                                }
                            }
                            if ($Healthcheck.DSCluster.CapacityUtilization) {
                                foreach ($DSClusterSumm in $DSClusterSummary) {
                                    if ($DSClusterSumm.'% Used' -ge 90) {
                                        $DSClusterSumm | Set-Style -Style Critical -Property '% Used'
                                    } elseif ($DSClusterSumm.'% Used' -ge 75 -and $DSClusterSumm.'% Used' -lt 90) {
                                        $DSClusterSumm | Set-Style -Style Critical -Property '% Used'
                                    }
                                }
                            }
                            if ($Healthcheck.DSCluster.SDRSAutomationLevel) {
                                foreach ($DSClusterSumm in $DSClusterSummary) {
                                    if ($DSClusterSumm.'SDRS Automation Level' -ne 
                                        $Healthcheck.DSCluster.SDRSAutomationLevelSetting) {
                                        $DSClusterSumm | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                    }
                                }
                            }   
                            $DSClusterSummary | Sort-Object Name | Table -Name 'Datastore Cluster Summary'
                        }
                        #endregion Datastore Cluster Condensed Information

                        if ($InfoLevel.DSCluster -ge 3) {
                            #region Datastore Cluster Detailed Information
                            foreach ($DSCluster in $DSClusters) {
                                ## TODO: Space Load Balance Config, IO Load Balance Config, VM Overrides, Rules
                                Section -Style Heading3 $DSCluster.Name {
                                    Paragraph ("The following table details the configuration " +
                                        "for datastore cluster $DSCluster.")
                                    BlankLine

                                    $DSClusterSummary = [PSCustomObject] @{
                                        'Name' = $DSCluster.Name
                                        'Id' = $DSCluster.Id
                                        'SDRS Automation Level' = $DSCluster.SdrsAutomationLevel
                                        'Space Utilization Threshold %' = $DSCluster.SpaceUtilizationThresholdPercent
                                        'I/O Load Balance Enabled' = $DSCluster.IOLoadBalanceEnabled
                                        'I/O Latency Threshold (ms)' = $DSCluster.IOLatencyThresholdMillisecond
                                        'Capacity GB' = [math]::Round($DSCluster.CapacityGB, 2)
                                        'FreeSpace GB' = [math]::Round($DSCluster.FreeSpaceGB, 2)
                                        '% Used' = [math]::Round(
                                            (100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2
                                        )
                                    }
                                    
                                    if ($Healthcheck.DSCluster.CapacityUtilization) {
                                        foreach ($DSClusterSumm in $DSClusterSummary) {
                                            if ($DSClusterSumm.'% Used' -ge 90) {
                                                $DSClusterSumm | Set-Style -Style Critical -Property '% Used'
                                            } elseif ($DSClusterSumm.'% Used' -ge 75 -and
                                                $DSClusterSumm.'% Used' -lt 90) {
                                                $DSClusterSumm | Set-Style -Style Critical -Property '% Used'
                                            }
                                        }
                                    }
                                    if ($Healthcheck.DSCluster.SDRSAutomationLevel) {
                                        foreach ($DSClusterSumm in $DSClusterSummary) {
                                            if ($DSClusterSumm.'SDRS Automation Level' -ne 
                                                $Healthcheck.DSCluster.SDRSAutomationLevelSetting) {
                                                $DSClusterSumm | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                            }
                                        }
                                    }
                                    $DSClusterSummary | Table -Name "$DSCluster Configuration" -List -ColumnWidths 50, 50
                                    
                                    #region SDRS Overrides
                                    $StoragePodProps = @{
                                        'ViewType' = 'StoragePod'
                                        'Filter' = @{'Name' = $DSCluster.Name}
                                    }
                                    $StoragePod = Get-View @StoragePodProps
                                    if ($StoragePod) {
                                        $PodConfig = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.PodConfig
                                        # Set default automation value variables
                                        Switch ($PodConfig.DefaultVmBehavior) {
                                            "automated" {$DefaultVmBehavior = "Default (Fully Automated)"}
                                            "manual" {$DefaultVmBehavior = "Default (No Automation (Manual Mode))"}
                                        }
                                        Switch ($PodConfig.DefaultIntraVmAffinity) {
                                            $true {$DefaultIntraVmAffinity = "Default (Yes)"}
                                            $false {$DefaultIntraVmAffinity = "Default (No)"}
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
                                                    $true {'Fully Automated'}
                                                    $false {'Disabled'}
                                                    $null {$DefaultVmBehavior}
                                                }
                                                'Keep VMDKs Together' = Switch ($Override.IntraVmAffinity) {
                                                    $true {'Yes'}
                                                    $false {'No'}
                                                    $null {$DefaultIntraVmAffinity}
                                                }
                                            }
                                        }
                                        Section -Style Heading4 'VM Overrides' {
                                            $VMOverrideDetails | Sort-Object 'Virtual Machine' | Table -Name 'VM Overrides'
                                        }
                                    }
                                    #endregion SDRS Overrides
                                }
                            }
                            #endregion Datastore Cluster Detailed Information
                        }
                    }
                    if ($InfoLevel.DSCluster -ge 3) {
                        PageBreak
                    }
                }
            }
            #endregion Datastore Clusters     

            #region Virtual Machine Section
            if ($InfoLevel.VM -ge 1) {
                if ($VMs) {
                    Section -Style Heading2 'Virtual Machines' {
                        Paragraph ("The following section provides information on Virtual Machines " +
                            "managed by vCenter Server $VCServerFQDN.")
                        BlankLine

                        #region Virtual Machine Condensed Information
                        if ($InfoLevel.VM -eq 2) {
                            $VMSummary = $VMs | Sort-Object Name | Select-Object Name, @{L = 'Power State'; E = {$_.powerstate}}, @{L = 'vCPUs'; E = {$_.NumCpu}}, @{L = 'Cores per Socket'; E = {$_.CoresPerSocket}}, @{L = 'Memory GB'; E = {[math]::Round(($_.memoryGB), 2)}}, @{L = 'Provisioned GB'; E = {[math]::Round(($_.ProvisionedSpaceGB), 2)}}, 
                            @{L = 'Used GB'; E = {[math]::Round(($_.UsedSpaceGB), 2)}}, @{L = 'HW Version'; E = {$_.Version}}, @{L = 'VM Tools Status'; E = {$_.ExtensionData.Guest.ToolsStatus}}
                            if ($Healthcheck.VM.VMTools) {
                                $VMSummary | Where-Object {$_.'VM Tools Status' -eq 'toolsNotInstalled' -or $_.'VM Tools Status' -eq 'toolsOld'} | Set-Style -Style Warning -Property 'VM Tools Status'
                            }
                            if ($Healthcheck.VM.PowerState) {
                                $VMSummary | Where-Object {$_.'Power State' -ne $Healthcheck.VM.PowerStateSetting} | Set-Style -Style Warning -Property 'Power State'
                            }
                            $VMSummary | Table -Name 'VM Summary'
                        }
                        #endregion Virtual Machine Condensed Information

                        #region Virtual Machine Detailed Information
                        if ($InfoLevel.VM -ge 3) {
                            ## TODO: More VM Details to Add
                            foreach ($VM in $VMs) {
                                Section -Style Heading3 $VM.name {
                                    $VMSpecs = $VM | Select-Object Name, id, 
                                    @{L = 'Operating System'; E = {$_.ExtensionData.Summary.Config.GuestFullName}}, 
                                    @{L = 'Hardware Version'; E = {$_.Version}}, 
                                    @{L = 'Power State'; E = {$_.PowerState}}, 
                                    @{L = 'VM Tools Status'; E = {$_.ExtensionData.Guest.ToolsStatus}},
                                    @{L = 'Fault Tolerance State'; E = {$_.ExtensionData.Runtime.FaultToleranceState}}, 
                                    @{L = 'Host'; E = {$_.VMhost.Name}}, 
                                    @{L = 'Parent'; E = {$_.VMhost.Parent.Name}}, 
                                    @{L = 'Parent Folder'; E = {$_.Folder.Name}}, 
                                    @{L = 'Parent Resource Pool'; E = {$_.ResourcePool.Name}}, 
                                    @{L = 'vCPUs'; E = {$_.NumCpu}}, 
                                    @{L = 'Cores per Socket'; E = {$_.CoresPerSocket}}, 
                                    @{L = 'Total vCPUs'; E = {[math]::Round(($_.NumCpu * $_.CoresPerSocket), 0)}}, 
                                    @{L = 'CPU Resources'; E = {"$($_.VMResourceConfiguration.CpuSharesLevel) / $($_.VMResourceConfiguration.NumCpuShares)"}}, 
                                    @{L = 'CPU Reservation'; E = {$_.VMResourceConfiguration.CpuReservationMhz}}, 
                                    @{L = 'CPU Limit'; E = {"$($_.VMResourceConfiguration.CpuReservationMhz) MHz"}}, 
                                    @{L = 'CPU Hot Add Enabled'; E = {$_.ExtensionData.Config.CpuHotAddEnabled}}, 
                                    @{L = 'CPU Hot Remove Enabled'; E = {$_.ExtensionData.Config.CpuHotRemoveEnabled}}, 
                                    @{L = 'Memory Allocation'; E = {"$([math]::Round(($_.memoryGB), 2)) GB"}}, 
                                    @{L = 'Memory Resources'; E = {"$($_.VMResourceConfiguration.MemSharesLevel) / $($_.VMResourceConfiguration.NumMemShares)"}},
                                    @{L = 'Memory Hot Add Enabled'; E = {$_.ExtensionData.Config.MemoryHotAddEnabled}},
                                    @{L = 'vDisks'; E = {($_.ExtensionData.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualDisk]}).Count}},
                                    @{L = 'Used Space'; E = {"$([math]::Round(($_.UsedSpaceGB), 2)) GB"}}, 
                                    @{L = 'Provisioned Space'; E = {"$([math]::Round(($_.ProvisionedSpaceGB), 2)) GB"}}, 
                                    @{L = 'Changed Block Tracking Enabled'; E = {$_.ExtensionData.Config.ChangeTrackingEnabled}},
                                    @{L = 'vNICs'; E = {($_.ExtensionData.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]}).Count}}, Notes
                                    if ($Healthcheck.VM.VMTools) {
                                        $VMSpecs | Where-Object {$_.'VM Tools Status' -eq 'toolsNotInstalled' -or $_.'VM Tools Status' -eq 'toolsOld'} | Set-Style -Style Warning -Property 'VM Tools Status'
                                    }
                                    if ($Healthcheck.VM.PowerState) {
                                        $VMSpecs | Where-Object {$_.'Power State' -ne $Healthcheck.VM.PowerStateSetting} | Set-Style -Style Warning -Property 'Power State'
                                    }
                                    if ($Healthcheck.VM.CpuHotAddEnabled) {
                                        $VMSpecs | Where-Object {$_.'CPU Hot Add Enabled' -eq $true} | Set-Style -Style Warning -Property 'CPU Hot Add Enabled'
                                    }
                                    if ($Healthcheck.VM.CpuHotRemoveEnabled) {
                                        $VMSpecs | Where-Object {$_.'CPU Hot Remove Enabled' -eq $true} | Set-Style -Style Warning -Property 'CPU Hot Remove Enabled'
                                    } 
                                    if ($Healthcheck.VM.MemoryHotAddEnabled) {
                                        $VMSpecs | Where-Object {$_.'Memory Hot Add Enabled' -eq $true} | Set-Style -Style Warning -Property 'Memory Hot Add Enabled'
                                    } 
                                    if ($Healthcheck.VM.ChangeBlockTrackingEnabled) {
                                        $VMSpecs | Where-Object {$_.'Changed Block Tracking Enabled' -eq $false} | Set-Style -Style Warning -Property 'Changed Block Tracking Enabled'
                                    } 
                                    $VMSpecs | Table -Name 'Virtual Machines' -List -ColumnWidths 50, 50
                                }
                            } 
                            #endregion Virtual Machine Summary Information
                        }
                        BlankLine

                        #region VM Snapshot Information
                        if ($InfoLevel.VM -ge 2) {
                            $VMSnapshots = $VMs | Get-Snapshot 
                            if ($VMSnapshots) {
                                Section -Style Heading3 'VM Snapshots' {
                                    $VMSnapshots = $VMSnapshots | Select-Object @{L = 'Virtual Machine'; E = {$_.VM}}, Name, Description, @{L = 'Days Old'; E = {((Get-Date) - $_.Created).Days}} 
                                    if ($Healthcheck.VM.VMSnapshots) {
                                        $VMSnapshots | Where-Object {$_.'Days Old' -ge 7} | Set-Style -Style Warning 
                                        $VMSnapshots | Where-Object {$_.'Days Old' -ge 14} | Set-Style -Style Critical
                                    }
                                    $VMSnapshots | Table -Name 'VM Snapshots'
                                }
                            }
                        }
                        #endregion VM Snapshot Information
                    }
                    PageBreak
                }
            }
            #endregion Virtual Machine Section

            #region VMware Update Manager Section
            if ($InfoLevel.VUM -ge 1) {
                $Script:VUMBaselines = Get-PatchBaseline -Server $vCenter
                if ($VUMBaselines) {
                    Section -Style Heading2 'VMware Update Manager' {
                        Paragraph ("The following section provides information on VMware Update Manager " +
                            "managed by vCenter Server $VCServerFQDN.")
                        #region VUM Baseline Information
                        if ($InfoLevel.VUM -ge 2) {
                            Section -Style Heading3 'Baselines' {
                                $VUMBaselines = $VUMBaselines | Sort-Object Name | Select-Object Name, Description, @{L = 'Type'; E = {$_.BaselineType}}, @{L = 'Target Type'; E = {$_.TargetType}}, @{L = 'Last Update Time'; E = {$_.LastUpdateTime}}, @{L = '# of Patches'; E = {($_.CurrentPatches).count}}
                                $VUMBaselines | Table -Name 'VMware Update Manager Baselines'
                            }
                        }
                        #endregion VUM Baseline Information
                        BlankLine
                        #region VUM Patch Information
                        $Script:VUMPatches = Get-Patch -Server $vCenter
                        if ($VUMPatches -and $InfoLevel.VUM -ge 5) {
                            Section -Style Heading3 'Patches' {
                                $VUMPatches = Get-Patch | Sort-Object -Descending ReleaseDate | Select-Object Name, @{L = 'Product'; E = {($_.Product).Name}}, Description, @{L = 'Release Date'; E = {$_.ReleaseDate}}, Severity, @{L = 'Vendor Id'; E = {$_.IdByVendor}}
                                $VUMPatches | Table -Name 'VMware Update Manager Patches'
                            }
                        }
                        #endregion VUM Patch Information
                    } 
                }
            }
            #endregion VMware Update Manager Section

            #region VMware NSX-V Section
            if ($InfoLevel.NSX -ge 1) {
                #Call the NSX-V report script
                $NSXReport = "$PSScriptRoot\..\..\Reports\NSX\NSX.ps1"
                if (Test-Path $NSXReport -ErrorAction SilentlyContinue) {
                    .$NSXReport -VIServer $VIServer -credentials $credentials
                } else {
                    Write-Error "$NSXReport report does not exist"
                    break
                }
            }
            #endregion VMware NSX-V Section

            #region VMware SRM Section
            ## TODO: VMware SRM Report
            if ($InfoLevel.SRM -ge 1) {
            }
            #endregion VMware SRM Section
        }
        # Disconnect vCenter Server
        $Null = Disconnect-VIServer -Server $VIServer -Confirm:$false -ErrorAction SilentlyContinue

    }
    #endregion Script Body
}