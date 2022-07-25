function Get-AbrvSphereVCObjects {
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