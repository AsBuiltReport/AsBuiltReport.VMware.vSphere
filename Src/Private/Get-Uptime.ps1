function Get-Uptime {
    [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]
    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$VMHost, [PSObject]$VM
    )
    $UptimeObject = @()
    $Date = (Get-Date).ToUniversalTime() 
    If ($VMHost) {
        $UptimeObject = Get-View -ViewType hostsystem -Property Name, Runtime.BootTime -Filter @{
            "Name" = "^$($VMHost.Name)$"
            "Runtime.ConnectionState" = "connected"
        } | Select-Object Name, @{L = 'UptimeDays'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalDays), 2) } }, @{L = 'UptimeHours'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalHours), 2) } }, @{L = 'UptimeMinutes'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalMinutes), 2) } }
    }

    if ($VM) {
        $UptimeObject = Get-View -ViewType VirtualMachine -Property Name, Runtime.BootTime -Filter @{
            "Name" = "^$($VM.Name)$"
            "Runtime.PowerState" = "poweredOn"
        } | Select-Object Name, @{L = 'UptimeDays'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalDays), 2) } }, @{L = 'UptimeHours'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalHours), 2) } }, @{L = 'UptimeMinutes'; E = { [math]::round(((($Date) - ($_.Runtime.BootTime)).TotalMinutes), 2) } }
    }
    Write-Output $UptimeObject
}