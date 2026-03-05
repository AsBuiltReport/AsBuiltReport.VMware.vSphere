<!-- ********** DO NOT EDIT THESE LINKS ********** -->
<p align="center">
    <a href="https://www.asbuiltreport.com/" alt="AsBuiltReport"></a>
            <img src='https://github.com/AsBuiltReport.png' width="8%" height="8%" /></a>
</p>
<p align="center">
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.VMware.vSphere/" alt="PowerShell Gallery Version">
        <img src="https://img.shields.io/powershellgallery/v/AsBuiltReport.VMware.vSphere.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.VMware.vSphere/" alt="PS Gallery Downloads">
        <img src="https://img.shields.io/powershellgallery/dt/AsBuiltReport.VMware.vSphere.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.VMware.vSphere/" alt="PS Platform">
        <img src="https://img.shields.io/powershellgallery/p/AsBuiltReport.VMware.vSphere.svg" /></a>
</p>
<p align="center">
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/graphs/commit-activity" alt="GitHub Last Commit">
        <img src="https://img.shields.io/github/last-commit/AsBuiltReport/AsBuiltReport.VMware.vSphere/master.svg" /></a>
    <a href="https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/master/LICENSE" alt="GitHub License">
        <img src="https://img.shields.io/github/license/AsBuiltReport/AsBuiltReport.VMware.vSphere.svg" /></a>
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/graphs/contributors" alt="GitHub Contributors">
        <img src="https://img.shields.io/github/contributors/AsBuiltReport/AsBuiltReport.VMware.vSphere.svg"/></a>
</p>
<p align="center">
    <a href="https://twitter.com/AsBuiltReport" alt="Twitter">
            <img src="https://img.shields.io/twitter/follow/AsBuiltReport.svg?style=social"/></a>
</p>

<p align="center">
    <a href='https://ko-fi.com/B0B7DDGZ7' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://ko-fi.com/img/githubbutton_sm.svg' border='0' alt='Want to keep alive this project? Support me on Ko-fi' /></a>
</p>
<!-- ********** DO NOT EDIT THESE LINKS ********** -->

# VMware vSphere As Built Report

