function Get-AbrVSphereVMHostSystem {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost System information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHostSystem
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VMHost)
    }

    process {
        try {
            Write-PScriboMessage -Message $LocalizedData.Collecting
            #region ESXi Host System Section
            Section -Style Heading4 $LocalizedData.SectionHeading {
                Paragraph ($LocalizedData.ParagraphSummary -f $VMHost)
                #region ESXi Host Profile Information
                if ($VMHost | Get-VMHostProfile) {
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.HostProfile {
                            $VMHostProfile = $VMHost | Get-VMHostProfile | Select-Object @{L = $LocalizedData.ProfileName; E = { $_.Name } }, @{L = $LocalizedData.ProfileDescription; E = { $_.Description } }
                            $TableParams = @{
                                Name = ($LocalizedData.TableHostProfile -f $VMHost)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostProfile | Sort-Object $LocalizedData.ProfileName | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.HostProfileError -f $VMHost.Name, $_.Exception.Message)
                    }
                }
                #endregion ESXi Host Profile Information

                #region ESXi Host Image Profile Information
                if ($UserPrivileges -contains 'Host.Config.Settings') {
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.ImageProfile {
                            $installdate = Get-InstallDate
                            $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                            $ImageProfile = $esxcli.software.profile.get.Invoke()
                            $SecurityProfile = [PSCustomObject]@{
                                $LocalizedData.ImageName = $ImageProfile.Name
                                $LocalizedData.ImageVendor = $ImageProfile.Vendor
                                $LocalizedData.InstallDate = $InstallDate.InstallDate
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableImageProfile -f $VMHost)
                                ColumnWidths = 50, 25, 25
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $SecurityProfile | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.ImageProfileError -f $VMHost.Name, $_.Exception.Message)
                    }
                } else {
                    Write-PScriboMessage -Message $LocalizedData.InsufficientPrivImageProfile
                }
                #endregion ESXi Host Image Profile Information

                #region ESXi Host Time Configuration
                try {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.TimeConfiguration {
                        $VMHostTimeSettings = [PSCustomObject]@{
                            $LocalizedData.TimeZone = $VMHost.timezone
                            $LocalizedData.NTPService = if ((Get-VMHostService -VMHost $VMHost | Where-Object { $_.key -eq 'ntpd' }).Running) {
                                $LocalizedData.Running
                            } else {
                                $LocalizedData.Stopped
                            }
                            $LocalizedData.NTPServers = (Get-VMHostNtpServer -VMHost $VMHost | Sort-Object) -join ', '
                        }
                        if ($Healthcheck.VMHost.NTP) {
                            $VMHostTimeSettings | Where-Object { $_.$($LocalizedData.NTPService) -eq $LocalizedData.Stopped } | Set-Style -Style Critical -Property $LocalizedData.NTPService
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableTimeConfig -f $VMHost)
                            ColumnWidths = 30, 30, 40
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostTimeSettings | Table @TableParams
                    }
                } catch {
                    Write-PScriboMessage -Message ($LocalizedData.TimeConfigError -f $VMHost.Name, $_.Exception.Message)
                }
                #endregion ESXi Host Time Configuration

                #region ESXi Host Syslog Configuration
                $SyslogConfig = $VMHost | Get-VMHostSysLogServer
                if ($SyslogConfig) {
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.Syslog {
                            # TODO: Syslog Rotate & Size, Log Directory (Adv Settings)
                            $SyslogConfig = $SyslogConfig | Select-Object @{L = $LocalizedData.SyslogHost; E = { $_.Host } }, @{L = $LocalizedData.SyslogPort; E = { $_.Port } }
                            $TableParams = @{
                                Name = ($LocalizedData.TableSyslog -f $VMHost)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $SyslogConfig | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.SyslogError -f $VMHost.Name, $_.Exception.Message)
                    }
                }
                #endregion ESXi Host Syslog Configuration

                #region ESXi Update Manager Baseline Information
                if ($UserPrivileges -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                    if ($VumServer.Name) {
                        try {
                            $VMHostPatchBaselines = $VMHost | Get-PatchBaseline
                        } catch {
                            Write-PScriboMessage -Message $LocalizedData.VUMBaselineNotAvailable
                        }
                        if ($VMHostPatchBaselines) {
                            try {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VUMBaseline {
                                    $VMHostBaselines = foreach ($VMHostBaseline in $VMHostPatchBaselines) {
                                        [PSCustomObject]@{
                                            $LocalizedData.VUMBaselineName = $VMHostBaseline.Name
                                            $LocalizedData.VUMDescription = $VMHostBaseline.Description
                                            $LocalizedData.VUMBaselineType = $VMHostBaseline.BaselineType
                                            $LocalizedData.VUMTargetType = $VMHostBaseline.TargetType
                                            $LocalizedData.VUMLastUpdate = ($VMHostBaseline.LastUpdateTime).ToLocalTime().ToString()
                                            $LocalizedData.VUMBaselinePatches = $VMHostBaseline.CurrentPatches.Count
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVUMBaselines -f $VMHost)
                                        ColumnWidths = 25, 25, 10, 10, 20, 10
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMHostBaselines | Sort-Object $LocalizedData.VUMBaselineName | Table @TableParams
                                }
                            } catch {
                                Write-PScriboMessage -Message ($LocalizedData.VUMBaselineError -f $VMHost.Name, $_.Exception.Message)
                            }
                        }
                    }
                } else {
                    Write-PScriboMessage -Message $LocalizedData.InsufficientPrivVUMBaseline
                }
                #endregion ESXi Update Manager Baseline Information

                #region ESXi Update Manager Compliance Information
                if ($UserPrivileges -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                    if ($VumServer.Name) {
                        try {
                            $VMHostCompliances = $VMHost | Get-Compliance
                        } catch {
                            Write-PScriboMessage -Message $LocalizedData.VUMComplianceNotAvailable
                        }
                        if ($VMHostCompliances) {
                            try {
                                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VUMCompliance {
                                    $VMHostComplianceInfo = foreach ($VMHostCompliance in $VMHostCompliances) {
                                        [PSCustomObject]@{
                                            $LocalizedData.VUMBaselineName = $VMHostCompliance.Baseline.Name
                                            $LocalizedData.VUMStatus = switch ($VMHostCompliance.Status) {
                                                'NotCompliant' { $LocalizedData.NotCompliant }
                                                default { $VMHostCompliance.Status }
                                            }
                                        }
                                    }
                                    if ($Healthcheck.VMHost.VUMCompliance) {
                                        $VMHostComplianceInfo | Where-Object { $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.Unknown } | Set-Style -Style Warning
                                        $VMHostComplianceInfo | Where-Object { $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.NotCompliant -or $_.$($LocalizedData.VUMStatus) -eq $LocalizedData.Incompatible } | Set-Style -Style Critical
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVUMCompliance -f $VMHost)
                                        ColumnWidths = 75, 25
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VMHostComplianceInfo | Sort-Object $LocalizedData.VUMBaselineName | Table @TableParams
                                }
                            } catch {
                                Write-PScriboMessage -Message -Message ($LocalizedData.VUMComplianceError -f $VMHost.Name, $_.Exception.Message)
                            }
                        }
                    }
                } else {
                    Write-PScriboMessage -Message $LocalizedData.InsufficientPrivVUMCompliance
                }
                #endregion ESXi Update Manager Compliance Information

                #region ESXi Host Comprehensive Information Section
                if ($InfoLevel.VMHost -ge 5) {
                    #region ESXi Host Advanced System Settings
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.AdvancedSettings {
                            $AdvSettings = $VMHost | Get-AdvancedSetting | Select-Object @{L = $LocalizedData.Key; E = { $_.Name } }, @{L = $LocalizedData.Value; E = { $_.Value } }
                            $TableParams = @{
                                Name = ($LocalizedData.TableAdvancedSettings -f $VMHost)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $AdvSettings | Sort-Object $LocalizedData.Key | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.AdvancedSettingsError -f $VMHost.Name, $_.Exception.Message)
                    }
                    #endregion ESXi Host Advanced System Settings

                    #region ESXi Host Software VIBs
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.VIBs {
                            $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                            $VMHostVibs = $esxcli.software.vib.list.Invoke()
                            $VMHostVibs = foreach ($VMHostVib in $VMHostVibs) {
                                [PSCustomObject]@{
                                    $LocalizedData.VIBName = $VMHostVib.Name
                                    $LocalizedData.VIBID = $VMHostVib.Id
                                    $LocalizedData.VIBVersion = $VMHostVib.Version
                                    $LocalizedData.VIBAcceptanceLevel = $VMHostVib.AcceptanceLevel
                                    $LocalizedData.VIBCreationDate = $VMHostVib.CreationDate
                                    $LocalizedData.VIBInstallDate = $VMHostVib.InstallDate
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableVIBs -f $VMHost)
                                ColumnWidths = 15, 25, 15, 15, 15, 15
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostVibs | Sort-Object $LocalizedData.VIBInstallDate -Descending | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.VIBsError -f $VMHost.Name, $_.Exception.Message)
                    }
                    #endregion ESXi Host Software VIBs
                }
                #endregion ESXi Host Comprehensive Information Section
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
        #endregion ESXi Host System Section
    }

    end {}
}
