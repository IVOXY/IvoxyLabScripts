

#Temp path definitions
$paramlab = "c:\git\ivoxylabscripts\lab.json"
$paramglobal = "c:\git\ivoxylabscripts\global.json"
#param([string[]]$paramlab,[string[]]$paramglobal)
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


foreach ($student in $students) {
    write-host $student
    write-host $labstartip
    $labstartip = $labstartip + 1
}