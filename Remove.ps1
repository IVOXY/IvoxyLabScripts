<#

.SYNOPSIS
This script will remove an IVOXY lab setup using powercli and powernsx

.DESCRIPTION
this script accepts 2 parameters. 1) a global configuration jason file containing server locations and login information (see global.json for an example) and 2) a lab json file that contains the lab build notes (see the labexample.json file for an example)

This script will simply clone all of the virtual machines in a "lab ID" directory on the vcenter server and build a new virtual wire and edge gateway.

.EXAMPLE
.\Remove.ps1 -paramlab .\0808A-lt001.json -paramglobal .\global.json

.NOTES
N/A

.LINK
http://github.com/ivoxy

#>



#Temp path definitions
#$paramlab = "c:\git\ivoxylabscripts\0807B-lt004.json"
#$paramglobal = "c:\git\ivoxylabscripts\global.json"
param([string[]]$paramlab,[string[]]$paramglobal)
try {
    $lab = get-content -raw -path $paramlab |convertfrom-json
}
catch {throw "I don't have a valid lab definition"}
try {
    $global = get-content -raw -path $paramglobal |convertfrom-json
}
catch {throw "I don't have a valid global definition"}

# Global Config Section

$dvswitch = $global.vcenter.dvswitch
$cluster = $global.vcenter.cluster
$datastore = $global.vcenter.datastore


#Lab Configuration
$labid = $lab.labid
$prefix = $lab.prefix
$students = $lab.students
$labip = $lab.labip
$labdefaulthost = $lab.labdefaulthost
$labstartip = $lab.labstartip

# Connect to required resources
connect-viserver -server $global.vcenter.ip -user $global.vcenter.user -Password $global.vcenter.password
Connect-NsxServer -server $global.nsx.ip -user $global.nsx.user -Password $global.nsx.password



foreach ($student in $students) {
    
    get-vm -location "$prefix-$labid*" |Stop-VM -confirm:$false  -runasync:$false
    get-vm -location "$prefix-$labid*" | remove-vm -DeletePermanently:$true -confirm:$false -runasync:$false

    
    $Edgename = "$prefix-$labid-$student"
    get-nsxedge -name $Edgename | Remove-NsxEdge -Confirm:$false

    start-sleep -s 10

    $LSName = "$prefix-$labid-$student"
    Get-NsxLogicalSwitch -name $LSname | Remove-NsxLogicalSwitch -Confirm:$false

    start-sleep -s 10
    
    get-folder -name "$prefix-$labid" |remove-folder -confirm:$false


    $labstartip = $labstartip + 1
}


Disconnect-VIServer -confirm:$false
Disconnect-NsxServer -confirm:$false