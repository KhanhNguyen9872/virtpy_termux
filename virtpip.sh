#!/data/data/com.termux/files/usr/bin/bash
user_termux="$(whoami)"

# ==== Choose installed Python version ====
installed_versions=()
[[ -d "/data/data/com.termux/virtpy" ]] && installed_versions+=("3.11")
[[ -d "/data/data/com.termux/virtpy_312" ]] && installed_versions+=("3.12")

if [[ ${#installed_versions[@]} -eq 0 ]]; then
    echo "No virtpy installation found. Please run install.sh first."
    exit 1
elif [[ ${#installed_versions[@]} -eq 1 ]]; then
    case "${installed_versions[0]}" in
        "3.11") virt_path="/data/data/com.termux/virtpy" ;;
        "3.12") virt_path="/data/data/com.termux/virtpy_312" ;;
    esac
else
    echo "Multiple Python versions detected:"
    select ver in "${installed_versions[@]}"; do
        case $ver in
            "3.11") virt_path="/data/data/com.termux/virtpy"; break ;;
            "3.12") virt_path="/data/data/com.termux/virtpy_312"; break ;;
            *) echo "Invalid choice" ;;
        esac
    done
fi
# =========================================

unset LD_PRELOAD
command="proot"
command+=" -k 4.14.81"
command+=" --link2symlink"
command+=" -0"
command+=" -r ${virt_path}"
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -w /home/${user_termux}"
command+=" /usr/bin/env -i"
command+=" HOME=/home/${user_termux}"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=$TERM"
command+=" LANG=C.UTF-8"
command+=" sudo -u ${user_termux} pip"

com="$@"
if [ -z "$1" ]; then
    exec $command
else
    $command $com
fi