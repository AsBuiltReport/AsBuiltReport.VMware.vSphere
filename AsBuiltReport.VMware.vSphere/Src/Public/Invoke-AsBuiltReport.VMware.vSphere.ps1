function Invoke-AsBuiltReport.VMware.vSphere {
    <#
    .SYNOPSIS
        PowerShell script to document the configuration of VMware vSphere infrastructure in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware vSphere infrastructure in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        2.0.0
        Date:           4th March 2026
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )

    # Check for required modules
    Get-RequiredModule -Name 'VCF.PowerCLI' -Version '9.0'

    # Display report module information using Core function
    Write-ReportModuleInfo -ModuleName 'VMware.vSphere'

    # Import Report Configuration
    $Report = $ReportConfig.Report
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options
    $Filter = $ReportConfig.Filter
    $LocalizedData = $reportTranslate.InvokeAsBuiltReportVMwarevSphere

    # Used to set values to TitleCase where required
    $TextInfo = (Get-Culture).TextInfo

    #region Script Body
    # Connect to vCenter Server using supplied credentials
    foreach ($VIServer in $Target) {
        try {
            Write-PScriboMessage -Message ($LocalizedData.Connecting -f $VIServer)
            $vCenter = Connect-VIServer $VIServer -Credential $Credential -ErrorAction Stop
        } catch {
            Write-Error $_
        }

        #region Generate vSphere report
        if ($vCenter) {
            # Check logged in user has sufficient privileges to generate an As Built Report
            Write-PScriboMessage -Message $LocalizedData.CheckPrivileges
            Try {
                $AuthMgr = Get-View $($vCenter.ExtensionData.Content.AuthorizationManager)
                $UserPrivileges = ($AuthMgr.FetchUserPrivilegeOnEntities("Folder-group-d1", $vCenter.User)).privileges
            } Catch {
                Write-PScriboMessage -Message $LocalizedData.UnablePrivileges
            }

            #region Cluster Collection
            Write-PScriboMessage -Message $LocalizedData.CollectingClusters
            $Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
            $ClusterFilterActive = $false
            if ($Filter.Cluster -and $Filter.Cluster -notcontains '*') {
                $ClusterFilterActive = $true
                # Build a datacenter name lookup only when at least one filter entry is datacenter-qualified (e.g. "DC1/ClusterA")
                $ClusterDCLookup = @{}
                if ($Filter.Cluster | Where-Object { $_ -like '*/*' }) {
                    foreach ($Cluster in $Clusters) {
                        $ClusterDCLookup[$Cluster.Id] = ($Cluster | Get-Datacenter -Server $vCenter).Name
                    }
                }
                $FilteredClusters = [System.Collections.Generic.List[object]]::new()
                foreach ($ClusterEntry in $Filter.Cluster) {
                    if ($ClusterEntry -like '*/*') {
                        $DCName, $CName = $ClusterEntry -split '/', 2
                        $Match = $Clusters | Where-Object { $_.Name -eq $CName -and $ClusterDCLookup[$_.Id] -eq $DCName }
                    } else {
                        $Match = $Clusters | Where-Object { $_.Name -eq $ClusterEntry }
                    }
                    if ($Match) { $FilteredClusters.AddRange([object[]]@($Match)) }
                    else { Write-PScriboMessage -IsWarning ($LocalizedData.ClusterNotFound -f $ClusterEntry) }
                }
                $Clusters = $FilteredClusters | Sort-Object Name
            }
            #endregion Cluster Collection

            # Create a lookup hashtable to link Host MoRefs to Names
            # Exclude VMware HCX hosts and ESX/ESXi versions prior to vSphere 5.0 from VMHost lookup
            Write-PScriboMessage -Message $LocalizedData.VMHostHashtable
            if ($ClusterFilterActive) {
                $VMHosts = $Clusters | Get-VMHost -Server $vCenter | Where-Object { $_.Model -notlike "*VMware Mobility Platform" -and $_.Version -gt 5 } | Sort-Object Name
            } else {
                $VMHosts = Get-VMHost -Server $vCenter | Where-Object { $_.Model -notlike "*VMware Mobility Platform" -and $_.Version -gt 5 } | Sort-Object Name
            }
            $VMHostLookup = @{ }
            foreach ($VMHost in $VMHosts) {
                $VMHostLookup.($VMHost.Id) = $VMHost.Name
            }

            # Create a lookup hashtable to quickly link VM MoRefs to Names
            # Exclude VMware Site Recovery Manager placeholder VMs
            Write-PScriboMessage -Message $LocalizedData.VMHashtable
            if ($ClusterFilterActive) {
                $VMs = $VMHosts | Get-VM | Where-Object {
                    $_.ExtensionData.Config.ManagedBy.ExtensionKey -notlike 'com.vmware.vcDr*'
                } | Sort-Object Name
            } else {
                $VMs = Get-VM -Server $vCenter | Where-Object {
                    $_.ExtensionData.Config.ManagedBy.ExtensionKey -notlike 'com.vmware.vcDr*'
                } | Sort-Object Name
            }
            $VMLookup = @{ }
            foreach ($VM in $VMs) {
                $VMLookup.($VM.Id) = $VM.Name
            }

            # Create a lookup hashtable to link Datastore MoRefs to Names
            Write-PScriboMessage -Message $LocalizedData.DatastoreHashtable
            if ($ClusterFilterActive) {
                $Datastores = $VMHosts | Get-Datastore | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name -Unique
            } else {
                $Datastores = Get-Datastore -Server $vCenter | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
            }
            $DatastoreLookup = @{ }
            foreach ($Datastore in $Datastores) {
                $DatastoreLookup.($Datastore.Id) = $Datastore.Name
            }

            # Create a lookup hashtable to link VDS Portgroups MoRefs to Names
            Write-PScriboMessage -Message $LocalizedData.VDPortGrpHashtable
            $VDPortGroups = Get-VDPortgroup -Server $vCenter | Sort-Object Name
            $VDPortGroupLookup = @{ }
            foreach ($VDPortGroup in $VDPortGroups) {
                $VDPortGroupLookup.($VDPortGroup.Key) = $VDPortGroup.Name
            }

            # Create a lookup hashtable to link EVC Modes to Names
            Write-PScriboMessage -Message $LocalizedData.EVCHashtable
            $SupportedEvcModes = $vCenter.ExtensionData.Capability.SupportedEVCMode
            $EvcModeLookup = @{ }
            foreach ($EvcMode in $SupportedEvcModes) {
                $EvcModeLookup.($EvcMode.Key) = $EvcMode.Label
            }

            #region ResourcePool Collection
            $ResourcePools = $Clusters | Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
            #endregion ResourcePool Collection

            #region vSAN Collection
            $VsanClusters = Get-VsanClusterConfiguration -Server $vCenter |
                Where-Object { $_.vsanenabled -eq $true -and $_.Name -in $Clusters.Name } |
                Sort-Object Name
            #endregion vSAN Collection

            #region DSCluster Collection
            $DSClusters = Get-DatastoreCluster -Server $vCenter | Where-Object {
                ($_ | Get-Datastore) | Where-Object { $_.Id -in $Datastores.Id }
            } | Sort-Object Name
            #endregion DSCluster Collection

            #region VDSwitch Collection
            $AllVDSwitches = Get-VDSwitch -Server $vCenter | Sort-Object Name
            if ($ClusterFilterActive) {
                $VMHostMoRefs = $VMHosts | ForEach-Object { "$($_.ExtensionData.MoRef.Type)-$($_.ExtensionData.MoRef.Value)" }
                $VDSwitches = $AllVDSwitches | Where-Object {
                    $VDSHostMoRefs = $_.ExtensionData.Summary.HostMember |
                        ForEach-Object { "$($_.Type)-$($_.Value)" }
                    ($VDSHostMoRefs | Where-Object { $_ -in $VMHostMoRefs }).Count -gt 0
                }
            } else {
                $VDSwitches = $AllVDSwitches
            }
            #endregion VDSwitch Collection

            $si = Get-View ServiceInstance -Server $vCenter
            $extMgr = Get-View -Id $si.Content.ExtensionManager -Server $vCenter

            #region VMware Update Manager Server Name
            Write-PScriboMessage -Message $LocalizedData.CheckVUM
            $VumServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcIntegrity' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Type -eq 'SOAP' -and $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VMware Update Manager Server Name

            #region vCenter REST API
            $vcApiUri = $null
            $vcApiHeaders = $null
            if ([version]$vCenter.Version -ge [version]'7.0') {
                $vcApiBaseUri = "https://$($vCenter.Name)/api"
                try {
                    $restToken = Invoke-RestMethod -Uri "$vcApiBaseUri/session" -Method Post -Credential $Credential -SkipCertificateCheck -ErrorAction Stop
                    $vcApiUri = $vcApiBaseUri
                    $vcApiHeaders = @{
                        'vmware-api-session-id' = $restToken
                    }
                } catch {
                    Write-PScriboMessage -IsWarning ($LocalizedData.RestApiSessionError -f $_.Exception.Message)
                }
            }
            #endregion vCenter REST API

            #region VxRail Manager Server Name
            Write-PScriboMessage -Message $LocalizedData.CheckVxRail
            $VxRailMgr = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vxrail' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Type -eq 'HTTPS' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VxRail Manager Server Name

            #region Site Recovery Manager Server Name
            Write-PScriboMessage -Message $LocalizedData.CheckSRM
            $SrmServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcDr' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion Site Recovery Manager Server Name

            #region NSX-T Manager Server Name
            Write-PScriboMessage -Message $LocalizedData.CheckNSXT
            $NsxtServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.nsx.management.nsxt' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { ($_.Company -eq 'VMware') -and ($_.Type -eq 'VIP') } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion NSX-T Manager Server Name

            #region Tag Information
            Try {
                Write-PScriboMessage -Message $LocalizedData.CollectingTags
                $TagAssignments = Get-TagAssignment -Server $vCenter -ErrorAction SilentlyContinue
                $Tags = Get-Tag -Server $vCenter | Sort-Object Name, Category
                $TagCategories = Get-TagCategory -Server $vCenter | Sort-Object Name | Select-Object Name, Description, Cardinality -Unique
            } Catch {
                Write-PScriboMessage -Message "$($LocalizedData.TagError). $($_.Exception.Message)"
            }
            #endregion Tag Information

            #region vCenter Advanced Settings
            Write-PScriboMessage -Message ($LocalizedData.CollectingAdvSettings -f $vCenter)
            $vCenterAdvSettings = Get-AdvancedSetting -Entity $vCenter
            $vCenterServerName = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.FQDN' }).Value
            $vCenterServerName = $vCenterServerName.ToString().ToLower()
            #endregion vCenter Advanced Settings

            #region vCenter Server Heading1 Section
            Section -Style Heading1 $vCenterServerName {
                Get-AbrVSpherevCenter
                Get-AbrVSphereCluster
                Get-AbrVSphereResourcePool
                Get-AbrVSphereVMHost
                Get-AbrVSphereNetwork
                Get-AbrVSpherevSAN
                Get-AbrVSphereDatastore
                Get-AbrVSphereDSCluster
                Get-AbrVSphereVM
                Get-AbrVSphereVUM
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
}
