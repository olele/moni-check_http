#!/bin/bash
export LC_ALL=C
ADRES=$1
ERR=0
MSG=""

function get_site(){
	# TODO: jakos mierzyc czas
	time $(wget -t 1 -nv -O /tmp/check$$.stdout $ADRES 2> /tmp/check$$.stderr) 2>&1 > /tmp/check$$.time
	echo $? > /tmp/check$$.errcode
}

function get_hostname(){
	echo "$1" | sed 's@https\?://\([^/?$#&]\+\).*@\1@'
} 

function check_stdout(){
	if [ "$(cat /tmp/check$$.stdout)" = "" ]
		then
			set_check_error_msg "Strona jest pusta"
			set_check_exit_code 2
			return 1
	fi
	grep -i -q 'PHP ERROR\|connection error\|Warning:\|Error:\|mysql_query\|mysql_connect' /tmp/check$$.stdout
	if [ $? -eq 0 ]
		then
			set_check_error_msg "Znaleziono bledy na stronie"
			set_check_exit_code 2
			return 1
	fi
}

function check_stderr(){
	cat /tmp/check$$.stderr|grep -v "$ADRES"|sed 's/^[0-9 -:]\+//'
}

function check_errcode(){
	ZM=$(cat /tmp/check$$.errcode)
	if [ -z "$ZM" ]
		then
			set_check_error_msg "Nieokreslony blad"
			set_check_exit_code 3
			return 2
	fi 
	if [ $ZM -ne 0 ]
		then
			if [ $ZM -le 4 ]
				then
					set_check_error_msg "Blad podczas przesylania danych z serwera"
					set_check_exit_code 2
			fi 
			if [ $ZM -eq 5 ]
				then
					set_check_error_msg "Blad certyfikatu SSL"
					set_check_exit_code 2
			fi
			if [ $ZM -eq 6 ]
				then
					set_check_error_msg "Strona wymaga autoryzacji"
					set_check_exit_code 2
			fi
			if [ $ZM -eq 7 ]
				then
					# TODO: O co come on? ;)
					set_check_error_msg "Protocol errors."
					set_check_exit_code 2
			fi
			if [ $ZM -eq 8 ]
				then
					set_check_error_msg "$(check_stderr)"
					set_check_exit_code 2
			fi
	fi
	return $ZM
}

function check_ping(){
	HOSTN=$(get_hostname $ADRES)
	fping -q $HOSTN
	if [ $? -ne 0 ]
		then
			set_check_error_msg "Host $HOSTN nie odpowiada na pingi"
			set_check_exit_code 2
			return 1
	fi 
}

function nag_prefix(){

case $1 in 
	0) echo -ne "OK $ADRES";;
	1) echo -ne "Uwaga $ADRES:";;
	2) echo -ne "Blad $ADRES:";;
	*) echo -ne "Nieznany blad $ADRES:"
esac	
}

function set_check_error_msg(){
	MSG="$* $MSG"
}

function set_check_exit_code(){
	ERR=$1
}

function print_msg(){
	echo $(nag_prefix $ERR) $MSG
}

function check_site(){
check_ping
if [ $? -ne 0 ]
	then
		return 1
fi
check_errcode
if [ $? -ne 0 ]
        then
                return 2
fi
check_stdout
if [ $? -ne 0 ]
        then
                return 3
fi

}

function main(){
	get_site
	check_site
	print_msg
	cat /tmp/check$$.time
	rm /tmp/check$$.errcode /tmp/check$$.stderr /tmp/check$$.stdout /tmp/check$$.time
	exit $ERR
}

main

