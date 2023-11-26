#!/bin/sh
# Usage: fd.sh state_file bdir dir dir_hash cmd [arg]
# state_file:
#   - Used to store the toggle flags.
#   - <state_file>.d* stores the search directory.
#   - <state_file>.fd stores the fd query for the command "repeat".
#   - <state_file>.fzf stores the fzf query (only on the vim side).
#   - <state_file>.p stores the currently active prompt.
# bdir: (base dir) absolute path to the current working directory of vim.
# dir: directory to search in, relative to bdir or absolute.
# dir_hash:
# 	- hash of dir used to store and recall the search directory.
# 	- empty strings turns off the feature.
# cmd [arg]: see the case statement below.

rel2home() {
	local d="`realpath --relative-base="$HOME" "$1"`"
	case $d in
		/*)
			echo "$d"
			;;
		*)
			if [ "$d" = "." ]; then
				d=""
			fi
			echo "~/$d"
			;;
	esac
}

save() {
	t="`mktemp`"
	cat<<EOF>"$t"
	H=$H
	I=$I
	L=$L
	D=$D
EOF
	mv "$t" "$STATEFILE"
}

savedir() {
	echo "$DIR" > "$DIRFILE"
}

STATEFILE="$1"
BDIR="$2"
DIR="$3"
DIRH="$4"
DIRFILE="$STATEFILE.d$DIRH"

test -f "$STATEFILE" && . "$STATEFILE"
test -f "$DIRFILE" && DIR="`cat "$DIRFILE"`"

case $5 in
	run|repeat)
		# run $QUERY [resume] | repeat
		case $5 in
			run)
				query="$6"
				echo "$query" > "$1.fd"
				if [ -z "$7" ]; then
					DIR="$3"
					savedir
				fi
				;;
			repeat)
				query="`cat "$1.fd"`"
				;;
		esac
		if [ -n "$H" ]; then f="$f --hidden"; fi
		if [ -n "$I" ]; then f="$f --no-ignore"; fi
		if [ -n "$L" ]; then f="$f --follow"; fi
		if [ -n "$D" ]; then f="$f -td"; else f="$f -tf -tl"; fi
		d="`realpath --relative-base="$BDIR" "$DIR"`"
		case "$d" in
			/*)
				rel2home "$DIR"
				bdir="$DIR"
				;;
			*)
				[ "$d" = "." ] && d=""
				echo "`rel2home "$BDIR"`\033[1m/$d\033[0m"
				bdir="$BDIR/$d"
				;;
		esac
		exec fd --color=always --base-directory "$bdir" $f -- "$query"
		;;
	prompt)
		if [ -n "$6" ]; then
			p="$6"
			echo "$p" > "$1.p"
		else
			p="`cat "$1.p"`"
			if [ -z "$p" ]; then
				p="fzf"
			fi
		fi
		flags="$H$I$L$D"
		if [ -n "$flags" ]; then
			echo -n "[$flags] $p>"
		else
			echo -n "$p>"
		fi
		;;
	toggle)
		case $6 in
			h)
				if [ -n "$H" ]; then H=; else H=h; fi
				;;
			i)
				if [ -n "$I" ]; then I=; else I=i; fi
				;;
			l)
				if [ -n "$L" ]; then L=; else L=l; fi
				;;
			d)
				if [ -n "$D" ]; then D=; else D=d; fi
				;;
		esac
		save
		;;
	dir)
		if [ -n "$6" ]; then
			# Override DIR.
			case "$DIR" in
				/*)
					d="$DIR/$6"
					;;
				*)
					d="$BDIR/$DIR/$6"
					;;
			esac
			if [ -d "$d" ]; then
				DIR="$d"
			elif [ -e "$d" ]; then
				DIR="`dirname "$d"`"
			fi
		else
			# Reset DIR to initial value.
			DIR="$3"
		fi
		savedir
		;;
	up)
		if [ "$DIR" = "." -o -z "$DIR" ]; then
			DIR="`realpath "$BDIR"`"
		fi
		DIR="`dirname "$DIR"`"
		savedir
		;;
	prefix)
		case "$DIR" in
			/*)
				echo "$DIR"
				;;
			*)
				echo "$BDIR/$DIR"
				;;
		esac
		;;
esac
