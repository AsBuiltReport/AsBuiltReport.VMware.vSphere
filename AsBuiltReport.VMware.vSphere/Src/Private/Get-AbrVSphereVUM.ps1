function Get-AbrVSphereVUM {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere VMware Update Manager information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVUM
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VUM)
    }

    process {
        try {
            if (($InfoLevel.VUM -ge 1) -and ($VumServer.Name)) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                try {
                    $VUMBaselines = Get-PatchBaseline -Server $vCenter
                } catch {
                    Write-PScriboMessage -Message $LocalizedData.NotAvailable
                }

                # Query software depots (vSphere 7.0+ REST API)
                $OnlineDepots = $null
                $OfflineDepots = $null
                if ($vcApiUri) {
                    try {
                        $OnlineDepots = Invoke-RestMethod -Uri "$vcApiUri/esx/settings/depots/online" `
                            -Method Get -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
                    } catch {
                        Write-PScriboMessage -IsWarning ($LocalizedData.DepotError -f $_.Exception.Message)
                    }
                    try {
                        $OfflineDepots = Invoke-RestMethod -Uri "$vcApiUri/esx/settings/depots/offline" `
                            -Method Get -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
                    } catch {
                        Write-PScriboMessage -IsWarning ($LocalizedData.DepotError -f $_.Exception.Message)
                    }
                }

                if ($VUMBaselines -or $OnlineDepots -or $OfflineDepots) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region VUM Baseline Detailed Information
                        if ($VUMBaselines) {
                            Section -Style Heading3 $LocalizedData.Baselines {
                                $VUMBaselineInfo = foreach ($VUMBaseline in $VUMBaselines) {
                                    [PSCustomObject]@{
                                        $LocalizedData.BaselineName = $VUMBaseline.Name
                                        $LocalizedData.Description = $VUMBaseline.Description
                                        $LocalizedData.Type = $VUMBaseline.BaselineType
                                        $LocalizedData.TargetType = $VUMBaseline.TargetType
                                        $LocalizedData.LastUpdate = ($VUMBaseline.LastUpdateTime).ToLocalTime().ToString()
                                        $LocalizedData.NumPatches = $VUMBaseline.CurrentPatches.Count
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVUMBaselines -f $vCenterServerName)
                                    ColumnWidths = 25, 25, 10, 10, 20, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VUMBaselineInfo | Sort-Object $LocalizedData.BaselineName | Table @TableParams
                            }
                        }
                        #endregion VUM Baseline Detailed Information

                        #region VUM Comprehensive Information
                        try {
                            $VUMPatches = Get-Patch -Server $vCenter | Sort-Object -Descending ReleaseDate
                        } catch {
                            Write-PScriboMessage -Message $LocalizedData.PatchNotAvailable
                        }
                        if ($VUMPatches -and $InfoLevel.VUM -ge 5) {
                            Section -Style Heading3 $LocalizedData.Patches {
                                $VUMPatchInfo = foreach ($VUMPatch in $VUMPatches) {
                                    [PSCustomObject]@{
                                        $LocalizedData.PatchName = $VUMPatch.Name
                                        $LocalizedData.PatchProduct = ($VUMPatch.Product).Name
                                        $LocalizedData.PatchDescription = $VUMPatch.Description
                                        $LocalizedData.PatchReleaseDate = $VUMPatch.ReleaseDate
                                        $LocalizedData.PatchVendorID = $VUMPatch.IdByVendor
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableVUMPatches -f $vCenterServerName)
                                    ColumnWidths = 20, 20, 20, 20, 20
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VUMPatchInfo | Table @TableParams
                            }
                        }
                        #endregion VUM Comprehensive Information

                        #region Software Depots
                        if ($OnlineDepots -or $OfflineDepots) {
                            Section -Style Heading3 $LocalizedData.SoftwareDepots {
                                if ($OnlineDepots) {
                                    Section -Style Heading4 $LocalizedData.OnlineDepots {
                                        $OnlineDepotInfo = foreach ($id in $OnlineDepots.PSObject.Properties.Name) {
                                            $depot = $OnlineDepots.$id
                                            # vSphere 7.x uses 'depot_url'; vSphere 8.x uses 'url'
                                            $depotUrl = if ($depot.url) { $depot.url } `
                                                elseif ($depot.depot_url) { $depot.depot_url } `
                                                else { '--' }
                                            [PSCustomObject]@{
                                                $LocalizedData.Description    = $depot.description
                                                $LocalizedData.DepotUrl       = $depotUrl
                                                $LocalizedData.SystemDefined  = $depot.system_defined
                                                $LocalizedData.DepotEnabled   = $depot.enabled
                                            }
                                        }
                                        $TableParams = @{
                                            Name         = ($LocalizedData.TableOnlineDepots -f $vCenterServerName)
                                            ColumnWidths = 30, 40, 15, 15
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $OnlineDepotInfo | Sort-Object $LocalizedData.Description | Table @TableParams
                                    }
                                }
                                if ($OfflineDepots) {
                                    $OfflineDepotInfo = foreach ($id in $OfflineDepots.PSObject.Properties.Name) {
                                        $depot = $OfflineDepots.$id
                                        # Skip system-generated bundles (HA, WCP, etc.) which have no location
                                        if (-not $depot.location) { continue }
                                        [PSCustomObject]@{
                                            $LocalizedData.Description   = $depot.description
                                            $LocalizedData.DepotLocation = $depot.location
                                        }
                                    }
                                    if ($OfflineDepotInfo) {
                                        if ($OnlineDepots) { BlankLine }
                                        Section -Style Heading4 $LocalizedData.OfflineDepots {
                                            $TableParams = @{
                                                Name         = ($LocalizedData.TableOfflineDepots -f $vCenterServerName)
                                                ColumnWidths = 40, 60
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $OfflineDepotInfo | Sort-Object $LocalizedData.Description | Table @TableParams
                                        }
                                    }
                                }
                            }
                        }
                        #endregion Software Depots
                    }
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
