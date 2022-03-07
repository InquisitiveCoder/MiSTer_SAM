#!/bin/bash

# https://github.com/mrchrisster/MiSTer_SAM/
# Copyright (c) 2021 by mrchrisster and Mellified

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

## Description
# This cycles through arcade and console cores periodically
# Games are randomly pulled from their respective folders

# ======== Credits ========
# Original concept and implementation by: mrchrisster
# Additional development by: Mellified
#
# Thanks for the contributions and support:
# pocomane, kaloun34, redsteakraw, RetroDriven, woelper, LamerDeluxe, InquisitiveCoder


#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/media/fat/linux:/media/fat/Scripts:/media/fat/Scripts/.MiSTer_SAM:.

#======== INI VARIABLES ========
# Change these in the INI file

#======== GLOBAL VARIABLES =========
declare -g mrsampath="/media/fat/Scripts/.MiSTer_SAM"
declare -g misterpath="/media/fat"
# Save our PID and process
declare -g sampid="${$}"
declare -g samprocess="$(basename -- ${0})"

#======== DEBUG VARIABLES ========
samquiet="Yes"
samdebug="No"
samtrace="No"

#======== LOCAL VARIABLES ========
gametimer=120
listenmouse="Yes"
listenkeyboard="Yes"
listenjoy="Yes"
repository_url="https://github.com/InquisitiveCoder/MiSTer_SAM"
branch="main"

# ======== TTY2OLED =======
ttyenable="No"
ttydevice="/dev/ttyUSB0"

#======== CORE PATHS ========
arcadepath="/media/fat/_Arcade"
consolepath="/media/fat/_Console/MiSTer_SAM"

#========= PARSE INI =========
# Read INI
if [ -f "${misterpath}/Scripts/MiSTer_SAM.ini" ]; then
	source "${misterpath}/Scripts/MiSTer_SAM.ini"
fi

#======== SAM MENU ========
function sam_premenu() {
	echo "+---------------------------+"
	echo "| MiSTer Super Attract Mode |"
	echo "+---------------------------+"
	echo " SAM Configuration:"
	if [ -f /etc/init.d/S93mistersam ]; then
		echo " -SAM autoplay ENABLED"
	else
		echo " -SAM autoplay DISABLED"
	fi
	echo " -Start after ${samtimeout} sec. idle"
	echo " -Start only on the menu: ${menuonly^}"
	echo " -Show each game for ${gametimer} sec."
	echo "" 
	echo " Press UP to open menu"
	echo " Press DOWN to start SAM"
	echo ""	
	echo " Or wait for"
	echo " auto-configuration"
	echo ""

	for i in {10..1}; do
		echo -ne " Updating SAM in ${i}...\033[0K\r"
		premenu="Default"
		read -r -s -N 1 -t 1 key
		if [[ "${key}" == "A" ]]; then
			premenu="Menu"
			break
		elif [[ "${key}" == "B" ]]; then
			premenu="Start"
			break
		elif [[ "${key}" == "C" ]]; then
			premenu="Default"
			break
		fi
	done
	parse_cmd ${premenu}
}

function sam_menu() {
	dialog --clear --no-cancel --ascii-lines --no-tags \
	--backtitle "Super Attract Mode" --title "[ Main Menu ]" \
	--menu "Use the arrow keys and enter \nor the d-pad and A button" 0 0 0 \
	Start "Start SAM now" \
	Skip "Skip game (ssh only)" \
	Stop "Stop SAM (ssh only)" \
	Single "Games from only one core" \
	Utility "Update and Monitor" \
	Config "Configure INI Settings" \
	Autoplay "Autoplay Configuration" \
	Cancel "Exit now" 2>"/tmp/.SAMmenu"
	menuresponse=$(<"/tmp/.SAMmenu")
	clear
	
	if [ "${samquiet,,}" == "no" ]; then echo " menuresponse: ${menuresponse}"; fi
	parse_cmd ${menuresponse}
}

