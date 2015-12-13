# Publish-Module
This script will take a folder and create a module from it.  The idea is to make for easier module publishing in Git by 
taking a folder structure, reading the scripts in those folders and creating a module (with manifest).

Most people will use dynamic modules, that will dot source the functions from many files.  I don't like this approach because
it makes for a very--and needlessly--slow module load.  Especially if you're loading the module over the network. 

Tree structure:

Repository
  |
  | PowerShell-Module.psm1
  | PowerShell-Manifest.psd1
  |
  |--->en-us
  |      |  
  |      | Help files
  |
  |--->Source
  |      |
  |      |--->Private
  |      |      |  Private Functions
  |      |
  |      |--->Public
  |      |      |  Public Functions
  |      |
  |      |--->Tests
                |  Pester support
                


TODO:

1. Modify http://thesurlyadmin.com/2015/01/20/building-modules/ for these purposes
2. Comment-based help support, pull function help out and put into module help.  
   a. Potential have separate help?  #region Help Maybe?
   b. International help (not just en-us)
3. Pester support?   
   a. Is Tests right place for this?
   b. If Pester is install, and Pester tests exists in Tests folder contains tests, Invoke-Pester?  Keep it separate (probably)
