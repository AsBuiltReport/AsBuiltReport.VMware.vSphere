# AsBuiltReport.VMware.vSphere – Developer Guide

## Module Architecture

This module follows the nested-folder pattern established by `AsBuiltReport.Microsoft.Azure`.

```
AsBuiltReport.VMware.vSphere/        ← repo root
├── AsBuiltReport.VMware.vSphere/    ← module source (published to PSGallery)
│   ├── AsBuiltReport.VMware.vSphere.psd1
│   ├── AsBuiltReport.VMware.vSphere.psm1
│   ├── AsBuiltReport.VMware.vSphere.json  ← report configuration schema
│   ├── Language/
│   │   ├── en-US/VMwarevSphere.psd1       ← primary translation template
│   │   ├── en-GB/VMwarevSphere.psd1       ← British English
│   │   ├── es-ES/VMwarevSphere.psd1       ← Spanish
│   │   ├── fr-FR/VMwarevSphere.psd1       ← French
│   │   └── de-DE/VMwarevSphere.psd1       ← German
│   └── Src/
│       ├── Public/
│       │   └── Invoke-AsBuiltReport.VMware.vSphere.ps1  ← entry point
│       └── Private/
│           ├── Convert-DataSize.ps1        ← helper functions
│           ├── Get-ESXiBootDevice.ps1
│           ├── Get-InstallDate.ps1
│           ├── Get-License.ps1
│           ├── Get-PciDeviceDetail.ps1
│           ├── Get-ScsiDeviceDetail.ps1
│           ├── Get-Uptime.ps1
│           ├── Get-vCenterStats.ps1
│           ├── Get-VMHostNetworkAdapterDP.ps1
│           ├── Get-AbrVSpherevCenter.ps1   ← section functions
│           ├── Get-AbrVSphereCluster.ps1
│           ├── Get-AbrVSphereClusterHA.ps1
│           ├── Get-AbrVSphereClusterProactiveHA.ps1
│           ├── Get-AbrVSphereClusterDRS.ps1
│           ├── Get-AbrVSphereResourcePool.ps1
│           ├── Get-AbrVSphereVMHost.ps1
│           ├── Get-AbrVSphereVMHostHardware.ps1
│           ├── Get-AbrVSphereVMHostSystem.ps1
│           ├── Get-AbrVSphereVMHostStorage.ps1
│           ├── Get-AbrVSphereVMHostNetwork.ps1
│           ├── Get-AbrVSphereVMHostSecurity.ps1
│           ├── Get-AbrVSphereNetwork.ps1
│           ├── Get-AbrVSpherevSAN.ps1
│           ├── Get-AbrVSphereDatastore.ps1
│           ├── Get-AbrVSphereDSCluster.ps1
│           ├── Get-AbrVSphereVM.ps1
│           └── Get-AbrVSphereVUM.ps1
├── Tests/
│   ├── AsBuiltReport.VMware.vSphere.Tests.ps1
│   ├── LocalizationData.Tests.ps1
│   └── Invoke-Tests.ps1
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Top-level section function | `Get-AbrVSphere{Component}` | `Get-AbrVSpherevCenter` |
| Sub-section function | `Get-AbrVSphere{Parent}{Sub}` | `Get-AbrVSphereClusterHA` |
| Language key (section) | `GetAbrVSphere{Component}` | `GetAbrVSpherevCenter` |
| Language key (sub-section) | `GetAbrVSphere{Parent}{Sub}` | `GetAbrVSphereClusterHA` |

The language key is derived from the function name by removing the hyphen: `Get-AbrVSpherevCenter` → `GetAbrVSpherevCenter`.

## Function Structure

Every section function follows this begin/process/end pattern:

```powershell
function Get-AbrVSphere{Name} {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve VMware vSphere {Name} information.
    .NOTES
        Version:        2.0.0
        Author:         Tim Carman
    #>
    [CmdletBinding()]
    param ()

    begin {
        $LocalizedData = $reportTranslate.GetAbrVSphere{Name}
        Write-PScriboMessage ($LocalizedData.InfoLevel -f $InfoLevel.{Section})
    }

    process {
        Try {
            if ($InfoLevel.{Section} -ge 1) {
                Write-PScriboMessage $LocalizedData.Collecting
                Section -Style Heading2 $LocalizedData.SectionHeading {
                    Paragraph ($LocalizedData.ParagraphSummary -f $vCenterServerName)
                    # ... section content
                }
            }
        } Catch {
            Write-PScriboMessage -IsWarning $($_.Exception.Message)
        }
    }

    end {}
}
```

**Key rules:**
- Functions use variables from parent scope (not parameters) — `$vCenter`, `$InfoLevel`, `$Report`, `$Healthcheck`, `$TextInfo`, `$vCenterServerName`, `$reportTranslate`, etc.
- `$LocalizedData` is always set in `begin {}` from `$reportTranslate.{KeyName}`
- All PSCustomObject property names (column headers), section headings, table names, and user-visible strings use `$LocalizedData` keys
- Table names (`Name =`) in `$TableParams` also use `$LocalizedData` keys for localization

## Language / i18n Structure

### Loading mechanism
The `AsBuiltReport.Core` module loads `Language/{culture}/VMwarevSphere.psd1` automatically. The `$reportTranslate` variable is set globally by `New-AsBuiltReport.ps1` before the Invoke- function runs.

The file name `VMwarevSphere` is derived from the report name `VMware.vSphere` by removing the dot.

### File format
```powershell
# culture = 'en-US'
@{
    GetAbrVSpherevCenter = ConvertFrom-StringData @'
        InfoLevel  = Tab:2 vCenter InfoLevel set to {0}.
        Collecting = Collecting vCenter Server information.
        SectionHeading = vCenter Server
        ParagraphSummary = The following sections detail the configuration of vCenter Server {0}.
        # ... more keys
    '@

    GetAbrVSphereCluster = ConvertFrom-StringData @'
        # ...
    '@
}
```

### Adding a new locale
1. Copy `Language/en-US/VMwarevSphere.psd1` to `Language/{culture}/VMwarevSphere.psd1`
2. Update the culture comment at the top
3. Translate string values (keep keys identical)
4. Run `Tests/Invoke-Tests.ps1` — `LocalizationData.Tests.ps1` will verify key consistency

## Development Commands

### Lint (PSScriptAnalyzer)
```powershell
# From repo root
Invoke-ScriptAnalyzer -Path .\AsBuiltReport.VMware.vSphere\Src -Recurse -Severity Warning, Error
```

### Run tests
```powershell
.\Tests\Invoke-Tests.ps1

