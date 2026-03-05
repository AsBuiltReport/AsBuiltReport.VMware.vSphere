function Get-AbrVSphereVMHostHardware {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere ESXi VMHost Hardware information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphereVMHostHardware
    }

    process {
        try {
            Write-PScriboMessage -Message $LocalizedData.Collecting
            #region ESXi Host Hardware Section
            Section -Style Heading4 $LocalizedData.SectionHeading {
                Paragraph ($LocalizedData.ParagraphSummary -f $VMHost)
                BlankLine

                #region ESXi Host Specifications
                $VMHostUptime = Get-Uptime -VMHost $VMHost
                $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
                $ScratchLocation = Get-AdvancedSetting -Entity $VMHost | Where-Object { $_.Name -eq 'ScratchConfig.CurrentScratchLocation' }
                $VMHostCpuTotal = [math]::Round(($VMHost.CpuTotalMhz) / 1000, 2)
                $VMHostCpuUsed = [math]::Round(($VMHost.CpuUsageMhz) / 1000, 2)
                $VMHostCpuFree = $VMHostCpuTotal - $VMHostCpuUsed
                $VMHostDetail = [PSCustomObject]@{
                    $LocalizedData.Host = $VMHost.Name
                    $LocalizedData.ConnectionState = switch ($VMHost.ConnectionState) {
                        'NotResponding' { $LocalizedData.NotResponding }
                        default { $TextInfo.ToTitleCase($VMHost.ConnectionState) }
                    }
                    $LocalizedData.ID = $VMHost.Id
                    $LocalizedData.Parent = $VMHost.Parent
                    $LocalizedData.Manufacturer = $VMHost.Manufacturer
                    $LocalizedData.Model = $VMHost.Model
                    $LocalizedData.SerialNumber = if ($VMHost.ExtensionData.Hardware.SystemInfo.SerialNumber) {
                        $VMHost.ExtensionData.Hardware.SystemInfo.SerialNumber
                    } else {
                        '--'
                    }
                    $LocalizedData.AssetTag = if ($VMHost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo[0].IdentifierValue) {
                        $VMHost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo[0].IdentifierValue
                    } else {
                        $LocalizedData.Unknown
                    }
                    $LocalizedData.ProcessorType = $VMHost.Processortype
                    $LocalizedData.HyperThreading = if ($VMHost.HyperthreadingActive) {
                        $LocalizedData.Enabled
                    } else {
                        $LocalizedData.Disabled
                    }
                    $LocalizedData.NumberOfCPUSockets = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
                    $LocalizedData.NumberOfCPUCores = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
                    $LocalizedData.NumberOfCPUThreads = $VMHost.ExtensionData.Hardware.CpuInfo.NumCpuThreads
                    $LocalizedData.CPUTotalUsedFree = "{0:N2} GHz / {1:N2} GHz / {2:N2} GHz" -f $VMHostCpuTotal, $VMHostCpuUsed, $VMHostCpuFree
                    $LocalizedData.MemoryTotalUsedFree = "{0} / {1} / {2}" -f (Convert-DataSize $VMHost.MemoryTotalGB), (Convert-DataSize $VMHost.MemoryUsageGB), (Convert-DataSize ($VMHost.MemoryTotalGB - $VMHost.MemoryUsageGB))
                    $LocalizedData.NUMANodes = $VMHost.ExtensionData.Hardware.NumaInfo.NumNodes
                    $LocalizedData.NumberOfNICs = $VMHost.ExtensionData.Summary.Hardware.NumNics
                    $LocalizedData.NumberOfHBAs = $VMHost.ExtensionData.Summary.Hardware.NumHBAs
                    $LocalizedData.NumberOfDatastores = ($VMHost.ExtensionData.Datastore).Count
                    $LocalizedData.NumberOfVMs = $VMHost.ExtensionData.VM.Count
                    $LocalizedData.MaximumEVCMode = $EvcModeLookup."$($VMHost.MaxEVCMode)"
                    $LocalizedData.EVCGraphicsMode = if ($VMHost.ExtensionData.Summary.CurrentEVCGraphicsModeKey) {
                        $VMHost.ExtensionData.Summary.CurrentEVCGraphicsModeKey
                    } else {
                        $LocalizedData.NotApplicable
                    }
                    $LocalizedData.PowerManagementPolicy = $VMHost.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy
                    $LocalizedData.ScratchLocation = $ScratchLocation.Value
                    $LocalizedData.BiosVersion = $VMHost.ExtensionData.Hardware.BiosInfo.BiosVersion
                    $LocalizedData.BiosReleaseDate = ($VMHost.ExtensionData.Hardware.BiosInfo.ReleaseDate).ToString()
                    $LocalizedData.Version = $VMHost.Version
                    $LocalizedData.Build = $VMHost.build
                    $LocalizedData.BootTime = ($VMHost.ExtensionData.Runtime.Boottime).ToLocalTime().ToString()
                    $LocalizedData.UptimeDays = $VMHostUptime.UptimeDays
                }
                $MemberProps = @{
                    'InputObject' = $VMHostDetail
                    'MemberType' = 'NoteProperty'
                }
                if ($UserPrivileges -contains 'Global.Licenses') {
                    try {
                        $VMHostLicense = Get-License -VMHost $VMHost
                        Add-Member @MemberProps -Name $LocalizedData.Product           -Value $VMHostLicense.Product
                        Add-Member @MemberProps -Name $LocalizedData.LicenseKey        -Value $VMHostLicense.LicenseKey
                        Add-Member @MemberProps -Name $LocalizedData.LicenseExpiration -Value $VMHostLicense.Expiration
                    } catch {
                        Write-PScriboMessage -IsWarning ($LocalizedData.LicenseError -f $VMHost.Name, $_.Exception.Message)
                    }
                } else {
                    Write-PScriboMessage -Message $LocalizedData.InsufficientPrivLicense
                }
                <#
                if ($TagAssignments | Where-Object {$_.entity -eq $VMHost}) {
                    Add-Member @MemberProps -Name 'Tags' -Value $(($TagAssignments | Where-Object {$_.entity -eq $VMHost}).Tag -join ',')
                }
                #>
                if ($Healthcheck.VMHost.ConnectionState) {
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.ConnectionState) -eq $LocalizedData.Maintenance } | Set-Style -Style Warning -Property $LocalizedData.ConnectionState
                }
                if ($Healthcheck.VMHost.HyperThreading) {
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.HyperThreading) -eq $LocalizedData.Disabled } | Set-Style -Style Warning -Property $LocalizedData.HyperThreading
                }
                if ($Healthcheck.VMHost.Licensing) {
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.Product) -like '*Evaluation*' } | Set-Style -Style Warning -Property $LocalizedData.Product
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.LicenseKey) -like '*-00000-00000' } | Set-Style -Style Warning -Property $LocalizedData.LicenseKey
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.LicenseExpiration) -eq 'Expired' } | Set-Style -Style Critical -Property $LocalizedData.LicenseExpiration
                }
                if ($Healthcheck.VMHost.ScratchLocation) {
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.ScratchLocation) -eq '/tmp/scratch' } | Set-Style -Style Warning -Property $LocalizedData.ScratchLocation
                }
                if ($Healthcheck.VMHost.UpTimeDays) {
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.UptimeDays) -ge 275 -and $_.$($LocalizedData.UptimeDays) -lt 365 } | Set-Style -Style Warning -Property $LocalizedData.UptimeDays
                    $VMHostDetail | Where-Object { $_.$($LocalizedData.UptimeDays) -ge 365 } | Set-Style -Style Critical -Property $LocalizedData.UptimeDays
                }
                $TableParams = @{
                    Name = ($LocalizedData.TableHardwareConfig -f $VMHost)
                    List = $true
                    ColumnWidths = 40, 60
                }
                if ($Report.ShowTableCaptions) {
                    $TableParams['Caption'] = "- $($TableParams.Name)"
                }
                $VMHostDetail | Table @TableParams
                #endregion ESXi Host Specifications

                #region ESXi IPMI/BMC Settings
                try {
                    $VMHostIPMI = $esxcli.hardware.ipmi.bmc.get.invoke()
                } catch {
                    Write-PScriboMessage -Message ($LocalizedData.IPMIBMCError -f $VMHost.Name, $_.Exception.Message)
                }
                if ($VMHostIPMI) {
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.IPMIBMC {
                            $VMHostIPMIInfo = [PSCustomObject]@{
                                $LocalizedData.Manufacturer = $VMHostIPMI.Manufacturer
                                $LocalizedData.MACAddress = $VMHostIPMI.MacAddress
                                $LocalizedData.IPMIBMCIPAddress = $VMHostIPMI.IPv4Address
                                $LocalizedData.SubnetMask = $VMHostIPMI.IPv4Subnet
                                $LocalizedData.Gateway = $VMHostIPMI.IPv4Gateway
                                $LocalizedData.FirmwareVersion = $VMHostIPMI.BMCFirmwareVersion
                            }

                            $TableParams = @{
                                Name = ($LocalizedData.TableIPMIBMC -f $VMHost)
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostIPMIInfo | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.IPMIBMCError -f $VMHost.Name, $_.Exception.Message)
                    }
                }
                #endregion ESXi IPMI/BMC Settings

                #region ESXi Host Boot Device
                try {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.BootDevice {
                        $ESXiBootDevice = Get-ESXiBootDevice -VMHost $VMHost
                        $VMHostBootDevice = [PSCustomObject]@{
                            $LocalizedData.Host = $ESXiBootDevice.Host
                            $LocalizedData.Device = $ESXiBootDevice.Device
                            $LocalizedData.BootType = $ESXiBootDevice.BootType
                            $LocalizedData.Vendor = $ESXiBootDevice.Vendor
                            $LocalizedData.Model = $ESXiBootDevice.Model
                            $LocalizedData.Size = switch ($ESXiBootDevice.SizeMB) {
                                'N/A' { 'N/A' }
                                default { Convert-DataSize $ESXiBootDevice.SizeMB -InputUnit MB -RoundUnits 0 }
                            }
                            $LocalizedData.BootDeviceIsSAS = $ESXiBootDevice.IsSAS
                            $LocalizedData.BootDeviceIsSSD = $ESXiBootDevice.IsSSD
                            $LocalizedData.BootDeviceIsUSB = $ESXiBootDevice.IsUSB
                        }
                        $TableParams = @{
                            Name = ($LocalizedData.TableBootDevice -f $VMHost)
                            List = $true
                            ColumnWidths = 40, 60
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostBootDevice | Table @TableParams
                    }
                } catch {
                    Write-PScriboMessage -Message ($LocalizedData.BootDeviceError -f $VMHost.Name, $_.Exception.Message)
                }
                #endregion ESXi Host Boot Devices

                #region ESXi Host PCI Devices
                try {
                    Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.PCIDevices {
                        <# Move away from esxcli.v2 implementation to be compatible with 8.x branch.
                        'Slot Description' information does not seem to be available through the API
                        Create an array with PCI Address and VMware Devices (vmnic,vmhba,?vmgfx?)
                        #>
                        $PciToDeviceMapping = @{}
                        $NetworkAdapters = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical
                        foreach ($adapter in $NetworkAdapters) {
                            $PciToDeviceMapping[$adapter.PciId] = $adapter.DeviceName
                        }
                        $hbAdapters = Get-VMHostHba -VMHost $VMHost
                        foreach ($adapter in $hbAdapters) {
                            $PciToDeviceMapping[$adapter.Pci] = $adapter.Device
                        }
                        <# Data Object - HostGraphicsInfo(vim.host.GraphicsInfo)
                        This function has been available since version 5.5, but we can't be sure if it is still valid.
                        I don't have access to a vGPU-enabled system.
                        #>
                        $GpuAdapters = (Get-VMHost $VMhost | Get-View -Property Config).Config.GraphicsInfo
                        foreach ($adapter in $GpuAdapters) {
                            $PciToDeviceMapping[$adapter.pciId] = $adapter.deviceName
                        }

                        $VMHostPciDevice = @{
                            VMHost = $VMHost
                            DeviceClass = @('MassStorageController', 'NetworkController', 'DisplayController', 'SerialBusController')
                        }
                        $PciDevices = Get-VMHostPciDevice @VMHostPciDevice

                        # Combine PciDevices and PciToDeviceMapping

                        $VMHostPciDevices = $PciDevices | ForEach-Object {
                            $PciDevice = $_
                            $device = $PCIToDeviceMapping[$pciDevice.Id]

                            if ($device) {
                                [PSCustomObject]@{
                                    $LocalizedData.Device = $device
                                    $LocalizedData.PCIAddress = $PciDevice.Id
                                    $LocalizedData.DeviceClass = $PciDevice.DeviceClass -replace ('Controller', "")
                                    $LocalizedData.PCIDeviceName = $PciDevice.DeviceName
                                    $LocalizedData.PCIVendorName = $PciDevice.VendorName
                                }
                            }
                        }

                        $TableParams = @{
                            Name = ($LocalizedData.TablePCIDevices -f $VMHost)
                            ColumnWidths = 17, 18, 15, 30, 20
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VMHostPciDevices | Sort-Object $LocalizedData.Device | Table @TableParams
                    }
                } catch {
                    Write-PScriboMessage -Message ($LocalizedData.PCIDeviceError -f $VMHost.Name, $_.Exception.Message)
                }
                #endregion ESXi Host PCI Devices

                #region ESXi Host PCI Devices Drivers & Firmware
                $VMHostPciDevicesDetails = Get-PciDeviceDetail -Server $vCenter -esxcli $esxcli | Sort-Object 'Device'
                if ($VMHostPciDevicesDetails) {
                    try {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.PCIDriversFirmware {
                            $TableParams = @{
                                Name = ($LocalizedData.TablePCIDriversFirmware -f $VMHost)
                                ColumnWidths = 12, 20, 11, 19, 11, 11, 16
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostPciDevicesDetails | Table @TableParams
                        }
                    } catch {
                        Write-PScriboMessage -Message ($LocalizedData.PCIDriversFirmwareError -f $VMHost.Name, $_.Exception.Message)
                    }
                }
                #endregion ESXi Host PCI Devices Drivers & Firmware

                #region ESXi Host I/O Device Identifiers
                try {
                    # Build PCI address -> VMkernel name mapping (VMkernelName is unpopulated on ESXi 8)
                    # Guard against null keys — software HBAs (iSCSI, software NVMe) have no PCI address
                    $IOPciToDevice = @{}
                    Get-VMHostNetworkAdapter -VMHost $VMHost -Physical | ForEach-Object {
                        if ($_.PciId) { $IOPciToDevice[$_.PciId] = $_.DeviceName }
                    }
                    Get-VMHostHba -VMHost $VMHost | ForEach-Object {
                        if ($_.Pci) { $IOPciToDevice[$_.Pci] = $_.Device }
                    }
                    (Get-VMHost $VMHost | Get-View -Property Config).Config.GraphicsInfo | ForEach-Object {
                        if ($_.pciId) { $IOPciToDevice[$_.pciId] = $_.deviceName }
                    }
                    $VMHostIODevices = $esxcli.hardware.pci.list.Invoke() |
                        Where-Object { $IOPciToDevice.ContainsKey($_.Address) } |
                        Sort-Object -Property Address
                    if ($VMHostIODevices) {
                        Section -Style NOTOCHeading5 -ExcludeFromTOC $LocalizedData.IODeviceIdentifiers {
                            $VMHostIODeviceInfo = $VMHostIODevices | ForEach-Object {
                                [PSCustomObject]@{
                                    $LocalizedData.Device      = $IOPciToDevice[$_.Address]
                                    $LocalizedData.Model       = $_.DeviceName
                                    $LocalizedData.VendorID    = [String]::Format("{0:x4}", $_.VendorID)
                                    $LocalizedData.DeviceID    = [String]::Format("{0:x4}", $_.DeviceID)
                                    $LocalizedData.SubVendorID = [String]::Format("{0:x4}", $_.SubVendorID)
                                    $LocalizedData.SubDeviceID = [String]::Format("{0:x4}", $_.SubDeviceID)
                                }
                            }
                            $TableParams = @{
                                Name         = ($LocalizedData.TableIODeviceIdentifiers -f $VMHost)
                                ColumnWidths = 13, 31, 14, 14, 14, 14
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VMHostIODeviceInfo | Sort-Object $LocalizedData.Device | Table @TableParams
                        }
                    }
                } catch {
                    Write-PScriboMessage -Message ($LocalizedData.IODeviceIdentifiersError -f $VMHost.Name, $_.Exception.Message)
                }
                #endregion ESXi Host I/O Device Identifiers
            }
        } catch {
            Write-PScriboMessage -Message ($LocalizedData.HardwareError -f $VMHost.Name, $_.Exception.Message)
        }
        #endregion ESXi Host Hardware Section
    }

    end {}
}
