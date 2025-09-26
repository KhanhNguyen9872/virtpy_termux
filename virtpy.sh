#!/data/data/com.termux/files/usr/bin/bash

green='\033[1;92m'
red='\033[1;31m'
yellow='\033[1;33m'
blue='\033[1;34m'
reset='\033[0m'
orange='\33[38;5;208m'
light_cyan='\033[1;96m'

if [[ "$(id -u 2>/dev/null)" == "0" ]]; then
    is_force=0
    for i in $@; do
        if [[ "$i" == "--force-root" ]]; then
            is_force=1
        fi
    done
    if [[ "$is_force" == "0" ]]; then
        printf "virtpy don't need root permission! run on root permission may destroy your system if this is malware script\nif you want run on root permission, use --force-root\n\n"
        exit 64
    fi
fi


if [[ "$1" == "--virtpy-help" ]] 2>/dev/null; then
    echo "${0} [launch python shell]"
    echo "${0} file.py [execute python file]"
    echo "${0} --virtpy-limit (size MB) [virtpy limit memory]"
    echo "${0} --virtpy-settings [virtpy settings]"
    echo "${0} --virtpy-help [virtpy help]"
    echo "${0} --virtpy-uninstall [virtpy uninstall]"
    echo "${0} --force-root [force run virtpy in root]"
    echo "${0} --virtpy-reinstall [virtpy reinstall]"
    exit 0
fi

if [[ "$1" == "--virtpy-uninstall" ]]; then
    installed_versions=()
    [[ -d "/data/data/com.termux/virtpy" ]] && installed_versions+=("3.11")
    [[ -d "/data/data/com.termux/virtpy_312" ]] && installed_versions+=("3.12")

    if [[ ${#installed_versions[@]} -eq 0 ]]; then
        echo "No virtpy installation found."
        exit 0
    fi

    echo "Installed versions:"
    for v in "${installed_versions[@]}"; do
        echo " - $v"
    done
    echo " A) Uninstall ALL versions"
    printf "\nChoose version to uninstall [${installed_versions[*]} / A]: "
    read choose

    case "$choose" in
        "3.11")
            rm -rf /data/data/com.termux/virtpy 2>/dev/null
            echo "Uninstalled Python 3.11 (virtpy)"
            ;;
        "3.12")
            rm -rf /data/data/com.termux/virtpy_312 2>/dev/null
            echo "Uninstalled Python 3.12 (virtpy_312)"
            ;;
        "A"|"a")
            rm -rf /data/data/com.termux/virtpy* 2>/dev/null
            rm -rf /data/data/com.termux/files/usr/bin/virtpy* 2>/dev/null
            rm -rf /data/data/com.termux/files/usr/bin/virtpip* 2>/dev/null
            echo "All versions uninstalled!"
            ;;
        *)
            echo "Cancelled."
            ;;
    esac
    exit 0
fi

if [[ "$1" == "--virtpy-reinstall" ]]; then
    bash -c "$(curl -L --max-redirs 15 https://raw.githubusercontent.com/KhanhNguyen9872/virtpy_termux/main/script_install.sh)"
    exit 0
fi

# ==== Choose installed Python version ====
installed_versions=()
[[ -d "/data/data/com.termux/virtpy" ]] && installed_versions+=("3.11")
[[ -d "/data/data/com.termux/virtpy_312" ]] && installed_versions+=("3.12")

if [[ ${#installed_versions[@]} -eq 0 ]]; then
    echo "${red}No virtpy installation found. Please run install.sh first.${reset}"
    exit 1
elif [[ ${#installed_versions[@]} -eq 1 ]]; then
    case "${installed_versions[0]}" in
        "3.11") virt_path="/data/data/com.termux/virtpy" ;;
        "3.12") virt_path="/data/data/com.termux/virtpy_312" ;;
    esac
else
    # Nếu đang setup env (chưa có file .virtpy trong bất kỳ phiên bản nào) → chọn version mặc định là phiên bản đầu tiên
    need_setup=1
    for v in "${installed_versions[@]}"; do
        case "$v" in
            "3.11") check_path="/data/data/com.termux/virtpy/usr/etc/.virtpy" ;;
            "3.12") check_path="/data/data/com.termux/virtpy_312/usr/etc/.virtpy" ;;
        esac
        if [[ -f "$check_path" ]]; then
            need_setup=0
        fi
    done

    if [[ $need_setup -eq 1 ]]; then
        # Đang setup env lần đầu → chọn 3.11 nếu có, nếu không thì 3.12
        if [[ " ${installed_versions[*]} " =~ "3.11" ]]; then
            virt_path="/data/data/com.termux/virtpy"
        else
            virt_path="/data/data/com.termux/virtpy_312"
        fi
    else
        # Bình thường thì cho phép chọn
        echo "Multiple Python versions detected:"
        select ver in "${installed_versions[@]}"; do
            case $ver in
                "3.11") virt_path="/data/data/com.termux/virtpy"; break ;;
                "3.12") virt_path="/data/data/com.termux/virtpy_312"; break ;;
                *) echo "Invalid choice" ;;
            esac
        done
    fi
