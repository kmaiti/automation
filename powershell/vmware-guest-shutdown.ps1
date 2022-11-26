<#
.SYNOPSIS
    shutdown vmware guests.
.DESCRIPTION
    shutdown vmware guests.
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

  [Parameter(Mandatory=$true)] 
  [string]$cluster,
  [Parameter(Mandatory=$true)]
  [string]$file
  
)


$nodes = Get-Content $file


Get-Cluster $cluster|Get-VM $nodes | Shutdown-VMGuest  

