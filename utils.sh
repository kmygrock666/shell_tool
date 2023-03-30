RESTORE=$(echo  '\033[0m')

RED=$(echo  '\033[00;31m')
GREEN=$(echo  '\033[00;32m')
YELLOW=$(echo  '\033[00;33m')
BLUE=$(echo  '\033[00;34m')
MAGENTA=$(echo  '\033[00;35m')
PURPLE=$(echo  '\033[00;35m')
CYAN=$(echo  '\033[00;36m')

LIGHTGRAY=$(echo  '\033[00;37m')
LRED=$(echo  '\033[01;31m')
LGREEN=$(echo  '\033[01;32m')
LYELLOW=$(echo  '\033[01;33m')
LBLUE=$(echo  '\033[01;34m')
LMAGENTA=$(echo  '\033[01;35m')
LPURPLE=$(echo  '\033[01;35m')
LCYAN=$(echo  '\033[01;36m')

WHITE=$(echo  '\033[01;37m')

function Ianhelp() {
    cat <<EOF

${CYAN}指令: galaxy {指令} [參數]${RESTORE}

env...............基本資訊(ex. galaxy 安裝路徑)
ad................廣宣圖片排序產生器
sort..............遊戲排序產生sql
logo..............遊戲LOGO產生
ip................取消 ip 不再網域內
restoreMusic......還原 new-nsk 舊背景音樂
renewMusic........替換新的背景音樂到 new-nsk [參數]
makesoftlink......軟連結
php...............切換版本 [參數]
startDocker.......啟動 mysql-redis-docker-compose
stopDocker........停止 mysql-redis-docker-compose
dockerInfo........查看詳情
go qa.............前往[測試站]
go dev............前往[開發站]
go qagcp..........前往[gcp測試站]
go prod...........前往[正式站]
go prodgcp........前往[gcp正式站]
go gcpsk..........前往[gcp小球] 2021/12/31 關閉
info {site}.......取得資訊[qa,dev,qagcp,prod,prodgcp][測試站,開發站,gcp測試站,正式站,gcp正式站]
weburl {site}.....取得bbgp網站[qa,prod] 預設平台大廳 切換彩票大廳(weburl qa lobby)
*.................顯示幫助

EOF
    exit 0
}

function addDomainToHost() {
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'ETC_HOSTS=($(cat /etc/hosts))'
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'DOCKER_HOSTS=($(cat $DIR/docker/hosts))'
    for domain in "${DOCKER_HOSTS[@]}"; do
        IS_EXIST_IN_ETC_HOSTS=$([[ ${ETC_HOSTS[*]} =~ (^|[[:space:]])"$domain"($|[[:space:]]) ]] && echo 'Y' || echo 'N')
        case $IS_EXIST_IN_ETC_HOSTS in
        N)
            echo "Insert '${LYELLOW}$domain${RESTORE}' to /etc/hosts"
            sudo echo $domain | sudo tee -a /etc/hosts 1>/dev/null
            ;;
        esac
    done
}

function removeDomainFromHost() {
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'ETC_HOSTS=($(cat /etc/hosts))'
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'GALAXY_HOSTS=($(cat $DIR/docker/hosts))'
    for domain in "${GALAXY_HOSTS[@]}"; do
        IS_EXIST_IN_ETC_HOSTS=$([[ ${ETC_HOSTS[*]} =~ (^|[[:space:]])"$domain"($|[[:space:]]) ]] && echo 'Y' || echo 'N')
        case $IS_EXIST_IN_ETC_HOSTS in
        Y)
            echo "Remove '${LYELLOW}$domain${RESTORE}' in /etc/hosts"
            sudo sed -i "" "/${domain}/d" /etc/hosts
            ;;
        esac
    done
}

function showPublicDomain() {
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'GALAXY_HOSTS=($(cat $DIR/docker/hosts))'
    for domain in "${GALAXY_HOSTS[@]}"; do
        arr=($(echo $domain))
        host=${arr[1]}
        echo "http://$host"
    done
}

