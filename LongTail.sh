#!/bin/sh 

############################################################################
# This is my crontab entry
# 59 * * * * /usr/local/etc/analyze_messages.sh >> /tmp/analyze_messages.sh.out 2>> /tmp/analyze_messages.sh.out
#
# You need to have /usr/local/etc/whois.pl installed also.  Sure, I could 
# have a faster mysql backend, but I don't NEED it.
#
# I am assuming your /var/log/messages file is really called messages, or 
# messages<something>.  .gz files are ok too.
#
# I am assuming your /var/log/httpd/access_file file is really called 
# access_file, or access_file<something>.  .gz files are ok too.
#
############################################################################
# Assorted Variables
# Do we obfuscate/rename the IP addresses?  You might want to do this if
# you are copying your reports to a public site.
# OBFUSCATE_IP_ADDRESSES=1 will hide addresses
# OBFUSCATE_IP_ADDRESSES=0 will NOT hide addresses
OBFUSCATE_IP_ADDRESSES=0
OBFUSCATE_URLS=0

# These are the search strings from the "LogIt" function in auth-passwd.c
# and are used to figure out which ports are being brute-forced.
# This code has not yet been written.
PASSLOG="PassLog"
PASSLOG2222="Pass2222Log"

# Where are the scripts we need to run?
SCRIPT_DIR="/usr/local/etc/"

# Where do we put the reports?
HTML_DIR="/var/www/html/honey/"

#Where is the messages file?
PATH_TO_VAR_LOG="/var/log/"

#Where is the apache access_log file?
PATH_TO_VAR_LOG_HTTPD="/var/log/httpd/"


#PATH_TO_VAR_LOG="/home/wedaa/source/LongTail/var/log/"
#PATH_TO_VAR_LOG_HTTPD="/home/wedaa/source/LongTail/var/log/httpd/"

############################################################################
# You don't need to edit after this.
#
TODAY=`date`
YEAR=`date +%Y`
HOUR=`date +%H` # This is used at the end of the program but we want to know it NOW

############################################################################
# Lets make sure we can write to the directory
#
function is_directory_good {
	if [ ! -d $1  ] ; then
        	echo "$1 is not a directory, exiting now "
		exit
	fi
	if [ ! -w $1  ] ; then
        	echo "I can't write to /tmp", exiting now
		exit
	fi
}
############################################################################
# Change the date in index.html
#
function change_date_date_in_index {
	DATE=`date`
	sed -i "s/updated on..*$/updated on $DATE/" $1/index.html
	sed -i "s/updated on..*$/updated on $DATE/" $1/index-long.html
}
	
############################################################################
# Make a proper HTML header for assorted columns
#
function make_header {
	# first argument, the full path including the filename you want to write to
	# second argument, the title of the web page
	# Other arguments are the column headers
	# NOTE: This destroys $MAKE_HEADER_FILENAME before adding to it.
	MAKE_HEADER_DATE=`date`
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	MAKE_HEADER_FILENAME=$1
	#echo "filename is $MAKE_HEADER_FILENAME"
	touch $MAKE_HEADER_FILENAME
	if [ ! -w $MAKE_HEADER_FILENAME ] ; then
		echo "Can't write to $MAKE_HEADER_FILENAME, exiting now"
		exit
	fi
	shift
	TITLE=$1
	#echo "title is $TITLE"
	shift
	echo "<HTML><!--HEADERLINE -->" > $MAKE_HEADER_FILENAME
	echo "<HEAD><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<META http-equiv=\"pragma\" content=\"no-cache\"><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<TITLE>LongTail Log Analysis $TITLE</TITLE> <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<style> /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo ".td-some-name /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "{ /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
  echo "  white-space:nowrap; /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
  echo "  vertical-align:top; /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "} /* HEADERLINE */ " >> $MAKE_HEADER_FILENAME
	echo "</style> <!--HEADERLINE --> " >> $MAKE_HEADER_FILENAME

	echo "</HEAD><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<BODY BGCOLOR=#00f0FF><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<H1>LongTail Log Analysis</H1><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<H3>$TITLE</H3><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<P>Created on $MAKE_HEADER_DATE<!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	
	if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
		echo "<P>IP Addresses have been obfuscated to hide the guilty. <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
		echo "ALL IP addresses have been reset to end in .127. <!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	fi

