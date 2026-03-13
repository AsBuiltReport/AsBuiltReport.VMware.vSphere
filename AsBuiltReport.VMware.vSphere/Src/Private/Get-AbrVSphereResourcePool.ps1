function Get-AbrVSphereResourcePool {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere Resource Pool information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereResourcePool
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.ResourcePool)
    }

    process {
        try {
            if ($InfoLevel.ResourcePool -ge 1) {
                $ResourcePools = Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
                if ($ResourcePools) {
                    Write-PScriboMessage -Message $LocalizedData.Collecting
                    #region Resource Pools Section
                    Section -Style Heading2 $LocalizedData.SectionHeading {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                        #region Resource Pool Advanced Summary
                        if ($InfoLevel.ResourcePool -le 2) {
                            BlankLine
                            $ResourcePoolInfo = foreach ($ResourcePool in $ResourcePools) {
                                [PSCustomObject]@{
                                    $LocalizedData.ResourcePool = $ResourcePool.Name
                                    $LocalizedData.Parent = $ResourcePool.Parent.Name
                                    $LocalizedData.CPUSharesLevel = $ResourcePool.CpuSharesLevel
                                    $LocalizedData.CPUReservationMHz = $ResourcePool.CpuReservationMHz
                                    $LocalizedData.CPULimitMHz = switch ($ResourcePool.CpuLimitMHz) {
                                        '-1' { $LocalizedData.Unlimited }
                                        default { $ResourcePool.CpuLimitMHz }
                                    }
                                    $LocalizedData.MemSharesLevel = $ResourcePool.MemSharesLevel
                                    $LocalizedData.MemReservation = Convert-DataSize $ResourcePool.MemReservationGB -RoundUnits 0
                                    $LocalizedData.MemLimit = switch ($ResourcePool.MemLimitGB) {
                                        '-1' { $LocalizedData.Unlimited }
                                        default { Convert-DataSize $ResourcePool.MemLimitGB -RoundUnits 0 }
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableResourcePoolSummary -f $vCenterServerName)
                                ColumnWidths = 20, 20, 10, 10, 10, 10, 10, 10
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $ResourcePoolInfo | Sort-Object $LocalizedData.ResourcePool | Table @TableParams
                        }
                        #endregion Resource Pool Advanced Summary

                        #region Resource Pool Detailed Information
                        if ($InfoLevel.ResourcePool -ge 3) {
                            foreach ($ResourcePool in $ResourcePools) {
                                Section -Style Heading3 $ResourcePool.Name {
                                    $ResourcePoolDetail = [PSCustomObject]@{
                                        $LocalizedData.ResourcePool = $ResourcePool.Name
                                        $LocalizedData.ID = $ResourcePool.Id
                                        $LocalizedData.Parent = $ResourcePool.Parent.Name
                                        $LocalizedData.CPUSharesLevel = $ResourcePool.CpuSharesLevel
                                        $LocalizedData.NumCPUShares = $ResourcePool.NumCpuShares
                                        $LocalizedData.CPUReservation = "$($ResourcePool.CpuReservationMHz) MHz"
                                        $LocalizedData.CPUExpandable = if ($ResourcePool.CpuExpandableReservation) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.CPULimitMHz = switch ($ResourcePool.CpuLimitMHz) {
                                            '-1' { $LocalizedData.Unlimited }
                                            default { "$($ResourcePool.CpuLimitMHz) MHz" }
                                        }
                                        $LocalizedData.MemSharesLevel = $ResourcePool.MemSharesLevel
                                        $LocalizedData.NumMemShares = $ResourcePool.NumMemShares
                                        $LocalizedData.MemReservation = Convert-DataSize $ResourcePool.MemReservationGB -RoundUnits 0
                                        $LocalizedData.MemExpandable = if ($ResourcePool.MemExpandableReservation) {
                                            $LocalizedData.Enabled
                                        } else {
                                            $LocalizedData.Disabled
                                        }
                                        $LocalizedData.MemLimit = switch ($ResourcePool.MemLimitGB) {
                                            '-1' { $LocalizedData.Unlimited }
                                            default { Convert-DataSize $ResourcePool.MemLimitGB -RoundUnits 0 }
                                        }
                                        $LocalizedData.NumVMs = $ResourcePool.ExtensionData.VM.Count
                                    }
                                    $MemberProps = @{
                                        'InputObject' = $ResourcePoolDetail
                                        'MemberType' = 'NoteProperty'
                                    }
                                    if ($TagAssignments | Where-Object { $_.entity -eq $ResourcePool }) {
                                        Add-Member @MemberProps -Name $LocalizedData.Tags -Value $(($TagAssignments | Where-Object { $_.entity -eq $ResourcePool }).Tag -join ', ')
                                    }
                                    #region Resource Pool Advanced Detail Information
                                    if ($InfoLevel.ResourcePool -ge 4) {
                                        $ResourcePoolDetail | ForEach-Object {
                                            # Query for VMs by resource pool Id
                                            $ResourcePoolId = $_.Id
                                            $ResourcePoolVMs = $VMs | Where-Object { $_.ResourcePoolId -eq $ResourcePoolId } | Sort-Object Name
                                            Add-Member -InputObject $_ -MemberType NoteProperty -Name $LocalizedData.VirtualMachines -Value ($ResourcePoolVMs.Name -join ', ')
                                        }
                                    }
                                    #endregion Resource Pool Advanced Detail Information
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableResourcePoolConfig -f $ResourcePool.Name)
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $ResourcePoolDetail | Table @TableParams
                                }
                            }
                        }
                        #endregion Resource Pool Detailed Information
                    }
                    #endregion Resource Pools Section
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