fi
# =========================================

user_termux="$(whoami)"
working_dir="$(pwd)"

## CONFIG
data_config="$(cat "${virt_path}.conf")"
if [[ "$(printf "$data_config" | grep 'mount_termux_dir' | head -n 1 | sed 's/=/ /' | awk '{print $2}')" == "1" ]] 2>/dev/null; then
    mount_termux_dir=1
    name_mount_termux_dir="${red}ENABLED${reset}"
else
    mount_termux_dir=0
    name_mount_termux_dir="${green}DISABLED${reset}"
fi
if [[ "$(printf "$data_config" | grep 'disable_mount_dir' | head -n 1 | sed 's/=/ /' | awk '{print $2}')" == "1" ]] 2>/dev/null; then
    disable_mount_dir=1
    name_disable_mount_dir="${red}ENABLED${reset}"
else
    disable_mount_dir=0
    name_disable_mount_dir="${green}DISABLED${reset}"
fi
#####
## CHECK ARG

if [ ! -f ${virt_path}/usr/bin/bash ] || [ ! -d ${virt_path}/bin ]; then
    printf "${red}virtpy has been destroyed\nPlease reinstall virtpy, using ${0} --virtpy-reinstall${reset}\n"
    exit 64
fi

if [[ "$1" == "--virtpy-settings" ]] 2>/dev/null; then
    function replace_settings() {
        sed -i "/${1}=/d" "${virt_path}.conf"
        printf "\n${1}=${2}" >> "${virt_path}.conf"
    }
    keep="1"
    virt_version="unknown"
    [[ "$virt_path" == "/data/data/com.termux/virtpy" ]] && virt_version="Python 3.11"
    [[ "$virt_path" == "/data/data/com.termux/virtpy_312" ]] && virt_version="Python 3.12"

    while [[ "$keep" == "1" ]] 2>/dev/null; do 
        clear
        printf "${light_cyan}> VIRTPY SETTINGS (${virt_version}) <${reset}\n"
        printf "${yellow}1. ${orange}Mount Termux Dir (com.termux/files) ${reset}[${name_mount_termux_dir}]\n"
        printf "${yellow}2. ${orange}Disable Mount Dir (Option 2) ${reset}[${name_disable_mount_dir}]\n"
        printf "${yellow}3. ${orange}Block website (domain name)\n"
        printf "${yellow}0. ${orange}Exit\n\n"
        printf "${light_cyan}>> Choose: ${green}"
        read choose
        printf "${reset}"
        case "$choose" in 
            1)
                if [[ "$mount_termux_dir" == "1" ]] 2>/dev/null; then
                    replace_settings "mount_termux_dir" "0"
                    name_mount_termux_dir="${green}DISABLED${reset}"
                    mount_termux_dir="0"
                else
                    replace_settings "mount_termux_dir" "1"
                    name_mount_termux_dir="${red}ENABLED${reset}"
                    mount_termux_dir="1"
                fi  
            ;;
            2)
                if [[ "$disable_mount_dir" == "1" ]] 2>/dev/null; then
                    replace_settings "disable_mount_dir" "0"
                    name_disable_mount_dir="${green}DISABLED${reset}"
                    disable_mount_dir="0"
                else
                    replace_settings "disable_mount_dir" "1"
                    name_disable_mount_dir="${green}ENABLED${reset}"
                    disable_mount_dir="1"
                fi  
            ;;
            3)
                clear
                touch "${virt_path}/../blacklist.txt"
                printf "\n${light_cyan}> You choose [Block website (domain name)]\n"
                printf "${orange}! You must add the domain name for each line !${reset}\n"
                printf "${orange}Example:\n"
                printf "${orange}    api.telegram.org\n    google.com\n    youtube.com\n\n${reset}"
                printf "${red} You can using [Ctrl + X] -> Y to save file in nano${reset}\n"
                printf "${yellow}> Do you want to continue? [Y/*]: ${green}"
                read choose
                if [[ "$choose" == "y" ]] || [[ "$choose" == "Y" ]]; then
                    nano "${virt_path}/../blacklist.txt"
                fi
            ;;
            0)
                keep="0"
                break
            ;;
        esac
    done
    clear
    exit 0
