#!/usr/bin/expect
spawn ./upgrade/{{ server.upgrade }}
expect "Press \\\[ENTER\\\]"
send "\n"
expect eof