function doTelepresence() {
    lang=$1
    repo=$2

    # docker stop galaxy_telepresence
    # docker rm -f galaxy_telepresence

    # rm -f $DIR/tools/kubectl_config
    # # 必須將 host 的 kubectl config 載入 container 內， container kubectl 才能正確操作 host 的 k8s
    # kubectl config view --raw >$DIR/tools/kubectl_config

    case "$lang" in
    go)
        # docker run --rm --network host --name galaxy_telepresence \
        #     --privileged \
        #     -v $DIR/tools/kubectl_config:/root/.kube/config \
        #     -v $DIR/../$repo:/go/src/code \
        #     -ti gitlab-new01.vir777.com:5001/galaxy-lib/telepresence:golang \
        #     telepresence \
        #     --method inject-tcp \
        #     --namespace galaxy-local \
        #     --swap-deployment backend-$repo
        telepresence --namespace galaxy-local --swap-deployment backend-$repo --docker-run --rm -it -v $DIR/../$repo:/go/src/code gitlab-new01.vir777.com:5001/galaxy-lib/telepresence:golang
        ;;
    easyswoole)
        export TELEPRESENCE_USE_DEPLOYMENT=1
        # docker run --rm --network host --name galaxy_telepresence --privileged -v $DIR/tools/kubectl_config:/root/.kube/config -v $DIR/../$repo:/easyswoole -ti gitlab-new01.vir777.com:5001/galaxy-lib/telepresence:easyswoole telepresence --namespace galaxy-local --swap-deployment backend-$repo
        telepresence --namespace galaxy-local --swap-deployment backend-$repo --docker-run --rm -it -v $DIR/../$repo:/easyswoole gitlab-new01.vir777.com:5001/galaxy-lib/telepresence:easyswoole bash
        ;;
    esac
}

function checkCommandTool() {
    requiredCommand=(
        galaxy
        curl
        git
        docker
        kubectl
        helm
    )

    for c in "${requiredCommand[@]}"; do
        command -v $c >/dev/null 2>&1 || {
            echo >&2 "${LRED}無法找到 $c 指令，請確認是否有正確安裝${RESTORE}"
            exit 1
        }
    done
}

