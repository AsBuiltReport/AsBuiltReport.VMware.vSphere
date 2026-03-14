function Get-AbrVSphereVM {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Virtual Machine information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVM
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VM)
    }

    process {
        try {
            if ($InfoLevel.VM -ge 1) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                if ($VMs) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Virtual Machine Summary Information
                        if ($InfoLevel.VM -eq 1) {
                            BlankLine
                            $VMSummary = [PSCustomObject]@{
                                $LocalizedData.TotalVMs = $VMs.Count
                                $LocalizedData.TotalvCPUs = ($VMs | Measure-Object -Property NumCpu -Sum).Sum
                                $LocalizedData.TotalMemory = Convert-DataSize ($VMs | Measure-Object -Property MemoryGB -Sum).Sum
                                $LocalizedData.TotalProvisionedSpace = Convert-DataSize ($VMs | Measure-Object -Property ProvisionedSpaceGB -Sum).Sum
                                $LocalizedData.TotalUsedSpace = Convert-DataSize ($VMs | Measure-Object -Property UsedSpaceGB -Sum).Sum
                                $LocalizedData.VMsPoweredOn = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                                $LocalizedData.VMsPoweredOff = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count
                                $LocalizedData.VMsOrphaned = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Orphaned' }).Count
                                $LocalizedData.VMsInaccessible = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Inaccessible' }).Count
                                $LocalizedData.VMsSuspended = ($VMs | Where-Object { $_.PowerState -eq 'Suspended' }).Count
                                $LocalizedData.VMsWithSnapshots = ($VMs | Where-Object { $_.ExtensionData.Snapshot }).Count
                                $LocalizedData.GuestOSTypes = (($VMs | Get-View).Summary.Config.GuestFullName | Select-Object -Unique).Count
                                $LocalizedData.VMToolsOKCount = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOK' }).Count
                                $LocalizedData.VMToolsOldCount = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOld' }).Count
                                $LocalizedData.VMToolsNotRunningCount = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotRunning' }).Count
                                $LocalizedData.VMToolsNotInstalledCount = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotInstalled' }).Count
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVMSummary -f $vCenterServerName)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMSummary | Table @TableParams
                        }
                        #endregion Virtual Machine Summary Information

                        #region Virtual Machine Advanced Summary
                        if ($InfoLevel.VM -eq 2) {
                            BlankLine
                            $VMSnapshotList = $VMs.Extensiondata.Snapshot.RootSnapshotList
                            $VMInfo = foreach ($VM in $VMs) {
                                $VMView = $VM | Get-View
                                [PSCustomObject]@{
                                    $LocalizedData.VirtualMachine = $VM.Name
                                    $LocalizedData.PowerState = switch ($VM.PowerState) {
                                        'PoweredOn' { $LocalizedData.On }
                                        'PoweredOff' { $LocalizedData.Off }
                                        default { $VM.PowerState }
                                    }
                                    $LocalizedData.IPAddress = if ($VMView.Guest.IpAddress) {
                                        $VMView.Guest.IpAddress
                                    } else {
                                        '--'
                                    }
                                    $LocalizedData.vCPUs = $VM.NumCpu
                                    $LocalizedData.Memory = Convert-DataSize $VM.MemoryGB -RoundUnits 0
                                    $LocalizedData.Provisioned = Convert-DataSize $VM.ProvisionedSpaceGB
                                    $LocalizedData.Used = Convert-DataSize $VM.UsedSpaceGB
                                    $LocalizedData.HWVersion = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                    $LocalizedData.VMToolsStatus = switch ($VMView.Guest.ToolsStatus) {
                                        'toolsOld' { $LocalizedData.ToolsOld }
                                        'toolsOK' { $LocalizedData.ToolsOK }
                                        'toolsNotRunning' { $LocalizedData.ToolsNotRunning }
                                        'toolsNotInstalled' { $LocalizedData.ToolsNotInstalled }
                                        default { $VMView.Guest.ToolsStatus }
                                    }
                                }
                            }
                            if ($Healthcheck.VM.VMToolsStatus) {
                                $VMInfo | Where-Object { $_.$($LocalizedData.VMToolsStatus) -ne $LocalizedData.ToolsOK } | Set-Style -Style Warning -Property $LocalizedData.VMToolsStatus
                            }
                            if ($Healthcheck.VM.PowerState) {
                                $VMInfo | Where-Object { $_.$($LocalizedData.PowerState) -ne $LocalizedData.On } | Set-Style -Style Warning -Property $LocalizedData.PowerState
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVMAdvancedSummary -f $vCenterServerName)
                                ColumnWidths = 21, 8, 16, 9, 9, 9, 9, 9, 10
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMInfo | Table @TableParams

                            #region VM Snapshot Information
                            if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                Section -Style Heading3 $LocalizedData.SnapshotHeading {
                                    $VMSnapshotInfo = foreach ($VMSnapshot in $VMSnapshotList) {
                                        [PSCustomObject]@{
                                            $LocalizedData.VirtualMachine = $VMLookup."$($VMSnapshot.VM)"
                                            $LocalizedData.SnapshotName = $VMSnapshot.Name
                                            $LocalizedData.SnapshotDescription = $VMSnapshot.Description
                                            $LocalizedData.DaysOld = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                        }
                                    }
                                    if ($Healthcheck.VM.VMSnapshots) {
                                        $VMSnapshotInfo | Where-Object { $_.$($LocalizedData.DaysOld) -ge 7 } | Set-Style -Style Warning
                                        $VMSnapshotInfo | Where-Object { $_.$($LocalizedData.DaysOld) -ge 14 } | Set-Style -Style Critical
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVMSnapshotSummary -f $vCenterServerName)
                                        ColumnWidths = 30, 30, 30, 10
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMSnapshotInfo | Table @TableParams
                                }
                            }
                            #endregion VM Snapshot Information
                        }
                        #endregion Virtual Machine Advanced Summary

                        #region Virtual Machine Detailed Information
                        if ($InfoLevel.VM -ge 3) {
                            if ($UserPrivileges -contains 'StorageProfile.View') {
                                $VMSpbmConfig = Get-SpbmEntityConfiguration -VM ($VMs) | Where-Object { $null -ne $_.StoragePolicy }
                            } else {
                                Write-PScriboMessage $LocalizedData.InsufficientPrivStoragePolicy
                            }
                            if ($InfoLevel.VM -ge 4) {
                                $VMHardDisks = Get-HardDisk -VM ($VMs) -Server $vCenter
                            }
                            $VMComplianceData = $null
                            if ($UserPrivileges -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                                if ($VUMConnection) {
                                    Try {
                                        $VMComplianceData = $VMs | Get-Compliance -ErrorAction SilentlyContinue
                                    } Catch {
                                        Write-PScriboMessage -Message $LocalizedData.VUMComplianceError
                                    }
                                }
                            } else {
                                Write-PScriboMessage -Message $LocalizedData.InsufficientPrivVUMCompliance
                            }
                            foreach ($VM in $VMs) {
                                Section -Style Heading3 $VM.name {
                                    $VMUptime = Get-Uptime -VM $VM
                                    $VMSpbmPolicy = $VMSpbmConfig | Where-Object { $_.entity -eq $vm }
                                    $VMView = $VM | Get-View
                                    $VMSnapshotList = $vmview.Snapshot.RootSnapshotList
                                    $VMDetail = [PSCustomObject]@{
                                        $LocalizedData.VirtualMachine = $VM.Name
                                        $LocalizedData.ID = $VM.Id
                                        $LocalizedData.OperatingSystem = $VMView.Summary.Config.GuestFullName
                                        $LocalizedData.HardwareVersion = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                        $LocalizedData.PowerState = switch ($VM.PowerState) {
                                            'PoweredOn' { $LocalizedData.On }
                                            'PoweredOff' { $LocalizedData.Off }
                                            default { $TextInfo.ToTitleCase($VM.PowerState) }
                                        }
                                        $LocalizedData.ConnectionState = $TextInfo.ToTitleCase($VM.ExtensionData.Runtime.ConnectionState)
                                        $LocalizedData.VMToolsStatus = switch ($VMView.Guest.ToolsStatus) {
                                            'toolsOld' { $LocalizedData.ToolsOld }
                                            'toolsOK' { $LocalizedData.ToolsOK }
                                            'toolsNotRunning' { $LocalizedData.ToolsNotRunning }
                                            'toolsNotInstalled' { $LocalizedData.ToolsNotInstalled }
                                            default { $TextInfo.ToTitleCase($VMView.Guest.ToolsStatus) }
                                        }
                                        $LocalizedData.FaultToleranceState = switch ($VMView.Runtime.FaultToleranceState) {
                                            'notConfigured' { $LocalizedData.FTNotConfigured }
                                            'needsSecondary' { $LocalizedData.FTNeedsSecondary }
                                            'running' { $LocalizedData.FTRunning }
                                            'disabled' { $LocalizedData.FTDisabled }
                                            'starting' { $LocalizedData.FTStarting }
                                            'enabled' { $LocalizedData.FTEnabled }
                                            default { $TextInfo.ToTitleCase($VMview.Runtime.FaultToleranceState) }
                                        }
                                        $LocalizedData.VMHost = $VM.VMHost.Name
                                        $LocalizedData.Parent = $VM.VMHost.Parent.Name
                                        $LocalizedData.ParentFolder = $VM.Folder.Name
                                        $LocalizedData.ParentResourcePool = $VM.ResourcePool.Name
                                        $LocalizedData.vCPUs = $VM.NumCpu
                                        $LocalizedData.CoresPerSocket = $VM.CoresPerSocket
                                        $LocalizedData.CPUShares = "$($VM.VMResourceConfiguration.CpuSharesLevel) / $($VM.VMResourceConfiguration.NumCpuShares)"
                                        $LocalizedData.CPUReservation = $VM.VMResourceConfiguration.CpuReservationMhz
                                        $LocalizedData.CPULimit = "$($VM.VMResourceConfiguration.CpuReservationMhz) MHz"
                                        $LocalizedData.CPUHotAdd = if ($VMView.Config.CpuHotAddEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.CPUHotRemove = if ($VMView.Config.CpuHotRemoveEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.MemoryAllocation = Convert-DataSize $VM.memoryGB -RoundUnits 0
                                        $LocalizedData.MemoryShares = "$($VM.VMResourceConfiguration.MemSharesLevel) / $($VM.VMResourceConfiguration.NumMemShares)"
                                        $LocalizedData.MemoryHotAdd = if ($VMView.Config.MemoryHotAddEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.vNICs = $VMView.Summary.Config.NumEthernetCards
                                        $LocalizedData.DNSName = if ($VMView.Guest.HostName) {
                                            $VMView.Guest.HostName
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.Networks = if ($VMView.Guest.Net.Network) {
                                            (($VMView.Guest.Net | Where-Object { $null -ne $_.Network } | Select-Object Network | Sort-Object Network).Network -join ', ')
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.IPAddress = if ($VMView.Guest.Net.IpAddress) {
                                            (($VMView.Guest.Net | Where-Object { ($null -ne $_.Network) -and ($null -ne $_.IpAddress) } | Select-Object IpAddress | Sort-Object IpAddress).IpAddress -join ', ')
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.MACAddress = if ($VMView.Guest.Net.MacAddress) {
                                            (($VMView.Guest.Net | Where-Object { $null -ne $_.Network } | Select-Object -Property MacAddress).MacAddress -join ', ')
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.vDisks = $VMView.Summary.Config.NumVirtualDisks
                                        $LocalizedData.ProvisionedSpace = Convert-DataSize $VM.ProvisionedSpaceGB
                                        $LocalizedData.UsedSpace = Convert-DataSize $VM.UsedSpaceGB
                                        $LocalizedData.ChangedBlockTracking = if ($VMView.Config.ChangeTrackingEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.StorageBasedPolicy = if ($VMSpbmPolicy.StoragePolicy.Name) {
                                            $TextInfo.ToTitleCase($VMSpbmPolicy.StoragePolicy.Name)
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.StorageBasedPolicyCompliance = switch ($VMSpbmPolicy.ComplianceStatus) {
                                            $null { '--' }
                                            'compliant' { $LocalizedData.Compliant }
                                            'nonCompliant' { $LocalizedData.NonCompliant }
                                            'unknown' { $LocalizedData.Unknown }
                                            default { $TextInfo.ToTitleCase($VMSpbmPolicy.ComplianceStatus) }
                                        }
                                    }
                                    $MemberProps = @{
                                        'InputObject' = $VMDetail
                                        'MemberType' = 'NoteProperty'
                                    }
                                    #if ($VMView.Config.CreateDate) {
                                    #    Add-Member @MemberProps -Name 'Creation Date' -Value ($VMView.Config.CreateDate).ToLocalTime().ToString()
                                    #}
                                    if ($Options.ShowTags -and ($TagAssignments | Where-Object { $_.entity -eq $VM })) {
                                        Add-Member @MemberProps -Name $LocalizedData.Tags -Value $(($TagAssignments | Where-Object { $_.entity -eq $VM }).Tag -join ', ')
                                    }
                                    if ($VM.Notes) {
                                        Add-Member @MemberProps -Name $LocalizedData.Notes -Value $VM.Notes
                                    }
                                    if ($VMView.Runtime.BootTime) {
                                        Add-Member @MemberProps -Name $LocalizedData.BootTime -Value ($VMView.Runtime.BootTime).ToLocalTime().ToString()
                                    }
                                    if ($VMUptime.UptimeDays) {
                                        Add-Member @MemberProps -Name $LocalizedData.UptimeDays -Value $VMUptime.UptimeDays
                                    }

                                    #region VM Health Checks
                                    if ($Healthcheck.VM.VMToolsStatus) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.VMToolsStatus) -ne $LocalizedData.ToolsOK } | Set-Style -Style Warning -Property $LocalizedData.VMToolsStatus
                                    }
                                    if ($Healthcheck.VM.PowerState) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.PowerState) -ne $LocalizedData.On } | Set-Style -Style Warning -Property $LocalizedData.PowerState
                                    }
                                    if ($Healthcheck.VM.ConnectionState) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.ConnectionState) -ne 'Connected' } | Set-Style -Style Critical -Property $LocalizedData.ConnectionState
                                    }
                                    if ($Healthcheck.VM.CpuHotAdd) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.CPUHotAdd) -eq $LocalizedData.Enabled } | Set-Style -Style Warning -Property $LocalizedData.CPUHotAdd
                                    }
                                    if ($Healthcheck.VM.CpuHotRemove) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.CPUHotRemove) -eq $LocalizedData.Enabled } | Set-Style -Style Warning -Property $LocalizedData.CPUHotRemove
                                    }
                                    if ($Healthcheck.VM.MemoryHotAdd) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.MemoryHotAdd) -eq $LocalizedData.Enabled } | Set-Style -Style Warning -Property $LocalizedData.MemoryHotAdd
                                    }
                                    if ($Healthcheck.VM.ChangeBlockTracking) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.ChangedBlockTracking) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.ChangedBlockTracking
                                    }
                                    if ($Healthcheck.VM.SpbmPolicyCompliance) {
                                        $VMDetail | Where-Object { $_.$($LocalizedData.StorageBasedPolicyCompliance) -eq $LocalizedData.Unknown } | Set-Style -Style Warning -Property $LocalizedData.StorageBasedPolicyCompliance
                                        $VMDetail | Where-Object { $_.$($LocalizedData.StorageBasedPolicyCompliance) -eq $LocalizedData.NonCompliant } | Set-Style -Style Critical -Property $LocalizedData.StorageBasedPolicyCompliance
                                    }
                                    #endregion VM Health Checks
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVMConfig -f $VM.Name)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMDetail | Table @TableParams

                                    if ($InfoLevel.VM -ge 4) {
                                        $VMnics = $VM.Guest.Nics | Where-Object { $null -ne $_.Device } | Sort-Object Device
                                        $VMHdds = $VMHardDisks | Where-Object { $_.ParentId -eq $VM.Id } | Sort-Object Name
                                        $SCSIControllers = $VMView.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -match "SCSI Controller" }
                                        $VMGuestVols = $VM.Guest.Disks | Sort-Object Path
                                        if ($VMnics) {
                                            Section -Style Heading4 $LocalizedData.NetworkAdapters {
                                                $VMnicInfo = foreach ($VMnic in $VMnics) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.NICName = $VMnic.Device.DeviceInfo.Label
                                                        $LocalizedData.NICConnected = if ($VMnic.Connected) { $LocalizedData.Connected } else { $LocalizedData.NotConnected }
                                                        $LocalizedData.NetworkName = switch -wildcard ($VMnic.NetworkName) {
                                                            'dvportgroup*' { $VDPortgroupLookup."$($VMnic.NetworkName)" }
                                                            default { $VMnic.NetworkName }
                                                        }
                                                        $LocalizedData.NICType = $VMnic.Device.Type
                                                        $LocalizedData.IPAddress = $VMnic.IpAddress -join [Environment]::NewLine
                                                        $LocalizedData.NICMAC = $VMnic.Device.MacAddress
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVMNetworkAdapters -f $VM.Name)
                                                    ColumnWidths = 20, 12, 16, 12, 20, 20
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMnicInfo | Table @TableParams
                                            }
                                        }
                                        if ($SCSIControllers) {
                                            Section -Style Heading4 $LocalizedData.SCSIControllers {
                                                $VMScsiControllers = foreach ($VMSCSIController in $SCSIControllers) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.Device = $VMSCSIController.DeviceInfo.Label
                                                        $LocalizedData.ControllerType = $VMSCSIController.DeviceInfo.Summary
                                                        $LocalizedData.BusSharing = switch ($VMSCSIController.SharedBus) {
                                                            'noSharing' { $LocalizedData.None }
                                                            default { $VMSCSIController.SharedBus }
                                                        }
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVMSCSIControllers -f $VM.Name)
                                                    ColumnWidths = 33, 34, 33
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMScsiControllers | Sort-Object $LocalizedData.Device | Table @TableParams
                                            }
                                        }
                                        if ($VMHdds) {
                                            Section -Style Heading4 $LocalizedData.HardDisks {
                                                if ($InfoLevel.VM -eq 4) {
                                                    $VMHardDiskInfo = foreach ($VMHdd in $VMHdds) {
                                                        $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                        $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                        [PSCustomObject]@{
                                                            $LocalizedData.DiskName = $VMHdd.Name
                                                            $LocalizedData.DiskDatastore = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                            $LocalizedData.Capacity = Convert-DataSize $VMHdd.CapacityGB
                                                            $LocalizedData.DiskProvisioning = switch ($VMHdd.StorageFormat) {
                                                                'EagerZeroedThick' { $LocalizedData.ThickEagerZeroed }
                                                                'LazyZeroedThick' { $LocalizedData.ThickLazyZeroed }
                                                                $null { '--' }
                                                                default { $VMHdd.StorageFormat }
                                                            }
                                                            $LocalizedData.DiskType = switch ($VMHdd.DiskType) {
                                                                'RawPhysical' { $LocalizedData.PhysicalRDM }
                                                                'RawVirtual' { $LocalizedData.VirtualRDM }
                                                                'Flat' { $LocalizedData.VMDK }
                                                                default { $VMHdd.DiskType }
                                                            }
                                                            $LocalizedData.DiskMode = switch ($VMHdd.Persistence) {
                                                                'IndependentPersistent' { $LocalizedData.IndependentPersistent }
                                                                'IndependentNonPersistent' { $LocalizedData.IndependentNonpersistent }
                                                                'Persistent' { $LocalizedData.Dependent }
                                                                default { $VMHdd.Persistence }
                                                            }
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = ($LocalizedData.TableVMHardDiskConfig -f $VM.Name)
                                                        ColumnWidths = 15, 25, 15, 15, 15, 15
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHardDiskInfo | Table @TableParams
                                                } else {
                                                    foreach ($VMHdd in $VMHdds) {
                                                        Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMHdd.Name)" {
                                                            $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                            $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                            $VMHardDiskInfo = [PSCustomObject]@{
                                                                $LocalizedData.DiskDatastore = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                                $LocalizedData.Capacity = Convert-DataSize $VMHdd.CapacityGB
                                                                $LocalizedData.DiskPath = $VMHdd.Filename.Substring($VMHdd.Filename.IndexOf("]") + 2)
                                                                $LocalizedData.DiskShares = "$($TextInfo.ToTitleCase($VMHdd.ExtensionData.Shares.Level)) / $($VMHdd.ExtensionData.Shares.Shares)"
                                                                $LocalizedData.DiskLimitIOPs = switch ($VMHdd.ExtensionData.StorageIOAllocation.Limit) {
                                                                    '-1' { $LocalizedData.Unlimited }
                                                                    default { $VMHdd.ExtensionData.StorageIOAllocation.Limit }
                                                                }
                                                                $LocalizedData.DiskProvisioning = switch ($VMHdd.StorageFormat) {
                                                                    'EagerZeroedThick' { $LocalizedData.ThickEagerZeroed }
                                                                    'LazyZeroedThick' { $LocalizedData.ThickLazyZeroed }
                                                                    $null { '--' }
                                                                    default { $VMHdd.StorageFormat }
                                                                }
                                                                $LocalizedData.DiskType = switch ($VMHdd.DiskType) {
                                                                    'RawPhysical' { $LocalizedData.PhysicalRDM }
                                                                    'RawVirtual' { $LocalizedData.VirtualRDM }
                                                                    'Flat' { $LocalizedData.VMDK }
                                                                    default { $VMHdd.DiskType }
                                                                }
                                                                $LocalizedData.DiskMode = switch ($VMHdd.Persistence) {
                                                                    'IndependentPersistent' { $LocalizedData.IndependentPersistent }
                                                                    'IndependentNonPersistent' { $LocalizedData.IndependentNonpersistent }
                                                                    'Persistent' { $LocalizedData.Dependent }
                                                                    default { $VMHdd.Persistence }
                                                                }
                                                                $LocalizedData.SCSIController = $SCSIController.DeviceInfo.Label
                                                                $LocalizedData.SCSIAddress = "$($SCSIController.BusNumber):$($VMHdd.ExtensionData.UnitNumber)"
                                                            }
                                                            $TableParams = @{
                                                                Name = ($LocalizedData.TableVMHardDisk -f $VMHdd.Name, $VM.Name)
                                                                List = $true
                                                                ColumnWidths = 25, 75
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VMHardDiskInfo | Table @TableParams
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        if ($VMGuestVols) {
                                            Section -Style Heading4 $LocalizedData.GuestVolumes {
                                                $VMGuestDiskInfo = foreach ($VMGuestVol in $VMGuestVols) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.Path = $VMGuestVol.Path
                                                        $LocalizedData.Capacity = Convert-DataSize $VMGuestVol.CapacityGB
                                                        $LocalizedData.UsedSpace = Convert-DataSize (($VMGuestVol.CapacityGB) - ($VMGuestVol.FreeSpaceGB))
                                                        $LocalizedData.FreeSpace = Convert-DataSize $VMGuestVol.FreeSpaceGB
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVMGuestVolumes -f $VM.Name)
                                                    ColumnWidths = 25, 25, 25, 25
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMGuestDiskInfo | Table @TableParams
                                            }
                                        }
                                    }


                                    if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                        Section -Style Heading4 $LocalizedData.SnapshotHeading {
                                            $VMSnapshots = foreach ($VMSnapshot in $VMSnapshotList) {
                                                [PSCustomObject]@{
                                                    $LocalizedData.SnapshotName = $VMSnapshot.Name
                                                    $LocalizedData.SnapshotDescription = $VMSnapshot.Description
                                                    $LocalizedData.DaysOld = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                                }
                                            }
                                            if ($Healthcheck.VM.VMSnapshots) {
                                                $VMSnapshots | Where-Object { $_.$($LocalizedData.DaysOld) -ge 7 } | Set-Style -Style Warning
                                                $VMSnapshots | Where-Object { $_.$($LocalizedData.DaysOld) -ge 14 } | Set-Style -Style Critical
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVMSnapshots -f $VM.Name)
                                                ColumnWidths = 45, 45, 10
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VMSnapshots | Table @TableParams
                                        }
                                    }

                                    #region VM VUM Compliance
                                    $VMCompliances = $VMComplianceData | Where-Object { $_.Entity -eq $VM }
                                    if ($VMCompliances) {
                                        BlankLine
                                        Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.VUMCompliance {
                                            $VMComplianceInfo = foreach ($VMCompliance in $VMCompliances) {
                                                $compStatus = switch ($VMCompliance.Status) {
                                                    'NotCompliant' { $LocalizedData.NotCompliant }
                                                    'Incompatible' { $LocalizedData.Incompatible }
                                                    'Unknown'      { $LocalizedData.Unknown }
                                                    default        { $VMCompliance.Status }
                                                }
                                                [PSCustomObject]@{
                                                    $LocalizedData.VUMBaselineName = $VMCompliance.Baseline.Name
                                                    $LocalizedData.VUMStatus       = $compStatus
                                                }
                                            }
                                            if ($Healthcheck.VM.VUMCompliance) {
                                                $VMComplianceInfo | Where-Object { $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.Unknown } | Set-Style -Style Warning -Property $LocalizedData.VUMStatus
                                                $VMComplianceInfo | Where-Object { $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.NotCompliant -or $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.Incompatible } | Set-Style -Style Critical -Property $LocalizedData.VUMStatus
                                            }
                                            $TableParams = @{
                                                Name         = ($LocalizedData.TableVUMCompliance -f $VM.Name)
                                                ColumnWidths = 75, 25
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VMComplianceInfo | Sort-Object $LocalizedData.VUMBaselineName | Table @TableParams
                                        }
                                    }
                                    #endregion VM VUM Compliance
                                }
                            }
                        }
                        #endregion Virtual Machine Detailed Information
                    }
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