# With code coverage
.\Tests\Invoke-Tests.ps1 -CodeCoverage

# With JUnit output (for CI)
.\Tests\Invoke-Tests.ps1 -OutputFormat JUnitXml
```

### Import module (smoke test, no vCenter required)
```powershell
Import-Module .\AsBuiltReport.VMware.vSphere\AsBuiltReport.VMware.vSphere.psd1 -Force
Get-Command -Module AsBuiltReport.VMware.vSphere
```

### Reload module during development
```powershell
Remove-Module AsBuiltReport.VMware.vSphere -ErrorAction SilentlyContinue
Import-Module .\AsBuiltReport.VMware.vSphere\AsBuiltReport.VMware.vSphere.psd1 -Force
```

## How to Add a New Section Function

1. **Create the function file** in `Src/Private/Get-AbrVSphere{Name}.ps1`
   - Follow the begin/process/end template above
   - Use `$InfoLevel.{Section}` for the info level check

2. **Add the language key** to `Language/en-US/VMwarevSphere.psd1`:
   ```powershell
   GetAbrVSphere{Name} = ConvertFrom-StringData @'
       InfoLevel      = {Section} InfoLevel set to {0}.
       Collecting     = Collecting {Section} information.
       SectionHeading = {Section Heading}
       ParagraphSummary = The following sections detail...
   '@
   ```

3. **Copy the key** to all other locale files (en-GB, etc.) with identical keys (translate values only)

4. **Call the function** from `Invoke-AsBuiltReport.VMware.vSphere.ps1` inside the `Section -Style Heading1` block

5. **Run tests** to verify:
   - `LocalizationData.Tests.ps1` checks all locale files have matching keys
   - `AsBuiltReport.VMware.vSphere.Tests.ps1` checks the .ps1 file exists in Private/

## InfoLevel Reference

| Level | Description |
|-------|-------------|
| 0 | Disabled (section not rendered) |
| 1 | Enabled / Summary |
| 2 | Advanced Summary |
| 3 | Detailed |
| 4 | Advanced Detailed |
| 5 | Comprehensive |

## Report JSON Configuration

The report configuration is in `AsBuiltReport.VMware.vSphere.json`. InfoLevel keys correspond to section names: `vCenter`, `Cluster`, `ResourcePool`, `VMHost`, `Network`, `vSAN`, `Datastore`, `DSCluster`, `VM`, `VUM`.

## Known Gotchas

### Pester 5 Discovery vs. Runtime Scoping
The `-Skip:()` expression in `It` blocks is evaluated at **discovery** time, before `BeforeAll {}` runs. Variables set in `BeforeAll` are not available to `-Skip:()` conditions. Use `BeforeDiscovery {}` for variables that control skip logic. Example in `AsBuiltReport.VMware.vSphere.Tests.ps1`:

```powershell
# Correct — BeforeDiscovery runs before -Skip:() is evaluated
BeforeDiscovery {
    $AnalyzerAvailable = $null -ne (Get-Module -Name PSScriptAnalyzer -ListAvailable | Select-Object -First 1)
}
```

### psm1 Module Exports
The `.psm1` only exports public functions (`Export-ModuleMember -Function $Public.BaseName`). Private section functions (`Get-AbrVSphere*`) are dot-sourced and available in module scope without being exported. The `FunctionsToExport` in the `.psd1` manifest acts as the final authoritative allow-list.

### Locale Key Consistency
The `en-US` locale file is the authoritative template. All other locales must have **identical key sets** — the `LocalizationData.Tests.ps1` Pester test enforces this. To quickly check parity without running Pester, compare key counts:
```powershell
# Count keys per locale manually
foreach ($locale in 'en-US','en-GB','es-ES','fr-FR','de-DE') {
    $count = (Get-Content ".\AsBuiltReport.VMware.vSphere\Language\$locale\VMwarevSphere.psd1" |
        Where-Object { $_ -match '^\s+\w+\s*=' -and $_ -notmatch "^'@" }).Count
    Write-Host "$locale`: $count keys"
}
```
