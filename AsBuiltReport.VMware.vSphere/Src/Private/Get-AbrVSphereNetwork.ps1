function Get-AbrVSphereNetwork {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Network information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereNetwork
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.Network)
    }

    process {
        try {
            if ($InfoLevel.Network -ge 1) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                # Create Distributed Switch Section if they exist
                # When a cluster filter is active, limit VDS list to those with member hosts in $VMHosts
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
                if ($VDSwitches) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Distributed Switch Advanced Summary
                        if ($InfoLevel.Network -le 2) {
                            BlankLine
                            $VDSInfo = foreach ($VDS in $VDSwitches) {
                                [PSCustomObject]@{
                                    $LocalizedData.VDSwitch = $VDS.Name
                                    $LocalizedData.Datacenter = $VDS.Datacenter.Name
                                    $LocalizedData.Manufacturer = $VDS.Vendor
                                    $LocalizedData.Version = $VDS.Version
                                    $LocalizedData.NumUplinks = $VDS.NumUplinkPorts
                                    $LocalizedData.NumPorts = $VDS.NumPorts
                                    $LocalizedData.NumHosts = $VDS.ExtensionData.Summary.HostMember.Count
                                    $LocalizedData.NumVMs = $VDS.ExtensionData.Summary.VM.Count
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVDSSummary -f $vCenterServerName)
                                ColumnWidths = 20, 18, 18, 10, 10, 8, 8, 8
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VDSInfo | Table @TableParams
                        }
                        #endregion Distributed Switch Advanced Summary

                        #region Distributed Switch Detailed Information
                        if ($InfoLevel.Network -ge 3) {
                            foreach ($VDS in ($VDSwitches)) {
                                #region VDS Section
                                Section -Style Heading3 $VDS {
                                    #region Distributed Switch General Properties
                                    $VDSwitchDetail = [PSCustomObject]@{
                                        $LocalizedData.VDSwitch = $VDS.Name
                                        $LocalizedData.ID = $VDS.Id
                                        $LocalizedData.Datacenter = $VDS.Datacenter.Name
                                        $LocalizedData.Manufacturer = $VDS.Vendor
                                        $LocalizedData.Version = $VDS.Version
                                        $LocalizedData.NumberOfUplinks = $VDS.NumUplinkPorts
                                        $LocalizedData.NumberOfPorts = $VDS.NumPorts
                                        $LocalizedData.NumberOfPortGroups = $VDS.ExtensionData.Summary.PortGroupName.Count
                                        $LocalizedData.NumberOfHosts = $VDS.ExtensionData.Summary.HostMember.Count
                                        $LocalizedData.NumberOfVMs = $VDS.ExtensionData.Summary.VM.Count
                                        $LocalizedData.MTU = $VDS.Mtu
                                        $LocalizedData.NIOC = if ($VDS.ExtensionData.Config.NetworkResourceManagementEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.DiscoveryProtocol = $VDS.LinkDiscoveryProtocol
                                        $LocalizedData.DiscoveryOperation = switch ($VDS.LinkDiscoveryProtocolOperation) {
                                            'listen' { $LocalizedData.Listen }
                                            'advertise' { $LocalizedData.Advertise }
                                            'both' { $LocalizedData.Both }
                                            'none' { $LocalizedData.Disabled }
                                            default { $VDS.LinkDiscoveryProtocolOperation }
                                        }
                                    }
                                    $MemberProps = @{
                                        'InputObject' = $VDSwitchDetail
                                        'MemberType' = 'NoteProperty'
                                    }
                                    if ($Options.ShowTags -and ($TagAssignments | Where-Object { $_.entity -eq $VDS })) {
                                        Add-Member @MemberProps -Name $LocalizedData.Tags -Value $(($TagAssignments | Where-Object { $_.entity -eq $VDS }).Tag -join ', ')
                                    }
                                    #region Network Advanced Detail Information
                                    if ($InfoLevel.Network -ge 4) {
                                        $VDSwitchDetail | ForEach-Object {
                                            $VDSwitchHosts = $VDS | Get-VMHost | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name $LocalizedData.Hosts -Value ($VDSwitchHosts.Name -join ', ')
                                            $VDSwitchVMs = $VDS | Get-VM | Sort-Object
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name $LocalizedData.VirtualMachines -Value ($VDSwitchVMs.Name -join ', ')
                                        }
                                    }
                                    #endregion Network Advanced Detail Information
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVDSGeneral -f $VDS)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VDSwitchDetail | Table @TableParams
                                    #endregion Distributed Switch General Properties

                                    #region Distributed Switch Uplink Ports
                                    $VdsUplinks = $VDS | Get-VDPortgroup | Where-Object { $_.IsUplink -eq $true } | Get-VDPort
                                    if ($VdsUplinks) {
                                        Section -Style Heading4 $LocalizedData.UplinkPorts {
                                            $VdsUplinkDetail = foreach ($VdsUplink in $VdsUplinks) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.VDSwitch = [string]$VdsUplink.Switch
                                                    $LocalizedData.Host = [string]$VdsUplink.ProxyHost
                                                    $LocalizedData.UplinkName = $VdsUplink.Name
                                                    $LocalizedData.PhysicalNetworkAdapter = [string]$VdsUplink.ConnectedEntity
                                                    $LocalizedData.UplinkPortGroup = [string]$VdsUplink.Portgroup
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSUplinkPorts -f $VDS)
                                                ColumnWidths = 20, 20, 20, 20, 20
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VdsUplinkDetail | Sort-Object $LocalizedData.VDSwitch, $LocalizedData.Host, $LocalizedData.UplinkName | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch Uplink Ports

                                    #region Distributed Switch Security
                                    $VDSecurityPolicy = $VDS | Get-VDSecurityPolicy
                                    if ($VDSecurityPolicy) {
                                        Section -Style Heading4 $LocalizedData.VDSSecurity {
                                            $VDSecurityPolicyDetail = [PSCustomObject]@{
                                                $LocalizedData.VDSwitch = $VDSecurityPolicy.VDSwitch.Name
                                                $LocalizedData.AllowPromiscuous = if ($VDSecurityPolicy.AllowPromiscuous) {
                                                    $LocalizedData.Accept
                                                } else {
                                                    $LocalizedData.Reject
                                                }
                                                $LocalizedData.ForgedTransmits = if ($VDSecurityPolicy.ForgedTransmits) {
                                                    $LocalizedData.Accept
                                                } else {
                                                    $LocalizedData.Reject
                                                }
                                                $LocalizedData.MACAddressChanges = if ($VDSecurityPolicy.MacChanges) {
                                                    $LocalizedData.Accept
                                                } else {
                                                    $LocalizedData.Reject
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSSecurity -f $VDS)
                                                ColumnWidths = 25, 25, 25, 25
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSecurityPolicyDetail | Table @TableParams
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
                                        Section -Style Heading4 $LocalizedData.VDSTrafficShaping {
                                            $VDSTrafficShapingDetail = foreach ($VDSTrafficShape in $VDSTrafficShaping) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.VDSwitch = $VDSTrafficShape.VDSwitch.Name
                                                    $LocalizedData.Direction = $VDSTrafficShape.Direction
                                                    $LocalizedData.Status = if ($VDSTrafficShape.Enabled) {
                                                        $LocalizedData.Enabled
                                                    } else {
                                                        $LocalizedData.Disabled
                                                    }
                                                    $LocalizedData.AverageBandwidth = $VDSTrafficShape.AverageBandwidth
                                                    $LocalizedData.PeakBandwidth = $VDSTrafficShape.PeakBandwidth
                                                    $LocalizedData.BurstSize = $VDSTrafficShape.BurstSize
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSTrafficShaping -f $VDS)
                                                ColumnWidths = 25, 13, 11, 17, 17, 17
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSTrafficShapingDetail | Sort-Object $LocalizedData.Direction | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch Traffic Shaping

                                    #region Distributed Switch LACP
                                    $VDSLacpGroups = $VDS.ExtensionData.Config.LacpGroupConfig
                                    if ($VDSLacpGroups) {
                                        Section -Style Heading4 $LocalizedData.VDSLACP {
                                            $LACPDetail = foreach ($LacpGroup in $VDSLacpGroups) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.VDSwitch    = $VDS.Name
                                                    $LocalizedData.LACPEnabled = $LocalizedData.Yes
                                                    $LocalizedData.LACPMode    = switch ($LacpGroup.Mode) {
                                                        'active'  { $LocalizedData.LACPActive }
                                                        'passive' { $LocalizedData.LACPPassive }
                                                        default   { $LacpGroup.Mode }
                                                    }
                                                }
                                            }
                                            $TableParams = @{
                                                Name         = ($LocalizedData.TableVDSLACP -f $VDS)
                                                ColumnWidths = 34, 33, 33
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $LACPDetail | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch LACP

                                    #region Distributed Switch NetFlow
                                    $VDSNetFlow = $VDS.ExtensionData.Config.IpfixConfig
                                    if ($VDSNetFlow -and $VDSNetFlow.CollectorIpAddress) {
                                        Section -Style Heading4 $LocalizedData.VDSNetFlow {
                                            $NetFlowDetail = [PSCustomObject]@{
                                                $LocalizedData.VDSwitch          = $VDS.Name
                                                $LocalizedData.CollectorIP       = $VDSNetFlow.CollectorIpAddress
                                                $LocalizedData.CollectorPort     = $VDSNetFlow.CollectorPort
                                                $LocalizedData.ActiveFlowTimeout = "$($VDSNetFlow.ActiveFlowTimeout) s"
                                                $LocalizedData.IdleFlowTimeout   = "$($VDSNetFlow.IdleFlowTimeout) s"
                                                $LocalizedData.SamplingRate      = $VDSNetFlow.SamplingRate
                                                $LocalizedData.InternalFlowsOnly = if ($VDSNetFlow.InternalFlowsOnly) { $LocalizedData.Yes } else { $LocalizedData.No }
                                            }
                                            $TableParams = @{
                                                Name         = ($LocalizedData.TableVDSNetFlow -f $VDS)
                                                ColumnWidths = 22, 13, 13, 13, 13, 13, 13
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $NetFlowDetail | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch NetFlow

                                    #region Distributed Switch NIOC Resource Pools
                                    if ($InfoLevel.Network -ge 4 -and $VDS.ExtensionData.Config.NetworkResourceManagementEnabled) {
                                        $VDSNIOCPools = $VDS | Get-VDNetworkResourcePool | Sort-Object Name
                                        if ($VDSNIOCPools) {
                                            Section -Style Heading4 $LocalizedData.NIOCResourcePools {
                                                $NIOCPoolDetails = foreach ($Pool in $VDSNIOCPools) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.NIOCResourcePool = $Pool.Name
                                                        $LocalizedData.NIOCSharesLevel  = $Pool.SharesLevel
                                                        $LocalizedData.NIOCSharesValue  = $Pool.NumShares
                                                        $LocalizedData.NIOCLimitMbps    = if ($Pool.Limit -eq -1) { $LocalizedData.Unlimited } else { $Pool.Limit }
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name         = ($LocalizedData.TableNIOCResourcePools -f $VDS)
                                                    ColumnWidths = 35, 20, 20, 25
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $NIOCPoolDetails | Table @TableParams
                                            }
                                        }
                                    }
                                    #endregion Distributed Switch NIOC Resource Pools

                                    #region Distributed Switch Port Groups
                                    $VDSPortgroups = $VDS | Get-VDPortgroup
                                    if ($VDSPortgroups) {
                                        Section -Style Heading4 $LocalizedData.VDSPortGroups {
                                            $VDSPortgroupDetail = foreach ($VDSPortgroup in $VDSPortgroups) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.PortGroup = $VDSPortgroup.Name
                                                    $LocalizedData.VDSwitch = $VDSPortgroup.VDSwitch.Name
                                                    $LocalizedData.Datacenter = $VDSPortgroup.Datacenter.Name
                                                    $LocalizedData.VLANConfiguration = if ($VDSPortgroup.VlanConfiguration) {
                                                        $VDSPortgroup.VlanConfiguration
                                                    } else {
                                                        '--'
                                                    }
                                                    $LocalizedData.PortBinding = $VDSPortgroup.PortBinding
                                                    $LocalizedData.NumPorts = $VDSPortgroup.NumPorts
                                                    <#
                                                    # Tags on portgroups cause Get-TagAssignments to error
                                                    'Tags' = & {
                                                        if ($TagAssignments | Where-Object {$_.entity -eq $VDSPortgroup}) {
                                                            ($TagAssignments | Where-Object {$_.entity -eq $VDSPortgroup}).Tag -join ','
                                                        } else {
                                                            '--'
                                                        }
                                                    }
                                                    #>
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSPortGroups -f $VDS)
                                                ColumnWidths = 20, 20, 20, 15, 15, 10
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSPortgroupDetail | Sort-Object $LocalizedData.PortGroup | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch Port Groups

                                    #region Distributed Switch Port Group Security
                                    $VDSPortgroupSecurity = $VDS | Get-VDPortgroup | Get-VDSecurityPolicy
                                    if ($VDSPortgroupSecurity) {
                                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VDSPortGroupSecurity {
                                            $VDSSecurityPolicies = foreach ($VDSSecurityPolicy in $VDSPortgroupSecurity) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.PortGroup = [string]$VDSSecurityPolicy.VDPortgroup
                                                    $LocalizedData.VDSwitch = $VDS.Name
                                                    $LocalizedData.AllowPromiscuous = if ($VDSSecurityPolicy.AllowPromiscuous) {
                                                        $LocalizedData.Accept
                                                    } else {
                                                        $LocalizedData.Reject
                                                    }
                                                    $LocalizedData.ForgedTransmits = if ($VDSSecurityPolicy.ForgedTransmits) {
                                                        $LocalizedData.Accept
                                                    } else {
                                                        $LocalizedData.Reject
                                                    }
                                                    $LocalizedData.MACAddressChanges = if ($VDSSecurityPolicy.MacChanges) {
                                                        $LocalizedData.Accept
                                                    } else {
                                                        $LocalizedData.Reject
                                                    }
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSPortGroupSecurity -f $VDS)
                                                ColumnWidths = 20, 20, 20, 20, 20
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSSecurityPolicies | Sort-Object $LocalizedData.PortGroup | Table @TableParams
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
                                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VDSPortGroupTrafficShaping {
                                            $VDSPortgroupTrafficShapingDetail = foreach ($VDSPortgroupTrafficShape in $VDSPortgroupTrafficShaping) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.PortGroup = [string]$VDSPortgroupTrafficShape.VDPortgroup
                                                    $LocalizedData.VDSwitch = $VDS.Name
                                                    $LocalizedData.Direction = $VDSPortgroupTrafficShape.Direction
                                                    $LocalizedData.Status = if ($VDSPortgroupTrafficShape.Enabled) {
                                                        $LocalizedData.Enabled
                                                    } else {
                                                        $LocalizedData.Disabled
                                                    }
                                                    $LocalizedData.AverageBandwidth = $VDSPortgroupTrafficShape.AverageBandwidth
                                                    $LocalizedData.PeakBandwidth = $VDSPortgroupTrafficShape.PeakBandwidth
                                                    $LocalizedData.BurstSize = $VDSPortgroupTrafficShape.BurstSize
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSPortGroupTrafficShaping -f $VDS)
                                                ColumnWidths = 16, 16, 10, 10, 16, 16, 16
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSPortgroupTrafficShapingDetail | Sort-Object $LocalizedData.PortGroup, $LocalizedData.Direction | Table @TableParams

                                        }
                                    }
                                    #endregion Distributed Switch Port Group Traffic Shaping

                                    #region Distributed Switch Port Group Teaming & Failover
                                    $VDUplinkTeamingPolicy = $VDS | Get-VDPortgroup | Get-VDUplinkTeamingPolicy
                                    if ($VDUplinkTeamingPolicy) {
                                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VDSPortGroupTeaming {
                                            $VDSPortgroupNICTeaming = foreach ($VDUplink in $VDUplinkTeamingPolicy) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.PortGroup = [string]$VDUplink.VDPortgroup
                                                    $LocalizedData.VDSwitch = $VDS.Name
                                                    $LocalizedData.LoadBalancing = switch ($VDUplink.LoadBalancingPolicy) {
                                                        'LoadbalanceSrcId' { $LocalizedData.LoadBalanceSrcId }
                                                        'LoadbalanceSrcMac' { $LocalizedData.LoadBalanceSrcMac }
                                                        'LoadbalanceIP' { $LocalizedData.LoadBalanceIP }
                                                        'ExplicitFailover' { $LocalizedData.ExplicitFailover }
                                                        default { $VDUplink.LoadBalancingPolicy }
                                                    }
                                                    $LocalizedData.NetworkFailureDetection = switch ($VDUplink.FailoverDetectionPolicy) {
                                                        'LinkStatus' { $LocalizedData.LinkStatus }
                                                        'BeaconProbing' { $LocalizedData.BeaconProbing }
                                                        default { $VDUplink.FailoverDetectionPolicy }
                                                    }
                                                    $LocalizedData.NotifySwitches = if ($VDUplink.NotifySwitches) {
                                                        $LocalizedData.Yes
                                                    } else {
                                                        $LocalizedData.No
                                                    }
                                                    $LocalizedData.FailbackEnabled = if ($VDUplink.EnableFailback) {
                                                        $LocalizedData.Yes
                                                    } else {
                                                        $LocalizedData.No
                                                    }
                                                    $LocalizedData.ActiveUplinks = $VDUplink.ActiveUplinkPort -join [Environment]::NewLine
                                                    $LocalizedData.StandbyUplinks = $VDUplink.StandbyUplinkPort -join [Environment]::NewLine
                                                    $LocalizedData.UnusedUplinks = $VDUplink.UnusedUplinkPort -join [Environment]::NewLine
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSPortGroupTeaming -f $VDS)
                                                ColumnWidths = 12, 12, 12, 11, 10, 10, 11, 11, 11
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSPortgroupNICTeaming | Sort-Object $LocalizedData.PortGroup | Table @TableParams
                                        }
                                    }
                                    #endregion Distributed Switch Port Group Teaming & Failover

                                    #region Distributed Switch Private VLANs
                                    $VDSwitchPrivateVLANs = $VDS | Get-VDSwitchPrivateVlan
                                    if ($VDSwitchPrivateVLANs) {
                                        Section -Style Heading4 $LocalizedData.VDSPrivateVLANs {
                                            $VDSPvlan = foreach ($VDSwitchPrivateVLAN in $VDSwitchPrivateVLANs) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.PrimaryVLANID = $VDSwitchPrivateVLAN.PrimaryVlanId
                                                    $LocalizedData.PrivateVLANType = $VDSwitchPrivateVLAN.PrivateVlanType
                                                    $LocalizedData.SecondaryVLANID = $VDSwitchPrivateVLAN.SecondaryVlanId
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVDSPrivateVLANs -f $VDS)
                                                ColumnWidths = 33, 34, 33
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VDSPvlan | Sort-Object $LocalizedData.PrimaryVLANID, $LocalizedData.SecondaryVLANID | Table @TableParams
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
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
