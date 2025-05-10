#!/bin/bash
# Author: An Shen
# Date: 2023-01-30
# Modified: 2025-05-10 to support all NeverIdle parameters

. /etc/profile

function log(){
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
}

function get_latest_info(){
    local latest_info_file='/tmp/NeverIdle-latest-info.json'
    wget -q -O ${latest_info_file} https://api.github.com/repos/layou233/NeverIdle/releases/latest
    [[ $? -ne 0 ]] && log "Failed to get latest info" && exit 1
    latest_version=$(grep tag_name ${latest_info_file} | cut -d '"' -f 4 | sed 's/^v//g')
    latest_comments=$(grep body ${latest_info_file} | cut -d '"' -f 4)
    rm -f ${latest_info_file}
}

function auto_set_mem_test_size(){
    mem_test='-m 2'
    if [[ $mem_total -lt 4 ]]; then
        log "AMD doesn't need to test memory!"
        mem_test=''
    elif [[ $mem_total -lt 13 ]]; then
        log "Memory test size: [1G]"
        mem_test='-m 1'
    else
        log "Memory test size: [2G]"
    fi
}

function download_and_run() {
    local base_download_url="https://github.com/layou233/NeverIdle/releases/download"
    local filename="NeverIdle-${platform}"
    local download_dir="/tmp"
    local download_url="${base_download_url}/${latest_version}/${filename}"
    
    mkdir -p $download_dir
    rm -f ${download_dir}/NeverIdle

    log "Downloading ${filename} to ${download_dir}/NeverIdle ..."
    wget -q -O ${download_dir}/NeverIdle ${download_url}
    [[ $? -ne 0 ]] && log "Download ${filename} failed" && exit 1

    chmod +x ${download_dir}/NeverIdle
    
    # Handle memory test size
    if [[ "x${memory_test_size}" == "x" || ${memory_test_size} -gt $mem_total ]]; then
        log "Invalid memory size: [${memory_test_size}], auto-setting"
        auto_set_mem_test_size
    elif [[ "x${memory_test_size}" == "x0" ]]; then
        mem_test=''
        log "Memory test disabled."
    else
        mem_test="-m ${memory_test_size}"
        log "Memory test size: [${memory_test_size}G]"
    fi

    # Handle CPU test (mutually exclusive -c and -cp)
    log "Debug: cpu_percentage=[${cpu_percentage}], cpu_test_interval=[${cpu_test_interval}]"
    if [[ "x${cpu_percentage}" != "x" ]]; then
        if [[ $(echo "$cpu_percentage >= 0 && $cpu_percentage <= 1" | bc) -eq 1 ]]; then
            cpu_test="-cp ${cpu_percentage}"
            log "CPU percentage test: [${cpu_percentage}]"
            if [[ "x${cpu_test_interval}" != "x" ]]; then
                log "Error: -cp and -c cannot be used together, ignoring -c"
            fi
        else
            log "Invalid CPU percentage: [${cpu_percentage}], must be in [0, 1], using default -c 2h"
            cpu_test="-c 2h"
        fi
    else
        if [[ "x${cpu_test_interval}" == "x" ]]; then
            cpu_test="-c 2h"
            log "CPU test interval is empty, set to default value: [2h]"
        elif [[ "x${cpu_test_interval}" == "x0" ]]; then
            cpu_test="-c 2h"
            log "CPU test can't disable, set to default value: [2h]."
        else
            if [[ ${cpu_test_interval} =~ ^[0-9]+[hms][0-9]*[hms]?[0-9]*[hms]?$ ]]; then
                cpu_test="-c ${cpu_test_interval}"
                log "CPU test interval: [${cpu_test_interval}]"
            else
                cpu_test="-c 2h"
                log "Invalid CPU test interval format [${cpu_test_interval}], set to default [2h]"
            fi
        fi
    fi

    # Handle network test interval
    if [[ "x${network_test_interval}" == "x" ]]; then
        network_test="-n 4h"
        log "Network test interval is empty, set to default value: [4h]"
    elif [[ "x${network_test_interval}" == "x0" ]]; then
        network_test=""
        log "Network test disabled."
    else
        if [[ ${network_test_interval} =~ ^[0-9]+[hms][0-9]*[hms]?[0-9]*[hms]?$ ]]; then
            network_test="-n ${network_test_interval}"
            log "Network test interval: [${network_test_interval}]"
        else
            network_test="-n 4h"
            log "Invalid network test interval format [${network_test_interval}], set to default [4h]"
        fi
    fi

    # Handle network concurrent connections
    if [[ "x${network_concurrent}" != "x" ]]; then
        if [[ ${network_concurrent} -gt 0 ]]; then
            network_concurrent_param="-t ${network_concurrent}"
            log "Network concurrent connections: [${network_concurrent}]"
        else
            log "Invalid network concurrent connections: [${network_concurrent}], using default [10]"
            network_concurrent_param=""
        fi
    else
        network_concurrent_param=""
        log "Network concurrent connections: [default 10]"
    fi

    # Handle process priority
    if [[ "x${priority}" != "x" ]]; then
        if [[ ${priority} -ge -20 && ${priority} -le 19 ]]; then
            priority_param="-p ${priority}"
            log "Process priority: [${priority}]"
        else
            log "Invalid priority: [${priority}], must be in [-20, 19], using default lowest priority"
            priority_param=""
        fi
    else
        priority_param=""
        log "Process priority: [default lowest]"
    fi

    # Construct and run the command
    local cmd="${download_dir}/NeverIdle ${cpu_test} ${mem_test} ${network_test} ${network_concurrent_param} ${priority_param}"
    log "Command: ${cmd}"
    nohup ${cmd} > ${download_dir}/NeverIdle.log 2>&1 &
    local pid=$(pgrep NeverIdle)
    log "NeverIdle [${pid}] is running"
    log "Log file: ${download_dir}/NeverIdle.log"
    log "========================================"
    log "Run 'pkill NeverIdle' to stop it."
    log "Run 'rm -f ${download_dir}/NeverIdle ${download_dir}/NeverIdle.log' to clean it."
}

