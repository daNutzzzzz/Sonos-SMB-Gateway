# Sonos-SMB-Gateway
 
 This is an SMB1 anonymous/guest server that works solely for Sonos S1 speakers. It has been build on Node and is a fork of adobe/node-smb-server.

## Why?
When Sonos introduced their S2 controller system they excluded older devices. In my opinion this move was for financial reasons only. If there where features that where too heavy for older devices they could have just brought these new features to newer devices and maintain (API) compatibility for existing features across new and old devices. While I have cheaper Sonos players like Symfonisk and Play:1 that support S2, I also have a Sonos Zoneplayer S5 (Play 3) and a Sonos Zoneplayer 120 (AMP), these are the only ones I have with a line-in and replacing them is costly as Sonos makes sure any speaker with a linein is in the higher priced segment. Sonos speakers running on the S1 system support SMBv1 with NTLMv1 only and support for this will eventually be dropped from Samba. In the mean time new versions of Samba will disable support for older unsecure protocol versions by default and distros do have the option to disable these at compile time. Which means from time to time you will have to invest time in keeping your configuration in working state. That said you can still use Samba today thanks to Jeremy Allison from the Samba project and Nelson Minar for debugging! I am committed to keep this project in a working state for as long as my Sonos S1 players are still working and I will try and repair them if that day comes.

## Warning
This SMB Server is unsecure I am focused on getting it to work on Sonos, you should not use it for something else. Everyone having access to port 445 may access all shares and can possibly do nasty things. This project will have out of date dependencies with known vulnerabilities. 

This work is released AS IS, WITHOUT WARRANTIES OF ANY KIND see the Apache License Version 2.0 included in the sources for more details. 

## When should use this? If you are not able to get Samba to work on your Sonos S1 system. For Sonos S2 you should be able to use Samba, but I do not have S2 speakers so I do not test on them. For setting up Sonos S1 on Samba I have two working config examples:
 • Ubuntu 20, Debian 11 Samba 4.13 smb.conf example modify to fit your needs.
 • Ubuntu 22 Samba 4.15 smb.conf example modify to fit your needs.

By all means do not use the Node SMB server if you need a secure SMB/CIFS server.

## Installing
You should set-up a dedicated virtual machine for running your SMB server. If you want extra safety you can put all your music on a read-only file system. Don’t forget to make backups. This SMB server won’t work with most other clients, including smbclient/fuse so if you want to be able to add more music later on, you can do this via SSH, NFS or you can go crazy and install Nextcloud. But remember you probably cannot use SMB to add music. This project is tested on Ubuntu 20 LTS, Ubuntu 22 LTS and Debian 11. Installing using automated installer Again use at your own risk, if you do not like running random scripts downloaded from the Internet, follow the manual installation steps. Run the following commands as root sudo su.

```
wget https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/install-sonos-smb.sh -O /tmp/install-sonos-smb.sh
chmod +x /tmp/install-sonos-smb.sh
/tmp/install-sonos-smb.sh
```

## Manual installation steps
Run the following commands as root sudo su. Note that lines that start with cat >> you have to copy multiple lines from cat >> … <<EOF … multiple lines to the final EOF. If you have trouble copy/pasting from the pdf, the README.md is also in the installation package.

```
apt install nodejs npm wget net-tools libcap2-bin

cat >> /usr/local/sbin/start-sonos-smb << EOF
#!/bin/bash
cd /etc/node-smb-server
npm start &
EOF
cat >> /etc/systemd/system/rc-local.service << EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
EOF

systemctl enable /etc/systemd/system/rc-local.service

cat >> /etc/rc.local << EOF
#!/bin/bash
/bin/rm -f /var/log/node-smb-server/*
/usr/local/sbin/start-sonos-smb &
exit 0
EOF

cat <<'EOF' >> /usr/local/sbin/smb-pacemaker
#!/bin/bash
STATUS=$(netstat -tulpn | grep ":445 " | wc -l)
if test $STATUS -ne 1; then
killall node
/usr/local/sbin/start-sonos-smb &
fi
EOF

chmod +rx /etc/rc.local
chmod +rx /usr/local/sbin/start-sonos-smb
chmod +rx /usr/local/sbin/smb-pacemaker

systemctl stop smbd
systemctl stop nmbd
systemctl disable smbd
systemctl disable nmbd

mkdir /var/log/node-smb-server
chmod ugo+w /var/log/node-smb-server/

mkdir /etc/node-smb-server
cd /etc/node-smb-server

wget https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/sonossmb.tar.gz -O /etc/node-smb-server/sonossmb.tar.gz
tar -xvf sonossmb.tar.gz
npm install

#open port 445 in the firewall
ufw allow 445/tcp
firewall-cmd --permanent --add-service=samba
firewall-cmd --reload
iptables -A INPUT -p tcp -m tcp --dport 445 -j ACCEPT
setcap 'cap_net_bind_service=+ep' `which node`

cat >> /etc/cron.d/sonossmb << EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
* *  * * * root /usr/local/sbin/smb-pacemaker
EOF
```