function sam_utilitymenu() {
	dialog --clear --no-cancel --ascii-lines --no-tags \
	--backtitle "Super Attract Mode" --title "[ Utilities ]" \
	--menu "Select an option" 0 0 0 \
	Update "Update SAM to latest" \
	Monitor "Display messages (ssh only)" \
	Back 'Previous menu' 2>"/tmp/.SAMmenu"
	menuresponse=$(<"/tmp/.SAMmenu")
	clear
	
	if [ "${samquiet,,}" == "no" ]; then echo " menuresponse: ${menuresponse}"; fi
	parse_cmd ${menuresponse}
}

function sam_autoplaymenu() {
	dialog --clear --no-cancel --ascii-lines --no-tags \
	--backtitle "Super Attract Mode" --title "[ Configure Autoplay ]" \
	--menu "Select an option" 0 0 0 \
	Enable "Enable Autoplay" \
	Disable "Disable Autoplay" \
	Back 'Previous menu' 2>"/tmp/.SAMmenu"
	menuresponse=$(<"/tmp/.SAMmenu")
	
	clear
	if [ "${samquiet,,}" == "no" ]; then echo " menuresponse: ${menuresponse}"; fi
	parse_cmd ${menuresponse}
}

function sam_configmenu() {
	dialog --clear --ascii-lines --no-cancel \
	--backtitle "Super Attract Mode" --title "[ INI Settings ]" \
	--msgbox "Here you can configure the INI settings for SAM.\n\nUse TAB to switch between editing, the OK and Cancel buttons." 0 0
	
	dialog --clear --ascii-lines \
	--backtitle "Super Attract Mode" --title "[ INI Settings ]" \
	--editbox "${misterpath}/Scripts/MiSTer_SAM.ini" 0 0 2>"/tmp/.SAMmenu"
	
	if [ -s "/tmp/.SAMmenu" ] && [ "$(diff -wq "/tmp/.SAMmenu" "${misterpath}/Scripts/MiSTer_SAM.ini")" ]; then
		cp -f "/tmp/.SAMmenu" "${misterpath}/Scripts/MiSTer_SAM.ini"
		dialog --clear --ascii-lines --no-cancel \
		--backtitle "Super Attract Mode" --title "[ INI Settings ]" \
		--msgbox "Changes saved!" 0 0
	fi
	
	parse_cmd menu
}

function parse_cmd() {
	if [ ${#} -gt 2 ]; then # We don't accept more than 2 parameters
		sam_help
	elif [ ${#} -eq 0 ]; then # No options - show the pre-menu
		sam_premenu
	else
		while [ ${#} -gt 0 ]; do
			case ${1,,} in
				default) # Default is split because sam_update relaunches itself
					sam_update defaultb
					break
					;;
				defaultb)
					sam_update
					sam_enable quickstart
					sam_start
					break
					;;
				start) # Start SAM immediately
					env_check ${1,,}
					tty_init
					sam_start
					pre_exit
					break
					;;
				skip | next) # Load next game - doesn't interrupt loop if running
					echo " Skipping to next game..."
					env_check ${1,,}
					tty_init
					next_core
					break
					;;
				stop) # Stop SAM immediately
					there_can_be_only_one
					echo " Thanks for playing!"
					pre_exit
					break
					;;
				update) # Update SAM
					sam_update
					break
					;;
				enable) # Enable SAM autoplay mode
					env_check ${1,,}
					sam_enable quickstart
					break
					;;
				disable) # Disable SAM autoplay
					sam_disable
					break
					;;
				monitor) # Attach output to terminal
					sam_monitor
					break
					;;
				utility)
					sam_utilitymenu
					break
					;;
				autoplay)
					sam_autoplaymenu
					break
					;;
				config)
					sam_configmenu
					break
					;;
				back)
					sam_menu
					break
					;;
				menu)
					sam_menu
					break
					;;
				cancel) # Exit
					echo " It's pitch dark; You are likely to be eaten by a Grue."
					break
					;;
				help)
					sam_help
					break
					;;
				*)
					echo " ERROR! ${1} is unknown."
					echo " Try $(basename -- ${0}) help"
					echo " Or check the Github readme."
					break
					;;
			esac
			shift
		done
	fi
}


