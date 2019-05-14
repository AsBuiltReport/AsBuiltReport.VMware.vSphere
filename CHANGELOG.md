# VMware vSphere As Built Report Changelog

## [1.0.3] - 2019-05-14
### Changed
- Fixed DRS Cluster Group reporting when group does not contain any members
- Fixed DRS Cluster Group sorting
- Fixed VMHost reporting to exclude HCX Cloud Gateway host

## [1.0.1] - 2019-05-13
### Changed
- Improvements to code and report readability
- Fixed bug in vCenter Server licensing reporting
- Fixed Datastore reporting when an empty datastore cluster exists

## [1.0.0] - 2019-03-27
### Added
- Update Manager Server name added to vCenter Server detailed information

### Changed 
- Corrected VMHost count for Distributed Virtual Switches
- Corrected vCenter Server licensing for vCenter Server 5.5/6.0
- Fixed script termination where ESXi hosts do not have a datastore

## [0.4.0] - 2019-03-15
### Changed
- Refactored into PowerShell module
- Updated default VMware style sheet to include page orientation
- Changed VM Snapshot reporting to be per VM for InfoLevel 3
### Removed
- Removed NSX-V reporting

## [0.3.0] - 2019-02-01
### Added
- Added Cluster VM Overrides section

### Changed
- Improvements to code structure & readability
- Improvements to output formatting
- Improvements to vSphere HA/DRS Cluster reporting and health checks
- Improvements to VM reporting and health checks
- Corrected sorting of numerous table entries
- Corrected VMHost & VM uptime calculations
- Corrected display of 3rd party Multipath Policy plugins
- Corrected vSAN type & disk count
- Updated Get-Uptime & Get-License functions

## [0.2.2] - 2018-09-19
### Added
- Added new VM health checks for CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Improvements to VM reporting for Guest OS, CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Minor updates to section paragraph text

## 0.2.1
### What's New
- Added SDRS VM Overrides to Datastore Cluster section
- SCSI LUN section rewritten to improve script performance
- Fixed issues with current working directory paths
- Changes to InfoLevel settings and definitions
- Script formatting improvements to some sections to align with PowerShell best practice guidelines
- vCenter Server SSL Certificate section removed temporarily   

## 0.2.0
### What's New
- Requires PScribo module 0.7.24
- Added regions/endregions to all sections of script
- Formatting improvements
- Added Resource Pool summary information
- Added vSAN summary information
- Added vCenter Server mail settings health check
- Datastore Clusters now has it's own dedicated section
- Added DSCluster health checks
- Added VM Power State health check
- Renamed Storage section to Datastores
- Renamed Storage health checks section to Datastore
- Added support for NSX-V reporting