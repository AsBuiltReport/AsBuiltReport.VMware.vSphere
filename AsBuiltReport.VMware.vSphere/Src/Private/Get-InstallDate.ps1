function Get-InstallDate {
    $esxcli = Get-EsxCli -VMHost $VMHost -V2 -Server $vCenter
    $thisUUID = $esxcli.system.uuid.get.Invoke()
    $decDate = [Convert]::ToInt32($thisUUID.Split("-")[0], 16)
    $installDate = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($decDate))
    [PSCustomObject][Ordered]@{
        Name = $VMHost.Name
        InstallDate = $installDate
    }
}