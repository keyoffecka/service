#!/bin/bash

source /etc/sysconfig/rc
source $RC_DIR/functions

service_name="$1"
command_name="$2"

function __stop_process() {
  local __pid="`cat "$SERVICE_RUN_DIR/$service_name"`"
  
  print_msg "Trying to stop $__pid of $service_name gracefully"
  try_stop_process 15 "$__pid"
  local __ret_val="$?"
  if [ "$__ret_val" == "0" ] ; then
    print_msg -e "Tried graceful shutdown, but the process $__pid of $service_name is still running.\nWill try to force the process shutdown.\n"

    try_stop_process 9 "$__pid"
    local __ret_val="$?"
  fi
  
  if [ "$__ret_val" == "0" ] ; then
    print_msg "Failed to stop $__pid of $service_name"
    __ret_val="-121"
  else
    print_msg "Process $__pid of $service_name has been stopped successfully"
    unregister

    __ret_val="0"
  fi
  
  return $__ret_val
}

if [ "`id -u`" == "0" ] ; then
  [ -w "`dirname "$SERVICE_RUN_DIR"`" ] && mkdir -p $SERVICE_RUN_DIR
elif [ "$command_name" != "help" -a "$command_name" != "status" ] ; then
  print_msg "Should be ROOT"
  exit -126
fi

if [ "$#" != "2" ] ; then
  print_msg "Wrong argument number"
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
    print_msg "Stopping $service_name"
    if $SERVICE $service_name status ; then
      __stop_process
      ret_val="$?"
    else
      print_msg "Failed to stop $service_name"
      ret_val="-111"
    fi
  elif [ "$command_name" == "status" ] ; then
    if [ -f "$SERVICE_RUN_DIR/$service_name" ]; then
      pid=`cat "$SERVICE_RUN_DIR/$service_name"`
      if [ -n "$pid" ] ; then
        if [ "`ps --pid $pid | wc -l`" -gt "1" ]  ; then
           print_msg "Process $pid of $service_name is running!"
           success
         else
           print_msg "Process $pid of $service_name is registered but is not running"
           success "-103"
         fi
       else
         print_msg "Process $pid of $service_name is registered but is not running"
         success "-103"
       fi
    else
      print_msg "No $service_name is registered"
      success "-102"
    fi
  else
    print_msg "Command $command_name is not supported by $service_name"
    success "-101"
  fi
fi

exit $ret_val
