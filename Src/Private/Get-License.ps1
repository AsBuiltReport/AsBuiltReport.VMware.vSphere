function Get-License {
    <#
    .SYNOPSIS
    Function to retrieve vSphere product licensing information.
    .DESCRIPTION
    Function to retrieve vSphere product licensing information.
    .NOTES
    Version:        0.3.0
    Author:         Tim Carman
    Twitter:        @tpcarman
    Github:         tpcarman
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .PARAMETER vCenter
    A vSphere vCenter Server object
    .PARAMETER Licenses
    All vSphere product licenses
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    Get-License -VMHost ESXi01
    .EXAMPLE
    Get-License -vCenter VCSA
    .EXAMPLE
    Get-License -Licenses
    #>
    [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]

    Param
    (
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$vCenter,
        [PSObject]$VMHost,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [Switch]$Licenses
    )

    $LicenseObject = @()
    $ServiceInstance = Get-View ServiceInstance -Server $vCenter
    $LicenseManager = Get-View $ServiceInstance.Content.LicenseManager -Server $vCenter
    $LicenseManagerAssign = Get-View $LicenseManager.LicenseAssignmentManager -Server $vCenter
    if ($VMHost) {
        $VMHostId = $VMHost.Extensiondata.Config.Host.Value
        $VMHostAssignedLicense = $LicenseManagerAssign.QueryAssignedLicenses($VMHostId)
        $VMHostLicense = $VMHostAssignedLicense.AssignedLicense
        $VMHostLicenseExpiration = ($VMHostLicense.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object Value).Value
        if ($VMHostLicense.LicenseKey -and $Options.ShowLicenseKeys) {
            $VMHostLicenseKey = $VMHostLicense.LicenseKey
        } else {
            $keyParts = $VMHostLicense.LicenseKey -split '-'
            $lastPart = $keyParts[-1]
            $maskedParts = $keyParts[0..($keyParts.Length - 2)] | ForEach-Object { '*' * $_.Length }
            $VMHostLicenseKey = ($maskedParts -join '-') + '-' + $lastPart
        }
        $LicenseObject = [PSCustomObject]@{
            Product = $VMHostLicense.Name
            LicenseKey = $VMHostLicenseKey
            Expiration =
            if ($VMHostLicenseExpiration -eq $null) {
                "Never"
            } elseif ($VMHostLicenseExpiration -gt (Get-Date)) {
                $VMHostLicenseExpiration.ToShortDateString()
            } else {
                "Expired"
            }
        }
    }
    if ($vCenter) {
        $vCenterAssignedLicense = $LicenseManagerAssign.GetType().GetMethod("QueryAssignedLicenses").Invoke($LicenseManagerAssign, @($_.MoRef.Value)) | Where-Object { $_.EntityID -eq $vCenter.InstanceUuid }
        $vCenterLicense = $vCenterAssignedLicense.AssignedLicense
        $vCenterLicenseExpiration = ($vCenterLicense.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object Value).Value
        if ($vCenterLicense.LicenseKey -and $Options.ShowLicenseKeys) {
            $vCenterLicenseKey = $vCenterLicense.LicenseKey
        } else {
            $keyParts = $vCenterLicense.LicenseKey -split '-'
            $lastPart = $keyParts[-1]
            $maskedParts = $keyParts[0..($keyParts.Length - 2)] | ForEach-Object { '*' * $_.Length }
            $vCenterLicenseKey = ($maskedParts -join '-') + '-' + $lastPart
        }
        $LicenseObject = [PSCustomObject]@{
            Product = $vCenterLicense.Name
            LicenseKey = $vCenterLicenseKey
            Expiration =
            if ($vCenterLicenseExpiration -eq $null) {
                "Never"
            } elseif ($vCenterLicenseExpiration -gt (Get-Date)) {
                $vCenterLicenseExpiration.ToShortDateString()
            } else {
                "Expired"
            }
        }
    }
    if ($Licenses) {
        foreach ($License in ($LicenseManager.Licenses | Where-Object { $_.licensekey -ne '' })) {
            $Object = @()
            $LicenseExpiration = $License.Properties | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object -ExpandProperty Value
            if ($Options.ShowLicenseKeys) {
                $LicenseKey = $License.LicenseKey
            } else {
                $keyParts = $License.LicenseKey -split '-'
                $lastPart = $keyParts[-1]
                $maskedParts = $keyParts[0..($keyParts.Length - 2)] | ForEach-Object { '*' * $_.Length }
                $LicenseKey = ($maskedParts -join '-') + '-' + $lastPart
            }
            $Object = [PSCustomObject]@{
                'License' = $License.License
                'Product' = $License.Name
                'LicenseKey' = $LicenseKey
                'Total' = $License.Total
                'Used' = Switch ($License.Used) {
                    $null { "0" }
                    default { $License.Used }
                }
                'Expiration' =
                if ($LicenseExpiration -eq $null) {
                    "Never"
                } elseif ($LicenseExpiration -gt (Get-Date)) {
                    $LicenseExpiration.ToShortDateString()
                } else {
                    "Expired"
                }
            }
            $LicenseObject += $Object
        }
    }
    Write-Output $LicenseObject
}