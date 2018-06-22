#!/bin/sh
# Author: Konrad Klimaszewski <graag666@gmail.com>
# Based on http://dl.eko.one.pl/projekty/hilink/99-hilink-pin.sh by Cezary Jackiewicz
#
# Script for OpenWRT that unlocks SIM card on Huawei E3372 Hilink modems.

DEBUG=0

[ $ACTION = "ifup" ] || exit 0
[ $INTERFACE = "wan" ] || exit 0
PROTO=$(uci -q get network.wan.proto)
[ "x$PROTO" = "xdhcp" ] || [ "x$PROTO" = "xstatic" ] || exit 0
PIN=$(uci -q get network.wan.pincode)
[ "x$PIN" = "x" ] && exit 0
PASSWORD=$(uci -q get network.wan.password)
[ "x$PASSWORD" = "x" ] && exit 0

sleep 5

. /lib/functions/network.sh
network_get_gateway GATEWAY wan
[ -z "$GATEWAY" ] && exit 0

# Get session cookie and request token for login request
SessionData=$(curl -s http://$GATEWAY/api/webserver/SesTokInfo)
SessionID=$(echo "$SessionData" | awk -F[\<\>] '/<SesInfo>/ {print $3}')
Token=$(echo "$SessionData" | awk -F[\<\>] '/<TokInfo>/ {print $3}')

[ "$DEBUG" == "1" ] && echo "SessionID: $SessionID"
[ "$DEBUG" == "1" ] && echo "Token: $Token"

[ -z "$Token" ] && exit 0
[ -z "$SessionID" ] && exit 0

# Encode password for type 4 hilik password requests
EncPass=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}' | tr -d '\n' | base64 -w 0)
LoginToken=$(echo -n "admin$EncPass$Token" | sha256sum | awk '{print $1}' | tr -d '\n' | base64 -w 0)
# Login
LoginData=$( \
    curl -D - -s -o /dev/null -X POST \
        -H "Cookie: $SessionID" \
        -H "__RequestVerificationToken: $Token" \
        -d "<request><Username>admin</Username><Password>$LoginToken</Password><password_type>4</password_type></request>" \
        http://$GATEWAY/api/user/login \
    )

[ "$DEBUG" == "1" ] && echo "Login data: $LoginData"

# Extract new session and request token
Token=$(echo "$LoginData" | grep "__RequestVerificationToken:" | awk -F: '{print $2}' | awk -F# '{print $1}')
SessionID=$(echo "$LoginData" | grep Set-Cookie | awk -F: '{print $2}' | awk -F\; '{print $1}')

[ "$DEBUG" == "1" ] && echo "Login SessionID: $SessionID"
[ "$DEBUG" == "1" ] && echo "Login Token: $Token"

[ -z "$Token" ] && exit 0
[ -z "$SessionID" ] && exit 0

# Test the SIM state
SimState=$(curl -s http://$GATEWAY/api/monitoring/converged-status -H "Content-Type: text/xml" -H "Cookie: $SessionID" | grep SimState | cut -d '>' -f2 | cut -d '<' -f1)
[ "$DEBUG" == "1" ] && echo "Current SIM state: $SimState"
if [ "x$SimState" = "x260" ]; then
    # Unlock the SIM card
    Result=$(curl -s -X POST \
        -H "__RequestVerificationToken: $Token" \
        -H "Content-Type: text/xml" \
        -H "Cookie: $SessionID" \
        -d "<request><OperateType>0</OperateType><CurrentPin>$PIN</CurrentPin><NewPin></NewPin><PukCode></PukCode></request>" \
        http://$GATEWAY/api/pin/operate)
    [ "$DEBUG" == "1" ] && echo "Result: $Result"
fi

