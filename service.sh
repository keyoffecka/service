#!/bin/bash

source /etc/sysconfig/rc

service_name="$1"
command_name="$2"

function register() {
  if [ -z "${1:-}" ] ; then
    touch "$SERVICE_RUN_DIR/$service_name"
  else
    echo "$1" > "$SERVICE_RUN_DIR/$service_name"
  fi
}

function register_process_by_name() {
  local __pid="`pidof "$1"`"
  local __ret_val="0"
  
  local i=0
  while [ "$i" -lt "$TRY" -a -z "$__pid" ] ; do
    sleep $TIMEOUT
    __pid="`pidof "$1"`"
    __ret_val="$?"
    i=$[i+1]
  done

  if [ -n "$__pid" ] ; then
    echo "Found $__pid of $1 of $service_name"
    register "$__pid"
  else
    __ret_val="-125"
    echo "No process $1 found"
  fi
  
  return $__ret_val
}

function unregister() {
  rm "$SERVICE_RUN_DIR/$service_name"
  return "$?"
}

function success() {
  ret_val="${1:-0}"
}

function check_process_running() {
  local __pid="$1"
  
  kill -s 0 "$__pid" 2>/dev/null
  local __ret_val="$?"
  local i="0"
  while [ "$i" -lt "$TRY" -a "$__ret_val" == "0" ] ; do
    sleep $TIMEOUT
    kill -s 0 "$__pid" 2>/dev/null
    __ret_val="$?"
    i=$[i+1]
  done
  
  return $__ret_val
}

function try_stop_process() {
  local __signal="$1"
  local __pid="$2"
  
  kill -s "$__signal" "$__pid" 2>/dev/null
  kill -s 0 "$__pid" 2>/dev/null
  local __ret_val="$?"
  local i="0"
  while [ "$i" -lt "$TRY" -a "$__ret_val" == "0" ] ; do
    sleep $TIMEOUT
    kill -s "$__signal" "$__pid" 2>/dev/null
    kill -s 0 "$__pid" 2>/dev/null
    __ret_val="$?"
    i=$[i+1]
  done
  
  return $__ret_val
}

function __stop_process() {
  local __pid="`cat "$SERVICE_RUN_DIR/$service_name"`"
  
  echo "Trying to stop $__pid of $service_name gracefully"
  try_stop_process 15 "$__pid"
  local __ret_val="$?"
  if [ "$__ret_val" == "0" ] ; then
    echo -e "Tried graceful shutdown, but the process $__pid of $service_name is still running.\nWill try to force the process shutdown.\n"

    try_stop_process 9 "$__pid"
    local __ret_val="$?"
  fi
  
  if [ "$__ret_val" == "0" ] ; then
    echo "Failed to stop $__pid of $service_name"
    __ret_val="-121"
  else
    echo "Process $__pid of $service_name has been stopped successfully"
    unregister

    __ret_val="0"
  fi
  
  return $__ret_val
}

if [ "`id -u`" == "0" ] ; then
  [ -w "`dirname "$SERVICE_RUN_DIR"`" ] && mkdir -p $SERVICE_RUN_DIR
elif [ "$command_name" != "help" -a "$command_name" != "status" ] ; then
  echo "Should be ROOT"
  exit -126
fi

if [ "$#" != "2" ] ; then
  echo "Wrong argument number"
  exit -127
fi

ret_val="undefined"
source $SERVICE_DIR/$service_name "$command_name"

if [ "$ret_val" == "undefined" ] ; then
  if [ "$command_name" == "restart" ] ; then
    $SERVICE $service_name stop
    success "$?"
    if [ "$ret_val" == "0" ] ; then
      sleep $RESTART_TIMEOUT
      $SERVICE $service_name start
      success "$?"
    fi
  elif [ "$command_name" == "stop" ] ; then
    echo "Stopping $service_name"
    if $SERVICE $service_name status ; then
      __stop_process
      ret_val="$?"
    else
      echo "Failed to stop $service_name"
      ret_val="-111"
    fi
  elif [ "$command_name" == "status" ] ; then
    if [ -f "$SERVICE_RUN_DIR/$service_name" ]; then
      pid=`cat "$SERVICE_RUN_DIR/$service_name"`
      if [ "`ps --pid $pid | wc -l`" -gt "1" ]  ; then
         echo "Process $pid of $service_name is running!"
         success
       else
         echo "Process $pid of $service_name is registered but is not running"
         success "-103"
       fi
    else
      echo "No $service_name is registered"
      success "-102"
    fi
  else
    echo "Command $command_name is not supported by $service_name"
    success "-101"
  fi
fi

exit $ret_val
