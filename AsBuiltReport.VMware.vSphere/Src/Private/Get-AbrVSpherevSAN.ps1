function Get-AbrVSpherevSAN {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere vSAN information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSpherevSAN
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.vSAN)
    }

    process {
        try {
            if (($InfoLevel.vSAN -ge 1) -and ($vCenter.Version -gt 6)) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                $VsanClusters = Get-VsanClusterConfiguration -Server $vCenter | Where-Object { $_.vsanenabled -eq $true } | Sort-Object Name
                if ($VsanClusters) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region vSAN Cluster Advanced Summary
                        if ($InfoLevel.vSAN -le 2) {
                            BlankLine
                            $VsanClusterInfo = foreach ($VsanCluster in $VsanClusters) {
                                [PSCustomObject]@{
                                    $LocalizedData.Cluster = $VsanCluster.Name
                                    $LocalizedData.StorageType = if ($VsanCluster.VsanEsaEnabled) {
                                        'ESA'
                                    } else {
                                        'OSA'
                                    }
                                    $LocalizedData.NumHosts = $VsanCluster.Cluster.ExtensionData.Host.Count
                                    $LocalizedData.Stretched = if ($VsanCluster.StretchedClusterEnabled) {
                                        $LocalizedData.Yes
                                    } else {
                                        $LocalizedData.No
                                    }
                                    $LocalizedData.Deduplication = if ($VsanCluster.SpaceEfficiencyEnabled) {
                                        $LocalizedData.Enabled
                                    } else {
                                        $LocalizedData.Disabled
                                    }
                                    $LocalizedData.Encryption = if ($VsanCluster.EncryptionEnabled) {
                                        $LocalizedData.Enabled
                                    } else {
                                        $LocalizedData.Disabled
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVSANClusterSummary -f $vCenterServerName)
                                ColumnWidths = 25, 15, 15, 15, 15, 15
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VsanClusterInfo | Table @TableParams
                        }
                        #endregion vSAN Cluster Advanced Summary

                        #region vSAN Cluster Detailed Information
                        if ($InfoLevel.vSAN -ge 3) {
                            foreach ($VsanCluster in $VsanClusters) {
                                $VsanSpaceUsage = Get-VsanSpaceUsage -Cluster $VsanCluster.Name
                                $VsanUsedCapacity = $VsanSpaceUsage.CapacityGB - $VsanSpaceUsage.FreeSpaceGB

                                # Calculate percentages
                                $VsanUsedPercent = if (0 -in @($VsanUsedCapacity, $VsanSpaceUsage.CapacityGB)) { 0 } else { [math]::Round(($VsanUsedCapacity / $VsanSpaceUsage.CapacityGB) * 100, 2) }
                                $VsanFreePercent = if (0 -in @($VsanUsedCapacity, $VsanSpaceUsage.CapacityGB)) { 0 } else { [math]::Round(($VsanSpaceUsage.FreeSpaceGB / $VsanSpaceUsage.CapacityGB) * 100, 2) }

                                #region vSAN Cluster Section
                                Section -Style Heading3 $VsanCluster.Name {
                                    if ($VsanCluster.VsanEsaEnabled) {
                                        Write-PScriboMessage -Message ($LocalizedData.CollectingESA -f $VsanCluster.Name)
                                        try {
                                            $VsanStoragePoolDisk = Get-VsanStoragePoolDisk -Cluster $VsanCluster.Cluster
                                            $VsanDiskFormat = $VsanStoragePoolDisk.DiskFormatVersion | Select-Object -First 1 -Unique
                                            $VsanClusterDetail = [PSCustomObject]@{
                                                $LocalizedData.Cluster = $VsanCluster.Name
                                                $LocalizedData.ID = $VsanCluster.Id
                                                $LocalizedData.StorageType = if ($VsanCluster.VsanEsaEnabled) {
                                                    'ESA'
                                                } else {
                                                    'OSA'
                                                }
                                                $LocalizedData.Stretched = if ($VsanCluster.StretchedClusterEnabled) {
                                                    $LocalizedData.Yes
                                                } else {
                                                    $LocalizedData.No
                                                }
                                                $LocalizedData.NumberOfHosts = $VsanCluster.Cluster.ExtensionData.Host.Count
                                                $LocalizedData.NumberOfDisks = $VsanStoragePoolDisk.Count
                                                $LocalizedData.DiskClaimMode = $VsanCluster.VsanDiskClaimMode
                                                $LocalizedData.DisksFormat = $VsanDiskFormat
                                                $LocalizedData.PerformanceService = if ($VsanCluster.PerformanceServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.FileService = if ($VsanCluster.FileServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.iSCSITargetService = if ($VsanCluster.IscsiTargetServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.Deduplication = if ($VsanCluster.SpaceEfficiencyEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.Encryption = if ($VsanCluster.EncryptionEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.HistoricalHealthService = if ($VsanCluster.HistoricalHealthEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.HealthCheck = if ($VsanCluster.HealthCheckEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.TotalCapacity = Convert-DataSize $VsanSpaceUsage.CapacityGB
                                                $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $VsanUsedCapacity), $VsanUsedPercent
                                                $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $VsanSpaceUsage.FreeSpaceGB), $VsanFreePercent
                                                $LocalizedData.PercentUsed = $VsanUsedPercent
                                                $LocalizedData.HCLLastUpdated = ($VsanCluster.TimeOfHclUpdate).ToLocalTime().ToString()
                                            }
                                            if ($Healthcheck.vSAN.CapacityUtilization) {
                                                $VsanClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                                $VsanClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and
                                                    $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                            }
                                            if ($InfoLevel.vSAN -ge 4) {
                                                $VsanClusterDetail | Add-Member -MemberType NoteProperty -Name $LocalizedData.Hosts -Value (($VsanStoragePoolDisk.Host | Select-Object -Unique | Sort-Object Name) -join ', ')
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVSANConfiguration -f $VsanCluster.Name)
                                                List = $true
                                                Columns = $LocalizedData.Cluster, $LocalizedData.ID, $LocalizedData.StorageType, $LocalizedData.Stretched, $LocalizedData.NumberOfHosts, $LocalizedData.NumberOfDisks, $LocalizedData.DiskClaimMode, $LocalizedData.DisksFormat, $LocalizedData.PerformanceService, $LocalizedData.FileService, $LocalizedData.iSCSITargetService, $LocalizedData.Deduplication, $LocalizedData.Encryption, $LocalizedData.HistoricalHealthService, $LocalizedData.HealthCheck, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity, $LocalizedData.HCLLastUpdated
                                                ColumnWidths = 40, 60
                                            }
                                            if ($InfoLevel.vSAN -ge 4) {
                                                $TableParams['Columns'] += $LocalizedData.Hosts
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VsanClusterDetail | Table @TableParams
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.ESAError -f $VsanCluster.Name, $_.Exception.Message)
                                        }

                                        #region vSAN Services
                                        try {
                                            Section -Style Heading4 $LocalizedData.ServicesSection {
                                                $VsanServices = @(
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.PerformanceService; $LocalizedData.Status = if ($VsanCluster.PerformanceServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.FileService; $LocalizedData.Status = if ($VsanCluster.FileServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.iSCSITargetService; $LocalizedData.Status = if ($VsanCluster.IscsiTargetServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.Deduplication; $LocalizedData.Status = if ($VsanCluster.SpaceEfficiencyEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.Encryption; $LocalizedData.Status = if ($VsanCluster.EncryptionEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.HistoricalHealthService; $LocalizedData.Status = if ($VsanCluster.HistoricalHealthEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.HealthCheck; $LocalizedData.Status = if ($VsanCluster.HealthCheckEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                )
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVSANServices -f $VsanCluster.Name)
                                                    ColumnWidths = 50, 50
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VsanServices | Table @TableParams
                                            }
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.ServicesError -f $VsanCluster.Name, $_.Exception.Message)
                                        }
                                        #endregion vSAN Services

                                        if ($VsanStoragePoolDisk) {
                                            Write-PScriboMessage -Message ($LocalizedData.CollectingDisks -f $VsanCluster.Name)
                                            try {
                                                Section -Style Heading4 $LocalizedData.DisksSection {
                                                    $vDisks = foreach ($Disk in $VsanStoragePoolDisk) {
                                                        [PSCustomObject]@{
                                                            $LocalizedData.DiskName = $Disk.Name
                                                            $LocalizedData.Name = $Disk.ExtensionData.DisplayName
                                                            $LocalizedData.DriveType = if ($Disk.IsSsd) {
                                                                $LocalizedData.Flash
                                                            } else {
                                                                $LocalizedData.HDD
                                                            }
                                                            $LocalizedData.Host = $Disk.Host.Name
                                                            $LocalizedData.State = if ($Disk.IsMounted) {
                                                                $LocalizedData.Mounted
                                                            } else {
                                                                $LocalizedData.Unmounted
                                                            }
                                                            $LocalizedData.Encrypted = if ($Disk.IsEncryped) {
                                                                $LocalizedData.Yes
                                                            } else {
                                                                $LocalizedData.No
                                                            }
                                                            $LocalizedData.Capacity = Convert-DataSize $Disk.CapacityGB
                                                            $LocalizedData.SerialNumber = $Disk.ExtensionData.SerialNumber
                                                            $LocalizedData.Vendor = $Disk.ExtensionData.Vendor
                                                            $LocalizedData.Model = $Disk.ExtensionData.Model
                                                            $LocalizedData.DiskType = $Disk.DiskType
                                                            $LocalizedData.DiskFormatVersion = $Disk.DiskFormatVersion
                                                        }
                                                    }

                                                    if ($InfoLevel.vSAN -ge 4) {
                                                        $vDisks | Sort-Object $LocalizedData.Host | ForEach-Object {
                                                            $vDisk = $_
                                                            Section -Style NOTOCHeading5 -ExcludeFromTOC "$($vDisk.$($LocalizedData.Name)) - $($vDisk.$($LocalizedData.Host))" {
                                                                $TableParams = @{
                                                                    Name = ($LocalizedData.TableDisk -f $vDisk.$($LocalizedData.Name), $vDisk.$($LocalizedData.Host))
                                                                    List = $true
                                                                    Columns = $LocalizedData.Name, $LocalizedData.State, $LocalizedData.DriveType, $LocalizedData.Encrypted, $LocalizedData.Capacity, $LocalizedData.Host, $LocalizedData.SerialNumber, $LocalizedData.Vendor, $LocalizedData.Model, $LocalizedData.DiskFormatVersion, $LocalizedData.DiskType
                                                                    ColumnWidths = 40, 60
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $vDisk | Table @TableParams
                                                            }
                                                        }
                                                    } else {
                                                        $TableParams = @{
                                                            Name = ($LocalizedData.TableVSANDisks -f $VsanCluster.Name)
                                                            Columns = $LocalizedData.DiskName, $LocalizedData.Capacity, $LocalizedData.State, $LocalizedData.Host
                                                            ColumnWidths = 40, 15, 15, 30
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $vDisks | Sort-Object $LocalizedData.Host | Table @TableParams
                                                    }
                                                }
                                            } catch {
                                                Write-PScriboMessage -Message ($LocalizedData.DiskError -f $VsanCluster.Name, $_.Exception.Message)
                                            }
                                        }
                                    } else {
                                        try {
                                            Write-PScriboMessage -Message ($LocalizedData.CollectingOSA -f $VsanCluster.Name)
                                            # Get vSAN Disk Groups
                                            $VsanDiskGroup = Get-VsanDiskGroup -Cluster $VsanCluster.Cluster
                                            $NumVsanDiskGroup = $VsanDiskGroup.Count
                                            # Get vSAN Disks (guard against null disk groups — e.g. unclaimed OSA cluster)
                                            if ($VsanDiskGroup) {
                                                $VsanDisk = Get-VsanDisk -VsanDiskGroup $VsanDiskGroup
                                            }
                                            $VsanDiskFormat = $VsanDisk.DiskFormatVersion | Select-Object -Unique
                                            # Count SSDs and HDDs
                                            $NumVsanSsd = ($VsanDisk | Where-Object { $_.IsSsd -eq $true } | Measure-Object).Count
                                            $NumVsanHdd = ($VsanDisk | Where-Object { $_.IsSsd -eq $false } | Measure-Object).Count
                                            # Determine Storage Type
                                            $VsanClusterType = if ($NumVsanHdd -gt 0) { $LocalizedData.HybridMode } else { $LocalizedData.AllFlash }
                                            $VsanClusterDetail = [PSCustomObject]@{
                                                $LocalizedData.Cluster = $VsanCluster.Name
                                                $LocalizedData.ID = $VsanCluster.Id
                                                $LocalizedData.StorageType = if ($VsanCluster.VsanEsaEnabled) {
                                                    'ESA'
                                                } else {
                                                    'OSA'
                                                }
                                                $LocalizedData.ClusterType = $VsanClusterType
                                                $LocalizedData.Stretched = if ($VsanCluster.StretchedClusterEnabled) {
                                                    $LocalizedData.Yes
                                                } else {
                                                    $LocalizedData.No
                                                }
                                                $LocalizedData.NumberOfHosts = $VsanCluster.Cluster.ExtensionData.Host.Count
                                                $LocalizedData.NumberOfDisks = $NumVsanSsd + $NumVsanHdd
                                                $LocalizedData.NumberOfDiskGroups = $NumVsanDiskGroup
                                                $LocalizedData.DiskClaimMode = $VsanCluster.VsanDiskClaimMode
                                                $LocalizedData.DisksFormat = $VsanDiskFormat
                                                $LocalizedData.PerformanceService = if ($VsanCluster.PerformanceServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.FileService = if ($VsanCluster.FileServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.iSCSITargetService = if ($VsanCluster.IscsiTargetServiceEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.Deduplication = if ($VsanCluster.SpaceEfficiencyEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.Encryption = if ($VsanCluster.EncryptionEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.HistoricalHealthService = if ($VsanCluster.HistoricalHealthEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.HealthCheck = if ($VsanCluster.HealthCheckEnabled) {
                                                    $LocalizedData.Enabled
                                                } else {
                                                    $LocalizedData.Disabled
                                                }
                                                $LocalizedData.TotalCapacity = Convert-DataSize $VsanSpaceUsage.CapacityGB
                                                $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $VsanUsedCapacity), $VsanUsedPercent
                                                $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $VsanSpaceUsage.FreeSpaceGB), $VsanFreePercent
                                                $LocalizedData.PercentUsed = $VsanUsedPercent
                                                $LocalizedData.HCLLastUpdated = ($VsanCluster.TimeOfHclUpdate).ToLocalTime().ToString()
                                            }
                                            if ($Healthcheck.vSAN.CapacityUtilization) {
                                                $VsanClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                                $VsanClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and
                                                    $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                            }
                                            if ($InfoLevel.vSAN -ge 4) {
                                                $VsanClusterDetail | Add-Member -MemberType NoteProperty -Name $LocalizedData.Hosts -Value (($VsanDiskGroup.VMHost | Select-Object -Unique | Sort-Object Name) -join ', ')
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableVSANConfiguration -f $VsanCluster.Name)
                                                List = $true
                                                Columns = $LocalizedData.Cluster, $LocalizedData.ID, $LocalizedData.StorageType, $LocalizedData.ClusterType, $LocalizedData.Stretched, $LocalizedData.NumberOfHosts, $LocalizedData.NumberOfDisks, $LocalizedData.NumberOfDiskGroups, $LocalizedData.DiskClaimMode, $LocalizedData.DisksFormat, $LocalizedData.PerformanceService, $LocalizedData.FileService, $LocalizedData.iSCSITargetService, $LocalizedData.Deduplication, $LocalizedData.Encryption, $LocalizedData.HistoricalHealthService, $LocalizedData.HealthCheck, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity, $LocalizedData.HCLLastUpdated
                                                ColumnWidths = 40, 60
                                            }
                                            if ($InfoLevel.vSAN -ge 4) {
                                                $TableParams['Columns'] += $LocalizedData.Hosts
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VsanClusterDetail | Table @TableParams
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.OSAError -f $VsanCluster.Name, $_.Exception.Message)
                                        }

                                        #region vSAN Services
                                        try {
                                            Section -Style Heading4 $LocalizedData.ServicesSection {
                                                $VsanServices = @(
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.PerformanceService; $LocalizedData.Status = if ($VsanCluster.PerformanceServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.FileService; $LocalizedData.Status = if ($VsanCluster.FileServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.iSCSITargetService; $LocalizedData.Status = if ($VsanCluster.IscsiTargetServiceEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.Deduplication; $LocalizedData.Status = if ($VsanCluster.SpaceEfficiencyEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.Encryption; $LocalizedData.Status = if ($VsanCluster.EncryptionEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.HistoricalHealthService; $LocalizedData.Status = if ($VsanCluster.HistoricalHealthEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                    [PSCustomObject]@{ $LocalizedData.Service = $LocalizedData.HealthCheck; $LocalizedData.Status = if ($VsanCluster.HealthCheckEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } }
                                                )
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVSANServices -f $VsanCluster.Name)
                                                    ColumnWidths = 50, 50
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VsanServices | Table @TableParams
                                            }
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.ServicesError -f $VsanCluster.Name, $_.Exception.Message)
                                        }
                                        #endregion vSAN Services

                                        if ($VsanDiskGroup) {
                                            Write-PScriboMessage -Message ($LocalizedData.CollectingDiskGroups -f $VsanCluster.Name)
                                            try {
                                                Section -Style Heading4 $LocalizedData.DiskGroupsSection {
                                                    $VsanDiskGroups = foreach ($DiskGroup in $VsanDiskGroup) {
                                                        $Disks = $DiskGroup | Get-VsanDisk
                                                        [PSCustomObject]@{
                                                            $LocalizedData.DiskGroup = $DiskGroup.Uuid
                                                            $LocalizedData.Host = $Diskgroup.VMHost.Name
                                                            $LocalizedData.NumDisks = $Disks.Count
                                                            $LocalizedData.State = if ($DiskGroup.IsMounted) {
                                                                $LocalizedData.Mounted
                                                            } else {
                                                                $LocalizedData.Unmounted
                                                            }
                                                            $LocalizedData.Type = switch ($DiskGroup.DiskGroupType) {
                                                                'AllFlash' { $LocalizedData.AllFlash }
                                                                default { $DiskGroup.DiskGroupType }
                                                            }
                                                            $LocalizedData.DisksFormat = $DiskGroup.DiskFormatVersion
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = ($LocalizedData.TableVSANDiskGroups -f $VsanCluster.Name)
                                                        ColumnWidths = 30, 30, 7, 11, 11, 11
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VsanDiskGroups | Sort-Object $LocalizedData.Host | Table @TableParams
                                                }
                                            } catch {
                                                Write-PScriboMessage -Message ($LocalizedData.DiskGroupError -f $VsanCluster.Name, $_.Exception.Message)
                                            }
                                        }

                                        if ($VsanDisk) {
                                            Write-PScriboMessage -Message ($LocalizedData.CollectingDisks -f $VsanCluster.Name)
                                            try {
                                                Section -Style Heading4 $LocalizedData.DisksSection {
                                                    $vDisks = foreach ($Disk in $VsanDisk) {
                                                        [PSCustomObject]@{
                                                            $LocalizedData.DiskName = $Disk.Name
                                                            $LocalizedData.Name = $Disk.ExtensionData.DisplayName
                                                            $LocalizedData.State = if ($Disk.IsMounted) {
                                                                $LocalizedData.Mounted
                                                            } else {
                                                                $LocalizedData.Unmounted
                                                            }
                                                            $LocalizedData.DriveType = if ($Disk.IsSsd) {
                                                                $LocalizedData.Flash
                                                            } else {
                                                                $LocalizedData.HDD
                                                            }
                                                            $LocalizedData.Host = $Disk.VsanDiskGroup.VMHost.Name
                                                            $LocalizedData.ClaimedAs = if ($Disk.IsCacheDisk) {
                                                                $LocalizedData.Cache
                                                            } else {
                                                                $LocalizedData.Capacity
                                                            }
                                                            $LocalizedData.Capacity = Convert-DataSize $Disk.CapacityGB
                                                            $LocalizedData.SerialNumber = $Disk.ExtensionData.SerialNumber
                                                            $LocalizedData.Vendor = $Disk.ExtensionData.Vendor
                                                            $LocalizedData.Model = $Disk.ExtensionData.Model
                                                            $LocalizedData.DiskGroup = $Disk.VsanDiskGroup.Uuid
                                                            $LocalizedData.DiskFormatVersion = $Disk.DiskFormatVersion
                                                        }
                                                    }

                                                    if ($InfoLevel.vSAN -ge 4) {
                                                        $vDisks | Sort-Object $LocalizedData.Host | ForEach-Object {
                                                            $vDisk = $_
                                                            Section -Style NOTOCHeading5 -ExcludeFromTOC "$($vDisk.$($LocalizedData.Name)) - $($vDisk.$($LocalizedData.Host))" {
                                                                $TableParams = @{
                                                                    Name = ($LocalizedData.TableDisk -f $vDisk.$($LocalizedData.Name), $vDisk.$($LocalizedData.Host))
                                                                    List = $true
                                                                    Columns = $LocalizedData.Name, $LocalizedData.DriveType, $LocalizedData.ClaimedAs, $LocalizedData.Capacity, $LocalizedData.Host, $LocalizedData.DiskGroup, $LocalizedData.SerialNumber, $LocalizedData.Vendor, $LocalizedData.Model, $LocalizedData.DiskFormatVersion
                                                                    ColumnWidths = 40, 60
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $vDisk | Table @TableParams
                                                            }
                                                        }
                                                    } else {
                                                        $TableParams = @{
                                                            Name = ($LocalizedData.TableVSANDisks -f $VsanCluster.Name)
                                                            Columns = $LocalizedData.Name, $LocalizedData.DriveType, $LocalizedData.ClaimedAs, $LocalizedData.Capacity, $LocalizedData.Host, $LocalizedData.DiskGroup
                                                            ColumnWidths = 21, 10, 10, 10, 21, 28
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $vDisks | Sort-Object $LocalizedData.Host | Table @TableParams
                                                    }
                                                }
                                            } catch {
                                                Write-PScriboMessage -Message ($LocalizedData.DiskError -f $VsanCluster.Name, $_.Exception.Message)
                                            }
                                        }
                                    }

                                    $VsanIscsiTargets = Get-VsanIscsiTarget -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue
                                    if ($VsanIscsiTargets) {
                                        Write-PScriboMessage -Message ($LocalizedData.CollectingiSCSITargets -f $VsanCluster.Name)
                                        try {
                                            Section -Style Heading4 $LocalizedData.iSCSITargetsSection {
                                                $VsanIscsiTargetInfo = foreach ($VsanIscsiTarget in $VsanIscsiTargets) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.IQN = $VsanIscsiTarget.IscsiQualifiedName
                                                        $LocalizedData.Alias = $VsanIscsiTarget.Name
                                                        $LocalizedData.LUNsCount = $VsanIscsiTarget.NumLuns
                                                        $LocalizedData.NetworkInterface = $VsanIscsiTarget.NetworkInterface
                                                        $LocalizedData.IOOwnerHost = $VsanIscsiTarget.IoOwnerVMHost.Name
                                                        $LocalizedData.TCPPort = $VsanIscsiTarget.TcpPort
                                                        $LocalizedData.Health = $TextInfo.ToTitleCase($VsanIscsiTarget.VsanHealth)
                                                        $LocalizedData.StoragePolicy = if ($VsanIscsiTarget.StoragePolicy.Name) {
                                                            $VsanIscsiTarget.StoragePolicy.Name
                                                        } else {
                                                            '--'
                                                        }
                                                        $LocalizedData.ComplianceStatus = $TextInfo.ToTitleCase($VsanIscsiTarget.SpbmComplianceStatus)
                                                        $LocalizedData.Authentication = $VsanIscsiTarget.AuthenticationType
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = ($LocalizedData.TableVSANiSCSITargets -f $VsanCluster.Name)
                                                    List = $true
                                                    ColumnWidths = 40, 60
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VsanIscsiTargetInfo | Table @TableParams
                                            }
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.iSCSITargetError -f $VsanCluster.Name, $_.Exception.Message)
                                        }
                                    }

                                    $VsanIscsiLuns = Get-VsanIscsiLun -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue | Sort-Object Name, LunId
                                    if ($VsanIscsiLuns) {
                                        Write-PScriboMessage -Message ($LocalizedData.CollectingiSCSILUNs -f $VsanCluster.Name)
                                        try {
                                            Section -Style Heading4 $LocalizedData.iSCSILUNsSection {
                                                $VsanIscsiLunInfo = foreach ($VsanIscsiLun in $VsanIscsiLuns) {
                                                    [PSCustomObject]@{
                                                        $LocalizedData.LUNName = $VsanIscsiLun.Name
                                                        $LocalizedData.LUNID = $VsanIscsiLun.LunId
                                                        $LocalizedData.Capacity = Convert-DataSize $VsanIscsiLun.CapacityGB
                                                        $LocalizedData.UsedCapacity = Convert-DataSize $VsanIscsiLun.UsedCapacityGB
                                                        $LocalizedData.State = if ($VsanIscsiLun.IsOnline) {
                                                            $LocalizedData.Online
                                                        } else {
                                                            $LocalizedData.Offline
                                                        }
                                                        $LocalizedData.Health = $TextInfo.ToTitleCase($VsanIscsiLun.VsanHealth)
                                                        $LocalizedData.StoragePolicy = if ($VsanIscsiLun.StoragePolicy.Name) {
                                                            $VsanIscsiLun.StoragePolicy.Name
                                                        } else {
                                                            '--'
                                                        }
                                                        $LocalizedData.ComplianceStatus = $TextInfo.ToTitleCase($VsanIscsiLun.SpbmComplianceStatus)
                                                    }
                                                }
                                                if ($InfoLevel.vSAN -ge 4) {
                                                    $TableParams = @{
                                                        Name = ($LocalizedData.TableVSANiSCSILUNs -f $VsanCluster.Name)
                                                        List = $true
                                                        ColumnWidths = 40, 60
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VsanIscsiLunInfo | Table @TableParams
                                                } else {
                                                    $TableParams = @{
                                                        Name = ($LocalizedData.TableVSANiSCSILUNs -f $VsanCluster.Name)
                                                        ColumnWidths = 28, 18, 18, 18, 18
                                                        Columns = $LocalizedData.LUNName, $LocalizedData.LUNID, $LocalizedData.Capacity, $LocalizedData.UsedCapacity, $LocalizedData.State
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VsanIscsiLunInfo | Table @TableParams
                                                }
                                            }
                                        } catch {
                                            Write-PScriboMessage -Message ($LocalizedData.iSCSILUNError -f $VsanCluster.Name, $_.Exception.Message)
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
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
