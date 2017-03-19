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