print_help () {
printf "
Usage: revoke [OPTION]
Download and host CRL information from remote Certificate Authority.

 Mandatory arguments to long options are mandatory for short options too.
   --help                     this help text
   --version                  prints version information
   --status                   prints configuration information
   --install-cron             installs script into cron

 Exit status:
   0  if OK,
   1  if minor problems (e.g., cannot access subdirectory),
   2  if serious trouble (e.g., cannot access command-line argument).

Documentation and source at <https://github.com/tonycavella/revoke>

"
}
