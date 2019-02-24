# Batsignal
# Use CircuitPython on an Adafruit Trinket M0 or other similar board to turn a lamp on and off
#---------------------------------------------------------------------------------------------
# Copyright: 2019 - Michael Lehman (drakoswraith@gmail.com)
# Released under the MIT license. 
# https://github.com/drakoswraith/batsignal
#---------------------------------------------------------------------------------------------
# Basic circuit consists of:
#   a momentary push button
#       - pulled high
#       - on pin 3, and connected to ground
#
#   an HBridge (eg L293D)
#       - wire the enable to 3.3V with a 10k resister
#       - The PWM input on the chip is wired to pin 2 of the trinket
#       - H-Bridge output of course goes to the positive lead of the LED/motor/etc..
# 
# 
# Lamp (or motor, or whatever...) can be toggled via either a button on D3
# Or by updating the modified time on either /signalon.txt or /signaloff.txt 
# on the root of the filesystem of the trinket
#
# By using the mechanism of saving to signalon.txt and signaloff.txt, it is easy to integrate this into software running
# on the host computer, without having to write complex USB commands, etc...
# This sytem works because the computer is able to write tothe USB storage, and the trinket
# can read from the storage, but not write to it
# As time marches ever forward, tracking the modified timestamp of the files gives a clear
# method of toggling the given command.
# The contents of the file do not matter for this method, although it would be trivial to add
# additional info that way (maybe set dotstar color, etc...)
#---------------------------------------------------------------------------------------------

import board
import pulseio
import digitalio
import adafruit_dotstar as dotstar
import time
import os
import supervisor


def getOnMTime():
    files = os.listdir()
    for f in files:
        if f.lower() == 'signalon.txt':
            # See the python 3.0 os.stat docs for the structure description
            #7 = access time, 8 = modified time, 9 = creation or metadata time
            return os.stat(f)[8]     
    return 0   

def getOffMTime():
    files = os.listdir()
    for f in files:
        if f.lower() == 'signaloff.txt':
            return os.stat(f)[8]     
    return 0  

# we need to disable auto-reload of the scripts to avoid the script
# restarting and losing our state when signalon.txt and signaloff.txt are modified
supervisor.disable_autoreload() 

dot = dotstar.DotStar(board.APA102_SCK, board.APA102_MOSI, 1, brightness=0.05)

pwmLamp = pulseio.PWMOut(board.D2)
pwmLamp.duty_cycle = 0 

btnToggle = digitalio.DigitalInOut(board.D3)
btnToggle.direction = digitalio.Direction.INPUT
btnToggle.pull = digitalio.Pull.UP

signalState = False
fileOnModTime = getOnMTime()
fileOffModTime = getOffMTime()
    
while True:
    if not signalState:
        if getOnMTime() > fileOnModTime:
            signalState = True
            fileOnModTime = getOnMTime()
            fileOffModTime = fileOnModTime

    if signalState:
        if getOffMTime() > fileOffModTime:
            signalState = False
            fileOffModTime = getOffMTime()
            fileOnModTime = fileOffModTime

    toggled = False
    #pullup flips the logic
    if not btnToggle.value:
        print("Button toggled")
        signalState = not signalState
        fileOnModTime = getOnMTime()
        fileOffModTime = getOffMTime()
        toggled = True

    if signalState:
        dot[0] = [0, 50, 100]
        pwmLamp.duty_cycle = 65535      #Lower this value to reduce brightness/current draw
    else:
        dot[0] = [0, 0, 0]
        pwmLamp.duty_cycle = 0
        

    #wait till button released to avoid flipping on and off
    if toggled:
        while not btnToggle.value:
            time.sleep(0.05)
    time.sleep(0.1)

