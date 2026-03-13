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
                    Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
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
                        #endregion vCenter Server Roles

                        #region vCenter Server Tags
                        if ($Tags) {
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
                        if ($TagCategories) {
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
                        if ($TagAssignments) {
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
                    }
                    #endregion vCenter Server Detailed Information

                    #region vCenter Server Advanced Detail Information
                    if ($InfoLevel.vCenter -ge 4) {
                        #region vCenter Alarms
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