VMware vSphere As Built Report is a PowerShell module which works in conjunction with [AsBuiltReport.Core](https://github.com/AsBuiltReport/AsBuiltReport.Core).

[AsBuiltReport](https://github.com/AsBuiltReport/AsBuiltReport) is an open-sourced community project which utilises PowerShell to produce as-built documentation in multiple document formats for multiple vendors and technologies.

The VMware vSphere As Built Report module is used to generate as built documentation for VMware vSphere / vCenter Server environments.

> [!TIP]
> Please refer to the [VMware ESXi](https://github.com/AsBuiltReport/AsBuiltReport.VMware.ESXi)  AsBuiltReport for reporting of standalone VMware ESXi servers.

Please refer to the AsBuiltReport [website](https://www.asbuiltreport.com) for more detailed information about this project.

<!--
## :books: Sample Reports
### Sample Report 1 - Default Style
Sample vSphere As Built report with health checks, using default report style.

Sample VMware vSphere As Built report HTML file: [Sample VMware vSphere As Built Report.html](https://htmlpreview.github.io/?https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/dev/Samples/Sample%20VMware%20vSphere%20As%20Built%20Report.html)
-->

# :beginner: Getting Started
Below are the instructions on how to install, configure and generate a VMware vSphere As Built report.

## :floppy_disk: Supported Versions
The VMware vSphere As Built Report supports the following vSphere versions;
- vSphere 8.0

> [!IMPORTANT]
> Ongoing VMware product and licensing restrictions, combined with limited access to development environments and resources, prevent further development and support of this report module beyond VMware vSphere 8.0.

## :no_entry_sign: Unsupported Versions
The following VMware vSphere versions are no longer being tested and/or supported;
- vSphere 5.5
- vSphere 6.0
- vSphere 6.5
- vSphere 6.7
- vSphere 7.0

### PowerShell
This report is compatible with the following PowerShell versions;

<!-- ********** Update supported PowerShell versions ********** -->
| Windows PowerShell 5.1 |     PowerShell 7    |
|:----------------------:|:--------------------:|
|   :white_check_mark:   | :white_check_mark: |

## 🌐 Language Support
<!-- ********** Update supported languages ********** -->
The VMware vSphere As Built Report supports the following languages;

| Language | Culture Code |
|----------|--------------|
| English (US) | en-US (Default) |
| English (GB) | en-GB |
| French | fr-FR |
| German | de-DE |
| Spanish | es-ES |

## :wrench: System Requirements
<!-- ********** Update system requirements ********** -->
PowerShell 5.1 or PowerShell 7, and the following PowerShell modules are required for generating a VMware vSphere As Built report.

Each of these modules can be easily downloaded and installed via the PowerShell Gallery

- [VCF PowerCLI Module](https://www.powershellgallery.com/packages/VCF.PowerCLI/)
- [AsBuiltReport.VMware.vSphere Module](https://www.powershellgallery.com/packages/AsBuiltReport.VMware.vSphere/)

### :closed_lock_with_key: Required Privileges
<!-- ********** Define required privileges ********** -->
<!-- ********** Try to follow best practices to define least privileges ********** -->

A VMware vSphere As Built Report can be generated with read-only privileges, however the following sections will be skipped;

* vSphere licensing information
* VM Storage Policy information
* VMware Update Manager / Lifecycle Manager information

For a complete report, the following role assigned privileges are required;

* Global > Licenses
* Global > Settings
* Host > Configuration > Change Settings
* Profile-driven Storage > Profile-driven storage view
* VMware vSphere Update Manager > View Compliance Status

## :package: Module Installation

### PowerShell
<!-- ********** Add installation for any additional PowerShell module(s) ********** -->
Open a PowerShell terminal window and install each of the required modules.

> [!NOTE]
> VCF PowerCLI 9.0 or higher is required. Please ensure older PowerCLI versions have been uninstalled.

```powershell
# Install
install-module VCF.PowerCLI -MinimumVersion 9.0 -AllowClobber -SkipPublisherCheck
install-module AsBuiltReport.VMware.vSphere
```

### GitHub
If you are unable to use the PowerShell Gallery, you can still install the module manually. Ensure you repeat the following steps for the [system requirements](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere#wrench-system-requirements) also.

1. Download the code package / [latest release](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/latest) zip from GitHub
2. Extract the zip file
3. Copy the folder `AsBuiltReport.VMware.vSphere` to a path that is set in `$env:PSModulePath`.
4. Open a PowerShell terminal window and unblock the downloaded files with
    ```powershell
    $path = (Get-Module -Name AsBuiltReport.VMware.vSphere -ListAvailable).ModuleBase; Unblock-File -Path $path\*.psd1; Unblock-File -Path $path\Src\Public\*.ps1; Unblock-File -Path $path\Src\Private\*.ps1
    ```
5. Close and reopen the PowerShell terminal window.

_Note: You are not limited to installing the module to those example paths, you can add a new entry to the environment variable PSModulePath if you want to use another path._

## :pencil2: Configuration
The vSphere As Built Report utilises a JSON file to allow configuration of report information, options, detail and healthchecks.

> [!IMPORTANT]
> Please remember to generate a new report JSON configuration file after each module update to ensure the report functions correctly.

A VMware vSphere report configuration file can be generated by executing the following command;
```powershell
New-AsBuiltReportConfig -Report VMware.vSphere -FolderPath <User specified folder> -Filename <Optional>
```

Executing this command will copy the default vSphere report JSON configuration to a user specified folder.

All report settings can then be configured via the JSON file.

The following provides information of how to configure each schema within the report's JSON file.

<!-- ********** DO NOT CHANGE THE REPORT SCHEMA SETTINGS ********** -->
### Report
The **Report** schema provides configuration of the vSphere report information.

| Sub-Schema          | Setting      | Default                        | Description                                                  |
|---------------------|--------------|--------------------------------|--------------------------------------------------------------|
| Name                | User defined | VMware vSphere As Built Report | The name of the As Built Report                              |
| Version             | User defined | 1.0                            | The report version                                           |
| Status              | User defined | Released                       | The report release status
| Language            | User defined | en-US                           | The default report language. This can be customised if the report module provides multilingual support |                                   |
| ShowCoverPageImage  | true / false | true                           | Toggle to enable/disable the display of the cover page image |
| ShowTableOfContents | true / false | true                           | Toggle to enable/disable table of contents                   |
| ShowHeaderFooter    | true / false | true                           | Toggle to enable/disable document headers & footers          |
| ShowTableCaptions   | true / false | true                           | Toggle to enable/disable table captions/numbering            |

### Options
The **Options** schema allows certain options within the report to be toggled on or off.

| Sub-Schema      | Setting      | Default | Description                                                                                                                                                                                 |
|-----------------|--------------|---------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ShowLicenseKeys | true / false | false   | Toggle to mask/unmask vSphere license keys<br><br> **Masked License Key**<br>\*\*\*\*\*-\*\*\*\*\*-\*\*\*\*\*-\*\*\*\*\*-AS12K<br><br> **Unmasked License Key**<br>AKLU4-PFG8M-W2D8J-56YDM-AS12K |
| ShowVMSnapshots | true / false | true    | Toggle to enable/disable reporting of VM snapshots                                                                                                                                          |

<!-- ********** Add/Remove the number of InfoLevels as required ********** -->
### InfoLevel
The **InfoLevel** schema allows configuration of each section of the report at a granular level. The following sections can be set.

There are 6 levels (0-5) of detail granularity for each section as follows;

| Setting | InfoLevel         | Description                                                                                                                                |
|:-------:|-------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
|    0    | Disabled          | Does not collect or display any information                                                                                                |
|    1    | Enabled / Summary | Provides summarised information for a collection of objects                                                                                |
|    2    | Adv Summary       | Provides condensed, detailed information for a collection of objects                                                                       |
|    3    | Detailed          | Provides detailed information for individual objects                                                                                       |
|    4    | Adv Detailed      | Provides detailed information for individual objects, as well as information for associated objects (Hosts, Clusters, Datastores, VMs etc) |
|    5    | Comprehensive     | Provides comprehensive information for individual objects, such as advanced configuration settings                                         |

The table below outlines the default and maximum **InfoLevel** settings for each section.

| Sub-Schema   | Default Setting | Maximum Setting |
|--------------|:---------------:|:---------------:|
| vCenter      |        3        |        5        |
| Cluster      |        3        |        4        |
| ResourcePool |        3        |        4        |
| VMHost       |        3        |        5        |
| Network      |        3        |        4        |
| vSAN         |        3        |        4        |
| Datastore    |        3        |        4        |
| DSCluster    |        3        |        4        |
| VM           |        2        |        4        |
| VUM          |        3        |        5        |

### Healthcheck
The **Healthcheck** schema is used to toggle health checks on or off.

#### vCenter
The **vCenter** schema is used to configure health checks for vCenter Server.

| Sub-Schema | Setting      | Default | Description                                         | Highlight                                                                                 |
|------------|--------------|---------|-----------------------------------------------------|-------------------------------------------------------------------------------------------|
| Mail       | true / false | true    | Highlights mail settings which are not configured   | ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) Not Configured                   |
| Licensing  | true / false | true    | Highlights product evaluation licenses              | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Product evaluation license in use |
| Alarms     | true / false | true    | Highlights vCenter Server alarms which are disabled | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Alarm disabled                    |

#### Cluster
The **Cluster** schema is used to configure health checks for vSphere Clusters.

| Sub-Schema                  | Setting      | Default | Description                                                                                | Highlight                                                                                                                                   |
|-----------------------------|--------------|---------|--------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| HAEnabled                   | true / false | true    | Highlights vSphere Clusters which do not have vSphere HA enabled                           | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA disabled                                                                 |
| HAAdmissionControl          | true / false | true    | Highlights vSphere Clusters which do not have vSphere HA Admission Control enabled         | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA Admission Control disabled                                               |
| HostFailureResponse         | true / false | true    | Highlights vSphere Clusters which have vSphere HA Failure Response set to disabled         | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA Host Failure Response disabled                                           |
| HostMonitoring              | true / false | true    | Highlights vSphere Clusters which do not have vSphere HA Host Monitoring enabled           | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA Host Monitoring disabled                                                 |
| DatastoreOnPDL              | true / false | true    | Highlights vSphere Clusters which do not have Datastore on PDL enabled                     | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA Datastore on PDL disabled                                                |
| DatastoreOnAPD              | true / false | true    | Highlights vSphere Clusters which do not have Datastore on APD enabled                     | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere HA Datastore on APD disabled                                                |
| APDTimeOut                  | true / false | true    | Highlights vSphere Clusters which do not have APDTimeOut enabled                           | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) APDTimeOut disabled                                                                 |
| vmMonitoring                | true / false | true    | Highlights vSphere Clusters which do not have VM Monitoring enabled                        | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) VM Monitoring disabled                                                              |
| DRSEnabled                  | true / false | true    | Highlights vSphere Clusters which do not have vSphere DRS enabled                          | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere DRS disabled                                                                |
| DRSAutomationLevelFullyAuto | true / false | true    | Checks the vSphere DRS Automation Level is set to 'Fully Automated'                        | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere DRS Automation Level not set to 'Fully Automated'                           |
| PredictiveDRS               | true / false | false   | Highlights vSphere Clusters which do not have Predictive DRS enabled                       | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Predictive DRS disabled                                                             |
| DRSVMHostRules              | true / false | true    | Highlights DRS VMHost rules which are disabled                                             | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) DRS VMHost rule disabled                                                            |
| DRSRules                    | true / false | true    | Highlights DRS rules which are disabled                                                    | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) DRS rule disabled                                                                   |
| vSANEnabled                 | true / false | true    | Highlights vSphere Clusters which do not have Virtual SAN enabled                          | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Virtual SAN disabled                                                                |
| EVCEnabled                  | true / false | true    | Highlights vSphere Clusters which do not have Enhanced vMotion Compatibility (EVC) enabled | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) vSphere EVC disabled                                                                |
| VUMCompliance               | true / false | true    | Highlights vSphere Clusters which do not comply with VMware Update Manager baselines       | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Unknown<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Not Compliant |

#### VMHost
The **VMHost** schema is used to configure health checks for VMHosts.

| Sub-Schema      | Setting      | Default | Description                                                                                                              | Highlight                                                                                                                                                                                     |
|-----------------|--------------|---------|--------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ConnectionState | true / false | true    | Highlights VMHosts which are in maintenance mode or disconnected                                                         | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Maintenance<br>  ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Disconnected                                               |
| HyperThreading  | true / false | true    | Highlights VMHosts which have HyperThreading disabled                                                                    | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) HyperThreading disabled<br>                                                                                                           |
| ScratchLocation | true / false | true    | Highlights VMHosts which are configured with the default scratch location                                                | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Scratch location is /tmp/scratch                                                                                                      |
| IPv6            | true / false | true    | Highlights VMHosts which do not have IPv6 enabled                                                                        | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) IPv6 disabled                                                                                                                         |
| UpTimeDays      | true / false | true    | Highlights VMHosts with uptime days greater than 9 months                                                                | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) 9 - 12 months<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  >12 months                                                |
| Licensing       | true / false | true    | Highlights VMHosts which are using production evaluation licenses                                                        | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Product evaluation license in use                                                                                                     |
| SSH             | true / false | true    | Highlights if the SSH service is enabled                                                                                 | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) TSM / TSM-SSH service enabled                                                                                                         |
| ESXiShell       | true / false | true    | Highlights if the ESXi Shell service is enabled                                                                          | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) TSM / TSM-EsxiShell service enabled                                                                                                   |
| NTP             | true / false | true    | Highlights if the NTP service has stopped or is disabled on a VMHost                                                     | ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  NTP service stopped / disabled                                                                                                      |
| StorageAdapter  | true / false | true    | Highlights storage adapters which are not 'Online'                                                                       | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Storage adapter status is 'Unknown'<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Storage adapter status is 'Offline' |
| NetworkAdapter  | true / false | true    | Highlights physical network adapters which are not 'Connected'<br> Highlights physical network adapters which are 'Down' | ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Network adapter is 'Disconnected'<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Network adapter is 'Down'           |
| LockdownMode    | true / false | true    | Highlights VMHosts which do not have Lockdown mode enabled                                                               | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Lockdown Mode disabled<br>                                                                                                            |
| VUMCompliance   | true / false | true    | Highlights VMHosts which are not compliant with VMware Update Manager software packages                                  | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Unknown<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7)  Incompatible                                                    |

