function Get-AbrVSphereDatastore {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Datastore information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereDatastore
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.Datastore)
    }

    process {
        try {
            if ($InfoLevel.Datastore -ge 1) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                if ($Datastores) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Datastore Infomative Information
                        if ($InfoLevel.Datastore -le 2) {
                            BlankLine
                            $DatastoreInfo = foreach ($Datastore in $Datastores) {

                                $DsUsedPercent = if (0 -in @($Datastore.FreeSpaceGB, $Datastore.CapacityGB)) { 0 } else { [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2) }
                                $DsFreePercent = if (0 -in @($Datastore.FreeSpaceGB, $Datastore.CapacityGB)) { 0 } else { [math]::Round(($Datastore.FreeSpaceGB / $Datastore.CapacityGB) * 100, 2) }
                                $DsUsedCapacityGB = ($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)

                                [PSCustomObject]@{
                                    $LocalizedData.Datastore = $Datastore.Name
                                    $LocalizedData.Type = $Datastore.Type
                                    $LocalizedData.Version = if ($Datastore.FileSystemVersion) {
                                        $Datastore.FileSystemVersion
                                    } else {
                                        '--'
                                    }
                                    $LocalizedData.NumHosts = $Datastore.ExtensionData.Host.Count
                                    $LocalizedData.NumVMs = $Datastore.ExtensionData.VM.Count
                                    $LocalizedData.TotalCapacity = Convert-DataSize $Datastore.CapacityGB
                                    $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $DsUsedCapacityGB), $DsUsedPercent
                                    $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $Datastore.FreeSpaceGB), $DsFreePercent
                                    $LocalizedData.PercentUsed = $DsUsedPercent
                                }
                            }
                            if ($Healthcheck.Datastore.CapacityUtilization) {
                                $DatastoreInfo | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                $DatastoreInfo | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and
                                    $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDatastoreSummary -f $vCenterServerName)
                                Columns = $LocalizedData.Datastore, $LocalizedData.Type, $LocalizedData.Version, $LocalizedData.NumHosts, $LocalizedData.NumVMs, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                ColumnWidths = 21, 10, 9, 9, 9, 14, 14, 14
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DatastoreInfo | Sort-Object $LocalizedData.Datastore | Table @TableParams
                        }
                        #endregion Datastore Advanced Summary

                        #region Datastore Detailed Information
                        if ($InfoLevel.Datastore -ge 3) {
                            foreach ($Datastore in $Datastores) {
                                $DsUsedPercent = if (0 -in @($Datastore.FreeSpaceGB, $Datastore.CapacityGB)) { 0 } else { [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2) }
                                $DSFreePercent = if (0 -in @($Datastore.FreeSpaceGB, $Datastore.CapacityGB)) { 0 } else { [math]::Round(($Datastore.FreeSpaceGB / $Datastore.CapacityGB) * 100, 2) }
                                $UsedCapacityGB = ($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)

                                #region Datastore Section
                                Section -Style Heading3 $Datastore.Name {
                                    $DatastoreDetail = [PSCustomObject]@{
                                        $LocalizedData.Datastore = $Datastore.Name
                                        $LocalizedData.ID = $Datastore.Id
                                        $LocalizedData.Datacenter = $Datastore.Datacenter.Name
                                        $LocalizedData.Type = $Datastore.Type
                                        $LocalizedData.Version = if ($Datastore.FileSystemVersion) {
                                            $Datastore.FileSystemVersion
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.State = switch ($Datastore.State) {
                                            'Normal' { $LocalizedData.Normal }
                                            'Maintenance' { $LocalizedData.Maintenance }
                                            'Unmounted' { $LocalizedData.Unmounted }
                                            default { $Datastore.State }
                                        }
                                        $LocalizedData.NumberOfHosts = $Datastore.ExtensionData.Host.Count
                                        $LocalizedData.NumberOfVMs = $Datastore.ExtensionData.VM.Count
                                        $LocalizedData.SIOC = if ($Datastore.StorageIOControlEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.CongestionThreshold = if ($Datastore.CongestionThresholdMillisecond) {
                                            "$($Datastore.CongestionThresholdMillisecond) ms"
                                        } else {
                                            '--'
                                        }
                                        $LocalizedData.TotalCapacity = Convert-DataSize $Datastore.CapacityGB
                                        $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $UsedCapacityGB), $DsUsedPercent
                                        $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $Datastore.FreeSpaceGB), $DSFreePercent
                                        $LocalizedData.PercentUsed = $DsUsedPercent
                                    }
                                    if ($Healthcheck.Datastore.CapacityUtilization) {
                                        $DatastoreDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                        $DatastoreDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and
                                            $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                    }
                                    $MemberProps = @{
                                        'InputObject' = $DatastoreDetail
                                        'MemberType' = 'NoteProperty'
                                    }
                                    if ($TagAssignments | Where-Object { $_.entity -eq $Datastore }) {
                                        Add-Member @MemberProps -Name $LocalizedData.Tags -Value $(($TagAssignments | Where-Object { $_.entity -eq $Datastore }).Tag -join ', ')
                                    }

                                    #region Datastore Advanced Detailed Information
                                    if ($InfoLevel.Datastore -ge 4) {
                                        $DatastoreHosts = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                            $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                        }
                                        Add-Member @MemberProps -Name $LocalizedData.Hosts -Value (($DatastoreHosts | Sort-Object) -join ', ')
                                        $DatastoreVMs = foreach ($DatastoreVM in $Datastore.ExtensionData.VM) {
                                            $VMLookup."$($DatastoreVM.Type)-$($DatastoreVM.Value)"
                                        }
                                        Add-Member @MemberProps -Name $LocalizedData.VirtualMachines -Value (($DatastoreVMs | Sort-Object) -join ', ')
                                    }
                                    #endregion Datastore Advanced Detailed Information
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableDatastoreConfig -f $Datastore.Name)
                                        List = $true
                                        Columns = $LocalizedData.Datastore, $LocalizedData.ID, $LocalizedData.Datacenter, $LocalizedData.Type, $LocalizedData.Version, $LocalizedData.State, $LocalizedData.NumberOfHosts, $LocalizedData.NumberOfVMs, $LocalizedData.SIOC, $LocalizedData.CongestionThreshold, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                        ColumnWidths = 40, 60
                                    }
                                    if ($InfoLevel.Datastore -ge 4) {
                                        $TableParams['Columns'] += $LocalizedData.Hosts, $LocalizedData.VirtualMachines
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $DatastoreDetail | Sort-Object $LocalizedData.Datacenter, $LocalizedData.Datastore | Table @TableParams

                                    # Get VMFS volumes. Ignore local SCSILuns.
                                    if (($Datastore.Type -eq 'VMFS') -and ($Datastore.ExtensionData.Info.Vmfs.Local -eq $false)) {
                                        #region SCSI LUN Information Section
                                        Section -Style Heading4 $LocalizedData.SCSILUNInfo {
                                            $ScsiLuns = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                $DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
                                                $ScsiDeviceDetailProps = @{
                                                    'VMHosts' = $VMHosts
                                                    'VMHostMoRef' = "$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                    'DatastoreDiskName' = $DiskName
                                                }
                                                $ScsiDeviceDetail = Get-ScsiDeviceDetail @ScsiDeviceDetailProps

                                                [PSCustomObject]@{
                                                    $LocalizedData.Host = $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                    $LocalizedData.CanonicalName = $DiskName
                                                    $LocalizedData.Capacity = Convert-DataSize $ScsiDeviceDetail.CapacityGB
                                                    $LocalizedData.Vendor = $ScsiDeviceDetail.Vendor
                                                    $LocalizedData.Model = $ScsiDeviceDetail.Model
                                                    $LocalizedData.IsSSD = $ScsiDeviceDetail.Ssd
                                                    $LocalizedData.MultipathPolicy = $ScsiDeviceDetail.MultipathPolicy
                                                    $LocalizedData.Paths = $ScsiDeviceDetail.Paths
                                                }
                                            }
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableSCSILUN -f $vCenterServerName)
                                                ColumnWidths = 19, 19, 10, 10, 10, 10, 14, 8
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $ScsiLuns | Sort-Object $LocalizedData.Host | Table @TableParams
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
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
