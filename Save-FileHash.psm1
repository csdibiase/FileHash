function Save-FileHash {
    <#
    .SYNOPSIS
    Generate a hash file in CSV format for all input files
    
    .DESCRIPTION
    This function generates a simple file has CSV for an inputed list of files
    
    .PARAMETER Path
    Input file path for the Get-ChildItem call

    .PARAMETER Output
    CSV file to contain the output hash

    .PARAMETER Algorithm 
    Hash algorithm to use.

    .PARAMETER Recurse
    Optional switch to hash files in subfolders to the specified path

    .EXAMPLE
    Save-FileHash -Path *.OVA -Output Hash.csv -Algorithm SHA256 -Recurse
    
    .NOTES
    By Christopher Di Biase <csdibiase@ra.rockwell.com>
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Output,
        [string][ValidateSet("MD5","SHA1","SHA256")]$Algorithm = "SHA256",
        [switch]$Recurse
    )
    
    # Set the current working directory to the path being evaluated
    Set-Location -Path $Path

    # Get a list of files to check. The script will optionally recurse through
    # all child folders.
    if ($Recurse) {
        $inFiles = Get-ChildItem -Path $Path -File -Recurse
    } else {
        $inFiles = Get-ChildItem -Path $Path -File
    }
    
    # Create the output file
    $outFile = New-Item -Path $Output -Force
    # Write the header into the output file
    Write-Output -InputObject "Path,Hash,Algorithm" | Out-File -FilePath $Output
    
    # Loop through all the input files
    $inFiles | ForEach-Object {
        # Generate the file hash
        $fileHash = Get-FileHash -Path $_.FullName -Algorithm $Algorithm
        # Generate a reletive path to the file
        $fileName = Resolve-Path -Path $_.FullName -Relative
        # Write the hash to the output file
        Write-Output "$FileName,$($fileHash.Hash),$($fileHash.Algorithm)" | Out-File -FilePath $Output -Append
        Write-Verbose $fileHash
    }

    # Dump the resultant output file to screen
    Import-CSV $outFile.FullName | Format-Table -AutoSize -Property Hash,Algorithm,Path
}

function Test-FileHash {
    <#
    .SYNOPSIS
    Check the hash of a file against a known good value and report OK/Failed
    
    .DESCRIPTION
    This function creates a simple pass/fail file has check.
    
    .PARAMETER HashFile
    CSV file continaing a header row, and one row per file to be checked with
    the Hash, file name or fullName, and hash algorithm.
    
    .EXAMPLE
    Test-FileHash -HashFile Hash.CSV
    
    .NOTES
    By Christopher Di Biase <csdibiase@ra.rockwell.com>
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$HashFile,
        [string[]]$Name
    )
    Write-Debug $HashFile
    $Files = Import-CSV -Path $HashFile
    $FilesToCheck = @()

    if ($null -ne $Name) { 
        foreach ($n in $Name) { 
            $FilesToCheck += $Files -match (Split-Path -Path $n -Leaf)
        }
    } else {
        $FilesToCheck = $Files
    } 
    foreach ($file in $FilesToCheck) {
        if ((Get-FileHash -Path $file.Path -Algorithm $file.Algorithm).Hash -eq $file.Hash.Trim()) {
            Write-Output "[   OK   ] $($file.Path)"
        } else {
            Write-Output "[ FAILED ] $($file.Path)"
        }
    }
}
Export-ModuleMember -Function Save-FileHash, Test-FileHash