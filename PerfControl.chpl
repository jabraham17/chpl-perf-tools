module PerfControl {
  private use IO;

  enum Command {
    enable,
    disable,
  }

  private inline proc commandToString(cmd: Command): string {
    select cmd {
      when Command.enable do return "enable";
      when Command.disable do return "disable";
      otherwise do halt("unknown command");
    }
  }
  private inline proc getEnv(name: string): string {
    use OS.POSIX only getenv;
    private use CTypes;
    var envname = name + "_" + here.hostname:string;
    var cstr = getenv(envname.c_str());
    return try! string.createBorrowingBuffer(cstr);
  }
  private inline proc getFD(name: string): int {
    var env = getEnv(name);
    if env == "" then return -1;
    return try! (env:int);
  }

  proc controlPerfCounters(cmd: Command, loc: locale = here) {
    on loc do try! {
      var perfCtlFD = getFD("CHPL_PERF_CTL_FD");
      if perfCtlFD != -1 {
        var perfCtlAckFD = getFD("CHPL_PERF_CTL_ACK_FD");
        if perfCtlAckFD == -1 {
          halt("CHPL_PERF_CTL_ACK_FD must be set if CHPL_PERF_CTL_FD is set");
        }

        // get IO.file handles to the low-level file descriptors
        var perfCtl = new file(perfCtlFD, own=false);
        var perfCtlAck = new file(perfCtlAckFD, own=false);
        var perfCtlWriter = perfCtl.writer();
        var perfCtlAckReader = perfCtlAck.reader();

        // write the command to the perf control file
        perfCtlWriter.write(commandToString(cmd) + "\n");
        perfCtlWriter.flush();

        // read the acknowledgement from the perf control file
        var ack = perfCtlAckReader.readString(4);
        if ack != "ack\n" {
          halt("failed to acknowledge perf control signal");
        }
      }
    }
  }

  proc enablePerfCounters(loc: locale = here) do
    controlPerfCounters(Command.enable, loc);
  proc disablePerfCounters(loc: locale = here) do
    controlPerfCounters(Command.disable, loc);

  proc enableAllPerfCounters() do
    for loc in Locales do enablePerfCounters(loc);
  proc disableAllPerfCounters() do
    for loc in Locales do disablePerfCounters(loc);


}
