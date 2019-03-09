param(
    [boolean]$addStartup = $false
)
#---------------------------------------------------------------------------------------------
# batsignal_monitor.ps1
# https://github.com/drakoswraith/batsignal
# Author: Michael Lehman <drakoswraith@gmail.com>
#
# Watch for a file on onedrive (or any other location), and when it shows up
# Update a control file on a USB Drive (presumably a trinket M0), to trigger an action
# 
# This script is intended to be run at startup
# It will create a systray icon with a lightbulb icon
# Right click the icon to bring up the menu
# 
# By default, this looks for a file at:
#
# To update this default path, use the "Set Watch File Path" menu option, or edit the registry 
# Key at:
# HKEY_CURRENT_USER\Software\DrakosWraith\BatSignal
# 
#---------------------------------------------------------------------------------------------
# Add to startup:
#---------------------------------------------------------------------------------------------
# Run script  with -addStartup $True to add to startup items
#       .\batsignal_monitor.ps1 -addStartup $True
# 
# Or manually add shortcut to startup:
#    start "$Env:APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
# and then manually create a shortcut to this script file there
# 
#---------------------------------------------------------------------------------------------
# Icons made by https://www.flaticon.com/authors/nice-and-serious
# from https://www.flaticon.com/	    
# Licensed by http://creativecommons.org/licenses/by/3.0/			   
#---------------------------------------------------------------------------------------------
$StartUp="$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$scriptdir = $PSCommandPath.Substring(0, $PSCommandPath.LastIndexOf("\") + 1)

function remStartup() {
    $delTask = 'schtasks /delete /f /tn "Batsignal_Monitor"'
    Start-Process -FilePath powershell.exe -ArgumentList $delTask -verb RunAs -WorkingDirectory C:
    #Start-Process -FilePath powershell.exe -ArgumentList $delTask -verb RunAs -WorkingDirectory C:
    #if(test-path "$StartUp\\BatSignalMonitor.lnk") { remove-item "$StartUp\\BatSignalMonitor.lnk" }
}

function addStartup() {
    $delTask = 'schtasks /delete /f /tn "Batsignal_Monitor"'
    $c = "'powershell.exe -windowstyle hidden -file `"" + $PSCommandPath + "`"'"
    $createTask = $delTask + '; schtasks /create /tn "Batsignal_Monitor" /sc onlogon /delay 0000:30 /tr ' + $c + '; pause'
    Start-Process -FilePath powershell.exe -ArgumentList $createTask -verb RunAs -WorkingDirectory C:
    #$code = 'New-Item -ItemType SymbolicLink -Path "' + "`'" + $StartUp  + "`'" + '" -Name "BatSignalMonitor.lnk" -Value "' + "`'" + $runfile + "`'" + '"; pause'
    #Start-Process -FilePath powershell.exe -ArgumentList $code -verb RunAs -WorkingDirectory C:
}


if($addStartup) {
    addStartup
    exit
}


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")

$form1 = New-Object System.Windows.Forms.form
$form1.ShowInTaskbar = $false
$form1.WindowState = "minimized"

$NotifyIcon= New-Object System.Windows.Forms.NotifyIcon
$ContextMenu = New-Object System.Windows.Forms.ContextMenu
$MenuItemExit = New-Object System.Windows.Forms.MenuItem
$MenuItemAddStart = New-Object System.Windows.Forms.MenuItem
$MenuItemRemStart = New-Object System.Windows.Forms.MenuItem
$MenuItemSigOn = New-Object System.Windows.Forms.MenuItem
$MenuItemSigOff = New-Object System.Windows.Forms.MenuItem
$MenuItemPause = New-Object System.Windows.Forms.MenuItem
$MenuItemFlagFile = New-Object System.Windows.Forms.MenuItem
$MenuItemSeperator1 = New-Object System.Windows.Forms.MenuItem
$MenuItemSeperator2 = New-Object System.Windows.Forms.MenuItem
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
    $NotifyIcon.Icon = "$scriptdir\lightbulb_on.ico"
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
    $NotifyIcon.Icon = "$scriptdir\lightbulb.ico"
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
        $MenuItemPause.Text = "Resume Watching"
    } else {
        $TimerCheckFile.Start()
        $MenuItemPause.Text = "Pause Watching"
    }
}

function setFlagFilePath(){
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Enter Path to Flag File'
    $form.Size = New-Object System.Drawing.Size(400,200)
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
    $label.Size = New-Object System.Drawing.Size(350,20)
    $label.Text = 'Please enter file to watch for to trigger the signal automatically:'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(340,20)
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

$MenuItemSeperator1.Text = "-"
$MenuItemSeperator2.Text = "-"

$MenuItemAddStart.Text = "Add to Startup (Scheduled Task)"
$MenuItemAddStart.add_Click({
    addStartup
})

$MenuItemRemStart.Text = "Remove from Startup (Scheduled Task)"
$MenuItemRemStart.add_Click({
    remStartup
})


$MenuItemExit.Text = "Exit"
$MenuItemExit.add_Click({
   $TimerCheckFile.stop()
   $NotifyIcon.Visible = $False
   $form1.close()
})


#$NotifyIcon.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)
$NotifyIcon.Icon = "$scriptdir\lightbulb.ico"
$NotifyIcon.ContextMenu = $ContextMenu
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSigOn)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSigOff)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemPause)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSeperator1)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemFlagFile)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemAddStart)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemRemStart)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemSeperator2)
$NotifyIcon.contextMenu.MenuItems.AddRange($MenuItemExit)
$NotifyIcon.Visible = $True

#doCheck
[void][System.Windows.Forms.Application]::Run($form1)






