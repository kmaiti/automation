<#
.SYNOPSIS
    Get vmware tools version in vmware guests.
.DESCRIPTION
    Get vmware tools version in vmware guests.
.PARAMETER Path
    The path to the .
.PARAMETER LiteralPath

.EXAMPLE
    C:\PS> 
    scriptname  -cluster <vm clustername>  -file <filename containing list of guests>
    scriptname  <clustername>  <filename>
    scriptname  "AMX PLAB"  C:\Users\kamalma\Desktop\vm.txt
    scriptname -cluster "TMO PLAB" -file "C:\Users\kamalma\Desktop\vm.txt"
.NOTES
    Author: Kamal Maiti
    Date:   May 2, 2015    
#>

Param(

  #      [string]$f
  [Parameter(Mandatory=$true)] 
  [string]$cluster,
  [Parameter(Mandatory=$true)]
  [string]$file
  
)


$nodes = Get-Content $file

Get-Cluster $cluster | Get-VM $nodes| Select Name, Version, ToolsVersion, ToolsVersionStatus

#Get-Cluster $cluster |Set-VM -VM $nodes -Description $note -Confirm:$false;