fi

# if [[ "$(pgrep virtpy 2>/dev/null | sed "/$$/d")" == "" ]]; then
#     2>/dev/null
# else
#     printf "${red}\nFound virtpy running!\nSome feature may not work correctly when running multiple instance\n\n${yellow}> Do you want to running another instance of virtpy? [Y/*]: ${green}"
#     read choose
#     if [[ "$choose" == "y" ]] || [[ "$choose" == "Y" ]]; then
#         2>/dev/null
#     else
#         printf "\n"
#         exit 0
#     fi
# fi

#####
printf " > virtpy is loading....\r"

cmd_root=" /usr/bin/env -i"
cmd_root+=" HOME=${HOME}"
cmd_root+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
cmd_root+=" TERM=$TERM"
cmd_root+=" LANG=en-US.UTF-8"

unset LD_PRELOAD
command="proot"
command+=" -k 4.14.81"
command+=" --kill-on-exit"
command+=" --link2symlink"
command+=" -0"
command+=" -r ${virt_path}"
command+=" -b /dev:/dev"
command+=" -b /proc:/proc"
command+=" -b /sys:/sys"
command+=" -b ${virt_path}:/system"
command+=" -b ${virt_path}:/vendor"
command+=" -b ${virt_path}:/product"
command+=" -b ${virt_path}:/system_ext"
command+=" -b ${virt_path}:/cust"
command+=" -b ${virt_path}:/apex"
command+=" -b ${virt_path}:/odm"

command+=" -b ${virt_path}/sdcard:/storage/self/primary"
command+=" -b ${virt_path}/sdcard:/storage/emulated/0"

if [[ "$(pgrep virtpy)" == "" ]]; then
    for i in "data" "sdcard" "data/data/com.termux/files/home" "data/data/com.termux/files/usr"; do
        rm -rf "${virt_path}/${i}/"* 2>/dev/null
    done
fi

if [ ! -d "${virt_path}/data/data/com.termux/files/home" ] 2>/dev/null || [ ! -d "${virt_path}/data/data/com.termux/files/usr" ] 2>/dev/null; then
    mkdir -p "${virt_path}/data/data/com.termux/files/home" 2>/dev/null
    mkdir -p "${virt_path}/data/data/com.termux/files/usr" 2>/dev/null
fi

mkdir -p "${virt_path}/sdcard" 2>/dev/null
mkdir -p "${virt_path}/storage/emulated/0" 2>/dev/null
mkdir -p "${virt_path}/storage/self/primary" 2>/dev/null

if [[ "${mount_termux_dir}" == "1" ]] 2>/dev/null; then
    command+=" -b /data/data/com.termux/files/home:/data/data/com.termux/files/home"
    command+=" -b /data/data/com.termux/files/usr:/data/data/com.termux/files/usr"
else 
    mkdir -p "${virt_path}/data/data/com.termux/files/home/storage" 2>/dev/null
    ln -s "/storage/emulated/0/DCIM" "${virt_path}/data/data/com.termux/files/home/storage/dcim" 2>/dev/null
    ln -s "/storage/emulated/0/Download" "${virt_path}/data/data/com.termux/files/home/storage/downloads" 2>/dev/null
    ln -s "/storage/emulated/0/Movies" "${virt_path}/data/data/com.termux/files/home/storage/movies" 2>/dev/null
    ln -s "/storage/emulated/0/Music" "${virt_path}/data/data/com.termux/files/home/storage/music" 2>/dev/null
    ln -s "/storage/emulated/0/Pictures" "${virt_path}/data/data/com.termux/files/home/storage/pictures" 2>/dev/null
    ln -s "/storage/emulated/0" "${virt_path}/data/data/com.termux/files/home/storage/shared" 2>/dev/null
