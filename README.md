# ConvertTo-Module
This script will take a folder and create a module from it.  The idea is to make for easier module publishing in Git by 
taking a folder structure, reading the scripts in those folders and creating a module (with manifest).

Most people will use dynamic modules, that will dot source the functions from many files.  I don't like this approach because
it makes for a very--and needlessly--slow module load.  Especially if you're loading the module over the network. 

Tree structure:

Repository<br/>
&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;PowerShell-Module.psm1<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;PowerShell-Manifest.psd1<br/>
&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|--->en-us<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| Help files<br/>
&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|--->Source<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|--->Private<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Private Functions<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;--->Public<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Public Functions<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|<br/>
&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|--->Tests<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Pester support<br/>
                


TODO:

Done. Modify http://thesurlyadmin.com/2015/01/20/building-modules/ for these purposes<br/>
Done/Canceled. Comment-based help support, pull function help out and put into module help.  <br/>
&nbsp;&nbsp;   a. Think will just pull .DESCRIPTION section<br/>
&nbsp;&nbsp;   b. International help (not just en-us)<br/>
Done. Pester support?   <br/>
&nbsp;&nbsp;   a. Is Tests right place for this?<br/>
&nbsp;&nbsp;   b. If Pester is install, and Pester tests exists in Tests folder contains tests, Invoke-Pester?  Keep it separate (probably)<br/>
Done. Figure out Readme.md crappy formatting<br/>