#======== SAM COMMANDS ========
function sam_start() { # sam_start (core)
	# Terminate any other running SAM processes
	there_can_be_only_one
	
	# If the MCP isn't running we need to start it in monitoring only mode
	if [ -z "$(pidof MiSTer_SAM_MCP)" ]; then
		${mrsampath}/MiSTer_SAM_MCP monitoronly &
	fi
	
	# Start SAM looping through cores and games
	loop_core ${1}
}
	
function sam_update() { # sam_update (next command)
	# Ensure the MiSTer SAM data directory exists
	mkdir --parents "${mrsampath}" &>/dev/null
	
	# Prep curl
	curl_check
	
	if [ ! "$(dirname -- ${0})" == "/tmp" ]; then
		# Warn if using non-default branch for updates
		if [ ! "${branch}" == "main" ]; then
			echo ""
			echo "*******************************"
			echo " Updating from ${branch}"
			echo "*******************************"
			echo ""
		fi
		
		# Download the newest MiSTer_SAM_on.sh to /tmp
		get_samstuff MiSTer_SAM_on.sh /tmp
		if [ -f /tmp/MiSTer_SAM_on.sh ]; then
			if [ ${1} ]; then
				echo " Continuing setup with latest"
				echo " MiSTer_SAM_on.sh..."
				/tmp/MiSTer_SAM_on.sh ${1}
				exit 0
			else
				echo " Launching latest"
				echo " MiSTer_SAM_on.sh..."
				/tmp/MiSTer_SAM_on.sh update
			exit 0
			fi
		else
			# /tmp/MiSTer_SAM_on.sh isn't there!
	  	echo " SAM update FAILED"
	  	echo " No Internet?"
	  	exit 1
		fi
	else # We're running from /tmp - download dependencies and proceed
		cp --force "/tmp/MiSTer_SAM_on.sh" "/media/fat/Scripts/MiSTer_SAM_on.sh"
		get_samstuff .MiSTer_SAM/MiSTer_SAM_init
		get_samstuff .MiSTer_SAM/MiSTer_SAM_MCP
		get_samstuff .MiSTer_SAM/MiSTer_SAM_joy.py
		get_samstuff .MiSTer_SAM/MiSTer_SAM_keyboard.sh
		get_samstuff .MiSTer_SAM/MiSTer_SAM_mouse.sh
		get_samstuff MiSTer_SAM_off.sh /media/fat/Scripts
		
		if [ -f /media/fat/Scripts/MiSTer_SAM.ini ]; then
			echo " MiSTer SAM INI already exists... SKIPPED!"
		else
			get_samstuff MiSTer_SAM.ini /media/fat/Scripts
		fi
	fi	
	echo " Update complete!"
	return
}

function sam_enable() { # Enable autoplay
	echo -n " Enabling MiSTer SAM Autoplay..."
	# Remount root as read-write if read-only so we can add our daemon
	mount | grep "on / .*[(,]ro[,$]" -q && RO_ROOT="true"
	[ "$RO_ROOT" == "true" ] && mount / -o remount,rw

	# Awaken daemon
	cp -f "${mrsampath}/MiSTer_SAM_init" /etc/init.d/_S93mistersam &>/dev/null
	mv -f /etc/init.d/_S93mistersam /etc/init.d/S93mistersam &>/dev/null
	chmod +x /etc/init.d/S93mistersam

	# Remove read-write if we were read-only
	sync
	[ "$RO_ROOT" == "true" ] && mount / -o remount,ro
	sync
	echo " Done!"

	echo -n " SAM autoplay daemon starting..."

	if [ "${1,,}" == "quickstart" ]; then
		/etc/init.d/S93mistersam quickstart &
	else
		/etc/init.d/S93mistersam start &
	fi

	echo " Done!"
	return
}

