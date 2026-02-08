###############################################################################
#  SVXlink UHF Amplifier Fan Contro module Coded by Dan Loranger (KG7PAR)
#  
#  
#
#  
#  
#
###############################################################################
#
# This is the namespace in which all functions and variables below will exist. 
# The name must match the configuration variable "NAME" in the [ModuleTcl] 
# section in the configuration file. The name may be changed but it must be 
# changed in both places.
#
###############################################################################
namespace eval TxFan {
	# Check if this module is loaded in the current logic core
	#
	if {![info exists CFG_ID]} {
		return;
	}
	#
	# Extract the module name from the current namespace
	#
	set module_name [namespace tail [namespace current]]
	
	
	# A convenience function for printing out info prefixed by the module name
	#
	#   msg - The message to print
	#
	proc printInfo {msg} {
		variable module_name
		puts "$msg"
	}
	 
	proc activateInit {} {
		
	}


	proc rptrOn {} {
		variable CFG_offlineCommand
		exec echo ' $CFG_offlineCommand 1#' > /usr/share/svxlink/orp_pty/ORP_FullDuplexLogic_Port1/dtmf_ctrl
	}
	# Places Repeater OnLine


	proc rptrOff {} {
		variable CFG_offlineCommand 
		exec echo '* $CFG_offlineCommand 0#' > /usr/share/svxlink/orp_pty/ORP_FullDuplexLogic_Port1/dtmf_ctrl
	}
	#Disables Repeater
	
	
	#variable CFG_offlineCommand
	variable CFG_MODE
	variable timer
	set timer 0
	variable Repeater_Online
	set Repeater_Online 1
	set Hysteresis_count 0
	proc main {} {
        variable CFG_MODE
		variable CFG_PTT_PATH_1
		variable CFG_PTT_PATH_2
		variable CFG_FAN_GPIO
		variable CFG_DELAY
		variable Hysteresis_count
		variable CFG_HYSTERESIS_TRIGGER
		variable timer
		variable Heatsink_temperature
		variable CFG_Heatsink_Setpoint
		variable CFG_Heatsink_Critical_Setpoint
		variable CFG_Transmitter_Online
		variable Repeater_Online
		switch $CFG_MODE {
			FOLLOW_PTT {
				if {[exec cat $CFG_PTT_PATH_1]}  { 
					#printInfo "Fan Enabled"
					set fp [open $CFG_FAN_GPIO w]
					puts $fp "1"
					close $fp
				} else {
					#printInfo "Fan disabled"
					set fp [open $CFG_FAN_GPIO w]
					puts $fp "0"
					close $fp
				}
			}
			COUNT_DOWN {
				set Heatsink_temperature [expr [expr [expr [expr [expr [exec cat /sys/bus/iio/devices/iio\:device0/in_voltage1_raw] * 4.88] / 10] - 50] * 1.8] + 32]
				if {$Repeater_Online == 1 && $Heatsink_temperature > $CFG_Heatsink_Critical_Setpoint} {
					#Heatsink temperature is greater than 100 Degrees Fahrenheit disable Repeater
					printInfo "CRITICAL HEATSINK TEMPERATURE EXCEEDED, REPEATER DISABLED"
					set Repeater_Online 0
					rptrOff
					
					
					


				} elseif {$Heatsink_temperature > $CFG_Heatsink_Setpoint} {
						printInfo "Heatsink: [format "%.1f" $Heatsink_temperature]"
						set fp [open $CFG_FAN_GPIO w]
						puts $fp "1"
						close $fp
						set timer $CFG_DELAY

				} elseif {$timer > 0 && [exec cat $CFG_PTT_PATH_1]} {
						set fp [open $CFG_FAN_GPIO w]
						puts $fp "1"
						close $fp
						set timer $CFG_DELAY
					# If Fan timer is already running any PTT activity resets the Fan Timer

				} elseif {[exec cat $CFG_PTT_PATH_1]} { 
					if {$Hysteresis_count < $CFG_HYSTERESIS_TRIGGER} {
						# Hysteresis not yet reached, increment the counter
						set Hysteresis_count [expr $Hysteresis_count+1] 
				    } else {
						# Hysteresis threshold reached ...
						# turn on the timer and reset the count down register
						set fp [open $CFG_FAN_GPIO w]
						puts $fp "1"
						close $fp
						set timer $CFG_DELAY

					}
				
				} else {
					# Clear the hysteresis timer
					set Hysteresis_count 0
							
					# work the fan
					if {$timer == 0} {
						#printInfo "Heatsink: $Heatsink_temperature"
						set fp [open $CFG_FAN_GPIO w]
						puts $fp "0"
						close $fp

						#bring repeater back online
						if {$Repeater_Online == 0} {
							set Repeater_Online 1
							rptrOn
						
						
						}

					} else {
						printInfo "UHF Amplifier Fan Timer: $timer"
						set timer [expr $timer-1]
					}
				}
			}
			default {
				printInfo "Unknown mode, supported options are COUNT_DOWN or FOLLOW_PTT"
			}
		}
	}
	
	
	
	# Executed when this module is being deactivated.
	#
	proc deactivateCleanup {} {
		printInfo "Module deactivated"
	}
	
	# check for new events
	proc check_for_alerts {} {
		main
	}
	
	append func $module_name "::check_for_alerts";
	Logic::addSecondTickSubscriber $func;
	
	# end of namespace
}
#
# This file has not been truncated
#