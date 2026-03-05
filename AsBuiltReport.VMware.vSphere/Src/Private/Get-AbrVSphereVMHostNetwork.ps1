function Get-AbrVSphereVMHostNetwork {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost Network information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHostNetwork
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VMHost)
    }

    process {
        try {
            Write-PScriboMessage -Message $LocalizedData.Collecting
            #region ESXi Host Network Section
            Section -Style Heading4 $LocalizedData.SectionHeading {
                Paragraph ($LocalizedData.ParagraphSummary -f $VMHost)
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
                    $LocalizedData.Host = $VMHost.Name
                    $LocalizedData.VirtualSwitches = ($VMHostVirtualSwitch | Sort-Object) -join ', '
                    $LocalizedData.VMKernelAdapters = ($VMHostNetwork.Vnic.Device | Sort-Object) -join ', '
                    $LocalizedData.PhysicalAdapters = ($VMHostNetwork.Pnic.Device | Sort-Object) -join ', '
                    $LocalizedData.VMkernelGateway = $VMHostNetwork.IpRouteConfig.DefaultGateway
                    $LocalizedData.IPv6 = if ($VMHostNetwork.IPv6Enabled) {
                        $LocalizedData.Enabled
                    } else {
                        $LocalizedData.Disabled
                    }
                    $LocalizedData.VMkernelIPv6Gateway = if ($VMHostNetwork.IpRouteConfig.IpV6DefaultGateway) {
                        $VMHostNetwork.IpRouteConfig.IpV6DefaultGateway
                    } else {
                        '--'
                    }
                    $LocalizedData.DNSServers = ($VMHostNetwork.DnsConfig.Address | Sort-Object) -join ', '
                    $LocalizedData.HostName = $VMHostNetwork.DnsConfig.HostName
                    $LocalizedData.DomainName = $VMHostNetwork.DnsConfig.DomainName
                    $LocalizedData.SearchDomain = ($VMHostNetwork.DnsConfig.SearchDomain | Sort-Object) -join ', '
                }
                if ($Healthcheck.VMHost.IPv6) {
                    $VMHostNetworkDetail | Where-Object { $_.$($LocalizedData.IPv6) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.IPv6
                }
                $TableParams = @{
                    Name = ($LocalizedData.TableNetworkConfig -f $VMHost)
                    List = $true
                    ColumnWidths = 40, 60
                }
                if ($Report.ShowTableCaptions) {
                    $TableParams['Caption'] = "- $($TableParams.Name)"
                }
                $VMHostNetworkDetail | Table @TableParams
                #endregion ESXi Host Network Configuration

                #region ESXi Host Physical Adapters
                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.PhysicalAdapters {
                    Paragraph ($LocalizedData.ParagraphPhysicalAdapters -f $VMHost)
                    $PhysicalNetAdapters = $VMHost.ExtensionData.Config.Network.Pnic | Sort-Object Device
                    $VMHostPhysicalNetAdapters = foreach ($PhysicalNetAdapter in $PhysicalNetAdapters) {
                        [PSCustomObject]@{
                            $LocalizedData.AdapterName = $PhysicalNetAdapter.Device
                            $LocalizedData.Status = if ($PhysicalNetAdapter.Linkspeed) {
                                $LocalizedData.Connected
                            } else {
                                $LocalizedData.Disconnected
                            }
                            $LocalizedData.VirtualSwitch = $(
                                if ($VMHost.ExtensionData.Config.Network.Vswitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                    ($VMHost.ExtensionData.Config.Network.Vswitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).Name
                                } elseif ($VMHost.ExtensionData.Config.Network.ProxySwitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                    ($VMHost.ExtensionData.Config.Network.ProxySwitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).DvsName
                                } else {
                                    '--'
                                }
                            )
                            $LocalizedData.AdapterMAC = $PhysicalNetAdapter.Mac
                            $LocalizedData.ActualSpeedDuplex = if ($PhysicalNetAdapter.LinkSpeed.SpeedMb) {
                                if ($PhysicalNetAdapter.LinkSpeed.Duplex) {
                                    "$($PhysicalNetAdapter.LinkSpeed.SpeedMb) Mbps, $($LocalizedData.FullDuplex)"
                                } else {
                                    $LocalizedData.AutoNegotiate
                                }
                            } else {
                                $LocalizedData.Down
                            }
                            $LocalizedData.ConfiguredSpeedDuplex = if ($PhysicalNetAdapter.Spec.LinkSpeed) {
                                if ($PhysicalNetAdapter.Spec.LinkSpeed.Duplex) {
                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mbps, $($LocalizedData.FullDuplex)"
                                } else {
                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mbps"
                                }
                            } else {
                                $LocalizedData.AutoNegotiate
                            }
                            $LocalizedData.WakeOnLAN = if ($PhysicalNetAdapter.WakeOnLanSupported) {
                                $LocalizedData.Supported
                            } else {
                                $LocalizedData.NotSupported
                            }
                        }
                    }
                    if ($Healthcheck.VMHost.NetworkAdapter) {
                        $VMHostPhysicalNetAdapters | Where-Object { $_.$($LocalizedData.Status) -ne $LocalizedData.Connected } | Set-Style -Style Critical -Property $LocalizedData.Status
                        $VMHostPhysicalNetAdapters | Where-Object { $_.$($LocalizedData.ActualSpeedDuplex) -eq $LocalizedData.Down } | Set-Style -Style Critical -Property $LocalizedData.ActualSpeedDuplex
                    }
                    if ($InfoLevel.VMHost -ge 4) {
                        foreach ($VMHostPhysicalNetAdapter in $VMHostPhysicalNetAdapters) {
                            Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMHostPhysicalNetAdapter.$($LocalizedData.AdapterName))" {
                                $TableParams = @{
                                    Name = ($LocalizedData.TablePhysicalAdapter -f $VMHostPhysicalNetAdapter.$($LocalizedData.AdapterName), $VMHost)
                                    List = $true
                                    ColumnWidths = 40, 60
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMHostPhysicalNetAdapter | Table @TableParams
                            }
                        }
                    } else {
                        BlankLine
                        $TableParams = @{
                            Name = ($LocalizedData.TablePhysicalAdapters -f $VMHost)
                            ColumnWidths = 11, 13, 15, 19, 14, 14, 14
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostPhysicalNetAdapters | Table @TableParams
                    }
                }
                #endregion ESXi Host Physical Adapters

                #region ESXi Host Cisco Discovery Protocol
                $VMHostNetworkAdapterCDP = $VMHost | Get-VMHostNetworkAdapterDP | Where-Object { $_.Status -eq 'Connected' } | Sort-Object Device
                if ($VMHostNetworkAdapterCDP) {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.CDP {
                        Paragraph ($LocalizedData.ParagraphCDP -f $VMHost)
                        if ($InfoLevel.VMHost -ge 4) {
                            foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMHostNetworkAdapter.Device)" {
                                    $VMHostCDP = [PSCustomObject]@{
                                        $LocalizedData.Status = $VMHostNetworkAdapter.Status
                                        $LocalizedData.SystemName = $VMHostNetworkAdapter.SystemName
                                        $LocalizedData.HardwarePlatform = $VMHostNetworkAdapter.HardwarePlatform
                                        $LocalizedData.SwitchID = $VMHostNetworkAdapter.SwitchId
                                        $LocalizedData.SoftwareVersion = $VMHostNetworkAdapter.SoftwareVersion
                                        $LocalizedData.ManagementAddress = $VMHostNetworkAdapter.ManagementAddress
                                        $LocalizedData.Address = $VMHostNetworkAdapter.Address
                                        $LocalizedData.PortID = $VMHostNetworkAdapter.PortId
                                        $LocalizedData.VLAN = $VMHostNetworkAdapter.Vlan
                                        $LocalizedData.MTU = $VMHostNetworkAdapter.Mtu
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableAdapterCDP -f $VMHostNetworkAdapter.Device, $VMHost)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMHostCDP | Table @TableParams
                                }
                            }
                        } else {
                            BlankLine
                            $VMHostCDP = foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                [PSCustomObject]@{
                                    $LocalizedData.AdapterName = $VMHostNetworkAdapter.Device
                                    $LocalizedData.Status = $VMHostNetworkAdapter.Status
                                    $LocalizedData.HardwarePlatform = $VMHostNetworkAdapter.HardwarePlatform
                                    $LocalizedData.SwitchID = $VMHostNetworkAdapter.SwitchId
                                    $LocalizedData.Address = $VMHostNetworkAdapter.Address
                                    $LocalizedData.PortID = $VMHostNetworkAdapter.PortId
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableAdaptersCDP -f $VMHost)
                                ColumnWidths = 11, 13, 26, 22, 17, 11
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostCDP | Table @TableParams
                        }
                    }
                }
                #endregion ESXi Host Cisco Discovery Protocol

                #region ESXi Host Link Layer Discovery Protocol
                $VMHostNetworkAdapterLLDP = $VMHost | Get-VMHostNetworkAdapterDP | Where-Object { $null -ne $_.ChassisId } | Sort-Object Device
                if ($VMHostNetworkAdapterLLDP) {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.LLDP {
                        Paragraph ($LocalizedData.ParagraphLLDP -f $VMHost)
                        if ($InfoLevel.VMHost -ge 4) {
                            foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterLLDP) {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMHostNetworkAdapter.Device)" {
                                    $VMHostLLDP = [PSCustomObject]@{
                                        $LocalizedData.ChassisID = $VMHostNetworkAdapter.ChassisId
                                        $LocalizedData.PortID = $VMHostNetworkAdapter.PortId
                                        $LocalizedData.TimeToLive = $VMHostNetworkAdapter.TimeToLive
                                        $LocalizedData.TimeOut = $VMHostNetworkAdapter.TimeOut
                                        $LocalizedData.Samples = $VMHostNetworkAdapter.Samples
                                        $LocalizedData.ManagementAddress = $VMHostNetworkAdapter.ManagementAddress
                                        $LocalizedData.PortDescription = $VMHostNetworkAdapter.PortDescription
                                        $LocalizedData.SystemDescription = $VMHostNetworkAdapter.SystemDescription
                                        $LocalizedData.SystemName = $VMHostNetworkAdapter.SystemName
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableAdapterLLDP -f $VMHostNetworkAdapter.Device, $VMHost)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMHostLLDP | Table @TableParams
                                }
                            }
                        } else {
                            BlankLine
                            $VMHostLLDP = foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterLLDP) {
                                [PSCustomObject]@{
                                    $LocalizedData.AdapterName = $VMHostNetworkAdapter.Device
                                    $LocalizedData.ChassisID = $VMHostNetworkAdapter.ChassisId
                                    $LocalizedData.PortID = $VMHostNetworkAdapter.PortId
                                    $LocalizedData.ManagementAddress = $VMHostNetworkAdapter.ManagementAddress
                                    $LocalizedData.PortDescription = $VMHostNetworkAdapter.PortDescription
                                    $LocalizedData.SystemName = $VMHostNetworkAdapter.SystemName
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableAdaptersLLDP -f $VMHost)
                                ColumnWidths = 11, 19, 16, 19, 18, 17
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostLLDP | Table @TableParams
                        }
                    }
                }
                #endregion ESXi Host Link Layer Discovery Protocol

                #region ESXi Host VMkernel Adapaters
                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VMKernelAdapters {
                    Paragraph ($LocalizedData.ParagraphVMKernelAdapters -f $VMHost)
                    $VMkernelAdapters = $VMHost | Get-View | ForEach-Object -Process {
                        #$esx = $_
                        $netSys = Get-View -Id $_.ConfigManager.NetworkSystem
                        $vnicMgr = Get-View -Id $_.ConfigManager.VirtualNicManager
                        $netSys.NetworkInfo.Vnic |
                        ForEach-Object -Process {
                            $device = $_.Device
                            [PSCustomObject]@{
                                $LocalizedData.AdapterName = $_.Device
                                $LocalizedData.NetworkLabel = & {
                                    if ($_.Spec.Portgroup) {
                                        $script:pg = $_.Spec.Portgroup
                                        $script:pg
                                    } elseif ($_.Spec.DistributedVirtualPort.Portgroupkey) {
                                        $script:pg = Get-View -ViewType DistributedVirtualPortgroup -Property Name, Key -Filter @{'Key' = "$($_.Spec.DistributedVirtualPort.PortgroupKey)" } | Select-Object -ExpandProperty Name
                                        $script:pg
                                    } else {
                                        '--'
                                    }
                                }
                                $LocalizedData.VirtualSwitch = & {
                                    if ($_.Spec.Portgroup) {
                                        (Get-VirtualPortGroup -Standard -Name $script:pg -VMHost $VMHost).VirtualSwitchName
                                    } elseif ($_.Spec.DistributedVirtualPort.Portgroupkey) {
                                        (Get-VDPortgroup -Name $script:pg).VDSwitch.Name | Select-Object -Unique
                                    } else {
                                        # Haven't figured out how to gather this yet!
                                        '--'
                                    }
                                }
                                $LocalizedData.TCPIPStack = switch ($_.Spec.NetstackInstanceKey) {
                                    'defaultTcpipStack' { $LocalizedData.TCPDefault }
                                    'vSphereProvisioning' { $LocalizedData.TCPProvisioning }
                                    'vmotion' { $LocalizedData.TCPvMotion }
                                    'vxlan' { $LocalizedData.TCPNsxOverlay }
                                    'hyperbus' { $LocalizedData.TCPNsxHyperbus }
                                    $null { $LocalizedData.TCPNotApplicable }
                                    default { $_.Spec.NetstackInstanceKey }
                                }
                                $LocalizedData.MTU = $_.Spec.Mtu
                                $LocalizedData.AdapterMAC = $_.Spec.Mac
                                $LocalizedData.DHCP = if ($_.Spec.Ip.Dhcp) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.IPAddress = & {
                                    if ($_.Spec.IP.IPAddress) {
                                        $script:ip = $_.Spec.IP.IPAddress
                                    } else {
                                        $script:ip = '--'
                                    }
                                    $script:ip
                                }
                                $LocalizedData.SubnetMask = & {
                                    if ($_.Spec.IP.SubnetMask) {
                                        $script:netmask = $_.Spec.IP.SubnetMask
                                    } else {
                                        $script:netmask = '--'
                                    }
                                    $script:netmask
                                }
                                $LocalizedData.DefaultGateway = if ($_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway) {
                                    $_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway
                                } else {
                                    '--'
                                }
                                $LocalizedData.vMotion = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vmotion' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.Provisioning = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereProvisioning' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.FTLogging = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'faultToleranceLogging' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.Management = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'management' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.vSphereReplication = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereReplication' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.vSphereReplicationNFC = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereReplicationNFC' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.vSAN = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vsan' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.vSANWitness = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vsanWitness' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                                $LocalizedData.vSphereBackupNFC = if ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereBackupnNFC' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                            }
                        }
                    }
                    foreach ($VMkernelAdapter in ($VMkernelAdapters | Sort-Object $LocalizedData.AdapterName)) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMkernelAdapter.$($LocalizedData.AdapterName))" {
                            $TableParams = @{
                                Name = ($LocalizedData.TableVMKernelAdapter -f $VMkernelAdapter.$($LocalizedData.AdapterName), $VMHost)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMkernelAdapter | Table @TableParams
                        }
                    }
                }
                #endregion ESXi Host VMkernel Adapaters

                #region ESXi Host Standard Virtual Switches
                $VSSwitches = $VMHost | Get-VirtualSwitch -Standard | Sort-Object Name
                if ($VSSwitches) {
                    #region Section Standard Virtual Switches
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.StandardvSwitches {
                        Paragraph ($LocalizedData.ParagraphStandardvSwitches -f $VMHost)
                        BlankLine
                        $VSSwitchNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                        #region ESXi Host Standard Virtual Switch Properties
                        $VSSProperties = foreach ($VSSwitchNicTeam in $VSSwitchNicTeaming) {
                            [PSCustomObject]@{
                                $LocalizedData.VirtualSwitch = $VSSwitchNicTeam.VirtualSwitch
                                $LocalizedData.MTU = $VSSwitchNicTeam.VirtualSwitch.Mtu
                                $LocalizedData.NumberOfPorts = $VSSwitchNicTeam.VirtualSwitch.NumPorts
                                $LocalizedData.NumberOfPortsAvailable = $VSSwitchNicTeam.VirtualSwitch.NumPortsAvailable
                            }
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableStandardvSwitches -f $VMHost)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VSSProperties | Table @TableParams
                        #endregion ESXi Host Standard Virtual Switch Properties

                        #region ESXi Host Virtual Switch Security Policy
                        $VssSecurity = $VSSwitches | Get-SecurityPolicy
                        if ($VssSecurity) {
                            #region Virtual Switch Security Policy
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSSecurity {
                                $VssSecurity = foreach ($VssSec in $VssSecurity) {
                                    [PSCustomObject]@{
                                        $LocalizedData.VirtualSwitch = $VssSec.VirtualSwitch
                                        $LocalizedData.PromiscuousMode = if ($VssSec.AllowPromiscuous) {
                                            $LocalizedData.Accept
                                        } else {
                                            $LocalizedData.Reject
                                        }
                                        $LocalizedData.MACAddressChanges = if ($VssSec.MacChanges) {
                                            $LocalizedData.Accept
                                        } else {
                                            $LocalizedData.Reject
                                        }
                                        $LocalizedData.ForgedTransmits = if ($VssSec.ForgedTransmits) {
                                            $LocalizedData.Accept
                                        } else {
                                            $LocalizedData.Reject
                                        }
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVSSecurity -f $VMHost)
                                    ColumnWidths = 25, 25, 25, 25
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VssSecurity | Sort-Object $LocalizedData.VirtualSwitch | Table @TableParams
                            }
                            #endregion Virtual Switch Security Policy
                        }
                        #endregion ESXi Host Virtual Switch Security Policy

                        #region ESXi Host Virtual Switch Traffic Shaping Policy
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSTrafficShaping {
                            $VssTrafficShapingPolicy = foreach ($VSSwitch in $VSSwitches) {
                                [PSCustomObject]@{
                                    $LocalizedData.VirtualSwitch = $VSSwitch.Name
                                    $LocalizedData.Status = if ($VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                        $LocalizedData.Enabled
                                    } else {
                                        $LocalizedData.Disabled
                                    }
                                    $LocalizedData.AverageBandwidth = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                    $LocalizedData.PeakBandwidth = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                    $LocalizedData.BurstSize = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVSTrafficShaping -f $VMHost)
                                ColumnWidths = 25, 15, 20, 20, 20
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VssTrafficShapingPolicy | Sort-Object $LocalizedData.VirtualSwitch | Table @TableParams
                        }
                        #endregion ESXi Host Virtual Switch Traffic Shaping Policy

                        #region ESXi Host Virtual Switch Teaming & Failover
                        $VssNicTeamingPolicy = $VSSwitches | Get-NicTeamingPolicy
                        if ($VssNicTeamingPolicy) {
                            #region Virtual Switch Teaming & Failover Section
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSTeamingFailover {
                                $VssNicTeaming = foreach ($VssNicTeam in $VssNicTeamingPolicy) {
                                    [PSCustomObject]@{
                                        $LocalizedData.VirtualSwitch = $VssNicTeam.VirtualSwitch
                                        $LocalizedData.LoadBalancing = switch ($VssNicTeam.LoadBalancingPolicy) {
                                            'LoadbalanceSrcId' { $LocalizedData.LBSrcId }
                                            'LoadbalanceSrcMac' { $LocalizedData.LBSrcMac }
                                            'LoadbalanceIP' { $LocalizedData.LBIP }
                                            'ExplicitFailover' { $LocalizedData.LBExplicitFailover }
                                            default { $VssNicTeam.LoadBalancingPolicy }
                                        }
                                        $LocalizedData.NetworkFailureDetection = switch ($VssNicTeam.NetworkFailoverDetectionPolicy) {
                                            'LinkStatus' { $LocalizedData.NFDLinkStatus }
                                            'BeaconProbing' { $LocalizedData.NFDBeaconProbing }
                                            default { $VssNicTeam.NetworkFailoverDetectionPolicy }
                                        }
                                        $LocalizedData.NotifySwitches = if ($VssNicTeam.NotifySwitches) {
                                            $LocalizedData.Yes
                                        } else {
                                            $LocalizedData.No
                                        }
                                        $LocalizedData.Failback = if ($VssNicTeam.FailbackEnabled) {
                                            $LocalizedData.Yes
                                        } else {
                                            $LocalizedData.No
                                        }
                                        $LocalizedData.ActiveNICs = ($VssNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                        $LocalizedData.StandbyNICs = ($VssNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                        $LocalizedData.UnusedNICs = ($VssNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVSTeamingFailover -f $VMHost)
                                    ColumnWidths = 20, 17, 12, 11, 10, 10, 10, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VssNicTeaming | Sort-Object $LocalizedData.VirtualSwitch | Table @TableParams
                            }
                            #endregion Virtual Switch Teaming & Failover Section
                        }
                        #endregion ESXi Host Virtual Switch Teaming & Failover

                        #region ESXi Host Virtual Switch Port Groups
                        $VssPortgroups = $VSSwitches | Get-VirtualPortGroup -Standard
                        if ($VssPortgroups) {
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSPortGroups {
                                $VssPortgroups = foreach ($VssPortgroup in $VssPortgroups) {
                                    [PSCustomObject]@{
                                        $LocalizedData.PortGroup = $VssPortgroup.Name
                                        $LocalizedData.VLAN = $VssPortgroup.VLanId
                                        $LocalizedData.VirtualSwitch = $VssPortgroup.VirtualSwitchName
                                        $LocalizedData.NumberOfVMs = ($VssPortgroup | Get-VM).Count
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVSPortGroups -f $VMHost)
                                    ColumnWidths = 40, 10, 40, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VssPortgroups | Sort-Object $LocalizedData.PortGroup, $LocalizedData.VLAN, $LocalizedData.VirtualSwitch | Table @TableParams
                            }
                            #endregion ESXi Host Virtual Switch Port Groups

                            #region ESXi Host Virtual Switch Port Group Security Policy
                            $VssPortgroupSecurity = $VSSwitches | Get-VirtualPortGroup | Get-SecurityPolicy
                            if ($VssPortgroupSecurity) {
                                #region Virtual Port Group Security Policy Section
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSPGSecurity {
                                    $VssPortgroupSecurity = foreach ($VssPortgroupSec in $VssPortgroupSecurity) {
                                        [PSCustomObject]@{
                                            $LocalizedData.PortGroup = $VssPortgroupSec.VirtualPortGroup
                                            $LocalizedData.VirtualSwitch = $VssPortgroupSec.virtualportgroup.virtualswitchname
                                            $LocalizedData.PromiscuousMode = if ($VssPortgroupSec.AllowPromiscuous) {
                                                $LocalizedData.Accept
                                            } else {
                                                $LocalizedData.Reject
                                            }
                                            $LocalizedData.MACChanges = if ($VssPortgroupSec.MacChanges) {
                                                $LocalizedData.Accept
                                            } else {
                                                $LocalizedData.Reject
                                            }
                                            $LocalizedData.ForgedTransmits = if ($VssPortgroupSec.ForgedTransmits) {
                                                $LocalizedData.Accept
                                            } else {
                                                $LocalizedData.Reject
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVSPGSecurity -f $VMHost)
                                        ColumnWidths = 27, 25, 16, 16, 16
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VssPortgroupSecurity | Sort-Object $LocalizedData.PortGroup, $LocalizedData.VirtualSwitch | Table @TableParams
                                }
                                #endregion Virtual Port Group Security Policy Section
                            }
                            #endregion ESXi Host Virtual Switch Port Group Security Policy

                            #region ESXi Host Virtual Switch Port Group Traffic Shaping Policy
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSPGTrafficShaping {
                                $VssPortgroupTrafficShapingPolicy = foreach ($VssPortgroup in $VssPortgroups) {
                                    [PSCustomObject]@{
                                        $LocalizedData.PortGroup = $VssPortgroup.Name
                                        $LocalizedData.VirtualSwitch = $VssPortgroup.VirtualSwitchName
                                        $LocalizedData.Status = switch ($VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                            $True { $LocalizedData.Enabled }
                                            $False { $LocalizedData.Disabled }
                                            $null { $LocalizedData.Inherited }
                                        }
                                        $LocalizedData.AverageBandwidth = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                        $LocalizedData.PeakBandwidth = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                        $LocalizedData.BurstSize = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVSPGTrafficShaping -f $VMHost)
                                    ColumnWidths = 19, 19, 11, 17, 17, 17
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VssPortgroupTrafficShapingPolicy | Sort-Object $LocalizedData.PortGroup, $LocalizedData.VirtualSwitch | Table @TableParams
                            }
                            #endregion ESXi Host Virtual Switch Port Group Traffic Shaping Policy

                            #region ESXi Host Virtual Switch Port Group Teaming & Failover
                            $VssPortgroupNicTeaming = $VSSwitches | Get-VirtualPortGroup | Get-NicTeamingPolicy
                            if ($VssPortgroupNicTeaming) {
                                #region Virtual Switch Port Group Teaming & Failover Section
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VSPGTeamingFailover {
                                    $VssPortgroupNicTeaming = foreach ($VssPortgroupNicTeam in $VssPortgroupNicTeaming) {
                                        [PSCustomObject]@{
                                            $LocalizedData.PortGroup = $VssPortgroupNicTeam.VirtualPortGroup
                                            $LocalizedData.VirtualSwitch = $VssPortgroupNicTeam.virtualportgroup.virtualswitchname
                                            $LocalizedData.LoadBalancing = switch ($VssPortgroupNicTeam.LoadBalancingPolicy) {
                                                'LoadbalanceSrcId' { $LocalizedData.LBSrcId }
                                                'LoadbalanceSrcMac' { $LocalizedData.LBSrcMac }
                                                'LoadbalanceIP' { $LocalizedData.LBIP }
                                                'ExplicitFailover' { $LocalizedData.LBExplicitFailover }
                                                default { $VssPortgroupNicTeam.LoadBalancingPolicy }
                                            }
                                            $LocalizedData.NetworkFailureDetection = switch ($VssPortgroupNicTeam.NetworkFailoverDetectionPolicy) {
                                                'LinkStatus' { $LocalizedData.NFDLinkStatus }
                                                'BeaconProbing' { $LocalizedData.NFDBeaconProbing }
                                                default { $VssPortgroupNicTeam.NetworkFailoverDetectionPolicy }
                                            }
                                            $LocalizedData.NotifySwitches = if ($VssPortgroupNicTeam.NotifySwitches) {
                                                $LocalizedData.Yes
                                            } else {
                                                $LocalizedData.No
                                            }
                                            $LocalizedData.Failback = if ($VssPortgroupNicTeam.FailbackEnabled) {
                                                $LocalizedData.Yes
                                            } else {
                                                $LocalizedData.No
                                            }
                                            $LocalizedData.ActiveNICs = ($VssPortgroupNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                            $LocalizedData.StandbyNICs = ($VssPortgroupNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                            $LocalizedData.UnusedNICs = ($VssPortgroupNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVSPGTeamingFailover -f $VMHost)
                                        ColumnWidths = 12, 11, 11, 11, 11, 11, 11, 11, 11
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VssPortgroupNicTeaming | Sort-Object $LocalizedData.PortGroup, $LocalizedData.VirtualSwitch | Table @TableParams
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
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
        #endregion ESXi Host Network Section
    }

    end {}
}
