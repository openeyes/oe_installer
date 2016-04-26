#!/bin/bash


# Verify we are running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Find real folder name where this script is located, then try symlinking it to /vagrant
# This is needed for non-vagrant environments - will silenly fail if /vagrant already exists
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# try the symlink - this is expected to fail in a vagrant environment
# TODO detect if running in a vagrant environment and don't try linking (it isn't necessary)
ln -s $DIR/.. /vagrant 2>/dev/null
if [ ! $? = 1 ]; then
	echo "
	$DIR has been symlinked to /vagrant
	"
fi

# copy our commands to /usr/bin
cp -f /vagrant/install/oe-* /usr/bin


# set command options
# Chose branch / tag to clone (default is master)
# set live
branch=master
defaultbranch=master
live=0
develop=0
force=0
customgitroot=0
gitroot=openeyes
cleanconfig=0
username=""
pass=""
httpuserstring=""
usessh=0
sshuserstring="git"
showhelp=0
checkoutparams=""
installpath="openeyes"
confpath=""
dbname=""
custompath=0
customconfpath=0
fixparams=""

# Process command line inputs
for i in "$@"
do
case $i in
    --live|-l|--upgrade) live=1
		## live will install for production ready environment
		;;
	--develop|-d|--d) develop=1; defaultbranch=develop; checkoutparams="$checkoutparams $i"
		## develop set default branches to develop if the named branch does not exist for a module
		;;
	--force|-f|--f) force=1
		## force will delete the www/openeyes directory without prompting - use with caution - useful to refresh an installation, or when moving between versions <=1.12 and verrsions >= 1.12.1
		;;
	--clean|-ff|--ff) force=1; cleanconfig=1
		## will completely wipe any existing openeyes configuration from /etc/openeyes - use with caution
		;;
	--root|-r|--r|--remote) customgitroot=1
		## Await custom root for git repo in net parameter
		;;
    -u*) username="${i:2}"; checkoutparams="$checkoutparams $i"
    ;;
    -p*) pass="${i:2}"; checkoutparams="$checkoutparams $i"
    ;;
    --ssh|-ssh) usessh=1; checkoutparams="$checkoutparams $i"
	;;
    --help) showhelp=1
    ;;
    --path) custompath=1; checkoutparams="$checkoutparams $i"; fixparams="$fixparams $i"
    ;;
    --conf-path) customconfpath=1; checkoutparams="$checkoutparams $i"; fixparams="$fixparams $i"
    ;;
	*)  if [ ! -z "$i" ]; then
			if [ "$customgitroot" = "1" ]; then
				gitroot=$i
				customgitroot=0
                $checkoutparams="$checkoutparams -r $i"
				## Set root path to repo
            elif [ $custompath = 1 ]; then
                installpath=$i
                custompath=0
                checkoutparams="$checkoutparams $i"
                fixparams="$fixparams $i"
            elif [ $customconfpath = 1 ]; then
                confpath=$i
                customconfpath=0
                checkoutparams="$checkoutparams $i"
                fixparams="$fixparams $i"
			elif [ "$branch" == "master" ]; then
                branch=$i
            else echo "Unknown command line: $i"
				## Set branch name
			fi
		fi
    ;;
esac
done

# Show help text
if [ $showhelp = 1 ]; then
    echo ""
    echo "DESCRIPTION:"
    echo "Installs the openeyes application"
    echo ""
    echo "usage: $0 <branch> [--help] [--force | -f] [--no-migrate | -n] [--kill-modules | -ff ] [--no-compile] [-r <remote>] [--no-summary] [--develop | -d] [-u<username>]  [-p<password>]"
    echo ""
    echo "COMMAND OPTIONS:"
    echo "  <branch>       : Install the specified <branch> / tag - defualt is to install master"
    echo "  --help         : Display this help text"
    echo "  --force | -f   : delete the www/openeyes directory without prompting "
    echo "                   - use with caution - useful to refresh an installation,"
    echo "                     or when moving between versions <=1.12 and versions >= 1.12.1"
    echo "  --clean | -ff  : will completely wipe any existing openeyes configuration "
    echo "                   out. This is required when switching between versions <= 1.12 "
    echo "                   from /etc/openeyes - use with caution"
    echo "  -r <remote>    : Use the specifed remote github fork - defaults to openeyes"
    echo "  --develop "
    echo "           |-d   : If specified branch is not found, fallback to develop branch"
    echo "                   - default woud fallback to master"
    echo "  -u<username>   : Use the specified <username> for connecting to github"
    echo "                   - default is anonymous"
    echo "  -p<password>   : Use the specified <password> for connecting to github"
    echo "                   - default is to prompt"
    echo "  -ssh		   : Use SSH protocol  - default is https"
    echo ""
    exit 1
