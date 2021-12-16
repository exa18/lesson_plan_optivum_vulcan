#!/bin/bash
#
#
#	Checks and notify if change lesson plans
#	valid for VULCAN's Optivum API generated
#	arg: -m : eachtime send mail
#
#	created: julian.cenkier@wp.eu
#	version: 20210915
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
		cu=$(cat text)
		if [[ -n $1 ]];then
			# New API
			stab="<button id.*table>"
			skl="font-size: 22px;\">(.)*</div>"
		else
			# Old
			stab="</table.*table>"
			skl="tytulnapis\">(.)*</span>"
		fi
		echo -e $cu | grep -Eo "${stab}" | grep -Po '<table.*$' > text1
		cat text | grep -Eo "${skl}" | grep -Eo ">.*<" | cut -c2- | rev | cut -c2- | rev > text2
			kl=$(cat text2)
			msg=$(cat text1)
			msgtit="<h3>${pp_prefix} / ${kl}</h3>"
			text="plan_${pp_prefix}_${kl}"
			textsum="${text}_sum"
			cat text1 > $text
				mailsub=$pp_prefix' PLAN '$kl
				mailmsg='MIME-Version: 1.0\nContent-Type: text/html; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n<html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head><body>'$(echo "$htmlstyle")$(echo -e "$msgtit")$(echo -e "$msg")'</body></html>'
		if [[ -e $textsum ]];then
			sha256sum --check $textsum| grep -o 'FAILED' > textstatus
			if [[ $(cat textstatus | wc -l) -gt 0 ]];then
				sha256sum $text > $textsum
				[[ -z $forcemail ]] && mailsub=$mailsub' zmiana' && sendMail
			fi
			rm textstatus
		else
			sha256sum $text > $textsum
		fi
			rm text text1 text2
			[[ -n $forcemail ]] && sendMail
	}
# <
#
#
forcemail=;[[ "${1}" = "-m" ]] && forcemail="yes"
justupdate=;[[ "${1}" = "-u" ]] && justupdate="yes"
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