function print_help_msg(){
    echo "Usage:"
    echo -e "\t-c \t CPU test interval (e.g., 12h23m34s), default: 2h, can't disable."
    echo -e "\t-cp \t CPU percentage waste (0 to 1, e.g., 0.2 for 20%), can't be used with -c."
    echo -e "\t-m \t Memory test size in GiB, 0 to disable, auto-set if invalid (0/<4G: none, <13G: 1G, >13G: 2G)."
    echo -e "\t-n \t Network test interval (e.g., 4h), 0 to disable."
    echo -e "\t-t \t Network concurrent connections, default: 10."
    echo -e "\t-p \t Process priority (-20 to 19, higher is lower priority), default: lowest."
    echo -e "\t-h \t Show this help info."
    exit 0
}

function read_args(){
    log "Debug: Raw arguments: [$@]"
    while getopts ":c:cp:m:n:t:p:h" opt; do
        log "Debug: Parsing option: -$opt, argument: $OPTARG"
        case "$opt" in
            c)
              cpu_test_interval="$OPTARG";;
            cp)
              cpu_percentage="$OPTARG";;
            m)
              memory_test_size="$OPTARG";;
            n)
              network_test_interval="$OPTARG";;
            t)
              network_concurrent="$OPTARG";;
            p)
              priority="$OPTARG";;
            h)
              print_help_msg;;
            \?)
              log "Invalid option: -$OPTARG";;
            :)
              log "Option -$OPTARG requires an argument";;
        esac
    done

    # Validate inputs
    log "Debug: Parsed cpu_percentage=[${cpu_percentage}], memory_test_size=[${memory_test_size}], network_test_interval=[${network_test_interval}]"
    if [[ "x${cpu_percentage}" != "x" ]]; then
        if ! [[ ${cpu_percentage} =~ ^[0-1](\.[0-9]*)?$ || ${cpu_percentage} =~ ^[0-1]$ ]]; then
            log "Invalid CPU percentage format [${cpu_percentage}], must be in [0, 1], ignoring"
            cpu_percentage=""
        fi
    fi

    if [[ "x${memory_test_size}" != "x" && ${memory_test_size} -lt 0 ]]; then
        log "Invalid memory size [${memory_test_size}], auto-setting"
        memory_test_size=""
    fi

    if [[ "x${network_concurrent}" != "x" && ! ${network_concurrent} =~ ^[0-9]+$ ]]; then
        log "Invalid network concurrent connections [${network_concurrent}], using default [10]"
        network_concurrent=""
    fi

    if [[ "x${priority}" != "x" && ! ${priority} =~ ^-?[0-9]+$ ]]; then
        log "Invalid priority [${priority}], using default lowest priority"
        priority=""
    fi
}

function init(){
    mem_total=$(free -g | awk '/Mem/ {print $2}')
    case $(uname -m) in
        x86_64)
            platform="linux-amd64";;
        aarch64)
            platform="linux-arm64";;
        *)
            log "Unsupported platform!"
            exit 1;;
    esac
}

function keep_stop(){
    pkill -9 NeverIdle
}

function main(){
    keep_stop
    init
    get_latest_info
    download_and_run
}

read_args "$@"
main
