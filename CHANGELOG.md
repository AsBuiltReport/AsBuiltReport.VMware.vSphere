# :arrows_clockwise: VMware vSphere As Built Report Changelog

## [[1.3.3.1](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.3.1)] - 2022-04-21

### Added
- Add VMHost IPMI / BMC configuration information

### Fixed
- Fix GitHub Action release workflow

## [[1.3.2](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.2)] - 2022-03-24

### Added
- Automated tweet release workflow

### Fixed
- Fix colour placeholders in `README.md`

## [[1.3.1](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.1)] - 2021-09-03

### Added
- VMHost network adapter LLDP reporting

## [[1.3.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.0)] - 2021-08-29
### Added
- PowerShell 7 compatibility
- PSScriptAnalyzer & PublishPSModule GitHub Action workflows
- Advanced detailed reporting for VI roles
- Advanced detailed reporting for vSAN disks
- Support for VMware Cloud environments (VCF, VMC, AVS, GVE) ([Fix #87](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/87))
- NSX TCP/IP stacks for VMkernel Adpater reporting
- Include release and issue links in `CHANGELOG.md`
### Fixed
- Incorrect section reporting with certain InfoLevels
- Datastore table now sorts by Datastore Name
- vSAN advanced detailed reporting
- Distributed vSwitch advanced detailed reporting
- Display issues with highlights in `README.md`

## [[1.2.1](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.2.1)] - 2020-09-29
### Fixed
- Fixed sort order of VMHost PCI Devices
- Fixed VMHost reporting for InfoLevels 1 & 2
- Fixed DSCluster reporting for InfoLevels 1 & 2

### Changed
- Set fixed table column widths for improved formatting
- Corrected section header colours in VMware default style

## [[1.2.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.2.0)] - 2020-08-31
### Added
- vCenter Server advanced system settings
- vCenter Server alarm health check
- Basic VM storage policy reporting
- Headers, footers & table captions/numbering

### Changed
- Improved table formatting
- Enhanced vCenter alarm reporting
- Changed Tag Assignment section to separate the category and tag to their own table columns
- Changed Tag Assignment section to sort on Entity
- Renamed InfoLevel `Informative` to `Adv Summary`
- Moved script functions from main script to private functions

### Fixed
- Section error with vSAN InfoLevel 4 or above
- Fixed text color for highlighted cells in default VMware style
- Fixed reporting of stateless boot devices ([Fix #76](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/76))
- Fixed issue where script was failing trying to parse vSphere Tag data ([Fix #77](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/77))
- Fixed issue with reporting on PCI-E device drivers by adding additional filter ([Fix #75](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/75))

## [[1.1.3](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.1.3)] - 2020-02-04
### Added
- Added vCenter Server certificate information ([Fix #31](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/31))
- Added VM summary information
- Added VM disk and guest volume information
- Added Virtual Switch to VMkernel adapter information
- Added Virtual Switch & Port Group Traffic Shaping information
- Added vSAN Disk Groups, iSCSI Targets & LUN reporting
- Added number of paths to SCSI LUN information
- Added VMHost CPU & Memory totals to Informative level
- Added VM Connection State information & health check
- Added number of targets, devices & paths to storage adapters
- Added VMHost storage and network adapter health checks
- Added License expiration information
- Added additional information to VMkernel adapters
- Added NTP, SSH & ESXi Shell health checks

### Changed
- Improved report formatting
- Improved VMHost storage adapter reporting ([Fix #32](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/32))
- Improved VMHost network adapter CDP reporting
- Improved VM SCSI controller reporting
- Updated VMHost CPU & Memory totals/usage in Detailed level
- Updated report JSON structure & default settings. A new report JSON must be generated for this release, use `New-AsBuiltReportConfig -Report VMware.vSphere -Path <path> -Overwrite`.
- Updated README with minimum required privileges to generate a VMware vSphere As Built Report. Full administrator privileges should no longer be required.

### Fixed
- Resolved issue with VMHost PCI device reporting ([Fix #33](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/33))
- Resolved issue with reporting of ESXi boot device size ([Fix #65](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/65))
- Resolved issue with vSphere licensing ([Fix #68](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/68) & [Fix #69](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/69))
- Resolved vSwitch reporting issue with physical adpaters ([Fix #27](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/27))
- Resolved issue with VMHost uptime health check reporting

### Removed
- Removed support for ESX/ESXi hosts prior to vSphere 5.0 ([Fix #67](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/67))
- Removed VMHost CPU & Memory usage from Informative level

## [[1.0.7](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.7)] - 2019-06-21
### Changed
- Fixed font in default VMware style
- Updated module manifest for icon and release notes

### Removed
- Removed Services health check

## [[1.0.6](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.6)] - 2019-05-16
### Changed
- Fixed code errors which prevented a report from being generated
- Improved code and report readability
- Fixed vCenter Server licensing reporting
- Fixed Datastore reporting when an empty datastore cluster exists
- Fixed DRS Cluster Group reporting when group does not contain any members
- Fixed DRS Cluster Group sorting
- Fixed VMHost reporting to exclude HCX Cloud Gateway host
- Updated VMware default style to more closely align with Clarity

## [[1.0.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.0)] - 2019-03-27
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

## [0.2.1]
### Added
- Added SDRS VM Overrides to Datastore Cluster section

### Changed
- SCSI LUN section rewritten to improve script performance
- Fixed issues with current working directory paths
- Changed InfoLevel settings and definitions
- Script formatting improvements to some sections to align with PowerShell best practice guidelines
- vCenter Server SSL Certificate section removed temporarily

## [0.2.0]
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
