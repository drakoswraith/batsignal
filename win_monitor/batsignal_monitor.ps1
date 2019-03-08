
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")

$form1 = New-Object System.Windows.Forms.form
$form1.ShowInTaskbar = $false
$form1.WindowState = "minimized"

$NotifyIcon= New-Object System.Windows.Forms.NotifyIcon
$ContextMenu = New-Object System.Windows.Forms.ContextMenu
$MenuItemExit = New-Object System.Windows.Forms.MenuItem
$MenuItemSigOn = New-Object System.Windows.Forms.MenuItem
$MenuItemSigOff = New-Object System.Windows.Forms.MenuItem
$MenuItemPause = New-Object System.Windows.Forms.MenuItem
$MenuItemFlagFile = New-Object System.Windows.Forms.MenuItem
$TimerCheckFile = New-Object System.Windows.Forms.Timer
#$icon = New-Object System.Drawing.Icon("D:\tmp\myicon.ico")
#$NotifyIcon.Icon =  $icon


if((test-path 'HKCU:\Software\DrakosWraith') -eq $false) {
    New-Item –Path 'HKCU:\Software' –Name 'DrakosWraith'
}
if((test-path 'HKCU:\Software\DrakosWraith\BatSignal') -eq $false) {
    New-Item –Path 'HKCU:\Software\DrakosWraith' –Name 'BatSignal'
}

$flagFile = ""
$vals = Get-ItemProperty -Path "HKCU:\Software\DrakosWraith\BatSignal"
if($vals.FlagFile -eq $null) {
    $flagFile = "$env:onedrive\batsignal_on.txt"
    New-ItemProperty -Path "HKCU:\Software\DrakosWraith\BatSignal" -Name "FlagFile" -Value $flagFile  -PropertyType "String"
} else {
    $flagFile = $vals.FlagFile
}


function findTrinket() {
    # check if the Trinket is plugged in and return the path to it
    $driveLetter = $null
    $drives = gwmi cim_logicaldisk | ? drivetype -eq 2 | where-object {$_.VolumeName -eq "CIRCUITPY"}
    if($drives) {
        $driveLetter = $drives.DeviceID
    }
    return $driveLetter
}


function doCheck() {
    # check if the flag file is present
    #   if yes.. clear flag file
    # check if USB device is plugged in
    # set batsignal on if flag file was found and usb drive is available
    # user must manually turn light off once turned on

    $flagFileFound = test-path $flagFile
    if($flagFileFound) { remove-item $flagFile }
    if($flagFileFound) {
        $message = "Notification to enable Bat Signal Received!"
        $NotifyIcon.ShowBalloonTip(5000,"Bat Signal On!",$message,[system.windows.forms.ToolTipIcon]"Info")
        signalOn
    }
}

function signalOn(){
    $NotifyIcon.Text = "Bat Signal On"
    $d = findTrinket
    if($d) {
        $sigFile = "$d\\signalon.txt"
        if(test-path "$d\\") {
            if(test-path $sigFile) {
                Set-ItemProperty -Path $sigFile -Name LastWriteTime -Value (get-date)
            } else {
                new-item $sigFile
            }
        }
    }
}

function signalOff(){
    $NotifyIcon.Text = "Bat Signal Off"
    $d = findTrinket
    if($d) {
        $sigFile = "$d\\signaloff.txt"
        if(test-path "$d\\") {
            if(test-path $sigFile) {
                Set-ItemProperty -Path $sigFile -Name LastWriteTime -Value (get-date)
            } else {
                new-item $sigFile
            }
        }
    }
}

function togglePause(){
    if($TimerCheckFile.Enabled) {
        $TimerCheckFile.Stop()
    } else {
        $TimerCheckFile.Start()
    }
}

function setFlagFilePath(){
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Enter Path to Flag File'
    $form.Size = New-Object System.Drawing.Size(300,200)
    $form.StartPosition = 'CenterScreen'

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = 'OK'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = 'Cancel'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = 'Please enter file to watch for to trigger the signal automatically:'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(260,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $flagFile = $textBox.Text
        Set-ItemProperty -Path "HKCU:\Software\DrakosWraith\BatSignal" -Name "FlagFile" -Value $flagFile
    }
}

$TimerCheckFile.Interval = 30000 # (30sec)
$TimerCheckFile.add_Tick({doCheck})
$TimerCheckFile.start()

$MenuItemSigOn.Text = "Signal On"
$MenuItemSigOn.add_Click({
    signalOn
})

$MenuItemSigOff.Text = "Signal Off"
$MenuItemSigOff.add_Click({
    signalOff
})


$MenuItemFlagFile.Text = "Set Watch File Path"
$MenuItemFlagFile.add_Click({
    setFlagFilePath
})

$MenuItemPause.Text = "Pause Watching"
$MenuItemPause.add_Click({
    togglePause
})

$MenuItemExit.Text = "Exit"
$MenuItemExit.add_Click({
   $TimerCheckFile.stop()
   $NotifyIcon.Visible = $False
   $form1.close()
})


$NotifyIcon.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)
$NotifyIcon.ContextMenu = $ContextMenu
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSigOn)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSigOff)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemFlagFile)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemExit)
$NotifyIcon.Visible = $True

#doCheck
[void][System.Windows.Forms.Application]::Run($form1)






