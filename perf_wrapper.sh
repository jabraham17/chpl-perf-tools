#!/usr/bin/env bash

# set CHPL_LAUNCHER_REAL_WRAPPER to use this
# set CHPL_PERF_BASE_NAME to use a different name for the perf.data file
# set CHPL_PERF_CMD to use different perf command (e.g. stat)
# set CHPL_PERF_ARGS to pass additional arguments to perf
# set CHPL_PERF_USE_CTL to use perf control interface

name=$(hostname)

perf_name=perf.data.$name
if [ ! -z $CHPL_PERF_BASE_NAME ]; then
  perf_name=perf.data.$CHPL_PERF_BASE_NAME.$name
fi
perf_cmd="record"
if [ ! -z $CHPL_PERF_CMD ]; then
  perf_cmd=$CHPL_PERF_CMD
fi

perf_args=""

if [ ! -z "$CHPL_PERF_ARGS" ]; then
  perf_args="$perf_args $CHPL_PERF_ARGS"
fi

if [ ! -z $CHPL_PERF_USE_CTL ]; then
  ctl_dir=perf_ctl/
  mkdir -p ${ctl_dir}
  ctl_fifo=${ctl_dir}perf_ctl_$name.fifo
  test -p ${ctl_fifo} && unlink ${ctl_fifo}
  mkfifo ${ctl_fifo}
  exec {ctl_fd}<>${ctl_fifo}

  ctl_ack_fifo=${ctl_dir}perf_ctl_ack_$name.fifo
  test -p ${ctl_ack_fifo} && unlink ${ctl_ack_fifo}
  mkfifo ${ctl_ack_fifo}
  exec {ctl_fd_ack}<>${ctl_ack_fifo}

  perf_args=$perf_args" --delay=-1 --control fd:${ctl_fd},${ctl_fd_ack}"

  export CHPL_PERF_CTL_FD_$name=${ctl_fd}
  export CHPL_PERF_CTL_ACK_FD_$name=${ctl_fd_ack}
fi

(set -x && /usr/bin/perf $perf_cmd -o $perf_name $perf_args -- $@)

if [ ! -z $CHPL_PERF_USE_CTL ]; then
  exec {ctl_fd_ack}>&-
  unlink ${ctl_ack_fifo}

  exec {ctl_fd}>&-
  unlink ${ctl_fifo}
fi