There is no support for SystemD because I do not like it.

## Setting up your share
Set-up your share in the /etc/node-smb-server/config.json file. You can either put your music in /home/public or change the path in config.json so it points to your music folder.

```
  "shares": {
    "public": {
      "backend": "fs",
      "description": "Music Collection",
      "path": "/home/public"
    }
  }
```

After making changes run killall node and run /usr/local/sbin/start-sonos-smb to start it again or wait a minute for the pacemaker to restart it.

In the Sonos S1 app go to Music Libary Setup and tap the Add Shared Music Folder option. Then use //ip-of-your-server/PUBLIC with the username guest and empty password. Here are some screenshots:

![alt text](https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/images/Screenshot_1)

![alt text](https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/images/Screenshot_2)

![alt text](https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/images/Screenshot_3)

## Troubleshooting
There is a lot of logging that can help with debugging, you can run the following command and watch the output while hitting the play button on the Sonos controller, assuming you have a playlist with music coming from your share:
```
tail -f /var/log/node-smb-server/*.log
```

While probably not useful, you can try and use smbclient from Samba to list your shares from this Sonos SMB server. You would need the following in /etc/samba/smb.conf
```
 [global]
    #Required for Sonos S1
    server min protocol = NT1
    client min protocol = NT1
    client use spnego = no
    client ntlmv2 auth = no
    ntlm auth = true
    ntlm auth = ntlmv1-permitted
```
You can then use smbclient as follows:
```
smbclient \\\\ip-or-fqdn\\PUBLIC -U guest%
```
Replace ip-or-fqdn with the IP or DNS domain name of the Sonos SMB server. Replace PUBLIC with the name of your share. You can use commands such as ls, cd and help to browse your share.

Another useless thing, mounting a share works by running the following commands as root:
```
 apt install cifs-utils #ubuntu
 apt install smbclient #debian
 mkdir /media
 mount -t cifs -o rw,username=guest,password="",vers=1.0 //ip-or-fqdn/PUBLIC /media/
```

### Tested Speakers, OS and Node versions

| Speaker | SoftwareVersion | HardwareVersion | Software date |
| --- | --- |
| Play:1 | 57.10-25140 | 1.20.1.6-2.1 | 2022-01-14 |
| Symfonisk Shelf (gen 1) | 57.10-25140 | 1.20.3.3-2.0 | 2022-01-14 |
| Zoneplayer 120 (Amp gen 1) | 57.10-25140 | 1.16.3.1-2.0 | 2022-01-14 |
| Zoneplayer S5 (Play:5 gen 1) | 57.10-25140 | 1.16.4.1-2.0 | 2022-01-14 |
| ZonePlayer S5 (Play:5 gen 1) | 57.13-34140 | 1.16.4.1-1.0 | 2022-01-14 |

NPM versions 7.5.2, 8.5.1. Node versions 12.22.9, 12.22.12, 14, 18.12.1*. Ubuntu 22.04, Debian 11.

### Known issues with Node 18 and above*
Instead of npm start use export NODE_OPTIONS=--openssl-legacy-provider && npm start. See: stackoverflow thread.

### Alternatives?
The only thing that comes to mind is running an older version of Samba in Docker.

### Disable logging
If everything works, you may want to turn off the logging, this benefits SSD lifetime:
```
mv /etc/node-smb-server/logging.json /etc/node-smb-server/_logging.json
```
To re-enable logging:
```
mv /etc/node-smb-server/_logging.json /etc/node-smb-server/logging.json
```
Restart the SMB server to apply the change.

### Changelog
To make Sonos work only one change is needed from the original source in lib/smb/cmd/tree_connect_andx.js:
```
#replace this line:
var shareName = msg.path.substring(msg.path.lastIndexOf('\\') + 1);
#with this line:
var shareName = msg.path.substring(msg.path.lastIndexOf('\\') + 1).toUpperCase();
```