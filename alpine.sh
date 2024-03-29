#!sh

# Check if user is root
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script"
    exit
fi

clear
echo "+------------------------------------------------------------------------+"
echo "|                             Alpine                                     |"
echo "+------------------------------------------------------------------------+"
echo "|                  A script to Net Install  Alpine                       |"
echo "+------------------------------------------------------------------------+"

console=tty0
branch=latest-stable
mirror=https://dl-cdn.alpinelinux.org/alpine
flavor=lts

cidr2mask() {
    value=$(( 0xffffffff ^ ((1 << (32 - $1)) - 1) ))
    echo "$(( ($value >> 24) & 0xff )).$(( ($value >> 16) & 0xff )).$(( ($value >> 8) & 0xff )).$(( $value & 0xff ))"
}
address=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
addr=$(echo $address | awk -F'/' '{print $1}')
cidr=$(echo $address | awk -F'/' '{print $2}')
gw=$(ip rou | awk '/default via/ {print $3}')
mask=$(cidr2mask $cidr)
dns1=8.8.8.8
dns2=8.8.4.4
alpine_addr="ip=${addr}::${gw}:${mask}::eth0::${dns1}:${dns2}"

if [ "$(uname -m)" = "x86_64" ]; then
    arch="x86_64"
elif [ "$(uname -m)" = "i386" ] || [ "$(uname -m)" = "i686" ] || [ "$(uname -m)" = "x86" ]; then
    arch="x86"
elif [ "$(uname -m)" = "armv8" ] || [ "$(uname -m)" = "armv8l" ] || [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
    arch="aarch64"
else
    arch="$(uname -m)"
fi
echo "系统平台：${arch}"


echo yes | ssh-keygen -t ed25519 -N '' -f KEY
if [ $? -ne 0 ]; then
    echo "请安装OpenSSH"
    exit
fi
ssh_key="$(curl -k -F "file=@KEY.pub" https://file.io | sed 's/.*"link":"//;s/".*//')"
if [ $? -ne 0 ]; then
    echo "请安装Curl"
    exit
fi

version="$(curl -k ${mirror}/${branch}/releases/${arch}/latest-releases.yaml | grep version | sed -n 1p | sed 's/version: //g' | xargs echo -n)"
if ! curl -k -f -# ${mirror}/${branch}/releases/${arch}/netboot/vmlinuz-${flavor} -o /boot/vmlinuz-${version}-netboot; then
    echo "Failed to download file!"
    exit 
fi

if ! curl -k -f -# ${mirror}/${branch}/releases/${arch}/netboot/initramfs-${flavor} -o /boot/initramfs-${version}-netboot; then
    echo "Failed to download file!"
    exit 
fi

cat > /etc/grub.d/40_custom << EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry 'Alpine' {
    linux /boot/vmlinuz-${version}-netboot ${alpine_addr} alpine_repo="${mirror}/${branch}/main" modloop="${mirror}/${branch}/releases/${arch}/netboot/modloop-${flavor}" modules="loop,squashfs" initrd="initramfs-${version}-netboot" console="${console}" ssh_key="${ssh_key}"
    initrd /boot/initramfs-${version}-netboot
}
EOF

if grub-install --version >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
    grub-reboot Alpine
elif grub2-install --version >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
    grub2-reboot Alpine
else
    echo "不支持当前系统"
    exit
fi

echo "wget -O KEY" "$(curl -k -F "file=@KEY" https://file.io | sed 's/.*"link":"//;s/".*//')" "&& chmod 0600 KEY"
echo "ssh -i KEY root@${addr}"