#	echo "<BR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
#	echo "<BR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<TABLE border=1><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	echo "<TR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
	while (( "$#" )); do
		echo "<TH>$1</TH><!--HEADERLINE -->" >>$MAKE_HEADER_FILENAME
		shift
	done
	echo "</TR><!--HEADERLINE -->" >> $MAKE_HEADER_FILENAME
}

############################################################################
# Make a proper HTML footer for assorted columns
#
function make_footer {
	# One argument, the full path including the filename you want to write to
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	MAKE_FOOTER_FILENAME=$1
	#echo "filename is $MAKE_FOOTER_FILENAME"
	touch $MAKE_FOOTER_FILENAME
	if [ ! -w $MAKE_FOOTER_FILENAME ] ; then
		echo "Can't write to $MAKE_FOOTER_FILENAME, exiting now"
		exit
	fi
	echo "" >> $MAKE_FOOTER_FILENAME
	echo "</TABLE><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	echo "</BODY><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	echo "</HTML><!--HEADERLINE -->" >> $MAKE_FOOTER_FILENAME
	if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
		hide_ip $1
	fi
}


############################################################################
# Obfuscate any IP addresses found by setting the last octet to 128
# I am assuming that any address in a class C address is controlled
# or owned by whoever owns the Class C
#
# This way the report doesn't name any single user, but blames the
# owner of the Class C range.
#
function hide_ip {
	# One argument, the full path including the filename you want to write to
	if [ "$#" == "0" ]; then
		echo "You forgot to pass arguments, exiting now"
		exit 1
	fi
	sed -i -r 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)[0-9]{1,3}/\1127/g' $1
}


