#!/bin/bash

function show_help {
	echo "Usage: ${0##*/} [-h] -c config_file [-g] [-i id6] [-l] [-r root_path]

Fetch covers for saved roms, or even for a rom ID6 if specified

options:
  -h      show this help message and exit
  -c      set config_file
  -g      generate config_file
  -i      run only for this id6
  -l      use lowres full covers
  -r      set root_dir"
}

function err () {
	echo "ERROR: $1" >&2
	[ -z "$2" ] || "$2" >&2
	exit 1
}

function err_help () {
	err "$1" show_help
}

function parse_opts {
	local opt OPTARG
	if [[ "$@" == '' ]]; then
		show_help_gen
		exit 0
	fi
	while getopts hc:gi:ls: opt; do
		case $opt in
			h)
				show_help
				exit 0
			;;
			c)
				config_file="$OPTARG"
			;;
			g)
				generate_cfile=true
			;;
			i)
				id6="$OPTARG"
			;;
			l)
				fullcov_array=(coverfull)
			;;
			r)
				root_dir="$OPTARG"
			;;
			\?)
				echo "Unknown option: -$OPTARG" >&2
				exit 1
			;;
			:)
				echo "Missing option argument for -$OPTARG" >&2
				exit 1
			;;
			*)
				err_help "Unimplemented option: -$opt"
			;;
		esac
	done
	[ -z "$config_file" ] && err_help "config_file must be set with -c or WII_COVERS_CONFIG"
}

generate_cfile () {
	read -p "Enter disk root directory path: " root_dir
	read -p "Enter covers root directory path: " covers_root_dir
	read -p "Enter preferred locales in order of preference [Example: DE,EN]: " locales
	read -p "Enter wbfs directory path: " wbfs_dir
	read -p "Enter normal covers path: " covers_path
	read -p "Enter 3d covers path: " covers_path_3d
	read -p "Enter disc covers path: " covers_path_disc
	read -p "Enter full covers path: " covers_path_full
	echo "# WiiCoversUpdate Config
root_dir=$root_dir
wbfs_dir=$wbfs_dir
locales=$locales
covers_root_dir=$covers_root_dir
covers_path=$covers_path
covers_path_3d=$covers_path_3d
covers_path_disc=$covers_path_disc
covers_path_full=$covers_path_full" > "$config_file"
}

parse_cfile () {
	while IFS== read -r key value; do
		case $key in
			\#*) continue ;;
			root_dir|wbfs_dir|locales|covers_root_dir|covers_path|covers_path_3d|covers_path_disc|covers_path_full)
				eval "${key}=\"${value}\""
			;;
			*) err "Unrecognized: $key" ;;
		esac
	done < "$1"
	[ -z "$covers_root_dir" ] && err "Missing covers_root_dir in settings file"
	[ -z "$covers_path" ] && err "Missing covers_path in settings file"
}

create_config_dir () {
	if [ ! -d "${config_file%\/*}" ]; then
		echo "Creating config parent folder: ${config_file%\/*}"
		mkdir -p "${config_file%\/*}" || err_help "Cannot create config parent folder"
	fi
}

create_dirs () {
	local i
	for i in "$covers_path" "$covers_path_3d" "$covers_path_disc" "$covers_path_full"; do
		[ -d "$covers_root_dir/$i" ] && continue
		echo "Creating covers folder: $covers_root_dir/$i"
		mkdir -p "$covers_root_dir/$i" || err_help "Cannot create this covers folder"
	done
}

check_cover () {
	[ "$2" = "$covers_root_dir//$1.png" ] && return 1
	[ -f "$2" ] && return 1
	return 0
}

check_cover_url () {
	local url="https://art.gametdb.com/wii/${1}/${2}/${3}.png"
	wget -q -nc --method HEAD "${url}" || return 1
}

download_cover () {
	local url="https://art.gametdb.com/wii/${1}/${2}/${3}.png"
	wget "${url}" -O "${4}"
}

update_rom_disccover () {
	local type
	for type in disc disccustom disccustomB; do
		check_cover_url "$type" "$1" "$2" || continue
		download_cover "$type" "$1" "$2" "$3"
		break
	done
}

update_rom_fullcover () {
	local type
	for type in "${fullcov_array[@]}"; do
		check_cover_url "$type" "$1" "$2" || continue
		download_cover "$type" "$1" "$2" "$3"
		break
	done
}

update_rom_covers () {
	local locale
	local rom_covers=(
		"$covers_root_dir/$covers_path/$1.png"
		"$covers_root_dir/$covers_path_3d/$1.png"
		"$covers_root_dir/$covers_path_disc/$1.png"
		"$covers_root_dir/$covers_path_full/$1.png"
	)
	for locale in ${locales//,/ }; do
		check_cover_url cover "$locale" "$1" || continue
		check_cover "$1" "${rom_covers[0]}" && download_cover cover "$locale" "$1" "${rom_covers[0]}"
		check_cover "$1" "${rom_covers[1]}" && check_cover_url cover3D "$locale" "$1" && \
			download_cover cover3D "$locale" "$1" "${rom_covers[1]}"
		check_cover "$1" "${rom_covers[2]}" && update_rom_disccover "$locale" "$1" "${rom_covers[2]}"
		check_cover "$1" "${rom_covers[3]}" && update_rom_fullcover "$locale" "$1" "${rom_covers[3]}"
		break
	done
}

update_roms_covers () {
	local fpath gname
	if [ -d "$root_dir/$wbfs_dir" ]; then
		for fpath in "$root_dir/$wbfs_dir"/*/*.wbfs; do
			[ -f "$fpath" ] || continue
			gname="${fpath%\/*}"
			gname="${gname##*\/}"
			echo "Fetching covers for: $gname"
			update_rom_covers "$(wit ID6 "$fpath")"
		done
	else
		err "WBFS folder not found"
	fi
}

function main () {
	local config_file="${config_file:-$WII_COVERS_CONFIG}" generate_cfile=false fullcov_array=(coverfullHQ coverfull)
	local root_dir wbfs_dir locales covers_root_dir covers_path covers_path_3d covers_path_disc covers_path_full
	parse_opts "$@"
	[ ! -d "${config_file%\/*}" ] && ! mkdir -p "${config_file%\/*}" && \
		err_help "Cannot create config parent folder ${config_file%\/*}"
	if $generate_cfile; then
		generate_cfile
		return 0
	fi
	create_config_dir
	parse_cfile "$config_file"
	create_dirs
	[ -z "$id6" ] && update_roms_covers || update_rom_covers "${id6^^}"
}

main "$@"
