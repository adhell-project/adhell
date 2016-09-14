#!/bin/bash

##################################
## Script-Name: 	macht-sinn	##
## Type:			Script		##
## Creator:			Crosser		##
## License:	        GPLv3		##
##################################

#####################
## ~~ Variables ~~ ##
#####################

# Define, check an load config file
CONF='/etc/machtsinn/machtsinn.conf'

if [ -r "$CONF" ]; then
	. $CONF
else
	echo -e "ERROR: $CONF is not readable or non existant."
    clean_up
	exit 11
fi

# Set macht-sinn's version
SCRIPTVERSION='0.1.2.2'

# Insert first given argument into a variable
ARG="$1"

# Define temporary files
TMPHOSTS="$TMPDIR/hosts.tmp"
TMPAD="$TMPDIR/hosts_ad.tmp"
TMPORIG="$TMPDIR/hosts_orig.tmp"

# Set whitelist location
WHITELIST='/etc/machtsinn/whitelist.conf'

# Set lock-File location
LCKFILE="/var/lock/machtsinn.lck"

#####################
## ~~ Functions ~~ ##
#####################

##
# Set error messages
##

printerr_error() {
    echo "[$(date +%F,%T)] There was an error. Please check the logfile at $LOGFILE"
}

printerr_root() {
    echo "[$(date +%F,%T)] ERROR: macht-sinn needs root-privileges to work correctly." | tee -a $LOGFILE
}

printerr_lock() {
    echo "[$(date +%F,%T)] ERROR: Lockfile $LCKFILE existant since $(date -r $LCKFILE +%F,%T)." >> $LOGFILE
}

##
# Generate needed files
##

# Generate lockfile
gen_lock() {
	if [ ! -e "$LCKFILE" ]; then
        touch "$LCKFILE"
    fi
}

# Generate temporary files
gen_temps() {
	if [ -e "$TMPDIR" ]; then
		rm -r "$TMPDIR"
	fi
    
    if [ ! -e "$ADNAME" ]; then
        touch "$ADNAME"
    fi
    
	mkdir "$TMPDIR"
	touch "$TMPHOSTS" "$TMPAD" "$TMPORIG"
	
	grep -vi "^$ADIP" "$ADNAME" >> "$TMPORIG"
}

##
# Pre blacklist fetching
##

# Get amount of blocked domains before the script updates them
get_prev_linecounts() {
	HOSTORIGCOUNT=$(cat $TMPORIG | wc -l)
	PREVADNAMECOUNT=$(cat $ADNAME | wc -l)
	PREVCOUNT=$(($PREVADNAMECOUNT-$HOSTORIGCOUNT))
}

##
# Blacklist fetching
##

# Get all blacklists configured in the config file and filter them
get_blacklist() {
echo "[$(date +%F,%T)] Start getting blocklists." | tee -a $LOGFILE
	for URL in $ADURL
		do
			echo "[$(date +%F,%T)] Fetching $URL" >> $LOGFILE && wget -T "$GETMAXT" -qO- "$URL" | grep -E '^(127.0.0.1|0.0.0.0)' | sed -u 's/\r$//;s/#.*$//;s/^127.0.0.1/'"$ADIP"'/;s/^0.0.0.0/'"$ADIP"'/;/^.*local$/d;/^.*localdomain$/d;/^.*localhost$/d;s/\s\{1,\}/ /' >> "$TMPHOSTS"
		done
}

# Generate the new blocklist file
gen_new_hostfile() {
    # Echo progress
    echo "[$(date +%F,%T)] Generating local files" >> $LOGFILE

	# Copy current hostfile
	cat "$TMPORIG" >> "$TMPAD"

	# Sort AD-List and remove whitelisted domains
    if [ -s "$WHITELIST" ]; then
        if [ -r "$WHITELIST" ]; then
            sort "$TMPHOSTS" | uniq -u | grep -vi -f "$WHITELIST" >> "$TMPAD"
        else
            echo "[$(date +%F,%T)] WARNING: Whitelist file $WHITELIST is not readable." | tee -a $LOGFILE
        fi
    else
        echo "[$(date +%F,%T)] WARNING: Whitelist file $WHITELIST is non existant or empty." | tee -a $LOGFILE
	    sort "$TMPHOSTS" | uniq -u >> "$TMPAD"
    fi

	# Overwrite current AD-List
	if [ -e "$ADNAME" ]; then
		rm "$ADNAME"
	fi
	mv "$TMPAD" "$ADNAME"
}

