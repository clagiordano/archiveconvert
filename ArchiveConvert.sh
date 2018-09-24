#!/bin/bash
#
#       ArchiveConvert.sh
#
#       Copyright 2010 Claudio Giordano <claudio.giordano@autistici.org>
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
#~ echo -e "[Debug]: ARGV: "$*"\n"
archiver="zip -r" # -q quiet
destextension=".cbz"
testcmd="zip -T"

# todo: scelta archivio di destinazione
# todo: scelta livello di compressione
# todo: file di log
# todo: verboso o no

i=1
for file in $*
do
	echo -e "Start processing file: \033[1;32m$file\033[0m"

	# if is passed a relative path convert it with pwd/path:
	if [ ${file:0:1} != "/" ]
	then
		file="$(pwd)/$file"
	fi

	# Make tempdir for unpacking archive:
	echo -e "\033[1;33mCreate temporary folder... \033[0m"
	if tmpdir=$(mktemp --directory)
	then
		echo -e "\033[1;32mtemporary folder created successfully $tmpdir.\033[0m"
	else
		echo -e "\033[1;31mcreation temporary folder failed, abort operation.\033[0m"
		exit 1
	fi

	# Check if file exists:
	if [ -e $file ]
	then
		# Get file mime-type:
		ftype=$(file --brief --mime-type $file)

		case $ftype in
			'application/zip')
				unarchiver="/usr/bin/unzip \"$file\" -d $tmpdir" # -q quiet
				;;

			'application/x-bzip2')
				unarchiver="/bin/tar xjf \"$file\" -C $tmpdir"
				;;

			'application/x-gzip')
				unarchiver="/bin/tar xzf $\"$file\" -C $tmpdir"
				;;

			'application/x-tar')
				unarchiver="/bin/tar xf \"$file\" -C $tmpdir"
				;;

			'application/x-rar')
				unarchiver="/usr/bin/unrar x \"$file\" $tmpdir" # -inul  Disable all messages.
				;;

			'application/x-7z-compressed')
				unarchiver="/usr/bin/7z x \"$file\" -o$tmpdir"
				;;
			*)
				unarchiver=""
				;;
		esac

		#~ echo -e "\t[Debug]: unarchiver: $unarchiver";

		# se la variabile unarchiver non è impostata allora
		# salta gli altri passaggi dato che il file non e' supportato.
		if [ $unarchiver ]
		then
			# Extract archive to tempdir
			echo -e "\033[1;33mExtracting archive to tempdir... \033[0m";
			#~ echo -e "[Debug]: extract: $unarchiver"
			if eval "$unarchiver"
			then
				echo -e "\033[1;32mextraction completed.\033[0m"

				# Change dir to tempdir
				echo -e "\033[1;33mChange dir to tempdir $tmpdir.\033[0m"
				cd $tmpdir

				# Recompression of the archive in the format chosen, into the source folder.
				echo -e "\033[1;33mRecompression of the archive in the format chosen, into the source folder ...\033[0m"
				newfilename=${file%\.*}$destextension
				compresscmd="$archiver \"$newfilename\" *"
				#~ echo -e "[Debug]: compresscmd: $compresscmd";

				if eval "$compresscmd"
				then
					echo -e "\033[1;32mRecompression completed.\033[0m"

					# check the integrity of the new archive
					echo -e "\033[1;33mcheck the integrity of the new archive ...\033[0m"
					if eval "$testcmd \"$newfilename\""
					then
						echo -e "\033[1;32mThe new archive is ok.\033[0m"
					else
						echo -e "\033[1;31mThe new archive seems be corrupt.\n\tOld File: $file\n\tNew File: $newfilename\033[0m"
					fi

					# back to previous folder:
					echo -e "\033[1;33mback to previous folder\033[0m"
					cd -

					# Remove temp dir after operation:
					echo -e "\033[1;33mRemoving temporary folder $tmpdir ...\033[0m"
					rm -rf $tmpdir
					echo -e "\033[1;32mtemporary folder removed successfully.\033[0m"
				else
					echo -e "\033[1;31mError during the recompression.\033[0m"
				fi
			else
				echo -e "\033[1;31mError during the extraction.\033[0m"
			fi
		else
			echo -e "\033[1;31mUnsupported file type: $file, skipped\033[0m"
		fi
	else
		echo -e "\033[1;31mThe file: $file doesn't exist, skipped.\033[0m"
	fi

	echo
done

echo -e "\033[1;32mAll operations completed successfully.\033[0m"

exit 0

