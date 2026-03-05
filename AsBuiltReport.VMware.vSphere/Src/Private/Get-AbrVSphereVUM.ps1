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
                if ($VUMBaselines) {
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region VUM Baseline Detailed Information
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
                        #endregion VUM Baseline Detailed Information

                        #region VUM Comprehensive Information
                        try {
                            $VUMPatches = Get-Patch -Server $vCenter | Sort-Object -Descending ReleaseDate
                        } catch {
                            Write-PScriboMessage -Message $LocalizedData.PatchNotAvailable
                        }
                        if ($VUMPatches -and $InfoLevel.VUM -ge 5) {
                            BlankLine
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
                    }
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
