function Get-AbrvSphereVCResources {
    BlankLine

    $vCenterResources = @(
        [Ordered] @{ Resource = 'CPU'; Used = "$([math]::round(($vmhosts.CpuUsageMhz | Measure-Object -Sum).sum / 1000,2)) GHz"; Free = "$([math]::round((($vmhosts.CpuTotalMhz | Measure-Object -Sum).sum / 1000) - (($vmhosts.CpuUsageMhz | Measure-Object -Sum).sum / 1000),2)) GHz"; Capacity = "$([math]::round(($vmhosts.CpuTotalMhz | Measure-Object -Sum).sum / 1000,1)) GHz" }
        [Ordered] @{ Resource = 'Memory'; Used = "$([math]::round(($vmhosts.MemoryUsageGB | Measure-Object -Sum).sum,2)) GB"; Free = "$([math]::round((($vmhosts.MemoryTotalGB | Measure-Object -Sum).sum) - (($vmhosts.MemoryUsageGB | Measure-Object -Sum).sum),2)) GB"; Capacity = "$([math]::round(($vmhosts.MemoryTotalGB | Measure-Object -Sum).sum,2)) GB" }
        [Ordered] @{ Resource = 'Storage'; Used = "$([math]::Round(((($Datastores).CapacityMB | Measure-Object -sum).sum / 1024 / 1024) - ((($Datastores).FreeSpaceMB | Measure-Object -sum).sum / 1024 / 1024),2)) GB"; Free = "$([math]::round(((($Datastores).FreeSpaceMB | Measure-Object -sum).sum / 1024 / 1024),2)) GB"; Capacity = "$([math]::round(((($Datastores).CapacityMB | Measure-Object -sum).sum / 1024 / 1024),2)) GB" }
    )

    $TableParams = @{
        Name = "vCenter Resource Summary - $($vCenterServerName)"
        ColumnWidths = 25, 25, 25, 25
        List = $true
        Key = 'Resource'
    }
    if ($Report.ShowTableCaptions) {
        $TableParams['Caption'] = "- $($TableParams.Name)"
    }
    Table -Hashtable $vCenterResources @TableParams

    Blankline

    $vCenterObjects = [PSCustomObject]@{
        'Clusters' = $Clusters.Count
        'Hosts' = $TotalVMHosts.Count
        'Virtual Machines' = $TotalVMs.Count
    }

    $TableParams = @{
        Name = "vCenter Object Summary - $($vCenterServerName)"
        ColumnWidths = 33, 34, 33
        List = $false
    }
    if ($Report.ShowTableCaptions) {
        $TableParams['Caption'] = "- $($TableParams.Name)"
    }
    $vCenterObjects | Table @TableParams
}