#### vSAN
The **vSAN** schema is used to configure health checks for vSAN.

| Sub-Schema          | Setting      | Default | Description                                                      | Highlight                                                                                                                                            |
|---------------------|--------------|---------|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| CapacityUtilization | true / false | true    | Highlights vSAN clusters with storage capacity utilization over 75% | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) 75 - 90% utilized<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) >90% utilized |

#### Datastore
The **Datastore** schema is used to configure health checks for Datastores.

| Sub-Schema          | Setting      | Default | Description                                                      | Highlight                                                                                                                                            |
|---------------------|--------------|---------|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| CapacityUtilization | true / false | true    | Highlights datastores with storage capacity utilization over 75% | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) 75 - 90% utilized<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) >90% utilized |

#### DSCluster
The **DSCluster** schema is used to configure health checks for Datastore Clusters.

| Sub-Schema                   | Setting      | Default | Description                                                                               | Highlight                                                                                                                                            |
|------------------------------|--------------|---------|-------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| CapacityUtilization          | true / false | true    | Highlights datastore clusters with storage capacity utilization over 75%                  | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) 75 - 90% utilized<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) >90% utilized |
| SDRSAutomationLevelFullyAuto | true / false | true    | Highlights if the Datastore Cluster SDRS Automation Level is not set to 'Fully Automated' | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Storage DRS Automation Level not set to 'Fully Automated'                                    |

