function Get-AbrVSphereClusterLCM {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Lifecycle Manager information for a cluster.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereClusterLCM
    }

    process {
        try {
            # $vcApiUri is only set for vSphere 7.0+; silently skip on older versions
            if (-not $vcApiUri) { return }

            $clusterId = $Cluster.Id -replace 'ClusterComputeResource-', ''
            $softwareUri = "$vcApiUri/esx/settings/clusters/$clusterId/software"

            try {
                $lcmSoftware = Invoke-RestMethod -Uri $softwareUri -Method Get `
                    -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
            } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
                # 404 = cluster is in VUM baseline mode — silently skip
                if ($_.Exception.Response.StatusCode -eq 404) { return }
                Write-PScriboMessage -IsWarning ($LocalizedData.LcmError -f $Cluster, $_.Exception.Message)
                return
            } catch {
                Write-PScriboMessage -IsWarning ($LocalizedData.LcmError -f $Cluster, $_.Exception.Message)
                return
            }

            #region vLCM Image Composition
            BlankLine
            Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.ImageComposition {
                $ImageInfo = [PSCustomObject]@{
                    $LocalizedData.BaseImage   = $lcmSoftware.base_image.version
                    $LocalizedData.VendorAddOn = if ($lcmSoftware.add_on) {
                        "$($lcmSoftware.add_on.name) $($lcmSoftware.add_on.version)"
                    } else {
                        $LocalizedData.None
                    }
                }
                $TableParams = @{
                    Name         = ($LocalizedData.TableImageComposition -f $Cluster)
                    List         = $true
                    ColumnWidths = 40, 60
                }
                if ($Report.ShowTableCaptions) {
                    $TableParams['Caption'] = "- $($TableParams.Name)"
                }
                $ImageInfo | Table @TableParams

                # Components sub-table — InfoLevel >= 4
                if ($InfoLevel.Cluster -ge 4 -and $lcmSoftware.components) {
                    BlankLine
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.Components {
                        $ComponentInfo = foreach ($name in ($lcmSoftware.components.PSObject.Properties.Name | Sort-Object)) {
                            [PSCustomObject]@{
                                $LocalizedData.ComponentName    = $name
                                $LocalizedData.ComponentVersion = $lcmSoftware.components.$name.version
                            }
                        }
                        $TableParams = @{
                            Name         = ($LocalizedData.TableComponents -f $Cluster)
                            ColumnWidths = 60, 40
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $ComponentInfo | Table @TableParams
                    }
                }
            }
            #endregion vLCM Image Composition

            #region Hardware Support Manager
            if ($lcmSoftware.hardware_support -and $lcmSoftware.hardware_support.managers) {
                BlankLine
                Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.HardwareSupportManager {
                    $HsmInfo = foreach ($mgrId in $lcmSoftware.hardware_support.managers.PSObject.Properties.Name) {
                        $mgr = $lcmSoftware.hardware_support.managers.$mgrId
                        $packages = if ($mgr.packages) {
                            ($mgr.packages.PSObject.Properties | ForEach-Object {
                                "$($_.Name) $($_.Value.version)"
                            }) -join '; '
                        } else {
                            $LocalizedData.None
                        }
                        [PSCustomObject]@{
                            $LocalizedData.HsmName     = $mgr.name
                            $LocalizedData.HsmVersion  = $mgr.version
                            $LocalizedData.HsmPackages = $packages
                        }
                    }
                    $TableParams = @{
                        Name         = ($LocalizedData.TableHardwareSupportManager -f $Cluster)
                        ColumnWidths = 35, 20, 45
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $HsmInfo | Table @TableParams
                }
            }
            #endregion Hardware Support Manager

            #region Image Compliance
            $lcmCompliance = $null
            try {
                $complianceUri = "$vcApiUri/esx/settings/clusters/$clusterId/software/compliance"
                $lcmCompliance = Invoke-RestMethod -Uri $complianceUri -Method Get `
                    -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
            } catch {
                Write-PScriboMessage -IsWarning ($LocalizedData.ComplianceError -f $Cluster, $_.Exception.Message)
            }
            if ($lcmCompliance) {
                BlankLine
                Section -Style NOTOCHeading4 -ExcludeFromTOC $LocalizedData.ImageCompliance {
                    $clusterStatus = $TextInfo.ToTitleCase(
                        $lcmCompliance.status.ToString().ToLower().Replace('_', ' ')
                    )
                    $ClusterComplianceInfo = [PSCustomObject]@{
                        $LocalizedData.Cluster          = $Cluster.Name
                        $LocalizedData.ComplianceStatus = $clusterStatus
                    }
                    if ($Healthcheck.Cluster.LCMCompliance) {
                        $ClusterComplianceInfo | Where-Object {
                            $_.$($LocalizedData.ComplianceStatus) -ne 'Compliant'
                        } | Set-Style -Style Warning -Property $LocalizedData.ComplianceStatus
                    }
                    $TableParams = @{
                        Name         = ($LocalizedData.TableImageCompliance -f $Cluster)
                        List         = $true
                        ColumnWidths = 40, 60
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $ClusterComplianceInfo | Table @TableParams

                    # Per-host compliance — InfoLevel >= 4
                    if ($InfoLevel.Cluster -ge 4 -and $lcmCompliance.hosts) {
                        BlankLine
                        $HostComplianceInfo = foreach ($hostId in $lcmCompliance.hosts.PSObject.Properties.Name) {
                            $hostData = $lcmCompliance.hosts.$hostId
                            $hostStatus = $TextInfo.ToTitleCase(
                                $hostData.status.ToString().ToLower().Replace('_', ' ')
                            )
                            [PSCustomObject]@{
                                $LocalizedData.VMHost           = $hostData.host_info.name
                                $LocalizedData.ComplianceStatus = $hostStatus
                            }
                        }
                        if ($Healthcheck.Cluster.LCMCompliance) {
                            $HostComplianceInfo | Where-Object {
                                $_.$($LocalizedData.ComplianceStatus) -ne 'Compliant'
                            } | Set-Style -Style Warning -Property $LocalizedData.ComplianceStatus
                        }
                        $TableParams = @{
                            Name         = ($LocalizedData.TableHostCompliance -f $Cluster)
                            ColumnWidths = 60, 40
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $HostComplianceInfo | Table @TableParams
                    }
                }
            }
            #endregion Image Compliance

        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
