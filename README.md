# VMware vSphere As Built Report

# Getting Started
Below are the instructions on how to install, configure and generate a VMware vSphere As Built report.

## Pre-requisites
The following PowerShell modules are required for generating a VMware vSphere As Built report.

Each of these modules can be easily downloaded and installed via the PowerShell Gallery 

- [PScribo Module](https://www.powershellgallery.com/packages/PScribo/)
- [VMware PowerCLI Module](https://www.powershellgallery.com/packages/VMware.PowerCLI/)

### Module Installation

Open a Windows PowerShell terminal window and install each of the required modules as follows;

```powershell
PS C:\> install-module PScribo

PS C:\> install-module VMware.PowerCLI
```

## Configuration
The vSphere As Built report utilises a JSON file (vSphere.json) to allow configuration of report information, features and section detail. All report settings are configured via the JSON file.

**Modification of the PowerShell script (vSphere.ps1) is not required or recommended.**

The following provides information of how to configure each schema within the report's JSON file.

### Report
The **Report** sub-schema provides configuration of the vSphere report information

| Schema | Sub-Schema | Description |
| ------ | ---------- | ----------- |
| Report | Name | The name of the As Built report
| Report | Version | The document version
| Report | Status | The document release status

### Options
The **Options** sub-schema allows certain options within the report to be toggled on or off

| Schema | Sub-Schema | Setting | Description |
| ------ | ---------- | ------- | ----------- |
| Options | ShowLicenses | true / false | Toggle to mask/unmask  vSphere license keys within the As Built report.<br><br> **Masked License Key**<br>\*\*\*\*\*-\*\*\*\*\*-\*\*\*\*\*-56YDM-AS12K<br><br> **Unmasked License Key**<br>AKLU4-PFG8M-W2D8J-56YDM-AS12K

### InfoLevel
The **InfoLevel** sub-schema allows configuration of each section of the report at a granular level. The following sections can be set

| Schema | Sub-Schema | Default Setting |
| ------ | ---------- | --------------- |
| InfoLevel | vCenter | 3
| InfoLevel | ResourcePool | 3
| InfoLevel | Cluster | 3
| InfoLevel | VMhost | 3
| InfoLevel | Network | 3
| InfoLevel | vSAN | 3
| InfoLevel | Datastore | 3
| InfoLevel | DSCluster | 3
| InfoLevel | VM | 3
| InfoLevel | VUM | 3
| InfoLevel | NSX\* | 0
| InfoLevel | SRM\*\* | 0

\* *Requires PowerShell module [PowerNSX](https://github.com/vmware/powernsx) to be installed*

\*\* *Placeholder for future release* 

There are 6 levels (0-5) of detail granularity for each section as follows;

| Setting | InfoLevel | Description |
| ------- | ---- | ----------- |
| 0 | Disabled | does not collect or display any information
| 1 | Summary | provides summarised information for a collection of objects
| 2 | Informative | provides condensed, detailed information for a collection of objects
| 3 | Detailed | provides detailed information for individual objects
| 4 | Adv Detailed | provides detailed information for individual objects, as well as information for associated objects (Hosts, Clusters, Datastores, VMs etc)
| 5 | Comprehensive | provides comprehensive information for individual objects, such as advanced configuration settings

### Healthcheck
The **Healthcheck** sub-schema is used to toggle health checks on or off.

#### vCenter
The **vCenter** sub-schema is used to configure health checks for vCenter Server.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| vCenter | Mail | true / false | Highlights mail settings which are not configured | ![Critical](https://placehold.it/15/FFB38F/000000?text=+) Not Configured 
| vCenter | Licensing | true / false | Highlights product evaluation licenses | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Product evaluation license in use

#### Cluster
The **Cluster** sub-schema is used to configure health checks for vSphere Clusters.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| Cluster | HAEnabled | true / false | Highlights vSphere Clusters which do not have vSphere HA enabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) vSphere HA disabled
| Cluster | HAAdmissionControl | true / false | Highlights vSphere Clusters which do not have vSphere HA Admission Control enabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) vSphere HA Admission Control disabled
| Cluster | DRSEnabled | true / false | Highlights vSphere Clusters which do not have vSphere DRS enabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) vSphere DRS disabled
| Cluster | DRSAutomationLevel | true / false | Enables/Disables checking the vSphere DRS Automation Level
| Cluster | DRSAutomationLevelSetting | Off / Manual / PartiallyAutomated / FullyAutomated | Highlights vSphere Clusters which do not match the specified DRS Automation Level | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Does not match specified DRS Automation Level
| Cluster | DRSVMHostRules | true / false | Highlights DRS VMHost rules which are disabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) DRS VMHost rule disabled
| Cluster | DRSRules | true / false | Highlights DRS rules which are disabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) DRS rule disabled
| Cluster | EVCEnabled | true / false | Highlights vSphere Clusters which do not have Enhanced vMotion Compatibility (EVC) enabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) vSphere EVC disabled
| Cluster | VUMCompliance | true / false | Highlights vSphere Clusters which do not comply with VMware Update Manager baselines | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Unknown<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+)  Not Compliant

