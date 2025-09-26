#!/data/data/com.termux/files/usr/bin/bash
rm -rf "install.sh" 2>/dev/null
bash_ver="$(bash --version 2>/dev/null | awk '{print $5}' | head -n 1)"

if [[ "${bash_ver}" != "(aarch64-unknown-linux-android)" ]]; then
    echo "virtpy_termux only work on Termux [ARM64/ARM]"
    exit 1
fi

binurl_download="https://raw.githubusercontent.com/KhanhNguyen9872/virtpy_termux/main"

echo "Choose Python version to install:"
echo "  1) Python 3.11 (default)"
echo "  2) Python 3.12 (new)"
echo "  3) Python 3.13 (coming soon, not yet available)"
read -p "Select [1-3]: " ver_choose

case "$ver_choose" in
    2)
        pyver="312"
        release_download="https://github.com/KhanhNguyen9872/virtpy_termux/releases/download/py311"
        folder_name="virtpy_312"
        ;;
    3)
        echo "Python 3.13 is coming soon, not available yet."
        exit 1
        ;;
    *)
        pyver="311"
        release_download="https://github.com/KhanhNguyen9872/virtpy_termux/releases/download/py311"
        folder_name="virtpy"
        ;;
esac

printf "\n>> Installing package....\n"

printf "deb https://packages-cf.termux.org/apt/termux-main/ stable main\n" > /data/data/com.termux/files/usr/etc/apt/source.list 2>/dev/null || exit 1
printf "deb https://packages-cf.termux.dev/apt/termux-root root stable\n" >> /data/data/com.termux/files/usr/etc/apt/source.list 2>/dev/null || exit 1
printf "deb https://packages-cf.termux.dev/apt/termux-x11 x11 main\n" >> /data/data/com.termux/files/usr/etc/apt/source.list 2>/dev/null || exit 1

apt update -y || exit 1
apt upgrade -y || exit 1
apt install python3 wget p7zip which proot -y || exit 1

clear
printf ">> Checking Termux ARCH.... "
sleep 1
aarch="$(lscpu | grep -w "Architecture:" | awk '{print $2}')"
if [[ $aarch == "armv8l" ]] || [[ $aarch == "armv7l" ]]; then
    printf "(ARM)\n"
    aarch="ARM"
    binurl_download="${binurl_download}/bin32"
else
    if [[ $aarch == "aarch64" ]]; then
        printf "(ARM64)\n"
        aarch="ARM64"
    else
        printf "(NOT SUPPORTED)\n"
        exit 1
    fi
fi

printf ">> Downloading file....\n"
current_path="$(pwd)"
wget -q --show-progress -O "virtpy.7z" "${release_download}/virtpy_${pyver}_${aarch}.7z" || exit 1
wget -q --show-progress -O "virtpy.sha512sum" "${release_download}/virtpy_${pyver}_${aarch}.sha512sum" 2> /dev/null || exit 1
wget -q --show-progress -O virtpy.sh "${binurl_download}/virtpy.sh" 2> /dev/null || exit 1
wget -q --show-progress -O virtpip.sh "${binurl_download}/virtpip.sh" 2> /dev/null || exit 1
wget -q --show-progress -O virtpy.conf "${binurl_download}/virtpy.conf" 2> /dev/null || exit 1

printf ">> Verifying file....\n"
7z x "virtpy.7z" -p"khanhnguyen9872sieudeptrainhatvutrunayhehehe" -aoa > /dev/null 2>&1 || {
    printf "\nFile corrupted or Not Found! Try again later!\n"
    rm -rf virtpy* virtpip.py .virtpy* 2> /dev/null
    exit 1
}
rm -rf virtpy.7z 2>/dev/null
sha512sum -c virtpy.sha512sum >/dev/null 2>&1 || {
    printf "\nFile corrupted or Not Found! Try again later!\n"
    rm -rf virtpy* virtpip.py .virtpy* 2> /dev/null
    exit 1
}
rm -rf "virtpy.sha512sum" 2>/dev/null

printf ">> FILE OK\n"
printf ">> Installing file....\n"
cd /data/data/com.termux 2>/dev/null
tar -xJf "${current_path}/.virtpy" 2> /dev/null || :
rm -rf "${current_path}/.virtpy" 2>/dev/null
mv "${current_path}/virtpy.sh" /data/data/com.termux/files/usr/bin/virtpy 2>/dev/null && chmod 777 /data/data/com.termux/files/usr/bin/virtpy 2>/dev/null
mv "${current_path}/virtpip.sh" /data/data/com.termux/files/usr/bin/virtpip 2>/dev/null && chmod 777 /data/data/com.termux/files/usr/bin/virtpip 2>/dev/null
if [[ "$pyver" == "311" ]]; then
    mv "${current_path}/virtpy.conf" /data/data/com.termux/virtpy.conf 2>/dev/null
    chmod 777 /data/data/com.termux/virtpy.conf 2>/dev/null
elif [[ "$pyver" == "312" ]]; then
    mv "${current_path}/virtpy.conf" /data/data/com.termux/virtpy_312.conf 2>/dev/null
    chmod 777 /data/data/com.termux/virtpy_312.conf 2>/dev/null
fi

printf ">> Setup env....\n"
if [[ "$pyver" == "311" ]]; then
    virtpy --virtpy-run-python311 >/dev/null 2>&1
elif [[ "$pyver" == "312" ]]; then
    virtpy --virtpy-run-python312 >/dev/null 2>&1
fi

printf ">> Installing feature....\n"
curl "${binurl_download}/feature/limit.py" > /data/data/com.termux/${folder_name}/bin/main.py 2>/dev/null
chmod 777 /data/data/com.termux/${folder_name}/bin/main.py 2>/dev/null
virtpip install psutil >/dev/null 2>&1

printf ">> Install completed!\n\n"
echo "[Use: 'virtpip' to use PIP, 'virtpy' to use python]"
cd "${current_path}"
exit 0
