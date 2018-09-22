# VMware vSphere As Built Report Changelog

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