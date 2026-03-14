function Convert-DataSize {
    param (
        [double]$Size,
        [ValidateSet("KB", "MB", "GB", "TB", "PB")]
        [string]$InputUnit = "GB",
        [ValidateSet("KB", "MB", "GB", "TB", "PB")]
        [string]$OutputUnit,
        [int]$RoundUnits = 2
    )

    switch ($InputUnit) {
        "KB" { $SizeInBytes = $Size * 1024 }
        "MB" { $SizeInBytes = $Size * 1024 * 1024 }
        "GB" { $SizeInBytes = $Size * 1024 * 1024 * 1024 }
        "TB" { $SizeInBytes = $Size * 1024 * 1024 * 1024 * 1024 }
        "PB" { $SizeInBytes = $Size * 1024 * 1024 * 1024 * 1024 * 1024 }
    }

    if (-not $OutputUnit) {
        if ($SizeInBytes -ge [math]::Pow(1024, 5)) {
            $OutputUnit = "PB"
        } elseif ($SizeInBytes -ge [math]::Pow(1024, 4)) {
            $OutputUnit = "TB"
        } elseif ($SizeInBytes -ge [math]::Pow(1024, 3)) {
            $OutputUnit = "GB"
        } elseif ($SizeInBytes -ge [math]::Pow(1024, 2)) {
            $OutputUnit = "MB"
        } elseif ($SizeInBytes -ge [math]::Pow(1024, 1)) {
            $OutputUnit = "KB"
        } else {
            $OutputUnit = "GB"
        }
    }

    switch ($OutputUnit) {
        "KB" { $OutputSize = $SizeInBytes / 1024 }
        "MB" { $OutputSize = $SizeInBytes / (1024 * 1024) }
        "GB" { $OutputSize = $SizeInBytes / (1024 * 1024 * 1024) }
        "TB" { $OutputSize = $SizeInBytes / (1024 * 1024 * 1024 * 1024) }
        "PB" { $OutputSize = $SizeInBytes / (1024 * 1024 * 1024 * 1024 * 1024) }
    }

    return "{0:N$RoundUnits} $OutputUnit" -f $OutputSize
}