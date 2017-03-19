# Global Config Section
$nsxip = "nsxmgr.lab.ivoxy.com"
$nsxuser = "admin"
$nsxpassword = "******"
$vcenterip = "dc1vc1.lab.ivoxy.com"
$vcenteruser = "svc_labapi@lab.ivoxy.com"
$vcenterpassword = "Simple plate camel1"
$dvswitch = "dSwitch0"
$cluster = "lab"
$datastore = "tintri1"


#Lab Configuration
$labid = "lt001"
$prefix = "hovs1"
$students = @("chrisc","gregn")
$labip = "192.168.2.1"
$labdefaulthost = "192.168.2.10"
$labstartip = 101



# Connect to required resources
connect-viserver -server $vcenterip -user $vcenteruser -Password $vcenterpassword
Connect-NsxServer -server $nsxip -user $nsxuser -Password $nsxpassword


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

    
    
    foreach ($_ in (get-vm -location "$labid*")) {
        # This really needs to be fixed. Sleep timers are not the way to do this
        $VMName = "$prefix-$labid-$student-" + $_.name
        new-vm -Name $VMName -VM $_ -ResourcePool (get-resourcepool -location $cluster) -Location "$prefix-$labid" -datastore $datastore -RunAsync:$false
        start-sleep -Seconds 600
        get-vm -name $VMName | get-networkadapter | set-networkadapter -networkname (get-vdportgroup "*$LSName*") -confirm:$false -runasync:$false
        start-sleep -seconds 10
        get-vm -name $VMName | Start-VM

    }

        $labstartip = $labstartip + 1
}





# Disconnect from resources
Disconnect-VIServer -confirm:$false
Disconnect-NsxServer -confirm:$false

