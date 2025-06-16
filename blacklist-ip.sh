#!/bin/bash
set -x
# Everything below will go to the file 'log.out':
IP_TMP=/tmp/ip.tmp
IP_BLOCKLIST=/etc/blacklistip/ip-blocklist
IP_BLOCKLIST_TMP=/tmp/ip-blocklist.tmp
IP_BLOCKLIST_TMP2=/tmp/ip-blocklist2.tmp
IP_BLOCKLIST_TMP3=/tmp/ip-blocklist_
IP_BLOCKLIST_CUSTOM=/etc/ip-blocklist-custom.conf # optional
echo "" > $IP_BLOCKLIST
TMPFS=/tmp/fstmpip.tmp
mkdir -p /etc/blacklistip
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
sort $IP_BLOCKLIST_TMP -n | uniq > $IP_BLOCKLIST_TMP2

lines_per_file=5000
total_lines=$(wc -l < "$IP_BLOCKLIST_TMP2")
echo "$total_lines"
parts=$(printf %d "$[$total_lines / $lines_per_file]")

rm $IP_BLOCKLIST_TMP3*  2>/dev/null
rm $IP_BLOCKLIST*  2>/dev/null
split -d -l $lines_per_file "$IP_BLOCKLIST_TMP2" $IP_BLOCKLIST_TMP3
echo $parts
$parts+=1
for i in $(seq 0 $parts);
do	
	echo $i
	fp=$(printf %02d "$i")
	echo "$fp"
	fname="blocklist$fp"
	n_blacklisttmp="$IP_BLOCKLIST_TMP3$fp"
	n_blacklist="$IP_BLOCKLIST$fp.conf"
	echo "$n_blacklisttmp"
	sort $n_blacklisttmp -n | uniq > $n_blacklist
	
	#Flush the ipset
	ipset destroy $fname
	ipset create $fname hash:net family inet hashsize 5500 maxelem 5500
	ipset flush $fname

	#Add IP addresses to the ipset
	grep -v "^#|^$" $IP_BLOCKLIST | while IFS= read -r ip;
	do
		 ipset add blocklist $ip;
	done
	
	
	### Section for firewalld
	firewall-cmd --delete-ipset=$fname --permanent
	firewall-cmd --permanent --zone=drop --remove-source=ipset:$fname
	firewall-cmd --permanent --new-ipset=$fname --type=hash:net --option=family=inet --option=hashsize=1048576 --option=maxelem=1048576
	firewall-cmd --permanent --ipset=$fname --add-entries-from-file="/etc/blacklistip/ip-$fname.conf"
	firewall-cmd --permanent --zone=drop --add-source=ipset:$fname
	echo $fp
done
firewall-cmd --reload



#Remove temporary list
rm $IP_BLOCKLIST_TMP
rm $IP_BLOCKLIST_TMP2
rm $IP_BLOCKLIST_TMP3*

#count how many IP addresses are in the list
# wc -l $IP_BLOCKLIST
