# :arrows_clockwise: VMware vSphere As Built Report Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [[2.0.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v2.0.0)] - 2026-03-05

### Added

- Modular architecture: each report section is now a dedicated private function (`Get-AbrVSphere*`)
- Internationalization (i18n) support via `Language/` `.psd1` files (`en-US`, `en-GB`, `es-ES`, `fr-FR`, `de-DE`)
- Pester test suite (`AsBuiltReport.VMware.vSphere.Tests.ps1`, `LocalizationData.Tests.ps1`, `Invoke-Tests.ps1`)
- GitHub Actions Pester workflow (`.github/workflows/Pester.yml`)

### Changed

- Complete module rewrite for improved maintainability and extensibility
- Module source now uses nested folder structure (`AsBuiltReport.VMware.vSphere/`)
- Requires `AsBuiltReport.Core` >= 1.6.2
- `CompatiblePSEditions` now explicitly declares `Desktop` and `Core` support

## [[1.3.6.1](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.6.1)] - 2025-08-24

### Fixed

- Fix issue with gathering ESXi Host Image Profile information

## [[1.3.6](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.6)] - 2025-08-24

### Fixed

- Fix divide by zero error (@rebelinux) ([#129](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/129))
- Fix PowerCLI module dependency ([#134](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/134))
- Update colour placeholders in `README.md`

### Changed

- Improve vSAN Capacity reporting and healthchecks
- Add `VCF.PowerCLI` to `ExternalModuleDependencies` in the module manifest

### Removed

- Remove `Get-RequiredModule` function to check for PowerCLI versions
- Remove VMware document style script

## [[1.3.5](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.5)] - 2025-02-27

### Added

- Add Free resource capacity reporting to VMhost hardware section

### Changed

- Update VMware PowerCLI requirements to version 13.3
- Improve error reporting for vSAN section
- Improve data size reporting. Data sizes are now displayed in more appropriately sized data units
- Change list tables to 40/60 column widths
- Change datastore capacity reporting to include percentage used & free values
- Update GitHub release workflow to add post to Bluesky social platform

### Fixed

- Fix issue with license reporting ([#128](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/128))
- Fix issue with vCenter user privileges not handling groups (@nathcoad) ([#102](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/102))
- Fix time & date outputs showing incorrect date format
- Fix VMware Update Manager reporting with PowerShell 7

## [[1.3.4](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.3.4)] - 2024-02-28

### Added

- Add vSAN ESA support ([#113](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/113))

### Changed

- Update VMware PowerCLI requirements to version 13.2 ([#107](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/107))
- Improve bug and feature request templates (@rebelinux)
- Improve TOC structure
- Update VMware style script for improved TOC structure
- Update GitHub action workflows

### Fixed

- Update VMHost PCI Devices reporting to fix issues with ESXi 8.x hosts (@orb71) ([#105](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/105)) & ([#111](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/111))
- Add Try/Catch to PCI Drivers and Firmware section to provide a workaround for ESXi 8.x hosts ([#116](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/116))
- Update vCenter Server alarms reporting ([#106](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/106))
- Fix issue with Platform Services Controller reporting ([#103](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/103))
- Fix NSX-T virtual switch network labels ([#118](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/118))

### Removed

- Remove reporting of vCenter Server OS type

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
- Support for VMware Cloud environments (VCF, VMC, AVS, GVE) ([#87](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/87))
- NSX TCP/IP stacks for VMkernel Adapter reporting
- Include release and issue links in `CHANGELOG.md`

### Fixed

- Incorrect section reporting with certain InfoLevels
- Datastore table now sorts by Datastore Name
- vSAN advanced detailed reporting
- Distributed vSwitch advanced detailed reporting
- Display issues with highlights in `README.md`

## [[1.2.1](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.2.1)] - 2020-09-29

### Changed

- Set fixed table column widths for improved formatting
- Correct section header colours in VMware default style

### Fixed

- Fix sort order of VMHost PCI Devices
- Fix VMHost reporting for InfoLevels 1 & 2
- Fix DSCluster reporting for InfoLevels 1 & 2

## [[1.2.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.2.0)] - 2020-08-31

### Added

- vCenter Server advanced system settings
- vCenter Server alarm health check
- Basic VM storage policy reporting
- Headers, footers & table captions/numbering

### Changed

- Improve table formatting
- Enhance vCenter alarm reporting
- Change Tag Assignment section to separate the category and tag to their own table columns
- Change Tag Assignment section to sort on Entity
- Rename InfoLevel `Informative` to `Adv Summary`
- Move script functions from main script to private functions

### Fixed

- Section error with vSAN InfoLevel 4 or above
- Fix text color for highlighted cells in default VMware style
- Fix reporting of stateless boot devices ([#76](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/76))
- Fix issue where script was failing trying to parse vSphere Tag data ([#77](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/77))
- Fix issue with reporting on PCI-E device drivers by adding additional filter ([#75](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/75))

## [[1.1.3](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.1.3)] - 2020-02-04

### Added

- Add vCenter Server certificate information ([#31](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/31))
- Add VM summary information
- Add VM disk and guest volume information
- Add Virtual Switch to VMkernel adapter information
- Add Virtual Switch & Port Group Traffic Shaping information
- Add vSAN Disk Groups, iSCSI Targets & LUN reporting
- Add number of paths to SCSI LUN information
- Add VMHost CPU & Memory totals to Informative level
- Add VM Connection State information & health check
- Add number of targets, devices & paths to storage adapters
- Add VMHost storage and network adapter health checks
- Add License expiration information
- Add additional information to VMkernel adapters
- Add NTP, SSH & ESXi Shell health checks

### Changed

- Improve report formatting
- Improve VMHost storage adapter reporting ([#32](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/32))
- Improve VMHost network adapter CDP reporting
- Improve VM SCSI controller reporting
- Update VMHost CPU & Memory totals/usage in Detailed level
- Update report JSON structure & default settings. A new report JSON must be generated for this release, use `New-AsBuiltReportConfig -Report VMware.vSphere -Path <path> -Overwrite`
- Update README with minimum required privileges to generate a VMware vSphere As Built Report. Full administrator privileges should no longer be required

### Fixed

- Resolve issue with VMHost PCI device reporting ([#33](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/33))
- Resolve issue with reporting of ESXi boot device size ([#65](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/65))
- Resolve issue with vSphere licensing ([#68](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/68) & [Fix #69](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/69))
- Resolve vSwitch reporting issue with physical adapters ([#27](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/27))
- Resolve issue with VMHost uptime health check reporting

### Removed

- Remove support for ESX/ESXi hosts prior to vSphere 5.0 ([#67](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues/67))
- Remove VMHost CPU & Memory usage from Informative level

## [[1.0.7](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.7)] - 2019-06-21

### Changed

- Update module manifest for icon and release notes

### Fixed

- Fix font in default VMware style

### Removed

- Remove Services health check

## [[1.0.6](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.6)] - 2019-05-16

### Changed

- Improve code and report readability
- Update VMware default style to more closely align with Clarity

### Fixed

- Fix code errors which prevented a report from being generated
- Fix vCenter Server licensing reporting
- Fix Datastore reporting when an empty datastore cluster exists
- Fix DRS Cluster Group reporting when group does not contain any members
- Fix DRS Cluster Group sorting
- Fix VMHost reporting to exclude HCX Cloud Gateway host

## [[1.0.0](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/releases/tag/v1.0.0)] - 2019-03-27

### Added

- Add Update Manager Server name to vCenter Server detailed information

### Fixed

- Fix VMHost count for Distributed Virtual Switches
- Fix vCenter Server licensing for vCenter Server 5.5/6.0
- Fix script termination where ESXi hosts do not have a datastore

## [0.4.0] - 2019-03-15

### Changed

- Refactor into PowerShell module
- Update default VMware style sheet to include page orientation
- Change VM Snapshot reporting to be per VM for InfoLevel 3

### Removed

- Remove NSX-V reporting

## [0.3.0] - 2019-02-01

### Added

- Add Cluster VM Overrides section

### Changed

- Improve code structure & readability
- Improve output formatting
- Improve vSphere HA/DRS Cluster reporting and health checks
- Improve VM reporting and health checks
- Fix sorting of numerous table entries
- Fix VMHost & VM uptime calculations
- Fix display of 3rd party Multipath Policy plugins
- Fix vSAN type & disk count
- Update `Get-Uptime` & `Get-License` functions

## [0.2.2] - 2018-09-19

### Added

- Add new VM health checks for CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Improve VM reporting for Guest OS, CPU Hot Add/Remove, Memory Hot Add & Change Block Tracking
- Minor updates to section paragraph text

## [0.2.1]

### Added

- Add SDRS VM Overrides to Datastore Cluster section

### Changed

- Rewrite SCSI LUN section to improve script performance
- Fix issues with current working directory paths
- Change InfoLevel settings and definitions
- Improve script formatting to align with PowerShell best practice guidelines
- Temporarily remove vCenter Server SSL Certificate section

## [0.2.0]

### Added

- Add regions/endregions to all sections of script
- Add Resource Pool summary information
- Add vSAN summary information
- Add vCenter Server mail settings health check
- Add DSCluster health checks
- Add VM Power State health check
- Add support for NSX-V reporting

### Changed

- Update about_Requires to PScribo module 0.7.24
- Improve formatting
- Move Datastore Clusters to its own dedicated section
- Rename Storage section to Datastores
- Rename Storage health checks section to Datastore
