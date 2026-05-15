function Get-vCenterStats {
    $vCenterStats = @()
    $ServiceInstance = Get-View ServiceInstance -Server $vCenter
    $VCenterStatistics = Get-View ($ServiceInstance).Content.PerfManager
    [int] $CurrentServiceIndex = 2;
    Foreach ($xStatLevel in $VCenterStatistics.HistoricalInterval) {
        Switch ($xStatLevel.SamplingPeriod) {
            300 { $xInterval = '5 Minutes' }
            1800 { $xInterval = '30 Minutes' }
            7200 { $xInterval = '2 Hours' }
            86400 { $xInterval = '1 Day' }
        }
        ## Add the required key/values to the hashtable
        $vCenterStatsHash = @{
            IntervalDuration = $xInterval;
            IntervalEnabled = $xStatLevel.Enabled;
            SaveDuration = $xStatLevel.Name;
            StatsLevel = $xStatLevel.Level;
        }
        ## Add the hash to the array
        $vCenterStats += $vCenterStatsHash;
        $CurrentServiceIndex++
    }
    Write-Output $vCenterStats
}