function Get-AbrVSpherevCenter {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vCenter Server information.
    .DESCRIPTION
        Documents the configuration of VMware vCenter Server in Word/HTML/Text formats using PScribo.
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
        $LocalizedData = $reportTranslate.GetAbrVSpherevCenter
        Write-PScriboMessage -Message ($LocalizedData.InfoLevel -f $InfoLevel.vCenter)
    }

    process {
        try {
            if ($InfoLevel.vCenter -ge 1) {
                Write-PScriboMessage -Message $LocalizedData.Collecting
                Section -Style Heading2 $LocalizedData.SectionHeading {
                    if ($InfoLevel.vCenter -le 2) {
                        Paragraph ($LocalizedData.ParagraphSummaryBrief -f $vCenterServerName)
                    } else {
                        Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                    }
                    BlankLine
                    # Gather basic vCenter Server Information
                    $vCenterServerInfo = [PSCustomObject]@{
                        $LocalizedData.vCenterServer = $vCenterServerName
                        $LocalizedData.IPAddress = ($vCenterAdvSettings | Where-Object { $_.name -like 'VirtualCenter.AutoManagedIPV4' }).Value
                        $LocalizedData.Version = $vCenter.Version
                        $LocalizedData.Build = $vCenter.Build
                    }
                    #region vCenter Server Summary & Advanced Summary
                    if ($InfoLevel.vCenter -le 2) {
                        $TableParams = @{
                            Name = ($LocalizedData.TablevCenterSummary -f $vCenterServerName)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterServerInfo | Table @TableParams

                        #region Resource Summary
                        Section -Style Heading3 $LocalizedData.ResourceSummary {
                        $totalCpuMhz    = ($VMHosts | Measure-Object -Property CpuTotalMhz -Sum).Sum
                        $usedCpuMhz     = ($VMHosts | Measure-Object -Property CpuUsageMhz -Sum).Sum
                        $freeCpuMhz     = $totalCpuMhz - $usedCpuMhz
                        $totalCpuGHz    = [Math]::Round($totalCpuMhz / 1000, 2)
                        $usedCpuGHz     = [Math]::Round($usedCpuMhz / 1000, 2)
                        $freeCpuGHz     = [Math]::Round($freeCpuMhz / 1000, 2)

                        $totalMemGB     = ($VMHosts | Measure-Object -Property MemoryTotalGB -Sum).Sum
                        $usedMemGB      = ($VMHosts | Measure-Object -Property MemoryUsageGB -Sum).Sum
                        $freeMemGB      = $totalMemGB - $usedMemGB
                        $totalMem       = Convert-DataSize -Size $totalMemGB -InputUnit GB
                        $usedMem        = Convert-DataSize -Size $usedMemGB -InputUnit GB
                        $freeMem        = Convert-DataSize -Size $freeMemGB -InputUnit GB

                        $totalStorageGB = ($Datastores | Measure-Object -Property CapacityGB -Sum).Sum
                        $freeStorageGB  = ($Datastores | Measure-Object -Property FreeSpaceGB -Sum).Sum
                        $usedStorageGB  = $totalStorageGB - $freeStorageGB
                        $totalStorage   = Convert-DataSize -Size $totalStorageGB -InputUnit GB
                        $usedStorage    = Convert-DataSize -Size $usedStorageGB -InputUnit GB
                        $freeStorage    = Convert-DataSize -Size $freeStorageGB -InputUnit GB

                        $vCenterResourceSummary = @(
                            [PSCustomObject]@{
                                $LocalizedData.SummaryResource = $LocalizedData.CPU
                                $LocalizedData.Free            = "$freeCpuGHz GHz"
                                $LocalizedData.Used            = "$usedCpuGHz GHz"
                                $LocalizedData.Total           = "$totalCpuGHz GHz"
                            }
                            [PSCustomObject]@{
                                $LocalizedData.SummaryResource = $LocalizedData.Memory
                                $LocalizedData.Free            = $freeMem
                                $LocalizedData.Used            = $usedMem
                                $LocalizedData.Total           = $totalMem
                            }
                            [PSCustomObject]@{
                                $LocalizedData.SummaryResource = $LocalizedData.Storage
                                $LocalizedData.Free            = $freeStorage
                                $LocalizedData.Used            = $usedStorage
                                $LocalizedData.Total           = $totalStorage
                            }
                        )
                        $TableParams = @{
                            Name         = ($LocalizedData.TablevCenterResourceSummary -f $vCenterServerName)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterResourceSummary | Table @TableParams
                        } # end Section ResourceSummary

                        Section -Style Heading3 $LocalizedData.Infrastructure {
                        $vCenterInfrastructureSummary = [PSCustomObject]@{
                            $LocalizedData.Datacenters = (Get-Datacenter -Server $vCenter).Count
                            $LocalizedData.Clusters    = $Clusters.Count
                            $LocalizedData.Networks    = $VDSwitches.Count
                            $LocalizedData.Datastores  = $Datastores.Count
                        }
                        $TableParams = @{
                            Name         = ($LocalizedData.TablevCenterInfrastructureSummary -f $vCenterServerName)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterInfrastructureSummary | Table @TableParams
                        } # end Section Infrastructure

                        Section -Style Heading3 $LocalizedData.Hosts {
                        $hostsConnected    = ($VMHosts | Where-Object { $_.ConnectionState -eq 'Connected' }).Count
                        $hostsDisconnected = ($VMHosts | Where-Object { $_.ConnectionState -eq 'Disconnected' }).Count
                        $hostsMaintenance  = ($VMHosts | Where-Object { $_.ConnectionState -eq 'Maintenance' }).Count
                        $vCenterHostSummary = [PSCustomObject]@{
                            $LocalizedData.Connected    = $hostsConnected
                            $LocalizedData.Disconnected = $hostsDisconnected
                            $LocalizedData.Maintenance  = $hostsMaintenance
                            $LocalizedData.Total        = $hostsConnected + $hostsDisconnected + $hostsMaintenance
                        }
                        $TableParams = @{
                            Name         = ($LocalizedData.TablevCenterHostSummary -f $vCenterServerName)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterHostSummary | Table @TableParams
                        } # end Section Hosts

                        Section -Style Heading3 $LocalizedData.VirtualMachines {
                        $vmPoweredOn  = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                        $vmPoweredOff = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count
                        $vmSuspended  = ($VMs | Where-Object { $_.PowerState -eq 'Suspended' }).Count
                        $vCenterVMSummary = [PSCustomObject]@{
                            $LocalizedData.PoweredOn  = $vmPoweredOn
                            $LocalizedData.PoweredOff = $vmPoweredOff
                            $LocalizedData.Suspended  = $vmSuspended
                            $LocalizedData.Total      = $vmPoweredOn + $vmPoweredOff + $vmSuspended
                        }
                        $TableParams = @{
                            Name         = ($LocalizedData.TablevCenterVMSummary -f $vCenterServerName)
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterVMSummary | Table @TableParams
                        } # end Section VirtualMachines
                        #endregion Resource Summary
                    }
                    #endregion vCenter Server Summary & Advanced Summary

                    #region vCenter Server Detailed Information
                    if ($InfoLevel.vCenter -ge 3) {
                        $MemberProps = @{
                            'InputObject' = $vCenterServerInfo
                            'MemberType' = 'NoteProperty'
                        }
                        #region vCenter Server Detail
                        if ($UserPrivileges -contains 'Global.Licenses') {
                            try {
                                $vCenterLicense = Get-License -vCenter $vCenter
                                Add-Member @MemberProps -Name $LocalizedData.Product           -Value $vCenterLicense.Product
                                Add-Member @MemberProps -Name $LocalizedData.LicenseKey        -Value $vCenterLicense.LicenseKey
                                Add-Member @MemberProps -Name $LocalizedData.LicenseExpiration -Value $vCenterLicense.Expiration
                            } catch {
                                Write-PScriboMessage -IsWarning $LocalizedData.InsufficientPrivLicense
                            }
                        } else {
                            Write-PScriboMessage -Message $LocalizedData.InsufficientPrivLicense
                        }

                        Add-Member @MemberProps -Name $LocalizedData.InstanceID -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'instance.id' }).Value

                        if ($vCenter.Version -ge 6) {
                            Add-Member @MemberProps -Name $LocalizedData.HTTPPort  -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpport' }).Value
                            Add-Member @MemberProps -Name $LocalizedData.HTTPSPort -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpsport' }).Value
                            Add-Member @MemberProps -Name $LocalizedData.PSC       -Value ((($vCenterAdvSettings).Where{ $_.name -eq 'config.vpxd.sso.admin.uri' }).Value).Split('/')[2]
                        }
                        if ($VumServer.Name) {
                            Add-Member @MemberProps -Name $LocalizedData.UpdateManagerServer -Value $VumServer.Name
                        }
                        if ($SrmServer.Name) {
                            Add-Member @MemberProps -Name $LocalizedData.SRMServer -Value $SrmServer.Name
                        }
                        if ($NsxtServer.Name) {
                            Add-Member @MemberProps -Name $LocalizedData.NSXTServer -Value $NsxtServer.Name
                        }
                        if ($VxRailMgr.Name) {
                            Add-Member @MemberProps -Name $LocalizedData.VxRailServer -Value $VxRailMgr.Name
                        }
                        if ($Healthcheck.vCenter.Licensing) {
                            $vCenterServerInfo | Where-Object { $_.$($LocalizedData.Product) -like '*Evaluation*' } | Set-Style -Style Warning  -Property $LocalizedData.Product
                            $vCenterServerInfo | Where-Object { $null -eq $_.$($LocalizedData.Product) }           | Set-Style -Style Warning  -Property $LocalizedData.Product
                            $vCenterServerInfo | Where-Object { $_.$($LocalizedData.LicenseKey) -like '*-00000-00000' } | Set-Style -Style Warning  -Property $LocalizedData.LicenseKey
                            $vCenterServerInfo | Where-Object { $_.$($LocalizedData.LicenseExpiration) -eq 'Expired' } | Set-Style -Style Critical -Property $LocalizedData.LicenseExpiration
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TablevCenterConfig -f $vCenterServerName)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $vCenterServerInfo | Table @TableParams
                        #endregion vCenter Server Detail

                        #region vCenter Server Database Settings
                        Section -Style Heading3 $LocalizedData.DatabaseSettings {
                            $vCenterDbInfo = [PSCustomObject]@{
                                $LocalizedData.DatabaseType = $TextInfo.ToTitleCase(($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dbtype' }).Value)
                                $LocalizedData.DataSourceName = ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dsn' }).Value
                                $LocalizedData.MaxDBConnection = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.MaxDBConnection' }).Value
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableDatabaseSettings -f $vCenterServerName)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $vCenterDbInfo | Table @TableParams
                        }
                        #endregion vCenter Server Database Settings

                        #region vCenter Server Mail Settings
                        Section -Style Heading3 $LocalizedData.MailSettings {
                            $vCenterMailInfo = [PSCustomObject]@{
                                $LocalizedData.SMTPServer = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.server' }).Value
                                $LocalizedData.SMTPPort = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.port' }).Value
                                $LocalizedData.MailSender = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.sender' }).Value
                            }
                            if ($Healthcheck.vCenter.Mail) {
                                $vCenterMailInfo | Where-Object { !($_.$($LocalizedData.SMTPServer)) } | Set-Style -Style Critical -Property $LocalizedData.SMTPServer
                                $vCenterMailInfo | Where-Object { !($_.$($LocalizedData.SMTPPort)) }   | Set-Style -Style Critical -Property $LocalizedData.SMTPPort
                                $vCenterMailInfo | Where-Object { !($_.$($LocalizedData.MailSender)) } | Set-Style -Style Critical -Property $LocalizedData.MailSender
                            }
                            $TableParams = @{
                                Name = ($LocalizedData.TableMailSettings -f $vCenterServerName)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $vCenterMailInfo | Table @TableParams
                        }
                        #endregion vCenter Server Mail Settings

                        #region vCenter Server Backup
                        Section -Style Heading3 $LocalizedData.BackupSettings {
                            if (-not $vcApiUri) {
                                Paragraph $LocalizedData.BackupApiNotAvailable
                            } else {
                                #region Backup Schedule
                                $BackupSchedules = $null
                                try {
                                    $BackupSchedules = Invoke-RestMethod -Uri "$vcApiUri/appliance/recovery/backup/schedules" -Method Get -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
                                } catch {
                                    Write-PScriboMessage -IsWarning ($LocalizedData.BackupApiError -f $_.Exception.Message)
                                }
                                Section -Style Heading4 $LocalizedData.BackupSchedule {
                                    if ($BackupSchedules -and $BackupSchedules.PSObject.Properties.Name.Count -gt 0) {
                                        $ApplianceTimezone = $null
                                        try {
                                            $ApplianceTimezone = Invoke-RestMethod -Uri "$vcApiUri/appliance/system/time/timezone" -Method Get -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
                                        } catch {}
                                        $BackupScheduleInfo = foreach ($schedId in $BackupSchedules.PSObject.Properties.Name) {
                                            $sched = $BackupSchedules.$schedId
                                            $recurrence = if ($sched.recurrence_info) {
                                                $h = [int]$sched.recurrence_info.hour % 12
                                                if ($h -eq 0) { $h = 12 }
                                                $ap = if ([int]$sched.recurrence_info.hour -ge 12) { 'P.M.' } else { 'A.M.' }
                                                $timeStr = '{0}:{1:D2} {2}' -f $h, [int]$sched.recurrence_info.minute, $ap
                                                $dayStr = if ($sched.recurrence_info.days -and $sched.recurrence_info.days.Count -gt 0) {
                                                    ($sched.recurrence_info.days | ForEach-Object { $TextInfo.ToTitleCase($_.ToLower()) }) -join ', '
                                                } else { $LocalizedData.BackupDaily }
                                                $tz = if ($ApplianceTimezone) { " $ApplianceTimezone" } else { '' }
                                                "$dayStr, $timeStr$tz"
                                            } else { '--' }
                                            $partsFormatted = ($sched.parts | ForEach-Object {
                                                switch ($_) {
                                                    'supervisors' { $LocalizedData.BackupPartSeat }
                                                    'seat'        { $LocalizedData.BackupPartSeat }
                                                    'common'      { $LocalizedData.BackupPartCommon }
                                                    'stats'       { $LocalizedData.BackupPartStats }
                                                    default       { $_ }
                                                }
                                            }) -join ', '
                                            [PSCustomObject]@{
                                                $LocalizedData.BackupEnabled        = if ($sched.enable) { $LocalizedData.BackupActivated } else { $LocalizedData.BackupDeactivated }
                                                $LocalizedData.BackupRecurrence     = $recurrence
                                                $LocalizedData.BackupLocation       = $sched.location
                                                $LocalizedData.BackupParts          = $partsFormatted
                                                $LocalizedData.BackupRetentionCount = $sched.retention_info.max_count
                                            }
                                        }
                                        if ($Healthcheck.vCenter.Backup) {
                                            $BackupScheduleInfo | Where-Object { $_.$($LocalizedData.BackupEnabled) -eq $LocalizedData.BackupDeactivated } | Set-Style -Style Warning -Property $LocalizedData.BackupEnabled
                                        }
                                        $TableParams = @{
                                            Name         = ($LocalizedData.TableBackupSchedule -f $vCenterServerName)
                                            List         = $true
                                            ColumnWidths = 40, 60
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $BackupScheduleInfo | Table @TableParams
                                    } else {
                                        Paragraph $LocalizedData.BackupNotConfigured
                                    }
                                }
                                #endregion Backup Schedule

                                #region Backup Job History
                                $BackupJobRecords = $null
                                try {
                                    $jobDetailsResponse = Invoke-RestMethod -Uri "$vcApiUri/appliance/recovery/backup/job/details" -Method Get -Headers $vcApiHeaders -SkipCertificateCheck -ErrorAction Stop
                                    if ($jobDetailsResponse -and $jobDetailsResponse.PSObject.Properties.Name.Count -gt 0) {
                                        $BackupJobRecords = $jobDetailsResponse.PSObject.Properties |
                                            Sort-Object Name -Descending | Select-Object -First 10 | ForEach-Object {
                                                $job = $_.Value
                                                $jobDuration = if ($job.start_time -and $job.end_time) { ([datetime]$job.end_time - [datetime]$job.start_time).TotalSeconds } elseif ($job.duration) { $job.duration } else { $null }
                                                [PSCustomObject]@{
                                                    Location  = $job.location
                                                    Type      = $job.type
                                                    State     = $job.state ?? $job.status
                                                    Size      = $job.size
                                                    Duration  = $jobDuration
                                                    Timestamp = $job.end_time
                                                }
                                            }
                                    }
                                } catch {
                                    Write-PScriboMessage -IsWarning ($LocalizedData.BackupApiError -f $_.Exception.Message)
                                }
                                Section -Style Heading4 $LocalizedData.BackupJobHistory {
                                    if ($BackupJobRecords -and $BackupJobRecords.Count -gt 0) {
                                        $BackupJobInfo = foreach ($record in $BackupJobRecords) {
                                            $duration = if ($record.Duration) { $ts = [timespan]::FromSeconds($record.Duration); '{0:D2}:{1:D2}:{2:D2}' -f $ts.Hours, $ts.Minutes, $ts.Seconds } else { '--' }
                                            $dataTransferred = if ($record.Size -gt 0) { '{0:N2} GB' -f ($record.Size / 1GB) } else { '--' }
                                            [PSCustomObject]@{
                                                $LocalizedData.BackupJobLocation        = if ($record.Location) { $record.Location } else { '--' }
                                                $LocalizedData.BackupJobType            = switch ($record.Type) {
                                                    'SCHEDULED' { $LocalizedData.BackupJobScheduled }
                                                    default     { if ($record.Type) { $TextInfo.ToTitleCase($record.Type.ToString().ToLower()) } else { '--' } }
                                                }
                                                $LocalizedData.BackupJobStatus          = switch ($record.State) {
                                                    'SUCCEEDED' { $LocalizedData.BackupJobComplete }
                                                    default     { if ($record.State) { $TextInfo.ToTitleCase($record.State.ToString().ToLower()) } else { '--' } }
                                                }
                                                $LocalizedData.BackupJobDataTransferred = $dataTransferred
                                                $LocalizedData.BackupJobDuration        = $duration
                                                $LocalizedData.BackupJobEndTime         = if ($record.Timestamp) { ([datetime]$record.Timestamp).ToLocalTime().ToString() } else { '--' }
                                            }
                                        }
                                        if ($Healthcheck.vCenter.Backup) {
                                            $BackupJobInfo | Where-Object { $_.$($LocalizedData.BackupJobStatus) -eq 'Failed' } | Set-Style -Style Critical -Property $LocalizedData.BackupJobStatus
                                        }
                                        $TableParams = @{
                                            Name         = ($LocalizedData.TableBackupJobHistory -f $vCenterServerName)
                                            ColumnWidths = 28, 13, 13, 13, 13, 20
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $BackupJobInfo | Table @TableParams
                                    } else {
                                        Paragraph $LocalizedData.BackupNoJobs
                                    }
                                }
                                #endregion Backup Job History
                            }
                        }
                        #endregion vCenter Server Backup

                        #region vCenter Server Historical Statistics
                        Section -Style Heading3 $LocalizedData.HistoricalStatistics {
                            $vCenterHistoricalStats = Get-vCenterStats | Select-Object @{L = $LocalizedData.IntervalDuration; E = { $_.IntervalDuration } },
                            @{L = $LocalizedData.IntervalEnabled; E = { $_.IntervalEnabled } },
                            @{L = $LocalizedData.SaveDuration; E = { $_.SaveDuration } },
                            @{L = $LocalizedData.StatisticsLevel; E = { $_.StatsLevel } } -Unique
                            $TableParams = @{
                                Name = ($LocalizedData.TableHistoricalStatistics -f $vCenterServerName)
                                ColumnWidths = 25, 25, 25, 25
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $vCenterHistoricalStats | Table @TableParams
                        }
                        #endregion vCenter Server Historical Statistics

                        #region vCenter Server Licensing
                        if ($UserPrivileges -contains 'Global.Licenses') {
                            Section -Style Heading3 $LocalizedData.Licensing {
                                try {
                                    $Licenses = Get-License -Licenses | Select-Object @{L = $LocalizedData.Product; E = { $_.Product } },
                                    @{L = $LocalizedData.LicenseKey; E = { ($_.LicenseKey) } },
                                    @{L = $LocalizedData.Total; E = { $_.Total } },
                                    @{L = $LocalizedData.Used; E = { $_.Used } },
                                    @{L = $LocalizedData.Available; E = { ($_.total) - ($_.Used) } },
                                    @{L = $LocalizedData.Expiration; E = { $_.Expiration } } -Unique
                                    if ($Healthcheck.vCenter.Licensing) {
                                        $Licenses | Where-Object { $_.$($LocalizedData.Product) -eq 'Product Evaluation' } | Set-Style -Style Warning
                                        $Licenses | Where-Object { $_.$($LocalizedData.Expiration) -eq 'Expired' } | Set-Style -Style Critical
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableLicensing -f $vCenterServerName)
                                        ColumnWidths = 25, 25, 12, 12, 12, 14
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $Licenses | Sort-Object $LocalizedData.Product, $LocalizedData.LicenseKey | Table @TableParams
                                } catch {
                                    Write-PScriboMessage -IsWarning $LocalizedData.InsufficientPrivLicense
                                }
                            }
                        } else {
                            Write-PScriboMessage -Message $LocalizedData.InsufficientPrivLicense
                        }
                        #endregion vCenter Server Licensing

                        #region vCenter Server Certificate
                        if ($vCenter.Version -ge 6) {
                            Section -Style Heading3 $LocalizedData.Certificate {
                                try {
                                    $SslCallback = [System.Net.Security.RemoteCertificateValidationCallback]{
                                        param($sender, $cert, $chain, $errors) $true
                                    }
                                    $TcpClient = New-Object -TypeName System.Net.Sockets.TcpClient -ArgumentList ($vCenterServerName, 443)
                                    $SslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList (
                                        $TcpClient.GetStream(), $false, $SslCallback
                                    )
                                    $SslStream.AuthenticateAsClient($vCenterServerName)
                                    $VIMachineCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
                                    $SslStream.Dispose()
                                    $TcpClient.Dispose()
                                    $SoftThresholdDays = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.softThreshold' }).Value
                                    $HardThresholdDays = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.hardThreshold' }).Value
                                    $DaysRemaining = ($VIMachineCert.NotAfter - (Get-Date)).Days
                                    $CertificateStatus = if ($DaysRemaining -le 0) {
                                        'EXPIRED'
                                    } elseif ($null -ne $HardThresholdDays -and $DaysRemaining -le [int]$HardThresholdDays) {
                                        'EXPIRING'
                                    } elseif ($null -ne $SoftThresholdDays -and $DaysRemaining -le [int]$SoftThresholdDays) {
                                        'EXPIRING_SOON'
                                    } else {
                                        'VALID'
                                    }
                                    $VcenterCertMgmt = [PSCustomObject]@{
                                        $LocalizedData.Subject       = $VIMachineCert.Subject
                                        $LocalizedData.Issuer        = $VIMachineCert.Issuer
                                        $LocalizedData.ValidFrom     = $VIMachineCert.NotBefore.ToString()
                                        $LocalizedData.ValidTo       = $VIMachineCert.NotAfter.ToString()
                                        $LocalizedData.Thumbprint    = $VIMachineCert.Thumbprint
                                        $LocalizedData.CertStatus    = $CertificateStatus
                                        $LocalizedData.Mode          = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.mode' }).Value
                                        $LocalizedData.SoftThreshold = "$(($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.softThreshold' }).Value) days"
                                        $LocalizedData.HardThreshold = "$(($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.hardThreshold' }).Value) days"
                                        $LocalizedData.MinutesBefore = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.minutesBefore' }).Value
                                        $LocalizedData.PollInterval  = "$(($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.pollIntervalDays' }).Value) days"
                                    }
                                    if ($Healthcheck.vCenter.Certificate) {
                                        $VcenterCertMgmt | Where-Object { $_.$($LocalizedData.CertStatus) -in @('EXPIRED', 'EXPIRING') }      | Set-Style -Style Critical -Property $LocalizedData.CertStatus
                                        $VcenterCertMgmt | Where-Object { $_.$($LocalizedData.CertStatus) -eq 'EXPIRING_SOON' }               | Set-Style -Style Warning  -Property $LocalizedData.CertStatus
                                    }
                                    $TableParams = @{
                                        Name         = ($LocalizedData.TableCertificate -f $vCenterServerName)
                                        List         = $true
                                        ColumnWidths = 40, 60
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VcenterCertMgmt | Table @TableParams
                                } catch {
                                    Write-PScriboMessage -IsWarning ($LocalizedData.InsufficientPrivCertificate -f $_.Exception.Message)
                                }
                            }
                        }
                        #endregion vCenter Server Certificate

                        #region vCenter Server Roles
                        if ($Options.ShowRoles) {
                        Section -Style Heading3 $LocalizedData.Roles {
                            $VIRoles = Get-VIRole -Server $vCenter | Where-Object { $null -ne $_.PrivilegeList } | Sort-Object Name
                            $VIRoleInfo = foreach ($VIRole in $VIRoles) {
                                [PSCustomObject]@{
                                    $LocalizedData.Role = $VIRole.Name
                                    $LocalizedData.SystemRole = if ($VIRole.IsSystem) { $LocalizedData.Yes } else { $LocalizedData.No }
                                    $LocalizedData.PrivilegeList = ($VIRole.PrivilegeList).Replace(".", " > ") | Select-Object -Unique
                                }
                            }
                            if ($InfoLevel.vCenter -ge 4) {
                                $VIRoleInfo | ForEach-Object {
                                    Section -Style NOTOCHeading5 -ExcludeFromTOC $_.$($LocalizedData.Role) {
                                        $TableParams = @{
                                            Name = ($LocalizedData.TableRole -f $_.$($LocalizedData.Role), $vCenterServerName)
                                            ColumnWidths = 35, 15, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $_ | Table @TableParams
                                    }
                                }
                            } else {
                                $TableParams = @{
                                    Name = ($LocalizedData.TableRoles -f $vCenterServerName)
                                    Columns = $LocalizedData.Role, $LocalizedData.SystemRole
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VIRoleInfo | Table @TableParams
                            }
                        }
                        } # end if ShowRoles
                        #endregion vCenter Server Roles

                        #region vCenter Server Tags
                        if ($Options.ShowTags -and $Tags) {
                            Section -Style Heading3 $LocalizedData.Tags {
                                $TagInfo = foreach ($Tag in $Tags) {
                                    [PSCustomObject]@{
                                        $LocalizedData.TagName = $Tag.Name
                                        $LocalizedData.TagDescription = if ($Tag.Description) { $Tag.Description } else { $LocalizedData.None }
                                        $LocalizedData.TagCategory = if ($Tag.Category) { $Tag.Category } else { $LocalizedData.None }
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableTags -f $vCenterServerName)
                                    ColumnWidths = 30, 40, 30
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $TagInfo | Table @TableParams
                            }
                        }
                        #endregion vCenter Server Tags

                        #region vCenter Server Tag Categories
                        if ($Options.ShowTags -and $TagCategories) {
                            Section -Style Heading3 $LocalizedData.TagCategories {
                                $TagCategoryInfo = foreach ($TagCategory in $TagCategories) {
                                    [PSCustomObject]@{
                                        $LocalizedData.TagCategory = if ($TagCategory.Name) { $TagCategory.Name } else { $LocalizedData.None }
                                        $LocalizedData.TagDescription = if ($TagCategory.Description) { $TagCategory.Description } else { $LocalizedData.None }
                                        $LocalizedData.TagCardinality = if ($TagCategory.Cardinality) { $TagCategory.Cardinality } else { $LocalizedData.None }
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableTagCategories -f $vCenterServerName)
                                    ColumnWidths = 30, 40, 30
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $TagCategoryInfo | Table @TableParams
                            }
                        }
                        #endregion vCenter Server Tag Categories

                        #region vCenter Server Tag Assignments
                        if ($Options.ShowTags -and $TagAssignments) {
                            Section -Style Heading3 $LocalizedData.TagAssignments {
                                $TagAssignmentInfo = foreach ($TagAssignment in $TagAssignments) {
                                    [PSCustomObject]@{
                                        $LocalizedData.TagEntity = $TagAssignment.Entity.Name
                                        $LocalizedData.TagName = $TagAssignment.Tag.Name
                                        $LocalizedData.TagCategory = $TagAssignment.Tag.Category
                                    }
                                }
                                $TableParams = @{
                                    Name = ($LocalizedData.TableTagAssignments -f $vCenterServerName)
                                    ColumnWidths = 30, 40, 30
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $TagAssignmentInfo | Sort-Object $LocalizedData.TagEntity | Table @TableParams
                            }
                        }
                        #endregion vCenter Server Tag Assignments

                        #region VM Storage Policies
                        if ($UserPrivileges -contains 'StorageProfile.View') {
                            $SpbmStoragePolicies = Get-SpbmStoragePolicy | Sort-Object Name
                            if ($SpbmStoragePolicies) {
                                Section -Style Heading3 $LocalizedData.VMStoragePolicies {
                                    $VmStoragePolicies = foreach ($SpbmStoragePolicy in $SpbmStoragePolicies) {
                                        [PSCustomObject]@{
                                            $LocalizedData.StoragePolicy = $SpbmStoragePolicy.Name
                                            $LocalizedData.Description = $SpbmStoragePolicy.Description
                                        }
                                    }
                                    $TableParams = @{
                                        Name = ($LocalizedData.TableVMStoragePolicies -f $vCenterServerName)
                                        ColumnWidths = 50, 50
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VmStoragePolicies | Table @TableParams
                                }
                            }
                        } else {
                            Write-PScriboMessage -Message $LocalizedData.InsufficientPrivStoragePolicy
                        }
                        #endregion VM Storage Policies

                        #region Content Libraries
                        $ContentLibraries = $null
                        try {
                            $ContentLibraries = Get-ContentLibrary -Server $vCenter -ErrorAction Stop | Sort-Object Name
                        } catch {
                            Write-PScriboMessage -IsWarning ($LocalizedData.ContentLibraryError -f $_.Exception.Message)
                        }
                        if ($ContentLibraries) {
                            Write-PScriboMessage -Message $LocalizedData.CollectingContentLibrary
                            Section -Style Heading3 $LocalizedData.ContentLibraries {
                                if ($InfoLevel.vCenter -eq 3) {
                                    $LibrarySummaryInfo = foreach ($Library in $ContentLibraries) {
                                        $LibItems = $null
                                        try { $LibItems = Get-ContentLibraryItem -ContentLibrary $Library -ErrorAction Stop } catch {}
                                        [PSCustomObject]@{
                                            $LocalizedData.ContentLibrary = $Library.Name
                                            $LocalizedData.LibraryType    = if ($Library.Type -eq 'Local') { $LocalizedData.LibraryLocal } else { $LocalizedData.LibrarySubscribed }
                                            $LocalizedData.Datastore      = if ($Library.Datastore) { $Library.Datastore.Name } else { '--' }
                                            $LocalizedData.ItemCount      = if ($LibItems) { $LibItems.Count } else { 0 }
                                            $LocalizedData.Description    = if ($Library.Description) { $Library.Description } else { $LocalizedData.None }
                                        }
                                    }
                                    if ($Healthcheck.vCenter.ContentLibrary) {
                                        foreach ($Library in $ContentLibraries) {
                                            if ($Library.Type -ne 'Local' -and -not $Library.AutomaticSync) {
                                                $LibrarySummaryInfo | Where-Object { $_.$($LocalizedData.ContentLibrary) -eq $Library.Name } |
                                                    Set-Style -Style Warning -Property $LocalizedData.LibraryType
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name         = ($LocalizedData.TableContentLibraries -f $vCenterServerName)
                                        ColumnWidths = 25, 15, 20, 10, 30
                                    }
                                    if ($Report.ShowTableCaptions) { $TableParams['Caption'] = "- $($TableParams.Name)" }
                                    $LibrarySummaryInfo | Table @TableParams
                                }
                                if ($InfoLevel.vCenter -ge 4) {
                                    foreach ($Library in $ContentLibraries) {
                                        Section -Style Heading4 $Library.Name {
                                            $LibItems = $null
                                            try {
                                                $LibItems = Get-ContentLibraryItem -ContentLibrary $Library -ErrorAction Stop | Sort-Object Name
                                            } catch {
                                                Write-PScriboMessage -IsWarning ($LocalizedData.ContentLibraryItemError -f $Library.Name, $_.Exception.Message)
                                            }
                                            $LibDetailObj = [PSCustomObject]@{
                                                $LocalizedData.ContentLibrary = $Library.Name
                                                $LocalizedData.LibraryType    = if ($Library.Type -eq 'Local') { $LocalizedData.LibraryLocal } else { $LocalizedData.LibrarySubscribed }
                                                $LocalizedData.Datastore      = if ($Library.Datastore) { $Library.Datastore.Name } else { '--' }
                                                $LocalizedData.ItemCount      = if ($LibItems) { $LibItems.Count } else { 0 }
                                                $LocalizedData.Description    = if ($Library.Description) { $Library.Description } else { $LocalizedData.None }
                                                $LocalizedData.CreationTime   = if ($Library.CreateDate) { $Library.CreateDate.ToString() } else { '--' }
                                                $LocalizedData.LastModified   = if ($Library.UpdateDate) { $Library.UpdateDate.ToString() } else { '--' }
                                            }
                                            if ($Library.Type -ne 'Local') {
                                                $MemberProps = @{ InputObject = $LibDetailObj; MemberType = 'NoteProperty' }
                                                Add-Member @MemberProps -Name $LocalizedData.SubscriptionUrl -Value $(if ($Library.SubscriptionUri) { $Library.SubscriptionUri } else { '--' })
                                                Add-Member @MemberProps -Name $LocalizedData.AutomaticSync   -Value $(if ($Library.AutomaticSync) { $LocalizedData.Enabled } else { $LocalizedData.Disabled })
                                                Add-Member @MemberProps -Name $LocalizedData.OnDemandSync    -Value $(if ($Library.DownloadContentOnDemand) { $LocalizedData.Enabled } else { $LocalizedData.Disabled })
                                            }
                                            if ($Healthcheck.vCenter.ContentLibrary) {
                                                $LibDetailObj | Where-Object { $_.$($LocalizedData.AutomaticSync) -eq $LocalizedData.Disabled } |
                                                    Set-Style -Style Warning -Property $LocalizedData.AutomaticSync
                                            }
                                            $TableParams = @{
                                                Name         = ($LocalizedData.TableContentLibrary -f $Library.Name, $vCenterServerName)
                                                List         = $true
                                                ColumnWidths = 40, 60
                                            }
                                            if ($Report.ShowTableCaptions) { $TableParams['Caption'] = "- $($TableParams.Name)" }
                                            $LibDetailObj | Table @TableParams

                                            if ($LibItems) {
                                                $ItemsInfo = foreach ($Item in $LibItems) {
                                                    $itemSize = if ($Item.SizeGB -gt 0) { Convert-DataSize -Size $Item.SizeGB -InputUnit GB } else { '--' }
                                                    [PSCustomObject]@{
                                                        $LocalizedData.ItemName     = $Item.Name
                                                        $LocalizedData.ContentType  = if ($Item.ItemType) { $Item.ItemType } else { '--' }
                                                        $LocalizedData.ItemSize     = $itemSize
                                                        $LocalizedData.Description  = if ($Item.Description) { $Item.Description } else { $LocalizedData.None }
                                                        $LocalizedData.CreationTime = if ($Item.CreationTime) { $Item.CreationTime.ToString() } else { '--' }
                                                        $LocalizedData.LastModified = if ($Item.LastWriteTime) { $Item.LastWriteTime.ToString() } else { '--' }
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name         = ($LocalizedData.TableLibraryItems -f $Library.Name)
                                                    ColumnWidths = 25, 13, 13, 21, 14, 14
                                                }
                                                if ($Report.ShowTableCaptions) { $TableParams['Caption'] = "- $($TableParams.Name)" }
                                                $ItemsInfo | Table @TableParams
                                            } else {
                                                Paragraph $LocalizedData.ContentLibraryNoItems
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        #endregion Content Libraries
                    }
                    #endregion vCenter Server Detailed Information

                    #region vCenter Server Advanced Detail Information
                    if ($InfoLevel.vCenter -ge 4) {
                        #region vCenter Alarms
                        if ($Options.ShowAlarms) {
                        Section -Style Heading3 $LocalizedData.Alarms {
                            $Alarms = Get-AlarmDefinition -PipelineVariable alarm | ForEach-Object -Process {
                                Get-AlarmAction -AlarmDefinition $_ -PipelineVariable action | ForEach-Object -Process {
                                    Get-AlarmActionTrigger -AlarmAction $_ |
                                    Select-Object @{N = $LocalizedData.Alarm; E = { $alarm.Name } },
                                    @{N = $LocalizedData.AlarmDescription; E = { $alarm.Description } },
                                    @{N = $LocalizedData.AlarmEnabled; E = { if ($alarm.Enabled) { $LocalizedData.Enabled } else { $LocalizedData.Disabled } } },
                                    @{N = $LocalizedData.TagEntityType; E = { $alarm.Entity.Type } },
                                    @{N = $LocalizedData.AlarmTriggered; E = {
                                            "{0}:{1}->{2} (Repeat={3})" -f $action.ActionType,
                                            $_.StartStatus,
                                            $_.EndStatus,
                                            $_.Repeat
                                        }
                                    },
                                    @{N = $LocalizedData.AlarmAction; E = { switch ($action.ActionType) {
                                                'SendEmail' {
                                                    "To: $($action.To -join ', ') `
                                                    Cc: $($action.Cc -join ', ') `
                                                    Subject: $($action.Subject) `
                                                    Body: $($action.Body)"
                                                }
                                                'ExecuteScript' {
                                                    "$($action.ScriptFilePath)"
                                                }
                                                default { '--' }
                                            }
                                        }
                                    }
                                }
                            }
                            $Alarms = ($Alarms).Where{ $_.$($LocalizedData.Alarm) -ne "" } | Sort-Object $LocalizedData.Alarm, $LocalizedData.AlarmTriggered
                            if ($Healthcheck.vCenter.Alarms) {
                                $Alarms | Where-Object { $_.$($LocalizedData.AlarmEnabled) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.AlarmEnabled
                            }
                            if ($InfoLevel.vCenter -ge 5) {
                                foreach ($Alarm in $Alarms) {
                                    Section -Style NOTOCHeading5 -ExcludeFromTOC $Alarm.$($LocalizedData.Alarm) {
                                        $TableParams = @{
                                            Name = ($LocalizedData.TableAlarm -f $Alarm.$($LocalizedData.Alarm), $vCenterServerName)
                                            List = $true
                                            ColumnWidths = 25, 75
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $Alarm | Table @TableParams
                                    }
                                }
                            } else {
                                $TableParams = @{
                                    Name = ($LocalizedData.TableAlarms -f $vCenterServerName)
                                    Columns = $LocalizedData.Alarm, $LocalizedData.AlarmDescription, $LocalizedData.AlarmEnabled, $LocalizedData.TagEntityType, $LocalizedData.AlarmTriggered
                                    ColumnWidths = 20, 20, 20, 20, 20
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $Alarms | Table @TableParams
                            }
                        }
                        } # end if ShowAlarms
                        #endregion vCenter Alarms
                    }
                    #endregion vCenter Server Advanced Detail Information

                    #region vCenter Server Comprehensive Information
                    if ($InfoLevel.vCenter -ge 5) {
                        #region vCenter Advanced System Settings
                        Section -Style Heading3 $LocalizedData.AdvancedSystemSettings {
                            $TableParams = @{
                                Name = ($LocalizedData.TableAdvancedSystemSettings -f $vCenterServerName)
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $vCenterAdvSettings |
                            Select-Object @{L = $LocalizedData.Key; E = { $_.Name } },
                            @{L = $LocalizedData.Value; E = { $_.Value } } |
                            Sort-Object $LocalizedData.Key | Table @TableParams
                        }
                        #endregion vCenter Advanced System Settings
                    }
                    #endregion vCenter Server Comprehensive Information
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