##
# Post blacklist fetching
##

# Get amount of blocked domains after the script updated them
get_curr_linecounts() {
	CURADNAMECOUNT=$(cat $ADNAME | wc -l)
	CURCOUNT=$((CURADNAMECOUNT-HOSTORIGCOUNT))
}

# Delete obsolete files
clean_up() {
	if [ -e "$TMPDIR" ]; then
		rm -r "$TMPDIR"
	fi
	
	if [ -e "$LCKFILE" ]; then
		rm "$LCKFILE"
fi
}

##
# User actions
##

# Remove all blocked hosts from the blocklist file
remove_adhosts() {
    # Echo progress
    echo "[$(date +%F,%T)] Removing blocked hosts" | tee -a $LOGFILE

    # Check and move blank hosts-file to "$ADNAME"
    if [ -s "$ADNAME" ]; then
        if [ -s "$TMPORIG" ]; then
            rm "$ADNAME"
            mv "$TMPORIG" "$ADNAME"
        else
            echo "[$(date +%F,%T)] ERROR: $ADNAME is empty, please check the \""'$ADNAME'"\" variable in $CONF!" >> $LOGFILE
            printerr_error
            clean_up
            exit 33
        fi
    else
        echo "[$(date +%F,%T)] ERROR: $ADNAME is empty, nothing to remove." >> $LOGFILE
        printerr_error
        clean_up
        exit 33
    fi
}

##
# Generate some prompts
##

# Show the help prompt
showhelp() {
	echo 'This script generates a Blacklist for ad- and malwareblocking.'
	echo 'Since this script needs write-access to $ADNAME, root-privileges are likely necessary.'
	echo 'Usage: machtsinn.sh {option}'
	echo '  -g || --generate    Start to generate the Blacklist in $ADNAME'
    echo '  -r || --remove      Remove all blocked hosts in $ADNAME'
    echo '  -c || --clean       Manually start cleaning after the script aborted. Use at your own Risk!'
	echo '  -v || --version     Print the version'
	echo '  -h || --help        Print this message'
}

# Show the error prompt
showerror() {
	echo "ERROR: \"$ARG\" is no valid argument."
}

# Show the version prompt
showversion() {
	echo "macht-sinn version $SCRIPTVERSION, ergibt das Sinn?"' ¯\_(ツ)_/¯'
	echo 'A true open-source ad-blocking alternative for browser-plugins and other misterious stuff.'
}

# Show previous and current amount of blocked domains
showblocked() {
    echo "[$(date +%F,%T)] Now blocking $CURCOUNT Domains. Previously $PREVCOUNT." | tee -a $LOGFILE   
}

#####################
## ~~ Execution ~~ ##
#####################

##
# Check which commmand should get executed and do so
##

# Option "--generate || -g"
if [ "$ARG" == "--generate" ] || [ "$ARG" == "-g" ]; then
	if [ ! -e "$LCKFILE" ]; then
		if [ "$(id -u)" != "0" ]; then
            printerr_root
            exit 55
		else
			gen_lock
			gen_temps
			get_prev_linecounts
			get_blacklist
			gen_new_hostfile
			get_curr_linecounts
			clean_up
            showblocked
		fi
	else
        printerr_lock
        printerr_error
        exit 44
	fi
# Option "--remove || -r"
elif [ "$ARG" == "--remove" ] || [ "$ARG" == "-r" ]; then
    if [ ! -e "$LCKFILE" ]; then
        if [ "$(id -u)" != "0" ]; then
            printerr_root
            exit 55
        else
            gen_lock
            gen_temps
            get_prev_linecounts
            remove_adhosts
            get_curr_linecounts
            clean_up
            showblocked
        fi
    else
        printerr_lock
        printerr_error
        exit 44
    fi
# Option "--clean || -c"
elif [ "$ARG" == "--clean" ] || [ "$ARG" == "-c" ]; then
    if [ "$(id -u)" != "0" ]; then
        printerr_root
        exit 55
    else
        clean_up
    fi
# Option "--version || -v"
elif [ "$ARG" == "--version" ] || [ "$ARG" == "-v" ]; then
	showversion
# Option "--help || -h"
elif [ "$ARG" == "--help" ] || [ "$ARG" == "-h" ] || [ -z "$ARG" ]; then
	showhelp
else
	showerror
	showhelp
    exit 22
fi

exit 0
