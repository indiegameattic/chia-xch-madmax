$Threads = "12"
$Drives = @("C:","D:")

$FarmerPublicKey = "qqq"
$PoolContract = "www"
$NumberOfPlots = "1"
$MinimumDiskSpace = 150
$MadMaxFolderPath = "C:\madMAx43v3r_chia-plotter_win_v0.1.5\"

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

foreach ($drive in $Drives) {
    
    $DriveFreeDiskSpace = Get-FreeSpaceGb($drive)
    While ($DriveFreeDiskSpace -gt $MinimumDiskSpace) {

        if ($DriveFreeDiskSpace -gt 0) {
            Write-Host "Drive:" $drive
            Write-Host "----------------"
            Write-Host "Free Disk Space:" $DriveFreeDiskSpace -ForegroundColor Yellow

            $Expression = $MadMaxFolderPath + ".\chia_plot.exe -t " + $drive + "\"
            $Expression += " -d " + $drive + "\"
            $Expression += " -r " + $Threads
            $Expression += " -n " + $NumberOfPlots
            $Expression += " -f " + $FarmerPublicKey
            $Expression += " -c " + $PoolContract
            $Expression = $Expression.Replace("  ", " ")

            Write-Host $Expression
            #Invoke-Expression $Expression

            $DriveFreeDiskSpace = Get-FreeSpaceGb($drive)

            #Start-Sleep 30
        } else {
            Write-Host ***Insufficient disk space in $drive
        }
    }
    Write-Host $drive Full
}
