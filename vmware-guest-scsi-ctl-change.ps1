<#
.SYNOPSIS
    Change scsi controller type from paravirtual to LSI parallel in vmware guests.
.DESCRIPTION
    Change scsi controller type from paravirtual to LSI parallel in vmware guests.
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
  #      [Parameter(Mandatory=$true)]  
  #      [ValidateScript({$_ -match [IPAddress]$_ })]    #validate IP address
  #      [string]$h,
  #      [string]$u,
   
  #      [string]$c,
  #      [string]$f
  [Parameter(Mandatory=$true)] 
  [string]$cluster,
  [Parameter(Mandatory=$true)]
  [string]$file
  
)
<#

$my_password = read-host "Enter a Password:" #-assecurestring
#Write-Host "$h : $u : $pw : $c : $f"
#$password = ConvertTo-SecureString "123" -AsPlainText -Force
#$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password)
#$result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
#Write-Host $result
#Write-Host $my_password
#VI-Connect 
#>

$nodes = Get-Content $file
#Write-Host "$h -> $cluster"
#Get-VM $host|

#View vm which has scisci controller as "ParaVirtual"
#Get-Cluster $cluster|Get-VM $nodes |Get-ScsiController | where {$_.Type -eq "ParaVirtual"} 

#make sure vms are kept offline before performing scsi changes.
Get-Cluster "$cluster"|Get-VM $nodes |Get-ScsiController | where {$_.Type -eq "ParaVirtual"} | Set-ScsiController -Type VirtualLsiLogic -Confirm:$false

