#!/usr/bin/expect -f
        set timeout 20
        set IPaddress [lindex $argv 0]
        set Username "root"
        set Password "mypw"
       # set Directory DIRECTORY_PATH

        #log_file -a $Directory/session_$IPaddress.log
        #send_log "### /START-SSH-SESSION/ IP: $IPaddress @ [exec date] ###\r"
       spawn ssh -t -o StrictHostKeyChecking=no $Username@$IPaddress  \"[lindex $argv 1 ]\"
        expect "*assword: "
        send "$Password\r"

        interact
	expect eof;
        #send_log "\r### /END-SSH-SESSION/ IP: $IPaddress @ [exec date] ###\r"
exit
