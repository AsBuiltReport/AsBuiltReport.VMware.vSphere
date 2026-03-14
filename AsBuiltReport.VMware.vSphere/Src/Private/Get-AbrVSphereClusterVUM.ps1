<#
.SYNOPSIS
    Private function to report vSphere cluster Update Manager baselines and compliance.
.DESCRIPTION
    Generates a PScriboDocument section detailing the VMware Update Manager baselines
    and compliance status for a given cluster.
.NOTES
    Version:    2.0.0
    Author:     Tim Carman
    Twitter:    @tpcarman
    Github:     tpcarman
.INPUTS
    None. Uses variables from the parent scope:
    $Cluster, $InfoLevel, $Report, $Healthcheck, $UserPrivileges, $VumServer,
    $vCenter, $VUMConnection, $reportTranslate
.OUTPUTS
    None. Writes PScriboDocument content directly.
#>
function Get-AbrVSphereClusterVUM {
    [CmdletBinding()]
    param ()
    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereClusterVUM
    }
    process {
        Try {
            #region Cluster VUM Baselines
            if ($UserPrivileges -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                if ($VUMConnection) {
                    Try {
                        $ClusterPatchBaselines = $Cluster | Get-PatchBaseline -ErrorAction Stop
                    } Catch {
                        Write-PScriboMessage -Message $LocalizedData.VUMBaselineNotAvailable
                    }
                    if ($ClusterPatchBaselines) {
                        Section -Style Heading3 $LocalizedData.UpdateManagerBaselines {
                            $ClusterBaselines = foreach ($ClusterBaseline in $ClusterPatchBaselines) {
                                [PSCustomObject]@{
                                    $LocalizedData.Baseline = $ClusterBaseline.Name
                                    $LocalizedData.Description = $ClusterBaseline.Description
                                    $LocalizedData.Type = $ClusterBaseline.BaselineType
                                    $LocalizedData.TargetType = $ClusterBaseline.TargetType
                                    $LocalizedData.LastUpdate = ($ClusterBaseline.LastUpdateTime).ToLocalTime().ToString()
                                    $LocalizedData.NumPatches = $ClusterBaseline.CurrentPatches.Count
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVUMBaselines -f $Cluster)
                                ColumnWidths = 25, 25, 10, 10, 20, 10
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $ClusterBaselines | Sort-Object $LocalizedData.Baseline | Table @TableParams
                        }
                    }
                    if ($Healthcheck.Cluster.VUMCompliance) {
                        $ClusterComplianceInfo | Where-Object { $_.$($LocalizedData.Status) -eq $LocalizedData.Unknown } | Set-Style -Style Warning
                        $ClusterComplianceInfo | Where-Object { $_.$($LocalizedData.Status) -eq $LocalizedData.NotCompliant -or $_.$($LocalizedData.Status) -eq $LocalizedData.Incompatible } | Set-Style -Style Critical
                    }
                    $TableParams = @{
                        Name = ($LocalizedData.TableVUMCompliance -f $Cluster)
                        ColumnWidths = 25, 50, 25
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $ClusterComplianceInfo | Sort-Object $LocalizedData.Entity, $LocalizedData.BaselineInfo | Table @TableParams
                }
            } else {
                Write-PScriboMessage -Message $LocalizedData.VUMPrivilegeMsgBaselines
            }
            #endregion Cluster VUM Baselines

            #region Cluster VUM Compliance (Advanced Detail Information)
            if ($UserPrivileges -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                if ($InfoLevel.Cluster -ge 4 -and $VumServer.Name) {
                    Try {
                        $ClusterCompliances = $Cluster | Get-Compliance -ErrorAction SilentlyContinue
                    } Catch {
                        Write-PScriboMessage -Message $LocalizedData.VUMComplianceNotAvailable
                    }
                    if ($ClusterCompliances) {
                        Section -Style Heading4 $LocalizedData.UpdateManagerCompliance {
                            $ClusterComplianceInfo = foreach ($ClusterCompliance in $ClusterCompliances) {
                                [PSCustomObject]@{
                                    $LocalizedData.Entity = $ClusterCompliance.Entity.Name
                                    $LocalizedData.BaselineInfo = $ClusterCompliance.Baseline.Name
                                    $LocalizedData.Status = Switch ($ClusterCompliance.Status) {
                                        'NotCompliant' { $LocalizedData.NotCompliant }
                                        default { $ClusterCompliance.Status }
                                    }
                                }
                            }
                            if ($Healthcheck.Cluster.VUMCompliance) {
                                $ClusterComplianceInfo | Where-Object { $_.$($LocalizedData.Status) -eq $LocalizedData.Unknown } | Set-Style -Style Warning
                                $ClusterComplianceInfo | Where-Object { $_.$($LocalizedData.Status) -eq $LocalizedData.NotCompliant -or $_.$($LocalizedData.Status) -eq $LocalizedData.Incompatible } | Set-Style -Style Critical
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVUMCompliance -f $Cluster)
                                ColumnWidths = 25, 50, 25
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $ClusterComplianceInfo | Sort-Object $LocalizedData.Entity, $LocalizedData.BaselineInfo | Table @TableParams
                        }
                    }
                }
            } else {
                Write-PScriboMessage -Message $LocalizedData.VUMPrivilegeMsgCompliance
            }
            #endregion Cluster VUM Compliance (Advanced Detail Information)

        } Catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }
    end {}
}
