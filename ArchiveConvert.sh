#!/bin/bash
#
#       ArchiveConvert.sh
#
#       Version: 2.2.1
#
#       Copyright 2010  - 2018 Claudio Giordano <claudio.giordano@autistici.org>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 3 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

clear
IFS='
'
# Default Archiver
# zip -0 no compression
# zip -9 max compression
# -6 default compression
archiver="zip -q -r" # -q quiet
destextension=".cbz"
#testcmd="zip -T"
testcmd="7z t"

function Usage()
{
	echo -e "Usage: `basename $0` [ OPTIONS ] [ FILES ]"
	echo -e "\t -d \t\t Delete source file after conversion."
	echo -e "\t -f TYPE \t Compression type ( default zip )"
	echo -e "\t -u PATH \t Join archives"
	echo -e "\t -v \t\t Verbose output"
    echo -e "\t -a \t\t Archiver command"
    echo -e "\t -e \t\t Destination extension"
}

if [ $# -eq 0 ]
then
	#~ echo "Empty Args, exit."
	Usage
	exit 1
fi

while getopts ":f:u:dva:e:" Options
do
	# Check Args:

  case $Options in
		d)
			DELETESOURCE="yes"
		;;

		f)
			if [[ $OPTARG =~ "^-.*" || $OPTARG == "0" ]]
			then
				echo -e "Missing required argument to the -f parameter, Exit."
				Usage
				exit 1
			else
				ARCHIVETYPE=$OPTARG
			fi
		;;

		u)
			if [[ $OPTARG =~ "^-.*" || $OPTARG == "0" ]]
			then
				echo -e "Missing required argument to the -u parameter, Exit."
				Usage
				exit 1
			else
				if [ $OPTARG != "/" ]
				then
					JOINED=$OPTARG
				else
					#echo -e "[Debug]: il percorso e' relativo lo correggo"
					JOINED="$(pwd)/$OPTARG"

					echo -e "Richiesto percorso assoluto per il file, esco.\n$OPTARG\n"
					Usage
					exit 1
				fi

				echo -e "[Debug]: JOINED: $JOINED"
			fi
		;;

        a)
            if [[ $OPTARG =~ "^-.*" || $OPTARG == "0" ]]
			then
                echo -e "Missing required argument to the -a parameter, Exit."
				Usage
				exit 1
			else
                #echo -e "New archiver: $OPTARG"
                archiver=$OPTARG
            fi
        ;;

        e)
            if [[ $OPTARG =~ "^-.*" || $OPTARG == "0" ]]
			then
                echo -e "Missing required argument to the -e parameter, Exit."
				Usage
				exit 1
			else
                #echo -e "destextension: $OPTARG"
                destextension=$OPTARG
            fi
        ;;


        v)
			VERBOSE="yes"
			#archiver="zip -r"
            archiver="$archiver"
		;;

		*)
			Usage
			exit 0
		;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -eq 0 ]
then
	echo "No files specified, exit."
	Usage
	exit 1
fi


# todo: scelta archivio di destinazione
# todo: scelta livello di compressione -l level
# todo: file di log
# todo: passaggio come argomento del tipo/livello di compressore
# todo: aggiungere a selectunarchiver la selezione del tipo di test dell'archivo
# todo: terzo array con le dimensioni originali dei file
# todo: -u unione archivi richiede nome file:
# - nome/percorso come argomento
# - lista archivi
# - estrazione singolo archivio
# - aggiunta all'archivio completo
# - rimozione file temp



