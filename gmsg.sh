#!/bin/bash

. config

if test -z "$MAXWEEK" -o -z "$STARTWK" -o -z "$TARGETCMT"; then
	echo "ERROR: config file is missing or incomplete."
	exit
fi

if test ! -f $STORY -o ! -f $COMMITMSG; then
	echo "ERROR: message files is missing."
	exit
fi

if test ! -f $COMMITMSG.dat -o $COMMITMSG -nt $COMMITMSG.dat ; then
  strfile $COMMITMSG || exit
fi


DAT=$(date '+%Y/%m/%d')
AGE=$(date '+%U')  # week number of year, with Sunday as first day of week
DOW=$(date '+%u')  # 1-7, 1=Monday

# don't bother w/ year transition
AGE=$(($AGE - $STARTWK))
DOW=$(($DOW % 7))

echo "Week: $AGE Day: $DOW"

if test $AGE -gt $MAXWEEK; then
	exit
fi


COL=${WEEK[$AGE]}
PIX=${COL:$DOW:1}

if test "$PIX" != "X"; then
	echo "No milk today."
	exit
fi


CMT=`curl -s $GITCALURL \
| sed -e 's/\],\[/\n/g;s/\]//g;s/\[//g' \
| grep "$DAT" \
| cut -d ',' -f 2`

echo "$CMT / $TARGETCMT"

if test -z "$CMT"; then
	echo "ERROR: canot query today's count"
	exit
fi
if test $CMT -lt 0 -o $CMT -ge $TARGETCMT; then
	echo "ERROR: bogus number -- nothing to do."
	exit
fi


export STORY
export DOW
export GITFILE

function next_word {
	TFN=`mktemp`

	if test -f $STORY; then
		sed 's/[ \t\n][ \t\n]*/\n/g' $STORY | grep -ve "^$"> $TFN
		read -r xx < $TFN
	else
		xx=""
	fi

	if test -z "$xx"; then
		echo "OUT OF MESSAGE" >&2
		echo -n "." >> $GITFILE
	else
		echo -n "$xx" > $GITFILE
		tail -n +2 $TFN > $STORY
	fi

	rm -f $TFN
}

function add_commit {
	next_word
	git add $GITFILE
	git commit -q -m "`fortune $COMMITMSG`" || exit
	sleep 1
}

echo "git commit: "
while test $CMT -lt $TARGETCMT; do
	CMT=$(($CMT + 1))
	printf "%2d " $CMT
	add_commit
done
echo

git push origin master