fi

if [ ! -d "${virt_path}/home/${user_termux}" ]; then
    cmd_root=" -w ${HOME} ${cmd_root}"
    command+="${cmd_root} useradd -m ${user_termux}"
    exec $command
    if [ ! -f ${virt_path}/usr/etc/.virtpy ]; then
        echo "" > ${virt_path}/usr/etc/.virtpy
    else
        virtpy $@
    fi
    exit 0
fi

for i in /data/data/com.termux/files/home/* /data/data/com.termux/files/usr/* /data/data/com.termux/files/usr/bin/termux*; do
    if [ -d "$i" ] 2>/dev/null; then
        mkdir -p "${virt_path}${i}" 2>/dev/null
        chmod 777 "${virt_path}${i}" -R 2>/dev/null
    else
        touch "${virt_path}${i}" 2>/dev/null
    fi
done

ln -s "${virt_path}/usr/bin/apt" "${virt_path}/usr/bin/pkg" 2>/dev/null

for i in /sdcard/*; do
    if [ -d "$i" ] 2>/dev/null; then
        mkdir -p "${virt_path}${i}" 2>/dev/null
        for j in ${i}/*; do
            if [ -d "$j" ]; then
                mkdir -p "${virt_path}${j}" 2>/dev/null
            else
                touch "${virt_path}${j}" 2>/dev/null
            fi
        done
        chmod 777 "${virt_path}${i}" -R 2>/dev/null
    else
        touch "${virt_path}${i}" 2>/dev/null
        chmod 777 "${virt_path}${i}" 2>/dev/null
    fi
done

if [ ! -d "${virt_path}${HOME}" ]; then
    mkdir -p "${virt_path}${HOME}" 2> /dev/null
fi

printf "                        \r"

function pr() {
    if [[ "${mount_termux_dir}" == "1" ]] 2>/dev/null; then
        printf "${red}>> ${green}Mounted folder ${reset}[${yellow}/data/data/com.termux/files/home${reset}]\n"
        printf "${red}>> ${green}Mounted folder ${reset}[${yellow}/data/data/com.termux/files/usr${reset}]\n"
    fi
}

# block website
touch "${virt_path}/../blacklist.txt" 2>/dev/null
printf "127.0.0.1     localhost\n::1     ip6-localhost ip6-loopback\n" > "${virt_path}/etc/hosts"
while IFS= read -r line
do
    if [[ "$line" != "" ]]; then
        printf "127.0.0.1     ${line}\n" >> "${virt_path}/etc/hosts"
        printf "${light_cyan}> Blocked: ${yellow}${line}${reset}\n"
    fi
done <<< $(cat "${virt_path}/../blacklist.txt" 2>/dev/null)

# --virtpy-limit
limit_found=0
max_mem=-1
count=0
min=0
max=0
for i in $@; do
    if [[ "$limit_found" == "1" ]]; then
        max=$count
        max_mem="$i"
        _args=""
        count_2=0
        for i in $@; do
            if [[ "$count_2" == "$min" ]] || [[ "$count_2" == "$max" ]]; then
                continue
            fi

            _args="${_args} ${i}"
            count_2=$((count_2 + 1))
        done
        set -- $_args
        break
    fi
    if [[ "$i" == "--virtpy-limit" ]]; then
        min=$count
        limit_found=1
    fi
    count=$((count + 1))
done
unset count
unset count_2
unset _args
unset max
unset min
unset limit_found

# main
if [ -z "$1" ];then
    printf "\n${red} !! YOU ARE RUNNING IN VIRTPY !!\n\n"
    if [[ "$max_mem" != "-1" ]]; then
        printf "${red}>> ${green}LIMIT: ${yellow}${max_mem} MB${reset}\n\n"
    fi
    printf "${red}>> ${green}Default will not mount anything from /sdcard\n${reset}"
    pr
    printf "${reset}\n"
    cmd_root=" -w ${HOME} ${cmd_root}"
    command+="${cmd_root} sudo -u ${user_termux} /bin/python /bin/main.py /bin/python ${max_mem}"
    $command
else
    path_file="$(readlink -f "$1" 2>/dev/null | sed 's/\/storage\/emulated\/0/\/sdcard/g')"
    filename="$(basename "$path_file" 2>/dev/null)"
    path_only="$(dirname "$path_file" 2>/dev/null)"
    is_folder=1
    for i in "/storage/emulated/0" "/sdcard" "/storage/self/primary"; do
        for j in "" "/Android" "/Download" "/DCIM" "/Pictures" "/Recordings" "/Movies" "/Music" "/Ringtones"; do
            if [[ "$path_only" == "${i}${j}" ]]; then
                is_folder=0
                break
            fi
        done
        if [[ "$is_folder" == "0" ]]; then
            break
        fi
    done
    cmd_root=" -w ${working_dir} ${cmd_root}"
    if [ -f "$path_file" ] 2>/dev/null; then
        execarg="${path_only}/${filename}"
        args_show="${reset}["
        args=""
        arg_count=1
        for i in $@; do
            if [[ "$arg_count" == "1" ]]; then
                2>/dev/null
            else
                args_show="${args_show}${yellow}${i}${reset}, "
                args="${args} ${i}"
            fi
            arg_count=$((arg_count + 1))
        done
        if [[ "$arg_count" != "2" ]]; then
            args_show="${args_show::-2}"
        fi
        args_show="${args_show}${reset}]"
        unset arg_count
        while [ -z $truehihi ] 2>/dev/null; do
            printf "\n${red} !! YOU ARE RUNNING IN VIRTPY !!\n\n"
            printf "${red}>> ${green}LIMIT: ${yellow}${max_mem} MB${reset}\n"
            printf "${red}>> ${green}PATH:  ${yellow}${path_only}${reset}\n"
            printf "${red}>> ${green}FILE:  ${yellow}${filename}${reset}\n"
            printf "${red}>> ${green}ARGS:  ${reset}${args_show}${reset}"
            printf "\n\n${red}>> ${green}Choose what you want to mount to virtpy?${reset}"
            printf "\n${yellow} 1. ${light_cyan}Only file (${blue}${filename}${light_cyan})${reset}"
            if [[ "${disable_mount_dir}" == "0" ]] 2>/dev/null; then
                if [[ "$is_folder" == "1" ]] 2>/dev/null; then
                    printf "\n${yellow} 2. ${light_cyan}All file from folder (${blue}${path_only}${light_cyan})${reset}"
                else
                    printf "\n${yellow} 2. ${red}Mount folder is not supported! Please move your file to another folder (you can create a new folder), not in there ${light_cyan}(${blue}${path_only}${light_cyan})${reset}"
                fi
            fi
            printf "\n${yellow} 3. ${light_cyan}Exit virtpy${reset}"
            printf "\n\n${orange}> Choose: ${green}"
            read choose
            printf "${reset}\n"
            if [[ "$choose" == "1" ]]; then
                command+=" -b ${path_file}:${path_only}/${filename}"
                printf "${red}>> ${green}Mounted file ${reset}[${yellow}${path_file}${reset}]\n"
            else
                if [[ "$choose" == "2" ]] && [[ "$is_folder" == "1" ]] && [[ "${disable_mount_dir}" == "0" ]]; then
                    command+=" -b ${path_only}:${path_only}"
                    printf "${red}>> ${green}Mounted folder ${reset}[${yellow}${path_only}${reset}]\n"
                else
                    if [[ "$choose" == "3" ]]; then
                        echo ""
                        exit 0
                    else
                        echo ""
                        echo "==================="
                        continue
                    fi
                fi
            fi
            pr
            printf "${reset}\n"
            command+="${cmd_root} sudo -u ${user_termux} /bin/python /bin/main.py /bin/python ${max_mem}"
            $command "$execarg" $args
            break
        done
    else
        printf "\n${red} !! YOU ARE RUNNING IN VIRTPY !!\n\n"
        if [[ "$max_mem" != "-1" ]]; then
            printf "${red}>> ${green}LIMIT: ${yellow}${max_mem} MB${reset}\n\n"
        fi
        printf "${red}>> ${green}Default will not mount anything from /sdcard\n${reset}"
        pr
        printf "${reset}\n"
        cmd_root=" -w ${HOME} ${cmd_root}"
        command+="${cmd_root} sudo -u ${user_termux} /bin/python /bin/main.py /bin/python ${max_mem}"
        $command $@
    fi
fi
