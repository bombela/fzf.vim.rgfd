#!/bin/sh
# Usage: rg.sh state_file base_dir rel_dir cmd [arg]
test -f $1 && . $1
cmd="rg --column --no-heading --color=always -S"
case $4 in
	run|repeat)
		case $4 in
			run)
				query="$5"
				echo "$query" > "$1.fd"
				;;
			repeat)
				query="`cat "$1.fd"`"
				;;
		esac
		if [ -n "$H" ]; then f="$f --hidden"; fi 
		if [ -n "$I" ]; then f="$f --no-ignore"; fi 
		if [ -n "$B" ]; then f="$f --text"; fi 
		if [ -n "$L" ]; then f="$f -L"; fi 
		if [ -n "$BDIR" ]; then bdir="$BDIR"; else bdir="$2"; fi 
		if [ -n "$RDIR" ]; then rdir="$RDIR"; else rdir="$3"; fi 
		if [ -z "$BDIR" ]; then
			echo "$rdir"
		else
			echo "($bdir)/$rdir"
		fi
		cd "$bdir"
		if [ -n "$rdir" ]; then
			$cmd $f -- "$query" "$rdir"
		else
			$cmd $f -- "$query"
		fi
		exit 0
		;;
	prompt)
		if [ -n "$5" ]; then
			P="$5"
		fi
		flags="$H$I$B$L"
		if [ -n "$flags" ]; then
			echo -n "[$flags] $P>"
		else
			echo -n "$P>"
		fi
		;;
	toggle)
		case $5 in
			h)
				if [ -n "$H" ]; then H=; else H=h; fi 
				;;
			i)
				if [ -n "$I" ]; then I=; else I=i; fi 
				;;
			b)
				if [ -n "$B" ]; then B=; else B=b; fi 
				;;
			l)
				if [ -n "$L" ]; then L=; else L=l; fi 
				;;
		esac
		;;
	rdir)
		if [ -n "$5" ]; then
			RDIR="$5"
			BDIR=""
		else
			RDIR=""
			BDIR=""
		fi
		;;
	up)
		if [ -z "$RDIR" ]; then RDIR="$3"; fi 
		if [ "$RDIR" = "." -o -z "$RDIR" ]; then
			if [ -n "$BDIR" ]; then bdir="$BDIR"; else bdir="$2"; fi 
			RDIR="`realpath --relative-base="$HOME" "$bdir"`"
			if [ "$RDIR" = "." ]; then
				RDIR="`realpath "$bdir"`"
				BDIR="/"
			else
				BDIR="$HOME"
			fi
		fi
		RDIR="`dirname "$RDIR"`"
		;;
esac

cat<<EOF>$1
P=$P
H=$H
I=$I
B=$B
L=$L
RDIR="$RDIR"
BDIR="$BDIR"
