$InformationPreference = "Continue"

function DisplayHelp([string]$text, [string]$color) {
    if ($color) {
        Write-Host $text -ForegroundColor $color
    }else {
        Write-Host "`n"$text "`n"
    }
}


# Text header formatting function
function DisplayHeader([string]$text){
    $textPadding = [int]($textLenght - $text.Length)/2
    Write-Host "`n"
    Write-Host $("#" * $textLenght) "`n"
    Write-Host $(" " * $textPadding ) $text "`n"
    Write-Host $("#" * $textLenght) "`n"
}

# Set default log directory (in case the variable $LogFile has not been defined)
#$LogFile = ""
if ( ([string]::IsNullOrEmpty($LogFile)) -Or ($LogFile.Length -eq 0) ) {
    $LogDir = ".\Logs"
    $LogFileName = "DefaultLogFile_$(Get-Date -format dd-MM-yyyy).log"
    $LogFile = Join-path $LogDir $LogFileName
    #New-Item $LogFile
}

Function Write-ActivityLog {
    <#
        .SYNOPSIS
        Write text to this script's log file
        .DESCRIPTION
        Write text to this script's log file
        .PARAMETER InformationType
            This parameter contains the information type prefix. Possible prefixes and information types are:
                I = Informational only with no acftion
                S = Success execution
                W = Warning Message
                E = Error Message
        .PARAMETER Text
            This parameter contains the text (the line) you want to write to the log file.
        .PARAMETER LogFile
            The file name and file extension to the log file (e.g. C:\Logs\logFile.log)
        .EXAMPLE
            Write-ActivityLog -InformationType "I" -Text "Copy files to C:\Temp" -LogFile "C:\Logs\logFile.log"
            Writes a line containing information to the log file

    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
        [Parameter(Mandatory=$false, Position = 2)][String]$LogFile
    )
    process {
        # Create new log file (overwrite existing one should it exist)
        if (! (Test-Path $LogFile) ) {
            # Note: the 'New-Item' cmdlet also creates any missing (sub)directories as well (works from W7/W2K8R2 to W10/W2K16 and higher)
            New-Item $LogFile -ItemType "file" -force | Out-Null
        }

        $DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)

        if ( $Text -eq "" ) {
            Add-Content $LogFile -value ("") # Write an empty line
        } else {
            Add-Content $LogFile -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }

        # Besides writing output to the log file also write it to the console
        Write-Information "`n$($InformationType.ToUpper()) - $Text" -InformationAction Continue
    }
}
