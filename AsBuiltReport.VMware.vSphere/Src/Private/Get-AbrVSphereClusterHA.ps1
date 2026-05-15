<#
.SYNOPSIS
    Private function to report vSphere HA cluster configuration.
.DESCRIPTION
    Generates a PScriboDocument section detailing the vSphere HA configuration
    for a given cluster, including Failures and Responses, Admission Control,
    Heartbeat Datastores, and Advanced Options subsections.
.NOTES
    Version:    2.0.0
    Author:     Tim Carman
    Twitter:    @tpcarman
    Github:     tpcarman
.INPUTS
    None. Uses variables from the parent scope:
    $Cluster, $ClusterDasConfig, $InfoLevel, $Report, $Healthcheck, $TextInfo, $reportTranslate
.OUTPUTS
    None. Writes PScriboDocument content directly.
#>
function Get-AbrVSphereClusterHA {
    [CmdletBinding()]
    param ()
    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereClusterHA
    }
    process {
        try {
            if ($Cluster.HAEnabled) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                Section -Style Heading4 $LocalizedData.SectionHeading {
                    Paragraph ($LocalizedData.ParagraphSummary -f $Cluster)
                    #region vSphere HA Cluster Failures and Responses
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.FailuresAndResponses {
                        $HAClusterResponses = [PSCustomObject]@{
                            $LocalizedData.HostMonitoring = $TextInfo.ToTitleCase($ClusterDasConfig.HostMonitoring)
                        }
                        if ($ClusterDasConfig.HostMonitoring -eq 'Enabled') {
                            $MemberProps = @{
                                'InputObject' = $HAClusterResponses
                                'MemberType' = 'NoteProperty'
                            }
                            if ($ClusterDasConfig.DefaultVmSettings.RestartPriority -eq 'Disabled') {
                                Add-Member @MemberProps -Name $LocalizedData.HostFailureResponse -Value $LocalizedData.Disabled
                            } else {
                                Add-Member @MemberProps -Name $LocalizedData.HostFailureResponse -Value $LocalizedData.RestartVMs
                                switch ($Cluster.HAIsolationResponse) {
                                    'DoNothing' {
                                        Add-Member @MemberProps -Name $LocalizedData.HostIsolationResponse -Value $LocalizedData.Disabled
                                    }
                                    'Shutdown' {
                                        Add-Member @MemberProps -Name $LocalizedData.HostIsolationResponse -Value $LocalizedData.ShutdownAndRestart
                                    }
                                    'PowerOff' {
                                        Add-Member @MemberProps -Name $LocalizedData.HostIsolationResponse -Value $LocalizedData.PowerOffAndRestart
                                    }
                                }
                                Add-Member @MemberProps -Name $LocalizedData.VMRestartPriority -Value $Cluster.HARestartPriority
                                switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForPDL) {
                                    'disabled' {
                                        Add-Member @MemberProps -Name $LocalizedData.PDLProtection -Value $LocalizedData.Disabled
                                    }
                                    'warning' {
                                        Add-Member @MemberProps -Name $LocalizedData.PDLProtection -Value $LocalizedData.IssueEvents
                                    }
                                    'restartAggressive' {
                                        Add-Member @MemberProps -Name $LocalizedData.PDLProtection -Value $LocalizedData.PowerOffAndRestart
                                    }
                                }
                                switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForAPD) {
                                    'disabled' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDProtection -Value $LocalizedData.Disabled
                                    }
                                    'warning' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDProtection -Value $LocalizedData.IssueEvents
                                    }
                                    'restartConservative' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDProtection -Value $LocalizedData.PowerOffRestartConservative
                                    }
                                    'restartAggressive' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDProtection -Value $LocalizedData.PowerOffRestartAggressive
                                    }
                                }
                                switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmReactionOnAPDCleared) {
                                    'none' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDRecovery -Value $LocalizedData.Disabled
                                    }
                                    'reset' {
                                        Add-Member @MemberProps -Name $LocalizedData.APDRecovery -Value $LocalizedData.ResetVMs
                                    }
                                }
                            }
                            switch ($ClusterDasConfig.VmMonitoring) {
                                'vmMonitoringDisabled' {
                                    Add-Member @MemberProps -Name $LocalizedData.VMMonitoring -Value $LocalizedData.Disabled
                                }
                                'vmMonitoringOnly' {
                                    Add-Member @MemberProps -Name $LocalizedData.VMMonitoring -Value $LocalizedData.VMMonitoringOnly
                                }
                                'vmAndAppMonitoring' {
                                    Add-Member @MemberProps -Name $LocalizedData.VMMonitoring -Value $LocalizedData.VMAndAppMonitoring
                                }
                            }
                        }
                        if ($Healthcheck.Cluster.HostFailureResponse) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.HostFailureResponse) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.HostFailureResponse
                        }
                        if ($Healthcheck.Cluster.HostMonitoring) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.HostMonitoring) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.HostMonitoring
                        }
                        if ($Healthcheck.Cluster.DatastoreOnPDL) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.PDLProtection) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.PDLProtection
                        }
                        if ($Healthcheck.Cluster.DatastoreOnAPD) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.APDProtection) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.APDProtection
                        }
                        if ($Healthcheck.Cluster.APDTimeout) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.APDRecovery) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.APDRecovery
                        }
                        if ($Healthcheck.Cluster.vmMonitoring) {
                            $HAClusterResponses | Where-Object { $_.$($LocalizedData.VMMonitoring) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.VMMonitoring
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableHAFailures -f $Cluster)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $HAClusterResponses | Table @TableParams
                    }
                    #endregion vSphere HA Cluster Failures and Responses

                    #region vSphere HA Cluster Admission Control
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.AdmissionControl {
                        $HAAdmissionControl = [PSCustomObject]@{
                            $LocalizedData.AdmissionControl = if ($Cluster.HAAdmissionControlEnabled) {
                                $LocalizedData.Enabled
                            } else {
                                $LocalizedData.Disabled
                            }
                        }
                        if ($Cluster.HAAdmissionControlEnabled) {
                            $MemberProps = @{
                                'InputObject' = $HAAdmissionControl
                                'MemberType' = 'NoteProperty'
                            }
                            Add-Member @MemberProps -Name $LocalizedData.FailoverLevel -Value $Cluster.HAFailoverLevel
                            switch ($ClusterDasConfig.AdmissionControlPolicy.GetType().Name) {
                                'ClusterFailoverHostAdmissionControlPolicy' {
                                    Add-Member @MemberProps -Name $LocalizedData.ACPolicy -Value $LocalizedData.DedicatedFailoverHosts
                                }
                                'ClusterFailoverResourcesAdmissionControlPolicy' {
                                    Add-Member @MemberProps -Name $LocalizedData.ACPolicy -Value $LocalizedData.ClusterResourcePercentage
                                }
                                'ClusterFailoverLevelAdmissionControlPolicy' {
                                    Add-Member @MemberProps -Name $LocalizedData.ACPolicy -Value $LocalizedData.SlotPolicy
                                }
                            }
                            if ($ClusterDasConfig.AdmissionControlPolicy.AutoComputePercentages) {
                                Add-Member @MemberProps -Name $LocalizedData.OverrideFailoverCapacity -Value $LocalizedData.No
                            } else {
                                Add-Member @MemberProps -Name $LocalizedData.OverrideFailoverCapacity -Value $LocalizedData.Yes
                                Add-Member @MemberProps -Name $LocalizedData.ACHostPercentage -Value $ClusterDasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent
                                Add-Member @MemberProps -Name $LocalizedData.ACMemPercentage -Value $ClusterDasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent
                            }
                            if ($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy) {
                                Add-Member @MemberProps -Name $LocalizedData.SlotPolicy -Value $LocalizedData.FixedSlotSize
                                Add-Member @MemberProps -Name $LocalizedData.CPUSlotSize -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Cpu) MHz"
                                Add-Member @MemberProps -Name $LocalizedData.MemorySlotSize -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Memory) MB"
                            } else {
                                Add-Member @MemberProps -Name $LocalizedData.SlotPolicy -Value $LocalizedData.CoverAllPoweredOnVMs
                            }
                            if ($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent) {
                                Add-Member @MemberProps -Name $LocalizedData.PerfDegradationTolerate -Value "$($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent)%"
                            }
                        }
                        if ($Healthcheck.Cluster.HAAdmissionControl) {
                            $HAAdmissionControl | Where-Object { $_.$($LocalizedData.AdmissionControl) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.AdmissionControl
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableHAAdmissionControl -f $Cluster)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $HAAdmissionControl | Table @TableParams
                    }
                    #endregion vSphere HA Cluster Admission Control

                    #region vSphere HA Cluster Heartbeat Datastores
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.HeartbeatDatastores {
                        $HeartbeatDatastores = [PSCustomObject]@{
                            $LocalizedData.HeartbeatSelectionPolicy = switch ($ClusterDasConfig.HBDatastoreCandidatePolicy) {
                                'allFeasibleDsWithUserPreference' { $LocalizedData.HBPolicyAllFeasibleDsWithUserPreference }
                                'allFeasibleDs' { $LocalizedData.HBPolicyAllFeasibleDs }
                                'userSelectedDs' { $LocalizedData.HBPolicyUserSelectedDs }
                                default { $ClusterDasConfig.HBDatastoreCandidatePolicy }
                            }
                            $LocalizedData.HeartbeatDatastores = try {
                                (((Get-View -Id $ClusterDasConfig.HeartbeatDatastore -Property Name).Name | Sort-Object) -join ', ')
                            } catch {
                                $LocalizedData.NoneSpecified
                            }
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableHAHeartbeat -f $Cluster)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $HeartbeatDatastores | Table @TableParams
                    }
                    #endregion vSphere HA Cluster Heartbeat Datastores

                    #region vSphere HA Cluster Advanced Options
                    $HAAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterHA' }
                    if ($HAAdvancedSettings) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.HAAdvancedOptions {
                            $HAAdvancedOptions = @()
                            foreach ($HAAdvancedSetting in $HAAdvancedSettings) {
                                $HAAdvancedOption = [PSCustomObject]@{
                                    $LocalizedData.Key = $HAAdvancedSetting.Name
                                    $LocalizedData.Value = $HAAdvancedSetting.Value
                                }
                                $HAAdvancedOptions += $HAAdvancedOption
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableHAAdvanced -f $Cluster)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $HAAdvancedOptions | Sort-Object $LocalizedData.Key | Table @TableParams
                        }
                    }
                    #endregion vSphere HA Cluster Advanced Options
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }
    end {}
}
