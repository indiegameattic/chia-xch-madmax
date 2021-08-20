$PlotsSourcePaths = @("C:\Users\ZZZ")
$PlotsDestinations = @("\\10.0.0.2\e", "\\10.0.0.3\f")

$share1 = @("E:", "\\10.0.0.2\e", $true, "XXX", "YYY")
$share2 = @("F:","\\10.0.0.3\f", $true, "XXX", "YYY")
$Shares = @($share1, $share2)

$ExcludeDrives = @("C:", "D:")
$WaitSeconds = 600
$MinimumDiskSpace = 150

function Refresh-NetworkDrives ($Shares) {
    Write-Host Refreshing Network Shares...
    foreach ($share in $Shares) {
        ### Drop share
        try { (New-Object -ComObject WScript.Network).RemoveNetworkDrive($share[0], $true) } catch { }
        ### Map share
        $status = (New-Object -ComObject WScript.Network).MapNetworkDrive($share[0], $share[1], $share[2], $share[3], $share[4])
    }
    Get-CimInstance -ClassName Win32_LogicalDisk
}

function Get-FreeSpaceGb ([parameter(Mandatory=$true)][String] $driveLetter) {
    if ($driveLetter.Length -eq 2) {
        $DriveFreeDiskSpace = (Get-CimInstance -ClassName Win32_LogicalDisk | 
            Select-Object -Property DeviceID,@{Name = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} | 
                Where-Object {$_.DeviceID -eq $driveLetter} | 
                    Measure-Object -Property 'FreeSpace (GB)' -Sum).Sum

        return $DriveFreeDiskSpace
    } else {
        ### Parameter invalid
        return -1
    }
}

Refresh-NetworkDrives($Shares)

$TotalFreeSpaceGb = (Get-CimInstance -ClassName Win32_LogicalDisk | 
    Select-Object -Property DeviceID, DriveType, @{Name = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} | 
        Where-Object {$_.DeviceID -notin $ExcludeDrives} | 
            Measure-Object -Property 'FreeSpace (GB)' -Sum).Sum

if ([bool]$TotalFreeSpaceGb) {
    do {
        $Drives = Get-CimInstance -ClassName Win32_LogicalDisk | 
            Select-Object -Property DeviceID, DriveType, ProviderName, @{Name='FreeSpace'; Expression={ [int]($_.FreeSpace / 1GB)}} | 
                Where-Object {$_.DeviceID -notin $ExcludeDrives}

        $ServerPaths = $Drives.ProviderName
        foreach ($plotsSourcePath in $PlotsSourcePaths) {

            $Plots = Get-ChildItem -Path "$plotsSourcePath\*" -Include *.plot

            if ($Plots.Length -gt 0) {
                ### Move each completed plot to harvester
                foreach ($plot in $Plots) {
                    Write-Host Move $plot.Name -ForegroundColor Blue -BackgroundColor White

                    ### Loop through available harvestrs to find free space
                    foreach ($drive in $Drives) {
                        $freeSpaceGb = Get-FreeSpaceGb($drive.DeviceID)

                        ### If free space is greater than 150GB...
                        if ($drive.FreeSpace -gt $MinimumDiskSpace) {
                            ### Move plot to harvester
                            if ($drive.DriveType -eq 4) {
                                $Destination = $drive.ProviderName.TrimEnd()+$PlotsDestinationFolder
                            } else {
                                $Destination = $drive.DeviceID.TrimEnd()+$PlotsDestinationFolder
                            }
                            robocopy $plotsSourcePath $Destination $plot.Name /MOVE /A-:SH /j /NJH /MT:4
                            Break
                        }
                    }
                }

                $TotalFreeSpaceGb = (Get-CimInstance -ClassName Win32_LogicalDisk | 
                    Select-Object -Property DeviceID, DriveType, @{Name = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} | 
                        Where-Object {$_.DeviceID -notin $ExcludeDrives} | 
                            Measure-Object -Property 'FreeSpace (GB)' -Sum).Sum

                Write-Host Total Free Space $TotalFreeSpaceGb GB -ForegroundColor Yellow
            } else {
                Write-Host No Plots found on $plotsSourcePath -ForegroundColor Red
            }
        }
        Write-Host Waiting...
        for ($i = $WaitSeconds; $i -gt 1; $i-- )
        {
            Write-Progress -Activity "Waiting..." -SecondsRemaining $i
            Start-Sleep 1
        }
    }
    until ($TotalFreeSpaceGb -lt $MinimumDiskSpace)

} else {
    Write-Host No available disk space
}
