#!/bin/bash
set -x
# Everything below will go to the file 'log.out':
IP_TMP=/tmp/ip.tmp
IP_BLOCKLIST=/etc/ip-blocklist.conf
IP_BLOCKLIST_TMP=/tmp/ip-blocklist.tmp
IP_BLOCKLIST_CUSTOM=/etc/ip-blocklist-custom.conf # optional
echo "" > $IP_BLOCKLIST
TMPFS=/tmp/fstmpip.tmp

curl https://raw.githubusercontent.com/anonymoushunter1998/blackip/refs/heads/Master/list-master > $TMPFS
cat $TMPFS
cat $TMPFS > BLACKLISTS
echo $BLACKLISTS 

while IFS= read -r line
do
  curl $line > $IP_TMP
  cat $IP_TMP
  grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' $IP_TMP >> $IP_BLOCKLIST_TMP
done < "$TMPFS"

#Sort the list
sort $IP_BLOCKLIST_TMP -n | uniq > $IP_BLOCKLIST

#Remove temporary list
rm $IP_BLOCKLIST_TMP

#count how many IP addresses are in the list
wc -l $IP_BLOCKLIST

#Flush the ipset
ipset destroy blocklist
ipset create blocklist hash:ip
ipset flush blocklist

#Add IP addresses to the ipset
grep -v "^#|^$" $IP_BLOCKLIST | while IFS= read -r ip;
do
     ipset add blocklist $ip;
done

### Section for firewalld
firewall-cmd --delete-ipset=blocklist --permanent
firewall-cmd --permanent --new-ipset=blocklist --type=hash:net --option=family=inet --option=hashsize=1048576 --option=maxelem=1048576
firewall-cmd --permanent --ipset=blocklist --add-entries-from-file=/etc/ip-blocklist.conf
firewall-cmd --permanent --zone=drop --add-source=ipset:blocklist
firewall-cmd --reload
echo "Firewalld ipset list entries:"
firewall-cmd --permanent --ipset=blocklist --get-entries | wc -l
echo "ipset list entries:"
cat /etc/ip-blocklist.conf | wc -l
