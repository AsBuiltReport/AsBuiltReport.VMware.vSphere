function Get-AbrVSphereVMHost {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHost
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VMHost)
    }

    process {
        try {
            if ($InfoLevel.VMHost -ge 1) {
                if ($VMHosts) {
                    Write-PScriboMessage -Message $LocalizedData.Collecting
                    #region Hosts Section
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region ESXi Host Advanced Summary
                        if ($InfoLevel.VMHost -le 2) {
                            BlankLine
                            try {
                                $VMHostInfo = foreach ($VMHost in $VMHosts) {
                                    [PSCustomObject]@{
                                        $LocalizedData.VMHost = $VMHost.Name
                                        $LocalizedData.Version = $VMHost.Version
                                        $LocalizedData.Build = $VMHost.Build
                                        $LocalizedData.Parent = $VMHost.Parent.Name
                                        $LocalizedData.ConnectionState = switch ($VMHost.ConnectionState) {
                                            'NotResponding' { $LocalizedData.NotResponding }
                                            'Maintenance' { $LocalizedData.Maintenance }
                                            'Disconnected' { $LocalizedData.Disconnected }
                                            default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                                        }
                                        $LocalizedData.NumCPUSockets = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
                                        $LocalizedData.NumCPUCores = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
                                        $LocalizedData.MemoryGB = Convert-DataSize $VMHost.MemoryTotalGB -RoundUnits 0
                                        $LocalizedData.NumVMs = $VMHost.ExtensionData.Vm.Count
                                    }
                                }
                                if ($Healthcheck.VMHost.ConnectionState) {
                                    $VMHostInfo | Where-Object { $_.$($LocalizedData.ConnectionState) -eq $LocalizedData.Maintenance } | Set-Style -Style Warning
                                    $VMHostInfo | Where-Object { $_.$($LocalizedData.ConnectionState) -eq $LocalizedData.NotResponding } | Set-Style -Style Critical
                                    $VMHostInfo | Where-Object { $_.$($LocalizedData.ConnectionState) -eq $LocalizedData.Disconnected } | Set-Style -Style Critical
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableHostSummary -f $vCenterServerName)
                                    ColumnWidths = 17, 9, 11, 15, 13, 9, 9, 9, 8
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMHostInfo | Table @TableParams
                            } catch {
                                Write-PScriboMessage -Message ($LocalizedData.ErrorCollecting -f $InfoLevel.VMHost)
                            }
                        }
                        #endregion ESXi Host Advanced Summary

                        #region ESXi Host Detailed Information
                        if ($InfoLevel.VMHost -ge 3) {
                            #region foreach VMHost Detailed Information loop
                            foreach ($VMHost in ($VMHosts | Where-Object { $_.ConnectionState -eq 'Connected' -or $_.ConnectionState -eq 'Maintenance' })) {
                                #region VMHost Section
                                Section -Style Heading3 $VMHost {
                                    if ($TagAssignments | Where-Object { $_.entity -eq $VMHost }) {
                                        Paragraph ($LocalizedData.Tags + ': ' + (($TagAssignments | Where-Object { $_.entity -eq $VMHost }).Tag -join ', '))
                                    }
                                    Get-AbrVSphereVMHostHardware
                                    Get-AbrVSphereVMHostSystem
                                    Get-AbrVSphereVMHostStorage
                                    Get-AbrVSphereVMHostNetwork
                                    Get-AbrVSphereVMHostSecurity
                                }
                                #endregion VMHost Section
                            }
                            #endregion foreach VMHost Detailed Information loop
                        }
                        #endregion ESXi Host Detailed Information
                    }
                    #endregion Hosts Section
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