function SelectUnArchiver ()
{
	unarchiver=""

	if [ ! -z "$1" ]
	then
		TestFile=$1
		# Get file mime-type:
		ftype=$(file --brief --mime-type $TestFile)
		#~ echo -e "[Debug] ftype: $ftype"

		case $ftype in
			'application/zip')
				if [ -e "/usr/bin/unzip" ]
				then
					if [ $VERBOSE ]
					then
						unarchiver="/usr/bin/unzip \"$1\" -d "
					else
						unarchiver="/usr/bin/unzip -q \"$1\" -d "
					fi
				else
					unarchiver=""
				fi
				;;

			'application/x-bzip2')
				if [ -e "/bin/tar" ]
				then
					unarchiver="/bin/tar xjf \"$1\" -C "
				else
					unarchiver=""
				fi
				;;

			'application/x-gzip')
				if [ -e "/bin/tar" ]
				then
					unarchiver="/bin/tar xzf $\"$1\" -C "
				else
					unarchiver=""
				fi
				;;

			'application/x-tar')
				if [ -e "/bin/tar" ]
				then
					unarchiver="/bin/tar xf \"$1\" -C "
				else
					unarchiver=""
				fi
				;;

			'application/x-rar')
				#~ if [ -e "/usr/bin/unrar" ]
				if [ -e "/usr/bin/unrar" ]
				then
					if [ $VERBOSE ]
					then
						unarchiver="/usr/bin/unrar x \"$1\" "
						#~ unarchiver="/usr/bin/unar \"$1\" -o "
					else
						unarchiver="/usr/bin/unrar -inul x \"$1\" " # opzione incompatibile  con unrar-free
						#~ unarchiver="/usr/bin/unrar x \"$1\" "
						#~ unarchiver="/usr/bin/unar \"$1\" -o "
					fi
				else
					unarchiver=""
				fi
				;;

			'application/x-7z-compressed')
				if [ -e "/usr/bin/7z" ]
				then
					if [ $VERBOSE ]
					then
						unarchiver="/usr/bin/7z x \"$1\" -o"
					else
						unarchiver="/usr/bin/7z x \"$1\" -o"
					fi
				else
					unarchiver=""
				fi
				;;

			*)
				unarchiver=""
				;;
		esac
	fi
}


