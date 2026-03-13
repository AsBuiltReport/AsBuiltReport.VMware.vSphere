function Get-AbrVSphereCluster {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Cluster information.
    .DESCRIPTION
        Documents the configuration of VMware vSphere Clusters in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereCluster
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.Cluster)
    }

    process {
        try {
            if ($InfoLevel.Cluster -ge 1) {
                $Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
                if ($Clusters) {
                    Write-PScriboMessage -Message $LocalizedData.Collecting
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Cluster Summary
                        if ($InfoLevel.Cluster -le 2) {
                            BlankLine
                            $ClusterInfo = foreach ($Cluster in $Clusters) {
                                [PSCustomObject]@{
                                    $LocalizedData.Cluster = $Cluster.Name
                                    $LocalizedData.Datacenter = ($Cluster | Get-Datacenter).Name
                                    $LocalizedData.NumHosts = $Cluster.ExtensionData.Host.Count
                                    $LocalizedData.NumVMs = $Cluster.ExtensionData.VM.Count
                                    $LocalizedData.HAEnabled = if ($Cluster.HAEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                    $LocalizedData.DRSEnabled = if ($Cluster.DRSEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                    $LocalizedData.VSANEnabled = if ($Cluster.VsanEnabled -or $VsanCluster.VsanEsaEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                    $LocalizedData.EVCMode = if ($Cluster.EVCMode) { $EvcModeLookup."$($Cluster.EVCMode)" } else { $LocalizedData.Disabled }
                                    $LocalizedData.VMSwapFilePolicy = switch ($Cluster.VMSwapfilePolicy) {
                                        'WithVM' { $LocalizedData.SwapWithVM }
                                        'InHostDatastore' { $LocalizedData.SwapInHostDatastore }
                                        default { $Cluster.VMSwapfilePolicy }
                                    }
                                }
                            }
                            if ($Healthcheck.Cluster.HAEnabled) {
                                $ClusterInfo | Where-Object { $_.$($LocalizedData.HAEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.HAEnabled
                            }
                            if ($Healthcheck.Cluster.DRSEnabled) {
                                $ClusterInfo | Where-Object { $_.$($LocalizedData.DRSEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.DRSEnabled
                            }
                            if ($Healthcheck.Cluster.VsanEnabled) {
                                $ClusterInfo | Where-Object { $_.$($LocalizedData.VSANEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.VSANEnabled
                            }
                            if ($Healthcheck.Cluster.EvcEnabled) {
                                $ClusterInfo | Where-Object { $_.$($LocalizedData.EVCMode) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.EVCMode
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableClusterSummary -f $vCenterServerName)
                                ColumnWidths = 15, 15, 7, 7, 11, 11, 11, 15, 8
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $ClusterInfo | Table @TableParams
                        }
                        #endregion Cluster Summary

                        #region Cluster Detailed Information
                        if ($InfoLevel.Cluster -ge 3) {
                            $Count = 1
                            foreach ($Cluster in $Clusters) {
                                Write-PScriboMessage -Message ($LocalizedData.Processing -f $Cluster.Name, $Count, $Clusters.Count)
                                $Count++
                                $ClusterDasConfig = $Cluster.ExtensionData.Configuration.DasConfig
                                $ClusterDrsConfig = $Cluster.ExtensionData.Configuration.DrsConfig
                                $ClusterConfigEx = $Cluster.ExtensionData.ConfigurationEx
                                Section -Style Heading3 $Cluster {
                                    Paragraph ($LocalizedData.ParagraphDetail -f $Cluster)
                                    BlankLine
                                    #region Cluster Configuration
                                    $ClusterDetail = [PSCustomObject]@{
                                        $LocalizedData.Cluster = $Cluster.Name
                                        $LocalizedData.ID = $Cluster.Id
                                        $LocalizedData.Datacenter = ($Cluster | Get-Datacenter).Name
                                        $LocalizedData.NumberOfHosts = $Cluster.ExtensionData.Host.Count
                                        $LocalizedData.NumberOfVMs = ($Cluster | Get-VM).Count
                                        $LocalizedData.HAEnabled = if ($Cluster.HAEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                        $LocalizedData.DRSEnabled = if ($Cluster.DRSEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                        $LocalizedData.VSANEnabled = if ($Cluster.VsanEnabled -or $Cluster.VsanEsaEnabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled }
                                        $LocalizedData.EVCMode = if ($Cluster.EVCMode) { $EvcModeLookup."$($Cluster.EVCMode)" } else { $LocalizedData.Disabled }
                                        $LocalizedData.VMSwapFilePolicy = switch ($Cluster.VMSwapfilePolicy) {
                                            'WithVM' { $LocalizedData.SwapVMDirectory }
                                            'InHostDatastore' { $LocalizedData.SwapHostDatastore }
                                            default { $Cluster.VMSwapfilePolicy }
                                        }
                                    }
                                    if ($Healthcheck.Cluster.HAEnabled) {
                                        $ClusterDetail | Where-Object { $_.$($LocalizedData.HAEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.HAEnabled
                                    }
                                    if ($Healthcheck.Cluster.DRSEnabled) {
                                        $ClusterDetail | Where-Object { $_.$($LocalizedData.DRSEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.DRSEnabled
                                    }
                                    if ($Healthcheck.Cluster.VsanEnabled) {
                                        $ClusterDetail | Where-Object { $_.$($LocalizedData.VSANEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.VSANEnabled
                                    }
                                    if ($Healthcheck.Cluster.EvcEnabled) {
                                        $ClusterDetail | Where-Object { $_.$($LocalizedData.EVCMode) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.EVCMode
                                    }
                                    if ($InfoLevel.Cluster -ge 4) {
                                        $ClusterDetail | ForEach-Object {
                                            $ClusterHosts = $Cluster | Get-VMHost | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name $LocalizedData.Hosts -Value ($ClusterHosts.Name -join ', ')
                                            $ClusterVMs = $Cluster | Get-VM | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name $LocalizedData.VirtualMachines -Value ($ClusterVMs.Name -join ', ')
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableClusterConfig -f $Cluster)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $ClusterDetail | Table @TableParams
                                    #endregion Cluster Configuration

                                    # Call sub-functions for HA, Proactive HA, DRS, VUM, and LCM
                                    Get-AbrVSphereClusterHA
                                    Get-AbrVSphereClusterProactiveHA
                                    Get-AbrVSphereClusterDRS
                                    Get-AbrVSphereClusterVUM
                                    Get-AbrVSphereClusterLCM
                                }
                            }
                        }
                        #endregion Cluster Detailed Information
                    }
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
