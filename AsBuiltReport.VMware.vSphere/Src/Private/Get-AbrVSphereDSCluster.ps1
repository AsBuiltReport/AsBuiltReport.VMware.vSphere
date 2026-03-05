function Get-AbrVSphereDSCluster {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Datastore Cluster information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereDSCluster
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.DSCluster)
    }

    process {
        try {
            if ($InfoLevel.DSCluster -ge 1) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                $DSClusters = Get-DatastoreCluster -Server $vCenter
                if ($DSClusters) {
                    #region Datastore Clusters Section
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Datastore Cluster Advanced Summary
                        if ($InfoLevel.DSCluster -le 2) {
                            BlankLine
                            $DSClusterInfo = foreach ($DSCluster in $DSClusters) {
                                [PSCustomObject]@{
                                    $LocalizedData.DSCluster = $DSCluster.Name
                                    $LocalizedData.SDRSAutomationLevel = switch ($DSCluster.SdrsAutomationLevel) {
                                        'FullyAutomated' { $LocalizedData.FullyAutomated }
                                        'Manual' { $LocalizedData.Manual }
                                        default { $DSCluster.SdrsAutomationLevel }
                                    }
                                    $LocalizedData.SpaceThreshold = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                    $LocalizedData.IOLoadBalancing = if ($DSCluster.IOLoadBalanceEnabled) {
                                        $LocalizedData.Enabled
                                    } else {
                                        $LocalizedData.Disabled
                                    }
                                    $LocalizedData.IOLatencyThreshold = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                }
                            }
                            if ($Healthcheck.DSCluster.SDRSAutomationLevelFullyAuto) {
                                $DSClusterInfo | Where-Object { $_.$($LocalizedData.SDRSAutomationLevel) -ne $LocalizedData.FullyAutomated } | Set-Style -Style Warning -Property $LocalizedData.SDRSAutomationLevel
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDSClusterConfig -f $DSCluster.Name)
                                ColumnWidths = 20, 20, 20, 20, 20
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DSClusterInfo | Sort-Object $LocalizedData.DSCluster | Table @TableParams
                        }
                        #endregion Datastore Cluster Advanced Summary

                        #region Datastore Cluster Detailed Information
                        if ($InfoLevel.DSCluster -ge 3) {
                            foreach ($DSCluster in $DSClusters) {
                                # TODO: Space Load Balance Config, IO Load Balance Config, Rules
                                # TODO: Test Tags

                                $DSCUsedPercent = if (0 -in @($DSCluster.FreeSpaceGB, $DSCluster.CapacityGB)) { 0 } else { [math]::Round((100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2) }
                                $DSCFreePercent = if (0 -in @($DSCluster.FreeSpaceGB, $DSCluster.CapacityGB)) { 0 } else { [math]::Round(($DSCluster.FreeSpaceGB / $DSCluster.CapacityGB) * 100, 2) }
                                $DSCUsedCapacityGB = ($DSCluster.CapacityGB - $DSCluster.FreeSpaceGB)

                                Section -Style Heading3 $DSCluster.Name {
                                    Paragraph ($LocalizedData.ParagraphDSClusterDetail -f $DSCluster)
                                    BlankLine

                                    $DSClusterDetail = [PSCustomObject]@{
                                        $LocalizedData.DSCluster = $DSCluster.Name
                                        $LocalizedData.ID = $DSCluster.Id
                                        $LocalizedData.SDRSAutomationLevel = switch ($DSCluster.SdrsAutomationLevel) {
                                            'FullyAutomated' { $LocalizedData.FullyAutomated }
                                            'Manual' { $LocalizedData.Manual }
                                            default { $DSCluster.SdrsAutomationLevel }
                                        }
                                        $LocalizedData.SpaceThreshold = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                        $LocalizedData.IOLoadBalancing = if ($DSCluster.IOLoadBalanceEnabled) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.IOLatencyThreshold = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                        $LocalizedData.TotalCapacity = Convert-DataSize $DSCluster.CapacityGB
                                        $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $DSCUsedCapacityGB), $DSCUsedPercent
                                        $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $DSCluster.FreeSpaceGB), $DSCFreePercent
                                        $LocalizedData.PercentUsed = $DSCUsedPercent
                                    }
                                    <#
                                    $MemberProps = @{
                                        'InputObject' = $DSClusterDetail
                                        'MemberType' = 'NoteProperty'
                                    }

                                    if ($TagAssignments | Where-Object {$_.entity -eq $DSCluster}) {
                                        Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $DSCluster}).Tag -join ',')
                                    }
                                    #>
                                    if ($Healthcheck.DSCluster.CapacityUtilization) {
                                        $DSClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                        $DSClusterDetail | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                    }
                                    if ($Healthcheck.DSCluster.SDRSAutomationLevel) {
                                        $DSClusterDetail | Where-Object { $_.$($LocalizedData.SDRSAutomationLevel) -ne $LocalizedData.FullyAutomated } | Set-Style -Style Warning -Property $LocalizedData.SDRSAutomationLevel
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableDSClusterConfig -f $DSCluster.Name)
                                        List = $true
                                        Columns = $LocalizedData.DSCluster, $LocalizedData.ID, $LocalizedData.SDRSAutomationLevel, $LocalizedData.SpaceThreshold, $LocalizedData.IOLoadBalancing, $LocalizedData.IOLatencyThreshold, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $DSClusterDetail | Table @TableParams

                                    #region SDRS VM Overrides
                                    $StoragePodProps = @{
                                        'ViewType' = 'StoragePod'
                                        'Filter' = @{'Name' = $DSCluster.Name }
                                    }
                                    $StoragePod = Get-View @StoragePodProps
                                    if ($StoragePod) {
                                        $PodConfig = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.PodConfig
                                        # Set default automation value variables
                                        switch ($PodConfig.DefaultVmBehavior) {
                                            "automated" { $DefaultVmBehavior = ($LocalizedData.DefaultBehavior -f $LocalizedData.FullyAutomated) }
                                            "manual" { $DefaultVmBehavior = ($LocalizedData.DefaultBehavior -f $LocalizedData.NoAutomation) }
                                        }
                                        if ($PodConfig.DefaultIntraVmAffinity) {
                                            $DefaultIntraVmAffinity = ($LocalizedData.DefaultBehavior -f $LocalizedData.Yes)
                                        } else {
                                            $DefaultIntraVmAffinity = ($LocalizedData.DefaultBehavior -f $LocalizedData.No)
                                        }
                                        $VMOverrides = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.VmConfig | Where-Object {
                                            -not (
                                                ($null -eq $_.Enabled) -and
                                                ($null -eq $_.IntraVmAffinity)
                                            )
                                        }
                                    }

                                    if ($VMOverrides) {
                                        $VMOverrideDetails = foreach ($Override in $VMOverrides) {
                                            [PSCustomObject]@{
                                                $LocalizedData.VirtualMachine = $VMLookup."$($Override.Vm.Type)-$($Override.Vm.Value)"
                                                $LocalizedData.SDRSAutomationLevel = switch ($Override.Enabled) {
                                                    $true { $LocalizedData.FullyAutomated }
                                                    $false { $LocalizedData.Disabled }
                                                    $null { $DefaultVmBehavior }
                                                }
                                                $LocalizedData.KeepVMDKsTogether = switch ($Override.IntraVmAffinity) {
                                                    $true { $LocalizedData.Yes }
                                                    $false { $LocalizedData.No }
                                                    $null { $DefaultIntraVmAffinity }
                                                }
                                            }
                                        }
                                        Section -Style Heading4 $LocalizedData.SDRSVMOverrides {
                                            $TableParams = @{
                                                Name = ($LocalizedData.TableSDRSVMOverrides -f $DSCluster.Name)
                                                ColumnWidths = 50, 30, 20
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VMOverrideDetails | Sort-Object $LocalizedData.VirtualMachine | Table @TableParams
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
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