function sam_disable() { # Disable autoplay
	echo -n " Disabling SAM autoplay..."
	# Clean out existing processes to ensure we can update
	there_can_be_only_one
	killall -q -9 S93mistersam
	killall -q -9 MiSTer_SAM_MCP
	killall -q -9 MiSTer_SAM_mouse.sh
	killall -q -9 MiSTer_SAM_keyboard.sh
	killall -q -9 xxd
	kill -9 $(ps | grep "inotifywait" | grep "SAM_Joy_Change" | cut --fields=2 --only-delimited --delimiter=' ')

	mount | grep -q "on / .*[(,]ro[,$]" && RO_ROOT="true"
	[ "$RO_ROOT" == "true" ] && mount / -o remount,rw
	rm -f /etc/init.d/S93mistersam > /dev/null 2>&1
	sync
	[ "$RO_ROOT" == "true" ] && mount / -o remount,ro
	sync
	echo " Done!"
}

function sam_help() { # sam_help
	echo " start - start immediately"
	echo " skip - skip to the next game"
	echo " stop - stop immediately"
	echo ""
	echo " update - self-update"
	echo " monitor - monitor SAM output"
	echo ""
	echo " enable - enable autoplay"
	echo " disable - disable autoplay"
	echo ""
	echo " menu - load to menu"
	echo ""
	echo " arcade, genesis, gba..."
	echo " games from one system only"
	exit 2
}

#======== UTILITY FUNCTIONS ========
function there_can_be_only_one() { # there_can_be_only_one
	# If another attract process is running kill it
	# This can happen if the script is started multiple times
	echo -n " Stopping other running instances of ${samprocess}..."
	kill -9 $(pidof -o ${sampid} ${samprocess}) &>/dev/null
	wait $(pidof -o ${sampid} ${samprocess}) &>/dev/null
	echo " Done!"
}

function env_check() {
	# Check if we've been installed
	if [ ! -f "${mrsampath}/MiSTer_SAM_MCP" ]; then
		echo " SAM required files not found."
		echo " Surprised? Check your INI."
		sam_update ${1}
		echo " Setup complete."
	fi
}

function tty_init() { # tty_init
	# tty2oled initialization
	if [ "${ttyenable,,}" == "yes" ]; then
		#echo " Stopping tty2oled daemon..."
		#/etc/init.d/S60tty2oled stop
		#echo " Done!"
		
		echo "CMDCLS" > "${ttydevice}"
		echo "CMDTXT,0,1,0,9, Welcome to..." > "${ttydevice}"
		sleep 0.2
		echo "CMDCLS" > "${ttydevice}"
		echo "CMDTXT,0,1,0,9, Welcome to..." > "${ttydevice}"
		sleep 0.2
		echo "CMDCLS" > "${ttydevice}"
		echo "CMDTXT,0,1,0,9, Welcome to..." > "${ttydevice}"
		sleep 0.2
		echo "CMDTXT,2,1,47,27,  Super" > "${ttydevice}"
		sleep 0.2
		echo "CMDTXT,2,1,47,45,      Attract" > "${ttydevice}"
		sleep 0.2
		echo "CMDTXT,2,1,47,61,          Mode!" > "${ttydevice}"
	fi
}

