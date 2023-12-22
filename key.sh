#!/bin/bash
RED_FONT_PREFIX="\033[31m"
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
FONT_COLOR_SUFFIX="\033[0m"
INFO="[${LIGHT_GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"
ERROR="[${RED_FONT_PREFIX}ERROR${FONT_COLOR_SUFFIX}]"
[ $EUID != 0 ] && SUDO=sudo

USAGE(){
    echo "
SSH Key Installer $VERSION

Usage:
        key.sh [options...] <arg>

Options:
  -u    从github安装公钥
  -f    从本地文件安装公钥
  -d    禁止密码登录"
}
if [ $# -eq 0 ]; then
    USAGE
    exit 1
fi
install_key() {
    [ "${PUB_KEY}" == '' ] && echo "${ERROR} ssh key does not exist." && exit 1
    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        echo -e "${INFO} '${HOME}/.ssh/authorized_keys' is missing..."
        echo -e "${INFO} Creating ${HOME}/.ssh/authorized_keys..."
        mkdir -p ${HOME}/.ssh/
        touch ${HOME}/.ssh/authorized_keys
        if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
            echo -e "${ERROR} Failed to create SSH key file."
        else
            echo -e "${INFO} Key file created, proceeding..."
        fi
    fi
    echo -e "${INFO} Adding SSH key..."
    echo -e "${PUB_KEY}" >>${HOME}/.ssh/authorized_keys
    chmod 700 ${HOME}/.ssh/
    chmod 600 ${HOME}/.ssh/authorized_keys
    [[ $(grep "${PUB_KEY}" "${HOME}/.ssh/authorized_keys") ]] &&
        echo -e "${INFO} SSH Key installed successfully!" || {
        echo -e "${ERROR} SSH key installation failed!"
        exit 1
    }
}
get_loacl_key() {
    if [ "${KEY_PATH}" == '' ]; then
        read -e -p "Please enter the path:" KEY_PATH
        [ "${KEY_PATH}" == '' ] && echo -e "${ERROR} Invalid input." && exit 1
    fi
    echo -e "${INFO} Get key from ${KEY_PATH}..."
    PUB_KEY=$(cat ${KEY_PATH})
}
get_github_key() {
    if [ "${KEY_ID}" == '' ]; then
        read -e -p "Please enter the GitHub account:" KEY_ID
        [ "${KEY_ID}" == '' ] && echo -e "${ERROR} Invalid input." && exit 1
    fi
    echo -e "${INFO} The GitHub account is: ${KEY_ID}"
    echo -e "${INFO} Get key from GitHub..."
    PUB_KEY=$(curl -fsSL https://github.com/${KEY_ID}.keys)
    if [ "${PUB_KEY}" == 'Not Found' ]; then
        echo -e "${ERROR} GitHub account not found."
        exit 1
    elif [ "${PUB_KEY}" == '' ]; then
        echo -e "${ERROR} This account ssh key does not exist."
        exit 1
    fi
}
disable_password() {
    $SUDO sed -i "s@.*\(PasswordAuthentication \).*@\1no@" /etc/ssh/sshd_config && {
        RESTART_SSHD=1
        echo -e "${INFO} Disabled password login in SSH."
    } || {
        RESTART_SSHD=0
        echo -e "${ERROR} Disable password login failed!"
        exit 1
    }
}
while getopts 'u:f:d:' OPT; do
    case $OPT in
    u)
        KEY_ID=$OPTARG
        get_github_key
        install_key
        ;;
    f)
        KEY_PATH=$OPTARG
        get_loacl_key
        install_key
        ;;
    d)
        disable_password
        ;;
    *)
        USAGE
        exit 1
        ;;
    esac
done
if [ "$RESTART_SSHD" = 1 ]; then
    echo -e "${INFO} Restarting sshd..."
    $SUDO systemctl restart sshd && echo -e "${INFO} Done."
fi