#### VMHost
The **VMHost** sub-schema is used to configure health checks for VMHosts.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| VMhost | ConnectionState | true / false | Highlights VMHosts connection state | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Maintenance<br>  ![Critical](https://placehold.it/15/FFB38F/000000?text=+)  Disconnected
| VMhost | ScratchLocation | true / false | Highlights VMHosts which are configured with the default scratch location | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Scratch location is /tmp/scratch
| VMhost | IPv6Enabled | true / false | Highlights VMHosts which do not have IPv6 enabled | ![Warning](https://placehold.it/15/FFE860/000000?text=+) IPv6 disabled
| VMhost | UpTimeDays | true / false | Highlights VMHosts with uptime days greater than 9 months | ![Warning](https://placehold.it/15/FFE860/000000?text=+) 9 - 12 months<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+)  >12 months
| VMhost | Licensing | true / false | Highlights VMHosts which are using production evaluation licenses | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Product evaluation license in use
| VMhost | Services | true / false | Highlights status of important VMHost services | ![Warning](https://placehold.it/15/FFE860/000000?text=+) TSM / TSM-SSH service enabled
| VMhost | TimeConfig | true / false | Highlights if the NTP service has stopped on a VMHost | ![Critical](https://placehold.it/15/FFB38F/000000?text=+)  NTP service stopped
| VMhost | VUMCompliance | true / false | Highlights VMHosts which are not compliant with VMware Update Manager software packages | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Unknown<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+)  Incompatible

#### vSAN
The **vSAN** sub-schema is used to configure health checks for vSAN.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| vSAN | CapacityUtilization | true / false | Highlights vSAN datastores with storage capacity utilization over 75% | ![Warning](https://placehold.it/15/FFE860/000000?text=+) 75 - 90% utilized<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+) >90% utilized

#### Datastore
The **Datastore** sub-schema is used to configure health checks for Datastores.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| Datastore | CapacityUtilization | true / false | Highlights datastores with storage capacity utilization over 75% | ![Warning](https://placehold.it/15/FFE860/000000?text=+) 75 - 90% utilized<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+) >90% utilized

#### DSCluster
The **DSCluster** sub-schema is used to configure health checks for Datastore Clusters.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| DSCluster | SDRSAutomationLevel | true / false | Enables/Disables checking the Datastore Cluster SDRS Automation Level
| DSCluster | SDRSAutomationLevelSetting | Off / Manual / PartiallyAutomated / FullyAutomated | Highlights Datastore Clusters which do not match the specified SDRS Automation Level | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Does not match specified SDRS Automation Level
| DSCluster | CapacityUtilization | true / false | Highlights datastore clusters with storage capacity utilization over 75% | ![Warning](https://placehold.it/15/FFE860/000000?text=+) 75 - 90% utilized<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+) >90% utilized

#### VM
The **VM** sub-schema is used to configure health checks for virtual machines.

| Schema | Sub-Schema | Setting | Description | Highlight |
| ------ | ---------- | ------- | ----------- | --------- |
| VM | PowerState | true / false | Enables/Disables checking the VM power state
| VM | PowerStateSetting | PoweredOn / PoweredOff | Highlights virtual machines which do not match the specified VM power state | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Highlights VMs which do not match the specified VM power state
| VM | CpuHotAddEnabled | true / false | Enables/Disables checking the VM options for CPU Hot Add | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Highlights VMs which have CPU Hot Add enabled
| VM | CpuHotRemoveEnabled | true / false | Enables/Disables checking the VM options for CPU Hot Remove | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Highlights VMs which have CPU Hot Remove enabled
| VM | MemoryHotAddEnabled | true / false | Enables/Disables checking the VM options for Memory Hot Add | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Highlights VMs which have Memory Hot Add enabled
| VM | ChangeBlockTrackingEnabled | true / false | Enables/Disables checking if Change Block Tracking is enabled on the VM | ![Warning](https://placehold.it/15/FFE860/000000?text=+) Highlights VMs which do not have Change Block Tracking enabled
| VM | VMTools | true / false | Highlights Virtual Machines which do not have VM Tools installed or are out of date | ![Warning](https://placehold.it/15/FFE860/000000?text=+) VM Tools not installed or out of date
| VM | VMSnapshots | true / false | Highlights Virtual Machines which have snapshots older than 7 days | ![Warning](https://placehold.it/15/FFE860/000000?text=+) VM Snapshot age >= 7 days<br> ![Critical](https://placehold.it/15/FFB38F/000000?text=+) VM Snapshot age >= 14 days

## Samples
### Sample Report 1 - Default Style
Sample vSphere As Built report with health checks, using default report style.

![Sample vSphere Report 1](Src/Public/Reports/vSphere/Samples/Sample_vSphere_Report_1.png "Sample vSphere Report 1")


### Sample Report 2 - Custom Style
Sample vSphere As Built report with health checks, using custom report style.

![Sample vSphere Report 2](Src/Public/Reports/vSphere/Samples/Sample_vSphere_Report_2.png "Sample vSphere Report 2")

# Release Notes
## [0.2.2] - 2018-09-19
### Added
- Added new VM health checks for CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking

### Changed
- Improvements to VM reporting for Guest OS, CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Minor updates to section paragraph text

## [0.2.1] - 2018-08-21
### Added
- Added SDRS VM Overrides to Datastore Cluster section

### Changed
- SCSI LUN section rewritten to improve script performance
- Fixed issues with current working directory paths
- Changes to InfoLevel settings and definitions
- Script formatting improvements to some sections to align with PowerShell best practice guidelines

### Removed
- vCenter Server SSL Certificate section removed temporarily   

## [0.2.0] - 2018-08-13
### Added
- Added regions/endregions to all sections of script
- Added Resource Pool summary information
- Added vSAN summary information
- Added vCenter Server mail settings health check
- Added DSCluster health checks
- Added VM Power State health check
- Added support for NSX-V reporting

### Changed
- Requires PScribo module 0.7.24
- Formatting improvements
- Datastore Clusters now has it's own dedicated section
- Renamed Storage section to Datastores
- Renamed Storage health checks section to Datastore

# Known Issues
- Verbose script errors when connecting to vCenter with a Read-Only user account

- In HTML documents, word-wrap of table cell contents is not working, causing the following issues;
  - Cell contents may overflow table columns
  - Tables may overflow page margin
  - [PScribo Issue #83](https://github.com/iainbrighton/PScribo/issues/83)

- In Word documents, some tables are not sized proportionately. To prevent cell overflow issues in HTML documents, most tables are auto-sized, this causes some tables to be out of proportion.
    
    - [PScribo Issue #83](https://github.com/iainbrighton/PScribo/issues/83)