#### VM
The **VM** schema is used to configure health checks for virtual machines.

| Sub-Schema           | Setting      | Default | Description                                                                                          | Highlight                                                                                                                                                                                                         |
|----------------------|--------------|---------|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| PowerState           | true / false | true    | Highlights VMs which are powered off                                                                 | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) VM is powered off                                                                                                                                         |
| ConnectionState      | true / false | true    | Highlights VMs which are orphaned or inaccessible                                                    | ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) VM is orphaned or inaccessible                                                                                                                           |
| CpuHotAdd            | true / false | true    | Highlights virtual machines which have CPU Hot Add enabled                                           | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) CPU Hot Add enabled                                                                                                                                       |
| CpuHotRemove         | true / false | true    | Highlights virtual machines which have CPU Hot Remove enabled                                        | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) CPU Hot Remove enabled                                                                                                                                    |
| MemoryHotAdd         | true / false | true    | Highlights VMs which have Memory Hot Add enabled                                                     | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Memory Hot Add enabled                                                                                                                                    |
| ChangeBlockTracking  | true / false | true    | Highlights VMs which do not have Change Block Tracking enabled                                       | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) Change Block Tracking disabled                                                                                                                            |
| SpbmPolicyCompliance | true / false | true    | Highlights VMs which do not comply with storage based policies                                       | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) VM storage based policy compliance is unknown<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) VM does not comply with storage based policies |
| VMToolsStatus        | true / false | true    | Highlights Virtual Machines which do not have VM Tools installed, are out of date or are not running | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) VM Tools not installed, out of date or not running                                                                                                        |
| VMSnapshots          | true / false | true    | Highlights Virtual Machines which have snapshots older than 7 days                                   | ![Warning](https://placehold.co/15x15/FFF4C7/FFF4C7) VM Snapshot age >= 7 days<br> ![Critical](https://placehold.co/15x15/FEDDD7/FEDDD7) VM Snapshot age >= 14 days                                         |

## :computer: Examples
<!-- ********** Add some examples. Use other AsBuiltReport modules as a guide. ********** -->

```powershell
# Generate a vSphere As Built Report for vCenter Server 'vcenter-01.corp.local' using specified credentials. Export report to HTML & DOCX formats. Use default report style. Append timestamp to report filename. Save reports to 'C:\Users\Tim\Documents'
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target 'vcenter-01.corp.local' -Username 'administrator@vsphere.local' -Password 'VMware1!' -Format Html,Word -OutputFolderPath 'C:\Users\Tim\Documents' -Timestamp

# Generate a vSphere As Built Report for vCenter Server 'vcenter-01.corp.local' using specified credentials and report configuration file. Export report to Text, HTML & DOCX formats. Use default report style. Save reports to 'C:\Users\Tim\Documents'. Display verbose messages to the console.
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target 'vcenter-01.corp.local' -Username 'administrator@vsphere.local' -Password 'VMware1!' -Format Text,Html,Word -OutputFolderPath 'C:\Users\Tim\Documents' -ReportConfigFilePath 'C:\Users\Tim\AsBuiltReport\AsBuiltReport.VMware.vSphere.json' -Verbose

# Generate a vSphere As Built Report for vCenter Server 'vcenter-01.corp.local' using stored credentials. Export report to HTML & Text formats. Use default report style. Highlight environment issues within the report. Save reports to 'C:\Users\Tim\Documents'.
PS C:\> $Creds = Get-Credential
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target 'vcenter-01.corp.local' -Credential $Creds -Format Html,Text -OutputFolderPath 'C:\Users\Tim\Documents' -EnableHealthCheck

# Generate a single vSphere As Built Report for vCenter Servers 'vcenter-01.corp.local' and 'vcenter-02.corp.local' using specified credentials. Report exports to WORD format by default. Apply custom style to the report. Reports are saved to the user profile folder by default.
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target 'vcenter-01.corp.local','vcenter-02.corp.local' -Username 'administrator@vsphere.local' -Password 'VMware1!' -StyleFilePath 'C:\Scripts\Styles\MyCustomStyle.ps1'

# Generate a vSphere As Built Report for vCenter Server 'vcenter-01.corp.local' using specified credentials. Export report to HTML & DOCX formats. Use default report style. Reports are saved to the user profile folder by default. Attach and send reports via e-mail.
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target 'vcenter-01.corp.local' -Username 'administrator@vsphere.local' -Password 'VMware1!' -Format Html,Word -OutputFolderPath 'C:\Users\Tim\Documents' -SendEmail
```
