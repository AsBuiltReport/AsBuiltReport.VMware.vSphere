function Get-AbrVSphereVMHostStorage {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost Storage information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHostStorage
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.VMHost)
    }

    process {
        try {
            Write-PScriboMessage -Message $LocalizedData.Collecting
            #region ESXi Host Storage Section
            Section -Style Heading4 $LocalizedData.SectionHeading {
                Paragraph ($LocalizedData.ParagraphSummary -f $VMHost)

                #region ESXi Host Datastore Specifications
                $VMHostDatastores = $VMHost | Get-Datastore | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
                if ($VMHostDatastores) {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.DatastoreSpecs {
                        $VMHostDsSpecs = foreach ($VMHostDatastore in $VMHostDatastores) {

                            $VMHostDsUsedPercent = if (0 -in @($VMHostDatastore.FreeSpaceGB, $VMHostDatastore.CapacityGB)) { 0 } else { [math]::Round((100 - (($VMHostDatastore.FreeSpaceGB) / ($VMHostDatastore.CapacityGB) * 100)), 2) }
                            $VMHostDsFreePercent = if (0 -in @($VMHostDatastore.FreeSpaceGB, $VMHostDatastore.CapacityGB)) { 0 } else { [math]::Round(($VMHostDatastore.FreeSpaceGB / $VMHostDatastore.CapacityGB) * 100, 2) }
                            $VMHostDsUsedCapacityGB = ($VMHostDatastore.CapacityGB) - ($VMHostDatastore.FreeSpaceGB)

                            [PSCustomObject]@{
                                $LocalizedData.Datastore = $VMHostDatastore.Name
                                $LocalizedData.DatastoreType = $VMHostDatastore.Type
                                $LocalizedData.Version = if ($VMHostDatastore.FileSystemVersion) {
                                    $VMHostDatastore.FileSystemVersion
                                } else {
                                    '--'
                                }
                                $LocalizedData.NumberOfVMs = $VMHostDatastore.ExtensionData.VM.Count
                                $LocalizedData.TotalCapacity = Convert-DataSize $VMHostDatastore.CapacityGB
                                $LocalizedData.UsedCapacity = "{0} ({1}%)" -f (Convert-DataSize $VMHostDsUsedCapacityGB), $VMHostDsUsedPercent
                                $LocalizedData.FreeCapacity = "{0} ({1}%)" -f (Convert-DataSize $Datastore.FreeSpaceGB), $VMHostDsFreePercent
                                $LocalizedData.PercentUsed = $VMHostDsUsedPercent
                            }
                        }
                        if ($Healthcheck.Datastore.CapacityUtilization) {
                            $VMHostDsSpecs | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 90 } | Set-Style -Style Critical -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                            $VMHostDsSpecs | Where-Object { $_.$($LocalizedData.PercentUsed) -ge 75 -and $_.$($LocalizedData.PercentUsed) -lt 90 } | Set-Style -Style Warning -Property $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableDatastores -f $VMHost)
                            Columns = $LocalizedData.Datastore, $LocalizedData.DatastoreType, $LocalizedData.Version, $LocalizedData.NumberOfVMs, $LocalizedData.TotalCapacity, $LocalizedData.UsedCapacity, $LocalizedData.FreeCapacity
                            ColumnWidths = 21, 10, 9, 9, 17, 17, 17
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostDsSpecs | Sort-Object $LocalizedData.Datastore | Table @TableParams
                    }
                }
                #endregion ESXi Host Datastore Specifications

                #region ESXi Host Storage Adapter Information
                $VMHostHbas = $VMHost | Get-VMHostHba | Sort-Object Device
                if ($VMHostHbas) {
                    #region ESXi Host Storage Adapters Section
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.StorageAdapters {
                        Paragraph ($LocalizedData.ParagraphStorageAdapters -f $VMHost)
                        foreach ($VMHostHba in $VMHostHbas) {
                            $Target = ((Get-View $VMHostHba.VMhost).Config.StorageDevice.ScsiTopology.Adapter | Where-Object { $_.Adapter -eq $VMHostHba.Key }).Target
                            $LUNs = Get-ScsiLun -Hba $VMHostHba -LunType "disk" -ErrorAction SilentlyContinue
                            $Paths = ($Target | ForEach-Object { $_.Lun.Count } | Measure-Object -Sum)
                            Section -Style NOTOCHeading5 -ExcludeFromTOC "$($VMHostHba.Device)" {
                                $VMHostStorageAdapter = [PSCustomObject]@{
                                    $LocalizedData.AdapterName = $VMHostHba.Device
                                    $LocalizedData.AdapterType = switch ($VMHostHba.Type) {
                                        'FibreChannel' { $LocalizedData.FC }
                                        'IScsi' { $LocalizedData.iSCSI }
                                        'ParallelScsi' { $LocalizedData.ParallelSCSI }
                                        default { $TextInfo.ToTitleCase($VMHostHba.Type) }
                                    }
                                    $LocalizedData.AdapterModel = $VMHostHba.Model
                                    $LocalizedData.AdapterStatus = $TextInfo.ToTitleCase($VMHostHba.Status)
                                    $LocalizedData.AdapterTargets = $Target.Count
                                    $LocalizedData.AdapterDevices = $LUNs.Count
                                    $LocalizedData.AdapterPaths = $Paths.Sum
                                }
                                $MemberProps = @{
                                    'InputObject' = $VMHostStorageAdapter
                                    'MemberType' = 'NoteProperty'
                                }
                                if ($VMHostStorageAdapter.$($LocalizedData.AdapterType) -eq $LocalizedData.iSCSI) {
                                    $iScsiAuthenticationMethod = switch ($VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType) {
                                        'chapProhibited' { $LocalizedData.ChapNone }
                                        'chapPreferred' { $LocalizedData.ChapUniPreferred }
                                        'chapDiscouraged' { $LocalizedData.ChapUniRequired }
                                        'chapRequired' {
                                            switch ($VMHostHba.ExtensionData.AuthenticationProperties.MutualChapAuthenticationType) {
                                                'chapProhibited' { $LocalizedData.ChapUnidirectional }
                                                'chapRequired' { $LocalizedData.ChapBidirectional }
                                            }
                                        }
                                        default { $VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType }
                                    }
                                    Add-Member @MemberProps -Name $LocalizedData.iSCSIName -Value $VMHostHba.IScsiName
                                    if ($VMHostHba.IScsiAlias) {
                                        Add-Member @MemberProps -Name $LocalizedData.iSCSIAlias -Value $VMHostHba.IScsiAlias
                                    } else {
                                        Add-Member @MemberProps -Name $LocalizedData.iSCSIAlias -Value '--'
                                    }
                                    if ($VMHostHba.CurrentSpeedMb) {
                                        Add-Member @MemberProps -Name $LocalizedData.AdapterSpeed -Value "$($VMHostHba.CurrentSpeedMb) Mb"
                                    } else {
                                        Add-Member @MemberProps -Name $LocalizedData.AdapterSpeed -Value '--'
                                    }
                                    if ($VMHostHba.ExtensionData.ConfiguredSendTarget) {
                                        Add-Member @MemberProps -Name $LocalizedData.DynamicDiscovery -Value (($VMHostHba.ExtensionData.ConfiguredSendTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" }) -join [Environment]::NewLine)
                                    } else {
                                        Add-Member @MemberProps -Name $LocalizedData.DynamicDiscovery -Value '--'
                                    }
                                    if ($VMHostHba.ExtensionData.ConfiguredStaticTarget) {
                                        Add-Member @MemberProps -Name $LocalizedData.StaticDiscovery -Value (($VMHostHba.ExtensionData.ConfiguredStaticTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" + "  " + "$($_.IScsiName)" }) -join [Environment]::NewLine)
                                    } else {
                                        Add-Member @MemberProps -Name $LocalizedData.StaticDiscovery -Value '--'
                                    }
                                    if ($iScsiAuthenticationMethod -eq $LocalizedData.ChapNone) {
                                        Add-Member @MemberProps -Name $LocalizedData.AuthMethod -Value $iScsiAuthenticationMethod
                                    } elseif ($iScsiAuthenticationMethod -eq $LocalizedData.ChapBidirectional) {
                                        Add-Member @MemberProps -Name $LocalizedData.AuthMethod -Value $iScsiAuthenticationMethod
                                        Add-Member @MemberProps -Name $LocalizedData.CHAPOutgoing -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                        Add-Member @MemberProps -Name $LocalizedData.CHAPIncoming -Value $VMHostHba.ExtensionData.AuthenticationProperties.MutualChapName
                                    } else {
                                        Add-Member @MemberProps -Name $LocalizedData.AuthMethod -Value $iScsiAuthenticationMethod
                                        Add-Member @MemberProps -Name $LocalizedData.CHAPOutgoing -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                    }
                                    if ($InfoLevel.VMHost -ge 4) {
                                        Add-Member @MemberProps -Name $LocalizedData.AdvancedOptions -Value (($VMHostHba.ExtensionData.AdvancedOptions | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join [Environment]::NewLine)
                                    }
                                }
                                if ($VMHostStorageAdapter.$($LocalizedData.AdapterType) -eq $LocalizedData.FC) {
                                    Add-Member @MemberProps -Name $LocalizedData.NodeWWN -Value (([String]::Format("{0:X}", $VMHostHba.NodeWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                    Add-Member @MemberProps -Name $LocalizedData.PortWWN -Value (([String]::Format("{0:X}", $VMHostHba.PortWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                    Add-Member @MemberProps -Name $LocalizedData.AdapterSpeed -Value $VMHostHba.Speed
                                }
                                if ($Healthcheck.VMHost.StorageAdapter) {
                                    $VMHostStorageAdapter | Where-Object { $_.$($LocalizedData.AdapterStatus) -ne $LocalizedData.Online } | Set-Style -Style Warning -Property $LocalizedData.AdapterStatus
                                    $VMHostStorageAdapter | Where-Object { $_.$($LocalizedData.AdapterStatus) -eq $LocalizedData.Offline } | Set-Style -Style Critical -Property $LocalizedData.AdapterStatus
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableStorageAdapter -f $VMHostStorageAdapter.$($LocalizedData.AdapterName), $VMHost)
                                    List = $true
                                    ColumnWidths = 25, 75
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMHostStorageAdapter | Table @TableParams
                            }
                        }
                    }
                    #endregion ESXi Host Storage Adapters Section
                }
                #endregion ESXi Host Storage Adapter Information
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
        #endregion ESXi Host Storage Section
    }

    end {}
}
