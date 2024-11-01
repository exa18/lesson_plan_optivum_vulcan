#!/bin/bash
#
#
#	Checks and notify if change lesson plans
#	valid for VULCAN's Optivum API generated
#	arg: -m : eachtime send mail
#	     -u : update only with no mail
#
#	created: julian.cenkier@wp.eu
#	version: 20241028
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
	d=$(date "+%Y%m%d")
	#
	if [ -f $cfg ]; then
		. $cfg
	else
		echo ".. Create and fill config: $cfg"
		exit
	fi

		mailurls=
		mailurlssl=
	if [[ ${#mailssl} -gt 0 ]];then
		mailurls='s'
		mailurlssl=' --ssl-reqd'
	fi
	[[ -z $mailuser ]] && mailuser=${mailfrom}
# <
#
#	functions
#
# >
	function sendMail(){
	if [[ -z $justupdate ]];then
		curl --url smtp$mailurls://$mailsmtp$mailurlssl \
		--mail-from $mailfrom \
		--mail-rcpt $mailto \
		--user $mailuser:$mailpass \
		-T <(echo -en "From: ${mailfrom}\nTo: ${mailto}\nSubject: ${mailsub}\n${mailmsg}")
	fi
	}

	function checkit(){
		status=
		statustitle=
		# Check which API: for 2.0 gives 0, for 1.0 more than 0
		checkapi=$(echo "${pp_uri}" | grep -o '.html' | wc -c)
		# Check connection
		connect=$(curl -kIs --connect-timeout 3 "${pp_uri}" | head -n 1 | grep -Eo "[0-9]{3}")
		if [[ $connect -eq 200 ]];then
			#
			# Get webside
			curl -kL "${pp_uri}" > text
			if [[ $checkapi -eq 0 ]];then
				# New API
				#
				# get changing part "?vsel=1337&vsel1=@" > "?vsel=1337&vsel"
				aa_uri=$(cat text | grep -Po '<select data-onchange-value="/.*"><option value="1"' | grep -Po '\?.*=@' | rev | cut -c 4- | rev)
				# find element for VSEL2, exp. o29
				bb_uri=$(cat text | grep -Po "<option value=\".*\">${pp_kl}" | awk '{print $NF}' | awk -F'"' '{print $2}')
				# get content from constructed link "LINK?vsel=1337&vsel2=o29"
				curl -kL "${pp_uri}${aa_uri}2=${bb_uri}" > text
				stab="<table.?class=\"opium_plan\".*table>"
				skl="font-size: 22px;\">(.)*</div>"
				echo -e $(cat text) | grep -Eo "${stab}" | grep -Po '<table.*$' | grep -Po '(?:<(td|th).*>)(.*)(?:<\/(td|th)>)' | tr '\015' '|' | sed -e 's:|\s*:|:g' -e 's:>|<\/tr>|<tr>|<td:><\/tr>|<tr><td:g' -e 's:>\s*:>:g' -e 's:<br*>:\*:g' -e 's:<\/\?\s*[^>]*>::g' | tr '|' '\n' > text1
			else
				# Old
				#
				stab="</table.*table>"
				skl="tytulnapis\">(.)*</span>"
				# other cleaning do to formating
				echo -e $(cat text) | grep -Eo "${stab}" | grep -Po '<table.*$' | sed -e 's:>\s*<:><:g' | grep -Po '(?:<(td|th).*>)(.*)(?:<\/(td|th)>)' | sed -e 's:</th>:|:g' -e 's:</td>:|:g' -e 's:|\s*:|:g' -e 's:>|<\/tr>|<tr>|<td:><\/tr>|<tr><td:g' -e 's:>\s*:>:g' -e 's:<br*>:\*:g' -e 's:<\/\?\s*[^>]*>::g' -e 's:\&nbsp\;::g' -e 's:Obowi.*VULCAN.*::g' | tr '|' '\n' > text1
			fi
			# detect and check class
			cat text | grep -Eo "${skl}" | grep -Eo ">.*<" | cut -c2- | rev | cut -c2- | rev > text2
			kl="$(cat text2)"
			#
			if [[ "${kl}" == "${pp_kl}" ]];then
				msgtit="<h3>${pp_prefix} / ${kl}</h3>"	# html titile (mail body)
				mailsub=$pp_prefix' PLAN '$kl			# mail subject
					#
					# file names
					#
					text="plan_${pp_prefix}_${kl}"		# reference (file)
					textsum="${text}_sum"				# hash
					texthtml="${text}_html"				# html (mail body)
				[[ -e $text ]] && readarray -t textorg <<< "$(cat $text)"	# read current file
				# here is place for make backup of previews file
				[[ -e $text ]] && rm $text

				day=7

				readarray -t text2check <<< "$(cat text1)"
				# trim spaces and remove row with empty days
				for i in "${!text2check[@]}";do
					row=$(( i%day ))
					# concat every row w/o 1st and 2nd column, then check if not empty
					[[ $row -eq 0 ]] && cap="${text2check[@]:$((i+2)):5}" && cap="${cap// /}"
					if [[ -n $cap ]];then
						a="${text2check[$i]}"
						[[ $row -eq 1 ]] && a="${a/- /-}"	# remove space inside "8:00- 8:55" when checking column with time
						a=$(echo "${a}" | sed -e 's/^\s*//g' | sed -e 's/\s*$//g')
						echo "${a}" >> $text	# (over)write file to hash with this output
					fi
				done
				# reaload array
				readarray -t text2check <<< "$(cat $text)"

				checkstatus=
				dlast=
				if [[ -e $textsum ]];then
					checkstatus=$(sha256sum --check $textsum | grep -o 'FAILED' | wc -l)
					if [[ $checkstatus -gt 0 ]];then
						dlast=" [$(date -r $textsum '+%Y%m%d')]"
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
				#
				# create HTML template
				#
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
								st=
								[[ -n $c ]] && [[ $x -gt 1 ]] && s=" changed" && st="<b>${c}:</b>"
								a="${msg[$i]}"
								msg[$i]="${a}<td class=\"${type[$x]}${s}\">${st}${text2check[$i]}</td>"
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
				#
				#	makeMail
				#
				msghtml=$(echo "${msg[@]}" | sed -e 's/>\s</></g')
				mailmsg='MIME-Version: 1.0\nContent-Type: text/html; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n<html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head><body>'$(echo "$htmlstyle")$(echo -e "$msgtit")$(echo -e "$msghtml")'</body></html>'
				#
				if [[ $checkstatus -gt 0 ]] || [[ -z $checkstatus ]];then
					#
					echo "${msghtml}" > $texthtml
					#
					#	makeWebPage
					#
					[[ -n $htmlwww ]] && [[ -d ./www ]] && html='<!DOCTYPE html><html class="no-js" lang="pl"><head><meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'$(echo "$pp_prefix :: $kl :: $d$dlast")'</title><meta http-equiv="content-type" content="text/html; charset=UTF-8"/>'$(echo "$htmlstyle")'<style>body{margin:0}.card {display:flex;justify-content:center;align-items:center;height:100vh;margin:auto}.card-body{overflow:auto}.nochanges td.changed{background:transparent!important}.nochanges td b{display:none}.toggle{position: static;margin-bottom:0.5em;background:#ff0;border: none;padding: 0.5em 1.5em;text-align:center;text-decoration:none;display:inline-block;cursor:pointer;font-weight:bold}.nochanges button{background:#999}@media (max-width:58em) {body{font-size:80%}.card-body{height:100%}}</style><script>function toggleClass(){const element = document.querySelector(".card");element.classList.toggle("nochanges");}</script></head><body><div class="container"><div class="card nochanges"><div class="card-body"><button class="toggle" onclick="toggleClass()">'$(echo "$pp_prefix / $kl")'</button>'$(echo "$msghtml")'</div></div></div></body></html>' && echo "$html" > ./www/${pp_prefix}_${kl}.html
					#
					[[ -z $forcemail ]] && sendMail
				fi
				[[ -n $forcemail ]] && sendMail
			else
				status="@<a href="'"'"${pp_uri}"'"'" class="'"'"list-group-item badge"'"'">@${pp_kl}-&gt;[${kl}]</a>"
				statustitle="Not match or removed"
			fi
		else
			status="!${connect}"
			statustitle="NO connection"
		fi
		kl="${pp_kl}"
		#
		#
		htmlstatus=
		[[ -n $status ]] && htmlstatus="<span class="'"'"badge"'"'" title="'"'"${statustitle}"'"'">${status}</span>"
		#
		#	create html list
		[[ -n $htmlwww ]] && [[ -e ./www/${pp_prefix}_${kl}.html ]] && indexitems="${indexitems}<a href="'"'"${pp_prefix}_${kl}.html"'"'" class="'"'"list-group-item"'"'">$(cat ./www/${pp_prefix}_${kl}.html | grep -Eo '<title>.*</title>' | sed -e 's/<title>//g' | sed -e 's/<\/title>//g')${htmlstatus}</a>"
		rm text text1 text2
	}
# <
#
#
indexitems=
if [[ $d -gt ${planactv[0]} ]] && [[ $d -le ${planactv[1]} ]];then
	if [[ ${#planlist[@]} -gt 0 ]];then
		for i in "${planlist[@]}";do
			IFS=';' read -ra plan <<< "$i"
			[[ -n ${plan[0]} ]] && pp_prefix=$(echo "${plan[0]}" | xargs)
			[[ -n ${plan[1]} ]] && pp_uri=$(echo "${plan[1]}" | xargs)
			pp_kl=$(echo "${plan[2]}" | xargs)
			[[ -n $pp_prefix ]] && [[ -n $pp_uri ]] && [[ -n $pp_kl ]] && checkit
		done
		#
		#	makeIndexPage
		#
		[[ -n $htmlwww ]] && [[ -d ./www ]] && indexwww='<!DOCTYPE html><html class="no-js" lang="pl"><head><meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Lesson Plan INDEX</title><meta http-equiv="content-type" content="text/html; charset=UTF-8"/><style>body{margin:0;background:#666}.card {display:flex;justify-content:center;align-items:center;height:100vh;margin:auto}.list-group-horizontal .list-group-item{margin-bottom:1em;border: none;padding: 0.5em 1.5em;text-align:center;text-decoration:none;cursor:pointer;font-weight:bold;color:#000;display:block;position: relative;}.list-group-item{background:#ff0;}.badge{position: absolute;right:0;padding: 0.2em 0.5em;background:#F00;bottom:-1em;}.list-group-item.badge{bottom:initial;margin-left:1em;}</style></head><body><div class="container"><div class="card nochanges"><div class="list-group list-group-horizontal">'$(echo "$indexitems")'</div></div></div></body></html>' && echo "$indexwww" > ./www/index.html
		#
		
	else
		echo ".. in $cfg fill planlist"
	fi
fi
cd $STARTdir || exit
