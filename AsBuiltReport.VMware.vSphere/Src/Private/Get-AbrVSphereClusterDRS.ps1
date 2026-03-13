<#
.SYNOPSIS
    Private function to report vSphere DRS cluster configuration.
.DESCRIPTION
    Generates a PScriboDocument section detailing the vSphere DRS configuration
    for a given cluster, including DRS settings, Additional Options, Power Management,
    Advanced Options, DRS Cluster Groups, DRS VM/Host Rules, DRS Rules, VM Overrides,
    and Permissions subsections.
.NOTES
    Version:    2.0.0
    Author:     Tim Carman
    Twitter:    @tpcarman
    Github:     tpcarman
.INPUTS
    None. Uses variables from the parent scope:
    $Cluster, $ClusterDrsConfig, $ClusterConfigEx, $VMLookup, $InfoLevel, $Report,
    $Healthcheck, $vCenter, $reportTranslate
.OUTPUTS
    None. Writes PScriboDocument content directly.
#>
function Get-AbrVSphereClusterDRS {
    [CmdletBinding()]
    param ()
    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereClusterDRS
    }
    process {
        Try {
            if ($Cluster.DrsEnabled) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                Section -Style Heading4 $LocalizedData.SectionHeading {
                    Paragraph ($LocalizedData.ParagraphSummary -f $Cluster)
                    BlankLine

                    #region vSphere DRS Cluster Specifications
                    $DrsCluster = [PSCustomObject]@{
                        $LocalizedData.DRS = if ($Cluster.DrsEnabled) {
                            $LocalizedData.Enabled
                        } else {
                            $LocalizedData.Disabled
                        }
                    }
                    $MemberProps = @{
                        'InputObject' = $DrsCluster
                        'MemberType' = 'NoteProperty'
                    }
                    Switch ($Cluster.DrsAutomationLevel) {
                        'Manual' {
                            Add-Member @MemberProps -Name $LocalizedData.AutomationLevel -Value $LocalizedData.Manual
                        }
                        'PartiallyAutomated' {
                            Add-Member @MemberProps -Name $LocalizedData.AutomationLevel -Value $LocalizedData.PartiallyAutomated
                        }
                        'FullyAutomated' {
                            Add-Member @MemberProps -Name $LocalizedData.AutomationLevel -Value $LocalizedData.FullyAutomated
                        }
                    }
                    Add-Member @MemberProps -Name $LocalizedData.MigrationThreshold -Value $ClusterDrsConfig.VmotionRate
                    if ($ClusterConfigEx.ProactiveDrsConfig.Enabled) {
                        Add-Member @MemberProps -Name $LocalizedData.PredictiveDRS -Value $LocalizedData.Enabled
                    } else {
                        Add-Member @MemberProps -Name $LocalizedData.PredictiveDRS -Value $LocalizedData.Disabled
                    }
                    if ($ClusterDrsConfig.EnableVmBehaviorOverrides) {
                        Add-Member @MemberProps -Name $LocalizedData.VirtualMachineAutomation -Value $LocalizedData.Enabled
                    } else {
                        Add-Member @MemberProps -Name $LocalizedData.VirtualMachineAutomation -Value $LocalizedData.Disabled
                    }
                    if ($Healthcheck.Cluster.DrsEnabled) {
                        $DrsCluster | Where-Object { $_.$($LocalizedData.DRS) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.DRS
                    }
                    if ($Healthcheck.Cluster.DrsAutomationLevelFullyAuto) {
                        $DrsCluster | Where-Object { $_.$($LocalizedData.AutomationLevel) -ne $LocalizedData.FullyAutomated } | Set-Style -Style Warning -Property $LocalizedData.AutomationLevel
                    }
                    $TableParams = @{
                        Name = ($LocalizedData.TableDRSConfig -f $Cluster)
                        List = $true
                        ColumnWidths = 40, 60
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $DrsCluster | Table @TableParams
                    #endregion vSphere DRS Cluster Specifications

                    #region DRS Cluster Additional Options
                    $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                    if ($DrsAdvancedSettings) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.AdditionalOptions {
                            $DrsAdditionalOptions = [PSCustomObject] @{
                                $LocalizedData.VMDistribution = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'TryBalanceVmsPerHost' }).Value) {
                                    '1' { $LocalizedData.Enabled }
                                    $null { $LocalizedData.Disabled }
                                }
                                $LocalizedData.MemoryMetricForLB = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'PercentIdleMBInMemDemand' }).Value) {
                                    '100' { $LocalizedData.Enabled }
                                    $null { $LocalizedData.Disabled }
                                }
                                $LocalizedData.CPUOverCommitment = if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                            }
                            $MemberProps = @{
                                'InputObject' = $DrsAdditionalOptions
                                'MemberType' = 'NoteProperty'
                            }
                            if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                Add-Member @MemberProps -Name $LocalizedData.OverCommitmentRatio -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerCore'}).Value):1 (vCPU:pCPU)"
                            }
                            if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerClusterPct' }).Value) {
                                Add-Member @MemberProps -Name $LocalizedData.OverCommitmentRatioCluster -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerClusterPct'}).Value) %"
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDRSAdditional -f $Cluster)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DrsAdditionalOptions | Table @TableParams
                        }
                    }
                    #endregion DRS Cluster Additional Options

                    #region vSphere DPM Configuration
                    if ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.PowerManagement {
                            $DpmConfig = [PSCustomObject]@{
                                $LocalizedData.DPM = if ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                                    $LocalizedData.Enabled
                                } else {
                                    $LocalizedData.Disabled
                                }
                            }
                            $MemberProps = @{
                                'InputObject' = $DpmConfig
                                'MemberType' = 'NoteProperty'
                            }
                            Switch ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior) {
                                'manual' {
                                    Add-Member @MemberProps -Name $LocalizedData.DPMAutomationLevel -Value $LocalizedData.Manual
                                }
                                'automated' {
                                    Add-Member @MemberProps -Name $LocalizedData.DPMAutomationLevel -Value $LocalizedData.Automated
                                }
                            }
                            if ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior -eq 'automated') {
                                Add-Member @MemberProps -Name $LocalizedData.DPMThreshold -Value $ClusterConfigEx.DpmConfigInfo.HostPowerActionRate
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDPM -f $Cluster)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DpmConfig | Table @TableParams
                        }
                    }
                    #endregion vSphere DPM Configuration

                    #region vSphere DRS Cluster Advanced Options
                    $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                    if ($DrsAdvancedSettings) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.AdvancedOptions {
                            $DrsAdvancedOptions = @()
                            foreach ($DrsAdvancedSetting in $DrsAdvancedSettings) {
                                $DrsAdvancedOption = [PSCustomObject]@{
                                    $LocalizedData.Key = $DrsAdvancedSetting.Name
                                    $LocalizedData.Value = $DrsAdvancedSetting.Value
                                }
                                $DrsAdvancedOptions += $DrsAdvancedOption
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDRSAdvanced -f $Cluster)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DrsAdvancedOptions | Sort-Object $LocalizedData.Key | Table @TableParams
                        }
                    }
                    #endregion vSphere DRS Cluster Advanced Options

                    #region vSphere DRS Cluster Group
                    $DrsClusterGroups = $Cluster | Get-DrsClusterGroup
                    if ($DrsClusterGroups) {
                        #region vSphere DRS Cluster Group Section
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.DRSClusterGroups {
                            $DrsGroups = foreach ($DrsClusterGroup in $DrsClusterGroups) {
                                [PSCustomObject]@{
                                    $LocalizedData.GroupName = $DrsClusterGroup.Name
                                    $LocalizedData.GroupType = Switch ($DrsClusterGroup.GroupType) {
                                        'VMGroup' { $LocalizedData.VMGroupType }
                                        'VMHostGroup' { $LocalizedData.VMHostGroupType }
                                        default { $DrsClusterGroup.GroupType }
                                    }
                                    $LocalizedData.GroupMembers = if (($DrsClusterGroup.Member).Count -gt 0) {
                                        ($DrsClusterGroup.Member | Sort-Object) -join ', '
                                    } else {
                                        $LocalizedData.None
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDRSGroups -f $Cluster)
                                ColumnWidths = 42, 16, 42
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $DrsGroups | Sort-Object $LocalizedData.GroupName, $LocalizedData.GroupType | Table @TableParams
                        }
                        #endregion vSphere DRS Cluster Group Section

                        #region vSphere DRS Cluster VM/Host Rules
                        $DrsVMHostRules = $Cluster | Get-DrsVMHostRule
                        if ($DrsVMHostRules) {
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.DRSVMHostRules {
                                $DrsVMHostRuleDetail = foreach ($DrsVMHostRule in $DrsVMHostRules) {
                                    [PSCustomObject]@{
                                        $LocalizedData.RuleName = $DrsVMHostRule.Name
                                        $LocalizedData.RuleType = Switch ($DrsVMHostRule.Type) {
                                            'MustRunOn' { $LocalizedData.MustRunOn }
                                            'ShouldRunOn' { $LocalizedData.ShouldRunOn }
                                            'MustNotRunOn' { $LocalizedData.MustNotRunOn }
                                            'ShouldNotRunOn' { $LocalizedData.ShouldNotRunOn }
                                            default { $DrsVMHostRule.Type }
                                        }
                                        $LocalizedData.RuleEnabled = if ($DrsVMHostRule.Enabled) {
                                            $LocalizedData.Yes
                                        } else {
                                            $LocalizedData.No
                                        }
                                        $LocalizedData.VMGroup = $DrsVMHostRule.VMGroup.Name
                                        $LocalizedData.HostGroup = $DrsVMHostRule.VMHostGroup.Name
                                    }
                                }
                                if ($Healthcheck.Cluster.DrsVMHostRules) {
                                    $DrsVMHostRuleDetail | Where-Object { $_.$($LocalizedData.RuleEnabled) -eq $LocalizedData.No } | Set-Style -Style Warning -Property $LocalizedData.RuleEnabled
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableDRSVMHostRules -f $Cluster)
                                    ColumnWidths = 22, 22, 12, 22, 22
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $DrsVMHostRuleDetail | Sort-Object $LocalizedData.RuleName | Table @TableParams
                            }
                        }
                        #endregion vSphere DRS Cluster VM/Host Rules

                        #region vSphere DRS Cluster Rules
                        $DrsRules = $Cluster | Get-DrsRule
                        if ($DrsRules) {
                            #region vSphere DRS Cluster Rules Section
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.DRSRules {
                                $DrsRuleDetail = foreach ($DrsRule in $DrsRules) {
                                    [PSCustomObject]@{
                                        $LocalizedData.RuleName = $DrsRule.Name
                                        $LocalizedData.RuleType = Switch ($DrsRule.Type) {
                                            'VMAffinity' { $LocalizedData.VMAffinity }
                                            'VMAntiAffinity' { $LocalizedData.VMAntiAffinity }
                                        }
                                        $LocalizedData.RuleEnabled = if ($DrsRule.Enabled) {
                                            $LocalizedData.Yes
                                        } else {
                                            $LocalizedData.No
                                        }
                                        $LocalizedData.Mandatory = $DrsRule.Mandatory
                                        $LocalizedData.RuleVMs = ($DrsRule.VMIds | ForEach-Object { (Get-View -Id $_).name }) -join ', '
                                    }
                                    if ($Healthcheck.Cluster.DrsRules) {
                                        $DrsRuleDetail | Where-Object { $_.$($LocalizedData.RuleEnabled) -eq $LocalizedData.No } | Set-Style -Style Warning -Property $LocalizedData.RuleEnabled
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableDRSRules -f $Cluster)
                                    ColumnWidths = 26, 25, 12, 12, 25
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $DrsRuleDetail | Sort-Object $LocalizedData.RuleType | Table @TableParams
                            }
                            #endregion vSphere DRS Cluster Rules Section
                        }
                        #endregion vSphere DRS Cluster Rules
                    }
                    #endregion vSphere DRS Cluster Group

                    #region Cluster VM Overrides
                    $DrsVmOverrides = $Cluster.ExtensionData.Configuration.DrsVmConfig
                    $DasVmOverrides = $Cluster.ExtensionData.Configuration.DasVmConfig
                    if ($DrsVmOverrides -or $DasVmOverrides) {
                        #region VM Overrides Section
                        Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.VMOverrides {
                            #region vSphere DRS VM Overrides
                            if ($DrsVmOverrides) {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.DRS {
                                    $DrsVmOverrideDetails = foreach ($DrsVmOverride in $DrsVmOverrides) {
                                        [PSCustomObject]@{
                                            $LocalizedData.VirtualMachine = $VMLookup."$($DrsVmOverride.Key.Type)-$($DrsVmOverride.Key.Value)"
                                            $LocalizedData.DRSAutomationLevel = if ($DrsVmOverride.Enabled -eq $false) {
                                                $LocalizedData.Disabled
                                            } else {
                                                Switch ($DrsVmOverride.Behavior) {
                                                    'manual' { $LocalizedData.Manual }
                                                    'partiallyAutomated' { $LocalizedData.PartiallyAutomated }
                                                    'fullyAutomated' { $LocalizedData.FullyAutomated }
                                                    default { $DrsVmOverride.Behavior }
                                                }
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableDRSVMOverrides -f $Cluster)
                                        ColumnWidths = 50, 50
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $DrsVmOverrideDetails | Sort-Object $LocalizedData.VirtualMachine | Table @TableParams
                                }
                            }
                            #endregion vSphere DRS VM Overrides

                            #region vSphere HA VM Overrides
                            if ($DasVmOverrides) {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.SectionVSphereHA {
                                    $DasVmOverrideDetails = foreach ($DasVmOverride in $DasVmOverrides) {
                                        [PSCustomObject]@{
                                            $LocalizedData.VirtualMachine = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                            $LocalizedData.HARestartPriority = Switch ($DasVmOverride.DasSettings.RestartPriority) {
                                                $null { '--' }
                                                'lowest' { $LocalizedData.Lowest }
                                                'low' { $LocalizedData.Low }
                                                'medium' { $LocalizedData.Medium }
                                                'high' { $LocalizedData.High }
                                                'highest' { $LocalizedData.Highest }
                                                'disabled' { $LocalizedData.Disabled }
                                                'clusterRestartPriority' { $LocalizedData.ClusterDefault }
                                            }
                                            $LocalizedData.VMDependencyTimeout = Switch ($DasVmOverride.DasSettings.RestartPriorityTimeout) {
                                                $null { '--' }
                                                '-1' { $LocalizedData.Disabled }
                                                default { $LocalizedData.Seconds -f $DasVmOverride.DasSettings.RestartPriorityTimeout }
                                            }
                                            $LocalizedData.HAIsolationResponse = Switch ($DasVmOverride.DasSettings.IsolationResponse) {
                                                $null { '--' }
                                                'none' { $LocalizedData.Disabled }
                                                'powerOff' { $LocalizedData.PowerOffAndRestart }
                                                'shutdown' { $LocalizedData.ShutdownAndRestartVMs }
                                                'clusterIsolationResponse' { $LocalizedData.ClusterDefault }
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableHAVMOverrides -f $Cluster)
                                        ColumnWidths = 25, 25, 25, 25
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $DasVmOverrideDetails | Sort-Object $LocalizedData.VirtualMachine | Table @TableParams

                                    #region PDL/APD Protection Settings Section
                                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.SectionPDLAPD {
                                        $DasVmOverridePdlApd = foreach ($DasVmOverride in $DasVmOverrides) {
                                            $DasVmComponentProtection = $DasVmOverride.DasSettings.VmComponentProtectionSettings
                                            [PSCustomObject]@{
                                                $LocalizedData.VirtualMachine = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                $LocalizedData.PDLFailureResponse = Switch ($DasVmComponentProtection.VmStorageProtectionForPDL) {
                                                    $null { '--' }
                                                    'clusterDefault' { $LocalizedData.ClusterDefault }
                                                    'warning' { $LocalizedData.IssueEvents }
                                                    'restartAggressive' { $LocalizedData.PowerOffAndRestart }
                                                    'disabled' { $LocalizedData.Disabled }
                                                }
                                                $LocalizedData.APDFailureResponse = Switch ($DasVmComponentProtection.VmStorageProtectionForAPD) {
                                                    $null { '--' }
                                                    'clusterDefault' { $LocalizedData.ClusterDefault }
                                                    'warning' { $LocalizedData.IssueEvents }
                                                    'restartConservative' { $LocalizedData.PowerOffRestartConservative }
                                                    'restartAggressive' { $LocalizedData.PowerOffRestartAggressive }
                                                    'disabled' { $LocalizedData.Disabled }
                                                }
                                                $LocalizedData.VMFailoverDelay = Switch ($DasVmComponentProtection.VmTerminateDelayForAPDSec) {
                                                    $null { '--' }
                                                    '-1' { $LocalizedData.Disabled }
                                                    default { $LocalizedData.Minutes -f (($DasVmComponentProtection.VmTerminateDelayForAPDSec)/60) }
                                                }
                                                $LocalizedData.ResponseRecovery = Switch ($DasVmComponentProtection.VmReactionOnAPDCleared) {
                                                    $null { '--' }
                                                    'reset' { $LocalizedData.ResetVMs }
                                                    'disabled' { $LocalizedData.Disabled }
                                                    'useClusterDefault' { $LocalizedData.ClusterDefault }
                                                }
                                            }
                                        }
                                        $TableParams = @{
                                            Name = ($LocalizedData.TableHAPDLAPD -f $Cluster)
                                            ColumnWidths = 20, 20, 20, 20, 20
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $DasVmOverridePdlApd | Sort-Object $LocalizedData.VirtualMachine | Table @TableParams
                                    }
                                    #endregion PDL/APD Protection Settings Section

                                    #region VM Monitoring Section
                                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VMMonitoring {
                                        $DasVmOverrideVmMonitoring = foreach ($DasVmOverride in $DasVmOverrides) {
                                            $DasVmMonitoring = $DasVmOverride.DasSettings.VmToolsMonitoringSettings
                                            [PSCustomObject]@{
                                                $LocalizedData.VirtualMachine = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                $LocalizedData.VMMonitoring = Switch ($DasVmMonitoring.VmMonitoring) {
                                                    $null { '--' }
                                                    'vmMonitoringDisabled' { $LocalizedData.Disabled }
                                                    'vmMonitoringOnly' { $LocalizedData.VMMonitoringOnly }
                                                    'vmAndAppMonitoring' { $LocalizedData.VMAndAppMonitoring }
                                                }
                                                $LocalizedData.VMMonitoringFailureInterval = Switch ($DasVmMonitoring.FailureInterval) {
                                                    $null { '--' }
                                                    default {
                                                        if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                            '--'
                                                        } else {
                                                            $LocalizedData.Seconds -f $DasVmMonitoring.FailureInterval
                                                        }
                                                    }
                                                }
                                                $LocalizedData.VMMonitoringMinUpTime = Switch ($DasVmMonitoring.MinUptime) {
                                                    $null { '--' }
                                                    default {
                                                        if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                            '--'
                                                        } else {
                                                            $LocalizedData.Seconds -f $DasVmMonitoring.MinUptime
                                                        }
                                                    }
                                                }
                                                $LocalizedData.VMMonitoringMaxFailures = Switch ($DasVmMonitoring.MaxFailures) {
                                                    $null { '--' }
                                                    default {
                                                        if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                            '--'
                                                        } else {
                                                            $DasVmMonitoring.MaxFailures
                                                        }
                                                    }
                                                }
                                                $LocalizedData.VMMonitoringMaxFailureWindow = Switch ($DasVmMonitoring.MaxFailureWindow) {
                                                    $null { '--' }
                                                    '-1' { $LocalizedData.NoWindow }
                                                    default {
                                                        if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                            '--'
                                                        } else {
                                                            $LocalizedData.WithinHours -f (($DasVmMonitoring.MaxFailureWindow)/3600)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        $TableParams = @{
                                            Name = ($LocalizedData.TableHAVMMonitoring -f $Cluster)
                                            ColumnWidths = 40, 12, 12, 12, 12, 12
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $DasVmOverrideVmMonitoring | Sort-Object $LocalizedData.VirtualMachine | Table @TableParams
                                    }
                                    #endregion VM Monitoring Section
                                }
                            }
                            #endregion vSphere HA VM Overrides
                        }
                        #endregion VM Overrides Section
                    }
                    #endregion Cluster VM Overrides

                    #region Cluster Permissions
                    Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.Permissions {
                        Paragraph ($LocalizedData.ParagraphPermissions -f $Cluster)
                        BlankLine
                        $VIPermissions = $Cluster | Get-VIPermission
                        $ClusterVIPermissions = foreach ($VIPermission in $VIPermissions) {
                            [PSCustomObject]@{
                                $LocalizedData.UserGroup = $VIPermission.Principal
                                $LocalizedData.IsGroup = if ($VIPermission.IsGroup) {
                                    $LocalizedData.Yes
                                } else {
                                    $LocalizedData.No
                                }
                                $LocalizedData.Role = $VIPermission.Role
                                $LocalizedData.DefinedIn = $VIPermission.Entity.Name
                                $LocalizedData.Propagate = if ($VIPermission.Propagate) {
                                    $LocalizedData.Yes
                                } else {
                                    $LocalizedData.No
                                }
                            }
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TablePermissions -f $Cluster)
                            ColumnWidths = 42, 12, 20, 14, 12
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $ClusterVIPermissions | Sort-Object $LocalizedData.UserGroup | Table @TableParams
                    }
                    #endregion Cluster Permissions
                }
            }
        } Catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }
    end {}
}
