# 宣告使用 /bin/bash
#!/bin/bash

# echo $0	#目前的檔案檔名
# echo $n	#n 從 1 開始，代表第幾個參數
# echo $#	#傳遞到程式或函式目前有幾個參數
# echo $*	#傳遞到程式或函式所有參數
# echo $@	#類似 $* 但是在被雙引號包含時有些許不同
# echo $?	#上一個指令退出狀態或是函式的返回值
# echo $$	#目前 process PID

# 取得執行檔的所在位置，若是Link模式時必須取得實際位置
SELF_PATH=${BASH_SOURCE[0]}
if [[ -L "$SELF_PATH" ]]; then
    DIR=$(dirname $(readlink ${SELF_PATH}))
else
    DIR=$(dirname ${SELF_PATH})
fi

if [ $DIR == "." ]; then
    DIR=$PWD
fi

source $DIR/utils.sh
preCommand=$1
subCommand=${2-}
FC="$preCommand$subCommand"
cd $DIR

# for i in $@
# do
# subCommand=${2-}
# done

case "$FC" in
env)
    cat <<EOF
    PATH: $DIR
    LINK: ${BASH_SOURCE[0]}
    PWD: $PWD
EOF
    echo $3
    exit 0
    ;;
ad)
    cd ~/Desktop/廣宣/廣宣工具/廣宣圖片排序產生器
    python3 ./auto_order.py
    ;;
sort)
    cd ~/Desktop/廣宣/廣宣工具/遊戲排序產生sql
    python3 ./game_sorting.py
    ;;
logo)
    cd ~/Desktop/廣宣/廣宣工具/廣宣logo
    python3 ./auto_logo.py
    ;;
ip)
    sed -i '' '16i\
        return true;
        ' ~/docker/work/new-nsk/business_classes/Memcache/MemcacheIpBlocker.php
    sed -i '' '48i\ 
        return true;
        ' ~/docker/work/new-nsk/www/lib/deny_ip.php
    echo success
    ;;
restoreMusic)
    work_path=$(pwd)
    cp -f ~/Desktop/廣宣/BBback.mp3 $work_path/www/layout/video/mp3
    echo "success copy to " $work_path
    ;;
renewMusic)
    if [ -f "$subCommand" ]; then
        work_path=$(pwd)
        cp -f "$subCommand" $work_path/www/layout/video/mp3/BBback.mp3
        echo "success copy to " $work_path
    fi
    ;;
makesoftlink)
    # -L 是一個用於測試符號鏈接的文件測試運算符
    if [ -L "/usr/local/ian" ] || [ -L "/usr/local/bin/ian" ]; then
        rm /usr/local/ian
        rm /usr/local/bin/ian
    fi

    ln -sf $PWD/main.sh /usr/local/bin/ian
    ;;
php)
    phpversion="$(php --version | tail -r | tail -n 1 | cut -d " " -f 2 | cut -c 1,2,3)"
    echo "${CYAN}=========== 當前版本 : ${phpversion} ===========${RESTORE}"
    echo "${CYAN}===========   可切換版本   ===========${RESTORE}"
    brew list --formula | grep php
    read -p "${CYAN}▶ 請輸入要切換的版本的(ex. php@5.6,php =>php@7.4): ${RESTORE}" PRESS_VERSION_NO
    if (($(echo "$phpversion > 7.4" | bc -l))); then
        phpversion="php"
    else
        phpversion="php@$phpversion"
    fi
    brew unlink $phpversion && brew link --force $PRESS_VERSION_NO
    # echo 'export PATH="/usr/local/opt/php@'${PRESS_VERSION_NO}'/bin:$PATH"' >> ~/.zshrc
    echo "${YELLOW}===========切換成功===========${RESTORE}"
    ;;
startDocker)
    # echo "${CYAN}Install missing domain to /etc/hosts${RESTORE}"
    # addDomainToHost
    cd $DIR/../docker
    docker-compose up -d

    echo "${CYAN}Done${RESTORE}"

    echo "${CYAN}Public Addr:${RESTORE}"
    showPublicDomain
    ;;
stopDocker)
    if [ "$2" == "purge" ]; then
        echo "${LRED}Remove domain from /etc/hosts${RESTORE}"
        removeDomainFromHost
    fi
    cd $DIR/../docker
    docker-compose down
    ;;
dockerInfo)
    echo "${CYAN}mysql:${RESTORE}"
    echo "${CYAN}---port:${RESTORE}${YELLOW} 3306 ${RESTORE}"
    echo "${CYAN}---user:${RESTORE}${YELLOW} root ${RESTORE}"
    echo "${CYAN}---pwd :${RESTORE}${YELLOW} root ${RESTORE}"
    echo "${CYAN}phpmyadmin:${RESTORE}"
    echo "${CYAN}---port:${RESTORE}${YELLOW} 8801 ${RESTORE}"
    echo "${CYAN}redis:${RESTORE}"
    echo "${CYAN}---port:${RESTORE}${YELLOW} 6379 ${RESTORE}"
    ;;
goqa)
    goto qa
    ;;
godev)
    goto dev
    ;;
goprod)
    goto prod
    ;;
gogcpsk)
    goto gcpsk
    ;;
goprodgcp)
    goto prodgcp
    ;;
goqagcp)
    goto qagcp
    ;;
info$subCommand)
    info $subCommand
    ;;
weburl$subCommand)
    loginAPI $subCommand $3
    ;;
* | help)
    Ianhelp

    ;;

esac