fi

# If custom path has been set, but no custom configpath/dbmane then assume config path and db name will be same as custom install path name
if [ -z $confpath ]; then
    confpath=$installpath
fi

if [ -z $dbname ]; then
    dbname=$installpath
fi

# copy our new configs to /etc/$confpath (don't overwrite existing config)
mkdir -p /etc/$confpath
cp -n /vagrant/install/etc/openeyes/* /etc/$confpath/
cp -n /vagrant/install/bashrc /etc/bash.bashrc

echo "

Installing openeyes $branch from https://gitgub.com/$gitroot
To /var/www/$installpath

"


# Terminate if any command fails
set -e

echo "
Downloading OpenEyes code base...
"

cd /var/www

# If $installpath dir exists, prompt user to delete it
if [ -d "$installpath" ]; then
	if [ ! "$force" = "1" ]; then
		echo "
CAUTION: $installpath folder already exists.
This installer will delete it. Any uncommitted changes will be lost!
If you're upgrading this is necessary.
Do you wish to continue?
"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) echo "OK."; force="1"; break;;
				No ) echo "OK, aborting. Nothing has been changed...
				"; exit;;
			esac
		done
	fi

	if [ "$force" = "1" ]; then
        # If cleanconfig (-ff) has been given on the command line, then completely
        # wipe the existing oe config before continuing. USE WITH EXTREME CAUTION
		if [ "$cleanconfig" = "1" ]; then
			echo "cleaning old config from /etc/$confpath"
			rm -rf /etc/$confpath
			mkdir /etc/$confpath
			cp -f /vagrant/install/etc/openeyes/* /etc/$confpath/
			cp -f /vagrant/install/bashrc /etc/bash.bashrc
		fi
        # END of cleanconfig

		if [ -d "$installpath/protected/config" ]; then
			echo "backing up previous configuration to /etc/$confpath/backup"
			mkdir -p /etc/$confpath/backup/config
			cp -f -r $installpath/protected/config/* /etc/$confpath/backup/config/
		fi

		echo "Removing existing $installpath folder"
		rm -rf $installpath
	fi

fi

echo calling oe-checkout with $checkoutparams
oe-checkout $branch -f --no-summary --no-fix $checkoutparams


cd /var/www/$installpath/protected
echo "uzipping yii. Please wait..."
if unzip -oq yii.zip ; then echo "."; fi
if unzip -oq vendors.zip ; then echo "."; fi

git submodule init
git submodule update -f

# keep a copy of these zips around in case we checkout an older branch that does not include them
mkdir -p /usr/lib/openeyes
cp yii.zip /usr/lib/openeyes 2>/dev/null || :
cp vendors.zip /usr/lib/openeyes 2>/dev/null || :
cd /usr/lib/openeyes
if [ ! -d "yii" ]; then echo "."; if unzip -oq yii.zip ; then echo "."; fi; fi
if [ ! -d "vendors" ]; then echo "."; if unzip -oq vendors.zip ; then echo "."; fi; fi


mkdir -p /var/www/$installpath/cache
mkdir -p /var/www/$installpath/assets
mkdir -p /var/www/$installpath/protected/cache
mkdir -p /var/www/$installpath/protected/runtime
chmod 777 /var/www/$installpath/cache
chmod 777 /var/www/$installpath/assets
chmod 777 /var/www/$installpath/protected/cache
chmod 777 /var/www/$installpath/protected/runtime
if [ ! `grep -c '^vagrant:' /etc/passwd` = '1' ]; then
	chown -R www-data:www-data /var/www/*
fi


if [ ! "$live" = "1" ]; then
    echo ""
	echo "Creating blank database..."
	cd $installdir

	echo "
	drop database if exists $dbname;
	create database $dbname;
	grant all privileges on $dbname.* to '$dbname'@'%' identified by '$dbname';
	flush privileges;
	" > /tmp/openeyes-mysql-create.sql

	mysql -u root "-ppassword" < /tmp/openeyes-mysql-create.sql
	rm /tmp/openeyes-mysql-create.sql


    # Create correct user string to pass to github
    if [ ! -z $username ]; then
        if [ ! -z $pass ]; then
    		sshuserstring="$username"
            httpuserstring="${username}:${pass}@"
        else
    		sshuserstring="$username"
            httpuserstring="${username}@"
        fi
    fi

    # Set base url string for cloning all repos
    basestring="https://${httpuserstring}github.com/$gitroot"

    # If using ssh, change the basestring to use ssh format
    if [ $usessh = 1 ]; then
    	basestring="${sshuserstring}@github.com:$gitroot"
    fi


	echo Downloading database
	cd /var/www/$installpath/protected/modules
	if ! git clone -b $branch ${basestring}/Sample.git sample ; then
		echo "$branch doesn't exist for sample database. Falling back to $defaultbranch branch for openeyes..."
        if ! git clone -b $defaultbranch ${basestring}/sample.git sample ; then
			# If we cannot find default branch at specifeid remote, fall back to OE git hub
			if [ "$gitroot != "openeyes ]; then
				echo "could not find $defaultbranch at $gitroot remote. Falling back to openeyes official repo"
				git clone -b $defaultbranch ${basestring/$gitroot/openeyes}/sample.git sample
			fi
		fi
	fi

	cd sample/sql
	mysql -uroot "-ppassword" -D $dbname < openeyes_sample_data.sql

	# # Set banner to show branch name
	echo "
	use $dbname;
	UPDATE $dbname.setting_installation s SET s.value='New openeyes installation - $branch' WHERE s.key='watermark';
	" > /tmp/openeyes-mysql-setbanner.sql

	mysql -u root "-ppassword" < /tmp/openeyes-mysql-setbanner.sql
	rm /tmp/openeyes-mysql-setbanner.sql

    sed -i "s/'dbname' => 'openeyes',/'dbname' => '$dbname',/" /var/www/$installpath/protected/config/local/common.php
    sed -i "s,parse_ini_file('/etc/openeyes/db.conf',parse_ini_file('/etc/$confpath/db.conf'," /var/www/$installpath/protected/config/local/common.php
    sed -i "s/dbname=openeyes/dbname=$dbname/" /etc/$confpath/db.conf
    '/etc/openeyes/db.conf'

fi

# call oe-fix
oe-fix $fixparams

# echo Performing database migrations
#
# cd /var/www/$installpath/protected
# ./yiic migrate --interactive=0
# ./yiic migratemodules --interactive=0


if [ ! "$live" = "1" ]; then
	echo Configuring Apache

	echo "
	<VirtualHost *:80>
	ServerName hostname
	DocumentRoot /var/www/$installpath
	<Directory /var/www/$installpath>
		Options FollowSymLinks
		AllowOverride All
		Order allow,deny
		Allow from all
	</Directory>
	ErrorLog /var/log/apache2/error.log
	LogLevel warn
	CustomLog /var/log/apache2/access.log combined
	</VirtualHost>
	" > /etc/apache2/sites-available/000-default.conf

	apache2ctl restart
fi


# The default environment type is assumed to be DEV/AWS.
# If we are on a vagrant box, set it to DEV/VAGRANT
# For live systems, /etc/$confpath/env.conf will have to be edited manually

if [ `grep -c '^vagrant:' /etc/passwd` = '1' ]; then
  hostname OpenEyesVM
  sed -i "s/envtype=AWS/envtype=VAGRANT/" /etc/$confpath/env.conf
  cp -f /vagrant/install/bashrc /home/vagrant/.bashrc
fi

if [ "$live" = "1" ]; then
echo "# env can be one of DEV or LIVE
# envtype can be one of LIVE, AWS or VAGRANT
env=LIVE
envtype=LIVE
" >/etc/$confpath/env.conf
fi


# Copy DICOM related files in place as required
cp -f /vagrant/install/dicom-file-watcher.conf /etc/init/
cp -f /vagrant/install/dicom /etc/cron.d/
cp -f /vagrant/install/run-dicom-service.sh /usr/local/bin
chmod +x /usr/local/bin/run-dicom-service.sh

id -u iolmaster &>/dev/null || useradd iolmaster -s /bin/false -m
mkdir -p /home/iolmaster/test
mkdir -p /home/iolmaster/incoming
chown iolmaster:www-data /home/iolmaster/*
chmod 775 /home/iolmaster/*

echo ""
oe-which $fixparams

echo --------------------------------------------------
echo OPENEYES SOFTWARE INSTALLED
echo Please check previous messages for any errors
echo --------------------------------------------------
