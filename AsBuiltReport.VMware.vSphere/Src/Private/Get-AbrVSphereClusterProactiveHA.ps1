<#
.SYNOPSIS
    Private function to report vSphere Proactive HA cluster configuration.
.DESCRIPTION
    Generates a PScriboDocument section detailing the Proactive HA configuration
    for a given cluster, including Failures and Responses subsection.
    Proactive HA is only available in vSphere 6.5 and above.
.NOTES
    Version:    2.0.0
    Author:     Tim Carman
    Twitter:    @tpcarman
    Github:     tpcarman
.INPUTS
    None. Uses variables from the parent scope:
    $ClusterConfigEx, $Cluster, $vCenter, $InfoLevel, $Report, $Healthcheck, $reportTranslate
.OUTPUTS
    None. Writes PScriboDocument content directly.
#>
function Get-AbrVSphereClusterProactiveHA {
    [CmdletBinding()]
    param ()
    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereClusterProactiveHA
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.Cluster)
    }
    process {
        try {
            # Proactive HA is only available in vSphere 6.5 and above
            if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled -and $vCenter.Version -ge 6.5) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                # TODO: Proactive HA Providers
                Section -Style Heading4 $LocalizedData.SectionHeading {
                    Paragraph ($LocalizedData.ParagraphSummary -f $Cluster)
                    #region Proactive HA Failures and Responses Section
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.FailuresAndResponses {
                        $ProactiveHa = [PSCustomObject]@{
                            ($LocalizedData.ProactiveHA) = if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                                $LocalizedData.Enabled
                            } else {
                                $LocalizedData.Disabled
                            }
                        }
                        if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                            $ProactiveHaModerateRemediation = switch ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation) {
                                'MaintenanceMode' { $LocalizedData.MaintenanceMode }
                                'QuarantineMode' { $LocalizedData.QuarantineMode }
                                default { $ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation }
                            }
                            $ProactiveHaSevereRemediation = switch ($ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                'MaintenanceMode' { $LocalizedData.MaintenanceMode }
                                'QuarantineMode' { $LocalizedData.QuarantineMode }
                                default { $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation }
                            }
                            $MemberProps = @{
                                'InputObject' = $ProactiveHa
                                'MemberType' = 'NoteProperty'
                            }
                            Add-Member @MemberProps -Name $LocalizedData.AutomationLevel -Value $ClusterConfigEx.InfraUpdateHaConfig.Behavior
                            if ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation -eq $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                Add-Member @MemberProps -Name $LocalizedData.Remediation -Value $ProactiveHaModerateRemediation
                            } else {
                                Add-Member @MemberProps -Name $LocalizedData.Remediation -Value $LocalizedData.MixedMode
                                Add-Member @MemberProps -Name $LocalizedData.ModerateRemediation -Value $ProactiveHaModerateRemediation
                                Add-Member @MemberProps -Name $LocalizedData.SevereRemediation -Value $ProactiveHaSevereRemediation
                            }
                        }
                        if ($Healthcheck.Cluster.ProactiveHA) {
                            $ProactiveHa | Where-Object { $_.$($LocalizedData.ProactiveHA) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.ProactiveHA
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableProactiveHA -f $Cluster)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $ProactiveHa | Table @TableParams
                    }
                    #endregion Proactive HA Failures and Responses Section
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }
    end {}
}
