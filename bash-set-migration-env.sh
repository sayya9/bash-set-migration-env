#!/bin/bash
# Andrew

Usage() {
        printf "Usage: `basename $0` [-h|-e|-r mode]\n"
        printf "mode -> backup|remove|restore\n"
        exit 1
}

SavePerm() {
        local ProjHomePath=/home/$1
        local PermList=$ProjHomePath/.permlist.txt
        local OwnerList=$ProjHomePath/.ownerlist.txt
        local DirOwner=`stat -c %u /home/$1`
        local DirPerm=`stat -c %a /home/$1`

        if [ "$DirOwner" = "root" ] || [ "$DirPerm" = "000" ]; then
                printf "This account %s may be already saved permission\n" $ProjHomePath
                return `false`
        fi

        if [ -f "$PermList" ]; then
                rm -f $PermList
        fi

        if [ -f "$OwnerList" ]; then
                rm -f $OwnerList
        fi

        for i in `ls -a $ProjHomePath | grep -vE '(^\.$|^\..$|nobackup|\.snapshot)'`
        do
                echo `cd $ProjHomePath; stat -c %a $i` "'$i'" >> $PermList
                echo `cd $ProjHomePath; stat -c %U $i` "'$i'" >> $OwnerList
    done
}

RemovePerm() {
        local ProjHomePath=/home/$1
        local PermList=$ProjHomePath/.permlist.txt
        local OwnerList=$ProjHomePath/.ownerlist.txt

        if [ ! -f "$PermList" ] || [ ! -f "$OwnerList" ]; then
                printf "This account %s must run backup mode first\n" $ProjHomePath
                exit 1
        fi
        find $ProjHomePath -maxdepth 1 \! -name nobackup | xargs chown -h root
        find $ProjHomePath -maxdepth 1 \! -name nobackup | xargs chmod 000
}

RestorePerm() {
        local t=$(ypcat -k auto.home | grep "$1 " | awk '{print $NF}' | sed 's/://')
        local DstPath=$(printf "/net/$t")
        local PermList=$DstPath/.permlist.txt
        local OwnerList=$DstPath/.ownerlist.txt
        local Owner=`stat -c %G $DstPath`

	echo restore mode
	if [ ! -f "$PermList" ] || [ ! -f "$OwnerList" ]; then
		printf "%s or %s: No such file\n" $PermList $OwnerList
		exit 1
	fi

	while read line
	do
		cd $DstPath && eval chmod $line
	done < $PermList

	while read line
	do
		cd $DstPath && eval chown -h $line
	done < $OwnerList

	chown $Owner $DstPath
	chmod 3770 $DstPath
}

filePath=/home/andrew/data/migration_acc.txt
opt=$(getopt -o ehr: -l edit,help,run: -n set-migration-env.sh -- "$@")

if [ "$?" != 0 ]; then
        Usage
        exit 1
fi
eval set -- "$opt"

while true; do
        case "$1" in
                -e|--edit)
                        vim $filePath
                        shift
                        break
                        ;;
                -r|--run)
                        case "$2" in
                                backup)
                                        while read acc; do
                                                SavePerm $acc
                                        done < $filePath
                                        break
                                        ;;
                                remove)
                                        while read acc; do
                                                RemovePerm $acc
                                        done < $filePath
                                        break
                                        ;;
                                restore)
                                        while read acc; do
                                                RestorePerm $acc
                                        done < $filePath
                                        break
                                        ;;
                                *)
                                        printf "error\n"
                                        ;;
                        esac
                        shift 2
                        break
                        ;;
                -h|--help)
                        Usage
                        break
                        ;;
                --)
                        shift
                        break
                        ;;
                *)
                        echo "Internal error!"
                        exit 1
                        ;;
        esac
done