function tty_update() { # tty_update core game
	if [ "${ttyenable,,}" == "yes" ]; then
		# Wait for tty2oled daemon to show the core logo
		inotifywait -e modify /tmp/CORENAME
		sleep 10
		
		# Transition effect
		echo "CMDGEO,8,1,126,30,31,15,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,1,126,30,63,31,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,1,126,30,127,63,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,1,126,30,255,127,0" > "${ttydevice}"
		sleep 0.2
		echo "CMDGEO,8,0,126,30,31,15,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,0,126,30,63,31,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,0,126,30,127,63,0" > "${ttydevice}"
		sleep 0.2                                        
		echo "CMDGEO,8,0,126,30,255,127,0" > "${ttydevice}"
		sleep 0.2                                        
		
		# Split long lines - length is approximate since fonts are variable width!
		if [ ${#2} -gt 23 ]; then
			echo "CMDTXT,2,1,0,20,${2:0:20}..." > "${ttydevice}"
			echo "CMDTXT,2,1,0,40, ${2:20}" > "${ttydevice}"
		else
			echo "CMDTXT,2,1,0,20,${2}" > "${ttydevice}"
		fi
		echo "CMDTXT,1,1,0,60,on ${1}" > "${ttydevice}"
	fi
}

function pre_exit() { # pre_exit
	#if [ "${usetty,,}" == "yes" ]; then /etc/init.d/S60tty2oled start; fi
	echo
}


#======== DOWNLOAD FUNCTIONS ========
function curl_check() {
	ALLOW_INSECURE_SSL="true"
	SSL_SECURITY_OPTION=""
	curl --connect-timeout 15 --max-time 600 --retry 3 --retry-delay 5 \
	 --silent --show-error "https://github.com" > /dev/null 2>&1
	case $? in
		0)
			;;
		60)
			if [[ "${ALLOW_INSECURE_SSL}" == "true" ]]
			then
				declare -g SSL_SECURITY_OPTION="--insecure"
			else
				echo "CA certificates need"
				echo "to be fixed for"
				echo "using SSL certificate"
				echo "verification."
				echo "Please fix them i.e."
				echo "using security_fixes.sh"
				exit 2
			fi
			;;
		*)
			echo "No Internet connection"
			exit 1
			;;
	esac
	set -e
}

function curl_download() { # curl_download ${filepath} ${URL}
		curl \
			--connect-timeout 15 --max-time 600 --retry 3 --retry-delay 5 --silent --show-error \
			${SSL_SECURITY_OPTION} \
			--fail \
			--location \
			-o "${1}" \
			"${2}"
}


#======== UPDATER FUNCTIONS ========
function get_samstuff() { #get_samstuff file (path)
	if [ -z "${1}" ]; then
		return 1
	fi
	
	filepath="${2}"
	if [ -z "${filepath}" ]; then
		filepath="${mrsampath}"
	fi

	echo -n " Downloading from ${repository_url}/blob/${branch}/${1} to ${filepath}/..."
	curl_download "/tmp/${1##*/}" "${repository_url}/blob/${branch}/${1}?raw=true"

	if [ ! "${filepath}" == "/tmp" ]; then
		mv --force "/tmp/${1##*/}" "${filepath}/${1##*/}"
	fi

	if [ "${1##*.}" == "sh" ]; then
		chmod +x "${filepath}/${1##*/}"
	fi
	
	echo " Done!"
}


