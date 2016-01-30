#!/usr/bin/expect
spawn ./setup-seafile.sh
expect "Press \\\[ENTER\\\]"
send "\n"
expect "\\\[server name\\\]:"
send "{{ server.config.name }}\n"
expect "\\\[This server's ip or domain\\\]:"
send "{{ server.config.domain }}\n"
expect "\\\[default: {{ server.dir }}/seafile-data \\\]"
send "\n"
expect "\\\[default: 8082 \\\]"
send "\n"
expect "press \\\[ENTER\\\]"
send "\n"
expect "Press \\\[ENTER\\\]"
send "\n"
expect "completed successfully."

spawn ./seafile.sh start
expect eof

spawn ./seahub.sh start
expect "\\\[ admin email \\\]"
send "{{ server.config.admin }}\n"
expect "\\\[ admin password \\\]"
send "{{ server.config.password }}\n"
expect "\\\[ admin password again \\\]"
send "{{ server.config.password }}\n"
expect "Done."

spawn ./seahub.sh stop
expect eof
spawn ./seafile.sh stop
expect eof