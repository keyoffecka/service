#!/usr/bin/bash

source /etc/sysconfig/rc
source $RC_DIR/functions

export PRINT_TO_TTY1="yes"

__curent_runlevel="$1"

function __start_them_all() {
  local processes_to_start=()
  local process=""
  local line=""

  while read line ; do
    local found=false
    if [ -n "$line" ] ; then
      for process in $(ls $SERVICE_RUN_DIR -1) ; do
        if [ "$line" == "$process" ] ; then
          PRINT_TO_TTY1="no" $SERVICE $process status >/dev/null 2>&1
          local status="$?"
          if [ "$status" == "0" -o "$status" == "153" ] ; then #0 - is running, 153 - is registered but is not running
            found=true
            break
          fi
        fi
      done
      if ! $found ; then
        processes_to_start+=($line)
      fi
    fi
  done < $RC_DIR/rc$__curent_runlevel

  while read line ; do
    if [ -n "$line" ] ; then
      for process in ${processes_to_start[@]} ; do
        if [ "$line" == "$process" ] ; then
          $SERVICE $process start
          break;
        fi
      done
    fi
  done < $RC_DIR/start-deps
}

function __kill_them_all() {
  local processes_to_kill=()
  local process=""
  local line=""
  for process in $(ls $SERVICE_RUN_DIR -1) ; do
    if [ -n "$process" ] ; then
      PRINT_TO_TTY1="no" $SERVICE $process status >/dev/null 2>&1
      local status="$?"
      if [ "$status" == "0" -o "$status" == "153" ] ; then #0 - is running, 153 - is registered but is not running
        local found=false
        while read line ; do
          if [ "$line" == "$process" ] ; then
            found=true;
            break;
          fi
        done < $RC_DIR/rc$__curent_runlevel

        if ! $found ; then
          processes_to_kill+=($process)
        fi
      fi
    fi
  done

  while read line ; do
    if [ -n "$line" ] ; then
      for process in ${processes_to_kill[@]} ; do
        if [ "$line" == "$process" ] ; then
          $SERVICE $process stop
          break;
        fi
      done
    fi
  done < $RC_DIR/kill-deps
}

function __start_rc_sysinit() {
  local line=""
  while read line ; do
    if [ -n "$line" ] ; then
      $SERVICE $line start
    fi
  done < $RC_DIR/rc-sysinit
}

if [ "$__curent_runlevel" == "sysinit" ] ; then
  __start_rc_sysinit
else
  __prev_runlevel="$(runlevel | awk '{print $1}')"

  if [ "$__prev_runlevel" != "N" ] ; then
    print_msg "Stopping processes"
    __kill_them_all
  fi
  __start_them_all
fi