#========= SAM MONITOR =========
function sam_monitor() {
	
	PID=$(ps aux |grep MiSTer_SAM_on.sh |grep -v grep |awk '{print $1}' | head -n 1)

	if [ $PID ]; then
		echo -n " Attaching MiSTer SAM to current shell..."
		THIS=$0
		ARGS=$@
		name=$(basename $THIS)
		quiet="no"
		nopt=""
		shift $((OPTIND-1))
		fds=""
		
		if [ -n "$nopt" ]; then
			for n_f in $nopt; do
			n=${n_f%%:*}
			f=${n_f##*:}
			if [ -n "${n//[0-9]/}" ] || [ -z "$f" ]; then 
				warn "Error parsing descriptor (-n $n_f)"
				exit 1
			fi

			if ! 2>/dev/null : >> $f; then
				warn "Cannot write to (-n $n_f) $f"
				exit 1
			fi
			fds="$fds $n"
			fns[$n]=$f
			done
		fi
		
		if [ -z "$stdout" ] && [ -z "$stderr" ] && [ -z "$stdin" ] && [ -z "$nopt" ]; then
			#second invocation form: dup to my own in/err/out
			[ -e /proc/$$/fd/0 ] &&  stdin=$(readlink /proc/$$/fd/0)
			[ -e /proc/$$/fd/1 ] && stdout=$(readlink /proc/$$/fd/1)
			[ -e /proc/$$/fd/2 ] && stderr=$(readlink /proc/$$/fd/2)
			if [ -z "$stdout" ] && [ -z "$stderr" ] && [ -z "$stdin" ]; then
			warn "Could not determine current standard in/out/err"
			exit 1
			fi
		fi
		
	
		gdb_cmds() {
			local _name=$1
			local _mode=$2
			local _desc=$3
			local _msgs=$4
			local _len
	
			[ -w "/proc/$PID/fd/$_desc" ] || _msgs=""
			if [ -d "/proc/$PID/fd" ] && ! [ -e "/proc/$PID/fd/$_desc" ]; then
			warn "Attempting to remap non-existent fd $n of PID ($PID)"
			fi
	
			[ -z "$_name" ] && return
	
			echo "set \$fd=open(\"$_name\", $_mode)"
			echo "set \$xd=dup($_desc)"
			echo "call dup2(\$fd, $_desc)"
			echo "call close(\$fd)"

			if  [ $((_mode & 3)) ] && [ -n "$_msgs" ]; then
				_len=$(echo -en "$_msgs" | wc -c)
				echo "call write(\$xd, \"$_msgs\", $_len)"
			fi

			echo "call close(\$xd)"
		}
	
		trap '/bin/rm -f $GDBCMD' EXIT
		GDBCMD=$(mktemp /tmp/gdbcmd.XXXX)
		{
			#Linux file flags (from /usr/include/bits/fcntl.sh)
			O_RDONLY=00
			O_WRONLY=01
			O_RDWR=02 
			O_CREAT=0100
			O_APPEND=02000
			echo "#gdb script generated by running '$0 $ARGS'"
			echo "attach $PID"
			gdb_cmds "$stdin"  $((O_RDONLY)) 0 "$msg_stdin"
			gdb_cmds "$stdout" $((O_WRONLY|O_CREAT|O_APPEND)) 1 "$msg_stdout"
			gdb_cmds "$stderr" $((O_WRONLY|O_CREAT|O_APPEND)) 2 "$msg_stderr"

			for n in $fds; do
				msg="Descriptor $n of $PID is remapped to ${fns[$n]}\n"
				gdb_cmds ${fns[$n]} $((O_RDWR|O_CREAT|O_APPEND)) $n "$msg"
			done
			#echo "quit"
		} > $GDBCMD
	
		if gdb -batch -n -x $GDBCMD >/dev/null </dev/null; then
			[ "$quiet" != "yes" ] && echo " Done!" >&2
		else
			warn " Failed!"
		fi
		
		#cp $GDBCMD /tmp/gdbcmd
		rm -f $GDBCMD
	else
		echo " Couldn't detect MiSTer_SAM_on.sh running"
	fi
}


# ======== SAM OPERATIONAL FUNCTIONS ========
function loop_core() { # loop_core
	echo " Let Mortal Kombat begin!"
	# Reset game log for this session
	echo "" |> /tmp/SAM_Games.log
	
	while :; do
		counter=${gametimer}

		next_core
		while [ ${counter} -gt 0 ]; do
			echo -ne " Next game in ${counter}...\033[0K\r"
			sleep 1
			((counter--))
			
			if [ -s /tmp/.SAM_Mouse_Activity ]; then
				if [ "${listenmouse,,}" == "yes" ]; then
					echo " Mouse activity detected!"
					exit
				else
					echo " Mouse activity ignored!"
					echo "" |>/tmp/.SAM_Mouse_Activity
				fi
			fi
			
			if [ -s /tmp/.SAM_Keyboard_Activity ]; then
				if [ "${listenkeyboard,,}" == "yes" ]; then
					echo " Keyboard activity detected!"
					exit
				else
					echo " Keyboard activity ignored!"
					echo "" |>/tmp/.SAM_Keyboard_Activity
				fi
			fi
			
			if [ -s /tmp/.SAM_Joy_Activity ]; then
				if [ "${listenjoy,,}" == "yes" ]; then
					echo " Controller activity detected!"
					exit
				else
					echo " Controller activity ignored!"
					echo "" |>/tmp/.SAM_Joy_Activity
				fi
			fi
		done
		echo
	done
}

function next_core() { # next_core
	local previous=${rompath}
	rompath=$({ find "${arcadepath}" -type f -name '*.mra' -not -path "${previous}"; \
		find "${consolepath}" -type f -name '*.mgl' -not -path "${previous}"; } \
		| shuf --head-count=1 --random-source=/dev/urandom)

	if [[ -z ${rompath} ]]; then
		echo " ERROR: No MRA files found in ${arcadepath} and no MGL files found in ${consolepath}" >&2
		exit 1
	fi

	local nextcore=$(parse_console "${rompath}")
	local romname=$(basename "${rompath}")

	if [[ ${samquiet,,} == no ]]; then
		echo " Shuffle result:"
		echo " * ${romname%.*}"
	fi

	if [[ -f ${rompath}.sam ]]; then
		source "${rompath}.sam"
	fi

	load_core "${nextcore:-MiSTer Arcade}" "${rompath}" "${romname%.*}" "${countdown}"
}

function load_core() { # load_core core /path/to/rom name_of_rom (countdown)
	echo -n " Starting now on the "
	echo -ne "\e[4m${1}\e[0m: "
	echo -e "\e[1m${3}\e[0m"
	echo "$(date +%H:%M:%S) - ${1} - ${3}" >> /tmp/SAM_Games.log
	echo "${3} (${1})" > /tmp/SAM_Game.txt
	tty_update "${1}" "${3}" &

	if [ "${4}" == "countdown" ]; then
		for i in {5..1}; do
			echo -ne " Loading game in ${i}...\033[0K\r"
			sleep 1
		done
	fi

	echo "load_core ${2}" >/dev/MiSTer_cmd
	sleep 1
	echo "" |>/tmp/.SAM_Joy_Activity
	echo "" |>/tmp/.SAM_Mouse_Activity
	echo "" |>/tmp/.SAM_Keyboard_Activity
}

function parse_console() { # parse_console rompath (
	if [[ ${1} == *.mgl ]]; then
		local tagname="rbf"
	else
		local tagname="platform"
	fi
	# Parse the contents of the rbf element to find the console.
	# This read loop assumes the element of interest has no attributes or child elements.
	local tag content
	while IFS=\> read -d\< tag content && [[ ${tag} != ${tagname} ]]; do true; done <"${1}"
	echo $(basename "${content}")
}

#========= MAIN =========
#======== DEBUG OUTPUT =========
if [ "${samtrace,,}" == "yes" ]; then
	echo " ********************************************************************************"
	#======== GLOBAL VARIABLES =========
	echo " mrsampath: ${mrsampath}"
	echo " misterpath: ${misterpath}"
	echo " sampid: ${sampid}"
	echo " samprocess: ${samprocess}"
	echo ""
	#======== LOCAL VARIABLES ========
	echo " commandline: ${@}"
	echo " repository_url: ${repository_url}"
	echo " branch: ${branch}"
	echo ""
	echo " gametimer: ${gametimer}"
	echo " listenmouse: ${listenmouse}"
	echo " listenkeyboard: ${listenkeyboard}"
	echo " listenjoy: ${listenjoy}"
	echo ""
	echo " arcadepath: ${arcadepath}"
	echo " consolepath: ${consolepath}"
	echo " ********************************************************************************"
	read -p " Continuing in 5 seconds or press any key..." -n 1 -t 5 -r -s
fi	

parse_cmd ${@}	# Parse command line parameters for input
pre_exit				# Shutdown routine	
exit
