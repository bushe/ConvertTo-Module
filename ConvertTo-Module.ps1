<#
.SYNOPSIS
    Easily build PowerShell modules for a set of functions contained in individual PS1 files
.DESCRIPTION
    Take a group of folders in this format:
        \Source
        \Source\Private
        \Source\Public

    And create a PowerShell module from them.  Will create the folders, module file and manifest (unless it already exists).  Any 
    PS1 file that contains a Function in it will be read and added to the module.  PS1 files in the Private folder will not be
    publicly published in the module (this is good for helper functions) and any PS1 files in the Public folder will be available for
    the user to run.  

    #Publish and #EndPublish allows you to add statements to your module.  Any code located between these lines will be included
    in the module, exactly as you write them.  This allows the inclusion of alias' or whatever other code you need to run when the module 
    is loaded.

    Write-Host "Not in the module"
    #Publish
    Write-Host "This is in the module"
    Write-Host "This is too"
    #EndPublish
    Write-Hote "But this isn't"

    #Publish and #EndPublish are ignored if inside a function.

.PARAMETER Path
    The path where you module folders and PS1 files containing your functions is located.

.PARAMETER CompanyName
    Only used when a module is created for the first time, you can put the company name in the appropriate field.

.INPUTS
    None
.OUTPUTS
    None
.EXAMPLE
    .\ConvertTo-Module.ps1 -Path -Path "\\server\share\Functions"

    Take all of the PS1 files in \\server\share\Functions and extract the functions from them and publish the resulting
    module(s) in the base directory:  \\server\share\Functions

.NOTES
    Author:             Martin Pugh
    Twitter:            @thesurlyadm1n
    Spiceworks:         Martin9700
    Blog:               www.thesurlyadmin.com
      
    Changelog:
        1.0             Initial Release
        1.1             Added #Publish and #EndPublish support.  Any code between these lines will be included in the module.
        1.11            Publish worked, but using an Alias didn't.  Turns out modules require special handling to export the
                        alias.
        1.2             Fixed module not loading when specifying folder instead of PSM1 file.  Removed automatic version incrementing.
                        Updated cbh
        1.21            Changed name to ConvertTo-Module since Publish-Module is now part of PS 5
.LINK
    https://github.com/martin9700/ConvertTo-Module
#>
[CmdletBinding()]
Param (
    [string]$Path,
    [string]$CompanyName = "Unknown"
)
Write-Verbose "$(Get-Date): ConvertTo-Module.ps1 started"

#Test for path
If ($Path)
{
    If (-not (Test-Path $Path))
    {
        Throw "$Path is an invalid folder"
    }
}
Else
{
    $Path = Split-Path -Path ($MyInvocation.MyCommand.Path)
}

#Test for needed folders, create if necessary
$PathList = "Source","Private","Public","Test"
$ParentPath = $Path
ForEach ($SubPath in $PathList)
{
    Remove-Variable -Name "$SubPath`Path" -Force -ErrorAction SilentlyContinue
    $tempPath = New-Variable -Name "$SubPath`Path" -Value (Join-Path -Path $ParentPath -ChildPath $SubPath) -Passthru
    If (-not (Test-Path $tempPath.Value))
    {
        New-Item -Path $tempPath.Value -ItemType Directory | Out-Null
    }
    $ParentPath = $SourcePath
}

#Read in the functions
$Statements = New-Object -TypeName System.Collections.ArrayList
$Functions = New-Object -TypeName System.Collections.ArrayList
$PublicFunctionNames = @{}
$HighVersion = [version]"0.0.0.2"
ForEach ($FunctionType in "Private","Public")
{
    $tempPath = Get-Variable -Name "$FunctionType`Path" | Select -ExpandProperty Value
    $Files = Get-ChildItem "$tempPath\*.ps1" -Recurse
    ForEach ($File in $Files)
    {
        $Raw = Get-Content $File
        $Count = 0
        $Begin = $false
        $PublishRegion = $false
        #$Synopsis = $false
        $Function = New-Object -TypeName System.Collections.ArrayList
        ForEach ($Line in $Raw)
        {
            #Write-host $Line
            If ($Line -like "#Publish*")
            {
                $PublishRegion = $true
                Continue
            }
            If ($PublishRegion -and (-not $Begin))
            {
                If ($Line -like "Function*")
                {
                    $PublishRegion = $false
                }
                Else
                {
                    If ($Line -like "#EndPublish*")
                    {
                        $PublishRegion = $false
                    }
                    Else
                    {
                        $Statements.Add($Line) | Out-Null
                    }
                    Continue
                }
            }
            If ($Line -like "Function*" -and (-not $Begin))
            {
                $Begin = $true
                If ($Line -match "(Function (?<FunctionName>.*) )|(Function (?<FunctionName>.*)$)" -and $FunctionType -eq "Public")
                {
                    $FName = $Matches.FunctionName.Trim()
                    If (-not $PublicFunctionNames.ContainsKey($FName))
                    {
                        $PublicFunctionNames.Add($FName,(New-Object -TypeName System.Collections.ArrayList)) | Out-Null
                    }
                }

                If ($Line -notlike "*{*")
                {
                    $Function.Add($Line) | Out-Null
                    Continue
                }
            }
            If ($Begin)
            {
                If ($Line -match "#requires -version (?<Version>.*)")
                {
                    $temp = $Matches.Version + ".0"
                    $Version = [version]$temp
                    If ($Version -gt $HighVersion)
                    {
                        $HighVersion = $Version
                    }
                }
                Else
                {
                    $Count = $Count + ($Line.Split("{").Count - 1)
                    $Count = $Count - ($Line.Split("}").Count - 1)
                    $Function.Add($Line) | Out-Null
                    If ($Count -eq 0)
                    {
                        $Functions.Add($Function -join "`n") | Out-Null
                        $Function = New-Object -TypeName System.Collections.ArrayList
                        $Begin = $false
                    }
                }
            }
        }
    }
}

#Save module
$ModuleName = Split-Path -Path $Path -Leaf
$OutModule = Join-Path -Path $Path -ChildPath "$ModuleName.psm1"
$Module = @"
$($Functions -join "`n`n`n")


#Included Statements:
$($Statements -join "`n")


Export-ModuleMember -Alias * -Function `"$($PublicFunctionNames.Keys -join '","')`"
"@
$Module | Out-File $OutModule -Force

#Create manifest
$OutManifest = Join-Path -Path $Path -ChildPath "$ModuleName.psd1"
If (-not (Test-Path $OutManifest))
{
    $Manifest = @{
        RootModule = $ModuleName
        ModuleVersion = "1.0.0.0"
        CompanyName = $CompanyName
        Path = $OutManifest
        PowerShellVersion = "$($HighVersion.Major).$($HighVersion.Minor)"
        Description = $ModuleName
    }
    New-ModuleManifest @Manifest
    Write-Verbose "$(Get-Date): Manifest for $($Path.BaseName) created"
}

Write-Verbose "$(Get-Date): Modules created at: $OutModule"
Write-Verbose "$(Get-Date): ConvertTo-Module.ps1 completed"