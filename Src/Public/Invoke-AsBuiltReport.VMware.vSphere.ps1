function Invoke-AsBuiltReport.VMware.vSphere {
    <#
    .SYNOPSIS
        PowerShell script to document the configuration of VMware vSphere infrastucture in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware vSphere infrastucture in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        1.3.3
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )

    # Check if the required version of VMware PowerCLI is installed
    Get-RequiredModule -Name 'VMware.PowerCLI' -Version '12.3'

    # Import Report Configuration
    $Report = $ReportConfig.Report
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options
    # Used to set values to TitleCase where required
    $TextInfo = (Get-Culture).TextInfo

    #region Script Body
    #---------------------------------------------------------------------------------------------#
    #                                         SCRIPT BODY                                         #
    #---------------------------------------------------------------------------------------------#
    # Connect to vCenter Server using supplied credentials
    foreach ($VIServer in $Target) {
        try {
            Write-PScriboMessage "Connecting to vCenter Server '$VIServer'."
            $vCenter = Connect-VIServer $VIServer -Credential $Credential -ErrorAction Stop
        } catch {
            Write-Error $_
        }

        #region Generate vSphere report
        if ($vCenter) {
            # Check logged in user has sufficient privileges to generate an As Built Report
            Write-PScriboMessage 'Checking vCenter user privileges.'
            Try {
                $UserPermission = Get-VIPermission | Where-Object {$_.Principal -eq $vCenter.User}
                $AuthMgr = Get-View $($vCenter.ExtensionData.Content.AuthorizationManager)
                $UserRole = $AuthMgr.RoleList | Where-Object {$_.Name -eq $($UserPermission.Role)}
            } Catch {
                Write-PScriboMessage 'Unable to obtain vCenter user privileges.'
            }

            # Create a lookup hashtable to quickly link VM MoRefs to Names
            # Exclude VMware Site Recovery Manager placeholder VMs
            Write-PScriboMessage 'Creating VM lookup hashtable.'
            $VMs = Get-VM -Server $vCenter | Where-Object {
                $_.ExtensionData.Config.ManagedBy.ExtensionKey -notlike 'com.vmware.vcDr*'
            } | Sort-Object Name
            $VMLookup = @{ }
            foreach ($VM in $VMs) {
                $VMLookup.($VM.Id) = $VM.Name
            }

            # Create a lookup hashtable to link Host MoRefs to Names
            # Exclude VMware HCX hosts and ESX/ESXi versions prior to vSphere 5.0 from VMHost lookup
            Write-PScriboMessage 'Creating VMHost lookup hashtable.'
            $VMHosts = Get-VMHost -Server $vCenter | Where-Object { $_.Model -notlike "*VMware Mobility Platform" -and $_.Version -gt 5 } | Sort-Object Name
            $VMHostLookup = @{ }
            foreach ($VMHost in $VMHosts) {
                $VMHostLookup.($VMHost.Id) = $VMHost.Name
            }

            # Create a lookup hashtable to link Datastore MoRefs to Names
            Write-PScriboMessage 'Creating Datastore lookup hashtable.'
            $Datastores = Get-Datastore -Server $vCenter | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
            $DatastoreLookup = @{ }
            foreach ($Datastore in $Datastores) {
                $DatastoreLookup.($Datastore.Id) = $Datastore.Name
            }

            # Create a lookup hashtable to link VDS Portgroups MoRefs to Names
            Write-PScriboMessage 'Creating VDPortGroup lookup hashtable.'
            $VDPortGroups = Get-VDPortgroup -Server $vCenter | Sort-Object Name
            $VDPortGroupLookup = @{ }
            foreach ($VDPortGroup in $VDPortGroups) {
                $VDPortGroupLookup.($VDPortGroup.Key) = $VDPortGroup.Name
            }

            # Create a lookup hashtable to link EVC Modes to Names
            Write-PScriboMessage 'Creating EVC lookup hashtable.'
            $SupportedEvcModes = $vCenter.ExtensionData.Capability.SupportedEVCMode
            $EvcModeLookup = @{ }
            foreach ($EvcMode in $SupportedEvcModes) {
                $EvcModeLookup.($EvcMode.Key) = $EvcMode.Label
            }

            $si = Get-View ServiceInstance -Server $vCenter
            $extMgr = Get-View -Id $si.Content.ExtensionManager -Server $vCenter

            #region VMware Update Manager Server Name
            Write-PScriboMessage 'Checking for VMware Update Manager Server.'
            $VumServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcIntegrity' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Type -eq 'SOAP' -and $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VMware Update Manager Server Name

            #region VxRail Manager Server Name
            Write-PScriboMessage 'Checking for VxRail Manager Server.'
            $VxRailMgr = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vxrail' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Type -eq 'HTTPS' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion VxRail Manager Server Name

            #region Site Recovery Manager Server Name
            Write-PScriboMessage 'Checking for VMware Site Recovery Manager Server.'
            $SrmServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.vcDr' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { $_.Company -eq 'VMware, Inc.' } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion Site Recovery Manager Server Name

            #region NSX-T Manager Server Name
            Write-PScriboMessage 'Checking for VMware NSX-T Manager Server.'
            $NsxtServer = $extMgr.ExtensionList | Where-Object { $_.Key -eq 'com.vmware.nsx.management.nsxt' } |
            Select-Object @{
                N = 'Name';
                E = { ($_.Server | Where-Object { ($_.Company -eq 'VMware') -and ($_.Type -eq 'VIP') } |
                        Select-Object -ExpandProperty Url).Split('/')[2].Split(':')[0] }
            }
            #endregion NSX-T Manager Server Name

            #region Tag Information
            $TagAssignments = Get-TagAssignment -Server $vCenter
            $Tags = Get-Tag -Server $vCenter | Sort-Object Name, Category
            $TagCategories = Get-TagCategory -Server $vCenter | Sort-Object Name | Select-Object Name, Description, Cardinality -Unique
            #endregion Tag Information

            #region vCenter Advanced Settings
            Write-PScriboMessage "Collecting $vCenter advanced settings."
            $vCenterAdvSettings = Get-AdvancedSetting -Entity $vCenter
            $vCenterServerName = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.FQDN' }).Value
            $vCenterServerName = $vCenterServerName.ToString().ToLower()
            #endregion vCenter Advanced Settings

            #region vCenter Server Heading1 Section
            Section -Style Heading1 $vCenterServerName {
                #region vCenter Server Section
                Write-PScriboMessage "vCenter InfoLevel set at $($InfoLevel.vCenter)."
                if ($InfoLevel.vCenter -ge 1) {
                    Section -Style Heading2 'vCenter Server' {
                        Paragraph "The following sections detail the configuration of vCenter Server $vCenterServerName."
                        BlankLine
                        # Gather basic vCenter Server Information
                        $vCenterServerInfo = [PSCustomObject]@{
                            'vCenter Server' = $vCenterServerName
                            'IP Address' = ($vCenterAdvSettings | Where-Object { $_.name -like 'VirtualCenter.AutoManagedIPV4' }).Value
                            'Version' = $vCenter.Version
                            'Build' = $vCenter.Build
                            'OS Type' = $vCenter.ExtensionData.Content.About.OsType
                        }
                        #region vCenter Server Summary & Advanced Summary
                        if ($InfoLevel.vCenter -le 2) {
                            $TableParams = @{
                                Name = "vCenter Server Summary - $vCenterServerName"
                                ColumnWidths = 20, 20, 20, 20, 20
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
                            if ($UserRole.Privilege -contains 'Global.Licenses') {
                                $vCenterLicense = Get-License -vCenter $vCenter
                                Add-Member @MemberProps -Name 'Product' -Value $vCenterLicense.Product
                                Add-Member @MemberProps -Name 'License Key' -Value $vCenterLicense.LicenseKey
                                Add-Member @MemberProps -Name 'License Expiration' -Value $vCenterLicense.Expiration
                            } else {
                                Write-PScriboMessage "Insufficient user privileges to report vCenter Server licensing. Please ensure the user account has the 'Global > Licenses' privilege assigned."
                            }

                            Add-Member @MemberProps -Name 'Instance ID' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'instance.id' }).Value

                            if ($vCenter.Version -ge 6) {
                                Add-Member @MemberProps -Name 'HTTP Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpport' }).Value
                                Add-Member @MemberProps -Name 'HTTPS Port' -Value ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.rhttpproxy.httpsport' }).Value
                                Add-Member @MemberProps -Name 'Platform Services Controller' -Value (($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.sso.admin.uri' }).Value -replace "^https://|/sso-adminserver/sdk/vsphere.local")
                            }
                            if ($VumServer.Name) {
                                Add-Member @MemberProps -Name 'Update Manager Server' -Value $VumServer.Name
                            }
                            if ($SrmServer.Name) {
                                Add-Member @MemberProps -Name 'Site Recovery Manager Server' -Value $SrmServer.Name
                            }
                            if ($NsxtServer.Name) {
                                Add-Member @MemberProps -Name 'NSX-T Manager Server' -Value $NsxtServer.Name
                            }
                            if ($VxRailMgr.Name) {
                                Add-Member @MemberProps -Name 'VxRail Manager Server' -Value $VxRailMgr.Name
                            }
                            if ($Healthcheck.vCenter.Licensing) {
                                $vCenterServerInfo | Where-Object { $_.'Product' -like '*Evaluation*' } | Set-Style -Style Warning -Property 'Product'
                                $vCenterServerInfo | Where-Object { $null -eq $_.'Product' } | Set-Style -Style Warning -Property 'Product'
                                $vCenterServerInfo | Where-Object { $_.'License Key' -like '*-00000-00000' } | Set-Style -Style Warning -Property 'License Key'
                                $vCenterServerInfo | Where-Object { $_.'License Expiration' -eq 'Expired' } | Set-Style -Style Critical -Property 'License Expiration'
                            }
                            $TableParams = @{
                                Name = "vCenter Server Configuration - $vCenterServerName"
                                List = $true
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $vCenterServerInfo | Table @TableParams
                            #endregion vCenter Server Detail

                            #region vCenter Server Database Settings
                            Section -Style Heading3 'Database Settings' {
                                $vCenterDbInfo = [PSCustomObject]@{
                                    'Database Type' = $TextInfo.ToTitleCase(($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dbtype' }).Value)
                                    'Data Source Name' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'config.vpxd.odbc.dsn' }).Value
                                    'Maximum Database Connection' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'VirtualCenter.MaxDBConnection' }).Value
                                }
                                $TableParams = @{
                                    Name = "Database Settings - $vCenterServerName"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $vCenterDbInfo | Table @TableParams
                            }
                            #endregion vCenter Server Database Settings

                            #region vCenter Server Mail Settings
                            Section -Style Heading3 'Mail Settings' {
                                $vCenterMailInfo = [PSCustomObject]@{
                                    'SMTP Server' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.server' }).Value
                                    'SMTP Port' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.smtp.port' }).Value
                                    'Mail Sender' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'mail.sender' }).Value
                                }
                                if ($Healthcheck.vCenter.Mail) {
                                    $vCenterMailInfo | Where-Object { !($_.'SMTP Server') } | Set-Style -Style Critical -Property 'SMTP Server'
                                    $vCenterMailInfo | Where-Object { !($_.'SMTP Port') } | Set-Style -Style Critical -Property 'SMTP Port'
                                    $vCenterMailInfo | Where-Object { !($_.'Mail Sender') } | Set-Style -Style Critical -Property 'Mail Sender'
                                }
                                $TableParams = @{
                                    Name = "Mail Settings - $vCenterServerName"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $vCenterMailInfo | Table @TableParams
                            }
                            #endregion vCenter Server Mail Settings

                            #region vCenter Server Historical Statistics
                            Section -Style Heading3 'Historical Statistics' {
                                $vCenterHistoricalStats = Get-vCenterStats | Select-Object @{L = 'Interval Duration'; E = { $_.IntervalDuration } }, @{L = 'Interval Enabled'; E = { $_.IntervalEnabled } },
                                @{L = 'Save Duration'; E = { $_.SaveDuration } }, @{L = 'Statistics Level'; E = { $_.StatsLevel } } -Unique
                                $TableParams = @{
                                    Name = "Historical Statistics - $vCenterServerName"
                                    ColumnWidths = 25, 25, 25, 25
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $vCenterHistoricalStats | Table @TableParams
                            }
                            #endregion vCenter Server Historical Statistics

                            #region vCenter Server Licensing
                            if ($UserRole.Privilege -contains 'Global.Licenses') {
                                Section -Style Heading3 'Licensing' {
                                    $Licenses = Get-License -Licenses | Select-Object Product, @{L = 'License Key'; E = { ($_.LicenseKey) } }, Total, Used, @{L = 'Available'; E = { ($_.total) - ($_.Used) } }, Expiration -Unique
                                    if ($Healthcheck.vCenter.Licensing) {
                                        $Licenses | Where-Object { $_.Product -eq 'Product Evaluation' } | Set-Style -Style Warning
                                        $Licenses | Where-Object { $_.Expiration -eq 'Expired' } | Set-Style -Style Critical
                                    }
                                    $TableParams = @{
                                        Name = "Licensing - $vCenterServerName"
                                        ColumnWidths = 25, 25, 12, 12, 12, 14
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $Licenses | Sort-Object 'Product', 'License Key' | Table @TableParams
                                }
                            } else {
                                Write-PScriboMessage "Insufficient user privileges to report vCenter Server licensing. Please ensure the user account has the 'Global > Licenses' privilege assigned."
                            }
                            #endregion vCenter Server Licensing

                            #region vCenter Server Certificate
                            if ($vCenter.Version -ge 6) {
                                Section -Style Heading3 'Certificate' {
                                    $VcenterCertMgmt = [PSCustomObject]@{
                                        'Country' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.country' }).Value
                                        'Email' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.email' }).Value
                                        'Locality' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.localityName' }).Value
                                        'State' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.state' }).Value
                                        'Organization' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.organizationName' }).Value
                                        'Organization Unit' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.cn.organizationalUnitName' }).Value
                                        'Validity' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.daysValid'}).Value / 365) years"
                                        'Mode' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.mode' }).Value
                                        'Soft Threshold' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.softThreshold'}).Value) days"
                                        'Hard Threshold' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.hardThreshold'}).Value) days"
                                        'Minutes Before' = ($vCenterAdvSettings | Where-Object { $_.name -eq 'vpxd.certmgmt.certs.minutesBefore' }).Value
                                        'Poll Interval' = "$(($vCenterAdvSettings | Where-Object {$_.name -eq 'vpxd.certmgmt.certs.pollIntervalDays'}).Value) days"
                                    }
                                    $TableParams = @{
                                        Name = "Certificate - $vCenterServerName"
                                        List = $true
                                        ColumnWidths = 50, 50
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $VcenterCertMgmt | Table @TableParams
                                }
                            }
                            #endregion vCenter Server Certificate

                            #region vCenter Server Roles
                            Section -Style Heading3 'Roles' {
                                $VIRoles = Get-VIRole -Server $vCenter | Where-Object {$null -ne $_.PrivilegeList} | Sort-Object Name
                                $VIRoleInfo = foreach ($VIRole in $VIRoles) {
                                    [PSCustomObject]@{
                                        'Role' = $VIRole.Name
                                        'System Role' = Switch ($VIRole.IsSystem) {
                                            $true { 'Yes' }
                                            $false { 'No' }
                                        }
                                        'Privilege List' = ($VIRole.PrivilegeList).Replace("."," > ") | Select-Object -Unique
                                    }
                                }
                                if ($InfoLevel.vCenter -ge 4) {
                                    $VIRoleInfo | ForEach-Object {
                                        Section -Style Heading4 $($_.Role) {
                                            $TableParams = @{
                                                Name = "Role $($_.Role) - $vCenterServerName"
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
                                        Name = "Roles - $vCenterServerName"
                                        Columns = 'Role','System Role'
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
                                Section -Style Heading3 'Tags' {
                                    $TagInfo = foreach ($Tag in $Tags) {
                                        [PSCustomObject] @{
                                            'Tag' = $Tag.Name
                                            'Description' = Switch ($Tag.Description) {
                                                '' { 'None' }
                                                default { $Tag.Description }
                                            }
                                            'Category' = Switch ($Tag.Category) {
                                                '' { 'None' }
                                                default { $Tag.Category }
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name = "Tags - $vCenterServerName"
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
                                Section -Style Heading3 'Tag Categories' {
                                    $TagCategoryInfo = foreach ($TagCategory in $TagCategories) {
                                        [PSCustomObject] @{
                                            'Category' = $TagCategory.Name
                                            'Description' = Switch ($TagCategory.Description) {
                                                '' { 'None' }
                                                default { $TagCategory.Description }
                                            }
                                            'Cardinality' = Switch ($TagCategory.Cardinality) {
                                                '' { 'None' }
                                                default { $TagCategory.Cardinality }
                                            }
                                        }
                                    }
                                    $TableParams = @{
                                        Name = "Tag Categories - $vCenterServerName"
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
                                Section -Style Heading3 'Tag Assignments' {
                                    $TagAssignmentInfo = foreach ($TagAssignment in $TagAssignments) {
                                        [PSCustomObject]@{
                                            'Entity' = $TagAssignment.Entity.Name
                                            'Tag' = $TagAssignment.Tag.Name
                                            'Category' = $TagAssignment.Tag.Category
                                        }
                                    }
                                    $TableParams = @{
                                        Name = "Tag Assignments - $vCenterServerName"
                                        ColumnWidths = 30, 40, 30
                                    }
                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $TagAssignmentInfo | Sort-Object Entity | Table @TableParams
                                }
                            }
                            #endregion vCenter Server Tag Assignments

                            #region VM Storage Policies
                            if ($UserRole.Privilege -contains 'StorageProfile.View') {
                                $SpbmStoragePolicies = Get-SpbmStoragePolicy | Sort-Object Name
                                if ($SpbmStoragePolicies) {
                                    Section -Style Heading3 'VM Storage Policies' {
                                        $VmStoragePolicies = foreach ($SpbmStoragePolicy in $SpbmStoragePolicies) {
                                            [PSCustomObject]@{
                                                'VM Storage Policy' = $SpbmStoragePolicy.Name
                                                'Description' = $SpbmStoragePolicy.Description
                                            }
                                        }
                                        $TableParams = @{
                                            Name = "VM Storage Policies - $vCenterServerName"
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $VmStoragePolicies | Table @TableParams
                                    }
                                }
                            } else {
                                Write-PScriboMessage "Insufficient user privileges to report VM storage policies. Please ensure the user account has the 'Storage Profile > View' privilege assigned."
                            }
                            #endregion VM Storage Policies
                        }
                        #endregion vCenter Server Detailed Information

                        #region vCenter Server Advanced Detail Information
                        if ($InfoLevel.vCenter -ge 4) {
                            #region vCenter Alarms
                            Section -Style Heading3 'Alarms' {
                                $Alarms = Get-AlarmDefinition -PipelineVariable alarm | ForEach-Object -Process {
                                    Get-AlarmAction -AlarmDefinition $_ -PipelineVariable action | ForEach-Object -Process {
                                        Get-AlarmActionTrigger -AlarmAction $_ |
                                        Select-Object @{N = 'Alarm'; E = { $alarm.Name } },
                                        @{N = 'Description'; E = { $alarm.Description } },
                                        @{N = 'Enabled'; E = { Switch ($alarm.Enabled) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                } }
                                        },
                                        @{N = 'Entity'; E = { $alarm.Entity.Type } },
                                        @{N = 'Trigger'; E = {
                                                "{0}:{1}->{2} (Repeat={3})" -f $action.ActionType,
                                                $_.StartStatus,
                                                $_.EndStatus,
                                                $_.Repeat
                                            }
                                        },
                                        @{N = 'Trigger Info'; E = { Switch ($action.ActionType) {
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
                                $Alarms = $Alarms | Sort-Object 'Alarm', 'Trigger'
                                if ($Healthcheck.vCenter.Alarms) {
                                    $Alarms | Where-Object { $_.'Enabled' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Enabled'
                                }
                                if ($InfoLevel.vCenter -ge 5) {
                                    foreach ($Alarm in $Alarms) {
                                        Section -Style Heading4 $($Alarm.Alarm) {
                                            $TableParams = @{
                                                Name = "$($Alarm.Alarm) - $vCenterServerName"
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
                                        Name = "Alarms - $vCenterServerName"
                                        Columns = 'Alarm', 'Description', 'Enabled', 'Entity', 'Trigger'
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
                            Section -Style Heading3 'Advanced System Settings' {
                                $TableParams = @{
                                    Name = "vCenter Advanced System Settings - $vCenterServerName"
                                    Columns = 'Name', 'Value'
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $vCenterAdvSettings | Sort-Object Name | Table @TableParams
                            }
                            #endregion vCenter Advanced System Settings
                        }
                        #endregion vCenter Server Comprehensive Information
                    }
                }
                #endregion vCenter Server Section

                #region Clusters
                Write-PScriboMessage "Cluster InfoLevel set at $($InfoLevel.Cluster)."
                if ($InfoLevel.Cluster -ge 1) {
                    $Clusters = Get-Cluster -Server $vCenter | Sort-Object Name
                    if ($Clusters) {
                        #region Cluster Section
                        Section -Style Heading2 'Clusters' {
                            Paragraph "The following sections detail the configuration of vSphere HA/DRS clusters managed by vCenter Server $vCenterServerName."
                            #region Cluster Advanced Summary
                            if ($InfoLevel.Cluster -le 2) {
                                BlankLine
                                $ClusterInfo = foreach ($Cluster in $Clusters) {
                                    [PSCustomObject]@{
                                        'Cluster' = $Cluster.Name
                                        'Datacenter' = $Cluster | Get-Datacenter
                                        '# of Hosts' = $Cluster.ExtensionData.Host.Count
                                        '# of VMs' = $Cluster.ExtensionData.VM.Count
                                        'vSphere HA' = Switch ($Cluster.HAEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'Virtual SAN' = Switch ($Cluster.VsanEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'EVC Mode' = Switch ($Cluster.EVCMode) {
                                            $null { 'Disabled' }
                                            default { $EvcModeLookup."$($Cluster.EVCMode)" }
                                        }
                                        'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                            'WithVM' { 'With VM' }
                                            'InHostDatastore' { 'In Host Datastore' }
                                            default { $Cluster.VMSwapfilePolicy }
                                        }
                                    }
                                }
                                if ($Healthcheck.Cluster.HAEnabled) {
                                    $ClusterInfo | Where-Object { $_.'vSphere HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere HA'
                                }
                                if ($Healthcheck.Cluster.DrsEnabled) {
                                    $ClusterInfo | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                }
                                if ($Healthcheck.Cluster.VsanEnabled) {
                                    $ClusterInfo | Where-Object { $_.'Virtual SAN' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Virtual SAN'
                                }
                                if ($Healthcheck.Cluster.EvcEnabled) {
                                    $ClusterInfo | Where-Object { $_.'EVC Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'EVC Mode'
                                }
                                $TableParams = @{
                                    Name = "Cluster Summary - $vCenterServerName"
                                    ColumnWidths = 15, 15, 7, 7, 11, 11, 11, 15, 8
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $ClusterInfo | Table @TableParams
                            }
                            #endregion Cluster Advanced Summary

                            #region Cluster Detailed Information
                            # TODO: Test Tags
                            if ($InfoLevel.Cluster -ge 3) {
                                foreach ($Cluster in $Clusters) {
                                    $ClusterDasConfig = $Cluster.ExtensionData.Configuration.DasConfig
                                    $ClusterDrsConfig = $Cluster.ExtensionData.Configuration.DrsConfig
                                    $ClusterConfigEx = $Cluster.ExtensionData.ConfigurationEx
                                    #region Cluster Section
                                    Section -Style Heading3 $Cluster {
                                        Paragraph "The following table details the configuration for cluster $Cluster."
                                        BlankLine
                                        #region Cluster Configuration
                                        $ClusterDetail = [PSCustomObject]@{
                                            'Cluster' = $Cluster.Name
                                            'ID' = $Cluster.Id
                                            'Datacenter' = $Cluster | Get-Datacenter
                                            'Number of Hosts' = $Cluster.ExtensionData.Host.Count
                                            'Number of VMs' = ($Cluster | Get-VM).Count
                                            'vSphere HA' = Switch ($Cluster.HAEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Virtual SAN' = Switch ($Cluster.VsanEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'EVC Mode' = Switch ($Cluster.EVCMode) {
                                                $null { 'Disabled' }
                                                default { $EvcModeLookup."$($Cluster.EVCMode)" }
                                            }
                                            'VM Swap File Policy' = Switch ($Cluster.VMSwapfilePolicy) {
                                                'WithVM' { 'Virtual machine directory' }
                                                'InHostDatastore' { 'Datastore specified by host' }
                                                default { $Cluster.VMSwapfilePolicy }
                                            }
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $ClusterDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        <#
                                        if ($TagAssignments | Where-Object {$_.entity -eq $Cluster}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $Cluster}).Tag -join ',')
                                        }
                                        #>
                                        if ($Healthcheck.Cluster.HAEnabled) {
                                            $ClusterDetail | Where-Object { $_.'vSphere HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere HA'
                                        }
                                        if ($Healthcheck.Cluster.DrsEnabled) {
                                            $ClusterDetail | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                        }
                                        if ($Healthcheck.Cluster.VsanEnabled) {
                                            $ClusterDetail | Where-Object { $_.'Virtual SAN' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Virtual SAN'
                                        }
                                        if ($Healthcheck.Cluster.EvcEnabled) {
                                            $ClusterDetail | Where-Object { $_.'EVC Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'EVC Mode'
                                        }
                                        #region Cluster Advanced Detailed Information
                                        if ($InfoLevel.Cluster -ge 4) {
                                            $ClusterDetail | ForEach-Object {
                                                $ClusterHosts = $Cluster | Get-VMHost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($ClusterHosts.Name -join ', ')
                                                $ClusterVMs = $Cluster | Get-VM | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ClusterVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Cluster Advanced Detailed Information
                                        $TableParams = @{
                                            Name = "Cluster Configuration - $Cluster"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $ClusterDetail | Table @TableParams
                                        #endregion Cluster Configuration

                                        #region vSphere HA Cluster Configuration
                                        if ($Cluster.HAEnabled) {
                                            Section -Style Heading4 'vSphere HA Configuration' {
                                                Paragraph "The following section details the vSphere HA configuration for $Cluster cluster."
                                                #region vSphere HA Cluster Failures and Responses
                                                Section -Style Heading5 'Failures and Responses' {
                                                    $HAClusterResponses = [PSCustomObject]@{
                                                        'Host Monitoring' = $TextInfo.ToTitleCase($ClusterDasConfig.HostMonitoring)
                                                    }
                                                    if ($ClusterDasConfig.HostMonitoring -eq 'Enabled') {
                                                        $MemberProps = @{
                                                            'InputObject' = $HAClusterResponses
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        if ($ClusterDasConfig.DefaultVmSettings.RestartPriority -eq 'Disabled') {
                                                            Add-Member @MemberProps -Name 'Host Failure Response' -Value 'Disabled'
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Host Failure Response' -Value 'Restart VMs'
                                                            Switch ($Cluster.HAIsolationResponse) {
                                                                'DoNothing' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Disabled'
                                                                }
                                                                'Shutdown' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Shutdown and restart VMs'
                                                                }
                                                                'PowerOff' {
                                                                    Add-Member @MemberProps -Name 'Host Isolation Response' -Value 'Power off and restart VMs'
                                                                }
                                                            }
                                                            Add-Member @MemberProps -Name 'VM Restart Priority' -Value $Cluster.HARestartPriority
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForPDL) {
                                                                'disabled' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Disabled'
                                                                }
                                                                'warning' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Issue events'
                                                                }
                                                                'restartAggressive' {
                                                                    Add-Member @MemberProps -Name 'Datastore with Permanent Device Loss' -Value 'Power off and restart VMs'
                                                                }
                                                            }
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmStorageProtectionForAPD) {
                                                                'disabled' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Disabled'
                                                                }
                                                                'warning' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Issue events'
                                                                }
                                                                'restartConservative' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Power off and restart VMs (conservative)'
                                                                }
                                                                'restartAggressive' {
                                                                    Add-Member @MemberProps -Name 'Datastore with All Paths Down' -Value 'Power off and restart VMs (aggressive)'
                                                                }
                                                            }
                                                            Switch ($ClusterDasConfig.DefaultVmSettings.VmComponentProtectionSettings.VmReactionOnAPDCleared) {
                                                                'none' {
                                                                    Add-Member @MemberProps -Name 'APD recovery after APD timeout' -Value 'Disabled'
                                                                }
                                                                'reset' {
                                                                    Add-Member @MemberProps -Name 'APD recovery after APD timeout' -Value 'Reset VMs'
                                                                }
                                                            }
                                                        }
                                                        Switch ($ClusterDasConfig.VmMonitoring) {
                                                            'vmMonitoringDisabled' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'Disabled'
                                                            }
                                                            'vmMonitoringOnly' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'VM monitoring only'
                                                            }
                                                            'vmAndAppMonitoring' {
                                                                Add-Member @MemberProps -Name 'VM Monitoring' -Value 'VM and application monitoring'
                                                            }
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.HostFailureResponse) {
                                                        $HAClusterResponses | Where-Object { $_.'Host Failure Response' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Host Failure Response'
                                                    }
                                                    if ($Healthcheck.Cluster.HostMonitoring) {
                                                        $HAClusterResponses | Where-Object { $_.'Host Monitoring' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Host Monitoring'
                                                    }
                                                    if ($Healthcheck.Cluster.DatastoreOnPDL) {
                                                        $HAClusterResponses | Where-Object { $_.'Datastore with Permanent Device Loss' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Datastore with Permanent Device Loss'
                                                    }
                                                    if ($Healthcheck.Cluster.DatastoreOnAPD) {
                                                        $HAClusterResponses | Where-Object { $_.'Datastore with All Paths Down' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Datastore with All Paths Down'
                                                    }
                                                    if ($Healthcheck.Cluster.APDTimeout) {
                                                        $HAClusterResponses | Where-Object { $_.'APD recovery after APD timeout' -eq 'Disabled' } | Set-Style -Style Warning -Property 'APD recovery after APD timeout'
                                                    }
                                                    if ($Healthcheck.Cluster.vmMonitoring) {
                                                        $HAClusterResponses | Where-Object { $_.'VM Monitoring' -eq 'Disabled' } | Set-Style -Style Warning -Property 'VM Monitoring'
                                                    }
                                                    $TableParams = @{
                                                        Name = "vSphere HA Failures and Responses - $Cluster"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $HAClusterResponses | Table @TableParams
                                                }
                                                #endregion vSphere HA Cluster Failures and Responses

                                                #region vSphere HA Cluster Admission Control
                                                Section -Style Heading5 'Admission Control' {
                                                    $HAAdmissionControl = [PSCustomObject]@{
                                                        'Admission Control' = Switch ($Cluster.HAAdmissionControlEnabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                    if ($Cluster.HAAdmissionControlEnabled) {
                                                        $MemberProps = @{
                                                            'InputObject' = $HAAdmissionControl
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Add-Member @MemberProps -Name 'Host Failures Cluster Tolerates' -Value $Cluster.HAFailoverLevel
                                                        Switch ($ClusterDasConfig.AdmissionControlPolicy.GetType().Name) {
                                                            'ClusterFailoverHostAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Dedicated failover hosts'
                                                            }
                                                            'ClusterFailoverResourcesAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Cluster resource percentage'
                                                            }
                                                            'ClusterFailoverLevelAdmissionControlPolicy' {
                                                                Add-Member @MemberProps -Name 'Host Failover Capacity Policy' -Value 'Slot policy'
                                                            }
                                                        }
                                                        Switch ($ClusterDasConfig.AdmissionControlPolicy.AutoComputePercentages) {
                                                            $true {
                                                                Add-Member @MemberProps -Name 'Override Calculated Failover Capacity' -Value 'No'
                                                            }
                                                            $false {
                                                                Add-Member @MemberProps -Name 'Override Calculated Failover Capacity' -Value 'Yes'
                                                                Add-Member @MemberProps -Name 'CPU %' -Value $ClusterDasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent
                                                                Add-Member @MemberProps -Name 'Memory %' -Value $ClusterDasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent
                                                            }
                                                        }
                                                        if ($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy) {
                                                            Add-Member @MemberProps -Name 'Slot Policy' -Value 'Fixed slot size'
                                                            Add-Member @MemberProps -Name 'CPU Slot Size' -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Cpu) MHz"
                                                            Add-Member @MemberProps -Name 'Memory Slot Size' -Value "$($ClusterDasConfig.AdmissionControlPolicy.SlotPolicy.Memory) MB"
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Slot Policy' -Value 'Cover all powered-on virtual machines'
                                                        }
                                                        if ($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent) {
                                                            Add-Member @MemberProps -Name 'Performance Degradation VMs Tolerate' -Value "$($ClusterDasConfig.AdmissionControlPolicy.ResourceReductionToToleratePercent)%"
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.HAAdmissionControl) {
                                                        $HAAdmissionControl | Where-Object { $_.'Admission Control' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Admission Control'
                                                    }
                                                    $TableParams = @{
                                                        Name = "vSphere HA Admission Control - $Cluster"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $HAAdmissionControl | Table @TableParams
                                                }
                                                #endregion vSphere HA Cluster Admission Control

                                                #region vSphere HA Cluster Heartbeat Datastores
                                                Section -Style Heading5 'Heartbeat Datastores' {
                                                    $HeartbeatDatastores = [PSCustomObject]@{
                                                        'Heartbeat Selection Policy' = Switch ($ClusterDasConfig.HBDatastoreCandidatePolicy) {
                                                            'allFeasibleDsWithUserPreference' { 'Use datastores from the specified list and complement automatically if needed' }
                                                            'allFeasibleDs' { 'Automatically select datastores accessible from the host' }
                                                            'userSelectedDs' { 'Use datastores only from the specified list' }
                                                            default { $ClusterDasConfig.HBDatastoreCandidatePolicy }
                                                        }
                                                        'Heartbeat Datastores' = try {
                                                            (((Get-View -Id $ClusterDasConfig.HeartbeatDatastore -Property Name).Name | Sort-Object) -join ', ')
                                                        } catch {
                                                            'None specified'
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "vSphere HA Heartbeat Datastores - $Cluster"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $HeartbeatDatastores | Table @TableParams
                                                }
                                                #endregion vSphere HA Cluster Heartbeat Datastores

                                                #region vSphere HA Cluster Advanced Options
                                                $HAAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterHA' }
                                                if ($HAAdvancedSettings) {
                                                    Section -Style Heading5 'vSphere HA Advanced Options' {
                                                        $HAAdvancedOptions = @()
                                                        foreach ($HAAdvancedSetting in $HAAdvancedSettings) {
                                                            $HAAdvancedOption = [PSCustomObject]@{
                                                                'Option' = $HAAdvancedSetting.Name
                                                                'Value' = $HAAdvancedSetting.Value
                                                            }
                                                            $HAAdvancedOptions += $HAAdvancedOption
                                                        }
                                                        $TableParams = @{
                                                            Name = "vSphere HA Advanced Options - $Cluster"
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $HAAdvancedOptions | Sort-Object Option | Table @TableParams
                                                    }
                                                }
                                                #endregion vSphere HA Cluster Advanced Options
                                            }
                                        }
                                        #endregion vSphere HA Cluster Configuration

                                        #region Proactive HA Configuration
                                        # TODO: Proactive HA Providers
                                        # Proactive HA is only available in vSphere 6.5 and above
                                        if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled -and $vCenter.Version -ge 6.5) {
                                            Section -Style Heading4 'Proactive HA' {
                                                Paragraph "The following section details the Proactive HA configuration for $Cluster cluster."
                                                #region Proactive HA Failures and Responses Section
                                                Section -Style Heading5 'Failures and Responses' {
                                                    $ProactiveHa = [PSCustomObject]@{
                                                        'Proactive HA' = Switch ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                    }
                                                    if ($ClusterConfigEx.InfraUpdateHaConfig.Enabled) {
                                                        $ProactiveHaModerateRemediation = Switch ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation) {
                                                            'MaintenanceMode' { 'Maintenance Mode' }
                                                            'QuarantineMode' { 'Quarantine Mode' }
                                                            default { $ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation }
                                                        }
                                                        $ProactiveHaSevereRemediation = Switch ($ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                                            'MaintenanceMode' { 'Maintenance Mode' }
                                                            'QuarantineMode' { 'Quarantine Mode' }
                                                            default { $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $ProactiveHa
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value $ClusterConfigEx.InfraUpdateHaConfig.Behavior
                                                        if ($ClusterConfigEx.InfraUpdateHaConfig.ModerateRemediation -eq $ClusterConfigEx.InfraUpdateHaConfig.SevereRemediation) {
                                                            Add-Member @MemberProps -Name 'Remediation' -Value $ProactiveHaModerateRemediation
                                                        } else {
                                                            Add-Member @MemberProps -Name 'Remediation' -Value 'Mixed Mode'
                                                            Add-Member @MemberProps -Name 'Moderate Remediation' -Value $ProactiveHaModerateRemediation
                                                            Add-Member @MemberProps -Name 'Severe Remediation' -Value $ProactiveHaSevereRemediation
                                                        }
                                                    }
                                                    if ($Healthcheck.Cluster.ProactiveHA) {
                                                        $ProactiveHa | Where-Object { $_.'Proactive HA' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Proactive HA'
                                                    }
                                                    $TableParams = @{
                                                        Name = "Proactive HA - $Cluster"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $ProactiveHa | Table @TableParams
                                                }
                                                #endregion Proactive HA Failures and Responses Section
                                            }
                                        }
                                        #endregion Proactive HA Configuration

                                        #region vSphere DRS Cluster Configuration
                                        if ($Cluster.DrsEnabled) {
                                            Section -Style Heading4 'vSphere DRS Configuration' {
                                                Paragraph ("The following table details the vSphere DRS configuration " +
                                                    "for cluster $Cluster.")
                                                BlankLine

                                                #region vSphere DRS Cluster Specifications
                                                $DrsCluster = [PSCustomObject]@{
                                                    'vSphere DRS' = Switch ($Cluster.DrsEnabled) {
                                                        $true { 'Enabled' }
                                                        $false { 'Disabled' }
                                                    }
                                                }
                                                $MemberProps = @{
                                                    'InputObject' = $DrsCluster
                                                    'MemberType' = 'NoteProperty'
                                                }
                                                Switch ($Cluster.DrsAutomationLevel) {
                                                    'Manual' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Manual'
                                                    }
                                                    'PartiallyAutomated' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Partially Automated'
                                                    }
                                                    'FullyAutomated' {
                                                        Add-Member @MemberProps -Name 'Automation Level' -Value 'Fully Automated'
                                                    }
                                                }
                                                Add-Member @MemberProps -Name 'Migration Threshold' -Value $ClusterDrsConfig.VmotionRate
                                                Switch ($ClusterConfigEx.ProactiveDrsConfig.Enabled) {
                                                    $false {
                                                        Add-Member @MemberProps -Name 'Predictive DRS' -Value 'Disabled'
                                                    }
                                                    $true {
                                                        Add-Member @MemberProps -Name 'Predictive DRS' -Value 'Enabled'
                                                    }
                                                }
                                                Switch ($ClusterDrsConfig.EnableVmBehaviorOverrides) {
                                                    $true {
                                                        Add-Member @MemberProps -Name 'Virtual Machine Automation' -Value 'Enabled'
                                                    }
                                                    $false {
                                                        Add-Member @MemberProps -Name 'Virtual Machine Automation' -Value 'Disabled'
                                                    }
                                                }
                                                if ($Healthcheck.Cluster.DrsEnabled) {
                                                    $DrsCluster | Where-Object { $_.'vSphere DRS' -eq 'Disabled' } | Set-Style -Style Warning -Property 'vSphere DRS'
                                                }
                                                if ($Healthcheck.Cluster.DrsAutomationLevelFullyAuto) {
                                                    $DrsCluster | Where-Object { $_.'Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'Automation Level'
                                                }
                                                $TableParams = @{
                                                    Name = "vSphere DRS Configuration - $Cluster"
                                                    List = $true
                                                    ColumnWidths = 50, 50
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $DrsCluster | Table @TableParams
                                                #endregion vSphere DRS Cluster Specfications

                                                #region DRS Cluster Additional Options
                                                $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                                                if ($DrsAdvancedSettings) {
                                                    Section -Style Heading5 'Additional Options' {
                                                        $DrsAdditionalOptions = [PSCustomObject] @{
                                                            'VM Distribution' = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'TryBalanceVmsPerHost' }).Value) {
                                                                '1' { 'Enabled' }
                                                                $null { 'Disabled' }
                                                            }
                                                            'Memory Metric for Load Balancing' = Switch (($DrsAdvancedSettings | Where-Object { $_.name -eq 'PercentIdleMBInMemDemand' }).Value) {
                                                                '100' { 'Enabled' }
                                                                $null { 'Disabled' }
                                                            }
                                                            'CPU Over-Commitment' = if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                                                'Enabled'
                                                            } else {
                                                                'Disabled'
                                                            }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $DrsAdditionalOptions
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerCore' }).Value) {
                                                            Add-Member @MemberProps -Name 'Over-Commitment Ratio' -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerCore'}).Value):1 (vCPU:pCPU)"
                                                        }
                                                        if (($DrsAdvancedSettings | Where-Object { $_.name -eq 'MaxVcpusPerClusterPct' }).Value) {
                                                            Add-Member @MemberProps -Name 'Over-Commitment Ratio (% of cluster capacity)' -Value "$(($DrsAdvancedSettings | Where-Object {$_.name -eq 'MaxVcpusPerClusterPct'}).Value) %"
                                                        }
                                                        $TableParams = @{
                                                            Name = "DRS Additional Options - $Cluster"
                                                            List = $true
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $DrsAdditionalOptions | Table @TableParams
                                                    }
                                                }
                                                #endregion DRS Cluster Additional Options

                                                #region vSphere DPM Configuration
                                                if ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                                                    Section -Style Heading5 'Power Management' {
                                                        $DpmConfig = [PSCustomObject]@{
                                                            'DPM' = Switch ($ClusterConfigEx.DpmConfigInfo.Enabled) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                        }
                                                        $MemberProps = @{
                                                            'InputObject' = $DpmConfig
                                                            'MemberType' = 'NoteProperty'
                                                        }
                                                        Switch ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior) {
                                                            'manual' {
                                                                Add-Member @MemberProps -Name 'Automation Level' -Value 'Manual'
                                                            }
                                                            'automated' {
                                                                Add-Member @MemberProps -Name 'Automation Level' -Value 'Automated'
                                                            }
                                                        }
                                                        if ($ClusterConfigEx.DpmConfigInfo.DefaultDpmBehavior -eq 'automated') {
                                                            Add-Member @MemberProps -Name 'DPM Threshold' -Value $ClusterConfigEx.DpmConfigInfo.HostPowerActionRate
                                                        }
                                                        $TableParams = @{
                                                            Name = "vSphere DPM - $Cluster"
                                                            List = $true
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $DpmConfig | Table @TableParams
                                                    }
                                                }
                                                #endregion vSphere DPM Configuration

                                                #region vSphere DRS Cluster Advanced Options
                                                $DrsAdvancedSettings = $Cluster | Get-AdvancedSetting | Where-Object { $_.Type -eq 'ClusterDRS' }
                                                if ($DrsAdvancedSettings) {
                                                    Section -Style Heading5 'Advanced Options' {
                                                        $DrsAdvancedOptions = @()
                                                        foreach ($DrsAdvancedSetting in $DrsAdvancedSettings) {
                                                            $DrsAdvancedOption = [PSCustomObject]@{
                                                                'Option' = $DrsAdvancedSetting.Name
                                                                'Value' = $DrsAdvancedSetting.Value
                                                            }
                                                            $DrsAdvancedOptions += $DrsAdvancedOption
                                                        }
                                                        $TableParams = @{
                                                            Name = "vSphere DRS Advanced Options - $Cluster"
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $DrsAdvancedOptions | Sort-Object Option | Table @TableParams
                                                    }
                                                }
                                                #endregion vSphere DRS Cluster Advanced Options

                                                #region vSphere DRS Cluster Group
                                                $DrsClusterGroups = $Cluster | Get-DrsClusterGroup
                                                if ($DrsClusterGroups) {
                                                    #region vSphere DRS Cluster Group Section
                                                    Section -Style Heading5 'DRS Cluster Groups' {
                                                        $DrsGroups = foreach ($DrsClusterGroup in $DrsClusterGroups) {
                                                            [PSCustomObject]@{
                                                                'DRS Cluster Group' = $DrsClusterGroup.Name
                                                                'Type' = Switch ($DrsClusterGroup.GroupType) {
                                                                    'VMGroup' { 'VM Group' }
                                                                    'VMHostGroup' { 'Host Group' }
                                                                    default { $DrsClusterGroup.GroupType }
                                                                }
                                                                'Members' = Switch (($DrsClusterGroup.Member).Count -gt 0) {
                                                                    $true { ($DrsClusterGroup.Member | Sort-Object) -join ', ' }
                                                                    $false { "None" }
                                                                }
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "DRS Cluster Groups - $Cluster"
                                                            ColumnWidths = 42, 16, 42
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $DrsGroups | Sort-Object 'DRS Cluster Group', 'Type' | Table @TableParams
                                                    }
                                                    #endregion vSphere DRS Cluster Group Section

                                                    #region vSphere DRS Cluster VM/Host Rules
                                                    $DrsVMHostRules = $Cluster | Get-DrsVMHostRule
                                                    if ($DrsVMHostRules) {
                                                        Section -Style Heading5 'DRS VM/Host Rules' {
                                                            $DrsVMHostRuleDetail = foreach ($DrsVMHostRule in $DrsVMHostRules) {
                                                                [PSCustomObject]@{
                                                                    'DRS VM/Host Rule' = $DrsVMHostRule.Name
                                                                    'Type' = Switch ($DrsVMHostRule.Type) {
                                                                        'MustRunOn' { 'Must run on hosts in group' }
                                                                        'ShouldRunOn' { 'Should run on hosts in group' }
                                                                        'MustNotRunOn' { 'Must not run on hosts in group' }
                                                                        'ShouldNotRunOn' { 'Should not run on hosts in group' }
                                                                        default { $DrsVMHostRule.Type }
                                                                    }
                                                                    'Enabled' = Switch ($DrsVMHostRule.Enabled) {
                                                                        $true { 'Yes' }
                                                                        $False { 'No' }
                                                                    }
                                                                    'VM Group' = $DrsVMHostRule.VMGroup
                                                                    'Host Group' = $DrsVMHostRule.VMHostGroup
                                                                }
                                                            }
                                                            if ($Healthcheck.Cluster.DrsVMHostRules) {
                                                                $DrsVMHostRuleDetail | Where-Object { $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Enabled'
                                                            }
                                                            $TableParams = @{
                                                                Name = "DRS VM/Host Rules - $Cluster"
                                                                ColumnWidths = 22, 22, 12, 22, 22
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $DrsVMHostRuleDetail | Sort-Object 'DRS VM/Host Rule' | Table @TableParams
                                                        }
                                                    }
                                                    #endregion vSphere DRS Cluster VM/Host Rules

                                                    #region vSphere DRS Cluster Rules
                                                    $DrsRules = $Cluster | Get-DrsRule
                                                    if ($DrsRules) {
                                                        #region vSphere DRS Cluster Rules Section
                                                        Section -Style Heading5 'DRS Rules' {
                                                            $DrsRuleDetail = foreach ($DrsRule in $DrsRules) {
                                                                [PSCustomObject]@{
                                                                    'DRS Rule' = $DrsRule.Name
                                                                    'Type' = Switch ($DrsRule.Type) {
                                                                        'VMAffinity' { 'Keep Vitrual Machines Together' }
                                                                        'VMAntiAffinity' { 'Separate Virtual Machines' }
                                                                    }
                                                                    'Enabled' = Switch ($DrsRule.Enabled) {
                                                                        $true { 'Yes' }
                                                                        $False { 'No' }
                                                                    }
                                                                    'Mandatory' = $DrsRule.Mandatory
                                                                    'Virtual Machines' = ($DrsRule.VMIds | ForEach-Object { (Get-View -id $_).name }) -join ', '
                                                                }
                                                                if ($Healthcheck.Cluster.DrsRules) {
                                                                    $DrsRuleDetail | Where-Object { $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Enabled'
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "DRS Rules - $Cluster"
                                                                ColumnWidths = 26, 25, 12, 12, 25
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $DrsRuleDetail | Sort-Object Type | Table @TableParams
                                                        }
                                                        #endregion vSphere DRS Cluster Rules Section
                                                    }
                                                    #endregion vSphere DRS Cluster Rules
                                                }
                                                #endregion vSphere DRS Cluster Group

                                                #region Cluster VM Overrides
                                                $DrsVmOverrides = $Cluster.ExtensionData.Configuration.DrsVmConfig
                                                $DasVmOverrides = $Cluster.ExtensionData.Configuration.DasVmConfig
                                                if ($DrsVmOverrides -or $DasVmOverrides) {
                                                    #region VM Overrides Section
                                                    Section -Style Heading4 'VM Overrides' {
                                                        #region vSphere DRS VM Overrides
                                                        if ($DrsVmOverrides) {
                                                            Section -Style Heading5 'vSphere DRS' {
                                                                $DrsVmOverrideDetails = foreach ($DrsVmOverride in $DrsVmOverrides) {
                                                                    [PSCustomObject]@{
                                                                        'Virtual Machine' = $VMLookup."$($DrsVmOverride.Key.Type)-$($DrsVmOverride.Key.Value)"
                                                                        'vSphere DRS Automation Level' = if ($DrsVmOverride.Enabled -eq $false) {
                                                                            'Disabled'
                                                                        } else {
                                                                            Switch ($DrsVmOverride.Behavior) {
                                                                                'manual' { 'Manual' }
                                                                                'partiallyAutomated' { 'Partially Automated' }
                                                                                'fullyAutomated' { 'Fully Automated' }
                                                                                default { $DrsVmOverride.Behavior }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                                $TableParams = @{
                                                                    Name = "DRS VM Overrides - $Cluster"
                                                                    ColumnWidths = 50, 50
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $DrsVmOverrideDetails | Sort-Object 'Virtual Machine' | Table @TableParams
                                                            }
                                                        }
                                                        #endregion vSphere DRS VM Overrides

                                                        #region vSphere HA VM Overrides
                                                        if ($DasVmOverrides) {
                                                            Section -Style Heading5 'vSphere HA' {
                                                                $DasVmOverrideDetails = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                    [PSCustomObject]@{
                                                                        'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                        'VM Restart Priority' = Switch ($DasVmOverride.DasSettings.RestartPriority) {
                                                                            $null { '--' }
                                                                            'lowest' { 'Lowest' }
                                                                            'low' { 'Low' }
                                                                            'medium' { 'Medium' }
                                                                            'high' { 'High' }
                                                                            'highest' { 'Highest' }
                                                                            'disabled' { 'Disabled' }
                                                                            'clusterRestartPriority' { 'Cluster default' }
                                                                        }
                                                                        'VM Dependency Restart Condition Timeout' = Switch ($DasVmOverride.DasSettings.RestartPriorityTimeout) {
                                                                            $null { '--' }
                                                                            '-1' { 'Disabled' }
                                                                            default { "$($DasVmOverride.DasSettings.RestartPriorityTimeout) seconds" }
                                                                        }
                                                                        'Host Isolation Response' = Switch ($DasVmOverride.DasSettings.IsolationResponse) {
                                                                            $null { '--' }
                                                                            'none' { 'Disabled' }
                                                                            'powerOff' { 'Power off and restart VMs' }
                                                                            'shutdown' { 'Shutdown and restart VMs' }
                                                                            'clusterIsolationResponse' { 'Cluster default' }
                                                                        }
                                                                    }
                                                                }
                                                                $TableParams = @{
                                                                    Name = "HA VM Overrides - $Cluster"
                                                                    ColumnWidths = 25, 25, 25, 25
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $DasVmOverrideDetails | Sort-Object 'Virtual Machine' | Table @TableParams

                                                                #region PDL/APD Protection Settings Section
                                                                Section -Style Heading5 'PDL/APD Protection Settings' {
                                                                    $DasVmOverridePdlApd = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmComponentProtection = $DasVmOverride.DasSettings.VmComponentProtectionSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'PDL Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForPDL) {
                                                                                $null { '--' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartAggressive' { 'Power off and restart VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'APD Failure Response' = Switch ($DasVmComponentProtection.VmStorageProtectionForAPD) {
                                                                                $null { '--' }
                                                                                'clusterDefault' { 'Cluster default' }
                                                                                'warning' { 'Issue events' }
                                                                                'restartConservative' { 'Power off and restart VMs - Conservative restart policy' }
                                                                                'restartAggressive' { 'Power off and restart VMs - Aggressive restart policy' }
                                                                                'disabled' { 'Disabled' }
                                                                            }
                                                                            'VM Failover Delay' = Switch ($DasVmComponentProtection.VmTerminateDelayForAPDSec) {
                                                                                $null { '--' }
                                                                                '-1' { 'Disabled' }
                                                                                default { "$(($DasVmComponentProtection.VmTerminateDelayForAPDSec)/60) minutes" }
                                                                            }
                                                                            'Response Recovery' = Switch ($DasVmComponentProtection.VmReactionOnAPDCleared) {
                                                                                $null { '--' }
                                                                                'reset' { 'Reset VMs' }
                                                                                'disabled' { 'Disabled' }
                                                                                'useClusterDefault' { 'Cluster default' }
                                                                            }
                                                                        }
                                                                    }
                                                                    $TableParams = @{
                                                                        Name = "HA VM Overrides PDL/APD Settings - $Cluster"
                                                                        ColumnWidths = 20, 20, 20, 20, 20
                                                                    }
                                                                    if ($Report.ShowTableCaptions) {
                                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                    }
                                                                    $DasVmOverridePdlApd | Sort-Object 'Virtual Machine' | Table @TableParams
                                                                }
                                                                #endregion PDL/APD Protection Settings Section

                                                                #region VM Monitoring Section
                                                                Section -Style Heading5 'VM Monitoring' {
                                                                    $DasVmOverrideVmMonitoring = foreach ($DasVmOverride in $DasVmOverrides) {
                                                                        $DasVmMonitoring = $DasVmOverride.DasSettings.VmToolsMonitoringSettings
                                                                        [PSCustomObject]@{
                                                                            'Virtual Machine' = $VMLookup."$($DasVmOverride.Key.Type)-$($DasVmOverride.Key.Value)"
                                                                            'VM Monitoring' = Switch ($DasVmMonitoring.VmMonitoring) {
                                                                                $null { '--' }
                                                                                'vmMonitoringDisabled' { 'Disabled' }
                                                                                'vmMonitoringOnly' { 'VM Monitoring Only' }
                                                                                'vmAndAppMonitoring' { 'VM and App Monitoring' }
                                                                            }
                                                                            'Failure Interval' = Switch ($DasVmMonitoring.FailureInterval) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.FailureInterval) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Minimum Uptime' = Switch ($DasVmMonitoring.MinUptime) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "$($DasVmMonitoring.MinUptime) seconds"
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Per-VM Resets' = Switch ($DasVmMonitoring.MaxFailures) {
                                                                                $null { '--' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        $DasVmMonitoring.MaxFailures
                                                                                    }
                                                                                }
                                                                            }
                                                                            'Maximum Resets Time Window' = Switch ($DasVmMonitoring.MaxFailureWindow) {
                                                                                $null { '--' }
                                                                                '-1' { 'No window' }
                                                                                default {
                                                                                    if ($DasVmMonitoring.VmMonitoring -eq 'vmMonitoringDisabled') {
                                                                                        '--'
                                                                                    } else {
                                                                                        "Within $(($DasVmMonitoring.MaxFailureWindow)/3600) hrs"
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                    $TableParams = @{
                                                                        Name = "HA VM Overrides VM Monitoring - $Cluster"
                                                                        ColumnWidths = 40, 12, 12, 12, 12, 12
                                                                    }
                                                                    if ($Report.ShowTableCaptions) {
                                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                    }
                                                                    $DasVmOverrideVmMonitoring | Sort-Object 'Virtual Machine' | Table @TableParams
                                                                }
                                                                #endregion VM Monitoring Section
                                                            }
                                                        }
                                                        #endregion vSphere HA VM Overrides
                                                    }
                                                    #endregion VM Overrides Section
                                                }
                                                #endregion Cluster VM Overrides

                                                #region Cluster VUM Baselines
                                                if ($UserRole.Privilege -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                                                    if ($VUMConnection) {
                                                        if ("Desktop" -eq $PSVersionTable.PsEdition) {
                                                            $ClusterPatchBaselines = $Cluster | Get-PatchBaseline
                                                        } else {
                                                            Write-PScriboMessage 'Cluster VUM baseline information is not currently available with your version of PowerShell.'
                                                        }
                                                        if ($ClusterPatchBaselines) {
                                                            Section -Style Heading4 'Update Manager Baselines' {
                                                                $ClusterBaselines = foreach ($ClusterBaseline in $ClusterPatchBaselines) {
                                                                    [PSCustomObject]@{
                                                                        'Baseline' = $ClusterBaseline.Name
                                                                        'Description' = $ClusterBaseline.Description
                                                                        'Type' = $ClusterBaseline.BaselineType
                                                                        'Target Type' = $ClusterBaseline.TargetType
                                                                        'Last Update Time' = ($ClusterBaseline.LastUpdateTime).ToLocalTime()
                                                                        '# of Patches' = $ClusterBaseline.CurrentPatches.Count
                                                                    }
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Update Manager Baselines - $Cluster"
                                                                    ColumnWidths = 25, 25, 10, 10, 20, 10
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $ClusterBaselines | Sort-Object 'Baseline' | Table @TableParams
                                                            }
                                                        }
                                                        if ($Healthcheck.Cluster.VUMCompliance) {
                                                            $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                            $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                        }
                                                        $TableParams = @{
                                                            Name = "Update Manager Compliance - $Cluster"
                                                            ColumnWidths = 25, 50, 25
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $ClusterComplianceInfo | Sort-Object Name, Baseline | Table @TableParams
                                                    }
                                                } else {
                                                    Write-PScriboMessage "Insufficient user privileges to report Cluster baselines. Please ensure the user account has the 'VMware Update Manager / VMware vSphere Lifecycle Manager > Manage Patches and Upgrades > View Compliance Status' privilege assigned."
                                                }
                                                #endregion Cluster VUM Baselines

                                                #region Cluster VUM Compliance (Advanced Detail Information)
                                                if  ($UserRole.Privilege -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                                                    if ($InfoLevel.Cluster -ge 4 -and $VumServer.Name) {
                                                        if ("Desktop" -eq $PSVersionTable.PsEdition) {
                                                            $ClusterCompliances = $Cluster | Get-Compliance
                                                        } else {
                                                            Write-PScriboMessage 'Cluster VUM compliance information is not currently available with your version of PowerShell.'
                                                        }
                                                        if ($ClusterCompliances) {
                                                            Section -Style Heading4 'Update Manager Compliance' {
                                                                $ClusterComplianceInfo = foreach ($ClusterCompliance in $ClusterCompliances) {
                                                                    [PSCustomObject]@{
                                                                        'Entity' = $ClusterCompliance.Entity
                                                                        'Baseline' = $ClusterCompliance.Baseline.Name
                                                                        'Status' = Switch ($ClusterCompliance.Status) {
                                                                            'NotCompliant' { 'Not Compliant' }
                                                                            default { $ClusterCompliance.Status }
                                                                        }
                                                                    }
                                                                }
                                                                if ($Healthcheck.Cluster.VUMCompliance) {
                                                                    $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                                    $ClusterComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Update Manager Compliance - $Cluster"
                                                                    ColumnWidths = 25, 50, 25
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $ClusterComplianceInfo | Sort-Object Entity, Baseline | Table @TableParams
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    Write-PScriboMessage "Insufficient user privileges to report Cluster compliance. Please ensure the user account has the 'VMware Update Manager / VMware vSphere Lifecycle Manager > Manage Patches and Upgrades > View Compliance Status' privilege assigned."
                                                }

                                                #endregion Cluster VUM Compliance (Advanced Detail Information)

                                                #region Cluster Permissions
                                                Section -Style Heading4 'Permissions' {
                                                    Paragraph "The following table details the permissions assigned to cluster $Cluster."
                                                    BlankLine
                                                    $VIPermissions = $Cluster | Get-VIPermission
                                                    $ClusterVIPermissions = foreach ($VIPermission in $VIPermissions) {
                                                        [PSCustomObject]@{
                                                            'User/Group' = $VIPermission.Principal
                                                            'Is Group?' = Switch ($VIPermission.IsGroup) {
                                                                $true { 'Yes' }
                                                                $false { 'No' }
                                                            }
                                                            'Role' = $VIPermission.Role
                                                            'Defined In' = $VIPermission.Entity
                                                            'Propagate' = Switch ($VIPermission.Propagate) {
                                                                $true { 'Yes' }
                                                                $false { 'No' }
                                                            }
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "Permissions - $Cluster"
                                                        ColumnWidths = 42, 12, 20, 14, 12
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $ClusterVIPermissions | Sort-Object 'User/Group' | Table @TableParams
                                                }
                                                #endregion Cluster Permissions
                                            }
                                        }
                                        #endregion vSphere DRS Cluster Configuration
                                    }
                                    #endregion Cluster Section
                                }
                            }
                            #endregion Cluster Detailed Information
                        }
                        #endregion Cluster Section
                    }
                }
                #endregion Clusters

                #region Resource Pool Section
                Write-PScriboMessage "ResourcePool InfoLevel set at $($InfoLevel.ResourcePool)."
                if ($InfoLevel.ResourcePool -ge 1) {
                    $ResourcePools = Get-ResourcePool -Server $vCenter | Sort-Object Parent, Name
                    if ($ResourcePools) {
                        #region Resource Pools Section
                        Section -Style Heading2 'Resource Pools' {
                            Paragraph "The following sections detail the configuration of resource pools managed by vCenter Server $vCenterServerName."
                            #region Resource Pool Advanced Summary
                            if ($InfoLevel.ResourcePool -le 2) {
                                BlankLine
                                $ResourcePoolInfo = foreach ($ResourcePool in $ResourcePools) {
                                    [PSCustomObject]@{
                                        'Resource Pool' = $ResourcePool.Name
                                        'Parent' = $ResourcePool.Parent
                                        'CPU Shares Level' = $ResourcePool.CpuSharesLevel
                                        'CPU Reservation MHz' = $ResourcePool.CpuReservationMHz
                                        'CPU Limit MHz' = Switch ($ResourcePool.CpuLimitMHz) {
                                            '-1' { 'Unlimited' }
                                            default { $ResourcePool.CpuLimitMHz }
                                        }
                                        'Memory Shares Level' = $ResourcePool.MemSharesLevel
                                        'Memory Reservation' = [math]::Round($ResourcePool.MemReservationGB, 2)
                                        'Memory Limit GB' = Switch ($ResourcePool.MemLimitGB) {
                                            '-1' { 'Unlimited' }
                                            default { [math]::Round($ResourcePool.MemLimitGB, 2) }
                                        }
                                    }
                                }
                                $TableParams = @{
                                    Name = "Resource Pool Summary - $($vCenterServerName)"
                                    ColumnWidths = 20, 20, 10, 10, 10, 10, 10, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $ResourcePoolInfo | Sort-Object Name | Table @TableParams
                            }
                            #endregion Resource Pool Advanced Summary

                            #region Resource Pool Detailed Information
                            # TODO: Test Tags
                            if ($InfoLevel.ResourcePool -ge 3) {
                                foreach ($ResourcePool in $ResourcePools) {
                                    Section -Style Heading3 $ResourcePool.Name {
                                        $ResourcePoolDetail = [PSCustomObject]@{
                                            'Resource Pool' = $ResourcePool.Name
                                            'ID' = $ResourcePool.Id
                                            'Parent' = $ResourcePool.Parent
                                            'CPU Shares Level' = $ResourcePool.CpuSharesLevel
                                            'Number of CPU Shares' = $ResourcePool.NumCpuShares
                                            'CPU Reservation' = "$($ResourcePool.CpuReservationMHz) MHz"
                                            'CPU Expandable Reservation' = Switch ($ResourcePool.CpuExpandableReservation) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'CPU Limit MHz' = Switch ($ResourcePool.CpuLimitMHz) {
                                                '-1' { 'Unlimited' }
                                                default { "$($ResourcePool.CpuLimitMHz) MHz" }
                                            }
                                            'Memory Shares Level' = $ResourcePool.MemSharesLevel
                                            'Number of Memory Shares' = $ResourcePool.NumMemShares
                                            'Memory Reservation' = "$([math]::Round($ResourcePool.MemReservationGB, 2)) GB"
                                            'Memory Expandable Reservation' = Switch ($ResourcePool.MemExpandableReservation) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Memory Limit' = Switch ($ResourcePool.MemLimitGB) {
                                                '-1' { 'Unlimited' }
                                                default { "$([math]::Round($ResourcePool.MemLimitGB, 2)) GB" }
                                            }
                                            'Number of VMs' = $ResourcePool.ExtensionData.VM.Count
                                        }
                                        <#
                                        $MemberProps = @{
                                            'InputObject' = $ResourcePoolDetail
                                            'MemberType' = 'NoteProperty'
                                        }

                                        if ($TagAssignments | Where-Object {$_.entity -eq $ResourcePool}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $ResourcePool}).Tag -join ',')
                                        }
                                        #>
                                        #region Resource Pool Advanced Detail Information
                                        if ($InfoLevel.ResourcePool -ge 4) {
                                            $ResourcePoolDetail | ForEach-Object {
                                                # Query for VMs by resource pool Id
                                                $ResourcePoolId = $_.Id
                                                $ResourcePoolVMs = $VMs | Where-Object { $_.ResourcePoolId -eq $ResourcePoolId } | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($ResourcePoolVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Resource Pool Advanced Detail Information
                                        $TableParams = @{
                                            Name = "Resource Pool Configuration - $($ResourcePool.Name)"
                                            List = $true
                                            ColumnWidths = 50, 50
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
                #endregion Resource Pool Section

                #region ESXi VMHost Section
                Write-PScriboMessage "VMHost InfoLevel set at $($InfoLevel.VMHost)."
                if ($InfoLevel.VMHost -ge 1) {
                    if ($VMHosts) {
                        #region Hosts Section
                        Section -Style Heading2 'Hosts' {
                            Paragraph "The following sections detail the configuration of VMware ESXi hosts managed by vCenter Server $vCenterServerName."
                            #region ESXi Host Advanced Summary
                            if ($InfoLevel.VMHost -le 2) {
                                BlankLine
                                $VMHostInfo = foreach ($VMHost in $VMHosts) {
                                    [PSCustomObject]@{
                                        'Host' = $VMHost.Name
                                        'Version' = $VMHost.Version
                                        'Build' = $VMHost.Build
                                        'Parent' = $VMHost.Parent
                                        'Connection State' = Switch ($VMHost.ConnectionState) {
                                            'NotResponding' { 'Not Responding' }
                                            default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                                        }
                                        'CPU Sockets' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
                                        'CPU Cores' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
                                        'Memory GB' = [math]::Round($VMHost.MemoryTotalGB, 0)
                                        '# of VMs' = $VMHost.ExtensionData.Vm.Count
                                    }
                                }
                                if ($Healthcheck.VMHost.ConnectionState) {
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Maintenance' } | Set-Style -Style Warning
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Not Responding' } | Set-Style -Style Critical
                                    $VMHostInfo | Where-Object { $_.'Connection State' -eq 'Disconnected' } | Set-Style -Style Critical
                                }
                                $TableParams = @{
                                    Name = "Host Summary - $($vCenterServerName)"
                                    ColumnWidths = 17, 9, 11, 15, 13, 9, 9, 9, 8
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMHostInfo | Table @TableParams
                            }
                            #endregion ESXi Host Advanced Summary

                            #region ESXi Host Detailed Information
                            if ($InfoLevel.VMHost -ge 3) {
                                #region foreach VMHost Detailed Information loop
                                foreach ($VMHost in ($VMHosts | Where-Object { $_.ConnectionState -eq 'Connected' -or $_.ConnectionState -eq 'Maintenance' })) {
                                    #region VMHost Section
                                    Section -Style Heading3 $VMHost {
                                        # TODO: Host Certificate, Swap File Location
                                        # TODO: Test Tags
                                        #region ESXi Host Hardware Section
                                        Section -Style Heading4 'Hardware' {
                                            Paragraph "The following section details the host hardware configuration for $VMHost."
                                            BlankLine

                                            #region ESXi Host Specifications
                                            $VMHostUptime = Get-Uptime -VMHost $VMHost
                                            $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                            $ScratchLocation = Get-AdvancedSetting -Entity $VMHost | Where-Object { $_.Name -eq 'ScratchConfig.CurrentScratchLocation' }
                                            $VMHostDetail = [PSCustomObject]@{
                                                'Host' = $VMHost.Name
                                                'Connection State' = Switch ($VMHost.ConnectionState) {
                                                    'NotResponding' { 'Not Responding' }
                                                    default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                                                }
                                                'ID' = $VMHost.Id
                                                'Parent' = $VMHost.Parent
                                                'Manufacturer' = $VMHost.Manufacturer
                                                'Model' = $VMHost.Model
                                                'Serial Number' = Switch ($VMHost.ExtensionData.Hardware.SystemInfo.SerialNumber) {
                                                    $null { '--' }
                                                    default { $VMHost.ExtensionData.Hardware.SystemInfo.SerialNumber }
                                                }
                                                'Asset Tag' = Switch ($VMHost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo[0].IdentifierValue) {
                                                    '' { 'Unknown' }
                                                    $null  { 'Unknown' }
                                                    default { $VMHost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo[0].IdentifierValue }
                                                }
                                                'Processor Type' = $VMHost.Processortype
                                                'HyperThreading' = Switch ($VMHost.HyperthreadingActive) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                }
                                                'Number of CPU Sockets' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
                                                'Number of CPU Cores' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
                                                'Number of CPU Threads' = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuThreads
                                                'CPU Total / Used' = "$([math]::Round(($VMHost.CpuTotalMhz) / 1000, 2)) GHz / $([math]::Round(($VMHost.CpuUsageMhz) / 1000, 2)) GHz"
                                                'Memory Total / Used' = "$([math]::Round($VMHost.MemoryTotalGB, 2)) GB / $([math]::Round($VMHost.MemoryUsageGB, 2)) GB"
                                                'NUMA Nodes' = $VMHost.ExtensionData.Hardware.NumaInfo.NumNodes
                                                'Number of NICs' = $VMHost.ExtensionData.Summary.Hardware.NumNics
                                                'Number of HBAs' = $VMHost.ExtensionData.Summary.Hardware.NumHBAs
                                                'Number of Datastores' = ($VMHost.ExtensionData.Datastore).Count
                                                'Number of VMs' = $VMHost.ExtensionData.VM.Count
                                                'Maximum EVC Mode' = $EvcModeLookup."$($VMHost.MaxEVCMode)"
                                                'EVC Graphics Mode' = Switch ($VMHost.ExtensionData.Summary.CurrentEVCGraphicsModeKey) {
                                                    $null { 'Not applicable'}
                                                    default { $VMHost.ExtensionData.Summary.CurrentEVCGraphicsModeKey }
                                                }
                                                'Power Management Policy' = $VMHost.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy
                                                'Scratch Location' = $ScratchLocation.Value
                                                'Bios Version' = $VMHost.ExtensionData.Hardware.BiosInfo.BiosVersion
                                                'Bios Release Date' = $VMHost.ExtensionData.Hardware.BiosInfo.ReleaseDate
                                                'ESXi Version' = $VMHost.Version
                                                'ESXi Build' = $VMHost.build
                                                'Boot Time' = ($VMHost.ExtensionData.Runtime.Boottime).ToLocalTime()
                                                'Uptime Days' = $VMHostUptime.UptimeDays
                                            }
                                            $MemberProps = @{
                                                'InputObject' = $VMHostDetail
                                                'MemberType' = 'NoteProperty'
                                            }
                                            if ($UserRole.Privilege -contains 'Global.Licenses') {
                                                $VMHostLicense = Get-License -VMHost $VMHost
                                                Add-Member @MemberProps -Name 'Product' -Value $VMHostLicense.Product
                                                Add-Member @MemberProps -Name 'License Key' -Value $VMHostLicense.LicenseKey
                                                Add-Member @MemberProps -Name 'License Expiration' -Value $VMHostLicense.Expiration
                                            } else {
                                                Write-PScriboMessage "Insufficient user privileges to report ESXi host licensing. Please ensure the user account has the 'Global > Licenses' privilege assigned."
                                            }
                                            <#
                                            if ($TagAssignments | Where-Object {$_.entity -eq $VMHost}) {
                                                Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $VMHost}).Tag -join ',')
                                            }
                                            #>
                                            if ($Healthcheck.VMHost.ConnectionState) {
                                                $VMHostDetail | Where-Object { $_.'Connection State' -eq 'Maintenance' } | Set-Style -Style Warning -Property 'Connection State'
                                            }
                                            if ($Healthcheck.VMHost.HyperThreading) {
                                                $VMHostDetail | Where-Object { $_.'HyperThreading' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Disabled'
                                            }
                                            if ($Healthcheck.VMHost.Licensing) {
                                                $VMHostDetail | Where-Object { $_.'Product' -like '*Evaluation*' } | Set-Style -Style Warning -Property 'Product'
                                                $VMHostDetail | Where-Object { $_.'License Key' -like '*-00000-00000' } | Set-Style -Style Warning -Property 'License Key'
                                                $VMHostDetail | Where-Object { $_.'License Expiration' -eq 'Expired' } | Set-Style -Style Critical -Property 'License Expiration'
                                            }
                                            if ($Healthcheck.VMHost.ScratchLocation) {
                                                $VMHostDetail | Where-Object { $_.'Scratch Location' -eq '/tmp/scratch' } | Set-Style -Style Warning -Property 'Scratch Location'
                                            }
                                            if ($Healthcheck.VMHost.UpTimeDays) {
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 275 -and $_.'Uptime Days' -lt 365 } | Set-Style -Style Warning -Property 'Uptime Days'
                                                $VMHostDetail | Where-Object { $_.'Uptime Days' -ge 365 } | Set-Style -Style Critical -Property 'Uptime Days'
                                            }
                                            $TableParams = @{
                                                Name = "Hardware Configuration - $VMHost"
                                                List = $true
                                                ColumnWidths = 50, 50
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VMHostDetail | Table @TableParams
                                            #endregion ESXi Host Specifications

                                            #region ESXi IPMI/BMC Settings
                                            Try {
                                                $VMHostIPMI = $esxcli.hardware.ipmi.bmc.get.invoke()
                                            } Catch {
                                                Write-PScriboMessage -IsWarning "Unable to collect IPMI / BMC  configuration from $VMHost"
                                            }
                                            if ($VMHostIPMI) {
                                                Section -Style Heading5 'IPMI / BMC' {
                                                    $VMHostIPMIInfo = [PSCustomObject]@{
                                                        'Manufacturer' = $VMHostIPMI.Manufacturer
                                                        'MAC Address' = $VMHostIPMI.MacAddress
                                                        'IP Address' = $VMHostIPMI.IPv4Address
                                                        'Subnet Mask' = $VMHostIPMI.IPv4Subnet
                                                        'Gateway' = $VMHostIPMI.IPv4Gateway
                                                        'Firmware Version' = $VMHostIPMI.BMCFirmwareVersion
                                                    }

                                                    $TableParams = @{
                                                        Name = "IPMI / BMC - $VMHost"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHostIPMIInfo | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi IPMI/BMC Settings

                                            #region ESXi Host Boot Device
                                            Section -Style Heading5 'Boot Device' {
                                                $ESXiBootDevice = Get-ESXiBootDevice -VMHost $VMHost
                                                $VMHostBootDevice = [PSCustomObject]@{
                                                    'Host' = $ESXiBootDevice.Host
                                                    'Device' = $ESXiBootDevice.Device
                                                    'Boot Type' = $ESXiBootDevice.BootType
                                                    'Vendor' = $ESXiBootDevice.Vendor
                                                    'Model' = $ESXiBootDevice.Model
                                                    'Size' = Switch ($ESXiBootDevice.SizeMB) {
                                                        'N/A' { 'N/A' }
                                                        default { "$([math]::Round($ESXiBootDevice.SizeMB / 1024, 2)) GB" }
                                                    }
                                                    'Is SAS' = $ESXiBootDevice.IsSAS
                                                    'Is SSD' = $ESXiBootDevice.IsSSD
                                                    'Is USB' = $ESXiBootDevice.IsUSB
                                                }
                                                $TableParams = @{
                                                    Name = "Boot Device - $VMHost"
                                                    List = $true
                                                    ColumnWidths = 50, 50
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMHostBootDevice | Table @TableParams
                                            }
                                            #endregion ESXi Host Boot Devices

                                            #region ESXi Host PCI Devices
                                            Section -Style Heading5 'PCI Devices' {
                                                $PciHardwareDevices = $esxcli.hardware.pci.list.Invoke() | Where-Object { $_.VMkernelName -match 'vmhba|vmnic|vmgfx' -and $_.ModuleName -ne 'None'} | Sort-Object -Property VMkernelName
                                                $VMHostPciDevices = foreach ($PciHardwareDevice in $PciHardwareDevices) {
                                                    [PSCustomObject]@{
                                                        'Device' = $PciHardwareDevice.VMkernelName
                                                        'PCI Address' = $PciHardwareDevice.Address
                                                        'Device Class' = $PciHardwareDevice.DeviceClassName
                                                        'Device Name' = $PciHardwareDevice.DeviceName
                                                        'Vendor Name' = $PciHardwareDevice.VendorName
                                                        'Slot Description' = $PciHardwareDevice.SlotDescription
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "PCI Devices - $VMHost"
                                                    ColumnWidths = 12, 13, 15, 25, 20, 15
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMHostPciDevices | Table @TableParams
                                            }
                                            #endregion ESXi Host PCI Devices

                                            #region ESXi Host PCI Devices Drivers & Firmware
                                            Section -Style Heading5 'PCI Devices Drivers & Firmware' {
                                                $VMHostPciDevicesDetails = Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli | Sort-Object 'Device'
                                                $TableParams = @{
                                                    Name = "PCI Devices Drivers & Firmware - $VMHost"
                                                    ColumnWidths = 12, 20, 11, 19, 11, 11, 16
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMHostPciDevicesDetails | Table @TableParams
                                            }
                                            #endregion ESXi Host PCI Devices Drivers & Firmware
                                        }
                                        #endregion ESXi Host Hardware Section

                                        #region ESXi Host System Section
                                        Section -Style Heading4 'System' {
                                            Paragraph "The following section details the host system configuration for $VMHost."
                                            #region ESXi Host Profile Information
                                            if ($VMHost | Get-VMHostProfile) {
                                                Section -Style Heading5 'Host Profile' {
                                                    $VMHostProfile = $VMHost | Get-VMHostProfile | Select-Object Name, Description
                                                    $TableParams = @{
                                                        Name = "Host Profile - $VMHost"
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHostProfile | Sort-Object Name | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi Host Profile Information

                                            #region ESXi Host Image Profile Information
                                            if ($UserRole.Privilege -contains 'Host.Config.Settings') {
                                                Section -Style Heading5 'Image Profile' {
                                                    $installdate = Get-InstallDate
                                                    $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                                    $ImageProfile = $esxcli.software.profile.get.Invoke()
                                                    $SecurityProfile = [PSCustomObject]@{
                                                        'Image Profile' = $ImageProfile.Name
                                                        'Vendor' = $ImageProfile.Vendor
                                                        'Installation Date' = $InstallDate.InstallDate
                                                    }
                                                    $TableParams = @{
                                                        Name = "Image Profile - $VMHost"
                                                        #ColumnWidths = 50, 25, 25
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $SecurityProfile | Table @TableParams
                                                }
                                            } else {
                                                Write-PScriboMessage "Insufficient user privileges to report ESXi host image profiles. Please ensure the user account has the 'Host > Configuration > Change settings' privilege assigned."
                                            }
                                            #endregion ESXi Host Image Profile Information

                                            #region ESXi Host Time Configuration
                                            Section -Style Heading5 'Time Configuration' {
                                                $VMHostTimeSettings = [PSCustomObject]@{
                                                    'Time Zone' = $VMHost.timezone
                                                    'NTP Service' = Switch ((Get-VMHostService -VMHost $VMHost | Where-Object { $_.key -eq 'ntpd' }).Running) {
                                                        $true { 'Running' }
                                                        $false { 'Stopped' }
                                                    }
                                                    'NTP Server(s)' = (Get-VMHostNtpServer -VMHost $VMHost | Sort-Object) -join ', '
                                                }
                                                if ($Healthcheck.VMHost.NTP) {
                                                    $VMHostTimeSettings | Where-Object { $_.'NTP Service' -eq 'Stopped' } | Set-Style -Style Critical -Property 'NTP Service'
                                                }
                                                $TableParams = @{
                                                    Name = "Time Configuration - $VMHost"
                                                    ColumnWidths = 30, 30, 40
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMHostTimeSettings | Table @TableParams
                                            }
                                            #endregion ESXi Host Time Configuration

                                            #region ESXi Host Syslog Configuration
                                            $SyslogConfig = $VMHost | Get-VMHostSysLogServer
                                            if ($SyslogConfig) {
                                                Section -Style Heading5 'Syslog Configuration' {
                                                    # TODO: Syslog Rotate & Size, Log Directory (Adv Settings)
                                                    $SyslogConfig = $SyslogConfig | Select-Object @{L = 'SysLog Server'; E = { $_.Host } }, Port
                                                    $TableParams = @{
                                                        Name = "Syslog Configuration - $VMHost"
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $SyslogConfig | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi Host Syslog Configuration

                                            #region ESXi Update Manager Baseline Information
                                            if ($UserRole.Privilege -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                                                if ($VumServer.Name) {
                                                    if ("Desktop" -eq $PSVersionTable.PsEdition) {
                                                        $VMHostPatchBaselines = $VMHost | Get-PatchBaseline
                                                    } else {
                                                        Write-PScriboMessage 'ESXi VUM baseline information is not currently available with your version of PowerShell.'
                                                    }
                                                    if ($VMHostPatchBaselines) {
                                                        Section -Style Heading5 'Update Manager Baselines' {
                                                            $VMHostBaselines = foreach ($VMHostBaseline in $VMHostPatchBaselines) {
                                                                [PSCustomObject]@{
                                                                    'Baseline' = $VMHostBaseline.Name
                                                                    'Description' = $VMHostBaseline.Description
                                                                    'Type' = $VMHostBaseline.BaselineType
                                                                    'Target Type' = $VMHostBaseline.TargetType
                                                                    'Last Update Time' = $VMHostBaseline.LastUpdateTime
                                                                    '# of Patches' = $VMHostBaseline.CurrentPatches.Count
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "Update Manager Baselines - $VMHost"
                                                                ColumnWidths = 25, 25, 10, 10, 20, 10
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VMHostBaselines | Sort-Object 'Baseline' | Table @TableParams
                                                        }
                                                    }
                                                }
                                            } else {
                                                Write-PScriboMessage "Insufficient user privileges to report ESXi host baselines. Please ensure the user account has the 'VMware Update Manager / VMware vSphere Lifecycle Manager > Manage Patches and Upgrades > View Compliance Status' privilege assigned."
                                            }
                                            #endregion ESXi Update Manager Baseline Information

                                            #region ESXi Update Manager Compliance Information
                                            if  ($UserRole.Privilege -contains 'VcIntegrity.Updates.com.vmware.vcIntegrity.ViewStatus') {
                                                if ($VumServer.Name) {
                                                    if ("Desktop" -eq $PSVersionTable.PsEdition) {
                                                        $VMHostCompliances = $VMHost | Get-Compliance
                                                    } else {
                                                        Write-PScriboMessage 'ESXi VUM compliance information is not currently available with your version of PowerShell.'
                                                    }
                                                    if ($VMHostCompliances) {
                                                        Section -Style Heading5 'Update Manager Compliance' {
                                                            $VMHostComplianceInfo = foreach ($VMHostCompliance in $VMHostCompliances) {
                                                                [PSCustomObject]@{
                                                                    'Baseline' = $VMHostCompliance.Baseline.Name
                                                                    'Status' = Switch ($VMHostCompliance.Status) {
                                                                        'NotCompliant' { 'Not Compliant' }
                                                                        default { $VMHostCompliance.Status }
                                                                    }
                                                                }
                                                            }
                                                            if ($Healthcheck.VMHost.VUMCompliance) {
                                                                $VMHostComplianceInfo | Where-Object { $_.Status -eq 'Unknown' } | Set-Style -Style Warning
                                                                $VMHostComplianceInfo | Where-Object { $_.Status -eq 'Not Compliant' -or $_.Status -eq 'Incompatible' } | Set-Style -Style Critical
                                                            }
                                                            $TableParams = @{
                                                                Name = "Update Manager Compliance - $VMHost"
                                                                ColumnWidths = 75, 25
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VMHostComplianceInfo | Sort-Object Baseline | Table @TableParams
                                                        }
                                                    }
                                                }
                                            } else {
                                                Write-PScriboMessage "Insufficient user privileges to report ESXi host compliance. Please ensure the user account has the 'VMware Update Manager / VMware vSphere Lifecycle Manager > Manage Patches and Upgrades > View Compliance Status' privilege assigned."
                                            }
                                            #endregion ESXi Update Manager Compliance Information

                                            #region ESXi Host Comprehensive Information Section
                                            if ($InfoLevel.VMHost -ge 5) {
                                                #region ESXi Host Advanced System Settings
                                                Section -Style Heading5 'Advanced System Settings' {
                                                    $AdvSettings = $VMHost | Get-AdvancedSetting | Select-Object Name, Value
                                                    $TableParams = @{
                                                        Name = "Advanced System Settings - $VMHost"
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $AdvSettings | Sort-Object Name | Table @TableParams
                                                }
                                                #endregion ESXi Host Advanced System Settings

                                                #region ESXi Host Software VIBs
                                                Section -Style Heading5 'Software VIBs' {
                                                    $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                                                    $VMHostVibs = $esxcli.software.vib.list.Invoke()
                                                    $VMHostVibs = foreach ($VMHostVib in $VMHostVibs) {
                                                        [PSCustomObject]@{
                                                            'VIB' = $VMHostVib.Name
                                                            'ID' = $VMHostVib.Id
                                                            'Version' = $VMHostVib.Version
                                                            'Acceptance Level' = $VMHostVib.AcceptanceLevel
                                                            'Creation Date' = $VMHostVib.CreationDate
                                                            'Install Date' = $VMHostVib.InstallDate
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "Software VIBs - $VMHost"
                                                        ColumnWidths = 15, 25, 15, 15, 15, 15
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHostVibs | Sort-Object 'Install Date' -Descending | Table @TableParams
                                                }
                                                #endregion ESXi Host Software VIBs
                                            }
                                            #endregion ESXi Host Comprehensive Information Section
                                        }
                                        #endregion ESXi Host System Section

                                        #region ESXi Host Storage Section
                                        Section -Style Heading4 'Storage' {
                                            Paragraph "The following section details the host storage configuration for $VMHost."

                                            #region ESXi Host Datastore Specifications
                                            $VMHostDatastores = $VMHost | Get-Datastore | Where-Object { ($_.State -eq 'Available') -and ($_.CapacityGB -gt 0) } | Sort-Object Name
                                            if ($VMHostDatastores) {
                                                Section -Style Heading5 'Datastores' {
                                                    $VMHostDsSpecs = foreach ($VMHostDatastore in $VMHostDatastores) {
                                                        [PSCustomObject]@{
                                                            'Datastore' = $VMHostDatastore.Name
                                                            'Type' = $VMHostDatastore.Type
                                                            'Version' = Switch ($VMHostDatastore.FileSystemVersion) {
                                                                $null { '--' }
                                                                default { $VMHostDatastore.FileSystemVersion }
                                                            }
                                                            '# of VMs' = $VMHostDatastore.ExtensionData.VM.Count
                                                            'Total Capacity GB' = [math]::Round($VMHostDatastore.CapacityGB, 2)
                                                            'Used Capacity GB' = [math]::Round((($VMHostDatastore.CapacityGB) - ($VMHostDatastore.FreeSpaceGB)), 2)
                                                            'Free Space GB' = [math]::Round($VMHostDatastore.FreeSpaceGB, 2)
                                                            '% Used' = [math]::Round((100 - (($VMHostDatastore.FreeSpaceGB) / ($VMHostDatastore.CapacityGB) * 100)), 2)
                                                        }
                                                    }
                                                    if ($Healthcheck.Datastore.CapacityUtilization) {
                                                        $VMHostDsSpecs | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical
                                                        $VMHostDsSpecs | Where-Object { $_.'% Used' -ge 75 -and $_.'% Used' -lt 90 } | Set-Style -Style Warning
                                                    }
                                                    $TableParams = @{
                                                        Name = "Datastores - $VMHost"
                                                        ColumnWidths = 20, 8, 9, 8, 15, 15, 15, 10
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHostDsSpecs | Sort-Object 'Datastore' | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi Host Datastore Specifications

                                            #region ESXi Host Storage Adapter Information
                                            $VMHostHbas = $VMHost | Get-VMHostHba | Sort-Object Device
                                            if ($VMHostHbas) {
                                                #region ESXi Host Storage Adapters Section
                                                Section -Style Heading5 'Storage Adapters' {
                                                    Paragraph "The following section details the storage adapter configuration for $VMHost."
                                                    foreach ($VMHostHba in $VMHostHbas) {
                                                        $Target = ((Get-View $VMHostHba.VMhost).Config.StorageDevice.ScsiTopology.Adapter | Where-Object { $_.Adapter -eq $VMHostHba.Key }).Target
                                                        $LUNs = Get-ScsiLun -Hba $VMHostHba -LunType "disk" -ErrorAction SilentlyContinue
                                                        $Paths = ($Target | foreach { $_.Lun.Count } | Measure-Object -Sum)
                                                        Section -Style Heading5 "$($VMHostHba.Device)" {
                                                            $VMHostStorageAdapter = [PSCustomObject]@{
                                                                'Adapter' = $VMHostHba.Device
                                                                'Type' = Switch ($VMHostHba.Type) {
                                                                    'FibreChannel' { 'Fibre Channel' }
                                                                    'IScsi' { 'iSCSI' }
                                                                    'ParallelScsi' { 'Parallel SCSI' }
                                                                    default { $TextInfo.ToTitleCase($VMHostHba.Type) }
                                                                }
                                                                'Model' = $VMHostHba.Model
                                                                'Status' = $TextInfo.ToTitleCase($VMHostHba.Status)
                                                                'Targets' = $Target.Count
                                                                'Devices' = $LUNs.Count
                                                                'Paths' = $Paths.Sum
                                                            }
                                                            $MemberProps = @{
                                                                'InputObject' = $VMHostStorageAdapter
                                                                'MemberType' = 'NoteProperty'
                                                            }
                                                            if ($VMHostStorageAdapter.Type -eq 'iSCSI') {
                                                                $iScsiAuthenticationMethod = Switch ($VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType) {
                                                                    'chapProhibited' { 'None' }
                                                                    'chapPreferred' { 'Use unidirectional CHAP unless prohibited by target' }
                                                                    'chapDiscouraged' { 'Use unidirectional CHAP if required by target' }
                                                                    'chapRequired' {
                                                                        Switch ($VMHostHba.ExtensionData.AuthenticationProperties.MutualChapAuthenticationType) {
                                                                            'chapProhibited' { 'Use unidirectional CHAP' }
                                                                            'chapRequired' { 'Use bidirectional CHAP' }
                                                                        }
                                                                    }
                                                                    default { $VMHostHba.ExtensionData.AuthenticationProperties.ChapAuthenticationType }
                                                                }
                                                                Add-Member @MemberProps -Name 'iSCSI Name' -Value $VMHostHba.IScsiName
                                                                if ($VMHostHba.IScsiAlias) {
                                                                    Add-Member @MemberProps -Name 'iSCSI Alias' -Value $VMHostHba.IScsiAlias
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'iSCSI Alias' -Value '--'
                                                                }
                                                                if ($VMHostHba.CurrentSpeedMb) {
                                                                    Add-Member @MemberProps -Name 'Speed' -Value "$($VMHostHba.CurrentSpeedMb) Mb"
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Speed' -Value '--'
                                                                }
                                                                if ($VMHostHba.ExtensionData.ConfiguredSendTarget) {
                                                                    Add-Member @MemberProps -Name 'Dynamic Discovery' -Value (($VMHostHba.ExtensionData.ConfiguredSendTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" }) -join [Environment]::NewLine)
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Dynamic Discovery' -Value '--'
                                                                }
                                                                if ($VMHostHba.ExtensionData.ConfiguredStaticTarget) {
                                                                    Add-Member @MemberProps -Name 'Static Discovery' -Value (($VMHostHba.ExtensionData.ConfiguredStaticTarget | ForEach-Object { "$($_.Address)" + ":" + "$($_.Port)" + "  " + "$($_.IScsiName)" }) -join [Environment]::NewLine)
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Static Discovery' -Value '--'
                                                                }
                                                                if ($iScsiAuthenticationMethod -eq 'None') {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                } elseif ($iScsiAuthenticationMethod -eq 'Use bidirectional CHAP') {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                    Add-Member @MemberProps -Name 'Outgoing CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                                                    Add-Member @MemberProps -Name 'Incoming CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.MutualChapName
                                                                } else {
                                                                    Add-Member @MemberProps -Name 'Authentication Method' -Value $iScsiAuthenticationMethod
                                                                    Add-Member @MemberProps -Name 'Outgoing CHAP Name' -Value $VMHostHba.ExtensionData.AuthenticationProperties.ChapName
                                                                }
                                                                if ($InfoLevel.VMHost -ge 4) {
                                                                    Add-Member @MemberProps -Name 'Advanced Options' -Value (($VMHostHba.ExtensionData.AdvancedOptions | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join [Environment]::NewLine)
                                                                }
                                                            }
                                                            if ($VMHostStorageAdapter.Type -eq 'Fibre Channel') {
                                                                Add-Member @MemberProps -Name 'Node WWN' -Value (([String]::Format("{0:X}", $VMHostHba.NodeWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                                                Add-Member @MemberProps -Name 'Port WWN' -Value (([String]::Format("{0:X}", $VMHostHba.PortWorldWideName) -split "(\w{2})" | Where-Object { $_ -ne "" }) -join ":")
                                                                Add-Member @MemberProps -Name 'Speed' -Value $VMHostHba.Speed
                                                            }
                                                            if ($Healthcheck.VMHost.StorageAdapter) {
                                                                $VMHostStorageAdapter | Where-Object { $_.'Status' -ne 'Online' } | Set-Style -Style Warning -Property 'Status'
                                                                $VMHostStorageAdapter | Where-Object { $_.'Status' -eq 'Offline' } | Set-Style -Style Critical -Property 'Status'
                                                            }
                                                            $TableParams = @{
                                                                Name = "Storage Adapter $($VMHostStorageAdapter.Adapter) - $VMHost"
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
                                        #endregion ESXi Host Storage Section

                                        #region ESXi Host Network Section
                                        Section -Style Heading4 'Network' {
                                            Paragraph "The following section details the host network configuration for $VMHost."
                                            BlankLine
                                            #region ESXi Host Network Configuration
                                            $VMHostNetwork = $VMHost.ExtensionData.Config.Network
                                            $VMHostVirtualSwitch = @()
                                            $VMHostVss = foreach ($vSwitch in $VMHost.ExtensionData.Config.Network.Vswitch) {
                                                $VMHostVirtualSwitch += $vSwitch.Name
                                            }
                                            $VMHostDvs = foreach ($dvSwitch in $VMHost.ExtensionData.Config.Network.ProxySwitch) {
                                                $VMHostVirtualSwitch += $dvSwitch.DvsName
                                            }
                                            $VMHostNetworkDetail = [PSCustomObject]@{
                                                'Host' = $VMHost.Name
                                                'Virtual Switches' = ($VMHostVirtualSwitch | Sort-Object) -join ', '
                                                'VMkernel Adapters' = ($VMHostNetwork.Vnic.Device | Sort-Object) -join ', '
                                                'Physical Adapters' = ($VMHostNetwork.Pnic.Device | Sort-Object) -join ', '
                                                'VMkernel Gateway' = $VMHostNetwork.IpRouteConfig.DefaultGateway
                                                'IPv6' = Switch ($VMHostNetwork.IPv6Enabled) {
                                                    $true { 'Enabled' }
                                                    $false { 'Disabled' }
                                                }
                                                'VMkernel IPv6 Gateway' = Switch ($VMHostNetwork.IpRouteConfig.IpV6DefaultGateway) {
                                                    $null { '--' }
                                                    default { $VMHostNetwork.IpRouteConfig.IpV6DefaultGateway }
                                                }
                                                'DNS Servers' = ($VMHostNetwork.DnsConfig.Address | Sort-Object) -join ', '
                                                'Host Name' = $VMHostNetwork.DnsConfig.HostName
                                                'Domain Name' = $VMHostNetwork.DnsConfig.DomainName
                                                'Search Domain' = ($VMHostNetwork.DnsConfig.SearchDomain | Sort-Object) -join ', '
                                            }
                                            if ($Healthcheck.VMHost.IPv6) {
                                                $VMHostNetworkDetail | Where-Object { $_.'IPv6' -eq $false } | Set-Style -Style Warning -Property 'IPv6'
                                            }
                                            $TableParams = @{
                                                Name = "Network Configuration - $VMHost"
                                                List = $true
                                                ColumnWidths = 50, 50
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VMHostNetworkDetail | Table @TableParams
                                            #endregion ESXi Host Network Configuration

                                            #region ESXi Host Physical Adapters
                                            Section -Style Heading5 'Physical Adapters' {
                                                Paragraph "The following section details the physical network adapter configuration for $VMHost."
                                                $PhysicalNetAdapters = $VMHost.ExtensionData.Config.Network.Pnic | Sort-Object Device
                                                $VMHostPhysicalNetAdapters = foreach ($PhysicalNetAdapter in $PhysicalNetAdapters) {
                                                    [PSCustomObject]@{
                                                        'Adapter' = $PhysicalNetAdapter.Device
                                                        'Status' = Switch ($PhysicalNetAdapter.Linkspeed) {
                                                            $null { 'Disconnected' }
                                                            default { 'Connected' }
                                                        }
                                                        'Virtual Switch' = $(
                                                            if ($VMHost.ExtensionData.Config.Network.Vswitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                                                ($VMHost.ExtensionData.Config.Network.Vswitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).Name
                                                            } elseif ($VMHost.ExtensionData.Config.Network.ProxySwitch.Pnic -contains $PhysicalNetAdapter.Key) {
                                                                ($VMHost.ExtensionData.Config.Network.ProxySwitch | Where-Object { $_.Pnic -eq $PhysicalNetAdapter.Key }).DvsName
                                                            } else {
                                                                '--'
                                                            }
                                                        )
                                                        'MAC Address' = $PhysicalNetAdapter.Mac
                                                        'Actual Speed, Duplex' = Switch ($PhysicalNetAdapter.LinkSpeed.SpeedMb) {
                                                            $null { 'Down' }
                                                            default {
                                                                if ($PhysicalNetAdapter.LinkSpeed.Duplex) {
                                                                    "$($PhysicalNetAdapter.LinkSpeed.SpeedMb) Mbps, Full Duplex"
                                                                } else {
                                                                    'Auto negotiate'
                                                                }
                                                            }
                                                        }
                                                        'Configured Speed, Duplex' = Switch ($PhysicalNetAdapter.Spec.LinkSpeed) {
                                                            $null { 'Auto negotiate' }
                                                            default {
                                                                if ($PhysicalNetAdapter.Spec.LinkSpeed.Duplex) {
                                                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mbps, Full Duplex"
                                                                } else {
                                                                    "$($PhysicalNetAdapter.Spec.LinkSpeed.SpeedMb) Mbps"
                                                                }
                                                            }
                                                        }
                                                        'Wake on LAN' = Switch ($PhysicalNetAdapter.WakeOnLanSupported) {
                                                            $true { 'Supported' }
                                                            $false { 'Not Supported' }
                                                        }
                                                    }
                                                }
                                                if ($Healthcheck.VMHost.NetworkAdapter) {
                                                    $VMHostPhysicalNetAdapters | Where-Object { $_.'Status' -ne 'Connected' } | Set-Style -Style Critical -Property 'Status'
                                                    $VMHostPhysicalNetAdapters | Where-Object { $_.'Actual Speed, Duplex' -eq 'Down' } | Set-Style -Style Critical -Property 'Actual Speed, Duplex'
                                                }
                                                if ($InfoLevel.VMHost -ge 4) {
                                                    foreach ($VMHostPhysicalNetAdapter in $VMHostPhysicalNetAdapters) {
                                                        Section -Style Heading5 "$($VMHostPhysicalNetAdapter.Adapter)" {
                                                            $TableParams = @{
                                                                Name = "Physical Adapter $($VMHostPhysicalNetAdapter.Adapter) - $VMHost"
                                                                List = $true
                                                                ColumnWidths = 50, 50
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VMHostPhysicalNetAdapter | Table @TableParams
                                                        }
                                                    }
                                                } else {
                                                    BlankLine
                                                    $TableParams = @{
                                                        Name = "Physical Adapters - $VMHost"
                                                        ColumnWidths = 11, 13, 15, 19, 14, 14, 14
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMHostPhysicalNetAdapters | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi Host Physical Adapters

                                            #region ESXi Host Cisco Discovery Protocol
                                            $VMHostNetworkAdapterCDP = $VMHost | Get-VMHostNetworkAdapterDP | Where-Object { $_.Status -eq 'Connected' } | Sort-Object Device
                                            if ($VMHostNetworkAdapterCDP) {
                                                Section -Style Heading5 'Cisco Discovery Protocol' {
                                                    Paragraph "The following section details the CDP information for $VMHost."
                                                    if ($InfoLevel.VMHost -ge 4) {
                                                        foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                                            Section -Style Heading5 "$($VMHostNetworkAdapter.Device)" {
                                                                $VMHostCDP = [PSCustomObject]@{
                                                                    'Status' = $VMHostNetworkAdapter.Status
                                                                    'System Name' = $VMHostNetworkAdapter.SystemName
                                                                    'Hardware Platform' = $VMHostNetworkAdapter.HardwarePlatform
                                                                    'Switch ID' = $VMHostNetworkAdapter.SwitchId
                                                                    'Software Version' = $VMHostNetworkAdapter.SoftwareVersion
                                                                    'Management Address' = $VMHostNetworkAdapter.ManagementAddress
                                                                    'Address' = $VMHostNetworkAdapter.Address
                                                                    'Port ID' = $VMHostNetworkAdapter.PortId
                                                                    'VLAN' = $VMHostNetworkAdapter.Vlan
                                                                    'MTU' = $VMHostNetworkAdapter.Mtu
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Network Adapter $($VMHostNetworkAdapter.Device) CDP Information - $VMHost"
                                                                    List = $true
                                                                    ColumnWidths = 50, 50
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $VMHostCDP | Table @TableParams
                                                            }
                                                        }
                                                    } else {
                                                        BlankLine
                                                        $VMHostCDP = foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterCDP) {
                                                            [PSCustomObject]@{
                                                                'Adapter' = $VMHostNetworkAdapter.Device
                                                                'Status' = $VMHostNetworkAdapter.Status
                                                                'Hardware Platform' = $VMHostNetworkAdapter.HardwarePlatform
                                                                'Switch ID' = $VMHostNetworkAdapter.SwitchId
                                                                'Address' = $VMHostNetworkAdapter.Address
                                                                'Port ID' = $VMHostNetworkAdapter.PortId
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "Network Adapter CDP Information - $VMHost"
                                                            ColumnWidths = 11, 13, 26, 22, 17, 11
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VMHostCDP | Table @TableParams
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host Cisco Discovery Protocol

                                            #region ESXi Host Link Layer Discovery Protocol
                                            $VMHostNetworkAdapterLLDP = $VMHost | Get-VMHostNetworkAdapterDP | Where-Object { $null -ne $_.ChassisId } | Sort-Object Device
                                            if ($VMHostNetworkAdapterLLDP) {
                                                Section -Style Heading5 'Link Layer Discovery Protocol' {
                                                    Paragraph "The following section details the LLDP information for $VMHost."
                                                    if ($InfoLevel.VMHost -ge 4) {
                                                        foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterLLDP) {
                                                            Section -Style Heading5 "$($VMHostNetworkAdapter.Device)" {
                                                                $VMHostLLDP = [PSCustomObject]@{
                                                                    'Chassis ID' = $VMHostNetworkAdapter.ChassisId
                                                                    'Port ID' = $VMHostNetworkAdapter.PortId
                                                                    'Time to live' = $VMHostNetworkAdapter.TimeToLive
                                                                    'TimeOut' = $VMHostNetworkAdapter.TimeOut
                                                                    'Samples' = $VMHostNetworkAdapter.Samples
                                                                    'Management Address' = $VMHostNetworkAdapter.ManagementAddress
                                                                    'Port Description' = $VMHostNetworkAdapter.PortDescription
                                                                    'System Description' = $VMHostNetworkAdapter.SystemDescription
                                                                    'System Name' = $VMHostNetworkAdapter.SystemName
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Network Adapter $($VMHostNetworkAdapter.Device) LLDP Information - $VMHost"
                                                                    List = $true
                                                                    ColumnWidths = 50, 50
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $VMHostLLDP | Table @TableParams
                                                            }
                                                        }
                                                    } else {
                                                        BlankLine
                                                        $VMHostLLDP = foreach ($VMHostNetworkAdapter in $VMHostNetworkAdapterLLDP) {
                                                            [PSCustomObject]@{
                                                                'Adapter' = $VMHostNetworkAdapter.Device
                                                                'Chassis ID' = $VMHostNetworkAdapter.ChassisId
                                                                'Port ID' = $VMHostNetworkAdapter.PortId
                                                                'Management Address' = $VMHostNetworkAdapter.ManagementAddress
                                                                'Port Description' = $VMHostNetworkAdapter.PortDescription
                                                                'System Name' = $VMHostNetworkAdapter.SystemName
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "Network Adapter LLDP Information - $VMHost"
                                                            ColumnWidths = 11, 19, 16, 19, 18, 17
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VMHostLLDP | Table @TableParams
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host Link Layer Discovery Protocol

                                            #region ESXi Host VMkernel Adapaters
                                            Section -Style Heading5 'VMkernel Adapters' {
                                                Paragraph "The following section details the VMkernel adapter configuration for $VMHost"
                                                $VMkernelAdapters = $VMHost | Get-View | ForEach-Object -Process {
                                                    $esx = $_
                                                    $netSys = Get-View -Id $_.ConfigManager.NetworkSystem
                                                    $vnicMgr = Get-View -Id $_.ConfigManager.VirtualNicManager
                                                    $netSys.NetworkInfo.Vnic |
                                                    ForEach-Object -Process {
                                                        $device = $_.Device
                                                        [PSCustomObject]@{
                                                            'Adapter' = $_.Device
                                                            'Network Label' = & {
                                                                if ($_.Spec.Portgroup) {
                                                                    $script:pg = $_.Spec.Portgroup
                                                                } else {
                                                                    $script:pg = Get-View -ViewType DistributedVirtualPortgroup -Property Name, Key -Filter @{'Key' = "$($_.Spec.DistributedVirtualPort.PortgroupKey)" } |
                                                                    Select-Object -ExpandProperty Name
                                                                }
                                                                $script:pg
                                                            }
                                                            'Virtual Switch' = & {
                                                                if ($_.Spec.Portgroup) {
                                                                    (Get-VirtualPortGroup -Standard -Name $script:pg -VMHost $VMHost).VirtualSwitchName
                                                                } else {
                                                                    (Get-VDPortgroup -Name $script:pg).VDSwitch.Name | Select-Object -Unique
                                                                }
                                                            }
                                                            'TCP/IP Stack' = Switch ($_.Spec.NetstackInstanceKey) {
                                                                'defaultTcpipStack' { 'Default' }
                                                                'vSphereProvisioning' { 'Provisioning' }
                                                                'vmotion' { 'vMotion' }
                                                                'vxlan' { 'nsx-overlay' }
                                                                'hyperbus' { 'nsx-hyperbus' }
                                                                $null { 'Not Applicable' }
                                                                default { $_.Spec.NetstackInstanceKey }
                                                            }
                                                            'MTU' = $_.Spec.Mtu
                                                            'MAC Address' = $_.Spec.Mac
                                                            'DHCP' = Switch ($_.Spec.Ip.Dhcp) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'IP Address' = & {
                                                                if ($_.Spec.IP.IPAddress) {
                                                                    $script:ip = $_.Spec.IP.IPAddress
                                                                } else {
                                                                    $script:ip = '--'
                                                                }
                                                                $script:ip
                                                            }
                                                            'Subnet Mask' = & {
                                                                if ($_.Spec.IP.SubnetMask) {
                                                                    $script:netmask = $_.Spec.IP.SubnetMask
                                                                } else {
                                                                    $script:netmask = '--'
                                                                }
                                                                $script:netmask
                                                            }
                                                            'Default Gateway' = Switch ($_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway) {
                                                                $null { '--' }
                                                                default { $_.Spec.IpRouteSpec.IpRouteConfig.DefaultGateway }
                                                            }
                                                            'vMotion' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vmotion' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'Provisioning' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereProvisioning' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'FT Logging' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'faultToleranceLogging' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'Management' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'management' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSphere Replication' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereReplication' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSphere Replication NFC' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereReplicationNFC' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSAN' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vsan' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSAN Witness' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vsanWitness' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                            'vSphere Backup NFC' = Switch ((($vnicMgr.Info.NetConfig | Where-Object { $_.NicType -eq 'vSphereBackupnNFC' }).SelectedVnic | ForEach-Object { $_ -match $device } ) -contains $true) {
                                                                $true { 'Enabled' }
                                                                $false { 'Disabled' }
                                                            }
                                                        }
                                                    }
                                                }
                                                foreach ($VMkernelAdapter in ($VMkernelAdapters | Sort-Object 'Adapter')) {
                                                    Section -Style Heading5 "$($VMkernelAdapter.Adapter)" {
                                                        $TableParams = @{
                                                            Name = "VMkernel Adapter $($VMkernelAdapter.Adapter) - $VMHost"
                                                            List = $true
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VMkernelAdapter | Table @TableParams
                                                    }
                                                }
                                            }
                                            #endregion ESXi Host VMkernel Adapaters

                                            #region ESXi Host Standard Virtual Switches
                                            $VSSwitches = $VMHost | Get-VirtualSwitch -Standard | Sort-Object Name
                                            if ($VSSwitches) {
                                                #region Section Standard Virtual Switches
                                                Section -Style Heading5 'Standard Virtual Switches' {
                                                    Paragraph "The following section details the standard virtual switch configuration for $VMHost."
                                                    BlankLine
                                                    $VSSwitchNicTeaming = $VSSwitches | Get-NicTeamingPolicy
                                                    #region ESXi Host Standard Virtual Switch Properties
                                                    $VSSProperties = foreach ($VSSwitchNicTeam in $VSSwitchNicTeaming) {
                                                        [PSCustomObject]@{
                                                            'Virtual Switch' = $VSSwitchNicTeam.VirtualSwitch
                                                            'MTU' = $VSSwitchNicTeam.VirtualSwitch.Mtu
                                                            'Number of Ports' = $VSSwitchNicTeam.VirtualSwitch.NumPorts
                                                            'Number of Ports Available' = $VSSwitchNicTeam.VirtualSwitch.NumPortsAvailable
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "Standard Virtual Switches - $VMHost"
                                                        ColumnWidths = 25, 25, 25, 25
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VSSProperties | Table @TableParams
                                                    #endregion ESXi Host Standard Virtual Switch Properties

                                                    #region ESXi Host Virtual Switch Security Policy
                                                    $VssSecurity = $VSSwitches | Get-SecurityPolicy
                                                    if ($VssSecurity) {
                                                        #region Virtual Switch Security Policy
                                                        Section -Style Heading5 'Virtual Switch Security' {
                                                            $VssSecurity = foreach ($VssSec in $VssSecurity) {
                                                                [PSCustomObject]@{
                                                                    'Virtual Switch' = $VssSec.VirtualSwitch
                                                                    'Promiscuous Mode' = Switch ($VssSec.AllowPromiscuous) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    }
                                                                    'MAC Address Changes' = Switch ($VssSec.MacChanges) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    }
                                                                    'Forged Transmits' = Switch ($VssSec.ForgedTransmits) {
                                                                        $true { 'Accept' }
                                                                        $false { 'Reject' }
                                                                    }
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "Virtual Switch Security Policy - $VMHost"
                                                                ColumnWidths = 25, 25, 25, 25
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VssSecurity | Sort-Object 'Virtual Switch' | Table @TableParams
                                                        }
                                                        #endregion Virtual Switch Security Policy
                                                    }
                                                    #endregion ESXi Host Virtual Switch Security Policy

                                                    #region ESXi Host Virtual Switch Traffic Shaping Policy
                                                    Section -Style Heading5 'Virtual Switch Traffic Shaping' {
                                                        $VssTrafficShapingPolicy = foreach ($VSSwitch in $VSSwitches) {
                                                            [PSCustomObject]@{
                                                                'Virtual Switch' = $VSSwitch.Name
                                                                'Status' = Switch ($VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                                                    $True { 'Enabled' }
                                                                    $False { 'Disabled' }
                                                                }
                                                                'Average Bandwidth (kbit/s)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                                                'Peak Bandwidth (kbit/s)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                                                'Burst Size (KB)' = $VSSwitch.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "Virtual Switch Traffic Shaping Policy - $VMHost"
                                                            ColumnWidths = 25, 15, 20, 20, 20
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VssTrafficShapingPolicy | Sort-Object 'Virtual Switch' | Table @TableParams
                                                    }
                                                    #endregion ESXi Host Virtual Switch Traffic Shaping Policy

                                                    #region ESXi Host Virtual Switch Teaming & Failover
                                                    $VssNicTeamingPolicy = $VSSwitches | Get-NicTeamingPolicy
                                                    if ($VssNicTeamingPolicy) {
                                                        #region Virtual Switch Teaming & Failover Section
                                                        Section -Style Heading5 'Virtual Switch Teaming & Failover' {
                                                            $VssNicTeaming = foreach ($VssNicTeam in $VssNicTeamingPolicy) {
                                                                [PSCustomObject]@{
                                                                    'Virtual Switch' = $VssNicTeam.VirtualSwitch
                                                                    'Load Balancing' = Switch ($VssNicTeam.LoadBalancingPolicy) {
                                                                        'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                        'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                        'LoadbalanceIP' { 'Route based on IP hash' }
                                                                        'ExplicitFailover' { 'Explicit Failover' }
                                                                        default { $VssNicTeam.LoadBalancingPolicy }
                                                                    }
                                                                    'Network Failure Detection' = Switch ($VssNicTeam.NetworkFailoverDetectionPolicy) {
                                                                        'LinkStatus' { 'Link status only' }
                                                                        'BeaconProbing' { 'Beacon probing' }
                                                                        default { $VssNicTeam.NetworkFailoverDetectionPolicy }
                                                                    }
                                                                    'Notify Switches' = Switch ($VssNicTeam.NotifySwitches) {
                                                                        $true { 'Yes' }
                                                                        $false { 'No' }
                                                                    }
                                                                    'Failback' = Switch ($VssNicTeam.FailbackEnabled) {
                                                                        $true { 'Yes' }
                                                                        $false { 'No' }
                                                                    }
                                                                    'Active NICs' = ($VssNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                                                    'Standby NICs' = ($VssNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                                                    'Unused NICs' = ($VssNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "Virtual Switch Teaming & Failover - $VMHost"
                                                                ColumnWidths = 20, 17, 12, 11, 10, 10, 10, 10
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VssNicTeaming | Sort-Object 'Virtual Switch' | Table @TableParams
                                                        }
                                                        #endregion Virtual Switch Teaming & Failover Section
                                                    }
                                                    #endregion ESXi Host Virtual Switch Teaming & Failover

                                                    #region ESXi Host Virtual Switch Port Groups
                                                    $VssPortgroups = $VSSwitches | Get-VirtualPortGroup -Standard
                                                    if ($VssPortgroups) {
                                                        Section -Style Heading5 'Virtual Switch Port Groups' {
                                                            $VssPortgroups = foreach ($VssPortgroup in $VssPortgroups) {
                                                                [PSCustomObject]@{
                                                                    'Port Group' = $VssPortgroup.Name
                                                                    'VLAN ID' = $VssPortgroup.VLanId
                                                                    'Virtual Switch' = $VssPortgroup.VirtualSwitchName
                                                                    '# of VMs' = ($VssPortgroup | Get-VM).Count
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "Virtual Switch Port Groups - $VMHost"
                                                                ColumnWidths = 40, 10, 40, 10
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VssPortgroups | Sort-Object 'Port Group', 'VLAN ID', 'Virtual Switch' | Table @TableParams
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Groups

                                                        #region ESXi Host Virtual Switch Port Group Security Policy
                                                        $VssPortgroupSecurity = $VSSwitches | Get-VirtualPortGroup | Get-SecurityPolicy
                                                        if ($VssPortgroupSecurity) {
                                                            #region Virtual Port Group Security Policy Section
                                                            Section -Style Heading5 'Virtual Switch Port Group Security' {
                                                                $VssPortgroupSecurity = foreach ($VssPortgroupSec in $VssPortgroupSecurity) {
                                                                    [PSCustomObject]@{
                                                                        'Port Group' = $VssPortgroupSec.VirtualPortGroup
                                                                        'Virtual Switch' = $VssPortgroupSec.virtualportgroup.virtualswitchname
                                                                        'Promiscuous Mode' = Switch ($VssPortgroupSec.AllowPromiscuous) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        }
                                                                        'MAC Changes' = Switch ($VssPortgroupSec.MacChanges) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        }
                                                                        'Forged Transmits' = Switch ($VssPortgroupSec.ForgedTransmits) {
                                                                            $true { 'Accept' }
                                                                            $false { 'Reject' }
                                                                        }
                                                                    }
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Virtual Switch Port Group Security Policy - $VMHost"
                                                                    ColumnWidths = 27, 25, 16, 16, 16
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $VssPortgroupSecurity | Sort-Object 'Port Group', 'Virtual Switch' | Table @TableParams
                                                            }
                                                            #endregion Virtual Port Group Security Policy Section
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Security Policy

                                                        #region ESXi Host Virtual Switch Port Group Traffic Shaping Policy
                                                        Section -Style Heading5 'Virtual Switch Port Group Traffic Shaping' {
                                                            $VssPortgroupTrafficShapingPolicy = foreach ($VssPortgroup in $VssPortgroups) {
                                                                [PSCustomObject]@{
                                                                    'Port Group' = $VssPortgroup.Name
                                                                    'Virtual Switch' = $VssPortgroup.VirtualSwitchName
                                                                    'Status' = Switch ($VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.Enabled) {
                                                                        $True { 'Enabled' }
                                                                        $False { 'Disabled' }
                                                                        $null { 'Inherited' }
                                                                    }
                                                                    'Average Bandwidth (kbit/s)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
                                                                    'Peak Bandwidth (kbit/s)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
                                                                    'Burst Size (KB)' = $VssPortgroup.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "Virtual Switch Port Group Traffic Shaping Policy - $VMHost"
                                                                ColumnWidths = 19, 19, 11, 17, 17, 17
                                                            }
                                                            if ($Report.ShowTableCaptions) {
                                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                                            }
                                                            $VssPortgroupTrafficShapingPolicy | Sort-Object 'Port Group', 'Virtual Switch' | Table @TableParams
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Traffic Shaping Policy

                                                        #region ESXi Host Virtual Switch Port Group Teaming & Failover
                                                        $VssPortgroupNicTeaming = $VSSwitches | Get-VirtualPortGroup | Get-NicTeamingPolicy
                                                        if ($VssPortgroupNicTeaming) {
                                                            #region Virtual Switch Port Group Teaming & Failover Section
                                                            Section -Style Heading5 'Virtual Switch Port Group Teaming & Failover' {
                                                                $VssPortgroupNicTeaming = foreach ($VssPortgroupNicTeam in $VssPortgroupNicTeaming) {
                                                                    [PSCustomObject]@{
                                                                        'Port Group' = $VssPortgroupNicTeam.VirtualPortGroup
                                                                        'Virtual Switch' = $VssPortgroupNicTeam.virtualportgroup.virtualswitchname
                                                                        'Load Balancing' = Switch ($VssPortgroupNicTeam.LoadBalancingPolicy) {
                                                                            'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                                            'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                                            'LoadbalanceIP' { 'Route based on IP hash' }
                                                                            'ExplicitFailover' { 'Explicit Failover' }
                                                                            default { $VssPortgroupNicTeam.LoadBalancingPolicy }
                                                                        }
                                                                        'Network Failure Detection' = Switch ($VssPortgroupNicTeam.NetworkFailoverDetectionPolicy) {
                                                                            'LinkStatus' { 'Link status only' }
                                                                            'BeaconProbing' { 'Beacon probing' }
                                                                            default { $VssPortgroupNicTeam.NetworkFailoverDetectionPolicy }
                                                                        }
                                                                        'Notify Switches' = Switch ($VssPortgroupNicTeam.NotifySwitches) {
                                                                            $true { 'Yes' }
                                                                            $false { 'No' }
                                                                        }
                                                                        'Failback' = Switch ($VssPortgroupNicTeam.FailbackEnabled) {
                                                                            $true { 'Yes' }
                                                                            $false { 'No' }
                                                                        }
                                                                        'Active NICs' = ($VssPortgroupNicTeam.ActiveNic | Sort-Object) -join [Environment]::NewLine
                                                                        'Standby NICs' = ($VssPortgroupNicTeam.StandbyNic | Sort-Object) -join [Environment]::NewLine
                                                                        'Unused NICs' = ($VssPortgroupNicTeam.UnusedNic | Sort-Object) -join [Environment]::NewLine
                                                                    }
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Virtual Switch Port Group Teaming & Failover - $VMHost"
                                                                    ColumnWidths = 12, 11, 11, 11, 11, 11, 11, 11, 11
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $VssPortgroupNicTeaming | Sort-Object 'Port Group', 'Virtual Switch' | Table @TableParams
                                                            }
                                                            #endregion Virtual Switch Port Group Teaming & Failover Section
                                                        }
                                                        #endregion ESXi Host Virtual Switch Port Group Teaming & Failover
                                                    }
                                                }
                                                #endregion Section Standard Virtual Switches
                                            }
                                            #endregion ESXi Host Standard Virtual Switches
                                        }
                                        #endregion ESXi Host Network Section

                                        #region ESXi Host Security Section
                                        Section -Style Heading4 'Security' {
                                            Paragraph "The following section details the host security configuration for $VMHost."
                                            #region ESXi Host Lockdown Mode
                                            if ($null -ne $VMHost.ExtensionData.Config.LockdownMode) {
                                                Section -Style Heading5 'Lockdown Mode' {
                                                    $LockdownMode = [PSCustomObject]@{
                                                        'Lockdown Mode' = Switch ($VMHost.ExtensionData.Config.LockdownMode) {
                                                            'lockdownDisabled' { 'Disabled' }
                                                            'lockdownNormal' { 'Enabled (Normal)' }
                                                            'lockdownStrict' { 'Enabled (Strict)' }
                                                            default { $VMHost.ExtensionData.Config.LockdownMode }
                                                        }
                                                    }
                                                    if ($Healthcheck.VMHost.LockdownMode) {
                                                        $LockdownMode | Where-Object { $_.'Lockdown Mode' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Lockdown Mode'
                                                    }
                                                    $TableParams = @{
                                                        Name = "Lockdown Mode - $VMHost"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $LockdownMode | Table @TableParams
                                                }
                                            }
                                            #endregion ESXi Host Lockdown Mode

                                            #region ESXi Host Services
                                            Section -Style Heading5 'Services' {
                                                $VMHostServices = $VMHost | Get-VMHostService
                                                $Services = foreach ($VMHostService in $VMHostServices) {
                                                    [PSCustomObject]@{
                                                        'Service' = $VMHostService.Label
                                                        'Daemon' = Switch ($VMHostService.Running) {
                                                            $true { 'Running' }
                                                            $false { 'Stopped' }
                                                        }
                                                        'Startup Policy' = Switch ($VMHostService.Policy) {
                                                            'automatic' { 'Start and stop with port usage' }
                                                            'on' { 'Start and stop with host' }
                                                            'off' { 'Start and stop manually' }
                                                            default { $VMHostService.Policy }
                                                        }
                                                    }
                                                }
                                                if ($Healthcheck.VMHost.NTP) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'NTP Daemon') -and ($_.Daemon -eq 'Stopped') } | Set-Style -Style Critical -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'NTP Daemon') -and ($_.'Startup Policy' -ne 'Start and stop with host') } | Set-Style -Style Critical -Property 'Startup Policy'
                                                }
                                                if ($Healthcheck.VMHost.SSH) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'SSH') -and ($_.Daemon -eq 'Running') } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'SSH') -and ($_.'Startup Policy' -ne 'Start and stop manually') } | Set-Style -Style Warning -Property 'Startup Policy'
                                                }
                                                if ($Healthcheck.VMHost.ESXiShell) {
                                                    $Services | Where-Object { ($_.'Service' -eq 'ESXi Shell') -and ($_.Daemon -eq 'Running') } | Set-Style -Style Warning -Property 'Daemon'
                                                    $Services | Where-Object { ($_.'Service' -eq 'ESXi Shell') -and ($_.'Startup Policy' -ne 'Start and stop manually') } | Set-Style -Style Warning -Property 'Startup Policy'
                                                }
                                                $TableParams = @{
                                                    Name = "Services - $VMHost"
                                                    ColumnWidths = 40, 20, 40
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $Services | Sort-Object 'Service' | Table @TableParams
                                            }
                                            #endregion ESXi Host Services

                                            #region ESXi Host Advanced Detail Information
                                            if ($InfoLevel.VMHost -ge 4) {
                                                #region ESXi Host Firewall
                                                $VMHostFirewallExceptions = $VMHost | Get-VMHostFirewallException
                                                if ($VMHostFirewallExceptions) {
                                                    #region Friewall Section
                                                    Section -Style Heading5 'Firewall' {
                                                        $VMHostFirewall = foreach ($VMHostFirewallException in $VMHostFirewallExceptions) {
                                                            [PScustomObject]@{
                                                                'Service' = $VMHostFirewallException.Name
                                                                'Status' = Switch ($VMHostFirewallException.Enabled) {
                                                                    $true { 'Enabled' }
                                                                    $false { 'Disabled' }
                                                                }
                                                                'Incoming Ports' = $VMHostFirewallException.IncomingPorts
                                                                'Outgoing Ports' = $VMHostFirewallException.OutgoingPorts
                                                                'Protocols' = $VMHostFirewallException.Protocols
                                                                'Daemon' = Switch ($VMHostFirewallException.ServiceRunning) {
                                                                    $true { 'Running' }
                                                                    $false { 'Stopped' }
                                                                    $null { 'N/A' }
                                                                    default { $VMHostFirewallException.ServiceRunning }
                                                                }
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "Firewall Configuration - $VMHost"
                                                            ColumnWidths = 22, 12, 21, 21, 12, 12
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VMHostFirewall | Sort-Object 'Service' | Table @TableParams
                                                    }
                                                    #endregion Friewall Section
                                                }
                                                #endregion ESXi Host Firewall

                                                #region ESXi Host Authentication
                                                $AuthServices = $VMHost | Get-VMHostAuthentication
                                                if ($AuthServices.DomainMembershipStatus) {
                                                    Section -Style Heading5 'Authentication Services' {
                                                        $AuthServices = $AuthServices | Select-Object Domain, @{L = 'Domain Membership'; E = { $_.DomainMembershipStatus } }, @{L = 'Trusted Domains'; E = { $_.TrustedDomains } }
                                                        $TableParams = @{
                                                            Name = "Authentication Services - $VMHost"
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
                                                Section -Style Heading4 'Virtual Machines' {
                                                    Paragraph "The following section details the virtual machine configuration for $VMHost."
                                                    BlankLine
                                                    #region ESXi Host Virtual Machine Information
                                                    $VMHostVMInfo = foreach ($VMHostVM in $VMHostVMs) {
                                                        $VMHostVMView = $VMHostVM | Get-View
                                                        [PSCustomObject]@{
                                                            'Virtual Machine' = $VMHostVM.Name
                                                            'Power State' = Switch ($VMHostVM.PowerState) {
                                                                'PoweredOn' { 'On' }
                                                                'PoweredOff' { 'Off' }
                                                                default { $VMHostVM.PowerState }
                                                            }
                                                            'IP Address' = Switch ($VMHostVMView.Guest.IpAddress) {
                                                                $null { '--' }
                                                                default { $VMHostVMView.Guest.IpAddress }
                                                            }
                                                            'CPUs' = $VMHostVM.NumCpu
                                                            #'Cores per Socket' = $VMHostVM.CoresPerSocket
                                                            'Memory GB' = [math]::Round(($VMHostVM.memoryGB), 2)
                                                            'Provisioned GB' = [math]::Round(($VMHostVM.ProvisionedSpaceGB), 2)
                                                            'Used GB' = [math]::Round(($VMHostVM.UsedSpaceGB), 2)
                                                            'HW Version' = ($VMHostVM.HardwareVersion).Replace('vmx-', 'v')
                                                            'VM Tools Status' = Switch ($VMHostVM.ExtensionData.Guest.ToolsStatus) {
                                                                'toolsOld' { 'Old' }
                                                                'toolsOK' { 'OK' }
                                                                'toolsNotRunning' { 'Not Running' }
                                                                'toolsNotInstalled' { 'Not Installed' }
                                                                default { $VMHostVM.ExtensionData.Guest.ToolsStatus }
                                                            }
                                                        }
                                                    }
                                                    if ($Healthcheck.VM.VMToolsStatus) {
                                                        $VMHostVMInfo | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                                    }
                                                    if ($Healthcheck.VM.PowerState) {
                                                        $VMHostVMInfo | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                                    }
                                                    $TableParams = @{
                                                        Name = "Virtual Machines - $VMHost"
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
                                                        Section -Style Heading5 'VM Startup/Shutdown' {
                                                            $VMStartPolicies = foreach ($VMStartPol in $VMStartPolicy) {
                                                                [PSCustomObject]@{
                                                                    'Start Order' = $VMStartPol.StartOrder
                                                                    'VM Name' = $VMStartPol.VirtualMachineName
                                                                    'Startup' = Switch ($VMStartPol.StartAction) {
                                                                        'PowerOn' { 'Enabled' }
                                                                        'None' { 'Disabled' }
                                                                        default { $VMStartPol.StartAction }
                                                                    }
                                                                    'Startup Delay' = "$($VMStartPol.StartDelay) seconds"
                                                                    'VMware Tools' = Switch ($VMStartPol.WaitForHeartbeat) {
                                                                        $true { 'Continue if VMware Tools is started' }
                                                                        $false { 'Wait for startup delay' }
                                                                    }
                                                                    'Shutdown Behavior' = Switch ($VMStartPol.StopAction) {
                                                                        'PowerOff' { 'Power Off' }
                                                                        'GuestShutdown' { 'Guest Shutdown' }
                                                                        default { $VMStartPol.StopAction }
                                                                    }
                                                                    'Shutdown Delay' = "$($VMStartPol.StopDelay) seconds"
                                                                }
                                                            }
                                                            $TableParams = @{
                                                                Name = "VM Startup/Shutdown Policy - $VMHost"
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
                #endregion ESXi VMHost Section

                #region Distributed Switch Section
                Write-PScriboMessage "Network InfoLevel set at $($InfoLevel.Network)."
                if ($InfoLevel.Network -ge 1) {
                    # Create Distributed Switch Section if they exist
                    $VDSwitches = Get-VDSwitch -Server $vCenter | Sort-Object Name
                    if ($VDSwitches) {
                        Section -Style Heading2 'Distributed Switches' {
                            Paragraph "The following sections detail the configuration of distributed switches managed by vCenter Server $vCenterServerName."
                            #region Distributed Switch Advanced Summary
                            if ($InfoLevel.Network -le 2) {
                                BlankLine
                                $VDSInfo = foreach ($VDS in $VDSwitches) {
                                    [PSCustomObject]@{
                                        'VDSwitch' = $VDS.Name
                                        'Datacenter' = $VDS.Datacenter
                                        'Manufacturer' = $VDS.Vendor
                                        'Version' = $VDS.Version
                                        '# of Uplinks' = $VDS.NumUplinkPorts
                                        '# of Ports' = $VDS.NumPorts
                                        '# of Hosts' = $VDS.ExtensionData.Summary.HostMember.Count
                                        '# of VMs' = $VDS.ExtensionData.Summary.VM.Count
                                    }
                                }
                                $TableParams = @{
                                    Name = "Distributed Switch Summary - $($vCenterServerName)"
                                    ColumnWidths = 20, 18, 18, 10, 10, 8, 8, 8
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VDSInfo | Table @TableParams
                            }
                            #endregion Distributed Switch Advanced Summary

                            #region Distributed Switch Detailed Information
                            if ($InfoLevel.Network -ge 3) {
                                # TODO: LACP, NetFlow, NIOC
                                # TODO: Test Tags
                                foreach ($VDS in ($VDSwitches)) {
                                    #region VDS Section
                                    Section -Style Heading3 $VDS {
                                        #region Distributed Switch General Properties
                                        $VDSwitchDetail = [PSCustomObject]@{
                                            'Distributed Switch' = $VDS.Name
                                            'ID' = $VDS.Id
                                            'Datacenter' = $VDS.Datacenter
                                            'Manufacturer' = $VDS.Vendor
                                            'Version' = $VDS.Version
                                            'Number of Uplinks' = $VDS.NumUplinkPorts
                                            'Number of Ports' = $VDS.NumPorts
                                            'Number of Port Groups' = $VDS.ExtensionData.Summary.PortGroupName.Count
                                            'Number of Hosts' = $VDS.ExtensionData.Summary.HostMember.Count
                                            'Number of VMs' = $VDS.ExtensionData.Summary.VM.Count
                                            'MTU' = $VDS.Mtu
                                            'Network I/O Control' = Switch ($VDS.ExtensionData.Config.NetworkResourceManagementEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Discovery Protocol' = $VDS.LinkDiscoveryProtocol
                                            'Discovery Protocol Operation' = $VDS.LinkDiscoveryProtocolOperation
                                        }
                                        <#
                                        $MemberProps = @{
                                            'InputObject' = $VDSwitchDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        if ($TagAssignments | Where-Object {$_.entity -eq $VDS}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $VDS}).Tag -join ',')
                                        }
                                        #>
                                        #region Network Advanced Detail Information
                                        if ($InfoLevel.Network -ge 4) {
                                            $VDSwitchDetail | ForEach-Object {
                                                $VDSwitchHosts = $VDS | Get-VMHost | Sort-Object Name
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Hosts' -Value ($VDSwitchHosts.Name -join ', ')
                                                $VDSwitchVMs = $VDS | Get-VM | Sort-Object
                                                Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Virtual Machines' -Value ($VDSwitchVMs.Name -join ', ')
                                            }
                                        }
                                        #endregion Network Advanced Detail Information
                                        $TableParams = @{
                                            Name = "Distributed Switch General Properties - $VDS"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $VDSwitchDetail | Table @TableParams
                                        #endregion Distributed Switch General Properties

                                        #region Distributed Switch Uplink Ports
                                        $VdsUplinks = $VDS | Get-VDPortgroup | Where-Object { $_.IsUplink -eq $true } | Get-VDPort
                                        if ($VdsUplinks) {
                                            Section -Style Heading4 'Distributed Switch Uplink Ports' {
                                                $VdsUplinkDetail = foreach ($VdsUplink in $VdsUplinks) {
                                                    [PSCustomObject]@{
                                                        'Distributed Switch' = $VdsUplink.Switch
                                                        'Host' = $VdsUplink.ProxyHost
                                                        'Uplink Name' = $VdsUplink.Name
                                                        'Physical Network Adapter' = $VdsUplink.ConnectedEntity
                                                        'Uplink Port Group' = $VdsUplink.Portgroup
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Uplink Ports - $VDS"
                                                    ColumnWidths = 20, 20, 20, 20, 20
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VdsUplinkDetail | Sort-Object 'Distributed Switch', 'Host', 'Uplink Name' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Uplink Ports

                                        #region Distributed Switch Security
                                        $VDSecurityPolicy = $VDS | Get-VDSecurityPolicy
                                        if ($VDSecurityPolicy) {
                                            Section -Style Heading4 'Distributed Switch Security' {
                                                $VDSecurityPolicyDetail = [PSCustomObject]@{
                                                    'Distributed Switch' = $VDSecurityPolicy.VDSwitch
                                                    'Allow Promiscuous' = Switch ($VDSecurityPolicy.AllowPromiscuous) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                    'Forged Transmits' = Switch ($VDSecurityPolicy.ForgedTransmits) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                    'MAC Address Changes' = Switch ($VDSecurityPolicy.MacChanges) {
                                                        $true { 'Accept' }
                                                        $false { 'Reject' }
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Security - $VDS"
                                                    ColumnWidths = 25, 25, 25, 25
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSecurityPolicyDetail | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Security

                                        #region Distributed Switch Traffic Shaping
                                        $VDSTrafficShaping = @()
                                        $VDSTrafficShapingIn = $VDS | Get-VDTrafficShapingPolicy -Direction In
                                        $VDSTrafficShapingOut = $VDS | Get-VDTrafficShapingPolicy -Direction Out
                                        $VDSTrafficShaping += $VDSTrafficShapingIn
                                        $VDSTrafficShaping += $VDSTrafficShapingOut
                                        if ($VDSTrafficShapingIn -or $VDSTrafficShapingOut) {
                                            Section -Style Heading4 'Distributed Switch Traffic Shaping' {
                                                $VDSTrafficShapingDetail = foreach ($VDSTrafficShape in $VDSTrafficShaping) {
                                                    [PSCustomObject]@{
                                                        'Distributed Switch' = $VDSTrafficShape.VDSwitch
                                                        'Direction' = $VDSTrafficShape.Direction
                                                        'Status' = Switch ($VDSTrafficShape.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Average Bandwidth (kbit/s)' = $VDSTrafficShape.AverageBandwidth
                                                        'Peak Bandwidth (kbit/s)' = $VDSTrafficShape.PeakBandwidth
                                                        'Burst Size (KB)' = $VDSTrafficShape.BurstSize
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Traffic Shaping - $VDS"
                                                    ColumnWidths = 25, 13, 11, 17, 17, 17
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSTrafficShapingDetail | Sort-Object 'Direction' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Traffic Shaping

                                        #region Distributed Switch Port Groups
                                        # TODO: Test Tags
                                        $VDSPortgroups = $VDS | Get-VDPortgroup
                                        if ($VDSPortgroups) {
                                            Section -Style Heading4 'Distributed Switch Port Groups' {
                                                $VDSPortgroupDetail = foreach ($VDSPortgroup in $VDSPortgroups) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSPortgroup.Name
                                                        'Distributed Switch' = $VDSPortgroup.VDSwitch
                                                        'Datacenter' = $VDSPortgroup.Datacenter
                                                        'VLAN Configuration' = Switch ($VDSPortgroup.VlanConfiguration) {
                                                            $null { '--' }
                                                            default { $VDSPortgroup.VlanConfiguration }
                                                        }
                                                        'Port Binding' = $VDSPortgroup.PortBinding
                                                        '# of Ports' = $VDSPortgroup.NumPorts
                                                        <#
                                                        # Tags on portgroups cause Get-TagAssignments to error
                                                        'Tags' = & {
                                                            if ($TagAssignments | Where-Object {$_.entity -eq $VDSPortgroup}) {
                                                                ($TagAssignments | Where-Object {$_.entity -eq $VDSPortgroup}).Tag -join ','
                                                            } else {
                                                                '--'
                                                            }
                                                        }
                                                        #>
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Port Groups - $VDS"
                                                    ColumnWidths = 20, 20, 20, 15, 15, 10
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSPortgroupDetail | Sort-Object 'Port Group' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Port Groups

                                        #region Distributed Switch Port Group Security
                                        $VDSPortgroupSecurity = $VDS | Get-VDPortgroup | Get-VDSecurityPolicy
                                        if ($VDSPortgroupSecurity) {
                                            Section -Style Heading5 "Distributed Switch Port Group Security" {
                                                $VDSSecurityPolicies = foreach ($VDSSecurityPolicy in $VDSPortgroupSecurity) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSSecurityPolicy.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Allow Promiscuous' = Switch ($VDSSecurityPolicy.AllowPromiscuous) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                        'Forged Transmits' = Switch ($VDSSecurityPolicy.ForgedTransmits) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                        'MAC Address Changes' = Switch ($VDSSecurityPolicy.MacChanges) {
                                                            $true { 'Accept' }
                                                            $false { 'Reject' }
                                                        }
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Port Group Security - $VDS"
                                                    ColumnWidths = 20, 20, 20, 20, 20
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSSecurityPolicies | Sort-Object 'Port Group' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Port Group Security

                                        #region Distributed Switch Port Group Traffic Shaping
                                        $VDSPortgroupTrafficShaping = @()
                                        $VDSPortgroupTrafficShapingIn = $VDS | Get-VDPortgroup | Get-VDTrafficShapingPolicy -Direction In
                                        $VDSPortgroupTrafficShapingOut = $VDS | Get-VDPortgroup | Get-VDTrafficShapingPolicy -Direction Out
                                        $VDSPortgroupTrafficShaping += $VDSPortgroupTrafficShapingIn
                                        $VDSPortgroupTrafficShaping += $VDSPortgroupTrafficShapingOut
                                        if ($VDSPortgroupTrafficShaping) {
                                            Section -Style Heading5 "Distributed Switch Port Group Traffic Shaping" {
                                                $VDSPortgroupTrafficShapingDetail = foreach ($VDSPortgroupTrafficShape in $VDSPortgroupTrafficShaping) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDSPortgroupTrafficShape.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Direction' = $VDSPortgroupTrafficShape.Direction
                                                        'Status' = Switch ($VDSPortgroupTrafficShape.Enabled) {
                                                            $true { 'Enabled' }
                                                            $false { 'Disabled' }
                                                        }
                                                        'Average Bandwidth (kbit/s)' = $VDSPortgroupTrafficShape.AverageBandwidth
                                                        'Peak Bandwidth (kbit/s)' = $VDSPortgroupTrafficShape.PeakBandwidth
                                                        'Burst Size (KB)' = $VDSPortgroupTrafficShape.BurstSize
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Port Group Traffic Shaping - $VDS"
                                                    ColumnWidths = 16, 16, 10, 10, 16, 16, 16
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSPortgroupTrafficShapingDetail | Sort-Object 'Port Group', 'Direction', 'Port Group' | Table @TableParams

                                            }
                                        }
                                        #endregion Distributed Switch Port Group Traffic Shaping

                                        #region Distributed Switch Port Group Teaming & Failover
                                        $VDUplinkTeamingPolicy = $VDS | Get-VDPortgroup | Get-VDUplinkTeamingPolicy
                                        if ($VDUplinkTeamingPolicy) {
                                            Section -Style Heading5 "Distributed Switch Port Group Teaming & Failover" {
                                                $VDSPortgroupNICTeaming = foreach ($VDUplink in $VDUplinkTeamingPolicy) {
                                                    [PSCustomObject]@{
                                                        'Port Group' = $VDUplink.VDPortgroup
                                                        'Distributed Switch' = $VDS.Name
                                                        'Load Balancing' = Switch ($VDUplink.LoadBalancingPolicy) {
                                                            'LoadbalanceSrcId' { 'Route based on the originating port ID' }
                                                            'LoadbalanceSrcMac' { 'Route based on source MAC hash' }
                                                            'LoadbalanceIP' { 'Route based on IP hash' }
                                                            'ExplicitFailover' { 'Explicit Failover' }
                                                            default { $VDUplink.LoadBalancingPolicy }
                                                        }
                                                        'Network Failure Detection' = Switch ($VDUplink.FailoverDetectionPolicy) {
                                                            'LinkStatus' { 'Link status only' }
                                                            'BeaconProbing' { 'Beacon probing' }
                                                            default { $VDUplink.FailoverDetectionPolicy }
                                                        }
                                                        'Notify Switches' = Switch ($VDUplink.NotifySwitches) {
                                                            $true { 'Yes' }
                                                            $false { 'No' }
                                                        }
                                                        'Failback Enabled' = Switch ($VDUplink.EnableFailback) {
                                                            $true { 'Yes' }
                                                            $false { 'No' }
                                                        }
                                                        'Active Uplinks' = $VDUplink.ActiveUplinkPort -join [Environment]::NewLine
                                                        'Standby Uplinks' = $VDUplink.StandbyUplinkPort -join [Environment]::NewLine
                                                        'Unused Uplinks' = $VDUplink.UnusedUplinkPort -join [Environment]::NewLine
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Port Group Teaming & Failover - $VDS"
                                                    ColumnWidths = 12, 12, 12, 11, 10, 10, 11, 11, 11
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSPortgroupNICTeaming | Sort-Object 'Port Group' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Port Group Teaming & Failover

                                        #region Distributed Switch Private VLANs
                                        $VDSwitchPrivateVLANs = $VDS | Get-VDSwitchPrivateVlan
                                        if ($VDSwitchPrivateVLANs) {
                                            Section -Style Heading4 'Distributed Switch Private VLANs' {
                                                $VDSPvlan = foreach ($VDSwitchPrivateVLAN in $VDSwitchPrivateVLANs) {
                                                    [PSCustomObject]@{
                                                        'Primary VLAN ID' = $VDSwitchPrivateVLAN.PrimaryVlanId
                                                        'Private VLAN Type' = $VDSwitchPrivateVLAN.PrivateVlanType
                                                        'Secondary VLAN ID' = $VDSwitchPrivateVLAN.SecondaryVlanId
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Distributed Switch Private VLANs - $VDS"
                                                    ColumnWidths = 33, 34, 33
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VDSPvlan | Sort-Object 'Primary VLAN ID', 'Secondary VLAN ID' | Table @TableParams
                                            }
                                        }
                                        #endregion Distributed Switch Private VLANs
                                    }
                                    #endregion VDS Section
                                }
                            }
                            #endregion Distributed Switch Detailed Information
                        }
                    }
                }
                #endregion Distributed Switch Section

                #region vSAN Section
                Write-PScriboMessage "vSAN InfoLevel set at $($InfoLevel.vSAN)."
                if (($InfoLevel.vSAN -ge 1) -and ($vCenter.Version -gt 6)) {
                    $VsanClusters = Get-VsanClusterConfiguration -Server $vCenter | Where-Object { $_.vsanenabled -eq $true } | Sort-Object Name
                    if ($VsanClusters) {
                        Section -Style Heading2 'vSAN' {
                            Paragraph "The following sections detail the configuration of vSAN managed by vCenter Server $vCenterServerName."
                            #region vSAN Cluster Advanced Summary
                            if ($InfoLevel.vSAN -le 2) {
                                BlankLine
                                $VsanClusterInfo = foreach ($VsanCluster in $VsanClusters) {
                                    [PSCustomObject]@{
                                        'Cluster' = $VsanCluster.Name
                                        'vSAN Enabled' = $VsanCluster.VsanEnabled
                                        'Stretched Cluster' = Switch ($VsanCluster.StretchedClusterEnabled) {
                                            $true { 'Yes' }
                                            $false { 'No' }
                                        }
                                        # TODO: Update for vSphere 7.0 U1 and higher - Space Efficiency: Deduplication & Compression, Compression Only, None
                                        'Deduplication & Compression' = Switch ($VsanCluster.SpaceEfficiencyEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'Encryption' = Switch ($VsanCluster.EncryptionEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                            $null { 'Disabled' }
                                        }
                                        'Health Check' = Switch ($VsanCluster.HealthCheckEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                    }
                                }
                                $TableParams = @{
                                    Name = "vSAN Cluster Summary - $($vCenterServerName)"
                                    ColumnWidths = 25, 15, 15, 15, 15, 15
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VsanClusterInfo | Table @TableParams
                            }
                            #endregion vSAN Cluster Advanced Summary

                            #region vSAN Cluster Detailed Information
                            if ($InfoLevel.vSAN -ge 3) {
                                foreach ($VsanCluster in $VsanClusters) {
                                    #region vSAN Cluster Section
                                    Section -Style Heading3 $VsanCluster.Name {
                                        $VsanDiskGroup = Get-VsanDiskGroup -Cluster $VsanCluster.Cluster
                                        $NumVsanDiskGroup = $VsanDiskGroup.Count
                                        $VsanDisk = Get-VsanDisk -VsanDiskGroup $VsanDiskGroup
                                        $VsanDiskFormat = $VsanDisk.DiskFormatVersion | Select-Object -First 1 -Unique
                                        $NumVsanSsd = ($VsanDisk | Where-Object { $_.IsSsd -eq $true }).Count
                                        $NumVsanHdd = ($VsanDisk | Where-Object { $_.IsSsd -eq $false }).Count
                                        if ($NumVsanHdd -gt 0) {
                                            $VsanClusterType = "Hybrid"
                                        } else {
                                            $VsanClusterType = "All Flash"
                                        }
                                        $VsanClusterDetail = [PSCustomObject]@{
                                            'Cluster' = $VsanCluster.Name
                                            'ID' = $VsanCluster.Id
                                            'Type' = $VsanClusterType
                                            'Stretched Cluster' = Switch ($VsanCluster.StretchedClusterEnabled) {
                                                $true { 'Yes' }
                                                $false { 'No' }
                                            }
                                            'Number of Hosts' = $VsanCluster.Cluster.ExtensionData.Host.Count
                                            'Disk Format Version' = $VsanDiskFormat
                                            'Total Number of Disks' = $NumVsanSsd + $NumVsanHdd
                                            'Total Number of Disk Groups' = $NumVsanDiskGroup
                                            'Disk Claim Mode' = $VsanCluster.VsanDiskClaimMode
                                            'Deduplication & Compression' = Switch ($VsanCluster.SpaceEfficiencyEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Encryption' = Switch ($VsanCluster.EncryptionEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                                $null { 'Disabled' }
                                            }
                                            'Health Check' = Switch ($VsanCluster.HealthCheckEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'HCL Last Updated' = $VsanCluster.TimeOfHclUpdate
                                        }

                                        if ($InfoLevel.vSAN -ge 4) {
                                            $VsanClusterDetail | Add-Member -MemberType NoteProperty -Name 'Hosts' -Value (($VsanDiskGroup.VMHost | Select-Object -Unique | Sort-Object Name) -join ', ')
                                        }
                                        $TableParams = @{
                                            Name = "vSAN Configuration - $($VsanCluster.Name)"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $VsanClusterDetail | Table @TableParams

                                        # TODO: vSAN Services

                                        Section -Style Heading4 'Disk Groups' {
                                            $VsanDiskGroups = foreach ($DiskGroup in $VsanDiskGroup) {
                                                $Disks = $DiskGroup | Get-VsanDisk
                                                [PSCustomObject]@{
                                                    'Disk Group' = $DiskGroup.Uuid
                                                    'Host' = $Diskgroup.VMHost
                                                    '# of Disks' = $Disks.Count
                                                    'State' = Switch ($DiskGroup.IsMounted) {
                                                        $true { 'Mounted' }
                                                        $False { 'Unmounted' }
                                                    }
                                                    'Type' = Switch ($DiskGroup.DiskGroupType) {
                                                        'AllFlash' { 'All Flash' }
                                                        default { $DiskGroup.DiskGroupType }
                                                    }
                                                    'Disk Format Version' = $DiskGroup.DiskFormatVersion
                                                }
                                            }
                                            $TableParams = @{
                                                Name = "vSAN Disk Groups - $($VsanCluster.Name)"
                                                ColumnWidths = 35, 28, 7, 10, 10, 10
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $VsanDiskGroups | Sort-Object Host | Table @TableParams
                                        }

                                        Section -Style Heading4 'Disks' {
                                            $vDisks = foreach ($Disk in $VsanDisk) {
                                                [PSCustomObject]@{
                                                    'Disk' = $Disk.Name
                                                    'Name' = $Disk.ExtensionData.DisplayName
                                                    'Drive Type' = Switch ($Disk.IsSsd) {
                                                        $true { 'Flash' }
                                                        $false { 'HDD' }
                                                    }
                                                    'Host' = $Disk.VsanDiskGroup.VMHost.Name
                                                    'Claimed As' = Switch ($Disk.IsCacheDisk) {
                                                        $true { 'Cache' }
                                                        $false { 'Capacity' }
                                                    }
                                                    'Capacity' = "$([math]::Round($Disk.CapacityGB, 2)) GB"
                                                    'Capacity GB' = [math]::Round($Disk.CapacityGB, 2)
                                                    'Serial Number' = $Disk.ExtensionData.SerialNumber
                                                    'Vendor' = $Disk.ExtensionData.Vendor
                                                    'Model' = $Disk.ExtensionData.Model
                                                    'Disk Group' = $Disk.VsanDiskGroup.Uuid
                                                    'Disk Format Version' = $Disk.DiskFormatVersion
                                                }
                                            }

                                            if ($InfoLevel.vSAN -ge 4) {
                                                $vDisks | Sort-Object Host | ForEach-Object {
                                                    Section -Style Heading4 "$($_.Disk) - $($_.Host)" {
                                                        $TableParams = @{
                                                            Name = "Disk $($_.Disk) - $($_.Host)"
                                                            List = $true
                                                            Columns = 'Name', 'Drive Type', 'Claimed As', 'Capacity', 'Host', 'Disk Group', 'Serial Number', 'Vendor', 'Model', 'Disk Format Version'
                                                            ColumnWidths = 50, 50
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $_ | Table @TableParams
                                                    }
                                                }
                                            } else {
                                                $TableParams = @{
                                                    Name = "vSAN Disks - $($VsanCluster.Name)"
                                                    Columns = 'Disk', 'Drive Type', 'Claimed As', 'Capacity GB', 'Host', 'Disk Group'
                                                    ColumnWidths = 21, 10, 10, 10, 21, 28
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $vDisks | Sort-Object Host | Table @TableParams
                                            }
                                        }

                                        $VsanIscsiTargets = Get-VsanIscsiTarget -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue
                                        if ($VsanIscsiTargets) {
                                            Section -Style Heading4 'iSCSI Targets' {
                                                $VsanIscsiTargetInfo = foreach ($VsanIscsiTarget in $VsanIscsiTargets) {
                                                    [PSCustomObject]@{
                                                        'IQN' = $VsanIscsiTarget.IscsiQualifiedName
                                                        'Alias' = $VsanIscsiTarget.Name
                                                        'LUNs' = $VsanIscsiTarget.NumLuns
                                                        'Network Interface' = $VsanIscsiTarget.NetworkInterface
                                                        'I/O Owner Host' = $VsanIscsiTarget.IoOwnerVMHost
                                                        'TCP Port' = $VsanIscsiTarget.TcpPort
                                                        'Health' = $TextInfo.ToTitleCase($VsanIscsiTarget.VsanHealth)
                                                        'Storage Policy' = Switch ($VsanIscsiTarget.StoragePolicy.Name) {
                                                            $null { '--' }
                                                            default { $VsanIscsiTarget.StoragePolicy.Name }
                                                        }
                                                        'Compliance Status' = $TextInfo.ToTitleCase($VsanIscsiTarget.SpbmComplianceStatus)
                                                        'Authentication' = $VsanIscsiTarget.AuthenticationType
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "vSAN iSCSI Targets - $($VsanCluster.Name)"
                                                    List = $true
                                                    ColumnWidths = 50, 50
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VsanIscsiTargetInfo | Table @TableParams
                                            }
                                        }

                                        $VsanIscsiLuns = Get-VsanIscsiLun -Cluster $VsanCluster.Cluster -ErrorAction SilentlyContinue | Sort-Object Name, LunId
                                        if ($VsanIscsiLuns) {
                                            Section -Style Heading4 'iSCSI LUNs' {
                                                $VsanIscsiLunInfo = foreach ($VsanIscsiLun in $VsanIscsiLuns) {
                                                    [PSCustomobject]@{
                                                        'LUN' = $VsanIscsiLun.Name
                                                        'LUN ID' = $VsanIscsiLun.LunId
                                                        'Capacity GB' = [math]::Round($VsanIscsiLun.CapacityGB, 2)
                                                        'Used Capacity GB' = [math]::Round($VsanIscsiLun.UsedCapacityGB, 2)
                                                        'State' = Switch ($VsanIscsiLun.IsOnline) {
                                                            $true { 'Online' }
                                                            $false { 'Offline' }
                                                        }
                                                        'Health' = $TextInfo.ToTitleCase($VsanIscsiLun.VsanHealth)
                                                        'Storage Policy' = Switch ($VsanIscsiLun.StoragePolicy.Name) {
                                                            $null { '--' }
                                                            default { $VsanIscsiLun.StoragePolicy.Name }
                                                        }
                                                        'Compliance Status' = $TextInfo.ToTitleCase($VsanIscsiLun.SpbmComplianceStatus)
                                                    }
                                                }
                                                if ($InfoLevel.vSAN -ge 4) {
                                                    $TableParams = @{
                                                        Name = "vSAN iSCSI LUNs - $($VsanCluster.Name)"
                                                        List = $true
                                                        ColumnWidths = 50, 50
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VsanIscsiLunInfo | Table @TableParams
                                                } else {
                                                    $TableParams = @{
                                                        Name = "vSAN iSCSI LUNs - $($VsanCluster.Name)"
                                                        ColumnWidths = 28 , 18, 18, 18, 18
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VsanIscsiLunInfo | Select-Object 'LUN', 'LUN ID', 'Capacity GB', 'Used Capacity GB', 'State' | Table @TableParams
                                                }
                                            }
                                        }
                                    }
                                    #endregion vSAN Cluster Section
                                }
                            }
                            #endregion vSAN Cluster Detailed Information
                        }
                    }
                }
                #endregion vSAN Section

                #region Datastore Section
                Write-PScriboMessage "Datastore InfoLevel set at $($InfoLevel.Datastore)."
                if ($InfoLevel.Datastore -ge 1) {
                    if ($Datastores) {
                        Section -Style Heading2 'Datastores' {
                            Paragraph "The following sections detail the configuration of datastores managed by vCenter Server $vCenterServerName."
                            #region Datastore Infomative Information
                            if ($InfoLevel.Datastore -le 2) {
                                BlankLine
                                $DatastoreInfo = foreach ($Datastore in $Datastores) {
                                    [PSCustomObject]@{
                                        'Datastore' = $Datastore.Name
                                        'Type' = $Datastore.Type
                                        'Version' = Switch ($Datastore.FileSystemVersion) {
                                            $null { '--' }
                                            default { $Datastore.FileSystemVersion }
                                        }
                                        '# of Hosts' = $Datastore.ExtensionData.Host.Count
                                        '# of VMs' = $Datastore.ExtensionData.VM.Count
                                        'Total Capacity GB' = [math]::Round($Datastore.CapacityGB, 2)
                                        'Used Capacity GB' = [math]::Round((($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)), 2)
                                        'Free Space GB' = [math]::Round($Datastore.FreeSpaceGB, 2)
                                        '% Used' = [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2)
                                    }
                                }
                                if ($Healthcheck.Datastore.CapacityUtilization) {
                                    $DatastoreInfo | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                    $DatastoreInfo | Where-Object { $_.'% Used' -ge 75 -and
                                        $_.'% Used' -lt 90 } | Set-Style -Style Warning -Property '% Used'
                                }
                                $TableParams = @{
                                    Name = "Datastore Summary - $($vCenterServerName)"
                                    ColumnWidths = 20, 9, 9, 9, 9, 11, 11, 11, 11
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $DatastoreInfo | Sort-Object Datastore | Table @TableParams
                            }
                            #endregion Datastore Advanced Summary

                            #region Datastore Detailed Information
                            if ($InfoLevel.Datastore -ge 3) {
                                foreach ($Datastore in $Datastores) {
                                    # TODO: Test Tags
                                    #region Datastore Section
                                    Section -Style Heading3 $Datastore.Name {
                                        $DatastoreDetail = [PSCustomObject]@{
                                            'Datastore' = $Datastore.Name
                                            'ID' = $Datastore.Id
                                            'Datacenter' = $Datastore.Datacenter
                                            'Type' = $Datastore.Type
                                            'Version' = Switch ($Datastore.FileSystemVersion) {
                                                $null { '--' }
                                                default { $Datastore.FileSystemVersion }
                                            }
                                            'State' = $Datastore.State
                                            'Number of Hosts' = $Datastore.ExtensionData.Host.Count
                                            'Number of VMs' = $Datastore.ExtensionData.VM.Count
                                            'Storage I/O Control' = Switch ($Datastore.StorageIOControlEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Congestion Threshold' = Switch ($Datastore.CongestionThresholdMillisecond) {
                                                $null { '--' }
                                                default { "$($Datastore.CongestionThresholdMillisecond) ms" }
                                            }
                                            'Total Capacity' = "$([math]::Round($Datastore.CapacityGB, 2)) GB"
                                            'Used Capacity' = "$([math]::Round((($Datastore.CapacityGB) - ($Datastore.FreeSpaceGB)), 2)) GB"
                                            'Free Space' = "$([math]::Round($Datastore.FreeSpaceGB, 2)) GB"
                                            '% Used' = [math]::Round((100 - (($Datastore.FreeSpaceGB) / ($Datastore.CapacityGB) * 100)), 2)
                                        }
                                        if ($Healthcheck.Datastore.CapacityUtilization) {
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                            $DatastoreDetail | Where-Object { $_.'% Used' -ge 75 -and
                                                $_.'% Used' -lt 90 } | Set-Style -Style Warning -Property '% Used'
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $DatastoreDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        <#
                                        if ($TagAssignments | Where-Object {$_.entity -eq $Datastore}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $Datastore}).Tag -join ',')
                                        }
                                        #>

                                        #region Datastore Advanced Detailed Information
                                        if ($InfoLevel.Datastore -ge 4) {
                                            $DatastoreHosts = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                            }
                                            Add-Member @MemberProps -Name 'Hosts' -Value (($DatastoreHosts | Sort-Object) -join ', ')
                                            $DatastoreVMs = foreach ($DatastoreVM in $Datastore.ExtensionData.VM) {
                                                $VMLookup."$($DatastoreVM.Type)-$($DatastoreVM.Value)"
                                            }
                                            Add-Member @MemberProps -Name 'Virtual Machines' -Value (($DatastoreVMs | Sort-Object) -join ', ')
                                        }
                                        #endregion Datastore Advanced Detailed Information
                                        $TableParams = @{
                                            Name = "Datastore Configuration - $($Datastore.Name)"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $DatastoreDetail | Sort-Object Datacenter, Name | Table @TableParams

                                        # Get VMFS volumes. Ignore local SCSILuns.
                                        if (($Datastore.Type -eq 'VMFS') -and ($Datastore.ExtensionData.Info.Vmfs.Local -eq $false)) {
                                            #region SCSI LUN Information Section
                                            Section -Style Heading4 'SCSI LUN Information' {
                                                $ScsiLuns = foreach ($DatastoreHost in $Datastore.ExtensionData.Host.Key) {
                                                    $DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
                                                    $ScsiDeviceDetailProps = @{
                                                        'VMHosts' = $VMHosts
                                                        'VMHostMoRef' = "$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                        'DatastoreDiskName' = $DiskName
                                                    }
                                                    $ScsiDeviceDetail = Get-ScsiDeviceDetail @ScsiDeviceDetailProps

                                                    [PSCustomObject]@{
                                                        'Host' = $VMHostLookup."$($DatastoreHost.Type)-$($DatastoreHost.Value)"
                                                        'Canonical Name' = $DiskName
                                                        'Capacity GB' = $ScsiDeviceDetail.CapacityGB
                                                        'Vendor' = $ScsiDeviceDetail.Vendor
                                                        'Model' = $ScsiDeviceDetail.Model
                                                        'Is SSD' = $ScsiDeviceDetail.Ssd
                                                        'Multipath Policy' = $ScsiDeviceDetail.MultipathPolicy
                                                        'Paths' = $ScsiDeviceDetail.Paths
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "SCSI LUN Information - $($vCenterServerName)"
                                                    ColumnWidths = 19, 19, 10, 10, 10, 10, 14, 8
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $ScsiLuns | Sort-Object Host | Table @TableParams
                                            }
                                            #endregion SCSI LUN Information Section
                                        }
                                    }
                                    #endregion Datastore Section
                                }
                            }
                            #endregion Datastore Detailed Information
                        }
                    }
                }
                #endregion Datastore Section

                #region Datastore Clusters
                Write-PScriboMessage "DSCluster InfoLevel set at $($InfoLevel.DSCluster)."
                if ($InfoLevel.DSCluster -ge 1) {
                    $DSClusters = Get-DatastoreCluster -Server $vCenter
                    if ($DSClusters) {
                        #region Datastore Clusters Section
                        Section -Style Heading2 'Datastore Clusters' {
                            Paragraph "The following sections detail the configuration of datastore clusters managed by vCenter Server $vCenterServerName."
                            #region Datastore Cluster Advanced Summary
                            if ($InfoLevel.DSCluster -le 2) {
                                BlankLine
                                $DSClusterInfo = foreach ($DSCluster in $DSClusters) {
                                    [PSCustomObject]@{
                                        'Datastore Cluster' = $DSCluster.Name
                                        'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                            'FullyAutomated' { 'Fully Automated' }
                                            'Manual' { 'Manual' }
                                            default { $DSCluster.SdrsAutomationLevel }
                                        }
                                        'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                        'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                            $true { 'Enabled' }
                                            $false { 'Disabled' }
                                        }
                                        'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                    }
                                }
                                if ($Healthcheck.DSCluster.SDRSAutomationLevelFullyAuto) {
                                    $DSClusterInfo | Where-Object { $_.'SDRS Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                }
                                $TableParams = @{
                                    Name = "Datastore Cluster Configuration - $($DSCluster.Name)"
                                    ColumnWidths = 20, 20, 20, 20, 20
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $DSClusterInfo | Sort-Object Name | Table @TableParams
                            }
                            #endregion Datastore Cluster Advanced Summary

                            #region Datastore Cluster Detailed Information
                            if ($InfoLevel.DSCluster -ge 3) {
                                foreach ($DSCluster in $DSClusters) {
                                    # TODO: Space Load Balance Config, IO Load Balance Config, Rules
                                    # TODO: Test Tags
                                    Section -Style Heading3 $DSCluster.Name {
                                        Paragraph ("The following table details the configuration " +
                                            "for datastore cluster $DSCluster.")
                                        BlankLine

                                        $DSClusterDetail = [PSCustomObject]@{
                                            'Datastore Cluster' = $DSCluster.Name
                                            'ID' = $DSCluster.Id
                                            'SDRS Automation Level' = Switch ($DSCluster.SdrsAutomationLevel) {
                                                'FullyAutomated' { 'Fully Automated' }
                                                'Manual' { 'Manual' }
                                                default { $DSCluster.SdrsAutomationLevel }
                                            }
                                            'Space Utilization Threshold' = "$($DSCluster.SpaceUtilizationThresholdPercent)%"
                                            'I/O Load Balance' = Switch ($DSCluster.IOLoadBalanceEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'I/O Latency Threshold' = "$($DSCluster.IOLatencyThresholdMillisecond) ms"
                                            'Capacity' = "$([math]::Round($DSCluster.CapacityGB, 2)) GB"
                                            'Free Space' = "$([math]::Round($DSCluster.FreeSpaceGB, 2)) GB"
                                            '% Used' = Switch ($DSCluster.CapacityGB -gt 0) {
                                                $true { [math]::Round((100 - (($DSCluster.FreeSpaceGB) / ($DSCluster.CapacityGB) * 100)), 2) }
                                                $false { '0' }
                                            }
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $DSClusterDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        <#
                                        if ($TagAssignments | Where-Object {$_.entity -eq $DSCluster}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $DSCluster}).Tag -join ',')
                                        }
                                        #>
                                        if ($Healthcheck.DSCluster.CapacityUtilization) {
                                            $DSClusterDetail | Where-Object { $_.'% Used' -ge 90 } | Set-Style -Style Critical -Property '% Used'
                                            $DSClusterDetail | Where-Object { $_.'% Used' -ge 75 -and $_.'% Used' -lt 90 } | Set-Style -Style Critical -Property '% Used'
                                        }
                                        if ($Healthcheck.DSCluster.SDRSAutomationLevel) {
                                            $DSClusterDetail | Where-Object { $_.'SDRS Automation Level' -ne 'Fully Automated' } | Set-Style -Style Warning -Property 'SDRS Automation Level'
                                        }
                                        $TableParams = @{
                                            Name = "Datastore Cluster Configuration - $($DSCluster.Name)"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $DSClusterDetail | Table @TableParams

                                        #region SDRS VM Overrides
                                        $StoragePodProps = @{
                                            'ViewType' = 'StoragePod'
                                            'Filter' = @{'Name' = $DSCluster.Name }
                                        }
                                        $StoragePod = Get-View @StoragePodProps
                                        if ($StoragePod) {
                                            $PodConfig = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.PodConfig
                                            # Set default automation value variables
                                            Switch ($PodConfig.DefaultVmBehavior) {
                                                "automated" { $DefaultVmBehavior = "Default (Fully Automated)" }
                                                "manual" { $DefaultVmBehavior = "Default (No Automation (Manual Mode))" }
                                            }
                                            Switch ($PodConfig.DefaultIntraVmAffinity) {
                                                $true { $DefaultIntraVmAffinity = "Default (Yes)" }
                                                $false { $DefaultIntraVmAffinity = "Default (No)" }
                                            }
                                            $VMOverrides = $StoragePod.PodStorageDrsEntry.StorageDrsConfig.VmConfig | Where-Object {
                                                -not (
                                                    ($null -eq $_.Enabled) -and
                                                    ($null -eq $_.IntraVmAffinity)
                                                )
                                            }
                                        }

                                        if ($VMOverrides) {
                                            $VMOverrideDetails = foreach ($Override in $VMOverrides) {
                                                [PSCustomObject]@{
                                                    'Virtual Machine' = $VMLookup."$($Override.Vm.Type)-$($Override.Vm.Value)"
                                                    'SDRS Automation Level' = Switch ($Override.Enabled) {
                                                        $true { 'Fully Automated' }
                                                        $false { 'Disabled' }
                                                        $null { $DefaultVmBehavior }
                                                    }
                                                    'Keep VMDKs Together' = Switch ($Override.IntraVmAffinity) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                        $null { $DefaultIntraVmAffinity }
                                                    }
                                                }
                                            }
                                            Section -Style Heading4 'SDRS VM Overrides' {
                                                $TableParams = @{
                                                    Name = "SDRS VM Overrides - $($DSCluster.Name)"
                                                    ColumnWidths = 50, 30, 20
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMOverrideDetails | Sort-Object 'Virtual Machine' | Table @TableParams
                                            }
                                        }
                                        #endregion SDRS VM Overrides
                                    }
                                }
                            }
                            #endregion Datastore Cluster Detailed Information
                        }
                        #endregion Datastore Clusters Section
                    }
                }
                #endregion Datastore Clusters

                #region Virtual Machine Section
                Write-PScriboMessage "VM InfoLevel set at $($InfoLevel.VM)."
                if ($InfoLevel.VM -ge 1) {
                    if ($VMs) {
                        Section -Style Heading2 'Virtual Machines' {
                            Paragraph "The following sections detail the configuration of virtual machines managed by vCenter Server $vCenterServerName."
                            #region Virtual Machine Summary Information
                            if ($InfoLevel.VM -eq 1) {
                                BlankLine
                                $VMSummary = [PSCustomObject]@{
                                    'Total VMs' = $VMs.Count
                                    'Total vCPUs' = ($VMs | Measure-Object -Property NumCpu -Sum).Sum
                                    'Total Memory' = "$([math]::Round(($VMs | Measure-Object -Property MemoryGB -Sum).Sum, 2)) GB"
                                    'Total Provisioned Space' = "$([math]::Round(($VMs | Measure-Object -Property ProvisionedSpaceGB -Sum).Sum, 2)) GB"
                                    'Total Used Space' = "$([math]::Round(($VMs | Measure-Object -Property UsedSpaceGB -Sum).Sum, 2)) GB"
                                    'VMs Powered On' = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                                    'VMs Powered Off' = ($VMs | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count
                                    'VMs Orphaned' = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Orphaned' }).Count
                                    'VMs Inaccessible' = ($VMs | Where-Object { $_.ExtensionData.Runtime.ConnectionState -eq 'Inaccessible' }).Count
                                    'VMs Suspended' = ($VMs | Where-Object { $_.PowerState -eq 'Suspended' }).Count
                                    'VMs with Snapshots' = ($VMs | Where-Object { $_.ExtensionData.Snapshot }).Count
                                    'Guest Operating System Types' = (($VMs | Get-View).Summary.Config.GuestFullName | Select-Object -Unique).Count
                                    'VM Tools OK' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOK' }).Count
                                    'VM Tools Old' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsOld' }).Count
                                    'VM Tools Not Running' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotRunning' }).Count
                                    'VM Tools Not Installed' = ($VMs | Where-Object { $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotInstalled' }).Count
                                }
                                $TableParams = @{
                                    Name = "VM Summary - $($vCenterServerName)"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMSummary | Table @TableParams
                            }
                            #endregion Virtual Machine Summary Information

                            #region Virtual Machine Advanced Summary
                            if ($InfoLevel.VM -eq 2) {
                                BlankLine
                                $VMSnapshotList = $VMs.Extensiondata.Snapshot.RootSnapshotList
                                $VMInfo = foreach ($VM in $VMs) {
                                    $VMView = $VM | Get-View
                                    [PSCustomObject]@{
                                        'Virtual Machine' = $VM.Name
                                        'Power State' = Switch ($VM.PowerState) {
                                            'PoweredOn' { 'On' }
                                            'PoweredOff' { 'Off' }
                                            default { $VM.PowerState }
                                        }
                                        'IP Address' = Switch ($VMView.Guest.IpAddress) {
                                            $null { '--' }
                                            default { $VMView.Guest.IpAddress }
                                        }
                                        'vCPUs' = $VM.NumCpu
                                        'Memory GB' = [math]::Round(($VM.MemoryGB), 0)
                                        'Provisioned GB' = [math]::Round(($VM.ProvisionedSpaceGB), 2)
                                        'Used GB' = [math]::Round(($VM.UsedSpaceGB), 2)
                                        'HW Version' = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                        'VM Tools Status' = Switch ($VMView.Guest.ToolsStatus) {
                                            'toolsOld' { 'Old' }
                                            'toolsOK' { 'OK' }
                                            'toolsNotRunning' { 'Not Running' }
                                            'toolsNotInstalled' { 'Not Installed' }
                                            default { $VMView.Guest.ToolsStatus }
                                        }
                                    }
                                }
                                if ($Healthcheck.VM.VMToolsStatus) {
                                    $VMInfo | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                }
                                if ($Healthcheck.VM.PowerState) {
                                    $VMInfo | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                }
                                $TableParams = @{
                                    Name = "VM Advanced Summary - $($vCenterServerName)"
                                    ColumnWidths = 21, 8, 16, 9, 9, 9, 9, 9, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VMInfo | Table @TableParams

                                #region VM Snapshot Information
                                if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                    Section -Style Heading3 'Snapshots' {
                                        $VMSnapshotInfo = foreach ($VMSnapshot in $VMSnapshotList) {
                                            [PSCustomObject]@{
                                                'Virtual Machine' = $VMLookup."$($VMSnapshot.VM)"
                                                'Snapshot Name' = $VMSnapshot.Name
                                                'Description' = $VMSnapshot.Description
                                                'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                            }
                                        }
                                        if ($Healthcheck.VM.VMSnapshots) {
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning
                                            $VMSnapshotInfo | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                        }
                                        $TableParams = @{
                                            Name = "VM Snapshot Summary - $($vCenterServerName)"
                                            ColumnWidths = 30, 30, 30, 10
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $VMSnapshotInfo | Table @TableParams
                                    }
                                }
                                #endregion VM Snapshot Information
                            }
                            #endregion Virtual Machine Advanced Summary

                            #region Virtual Machine Detailed Information
                            # TODO: Test Tags
                            if ($InfoLevel.VM -ge 3) {
                                if ($UserRole.Privilege -contains 'StorageProfile.View') {
                                    $VMSpbmConfig = Get-SpbmEntityConfiguration -VM ($VMs) | Where-Object { $null -ne $_.StoragePolicy }
                                } else {
                                    Write-PScriboMessage "Insufficient user privileges to report VM storage policies. Please ensure the user account has the 'Storage Profile > View' privilege assigned."
                                }
                                if ($InfoLevel.VM -ge 4) {
                                    $VMHardDisks = Get-HardDisk -VM ($VMs) -Server $vCenter
                                }
                                foreach ($VM in $VMs) {
                                    Section -Style Heading3 $VM.name {
                                        $VMUptime = Get-Uptime -VM $VM
                                        $VMSpbmPolicy = $VMSpbmConfig | Where-Object { $_.entity -eq $vm }
                                        $VMView = $VM | Get-View
                                        $VMSnapshotList = $vmview.Snapshot.RootSnapshotList
                                        $VMDetail = [PSCustomObject]@{
                                            'Virtual Machine' = $VM.Name
                                            'ID' = $VM.Id
                                            'Operating System' = $VMView.Summary.Config.GuestFullName
                                            'Hardware Version' = ($VM.HardwareVersion).Replace('vmx-', 'v')
                                            'Power State' = Switch ($VM.PowerState) {
                                                'PoweredOn' { 'On' }
                                                'PoweredOff' { 'Off' }
                                                default { $TextInfo.ToTitleCase($VM.PowerState) }
                                            }
                                            'Connection State' = $TextInfo.ToTitleCase($VM.ExtensionData.Runtime.ConnectionState)
                                            'VM Tools Status' = Switch ($VMView.Guest.ToolsStatus) {
                                                'toolsOld' { 'Old' }
                                                'toolsOK' { 'OK' }
                                                'toolsNotRunning' { 'Not Running' }
                                                'toolsNotInstalled' { 'Not Installed' }
                                                default { $TextInfo.ToTitleCase($VMView.Guest.ToolsStatus) }
                                            }
                                            'Fault Tolerance State' = Switch ($VMView.Runtime.FaultToleranceState) {
                                                'notConfigured' { 'Not Configured' }
                                                'needsSecondary' { 'Needs Secondary' }
                                                'running' { 'Running' }
                                                'disabled' { 'Disabled' }
                                                'starting' { 'Starting' }
                                                'enabled' { 'Enabled' }
                                                default { $TextInfo.ToTitleCase($VMview.Runtime.FaultToleranceState) }
                                            }
                                            'Host' = $VM.VMHost.Name
                                            'Parent' = $VM.VMHost.Parent.Name
                                            'Parent Folder' = $VM.Folder.Name
                                            'Parent Resource Pool' = $VM.ResourcePool.Name
                                            'vCPUs' = $VM.NumCpu
                                            'Cores per Socket' = $VM.CoresPerSocket
                                            'CPU Shares' = "$($VM.VMResourceConfiguration.CpuSharesLevel) / $($VM.VMResourceConfiguration.NumCpuShares)"
                                            'CPU Reservation' = $VM.VMResourceConfiguration.CpuReservationMhz
                                            'CPU Limit' = "$($VM.VMResourceConfiguration.CpuReservationMhz) MHz"
                                            'CPU Hot Add' = Switch ($VMView.Config.CpuHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'CPU Hot Remove' = Switch ($VMView.Config.CpuHotRemoveEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Memory Allocation' = "$([math]::Round(($VM.memoryGB), 2)) GB"
                                            'Memory Shares' = "$($VM.VMResourceConfiguration.MemSharesLevel) / $($VM.VMResourceConfiguration.NumMemShares)"
                                            'Memory Hot Add' = Switch ($VMView.Config.MemoryHotAddEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'vNICs' = $VMView.Summary.Config.NumEthernetCards
                                            'DNS Name' = if ($VMView.Guest.HostName) {
                                                $VMView.Guest.HostName
                                            } else {
                                                '--'
                                            }
                                            'Networks' = if ($VMView.Guest.Net.Network) {
                                                (($VMView.Guest.Net | Where-Object { $null -ne $_.Network } | Select-Object Network | Sort-Object Network).Network -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'IP Address' = if ($VMView.Guest.Net.IpAddress) {
                                                (($VMView.Guest.Net | Where-Object { ($null -ne $_.Network) -and ($null -ne $_.IpAddress) } | Select-Object IpAddress | Sort-Object IpAddress).IpAddress -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'MAC Address' = if ($VMView.Guest.Net.MacAddress) {
                                                (($VMView.Guest.Net | Where-Object { $null -ne $_.Network } | Select-Object -Property MacAddress).MacAddress -join ', ')
                                            } else {
                                                '--'
                                            }
                                            'vDisks' = $VMView.Summary.Config.NumVirtualDisks
                                            'Provisioned Space' = "$([math]::Round(($VM.ProvisionedSpaceGB), 2)) GB"
                                            'Used Space' = "$([math]::Round(($VM.UsedSpaceGB), 2)) GB"
                                            'Changed Block Tracking' = Switch ($VMView.Config.ChangeTrackingEnabled) {
                                                $true { 'Enabled' }
                                                $false { 'Disabled' }
                                            }
                                            'Storage Based Policy' = Switch ($VMSpbmPolicy.StoragePolicy.Name) {
                                                $null { '--' }
                                                default { $TextInfo.ToTitleCase($VMSpbmPolicy.StoragePolicy.Name) }
                                            }
                                            'Storage Based Policy Compliance' = Switch ($VMSpbmPolicy.ComplianceStatus) {
                                                $null { '--' }
                                                'compliant' { 'Compliant' }
                                                'nonCompliant' { 'Non Compliant' }
                                                'unknown' { 'Unknown' }
                                                default { $TextInfo.ToTitleCase($VMSpbmPolicy.ComplianceStatus) }
                                            }
                                        }
                                        $MemberProps = @{
                                            'InputObject' = $VMDetail
                                            'MemberType' = 'NoteProperty'
                                        }
                                        #if ($VMView.Config.CreateDate) {
                                        #    Add-Member @MemberProps -Name 'Creation Date' -Value ($VMView.Config.CreateDate).ToLocalTime()
                                        #}
                                        <#
                                        if ($TagAssignments | Where-Object {$_.entity -eq $VM}) {
                                            Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $VM}).Tag -join ',')
                                        }
                                        #>
                                        if ($VM.Notes) {
                                            Add-Member @MemberProps -Name 'Notes' -Value $VM.Notes
                                        }
                                        if ($VMView.Runtime.BootTime) {
                                            Add-Member @MemberProps -Name 'Boot Time' -Value ($VMView.Runtime.BootTime).ToLocalTime()
                                        }
                                        if ($VMUptime.UptimeDays) {
                                            Add-Member @MemberProps -Name 'Uptime Days' -Value $VMUptime.UptimeDays
                                        }

                                        #region VM Health Checks
                                        if ($Healthcheck.VM.VMToolsStatus) {
                                            $VMDetail | Where-Object { $_.'VM Tools Status' -ne 'OK' } | Set-Style -Style Warning -Property 'VM Tools Status'
                                        }
                                        if ($Healthcheck.VM.PowerState) {
                                            $VMDetail | Where-Object { $_.'Power State' -ne 'On' } | Set-Style -Style Warning -Property 'Power State'
                                        }
                                        if ($Healthcheck.VM.ConnectionState) {
                                            $VMDetail | Where-Object { $_.'Connection State' -ne 'Connected' } | Set-Style -Style Critical -Property 'Connection State'
                                        }
                                        if ($Healthcheck.VM.CpuHotAdd) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Add'
                                        }
                                        if ($Healthcheck.VM.CpuHotRemove) {
                                            $VMDetail | Where-Object { $_.'CPU Hot Remove' -eq 'Enabled' } | Set-Style -Style Warning -Property 'CPU Hot Remove'
                                        }
                                        if ($Healthcheck.VM.MemoryHotAdd) {
                                            $VMDetail | Where-Object { $_.'Memory Hot Add' -eq 'Enabled' } | Set-Style -Style Warning -Property 'Memory Hot Add'
                                        }
                                        if ($Healthcheck.VM.ChangeBlockTracking) {
                                            $VMDetail | Where-Object { $_.'Changed Block Tracking' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Changed Block Tracking'
                                        }
                                        if ($Healthcheck.VM.SpbmPolicyCompliance) {
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Unknown' } | Set-Style -Style Warning -Property 'Storage Based Policy Compliance'
                                            $VMDetail | Where-Object { $_.'Storage Based Policy Compliance' -eq 'Non Compliant' } | Set-Style -Style Critical -Property 'Storage Based Policy Compliance'
                                        }
                                        #endregion VM Health Checks
                                        $TableParams = @{
                                            Name = "VM Configuration - $($VM.Name)"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $VMDetail | Table @TableParams

                                        if ($InfoLevel.VM -ge 4) {
                                            $VMnics = $VM.Guest.Nics | Where-Object { $null -ne $_.Device } | Sort-Object Device
                                            $VMHdds = $VMHardDisks | Where-Object { $_.ParentId -eq $VM.Id } | Sort-Object Name
                                            $SCSIControllers = $VMView.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -match "SCSI Controller" }
                                            $VMGuestVols = $VM.Guest.Disks | Sort-Object Path
                                            if ($VMnics) {
                                                Section -Style Heading4 "Network Adapters" {
                                                    $VMnicInfo = foreach ($VMnic in $VMnics) {
                                                        [PSCustomObject]@{
                                                            'Adapter' = $VMnic.Device
                                                            'Connected' = $VMnic.Connected
                                                            'Network Name' = Switch -wildcard ($VMnic.Device.NetworkName) {
                                                                'dvportgroup*' { $VDPortgroupLookup."$($VMnic.Device.NetworkName)" }
                                                                default { $VMnic.Device.NetworkName }
                                                            }
                                                            'Adapter Type' = $VMnic.Device.Type
                                                            'IP Address' = $VMnic.IpAddress -join [Environment]::NewLine
                                                            'MAC Address' = $VMnic.Device.MacAddress
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "Network Adapters - $($VM.Name)"
                                                        ColumnWidths = 20, 12, 16, 12, 20, 20
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMnicInfo | Table @TableParams
                                                }
                                            }
                                            if ($SCSIControllers) {
                                                Section -Style Heading4 "SCSI Controllers" {
                                                    $VMScsiControllers = foreach ($VMSCSIController in $SCSIControllers) {
                                                        [PSCustomObject]@{
                                                            'Device' = $VMSCSIController.DeviceInfo.Label
                                                            'Controller Type' = $VMSCSIController.DeviceInfo.Summary
                                                            'Bus Sharing' = Switch ($VMSCSIController.SharedBus) {
                                                                'noSharing' { 'None' }
                                                                default { $VMSCSIController.SharedBus }
                                                            }
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "SCSI Controllers - $($VM.Name)"
                                                        ColumnWidths = 33, 34, 33
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMScsiControllers | Sort-Object 'Device' | Table @TableParams
                                                }
                                            }
                                            if ($VMHdds) {
                                                Section -Style Heading4 "Hard Disks" {
                                                    If ($InfoLevel.VM -eq 4) {
                                                        $VMHardDiskInfo = foreach ($VMHdd in $VMHdds) {
                                                            $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                            $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                            [PSCustomObject]@{
                                                                'Disk' = $VMHdd.Name
                                                                'Datastore' = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                                'Capacity' = "$([math]::Round(($VMHdd.CapacityGB), 2)) GB"
                                                                'Disk Provisioning' = Switch ($VMHdd.StorageFormat) {
                                                                    'EagerZeroedThick' { 'Thick Eager Zeroed' }
                                                                    'LazyZeroedThick' { 'Thick Lazy Zeroed' }
                                                                    $null { '--' }
                                                                    default { $VMHdd.StorageFormat }
                                                                }
                                                                'Disk Type' = Switch ($VMHdd.DiskType) {
                                                                    'RawPhysical' { 'Physical RDM' }
                                                                    'RawVirtual' { "Virtual RDM" }
                                                                    'Flat' { 'VMDK' }
                                                                    default { $VMHdd.DiskType }
                                                                }
                                                                'Disk Mode' = Switch ($VMHdd.Persistence) {
                                                                    'IndependentPersistent' { 'Independent - Persistent' }
                                                                    'IndependentNonPersistent' { 'Independent - Nonpersistent' }
                                                                    'Persistent' { 'Dependent' }
                                                                    default { $VMHdd.Persistence }
                                                                }
                                                            }
                                                        }
                                                        $TableParams = @{
                                                            Name = "Hard Disk Configuration - $($VM.Name)"
                                                            ColumnWidths = 15, 25, 15, 15, 15, 15
                                                        }
                                                        if ($Report.ShowTableCaptions) {
                                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                                        }
                                                        $VMHardDiskInfo | Table @TableParams
                                                    } else {
                                                        foreach ($VMHdd in $VMHdds) {
                                                            Section -Style Heading5 "$($VMHdd.Name)" {
                                                                $SCSIDevice = $VMView.Config.Hardware.Device | Where-Object { $_.Key -eq $VMHdd.ExtensionData.Key -and $_.Backing.FileName -eq $VMHdd.FileName }
                                                                $SCSIController = $SCSIControllers | Where-Object { $SCSIDevice.ControllerKey -eq $_.Key }
                                                                $VMHardDiskInfo = [PSCustomObject]@{
                                                                    'Datastore' = $VMHdd.FileName.Substring($VMHdd.Filename.IndexOf("[") + 1, $VMHdd.Filename.IndexOf("]") - 1)
                                                                    'Capacity' = "$([math]::Round(($VMHdd.CapacityGB), 2)) GB"
                                                                    'Disk Path' = $VMHdd.Filename.Substring($VMHdd.Filename.IndexOf("]") + 2)
                                                                    'Disk Shares' = "$($TextInfo.ToTitleCase($VMHdd.ExtensionData.Shares.Level)) / $($VMHdd.ExtensionData.Shares.Shares)"
                                                                    'Disk Limit IOPs' = Switch ($VMHdd.ExtensionData.StorageIOAllocation.Limit) {
                                                                        '-1' { 'Unlimited' }
                                                                        default { $VMHdd.ExtensionData.StorageIOAllocation.Limit }
                                                                    }
                                                                    'Disk Provisioning' = Switch ($VMHdd.StorageFormat) {
                                                                        'EagerZeroedThick' { 'Thick Eager Zeroed' }
                                                                        'LazyZeroedThick' { 'Thick Lazy Zeroed' }
                                                                        $null { '--' }
                                                                        default { $VMHdd.StorageFormat }
                                                                    }
                                                                    'Disk Type' = Switch ($VMHdd.DiskType) {
                                                                        'RawPhysical' { 'Physical RDM' }
                                                                        'RawVirtual' { "Virtual RDM" }
                                                                        'Flat' { 'VMDK' }
                                                                        default { $VMHdd.DiskType }
                                                                    }
                                                                    'Disk Mode' = Switch ($VMHdd.Persistence) {
                                                                        'IndependentPersistent' { 'Independent - Persistent' }
                                                                        'IndependentNonPersistent' { 'Independent - Nonpersistent' }
                                                                        'Persistent' { 'Dependent' }
                                                                        default { $VMHdd.Persistence }
                                                                    }
                                                                    'SCSI Controller' = $SCSIController.DeviceInfo.Label
                                                                    'SCSI Address' = "$($SCSIController.BusNumber):$($VMHdd.ExtensionData.UnitNumber)"
                                                                }
                                                                $TableParams = @{
                                                                    Name = "Hard Disk $($VMHdd.Name) - $($VM.Name)"
                                                                    List = $true
                                                                    ColumnWidths = 25, 75
                                                                }
                                                                if ($Report.ShowTableCaptions) {
                                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                                }
                                                                $VMHardDiskInfo | Table @TableParams
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($VMGuestVols) {
                                                Section -Style Heading4 "Guest Volumes" {
                                                    $VMGuestDiskInfo = foreach ($VMGuestVol in $VMGuestVols) {
                                                        [PSCustomObject]@{
                                                            'Path' = $VMGuestVol.Path
                                                            'Capacity' = "$([math]::Round(($VMGuestVol.CapacityGB), 2)) GB"
                                                            'Used Space' = "$([math]::Round((($VMGuestVol.CapacityGB) - ($VMGuestVol.FreeSpaceGB)), 2)) GB"
                                                            'Free Space' = "$([math]::Round($VMGuestVol.FreeSpaceGB, 2)) GB"
                                                        }
                                                    }
                                                    $TableParams = @{
                                                        Name = "Guest Volumes - $($VM.Name)"
                                                        ColumnWidths = 25, 25, 25, 25
                                                    }
                                                    if ($Report.ShowTableCaptions) {
                                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                                    }
                                                    $VMGuestDiskInfo | Table @TableParams
                                                }
                                            }
                                        }


                                        if ($VMSnapshotList -and $Options.ShowVMSnapshots) {
                                            Section -Style Heading4 "Snapshots" {
                                                $VMSnapshots = foreach ($VMSnapshot in $VMSnapshotList) {
                                                    [PSCustomObject]@{
                                                        'Snapshot Name' = $VMSnapshot.Name
                                                        'Description' = $VMSnapshot.Description
                                                        'Days Old' = ((Get-Date).ToUniversalTime() - $VMSnapshot.CreateTime).Days
                                                    }
                                                }
                                                if ($Healthcheck.VM.VMSnapshots) {
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 7 } | Set-Style -Style Warning
                                                    $VMSnapshots | Where-Object { $_.'Days Old' -ge 14 } | Set-Style -Style Critical
                                                }
                                                $TableParams = @{
                                                    Name = "VM Snapshots - $($VM.Name)"
                                                    ColumnWidths = 45, 45, 10
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $VMSnapshots | Table @TableParams
                                            }
                                        }
                                    }
                                }
                            }
                            #endregion Virtual Machine Detailed Information
                        }
                    }
                }
                #endregion Virtual Machine Section

                #region VMware Update Manager Section
                Write-PScriboMessage "VUM InfoLevel set at $($InfoLevel.VUM)."
                if (($InfoLevel.VUM -ge 1) -and ($VumServer.Name)) {
                    if ("Desktop" -eq $PSVersionTable.PsEdition) {
                        $VUMBaselines = Get-PatchBaseline -Server $vCenter
                    } else {
                        Write-PScriboMessage 'VUM patch baseline information is not currently available with your version of PowerShell.'
                    }
                    if ($VUMBaselines) {
                        Section -Style Heading2 'VMware Update Manager' {
                            Paragraph "The following sections detail the configuration of VMware Update Manager managed by vCenter Server $vCenterServerName."
                            #region VUM Baseline Detailed Information
                            Section -Style Heading3 'Baselines' {
                                $VUMBaselineInfo = foreach ($VUMBaseline in $VUMBaselines) {
                                    [PSCustomObject]@{
                                        'Baseline' = $VUMBaseline.Name
                                        'Description' = $VUMBaseline.Description
                                        'Type' = $VUMBaseline.BaselineType
                                        'Target Type' = $VUMBaseline.TargetType
                                        'Last Update Time' = ($VUMBaseline.LastUpdateTime).ToLocalTime()
                                        '# of Patches' = $VUMBaseline.CurrentPatches.Count
                                    }
                                }
                                $TableParams = @{
                                    Name = "VMware Update Manager Baseline Summary - $($vCenterServerName)"
                                    ColumnWidths = 25, 25, 10, 10, 20, 10
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $VUMBaselineInfo | Sort-Object Baseline | Table @TableParams
                            }
                            #endregion VUM Baseline Detailed Information

                            #region VUM Comprehensive Information
                            if ("Desktop" -eq $PSVersionTable.PsEdition) {
                                $VUMPatches = Get-Patch -Server $vCenter | Sort-Object -Descending ReleaseDate
                            } else {
                                Write-PScriboMessage 'VUM patch information is not currently available with your version of PowerShell.'
                            }
                            if ($VUMPatches -and $InfoLevel.VUM -ge 5) {
                                BlankLine
                                Section -Style Heading3 'Patches' {
                                    $VUMPatchInfo = foreach ($VUMPatch in $VUMPatches) {
                                        [PSCustomObject]@{
                                            'Patch' = $VUMPatch.Name
                                            'Product' = ($VUMPatch.Product).Name
                                            'Description' = $VUMPatch.Description
                                            'Release Date' = $VUMPatch.ReleaseDate
                                            'Vendor ID' = $VUMPatch.IdByVendor
                                        }
                                    }
                                    $TableParams = @{
                                        Name = "VMware Update Manager Patch Information - $($vCenterServerName)"
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
                #endregion VMware Update Manager Section
            }
            #endregion vCenter Server Heading1 Section

            # Disconnect vCenter Server
            $Null = Disconnect-VIServer -Server $VIServer -Confirm:$false -ErrorAction SilentlyContinue
        } # End of If $vCenter
        #endregion Generate vSphere report

        #region Variable cleanup
        Clear-Variable -Name vCenter
        #endregion Variable cleanup

    } # End of Foreach $VIServer
    #endregion Script Body
} # End Invoke-AsBuiltReport.VMware.vSphere function