#!/bin/bash
#
#
#	Checks and notify if change lesson plans
#	valid for VULCAN's Optivum API generated
#	arg: -m : eachtime send mail
#	     -u : update only with no mail
#
#	created: julian.cenkier@wp.eu
#	version: 20220112
#
#	Install on host with shell access
#	and set cron job for period checks.
#
# >
    SCRIPT=${0##*/}
	SCRIPTdir="${0%/*}/"
    SCRIPTname=${SCRIPT%.*}
    cfg=".${SCRIPTname}cfg"
	STARTdir="$(pwd)"
	cd $SCRIPTdir || exit
	#
	forcemail=;[[ "${1}" = "-m" ]] && forcemail="yes"
	justupdate=;[[ "${1}" = "-u" ]] && justupdate="yes"
	#
    if [ -f $cfg ]; then
        . $cfg
    else
        echo ".. Create and fill config: $cfg"
        exit
    fi

        mailurls=
        mailurlssl=
    if [ ${#mailssl} -gt 0 ];then
        mailurls='s'
        mailurlssl=' --ssl-reqd'
    fi

    function sendMail(){
		if [[ -z $justupdate ]];then
        curl --url smtp$mailurls://$mailsmtp$mailurlssl \
        --mail-from $mailfrom \
        --mail-rcpt $mailto \
        --user $mailfrom:$mailpass \
        -T <(echo -en "From: ${mailfrom}\nTo: ${mailto}\nSubject: ${mailsub}\n${mailmsg}")
		fi
    }

	function checkit(){
		curl -L "${pp_uri}${1}" > text
		if [[ -n $1 ]];then
			# New API
			stab="<button id.*table>"
			skl="font-size: 22px;\">(.)*</div>"
		else
			# Old
			stab="</table.*table>"
			skl="tytulnapis\">(.)*</span>"
		fi
		echo -e $(cat text) | grep -Eo "${stab}" | grep -Po '<table.*$' | tr '\015' '|' | sed -e 's/<br*>/\*/g' | sed -e 's/<\/\?\s*[^>]*>//g' | tr '|' '\n' > text1
		cat text | grep -Eo "${skl}" | grep -Eo ">.*<" | cut -c2- | rev | cut -c2- | rev > text2
			kl=$(cat text2)
			readarray -t text2check <<< $(cat text1)
			# trim spaces
			for i in "${!text2check[@]}";do
				a="${text2check[$i]}"
				text2check[$i]=$(echo "${a}" | sed -e 's/^\s//g' | sed -e 's/\s$//g')
			done
			msgtit="<h3>${pp_prefix} / ${kl}</h3>"	# html titile (mail body)
			mailsub=$pp_prefix' PLAN '$kl			# mail subject
				#
				# file names
				#
				text="plan_${pp_prefix}_${kl}"	# reference (file)
				textsum="${text}_sum"			# hash
				texthtml="${text}_html"			# html (mail body)
			
			readarray -t textorg <<< $(cat $text)	# read previews file
			# here is place for make backup of previews file
			echo "${text2check[@]}" > $text			# (over)write with downloaded file

		if [[ -e $textsum ]];then
			checkstatus=$(sha256sum --check $textsum | grep -o 'FAILED' | wc -l)
			if [[ $checkstatus -gt 0 ]];then
				sha256sum $text > $textsum
				mailsub=$mailsub' zmiana'
				#
				# select changes
				#
				changed=()
				for i in "${!text2check[@]}"; do
					s="${textorg[$i]}"
					c="${text2check[$i]}"
					stat=
					if [[ "$s" != "$c" ]];then
						stat="!"	# changed
						[[ -z $s ]] && [[ -n $c ]] && stat="+"	# added
						[[ -n $s ]] && [[ -z $c ]] && stat="-"	# removed
					fi
					changed[$i]="${stat}"
				done
			fi
		else
			sha256sum $text > $textsum
		fi
			rm text text1 text2
			#
			# create HTML template
			#
				day=7
				type=("nr" "g" "l" "l" "l" "l" "l")	# cell type/class
				i=0
				msg=()
				while [[ $i -lt ${#text2check[@]} ]] ;do
					x=0
					if [[ $i -lt $day ]];then
						msg[$i]="<table class=\"opium_plan\"><tr>"
						while [[ $x -lt $day ]];do
							a="${msg[$i]}"
							msg[$i]="${a}<th>${text2check[$i]}</th>"
							x=$((x+1))
							i=$((i+1))
						done
					else
						msg[$i]="<tr>"
						while [[ $x -lt $day ]];do
							c="${changed[$i]}"
							s=
							[[ -n $c ]] && [[ $x -gt 1 ]] && s=" changed"
							a="${msg[$i]}"
							msg[$i]="${a}<td class=\"${type[$x]}${s}\">${text2check[$i]}</td>"
							msg[$i]="$(echo ${msg[$i]} | sed -e 's/\*/<br>/g')"
							x=$((x+1))
							i=$((i+1))
						done
					fi
						i=$((i-1))
						msg[$i]="${msg[$i]}</tr>"
					i=$((i+1))
					[[ -z ${text2check[$i]} ]] && break
				done
				msg[$i]="</table>"
				echo "${msg[@]}" | sed -e 's/>\s</></g' > $texthtml
				msghtml="$(cat $texthtml)"
			mailmsg='MIME-Version: 1.0\nContent-Type: text/html; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n<html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head><body>'$(echo "$htmlstyle")$(echo -e "$msgtit")$(echo -e "$msghtml")'</body></html>'
			[[ $checkstatus -gt 0 ]] && [[ -z $forcemail ]] && sendMail
			[[ -n $forcemail ]] && sendMail
	}
# <
#
#
if [[ ${#planlist[@]} -gt 0 ]];then
	for i in "${planlist[@]}";do
		IFS=';' read -ra plan <<< "$i"
		[[ -n ${plan[0]} ]] && pp_prefix=$(echo "${plan[0]}" | xargs)
		[[ -n ${plan[1]} ]] && pp_uri=$(echo "${plan[1]}" | xargs)
		[[ -n $pp_prefix ]] && [[ -n $pp_uri ]] && checkit $(echo "${plan[2]}" | xargs)
	done
else
	echo ".. in $cfg fill planlist"
fi
cd $STARTdir || exit