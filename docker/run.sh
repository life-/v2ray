#!/bin/bash


function help() {
    echo "Usage: $0 -h HUB -t TAG [-d DOMAIN] build|start"
}

function build() {
    docker build -t $HUB:$TAG .
}

function start() {
    # check certificate
    if [[ ! -f ./v2ray.key || ! -f ./v2ray.crt ]]; then
       if [ "x${DOMAIN}" == "x" ]; then
         echo "Pelease special a domain to generate certificate..."
         exit 1
       fi
       genCert
    fi

    # check configuration
    if [ ! -f ./config.json ]; then
       genConfig
    fi

    docker run -d --network host -e LC_ALL=zh_CN.UTF-8 -v `pwd`:/etc/v2ray -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro $HUB:$TAG
}

function stop() {
    docker ps | grep "$HUB" |grep -v grep| awk '{print $1}'|xargs -r docker rm -f
}

#-------------------------------------------------------------------------------
#   private functions
#-------------------------------------------------------------------------------
function genConfig() {
    export uid=$(uuidgen -r)
    envsubst < server.json.tpl > config.json
}

# <see> https://github.com/Neilpang/acme.sh/wiki/%E8%AF%B4%E6%98%8E
function genCert() {
    # step 1: intall acme.sh
    if [ ! -d ~/.acme.sh ]; then
      curl  https://get.acme.sh | sh
    fi
    # alias acme.sh="~/.acme.sh/acme.sh"

    # step 2: check you have the privileges of domain
    /home/admin/.acme.sh/acme.sh --issue  -d ${DOMAIN} --standalone

    # step 3: generate cert
    /home/admin/.acme.sh/acme.sh  --installcert  -d  ${DOMAIN}  --log \
        --key-file   ./v2ray.key \
        --fullchain-file ./v2ray.cer 
}

while getopts ":h:t:d:" opt; do
  case ${opt} in
    h ) # process option hub
      HUB=${OPTARG}
      ;;
    t ) # process option tag
      TAG=${OPTARG}
      ;;
    d ) # process option domain
      DOMAIN=${OPTARG}
      ;;
    \? )
      help
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

command=$1
case $command in
  build) # build the image
    build
    ;;
  start) # start the container
    start
    ;;
  stop) # stop the container
    stop
    ;;
  *)
    help
    ;;
esac
