<#

.SYNOPSIS
This script will build an IVOXY lab setup using powercli and powernsx

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
#$paramlab = "c:\git\ivoxylabscripts\0808A-lt001.json"
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


#Create folder
(get-view -viewtype folder -filter @{"name"="Student Labs"}).createfolder("$prefix-$labid")

# Do stuff
foreach ($student in $students) {
    # Create Virtual Wire
    $LSName = "$prefix-$labid-$student"
    $LSwitch = Get-NsxTransportZone -name "dc1" | New-NsxLogicalSwitch $LSName
    get-vdportgroup -name "*$LSName*" | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true

    #Create Edge
    $Edgename = "$prefix-$labid-$student"
    $edgevnic0 = New-NsxEdgeInterfaceSpec -index 0 -name "Uplink" -Type uplink -ConnectedTo (Get-VDPortgroup -name "VLAN105*") -PrimaryAddress "10.100.5.$labstartip" -SubnetPrefixLength 24
    $edgevnic1 = new-nsxedgeinterfacespec -index 1 -name "internal" -Type internal -ConnectedTo $LSwitch -PrimaryAddress $labip -SubnetPrefixLength 24

    $edge = New-NsxEdge -Name $edgename -cluster (Get-Cluster -name $cluster) -Datastore (Get-Datastore -name $datastore) -interface $edgevnic0,$edgevnic1 -password "Go#Sand!waffles22" -FwDefaultPolicyAllow
    get-nsxedge -name $Edgename | get-nsxedgerouting | Set-NsxEdgeRouting -defaultgatewayaddress 10.100.5.1 -confirm:$false
    get-nsxedge -name $edgename | get-nsxedgenat | New-NsxEdgeNatRule -Vnic 0 -OriginalAddress "10.100.5.$labstartip" -TranslatedAddress $labdefaulthost -action dnat
    get-nsxedge -name $edgename | get-nsxedgenat | New-NsxEdgeNatRule -Vnic 0 -OriginalAddress "192.168.2.0/24" -TranslatedAddress "10.100.5.$labstartip" -action snat
    get-nsxedge -name $edgename | get-nsxedgerouting | New-NsxEdgeStaticRoute -Network 10.1.0.0/22 -NextHop 192.168.2.254 -confirm:$false
    
    
    foreach ($_ in (get-vm -location "$labid*")) {
        # This really needs to be fixed. Sleep timers are not the way to do this
        $VMName = "$prefix-$labid-$student-" + $_.name
        new-vm -Name $VMName -VM $_ -ResourcePool (get-resourcepool -location $cluster) -Location "$prefix-$labid" -datastore $datastore -RunAsync:$false
        #Wait-Task -Task $task
        #start-sleep -Seconds 900
        start-sleep -seconds 60
        #add select-object -first 2
        get-vm -name $VMName | get-networkadapter |select-object -first 2| set-networkadapter -networkname (get-vdportgroup "*$LSName*") -confirm:$false -runasync:$false
        start-sleep -seconds 10
        get-vm -name $VMName | Start-VM

    }

        $labstartip = $labstartip + 1
}





# Disconnect from resources
Disconnect-VIServer -confirm:$false
Disconnect-NsxServer -confirm:$false

