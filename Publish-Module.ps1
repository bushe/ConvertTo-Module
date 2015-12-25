<#
.SYNOPSIS
    Easily build PowerShell modules for a set of functions contained in individual PS1 files
.DESCRIPTION
    Put a collection of your favorite functions into their own PS1 files, complete with any code you used for
    testing purposes and this script will extract ONLY the function portion and gather all the functions into
    a PowerShell module.  The module will be named after the folder name they're placed under.  Script will also
    support nested folders, meaning all functions in all subfolders will be contained int he main module, but
    a second module named after the nested folder will be created and will only contain the functions from it's
    folder and every nested folder under there, etc.

    Functions
        Module1
            Module2
        Module3

    Point the script at Functions and 3 modules will be created.  Module1 will contain all functions in the Modules1
    and Modules 2 folder.  Module 2 will only contain the functions in the Modules2 folder.  Module3 will be a 
    separate module and only contain the functions in that folder.

    Manifest file for the module will also be created with the correct PowerShell version requirement (assuming you
    specified this with the "#requires -Version" code in your functions), and the script will also increment the
    version number of the module based on the number of PS1 files that have changed from the last publish.

    Manifest file can also be edited to suit your requirements.

    #Publish and #EndPublish allows you to add statements to your module.  Any code located between these lines will be included
    in the module.  This allows the inclusion of alias' or whatever other code you need to run when the module is loaded.

    Write-Host "Not in the module"
    #Publish
    Write-Host "This is in the module"
    Write-Host "This is too"
    #EndPublish
    Write-Hote "But this isn't"

    #Publish and #EndPublish are ignored if inside a function.

.PARAMETER Path
    The path where you module folders and PS1 files containing your functions is located.

.PARAMETER ModulePath
    The destination folder where your newly created modules and module manifest files will be stored.  Each module will
    get it's own folder.

.PARAMETER CompanyName
    Only used when a module is created for the first time, you can put the company name in the appropriate field.

.INPUTS
    None
.OUTPUTS
    None
.EXAMPLE
    .\Publish-Module.ps1 -Path "\\server\share\Functions" -ModulePath "\\server\share\Modules"

    Take all of the PS1 files in \\server\share\Functions and extract the functions from them and publish the resulting
    module(s) to \\server\share\Modules, complete with manifest file.

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
.LINK
    http://community.spiceworks.com/scripts/show/2981-create-powershell-modules-on-the-fly-publish-module-ps1
#>
[CmdletBinding()]
Param (
    [string]$Path = "c:\Dropbox\test\citrix.NetScaler"
)
Write-Verbose "$(Get-Date): Publish-Module.ps1 started"

$CBHKeywords = "(SYNOPSIS)|(DESCRIPTION)|(PARAMETER)|(EXAMPLE)|(INPUTS)|(OUTPUTS)|(NOTES)|(LINK)|(COMPONENT)|(ROLE)|(FUNCTIONALITY)|(FORWARDHELPTARGETNAME)|(FORWARDHELPCATEGORY)|(EXTERNALHELP)"

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
<#
$HelpPath = Join-Path -Path $Path -ChildPath "en-US"
If (-not (Test-Path $HelpPath))
{
    New-Item -Path $HelpPath -ItemType Directory | Out-Null
}
#>

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
            Write-host $Line
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
                #If ($Synopsis)
                #{
                #    If ($Line -match $CBHKeywords -or $Line -like "*#>*")
                <#    {
                        $Synopsis = $false
                    }
                    Else
                    {
                        $PublicFunctionNames[$FName].Add($Line) | Out-Null
                    }
                }
                If ($Line -match "\.SYNOPSIS(?<FirstLine>.*)" -and -not ($Synopsis))
                {
                    If ($Matches.FirstLine)
                    {
                        $PublicFunctionNames[$FName].Add($Matches.FirstLine) | Out-Null
                    }
                    $Synopsis = $true
                }
                #>

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
$OutModule = Join-Path -Path $Path -ChildPath "$(Split-Path -Path $Path -Leaf).psm1"
$Functions -join "`n`n`n" | Out-File $OutModule -Encoding ascii
Add-Content -Value "`n`n#Included Statements:" -Path $OutModule
Start-Sleep -Milliseconds 500
Add-Content -Value $Statements -Path $OutModule
Start-Sleep -Milliseconds 500
Add-Content -Value "`n`nExport-ModuleMember -Alias * -Function `"$($PublicFunctionNames.Keys -join '","')`"" -Path $OutModule

<# Removing automatic help creation, it just doesn't look good
$HelpFunctions = ForEach ($Func in $PublicFunctionNames.Keys)
{
    Write-Output "$Func`n"
    ForEach ($Line in $PublicFunctionNames[$Func])
    {
        Write-Output "$Line`n"
    }
    Write-Output " "
}
$Help = @"
TOPIC
$(Split-Path -Path $Path -Leaf)

LONG DESCRIPTION
$HelpFunctions
"@
$Help | Out-File (Join-Path -Path $HelpPath -ChildPath "about_$(Split-Path -Path $Path -Leaf).help.txt") -Encoding utf8
#>

#Create manifest
$OutManifest = Join-Path -Path $Path -ChildPath "$(Split-Path -Path $Path -Leaf).psd1"
If (Test-Path $OutManifest)
{
    $Manifest = Invoke-Expression -Command (Get-Content $OutManifest -Raw)
    $LastChange = (Get-ChildItem $OutManifest).LastWriteTime
    $ChangedFiles = ($Files | Where LastWriteTime -gt $LastChange).Count
    $PercentChange = 100 - ((($Files.Count - $ChangedFiles) / $Files.Count) * 100)
    $Version = ([version]$Manifest["ModuleVersion"]) | Select Major,Minor,Build,Revision
    If ($PercentChange -ge 50)
    {
        $Version.Major ++
        $Version.Minor = 0
        $Version.Build = 0
        $Version.Revision = 0
    }
    ElseIf ($PercentChange -ge 25)
    {
        $Version.Minor ++
        $Version.Build = 0
        $Version.Revision = 0
    }
    ElseIf ($PercentChagne -ge 10)
    {
        $Version.Build ++
        $Version.Revision = 0
    }
    ElseIf ($PercentChange -gt 0)
    {
        $Version.Revision ++
    }
    $Manifest["ModuleVersion"] = "$($Version.Major).$($Version.Minor).$($Version.Build).$($Version.Revision)"

}
Else
{
    $Manifest = @{
        RootModule = $Dir.BaseName
        ModuleVersion = "1.0.0.0"
        CompanyName = $CompanyName
    }
}
$Manifest.Add("Path",$OutManifest)
$Manifest["PowerShellVersion"] = "$($HighVersion.Major).$($HighVersion.Minor)"
If ($Manifest["CompanyName"] -eq "Unknown")
{
    $Manifest["CompanyName"] = $CompanyName
}
New-ModuleManifest @Manifest
Write-Verbose "$(Get-Date): Manifest for $($Dir.BaseName) created"

Write-Verbose "$(Get-Date): Modules created at: $ModulePath"
Write-Verbose "$(Get-Date): Publish-Module.ps1 completed"