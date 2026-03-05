function Get-AbrVSphereVMHostSecurity {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost Security information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHostSecurity
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VMHost)
    }

    process {
        try {
            Write-PScriboMessage -Message $LocalizedData.Collecting
            #region ESXi Host Security Section
            Section -Style Heading4 $LocalizedData.SectionHeading {
                Paragraph ($LocalizedData.ParagraphSummary -f $VMHost)
                #region ESXi Host Lockdown Mode
                if ($null -ne $VMHost.ExtensionData.Config.LockdownMode) {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.LockdownMode {
                        $LockdownMode = [PSCustomObject]@{
                            $LocalizedData.LockdownMode = switch ($VMHost.ExtensionData.Config.LockdownMode) {
                                'lockdownDisabled' { $LocalizedData.LockdownDisabled }
                                'lockdownNormal' { $LocalizedData.LockdownNormal }
                                'lockdownStrict' { $LocalizedData.LockdownStrict }
                                default { $VMHost.ExtensionData.Config.LockdownMode }
                            }
                        }
                        if ($Healthcheck.VMHost.LockdownMode) {
                            $LockdownMode | Where-Object { $_.$($LocalizedData.LockdownMode) -eq $LocalizedData.LockdownDisabled } | Set-Style -Style Warning -Property $LocalizedData.LockdownMode
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableLockdownMode -f $VMHost)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $LockdownMode | Table @TableParams
                    }
                }
                #endregion ESXi Host Lockdown Mode

                #region ESXi Host Services
                Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.Services {
                    $VMHostServices = $VMHost | Get-VMHostService
                    $Services = foreach ($VMHostService in $VMHostServices) {
                        [PSCustomObject]@{
                            $LocalizedData.ServiceName = $VMHostService.Label
                            $LocalizedData.ServiceRunning = if ($VMHostService.Running) {
                                $LocalizedData.Running
                            } else {
                                $LocalizedData.Stopped
                            }
                            $LocalizedData.ServicePolicy = switch ($VMHostService.Policy) {
                                'automatic' { $LocalizedData.SvcPortUsage }
                                'on' { $LocalizedData.SvcWithHost }
                                'off' { $LocalizedData.SvcManually }
                                default { $VMHostService.Policy }
                            }
                        }
                    }
                    if ($Healthcheck.VMHost.NTP) {
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'NTP Daemon') -and ($_.$($LocalizedData.ServiceRunning) -eq $LocalizedData.Stopped) } | Set-Style -Style Critical -Property $LocalizedData.ServiceRunning
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'NTP Daemon') -and ($_.$($LocalizedData.ServicePolicy) -ne $LocalizedData.SvcWithHost) } | Set-Style -Style Critical -Property $LocalizedData.ServicePolicy
                    }
                    if ($Healthcheck.VMHost.SSH) {
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'SSH') -and ($_.$($LocalizedData.ServiceRunning) -eq $LocalizedData.Running) } | Set-Style -Style Warning -Property $LocalizedData.ServiceRunning
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'SSH') -and ($_.$($LocalizedData.ServicePolicy) -ne $LocalizedData.SvcManually) } | Set-Style -Style Warning -Property $LocalizedData.ServicePolicy
                    }
                    if ($Healthcheck.VMHost.ESXiShell) {
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'ESXi Shell') -and ($_.$($LocalizedData.ServiceRunning) -eq $LocalizedData.Running) } | Set-Style -Style Warning -Property $LocalizedData.ServiceRunning
                        $Services | Where-Object { ($_.$($LocalizedData.ServiceName) -eq 'ESXi Shell') -and ($_.$($LocalizedData.ServicePolicy) -ne $LocalizedData.SvcManually) } | Set-Style -Style Warning -Property $LocalizedData.ServicePolicy
                    }
                    $TableParams = @{
                        Name = ($LocalizedData.TableServices -f $VMHost)
                        ColumnWidths = 40, 20, 40
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $Services | Sort-Object $LocalizedData.ServiceName | Table @TableParams
                }
                #endregion ESXi Host Services

                #region ESXi Host Advanced Detail Information
                if ($InfoLevel.VMHost -ge 4) {
                    #region ESXi Host Firewall
                    $VMHostFirewallExceptions = $VMHost | Get-VMHostFirewallException
                    if ($VMHostFirewallExceptions) {
                        #region Friewall Section
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.Firewall {
                            $VMHostFirewall = foreach ($VMHostFirewallException in $VMHostFirewallExceptions) {
                                [PScustomObject]@{
                                    $LocalizedData.FirewallService = $VMHostFirewallException.Name
                                    $LocalizedData.Status = if ($VMHostFirewallException.Enabled) {
                                        $LocalizedData.Enabled
                                    } else {
                                        $LocalizedData.Disabled
                                    }
                                    $LocalizedData.IncomingPorts = $VMHostFirewallException.IncomingPorts
                                    $LocalizedData.OutgoingPorts = $VMHostFirewallException.OutgoingPorts
                                    $LocalizedData.Protocols = $VMHostFirewallException.Protocols
                                    $LocalizedData.Daemon = switch ($VMHostFirewallException.ServiceRunning) {
                                        $true { $LocalizedData.Running }
                                        $false { $LocalizedData.Stopped }
                                        $null { 'N/A' }
                                        default { $VMHostFirewallException.ServiceRunning }
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableFirewall -f $VMHost)
                                ColumnWidths = 22, 12, 21, 21, 12, 12
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostFirewall | Sort-Object $LocalizedData.FirewallService | Table @TableParams
                        }
                        #endregion Friewall Section
                    }
                    #endregion ESXi Host Firewall

                    #region ESXi Host Authentication
                    $AuthServices = $VMHost | Get-VMHostAuthentication
                    if ($AuthServices.DomainMembershipStatus) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.Authentication {
                            $AuthServices = $AuthServices | Select-Object @{L = $LocalizedData.Domain; E = { $_.Domain } }, @{L = $LocalizedData.DomainMembership; E = { $_.DomainMembershipStatus } }, @{L = $LocalizedData.TrustedDomains; E = { $_.TrustedDomains } }
                            $TableParams = @{
                                Name = ($LocalizedData.TableAuthentication -f $VMHost)
                                ColumnWidths = 25, 25, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $AuthServices | Table @TableParams
                        }
                    }
                    #endregion ESXi Host Authentication
                }
                #endregion ESXi Host Advanced Detail Information
            }
            #endregion ESXi Host Security Section

            #region ESXi Host Virtual Machines Advanced Detail Information
            if ($InfoLevel.VMHost -ge 4) {
                $VMHostVMs = $VMHost | Get-VM | Sort-Object Name
                if ($VMHostVMs) {
                    #region Virtual Machines Section
                    Section -Style Heading4 $LocalizedData.VMInfoSection {
                        Paragraph ($LocalizedData.ParagraphVMInfo -f $VMHost)
                        BlankLine
                        #region ESXi Host Virtual Machine Information
                        $VMHostVMInfo = foreach ($VMHostVM in $VMHostVMs) {
                            $VMHostVMView = $VMHostVM | Get-View
                            [PSCustomObject]@{
                                $LocalizedData.VMName = $VMHostVM.Name
                                $LocalizedData.VMPowerState = switch ($VMHostVM.PowerState) {
                                    'PoweredOn' { $LocalizedData.On }
                                    'PoweredOff' { $LocalizedData.Off }
                                    default { $VMHostVM.PowerState }
                                }
                                $LocalizedData.VMIPAddress = if ($VMHostVMView.Guest.IpAddress) {
                                    $VMHostVMView.Guest.IpAddress
                                } else {
                                    '--'
                                }
                                $LocalizedData.VMCPUs = $VMHostVM.NumCpu
                                #'Cores per Socket' = $VMHostVM.CoresPerSocket
                                $LocalizedData.VMMemoryGB = Convert-DataSize $VMHostVM.memoryGB -RoundUnits 0
                                $LocalizedData.VMProvisioned = Convert-DataSize $VMHostVM.ProvisionedSpaceGB
                                $LocalizedData.VMUsed = Convert-DataSize $VMHostVM.UsedSpaceGB
                                $LocalizedData.VMHWVersion = ($VMHostVM.HardwareVersion).Replace('vmx-', 'v')
                                $LocalizedData.VMToolsStatus = switch ($VMHostVM.ExtensionData.Guest.ToolsStatus) {
                                    'toolsOld' { $LocalizedData.ToolsOld }
                                    'toolsOK' { $LocalizedData.ToolsOK }
                                    'toolsNotRunning' { $LocalizedData.ToolsNotRunning }
                                    'toolsNotInstalled' { $LocalizedData.ToolsNotInstalled }
                                    default { $VMHostVM.ExtensionData.Guest.ToolsStatus }
                                }
                            }
                        }
                        if ($Healthcheck.VM.VMToolsStatus) {
                            $VMHostVMInfo | Where-Object { $_.$($LocalizedData.VMToolsStatus) -ne $LocalizedData.ToolsOK } | Set-Style -Style Warning -Property $LocalizedData.VMToolsStatus
                        }
                        if ($Healthcheck.VM.PowerState) {
                            $VMHostVMInfo | Where-Object { $_.$($LocalizedData.VMPowerState) -ne $LocalizedData.On } | Set-Style -Style Warning -Property $LocalizedData.VMPowerState
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableVMs -f $VMHost)
                            ColumnWidths = 21, 8, 16, 9, 9, 9, 9, 9, 10
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostVMInfo | Table @TableParams
                        #endregion ESXi Host Virtual Machine Information

                        #region ESXi Host VM Startup/Shutdown Information
                        $VMStartPolicy = $VMHost | Get-VMStartPolicy | Where-Object { $_.StartAction -ne 'None' }
                        if ($VMStartPolicy) {
                            #region VM Startup/Shutdown Section
                            Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.StartupShutdown {
                                $VMStartPolicies = foreach ($VMStartPol in $VMStartPolicy) {
                                    [PSCustomObject]@{
                                        $LocalizedData.StartupOrder = $VMStartPol.StartOrder
                                        $LocalizedData.VMName = $VMStartPol.VirtualMachineName
                                        $LocalizedData.StartupEnabled = switch ($VMStartPol.StartAction) {
                                            'PowerOn' { $LocalizedData.Enabled }
                                            'None' { $LocalizedData.Disabled }
                                            default { $VMStartPol.StartAction }
                                        }
                                        $LocalizedData.StartupDelay = "$($VMStartPol.StartDelay) seconds"
                                        $LocalizedData.WaitForHeartbeat = if ($VMStartPol.WaitForHeartbeat) {
                                            $LocalizedData.WaitHeartbeat
                                        } else {
                                            $LocalizedData.WaitDelay
                                        }
                                        $LocalizedData.StopAction = switch ($VMStartPol.StopAction) {
                                            'PowerOff' { $LocalizedData.PowerOff }
                                            'GuestShutdown' { $LocalizedData.GuestShutdown }
                                            default { $VMStartPol.StopAction }
                                        }
                                        $LocalizedData.StopDelay = "$($VMStartPol.StopDelay) seconds"
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableStartupShutdown -f $VMHost)
                                    ColumnWidths = 11, 34, 11, 11, 11, 11, 11
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMStartPolicies | Table @TableParams
                            }
                            #endregion VM Startup/Shutdown Section
                        }
                        #endregion ESXi Host VM Startup/Shutdown Information
                    }
                    #endregion Virtual Machines Section
                }
            }
            #endregion ESXi Host Virtual Machines Advanced Detail Information
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