############################################################################
# Count ssh attacks and modify $HTML_DIR/index.html
#
# Called as count_ssh_attacks $HTML_DIR $PATH_TO_VAR_LOG "messages*"
#
function count_ssh_attacks {
	TMP_HTML_DIR=$1
	PATH_TO_VAR_LOG=$2
	MESSAGES=$3

	ORIGINAL_DIRECTORY=`pwd`

	TMP_DATE=`date +"%b %d"|sed 's/ /\\ /g'`
	TMP_YEAR=`date +%Y`
	TMP_MONTH=`date +%m`

	cd $PATH_TO_VAR_LOG
	TODAY=`$SCRIPT_DIR/catall.sh $PATH_TO_VAR_LOG/$MESSAGES |grep ssh |grep "$TMP_DATE" | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`

	cd $TMP_HTML_DIR/historical/
	TMP=`zcat $TMP_YEAR/$TMP_MONTH/*/current-raw-data.gz |grep ssh | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	THIS_MONTH=`expr $TMP + $TODAY`

	# This was tested and works with 365 files :-)
	TMP=`zcat $TMP_YEAR/*/*/current-raw-data.gz |grep ssh | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	THIS_YEAR=`expr $TMP + $TODAY`

	# I have no idea where this breaks, but it's a big-ass number of files
	TMP=`zcat */*/*/current-raw-data.gz |grep ssh | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	TOTAL=`expr $TMP + $TODAY`

	#NOTE TO SELF
	# These commands rely upon the ability to have a REALLY long command string.
	# They really need to be rewritten to do a find |catall.sh
	#
	#THIS_YEAR=`for FILE in $TMP_YEAR/*/*/current-raw-data.gz |grep ssh | grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password|wc -l`
	
	sed -i "s/SSH Activity Today.*$/SSH Activity Today: $TODAY/" $1/index.html
	sed -i "s/SSH Activity This Month.*$/SSH Activity This Month: $THIS_MONTH/" $1/index.html
	sed -i "s/SSH Activity This Year.*$/SSH Activity This Year: $THIS_YEAR/" $1/index.html
	sed -i "s/SSH Activity Since Logging Started.*$/SSH Activity Since Logging Started: $TOTAL/" $1/index.html
	
	sed -i "s/SSH Activity Today.*$/SSH Activity Today: $TODAY/" $1/index-long.html
	sed -i "s/SSH Activity This Month.*$/SSH Activity This Month: $THIS_MONTH/" $1/index-long.html
	sed -i "s/SSH Activity This Year.*$/SSH Activity This Year: $THIS_YEAR/" $1/index-long.html
	sed -i "s/SSH Activity Since Logging Started.*$/SSH Activity Since Logging Started: $TOTAL/" $1/index-long.html

	cd $ORIGINAL_DIRECTORY
}
	
############################################################################
# Current ssh attacks
#
# Called as ssh_attacks             $TMP_HTML_DIR $YEAR $PATH_TO_VAR_LOG DATE "messages*"
#
function ssh_attacks {
	TMP_HTML_DIR=$1
	is_directory_good $TMP_HTML_DIR
	YEAR=$2
	PATH_TO_VAR_LOG=$3
	DATE=$4
	MESSAGES=$5
	FILE_PREFIX=$6

	#
	# I do a cd tp $PATH_TO_VAR_LOG to reduce the commandline length.  If the 
	# commandline is too long and breaks on your system due to there being 
	# way too many files in the directory, then you should probably be using
	# some other tool.
	ORIGINAL_DIRECTORY=`pwd`
	cd $PATH_TO_VAR_LOG

#echo "DEBUG  $TMP_HTML_DIR, $YEAR, $PATH_TO_VAR_LOG, $DATE, messages is $MESSAGES file prefix is $FILE_PREFIX "

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-root-passwords" "Root Passwords" "Count" "Password"

	$SCRIPT_DIR/catall.sh $MESSAGES |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep |grep Password |grep Username\:\ root |awk '{print $NF}' |sort |uniq -c|sort -n |awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-root-passwords

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords" "Top 20 Root Passwords" "Count" "Password"
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-root-passwords|grep -v HEADERLINE  >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-root-passwords"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-root-passwords"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords" "Non Root Passwords" "Count" "Password"
	$SCRIPT_DIR/catall.sh $MESSAGES | grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |grep Password |grep -v Username\:\ root |awk '{print $NF}' |sort |uniq -c|sort -n |awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}'  >> $TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords" "Top 20 Non Root Passwords" "Count" "Password"
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-passwords"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-passwords"
	
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts" "Non Root Accounts" "Count" "Account"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts" "Top 20 Non Root Accounts" "Count" "Account"
	#$SCRIPT_DIR/catall.sh $MESSAGES | grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |grep Password |grep -v Username\:\ root |awk '{print $8}' |sort |uniq -c|sort -n | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts
	$SCRIPT_DIR/catall.sh $MESSAGES | grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |grep Password |awk '{print $8}' |sort |uniq -c|sort -n | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts
	tail -21 $TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-accounts"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-accounts"
	
	# This works but gives only IP addresses
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-addresses" "IP Addresses" "Count" "IP Address" "WhoIS" "Blacklisted"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses" "Top 20 IP Addresses" "Count" "IP Address" "WhoIS" "Blacklisted"
	$SCRIPT_DIR/catall.sh $MESSAGES | grep Fail |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | sed 's/^.*from //'|sed 's/ port..*$//'|sort |uniq -c |sort -n |awk '{printf("<TR><TD>%d</TD><TD>%s</TD><TD><a href=\"http://whois.urih.com/record/%s\">Whois lookup</A></TD><TD><a href=\"http://www.dnsbl-check.info/?checkip=%s\">Blacklisted?</A></TR>\n",$1,$2,$2,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-addresses
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-ip-addresses |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-addresses"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-addresses"
	
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country" "Attacks by Country" "Count" "Country"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country" "Top 20 Countries" "Count" "Country"
	for IP in `$SCRIPT_DIR/catall.sh $MESSAGES |grep Fail |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | sed 's/^.*from //'|sed 's/ port..*$//'|sort |uniq |grep -v \:\:1`; do   $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed  $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-attacks-by-country"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks-by-country"
	
	# Figuring out most common non-root pairs
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs" "Non Root Pairs" "Count" "Account:Password"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs" "Top 20 Non Root Pairs" "Count" "Account:Password"
	$SCRIPT_DIR/catall.sh $MESSAGES |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |grep Password |grep -v Username\:\ root |awk '{printf ("%s:%s\n",$8, $NF)}' |sort |uniq -c|sort -n | awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-non-root-pairs"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-non-root-pairs"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day" "Historical Ssh Attacks By Time Of Day" "Count" "Hour of Day"
	grep ssh messages*| grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep |grep Password | awk '{print $3}'|awk -F: '{print $1}' |sort |uniq -c| awk '{printf("<TR><TD>%d</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ssh-attacks-by-time-of-day"

	#-------------------------------------------------------------------------
	# raw data compressed 
	# This only prints the account and the password
	if [ $OBFUSCATE_IP_ADDRESSES -gt 0 ] ; then
		$SCRIPT_DIR/catall.sh $MESSAGES |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password\|password |sed -r 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)[0-9]{1,3}/\1127/g'  |gzip -c > $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz
	else
		$SCRIPT_DIR/catall.sh $MESSAGES |grep ssh |grep "$DATE"|grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-ssh.grep | grep -vf $SCRIPT_DIR/LongTail-exclude-accounts.grep  |egrep Password\|password |gzip -c > $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz
	fi
	#echo "Wrote to $TMP_HTML_DIR/$FILE_PREFIX-raw-data.gz"

	#
	# read and run any LOCALLY WRITTEN reports
	#
	. $SCRIPT_DIR/Longtail-ssh-local-reports

	# cd back to the original directory.  this should be the last command in 
	# the function.
	cd $ORIGINAL_DIRECTORY
}

#########################################################################################################
# HTTP STUFF HERE
# http_attacks $TMP_HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$DATE"  "access_log"  "current"
#
function http_attacks {
	TMP_HTML_DIR=$1
	is_directory_good $TMP_HTML_DIR
	YEAR=$2
	PATH_TO_VAR_LOG_HTTPD=$3
	DATE=$4
	ACCESS_LOG=$5
	FILE_PREFIX=$6
	
	#	Date format should be like this --> DATE=`date +%d/%b/%Y`
	#
	# I do a cd tp $PATH_TO_VAR_LOG to reduce the commandline length.  If the 
	# commandline is too long and breaks on your system due to there being 
	# way too many files in the directory, then you should probably be using
	# some other tool.
	ORIGINAL_DIRECTORY=`pwd`
	cd $PATH_TO_VAR_LOG_HTTPD

	
	#####################################################################################################
	# Access logs here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log" "Webpages" 
	echo "</TABLE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	echo "<PRE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	$SCRIPT_DIR/catall.sh $ACCESS_LOG | grep -hvf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep|grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE  >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	echo "</PRE><!--HEADERLINE -->" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log"
	
	
	#####################################################################################################
	#echo "What webpages are they looking for?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages" "Shellshock Requests" "Count" "Webpage"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages" "Top 20 Shellshock Requests" "Count" "Webpage"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' |sed 's/ ..*$//'|sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages |grep -v HEADERLINE >> $TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-webpages"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-webpages"

	
	#####################################################################################################
	#echo "What are the actual attacks they are trying to run?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-attacks" "Attacks"  "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks" "Top 20 Attacks"  "Count" "Attack"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG  |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//'|sort |uniq -c|sort -n  | sed -r 's/^ +/<TR><TD>/'|sed 's/ /<\/TD><TD>/'|sed 's/$/<\/TD><\/TR>/' >> $TMP_HTML_DIR/$FILE_PREFIX-attacks
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-attacks  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-attacks"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-attacks"
	
	#####################################################################################################
	#echo "Where are they getting their payloads from or trying to connect to with bash?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-payloads" "Payloads"  "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads" "Top 20 Payloads"  "Count" "Attack"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG  |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//' |sed 's/^..*http/http/'|sed 's/^..*ftp/ftp/' |sed 's/;..*//'| sed 's/^..*\/dev\/tcp/\/dev\/tcp/' |sed 's/0>.*//' |sed 's/>.*//' |sort |uniq -c |sort -n  |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-payloads
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-payloads  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-payloads"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-payloads"
	
	#####################################################################################################
	#echo "What are they trying to rm?"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-rm-attempts" "rm Attempts"  "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts" "Top 20 rm Attempts"  "Count" "Attack"
	grep -h \:\; $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep perl|sed 's/..*perl/perl/'|sed 's/^..*rm/rm/' |sort |uniq -c|sort -n |grep rm |sed 's/;.*//' |sort -n |sed 's/^/<TR><TD>/'|sed 's/$/<\/TD><\/TR>/'|sed 's/ rm/<\/TD><TD>rm/' >> $TMP_HTML_DIR/$FILE_PREFIX-rm-attempts
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-rm-attempts  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-rm-attempts"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-rm-attempts"
	
	#####################################################################################################
	#echo "Shellshock attacks not explitly using perl"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl" "shellshock-not-using-perl"  "Count" "Attack"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl" "Top 20 shellshock-not-using-perl"  "Count" "Attack"
	grep -h \:\; $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep  -v perl |sed 's/^..*\"GET\ //'| sed 's/^..*\"HEAD\ //' | sed 's/^..*:;//' |sed 's/\}\;//' |sort |uniq -c |sort -n |sed 's/^ *//' |sed 's/^/<TR><TD>/' |sed 's/$/<\/TD><\/TR>/' |sed 's/ /<\/TD><TD>/'   >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl

	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-not-using-perl"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-shellshock-not-using-perl"
	
	#####################################################################################################
	# Shellshock here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock" "access-log-shell-shock" 
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \:\; >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log-shell-shock"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock" "ip-access-log-shell-shock"  "Count" "Attack"
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \:\; | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}'>> $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-shell-shock"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock" "country-access-log-shell-shock"  "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \:\; | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-shell-shock
	
	#####################################################################################################
	# 404 probes here
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-access-log-404" "access-log-404"  
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\  >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-access-log-404"

#-------------------------------------------------------------------------
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404" "open-proxy-log-404"  
	echo "</TABLE><PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\ |grep 'GET http:' >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	echo "</PRE>" >> $TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-open-proxy-log-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404" "ip-open-proxy-404"  "Count" "IP Address"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404" "Top 20 ip-open-proxy-404"  "Count" "IP Address"
	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep  |grep $DATE |grep \ 404\ |grep 'GET http:' | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-open-proxy-404"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-open-proxy-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404" "country-open-proxy-log-404"  "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep -v \:\; |grep $DATE |grep \ 404\ |grep 'GET http:'  | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-open-proxy-log-404

#-------------------------------------------------------------------------

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404" "ip-access-log-404"  "Count" "IP Address"
	make_header "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404" "Top 20 ip-access-log-404"  "Count" "IP Address"

	grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -v \:\; |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep $DATE |grep \ 404\  | awk '{print $1}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404
	tail -20 $TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404  |grep -v HEADERLINE>> $TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-ip-access-log-404"
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-top-20-ip-access-log-404"

	make_header "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404" "country-access-log-404"  "Count" "Country"
	for IP in `grep -vhf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-webpages.grep |grep -v \:\; |grep $DATE |grep \ 404\  | awk '{print $1}' |sort |uniq` ;do $SCRIPT_DIR/whois.pl $IP |grep -i country|head -1|sed 's/:/: /g' ; done | awk '{print $NF}' |sort |uniq -c |sort -n |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404"
	sed -i -f $SCRIPT_DIR/translate_country_codes.sed.orig  $TMP_HTML_DIR/$FILE_PREFIX-country-access-log-404


	make_header "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day" "shellshock-by-time-of-day"  "Count" "Time"
	$SCRIPT_DIR/catall.sh $ACCESS_LOG |grep -vf $SCRIPT_DIR/LongTail-exclude-IPs-httpd.grep  |grep -v \/honey\/ | grep \:\; |awk -F: '{print $2}' |sort|uniq -c |awk '{printf ("<TR><TD>%s</TD><TD>%s</TD></TR>\n",$1,$2)}' >> $TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day
	make_footer "$TMP_HTML_DIR/$FILE_PREFIX-shellshock-by-time-of-day"

	#
	# read and run any LOCALLY WRITTEN reports
	#
	. $SCRIPT_DIR/Longtail-httpd-local-reports


	# cd back to the original directory.  this should be the last command in 
	# the function.
	cd $ORIGINAL_DIRECTORY

}


############################################################################
# Set permissions so everybody can read the files
#
function set_permissions {
	TMP_HTML_DIR=$1
	chmod a+r $TMP_HTML_DIR/*
}

############################################################################
# Create historical copies of the data
#
function create_historical_copies {
	TMP_HTML_DIR=$1
	DATE=`date +%Y.%m.%d`
	if [ $HOUR -eq 23 ]; then
		cd  $TMP_HTML_DIR
		mkdir -p $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`
		cp $TMP_HTML_DIR/index-historical.html $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`/index.html
		for FILE in `ls |grep -v historical|egrep -v index.html\|index-long.html\last-30\|last-7` ; do
			echo "DEBUG- Copying $FILE to historical"
			#cp $FILE $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`/$FILE.$DATE
			cp $FILE $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`/
		done
		chmod a+rx $TMP_HTML_DIR/historical
		chmod a+rx $TMP_HTML_DIR/historical/`date +%Y`
		chmod a+rx $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`
		chmod a+rx $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`
		chmod a+r  $TMP_HTML_DIR/historical/`date +%Y`/`date +%m`/`date +%d`/*
	fi
}


############################################################################
# Main 
#


change_date_date_in_index $HTML_DIR $YEAR

DATE=`date +"%b %d"` # THIS IS TODAY
#-----------------------------------------------------------------
# Lets count the ssh attacks
count_ssh_attacks $HTML_DIR $PATH_TO_VAR_LOG "messages*"

#----------------------------------------------------------------
# Lets check the ssh logs
#echo "DEBUG Doing ssh analysis now"
ssh_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG "$DATE"  "messages" "current"
ssh_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG "."      "messages*" "historical"

#echo "DEBUG exiting now for DEBUG"
#exit

LAST_WEEK=""
for i in 1 2 3 4 5 6 7 ; do
	TMP_DATE=`date +"%b %d" --date="$i day ago"`
	if [ "$LAST_WEEK" == "" ] ; then
		LAST_WEEK="$TMP_DATE"
	else
		LAST_WEEK="$LAST_WEEK\\|$TMP_DATE"
	fi
done
#echo $LAST_WEEK
ssh_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG "$LAST_WEEK"      "messages*" "last-7-days"


LAST_MONTH=""
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
	TMP_DATE=`date +"%b %d" --date="$i day ago"`
	if [ "$LAST_MONTH" == "" ] ; then
		LAST_MONTH="$TMP_DATE"
	else
		LAST_MONTH="$LAST_MONTH\\|$TMP_DATE"
	fi
done
#echo $LAST_MONTH
ssh_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG "$LAST_MONTH"      "messages*" "last-30-days"


# This is an example of how to call ssh_attacks for past dates and 
# put the reports in the $HTML_DIR/historical/Year/month/date directory
# Please remember that single digit dates have two leading spaces
# while double digit dates only have one leading space
#
#for LOOP in 1 2 3 4 5 6 7 8 9 ; do
#	mkdir -p $HTML_DIR/historical/2015/01/0$LOOP
#	ssh_attacks $HTML_DIR/historical/2015/01/0$LOOP $YEAR $PATH_TO_VAR_LOG "Jan  $LOOP"      "messages*" "current"
#done
#for LOOP in 10 11 12 13 14 15 16 17 18 19 20 ; do
#	mkdir -p $HTML_DIR/historical/2015/01/$LOOP
#	ssh_attacks $HTML_DIR/historical/2015/01/$LOOP $YEAR $PATH_TO_VAR_LOG "Jan $LOOP"      "messages*" "current"
#done


#-----------------------------------------------------------------
# Now lets do some long term ssh reports....  Lets do a comparison of 
# top 20 non-root-passwords and top 20 root passwords
#-----------------------------------------------------------------
#echo "DEBUG Doing trend analysis now"
cd $HTML_DIR/historical 
make_header "$HTML_DIR/trends-in-non-root-passwords" "Trends in Non Root Passwords From 20th to Most Common" "Date" "20" "19" "18" "17" "16" "15" "14" "13" "12" "11" "10" "9" "8" "7" "6" "5" "4" "3" "2" "1"

#for FILE in `find . -name 'current-top-20-non-root-passwords'|sort -n ` ; do  echo "<TR>";echo -n "<TD>"; echo -n $FILE |\
#	sed 's/current-top-20-non-root-passwords/ /'|sed 's/^.//'|sed 's/\// /'|sed 's/\/ $//'; \
#	echo -n "</TD>"; grep TR $FILE |\
#	grep -v HEADERLINE |sed 's/<TR>//'|sed 's/<.TR>//'|sed 's/<.TD><TD>/:/' ;\
#	echo "</TR>" ; done >> $HTML_DIR/trends-in-non-root-passwords

#echo "DEBUG in current-top-20-non-root-passwords"
for FILE in `find . -name 'current-top-20-non-root-passwords'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; echo -n $FILE |\
	sed 's/current-top-20-non-root-passwords/ /'|sed 's/^.//'|sed 's/\// /'|sed 's/\/ $//'; \
	echo -n "</TD>"; grep TR $FILE |\
	grep -v HEADERLINE | \
	awk '{print $1}' |sed 's/<\/TD><\/TR>/ <\/TD><\/TR>/'|sed 's/<\/TD><TD>/<\/TD><TD> /' |awk '{printf ("%s <a href=\"https://www.google.com/search?q=default+password+%s\">%s</a> %s\n",$1,$2,$2,$3)}' |\
	sed 's/<TR>//'|sed 's/<.TR>//'|sed 's/<.TD><TD>/:/' ;\
	echo "</TR>" ; done >> $HTML_DIR/trends-in-non-root-passwords

make_footer "$HTML_DIR/trends-in-non-root-passwords"
sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-non-root-passwords

#-----------------------------------------------------------------
cd $HTML_DIR/historical 
make_header "$HTML_DIR/trends-in-root-passwords" "Trends in Root Passwords From 20th to Most Common" "Date" "20" "19" "18" "17" "16" "15" "14" "13" "12" "11" "10" "9" "8" "7" "6" "5" "4" "3" "2" "1"
# This works #for FILE in `find . -name 'current-top-20-root-passwords'|sort -n ` ; do  echo "<TR>";echo -n "<TD>"; echo -n $FILE | \
# sed 's/current-top-20-root-passwords//' |sed 's/^.//'|sed 's/\// /'|sed 's/\/ $//' ;echo -n "</TD>"; grep TR $FILE | \
# grep -v HEADERLINE |sed 's/<TR>//'|sed 's/<.TR>//'|sed 's/<.TD><TD>/:/' ; echo "</TR>" ; done >> $HTML_DIR/trends-in-root-passwords
for FILE in `find . -name 'current-top-20-root-passwords'|sort -nr ` ; do  echo "<TR>";echo -n "<TD>"; echo -n $FILE |\
	sed 's/current-top-20-root-passwords/ /'|sed 's/^.//'|sed 's/\// /'|sed 's/\/ $//'; \
	echo -n "</TD>"; grep TR $FILE |\
	grep -v HEADERLINE | \
	awk '{print $1}' |sed 's/<\/TD><\/TR>/ <\/TD><\/TR>/'|sed 's/<\/TD><TD>/<\/TD><TD> /' |awk '{printf ("%s <a href=\"https://www.google.com/search?q=default+password+%s\">%s</a> %s\n",$1,$2,$2,$3)}' |\
	sed 's/<TR>//'|sed 's/<.TR>//'|sed 's/<.TD><TD>/:/' ;\
	echo "</TR>" ; done >> $HTML_DIR/trends-in-root-passwords

make_footer "$HTML_DIR/trends-in-root-passwords"
sed -i 's/<TD>/<TD class="td-some-name">/g' $HTML_DIR/trends-in-root-passwords
cd $HTML_DIR/historical 


#-----------------------------------------------------------------
# Lets check the httpd access_logs logs
# Reset the date to an access_log format
DATE=`date +%d/%b/%Y`
#echo "DEBUG Doing http analysis now"
http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$DATE"  "access_log"  "current"
http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "."      "access_log*" "historical"

LAST_WEEK=""
for i in 1 2 3 4 5 6 7 ; do
  TMP_DATE=`date +"%d/%b/%Y" --date="$i day ago"`
  if [ "$LAST_WEEK" == "" ] ; then
    LAST_WEEK="$TMP_DATE"
  else
    LAST_WEEK="$LAST_WEEK\\|$TMP_DATE"
  fi
done
#echo $LAST_WEEK
http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$LAST_WEEK"      "access_log*" "last-7-days"


LAST_MONTH=""
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  TMP_DATE=`date +"%d/%b/%Y" --date="$i day ago"`
  if [ "$LAST_MONTH" == "" ] ; then
    LAST_MONTH="$TMP_DATE"
  else
    LAST_MONTH="$LAST_MONTH\\|$TMP_DATE"
  fi
done
#echo $LAST_MONTH
http_attacks $HTML_DIR $YEAR $PATH_TO_VAR_LOG_HTTPD "$LAST_MONTH"      "access_log*" "last-30-days"



# Now, if we have access to other access_logs, we put them in a 
# different directory.  That way they don't get com-mingled with
# the honeypot data.
# NOTE: I'm still working on this part...
#

set_permissions  $HTML_DIR 
create_historical_copies  $HTML_DIR

exit