function checkFortiConnect() {
    if [ "$isCheckFortiConnect" == "N" ]; then
        return
    fi

    resp=$(curl -s https://gitlab-new01.vir777.com --max-time 10)

    if [ "$resp" == "" ]; then
        echo "${LRED}無法與 Gitlab 進行連線，請確認是否已連接 Forti，或是指令加上 --no-check 跳過檢查機制${RESTORE}"
        exit 1
    fi

    git remote update >/dev/null 2>&1
    git fetch -f --prune --prune-tags >/dev/null 2>&1
}

function doUpgrade() {
    checkFortiConnect
    current=$(git describe --tags)
    latest=$(git describe --tags $(git rev-list --tags --max-count=1))

    if [ "$current" != "$latest" ]; then
        git checkout ${latest} >/dev/null 2>&1

        echo "${LMAGENTA}更新完畢，請重新執行你的指令。必要時刻需要重新啟動整個環境。${RESTORE}"
    else
        echo "${LMAGENTA}已經是最新版本。${RESTORE}"
    fi

    echo
}

function goto {
    station=${1:-qa}
    # if [ ${station} == 'dev' ]; then
    #     # echo "總控/管/客端    ssh rd2-admin@10.251.39.154 / sudo su dsk_red"
    #     # ssh rd2-admin@10.251.31.136
    #     echo "總控/管/客端    ssh ian313_tsai@10.32.62.1 / sudo su rd2-admin"
    #     echo ""
    #     info qa
    #     echo ""

    #     ssh ian313_tsai@10.32.62.1
    # fi
    if [ ${station} == 'oldqa' ]; then
        echo "I think you know how to use this: Rd2OnFire"
        echo "請輸入行動裝置驗證密碼："
        ssh rd2-admin@10.251.31.135
    fi
    if [ ${station} == 'qa' ] || [ ${station} == 'dev' ]; then
        echo "Welcom to ${LBLUE}Rd2OnFire${RESTORE}，${LRED}登入流程：${RESTORE}"
        echo "${LIGHTGRAY}1. 使用 InAuth(Forti) 帳號密碼驗證登入跳板機。${RESTORE}"
        echo "${LIGHTGRAY}2. 切換使用者為 rd2-admin： sudo su rd2-admin 「${RESTORE}${BLUE}密碼你知道的${RESTORE}${LIGHTGRAY}」。${RESTORE}"
        echo "${LIGHTGRAY}3. ssh xx.xx.xx.xx 登入欲前往的機器。${RESTORE}"
        # echo "${LIGHTGRAY}PS. 也可省略第二點，執行：max info qa 取得機器資訊列表，直接複製貼上前往。${RESTORE}"
        echo ""
        read -p ">> 請輸入InAuth(Forti)驗證帳號:: " username;
        echo ""
        if [ ${station} == 'qa' ]; then
        info qa
        ssh $username@10.32.72.1
        else
        info dev
        ssh $username@10.32.62.1
        fi
    fi
    if [ ${station} == 'prod' ]; then
        echo "Welcom to ${LBLUE}marve1@tH0r3#ragnaRk${RESTORE}，${LRED}登入流程：${RESTORE}"
        echo "${LIGHTGRAY}1. 使用 InAuth(Forti) 帳號密碼驗證登入跳板機。${RESTORE}"
        echo "${LIGHTGRAY}2. 切換使用者為 rd2-admin： sudo su rd2-admin 「${RESTORE}${BLUE}密碼你知道的${RESTORE}${LIGHTGRAY}」。${RESTORE}"
        echo "${LIGHTGRAY}3. ssh rd2-admin@xx.xx.xx.xx 登入欲前往的機器。${RESTORE}"
        echo "${LIGHTGRAY}4. 進入各站後，sudo su 該站別要使用的帳號。${RESTORE}"
        echo ""
        info prod
        echo ""

        read -p "請輸入InAuth(Forti)驗證帳號:: " username;
        # echo ">> 請輸入InAuth(Forti)驗證密碼:: "
        ssh $username@10.249.49.11
    fi
    if [ ${station} == 'gcpsk' ]; then
        read -p "請輸入欲連線機器:: " ip;
        ssh -F ~/.ssh/ssh_config_rd2.sk $ip
    fi
    if [ ${station} == 'prodgcp' ]; then
        info prodgcp
        echo ""
        read -p "請輸入欲連線機器:: " ip;
        ssh -F ~/.ssh/ssh_config_rd2.ipl $ip
    fi
    if [ ${station} == 'qagcp' ]; then
        info qagcp
        echo ""
        read -p "請輸入欲連線機器:: " ip;
        ssh -F ~/.ssh/ssh_config_rd2.ipl $ip
    fi
}

function info {
    info=${1:-qa}
    if [ ${info} == 'dev' ]; then
        machine=(
            "# K8S"
            ">>>> pod"
            "k8s-master      ;ssh rd2-admin@10.32.62.122;sudo -i;-"
            ">>>> 指令"
            "pod list        ;kubectl get pod -n portal ;-;-"
            "enter pod       ;kubectl exec -it {pod-key} -n portal /bin/sh;-;-"
            "# 機群"
            "控端            ;ssh rd2-admin@10.32.62.31 ;sudo su ipl_red;-"
            "管端            ;ssh rd2-admin@10.32.62.32 ;sudo su ipl_red;-"
            "客端            ;ssh rd2-admin@10.32.62.33 ;sudo su ipl_red;-"
            "客端            ;ssh rd2-admin@10.32.62.34 ;sudo su ipl_red;-"
            "API             ;ssh rd2-admin@10.32.62.38 ;sudo su ipl_red;-"
            "API             ;ssh rd2-admin@10.32.62.39 ;sudo su ipl_red;-"
            "總控            ;ssh rd2-admin@10.32.62.12 ;sudo su dsk_red;-"
            ">>>> 其他服務"
            "Switch          ;ssh rd2-admin@10.32.62.51 ;-;-"
            "Gusher          ;ssh rd2-admin@10.32.62.53 ;-;-"
        )
    fi
    if [ ${info} == 'qa' ]; then
        machine=(
            "# K8S"
            ">>>> pod"
            "k8s-master      ;ssh rd2-admin@10.32.72.204;sudo -i;-"
            ">>>> 指令"
            "pod list        ;kubectl get pod -n portal ;-;-"
            "enter pod       ;kubectl exec -it {pod-key} -n portal /bin/sh;-;-"
            "# 機群"
            "控端            ;ssh rd2-admin@10.32.72.31 ;sudo su ipl_red;-"
            "管端            ;ssh rd2-admin@10.32.72.32 ;sudo su ipl_red;-"
            "客端            ;ssh rd2-admin@10.32.72.33 ;sudo su ipl_red;-"
            "客端            ;ssh rd2-admin@10.32.72.34 ;sudo su ipl_red;-"
            "API             ;ssh rd2-admin@10.32.72.38 ;sudo su ipl_red;-"
            "API             ;ssh rd2-admin@10.32.72.39 ;sudo su ipl_red;-"
            "總控            ;ssh rd2-admin@10.32.72.12 ;sudo su dsk_red;-"
            ">>>> 其他服務"
            "Switch          ;ssh rd2-admin@10.32.72.51 ;-;-"
            "Gusher          ;ssh rd2-admin@10.32.72.53 ;-;-"
        )
    fi
    if [ ${info} == 'qagcp' ]; then
        machine=(
            "# 機群"
            "控端            ;10.102.6.141 ;sudo su;-"
            "管端            ;10.102.6.142 ;sudo su;-"
            "API            ;10.102.6.146 ;sudo su;-"
            "總控            ;10.102.6.132 ;sudo su;-"
            ">>>> 其他服務"
            "Switch          ;10.2.6.99 ;-;-"
            "Gusher          ;10.2.6.166;-;-"
        )
    fi
    if [ ${info} == 'prod' ]; then
        machine=(
            "# K8S"
            ">>>> pod"
            "k8s-master      ;ssh rd2-admin@172.17.88.21 ;sudo -i;21~23"
            ">>>> 指令"
            "pod list        ;kubectl get pod -n portal  ;-;-"
            "enter pod       ;kubectl exec -it {pod-key} -n portal /bin/sh;-;-"
            "# 機群"
            "控端            ;ssh rd2-admin@172.17.15.10 ;sudo su;1,2,10,11,12"
            "管端            ;ssh rd2-admin@172.17.15.20 ;sudo su;20~23"
            "客端            ;ssh rd2-admin@172.17.15.100;sudo su;100~111"
            "客端            ;ssh rd2-admin@172.17.24.12 ;sudo su;12~24"
            "API             ;ssh rd2-admin@172.20.5.30  ;sudo su;30~39"
            "總控            ;ssh rd2-admin@172.17.5.242 ;sudo su;-"
            ">>>> 其他服務"
            "Switch          ;ssh rd2-admin@172.17.16.70 ;70~71;-"
            "Gusher          ;ssh rd2-admin@172.17.16.30 ;30~32;-"
        )
    fi
    if [ ${info} == 'gcpsk' ]; then
        machine=(
            "# K8S"
            ">>>> pod"
            "k8s-master      ;ssh rd2-admin@10.32.72.204;sudo -i;-"
            ">>>> 指令"
            "pod list        ;kubectl get pod -n portal"
            "enter pod       ;kubectl exec -it {pod-key} -n portal /bin/sh"
        )
    fi
    if [ ${info} == 'prodgcp' ]; then
        machine=(
            "# 機群"
            "控端            ;10.2.6.21 ;sudo su;21~23"
            "管端            ;10.2.6.31 ;sudo su;31~32"
            "API             ;10.2.6.41 ;sudo su;41~43"
            "總控            ;10.2.6.11 ;sudo su;-"
            ">>>> 其他服務"
            "Switch          ;10.2.6.99 ;-;-"
            "Gusher          ;10.2.6.166;-;-"
        )
    fi

    for i in "${machine[@]}"; do 
        
        if [[ $i == *";"* ]]; then
            IFS=';' read -ra ADDR <<< "$i"
            echo "| ${LIGHTGRAY}${ADDR[0]}${RESTORE} | ${LGREEN}${ADDR[1]}${RESTORE} | ${LBLUE}${ADDR[2]}${RESTORE} | ${LBLUE}${ADDR[3]}${RESTORE} |"
        else
            echo "${LRED}$i${RESTORE}"
        fi
        
    done
}

function getWebUrl {
    CURL='/usr/bin/curl'
    RVMHTTP="http://apollo.vir777.net/apidoc/login_link.php"
    HTTP="https://"
    DOMAIN="888.vir777.net"
    CURLARGS="-f -s -S -k"
    PAGESITE="&page_site=game"
    USER="rd2ian"
    UPPERUSER="drd2ian"
    STARTDATE="$(TZ=America/New_York date +'%Y-%m-%d')"
    ENDDATE="$(TZ=America/New_York date +'%Y-%m-%d')"
    if [ ${1} == 'prod' ]; then
        RVMHTTP="http://linkapi.04viplite.com/apidoc/login_link.php"
        DOMAIN="888.04viplite.com"
        USER="rd2test1"
        UPPERUSER="drd2test"
    fi

    if [ ${2:-qa} == 'lobby' ]; then
        PAGESITE="&page_site=Ltlottery"
    fi

    DATA=" -d event=Machine&code=rd1xu06ru%2C6&hallid=3820474&domain=$DOMAIN&username=$USER&uppername=$UPPERUSER&startdate=$STARTDATE&enddate=$ENDDATE&website=bbinbgp"
    raw="$($CURL $CURLARGS $RVMHTTP $DATA | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['data'][0])")" 
    echo $HTTP$raw$PAGESITE

 }

 function loginAPI {
    CURL='/usr/bin/curl'
    CURLARGS="-f -s -S -k"
    DOMAIN="http://888.vir777.net/"
    API_PATH="app/WebService/JSON/display.php/Login"
    today="$(TZ=America/New_York date +'%Y%m%d')"
    website="bbinbgp"
    USER="rd2ian"
    UPPERUSER="drd2ian"
    if [ ${1} == 'prod' ]; then
        DOMAIN="http://888.04viplite.com/"
        USER="rd2test1"
        UPPERUSER="drd2test"
    fi

    PAGESITE="&page_site=game"
    KeyB="4GZ2qQ"
    key_A="ai"
    st=$website$USER$KeyB$today
    key_B="$(printf "$st" | md5)"
    key_C="increas"
    KEY=$key_A$key_B$key_C
    

    if [ ${2:-qa} == 'lobby' ]; then
        PAGESITE="&page_site=Ltlottery"
    fi

    DATA="?website=$website&username=$USER&uppername=$UPPERUSER&key=$KEY"
    echo $DOMAIN$API_PATH$DATA$PAGESITE
 }