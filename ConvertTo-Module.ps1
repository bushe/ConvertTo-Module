<#
.SYNOPSIS
    Easily build PowerShell modules for a set of functions contained in individual PS1 files
.DESCRIPTION
    Take a group of folders in this format:
        \Source
        \Source\Private
        \Source\Public(Optional, can be stored in Source root)
        \Source\Test

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

.PARAMETER Name
    Name of the module.  By default it will be the same name as the parent directly.
        c:\modules\MyTools    - Module Name would be MyTools
        
.PARAMETER ForceFolderCreation
    ForceFolderCreation will force the creation of Private and Tests folders if they were deleted.       

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
    [string]$Name,
    [string[]]$AliasesToExport,
    [string]$Author,
    [string]$CompanyName,
    [string]$Copyright,
    [string]$DefaultCommandPrefix,
    [string]$Description,
    [string[]]$FileList,
    [guid]$Guid,
    [string]$HelpInfoUri,
    [version]$ModuleVersion,
    [object[]]$RequiredModules,
    [version]$PowerShellVersion,
    [switch]$ForceFolderCreation    
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
$PathList = "Source","Public","Private","Test"
$ParentPath = $Path
ForEach ($SubPath in $PathList)
{
    Remove-Variable -Name "$SubPath`Path" -Force -ErrorAction SilentlyContinue
    $tempPath = New-Variable -Name "$SubPath`Path" -Value (Join-Path -Path $ParentPath -ChildPath $SubPath) -Passthru
    
    if($SubPath -eq "Public" -and -not (Test-Path $tempPath.Value) -and (Get-ChildItem $SourcePath\*.ps1).count -ge 1){
        Write-Verbose "No Public folder found so Defaulting to .ps1 stored directly in source"
        Set-Variable -Name "$SubPath`Path" -Value $SourcePath
    }
    
    If (-not (Test-Path $tempPath.Value))
    {
        New-Item -Path $tempPath.Value -ItemType Directory | Out-Null
    }
    elseif($ParentPath -eq $SourcePath -and $ForceFolderCreation -eq $false)
    {
        break
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
    $tempPath = Get-Variable -Name "$FunctionType`Path" -ErrorAction SilentlyContinue | Select -ExpandProperty Value
    if($tempPath){
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
                    If ($Line -match "Function (?<FunctionName>\w+(-|.)?\w+)( |\{)?.*" -and $FunctionType -eq "Public")
                    {
                        $FName = $Matches.FunctionName.Trim()
                        If (-not $PublicFunctionNames.ContainsKey($FName))
                        {
                            $PublicFunctionNames.Add($FName,"") 
                        }
                        Else
                        {
                            Write-Warning "Duplicate function found in $File.  Function Name: $FName"
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
}

#Save module
If ($Name)
{
    $ModuleName = $Name
}
Else
{
    $ModuleName = Split-Path -Path $Path -Leaf
}
$OutModule = Join-Path -Path $Path -ChildPath "$ModuleName.psm1"
$Module = @"
$($Functions -join "`n`n`n")


#Included Statements:
$($Statements -join "`n")

"@
$Module | Out-File $OutModule -Force

#Create manifest
$OutManifest = Join-Path -Path $Path -ChildPath "$ModuleName.psd1"
$ManifestSplat = $PSBoundParameters

Write-Verbose "Removing any Parameters not supported by Update-ModuleManifest"
foreach($Parameter in $ManifestSplat){
    $AvailableParams = Get-Command Update-ModuleManifest  | Select -ExpandProperty Parameters
    if($AvailableParams -notcontains $Parameter){
        $ManifestSplat.Remove($Parameter) | Out-Null
    }
}

$ManifestSplat.Path = $OutManifest
$ManifestSplat.FunctionsToExport = [array]$PublicFunctionNames.Keys
If (-not (Test-Path $OutManifest))
{
    $ManifestSplat.RootModule = $ModuleName
    If (-not $PowerShellVersion)
    {
        $ManifestSplat.PowerShellVersion = "$($HighVersion.Major).$($HighVersion.Minor)"
    }
    If (-not $Description)
    {
        $ManifestSplat.Description = $ModuleName
    }
    New-ModuleManifest @ManifestSplat
    Write-Verbose "$(Get-Date): Manifest for $ModuleName created"
}
Else
{
    Update-ModuleManifest @ManifestSplat
    Write-Verbose "$(Get-Date): Manifest for $ModuleName was updated"
}

Write-Verbose "$(Get-Date): Modules created at: $OutModule"
Write-Verbose "$(Get-Date): ConvertTo-Module.ps1 completed"