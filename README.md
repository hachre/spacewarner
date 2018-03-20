# SpaceWarner
Warns when disk space is dangerously low and sends notification mails.

### Installation
- Step 1: Run the following commands:
```
cd /opt
git clone https://github.com/hachre/spacewarner.git
cd spacewarner
chmod a+x update.sh
./update.sh
ln -s /opt/spacewarner/spacewarner.sh /bin/spacewarner # Optional
cp spacewarner.dist.conf /etc/spacewarner.conf
```
- Step 2: Edit `/etc/spacewarner.conf` and choose whether you want warning mails at all and if so which backend to use.
- Step 3: Test the mail setup by running `spacewarner --mailtest`. You should receive a simple test mail.
- Step 4: Check whether your devices are correctly shown by running `spacewarner`. Entries marked BAD will cause a mail notification to be sent to you.
- Step 5: Put SpaceWarner into your crontab by adding something like this:
```
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
0 * * * * spacewarner --cron
```

### Update
- Simply run the following command:
```
/opt/spacewarner/update.sh
```

