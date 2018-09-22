# Get public function definition files and dot source them
$Public = @(Get-ChildItem -Path $PSScriptRoot\Src\Public\*.ps1)

foreach ($Module in $Public) {
    try {
        . $Module.FullName
    } catch {
        Write-Error -Message "Failed to import function $($Module.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
