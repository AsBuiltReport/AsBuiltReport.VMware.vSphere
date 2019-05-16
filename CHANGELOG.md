# VMware vSphere As Built Report Changelog

## [1.0.6] - 2019-05-16
### Changed
- Fixed code errors which prevented a report from being generated
- Improved code and report readability
- Fixed vCenter Server licensing reporting
- Fixed Datastore reporting when an empty datastore cluster exists
- Fixed DRS Cluster Group reporting when group does not contain any members
- Fixed DRS Cluster Group sorting
- Fixed VMHost reporting to exclude HCX Cloud Gateway host
- Updated VMware default style to more closely align with Clarity

## [1.0.0] - 2019-03-27
### Added
- Added Update Manager Server name to vCenter Server detailed information

### Changed 
- Fixed VMHost count for Distributed Virtual Switches
- Fixed vCenter Server licensing for vCenter Server 5.5/6.0
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
- Improved code structure & readability
- Improved output formatting
- Improved vSphere HA/DRS Cluster reporting and health checks
- Improved VM reporting and health checks
- Fixed sorting of numerous table entries
- Fixed VMHost & VM uptime calculations
- Fixed display of 3rd party Multipath Policy plugins
- Fixed vSAN type & disk count
- Updated Get-Uptime & Get-License functions

## [0.2.2] - 2018-09-19
### Added
- Added new VM health checks for CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Improved VM reporting for Guest OS, CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Minor updates to section paragraph text

## 0.2.1
### Added
- Added SDRS VM Overrides to Datastore Cluster section

### Changed
- SCSI LUN section rewritten to improve script performance
- Fixed issues with current working directory paths
- Changed InfoLevel settings and definitions
- Script formatting improvements to some sections to align with PowerShell best practice guidelines
- vCenter Server SSL Certificate section removed temporarily   

## 0.2.0
### Added
- Added regions/endregions to all sections of script
- Added Resource Pool summary information
- Added vSAN summary information
- Added vCenter Server mail settings health check
- Added DSCluster health checks
- Added VM Power State health check
- Added support for NSX-V reporting

### Changed
- Updated about_Requires to PScribo module 0.7.24
- Formatting improvements
- Datastore Clusters now has it's own dedicated section
- Renamed Storage section to Datastores
- Renamed Storage health checks section to Datastore