function CreateConversionList ()
{
	# generate array for conversion list
	i=0
	for FileArg in $*
	do
		if [ ${FileArg:0:1} != "/" ]
		then
			FilePath="$(pwd)/$FileArg"
		else
			FilePath=$FileArg
		fi

		# if file exist and is supported add to array FilesList:
		if [ -e $FilePath ]
		then
			#~ echo "il file $FilePath esiste"
			FilesList[$i]=$FilePath
			SelectUnArchiver "$FilePath"
			UnArchiverList[$i]=$unarchiver
			#~ echo -e "[Debug] unarchiver: "${ArchiverList[$i]}

			let i=$i+1
		else
			echo -e "\033[1;31mFile \"$FilePath\" doesn't exist, skipped.\033[0m"
		fi
	done

	# Print conversion parameters:
	echo -e "     Archiver: $archiver"
	echo -e "Delete Source: $DELETESOURCE"
	echo -e "       Format: $ARCHIVETYPE"
	echo -e "       Joined: $JOINED"
	echo -e "      Verbose: $VERBOSE"
    echo -e "    Extension: $destextension"
	echo

	# print and confirm conversion list:
	i=0
	a=1
	#~ echo -e "--- Conversion List ---"
	while [ $i -lt ${#FilesList[*]} ]
	do
		#~ echo "File: [$i] ${FilesList[$i]}"
		#~ echo "UnArchiverList[$i]:  ${UnArchiverList[$i]}"
		if [ ${UnArchiverList[$i]} ]
		then
			ConvertStatus="\033[1;32m Supported \033[0m"
		else
			ConvertStatus="\033[1;31mUnsupported\033[0m"
		fi

		echo -e "[\033[1;36m$a\033[0m][$ConvertStatus] `basename ${FilesList[$i]}`"

		let i=$i+1
		let a=$a+1
	done

	#~ echo "count: ${#UnArchiverList[*]}"

	if [ ${#UnArchiverList[*]} -eq 0 ]
	then
		echo "No file for conversion, exit"
		exit 1
	fi

	selected_resp="no"
	while [ $selected_resp == "no" ]
	do
		echo ""
		read -p "Start archives conversion? [y/n]: " resp
		case $resp in
			y | yes | s | si )
				selected_resp="yes"
				StartConversion
			;;

			n | no )
				echo "Conversion aborted."
				exit 2
			;;

			* )
				echo "insert only y/yes/s/si/n/no"
			;;
		esac
	done
}

function StartConversion ()
{
	clear
	echo -e "\033[1;32mStarting conversion... \033[0m"

	i=0
	a=1
	tot_pass=0

	#~ echo "count: ${#FilesList[*]} "
	unit=$[100/${#FilesList[*]}]
	if [ $DELETESOURCE ]
	then
		pass=$[$unit/6]
	else
		pass=$[$unit/5]
	fi

	#~ echo " unit: $unit"
	#~ echo " pass: $pass"

	while [ $i -lt ${#UnArchiverList[*]} ]
	do
		# if supported archive:
		if [ "${UnArchiverList[$i]}" != "" ]
		then
			# TODO: test source archive integrity

			let tot_pass=$tot_pass+$pass
			# Make tempdir for unpacking archive:
			if TMPDIR=$(mktemp --directory)
			then
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m  Make TempDir  \033[0m] `basename ${FilesList[$i]}`"
				if [ $VERBOSE ]
				then
					echo "created temp dir to $TMPDIR"
				fi
			else
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m  Make TempDir  \033[0m] `basename ${FilesList[$i]}`"
				if [ $VERBOSE ]
				then
					echo "failed to create temp dir to $TMPDIR"
				fi
				exit 1
			fi

			let tot_pass=$tot_pass+$pass
			#~ # Extract file to temp dir and cd in:
			if [ $VERBOSE ]
			then
				echo -e "[Debug]: Unarchiver Command ${UnArchiverList[$i]} $TMPDIR";
				echo "Unarchiver Command: ${UnArchiverList[$i]} $TMPDIR"
			fi

			if eval "${UnArchiverList[$i]}$TMPDIR"
			then
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m   Extracting   \033[0m] `basename ${FilesList[$i]}`"

				cd $TMPDIR
			else
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m   Extracting   \033[0m] `basename ${FilesList[$i]}`"
				exit 1
			fi

			let tot_pass=$tot_pass+$pass
			# Recompression of the archive in the format chosen, into the source folder.
			if [ $JOINED ]
			then
				newfilename=$JOINED
				archiver="$archiver --grow"
			else
				newfilename=${FilesList[$i]%\.*}$destextension
			fi

			compresscmd="$archiver \"$newfilename\" *"
			if [ $VERBOSE ]
			then
				echo "CompressCmd: $compresscmd"
			fi

			if eval "$compresscmd"
			then
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m Recompressing  \033[0m] `basename ${FilesList[$i]}`"
			else
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m Recompressing  \033[0m] `basename ${FilesList[$i]}`"
				exit 1
			fi

			let tot_pass=$tot_pass+$pass
			# check the integrity of the new archive
			if eval "$testcmd \"$newfilename\" > /dev/null 2>&1"
			then
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m    Testing     \033[0m] `basename ${FilesList[$i]}`"
			else
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m    Testing     \033[0m] `basename ${FilesList[$i]}`"
				exit 1
			fi
			# back to previous folder:
			#~ echo -e "\033[1;33mback to previous folder\033[0m"
			cd - > /dev/null 2>&1

			let tot_pass=$tot_pass+$pass
			# Remove temp dir after operation:
			if eval "rm -rf $TMPDIR"
			then
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m Remove TempDir \033[0m] `basename ${FilesList[$i]}`"
			else
				echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m Remove TempDir \033[0m] `basename ${FilesList[$i]}`"
				exit 1
			fi

			# Remove source archive
			if [ $DELETESOURCE ]
			then
				let tot_pass=$tot_pass+$pass
				#~ echo -e "[Debug]: ${FilesList[$i]}";
				if eval "rm -f \"${FilesList[$i]}\""
				then
					echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;32m Remove Source  \033[0m] `basename ${FilesList[$i]}`"
				else
					echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m Remove Source  \033[0m] `basename ${FilesList[$i]}`"
					exit 1
				fi
			fi

			echo -e "New archive \033[1;32m\"`basename $newfilename`\"\033[0m created succesfully."
		else
			echo -e "[\033[1;36m$tot_pass%\033[0m][\033[1;31m    Skipped     \033[0m] `basename ${FilesList[$i]}`"
		fi

		let i=$i+1
		let a=$a+1
		echo
	done

	echo -e "\033[1;32mEnd conversion. \033[0m"
}


# main
CreateConversionList $*


exit 0

