#!/bin/bash

source /etc/sysconfig/rc
source $RC_DIR/functions

for command_name in $@; do : ; done

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

if [ "$#" -lt "2" ] ; then
  print_msg "Wrong argument number"
  exit -127
fi

__service__service_names=()
__service__index=0
for __service__service_name in $@ ; do
  __service__index=$[__service__index+1]
  if [ "$__service__index" -eq "$#" ] ; then
    break
  fi
  if [ ! -r "$SERVICE_DIR/$__service__service_name" ] ; then
    print_msg "$__service__service_name is unknown"
    exit -125
  fi
  if [[ $__service__service_name =~ ^@.+ ]] ; then
    while read __service__line ; do
      if [ ! -r "$SERVICE_DIR/$__service__line" ] ; then
        print_msg "$__service__line is unknown"
        exit -125
      fi
      __service__service_names+=($__service__line)
    done<"$SERVICE_DIR/$__service__service_name"
  else
    __service__service_names+=($__service__service_name)
  fi
done

__service__command_names="$command_name"
if [ "$__service__command_names" == "restart" ] ; then
  __service__command_names="stop start"
fi

__service__first=1
for command_name in $__service__command_names ; do
  if [ "$__service__first" -eq 0 ] ; then
    sleep $RESTART_TIMEOUT
  fi
  __service__first=0

  __service__index=0
  for service_name in "${__service__service_names[@]}" ; do
    __service__index=$[__service__index+1]
    
    if [ "$command_name" == "stop" ]; then
      __service__reverse_index=0
      for service_name in "${__service__service_names[@]}" ; do
        __service__reverse_index=$[__service__reverse_index+1]
        if [ "$__service__reverse_index" -eq "$[${#__service__service_names[@]}+1-$__service__index]" ] ; then
          break;
        fi
      done
    fi
    
    ret_val="undefined"
    source $SERVICE_DIR/$service_name "$command_name"

    if [ "$ret_val" == "undefined" ] ; then
      if [ "$command_name" == "stop" ] ; then
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
    
    if [ "$ret_val" -ne "0" ] ; then
      break;
    fi

  done

  if [ "$ret_val" -ne "0" ] ; then
    break;
  fi

done

exit $ret_val
