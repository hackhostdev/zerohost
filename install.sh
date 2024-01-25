#!/bin/bash
Infon()
{
 printf "\033[1;32m$@\033[0m"
}
Info()
{
 Infon "$@\n"
}
Error()
{
 printf "\033[1;31m$@\033[0m\n"
}
Error_n()
{
 Error "$@"
}
Error_s()
{
 Error "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_s()
{
 Info "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_n()
{
 Info "$@"
}
log_t()
{
 log_s
 Info "- - - $@"
 log_s
}
log_tt()
{
 Info "- - - $@"
 log_s
}

RED=$(tput setaf 1)
green=$(tput setaf 2)
white=$(tput setaf 7)
reset=$(tput sgr0)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
LOGIN=$(whoami)
VER=$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')
VIRT=$(hostnamectl | grep -e "Virtualization" | awk '{print $2}')
RAM=$(free -m | awk '/Mem:/ { print $2 }')
IP_SERV=`ip -o -4 address show scope global | tr '/' ' ' | awk '$3~/^inet/ && $2~/^(eth|veth|venet|ens|eno|enp)[0-9]+$|^enp[0-9]+s[0-9a-z]+$/ {print $4}'|head -1`

MIRROR="https://raw.githubusercontent.com/hackhostdev/zerohost/main"
PMA_VERSION="5.2.0"
PANEL_NAME="parasha_zero.zip"

install_panel()
{
	clear
	read -p "${MAGENTA}Пожалуйста, введите домен или IP:${reset}" DOMAIN
	read -p "${MAGENTA}Пожалуйста, введите ключ сайта reCaptcha v2:${reset}" R_KEY_V2
	read -p "${MAGENTA}Пожалуйста, введите секретный ключ reCaptcha v2:${reset}" R_SKEY_V2
	read -p "${MAGENTA}Пожалуйста, введите ваш размер члена:${reset}" RAZMER
	log_n "${MAGENTA}Добавление репозитория"
	echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list
	echo "deb http://deb.debian.org/debian-security/ bullseye-security main" >> /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian-security/ bullseye-security main" >> /etc/apt/sources.list
	echo "deb http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list
	log_n "${MAGENTA}Первоначальная настройка"
	export DEBIAN_FRONTEND=noninteractive
	echo 'net.ipv6.conf.all.disable_ipv6 = 1' > /etc/sysctl.d/90-disable-ipv6.conf
	echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.d/90-disable-ipv6.conf
	echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.d/90-disable-ipv6.conf
	sysctl -p -f /etc/sysctl.d/90-disable-ipv6.conf
	echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
	log_n "${MAGENTA}Обновление пакетов и апгрейд системы"
	apt-get -qq update
	apt-get -y upgrade
	log_n "${MAGENTA}Установка пакетов"
	apt-get install -y wget pwgen apache2 php7.4 php7.4-mysql php7.4-ssh2 php7.4-curl php7.4-mbstring php7.4-xml php7.4-json php7.4-zip php7.4-gd mariadb-server unzip htop apt-transport-https ca-certificates iptables-persistent
	systemctl enable netfilter-persistent.service
	ADMIN_PASS=$(pwgen -cns -1 28)
	PMA_PASS=$(pwgen -cns -1 24)
	blowfish_secret=$(pwgen -cns -1 32)
	mysql -e "GRANT ALL ON *.* TO 'admin'@'localhost' IDENTIFIED BY '$ADMIN_PASS' WITH GRANT OPTION"
	mysql -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost' IDENTIFIED BY '$PMA_PASS'"
	mysql -e "FLUSH PRIVILEGES"
	log_n "${MAGENTA}Установка PhpMyAdmin"
	wget --no-check-certificate https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz	
	tar xvf phpMyAdmin-$PMA_VERSION-all-languages.tar.gz
	rm phpMyAdmin-$PMA_VERSION-all-languages.tar.gz
	mv phpMyAdmin-$PMA_VERSION-all-languages/ /usr/share/phpmyadmin
	wget --no-check-certificate $MIRROR/config_pma.txt -O /usr/share/phpmyadmin/config.inc.php 
	sed -i "s/blowfish_secret_input/${blowfish_secret}/g" /usr/share/phpmyadmin/config.inc.php
	sed -i "s/pmapass/${PMA_PASS}/g" /usr/share/phpmyadmin/config.inc.php
	mysql < /usr/share/phpmyadmin/sql/create_tables.sql 
	mkdir -p /var/lib/phpmyadmin/tmp
	chown -R www-data:www-data /usr/share/phpmyadmin /var/lib/phpmyadmin
	chmod -R 770 /usr/share/phpmyadmin /var/lib/phpmyadmin
	chmod -R 640 /usr/share/phpmyadmin/config.inc.php
	rm -rf /usr/share/phpmyadmin/setup /usr/share/phpmyadmin/examples /usr/share/phpmyadmin/config.sample.inc.php
	log_n "${MAGENTA}Настройка Apache2, PHP и MariaDB"
	wget --no-check-certificate $MIRROR/config_apache.txt -O /etc/apache2/sites-available/hostinpl.conf
	PMA_URL=$(pwgen -cns -1 16)
	PMA_URL_LOGIN=$(pwgen -cns -1 6)
	PMA_URL_PASS=$(pwgen -cns -1 16)
	sed -i "s/domain.ru/${DOMAIN}/g" /etc/apache2/sites-available/hostinpl.conf
	sed -i "s/pma_edit/${PMA_URL}/g" /etc/apache2/sites-available/hostinpl.conf
	htpasswd -b -c /var/lib/phpmyadmin/.htpasswd $PMA_URL_LOGIN $PMA_URL_PASS
	a2ensite hostinpl
	a2dissite 000-default
	a2enmod rewrite
	wget --no-check-certificate $MIRROR/php.ini -O /etc/php/7.4/apache2/php.ini
	wget --no-check-certificate $MIRROR/php.ini -O /etc/php/7.4/cli/php.ini
	ln -snf /usr/share/zoneinfo/Europe/Moscow /etc/localtime && echo Europe/Moscow > /etc/timezone
	sed -i 's/#max_connections        = 100/max_connections        = 1000/g' /etc/mysql/mariadb.conf.d/50-server.cnf
	service apache2 url
	service mysql restart
	log_n "${MAGENTA}Настройка Cronrab"
	(crontab -l ; echo "0 0 * * * bash -c 'php /var/www/cron.php index'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/1 * * * * bash -c 'php /var/www/cron.php gameServers'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/1 * * * * bash -c 'php /var/www/cron.php tasks'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/10 * * * * bash -c 'php /var/www/cron.php serverReloader'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/30 * * * * bash -c 'php /var/www/cron.php stopServers'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/30 * * * * bash -c 'php /var/www/cron.php stopServersQuery'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/60 * * * * bash -c 'php /var/www/cron.php updateStats'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "*/60 * * * * bash -c 'php /var/www/cron.php updateStatsLocations'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	(crontab -l ; echo "0 * */7 * * bash -c 'php /var/www/cron.php clearLogs'") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	service cron restart
	log_n "${MAGENTA}Установка панели"
	wget --no-check-certificate $MIRROR/$PANEL_NAME
	unzip $PANEL_NAME -d /var/www/
	rm $PANEL_NAME


	sed -i "s/pmaurl/${PMA_URL}/g" /var/www/application/config.php
	sed -i "s/pma_loginurl/${PMA_URL_LOGIN}/g" /var/www/application/config.php
	sed -i "s/pma_passwdurl/${PMA_URL_PASS}/g" /var/www/application/config.php

	sed -i "s/RAZMERclena/${RAZMER}/g" /var/www/application/config.php

	sed -i "s/parol/${ADMIN_PASS}/g" /var/www/application/config.php
	sed -i "s/domen.ru/${DOMAIN}/g" /var/www/application/config.php
	sed -i "s/edit_r_key_v2/${R_KEY_V2}/g" /var/www/application/config.php
	sed -i "s/edit_r_skey_v2/${R_SKEY_V2}/g" /var/www/application/config.php
	chown -R www-data:www-data /var/www
	chmod -R 770 /var/www
	log_n "${MAGENTA}Создание и импорт базы данных"
	mkdir /var/lib/mysql/hostin
	chown -R mysql:mysql /var/lib/mysql/hostin
	mysql hostin < /var/www/hostinpl5_6.sql
	rm /var/www/hostinpl5_6.sql
	rm -rf /var/www/html
	service netfilter-persistent save
	log_n "==================== Установка ZEROHSP - АВТОР ПАНЕЛИ ГОВНОЕД успешно завершена ===================="
	Error_n "${green} - Адрес панели: ${white}http://$DOMAIN"
	Error_n "${green} -- Адрес phpmyadmin: ${white}http://$DOMAIN/$PMA_URL"
	Error_n "${green} --- Данные для входа в phpmyadmin:"
	Error_n "${green} --- Пользователь: ${white}$PMA_URL_LOGIN"
	Error_n "${green} --- Пароль: ${white}$PMA_URL_PASS"
	Error_n "${green} ---- Данные для входа в базу панели:"
	Error_n "${green} ---- Пользователь: ${white}admin"
	Error_n "${green} ---- Пароль: ${white}$ADMIN_PASS"
	Error_n "${green}Мониторинг нагрузки сервера: ${white}htop"
	log_n "=============================== GOVNOED ==============================="
	Info
	log_tt "${white}Добро пожаловать в установочное меню ${MAGENTA}ZEROHSP - АВТОР ПАНЕЛИ ГОВНОЕД "
	Info "- ${white}1 ${green}- ${white}Подключить файл подкачки"
	Info "- ${white}0 ${green}- ${white}Выйти из установщика"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню: " case
	case $case in
		1) install_swap;;
		0) exit;;
	esac
}
		
install_location()
{
	clear
	log_n "${MAGENTA}Добавление репозитория"
	echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list
	echo "deb http://deb.debian.org/debian-security/ bullseye-security main" >> /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian-security/ bullseye-security main" >> /etc/apt/sources.list
	echo "deb http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list
	echo "deb-src http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list
	log_n "${MAGENTA}Первоначальная настройка"
	export DEBIAN_FRONTEND=noninteractive
	echo 'net.ipv6.conf.all.disable_ipv6 = 1' > /etc/sysctl.d/90-disable-ipv6.conf
	echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.d/90-disable-ipv6.conf
	echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.d/90-disable-ipv6.conf
	sysctl -p -f /etc/sysctl.d/90-disable-ipv6.conf
	echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
	groupadd gameservers
	Line_Number=$(grep -n "127.0.0.1" /etc/hosts | cut -d: -f 1)
	My_Hostname=$(hostname)
	if [[ -n $Line_Number ]]; then
		for Line_Number2 in $Line_Number ; do
			String=$(sed "${Line_Number2}q;d" /etc/hosts)
			if [[ $String != *"$My_Hostname"* ]]; then
				New_String="$String $My_Hostname"
				sed -i "${Line_Number2}s/.*/${New_String}/" /etc/hosts
			fi
		done
	else
		echo "127.0.0.1 $My_Hostname " >> /etc/hosts
	fi
	log_n "${MAGENTA}Обновление пакетов и апгрейд системы"
	apt-get -qq update
	apt-get -y upgrade
	log_n "${MAGENTA}Установка пакетов"
	apt-get install -y wget pwgen apt-transport-https ca-certificates gnupg-agent
	wget https://download.docker.com/linux/debian/gpg -O - | apt-key add -
	echo "deb [arch=amd64] https://download.docker.com/linux/debian bullseye stable" >> /etc/apt/sources.list
	apt-get -qq update
	apt-get install docker-ce docker-ce-cli -y
	apt-get install -y nginx php7.4-fpm php7.4-mysql php7.4-ssh2 php7.4-curl php7.4-mbstring php7.4-xml php7.4-json php7.4-zip php7.4-gd mariadb-server unzip htop iptables-persistent pure-ftpd
	systemctl enable netfilter-persistent.service
	ADMIN_PASS=$(pwgen -cns -1 28)
	PMA_PASS=$(pwgen -cns -1 24)
	blowfish_secret=$(pwgen -cns -1 32)
	mysql -e "GRANT ALL ON *.* TO 'admin'@'localhost' IDENTIFIED BY '$ADMIN_PASS' WITH GRANT OPTION"
	mysql -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost' IDENTIFIED BY '$PMA_PASS'"
	mysql -e "FLUSH PRIVILEGES"
	log_n "${MAGENTA}Установка PhpMyAdmin"
	wget --no-check-certificate https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz	
	tar xvf phpMyAdmin-$PMA_VERSION-all-languages.tar.gz
	rm phpMyAdmin-$PMA_VERSION-all-languages.tar.gz
	mv phpMyAdmin-$PMA_VERSION-all-languages/ /usr/share/phpmyadmin
	wget --no-check-certificate $MIRROR/config_pma.txt -O /usr/share/phpmyadmin/config.inc.php 
	sed -i "s/blowfish_secret_input/${blowfish_secret}/g" /usr/share/phpmyadmin/config.inc.php
	sed -i "s/pmapass/${PMA_PASS}/g" /usr/share/phpmyadmin/config.inc.php
	mysql < /usr/share/phpmyadmin/sql/create_tables.sql 
	mkdir -p /var/lib/phpmyadmin/tmp
	chown -R www-data:www-data /usr/share/phpmyadmin /var/lib/phpmyadmin
	chmod -R 770 /usr/share/phpmyadmin /var/lib/phpmyadmin
	chmod -R 640 /usr/share/phpmyadmin/config.inc.php
	rm -rf /usr/share/phpmyadmin/setup /usr/share/phpmyadmin/examples /usr/share/phpmyadmin/config.sample.inc.php
	log_n "${MAGENTA}Настройка Nginx, PHP и MariaDB"
	service nginx stop
	wget --no-check-certificate $MIRROR/php.ini -O /etc/php/7.4/fpm/php.ini
	wget --no-check-certificate $MIRROR/php.ini -O /etc/php/7.4/cli/php.ini
	wget --no-check-certificate $MIRROR/config_nginx.txt -O /etc/nginx/nginx.conf
	ln -snf /usr/share/zoneinfo/Europe/Moscow /etc/localtime && echo Europe/Moscow > /etc/timezone
	sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf 
	sed -i 's/#max_connections        = 100/max_connections        = 1000/g' /etc/mysql/mariadb.conf.d/50-server.cnf
	echo 'sql-mode=""' >> /etc/mysql/mariadb.conf.d/50-server.cnf
	mkdir /var/nginx
	echo 'FastDL it`s working :)' > /var/nginx/index.html	
	service nginx start
	service php7.4-fpm restart
	service mysql restart
	log_n "${MAGENTA}Создание нужных папок для работы серверов"
	mkdir /home/cp /home/cp/backups /home/cp/gameservers /home/cp/gameservers/files
	chown -R root /home/ 
	chmod -R 755 /home/ 
	chmod -R 700 /home/cp/backups
	log_n "${MAGENTA}Настройка SSH и FTP"
	sh -c "echo '' >> /etc/ssh/sshd_config"
	sh -c "echo 'DenyGroups gameservers' >> /etc/ssh/sshd_config"
	service ssh restart 
	service sshd restart 
	echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
	echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
	echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
	echo "yes" > /etc/pure-ftpd/conf/VerboseLog
	echo "yes" > /etc/pure-ftpd/conf/IPV4Only
	echo "100" > /etc/pure-ftpd/conf/MaxClientsNumber
	echo "8" > /etc/pure-ftpd/conf/MaxClientsPerIP
	echo "no" > /etc/pure-ftpd/conf/DisplayDotFiles 
	echo "15" > /etc/pure-ftpd/conf/MaxIdleTime
	echo "16" > /etc/pure-ftpd/conf/MaxLoad
	echo "50000 50300" > /etc/pure-ftpd/conf/PassivePortRange
	service pure-ftpd restart 
	log_n "${MAGENTA}Сборка образа Docker для работы игровых серверов"
	wget --no-check-certificate $MIRROR/Dockerfile
	docker build -t hostinpl:games .
	rm Dockerfile 
	log_n "${MAGENTA}Загрузка SteamCMD"
	apt-get install -y lib32stdc++6 
	cd /root 
	mkdir steamcmd 
	cd steamcmd 
	wget http://media.steampowered.com/client/steamcmd_linux.tar.gz 
	tar xvfz steamcmd_linux.tar.gz 
	rm steamcmd_linux.tar.gz 
	log_n "================ Настройка игровой локации прошла успешно ================"
	Error_n "${green}Подключите локацию в панели управления"
	Error_n "${green}Базы данных серверов этой локации будут хранится на ней."
	Error_n "${green}Адрес phpmyadmin: ${white}http://$IP_SERV:8080/phpmyadmin"
	Error_n "${green}Данные для входа в phpmyadmin:"
	Error_n "${green}Пользователь: ${white}admin"
	Error_n "${green}Пароль: ${white}$ADMIN_PASS"
	Error_n "${green}Мониторинг нагрузки сервера: ${white}htop"
	log_n "=========================== GOVNOED ==========================="
	Info
	log_tt "${white}Добро пожаловать в установочное меню ${MAGENTA}ZEROHSP - АВТОР ПАНЕЛИ ГОВНОЕД "
	Info "- ${white}1 ${green}- ${white}Подключить файл подкачки"
	Info "- ${white}2 ${green}- ${white}Загрузить игры на локацию"
	Info "- ${white}0 ${green}- ${white}Выйти из установщика"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню: " case
	case $case in
		1) install_swap;;
		2) dop_games;;
		0) exit;;
	esac
}

install_swap()
{
	clear
	read -p "${white}Введите размер файла подкачки (в GB. Например: 1):${reset}" GB
	fallocate -l ${GB}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile 
    swapon /swapfile
    echo "/swapfile    none    swap    sw    0    0" >> /etc/fstab
	log_n "================ Файл подкачки размером в ${GB}GB успешно подключен! ==============="
}

dop_games()
{
	clear
	log_s
	log_tt "${white}Добро пожаловать в меню загрузки игр для ${MAGENTA}ZEROHSP - АВТОР ПАНЕЛИ ГОВНОЕД "
	Info "- ${white}1 ${green}- ${white}San Andreas: Multiplayer 0.3.7"
	Info "- ${white}2 ${green}- ${white}Criminal Russia: Multiplayer 0.3e"
	Info "- ${white}3 ${green}- ${white}Criminal Russia: Multiplayer 0.3.7"
	Info "- ${white}4 ${green}- ${white}United Multiplayer"
	Info "- ${white}5 ${green}- ${white}Multi Theft Auto: Multiplayer 1.5.9"
	Info "- ${white}6 ${green}- ${white}MineCraft: PE"
	Info "- ${white}7 ${green}- ${white}Counter Strike: 1.6"
	Info "- ${white}8 ${green}- ${white}Counter Strike: Source"
	Info "- ${white}9 ${green}- ${white}GTA V: RAGE MP (0.3.6, 0.3.7, 1.1)"
	Info "- ${white}10 ${green}- ${white}MineCraft Java"
	Info "- ${white}0 ${green}- ${white}Выход в главное меню"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню: " case
	case $case in
		1) 
			clear
			mkdir /home/cp/gameservers/files/samp > /dev/null 2>&1
			cd /home/cp/gameservers/files/samp > /dev/null 2>&1
			log_n "${BLUE}Load game San Andreas: Multiplayer 0.3.7"
			wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/samp.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			log_n "${BLUE}Unpacking game San Andreas: Multiplayer 0.3.7"
			unzip samp.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			rm samp.zip > /dev/null 2>&1
			log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
			Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
			Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
			log_s
			Info
			read -p "Пожалуйста, введите пункт меню: " case
			case $case in
				1) dop_games;;     
				0) menu;;
			esac 
		  ;;       
		2) 
			clear
			mkdir /home/cp/gameservers/files/crmp > /dev/null 2>&1
			cd /home/cp/gameservers/files/crmp > /dev/null 2>&1
			log_n "${BLUE}Load game Criminal Russia: Multiplayer 0.3e"
			wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/crmp.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			log_n "${BLUE}Unpacking game Criminal Russia: Multiplayer 0.3e"
			unzip crmp.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			rm crmp.zip > /dev/null 2>&1
			log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
			Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
			Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
			log_s
			Info
			read -p "Пожалуйста, введите пункт меню: " case
			case $case in
				1) dop_games;;     
				0) menu;;
			esac 
		  ;;
		3) 
				clear
		mkdir /home/cp/gameservers/files/crmp037 > /dev/null 2>&1
		cd /home/cp/gameservers/files/crmp037 > /dev/null 2>&1
		log_n "${BLUE}Load game Criminal Russia: Multiplayer 0.3.7"
		wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/crmp037.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		log_n "${BLUE}Unpacking game Criminal Russia: Multiplayer 0.3.7"
		unzip crmp037.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		rm crmp037.zip > /dev/null 2>&1
		log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
		Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
		Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
		log_s
		Info
		read -p "Пожалуйста, введите пункт меню: " case
		case $case in
			1) dop_games;;     
			0) menu;;
		esac  
	  ;;
		4) 
		clear
		mkdir /home/cp/gameservers/files/unit > /dev/null 2>&1
		cd /home/cp/gameservers/files/unit > /dev/null 2>&1
		log_n "${BLUE}Load game United Multiplayer"
		wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/unit.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		log_n "${BLUE}Unpacking game United Multiplayer"
		unzip unit.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		rm unit.zip > /dev/null 2>&1
		log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
		Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
		Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
		log_s
		Info
		read -p "Пожалуйста, введите пункт меню: " case
		case $case in
			1) dop_games;;     
			0) menu;;
		esac 
	  ;;
		5) 
		clear
			mkdir /home/cp/gameservers/files/mta > /dev/null 2>&1
			cd /home/cp/gameservers/files/mta > /dev/null 2>&1
			log_n "${BLUE}Load game Multi Theft Auto: Multiplayer"
			wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/mta.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			log_n "${BLUE}Unpacking game Multi Theft Auto: Multiplayer"
			unzip mta.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			rm mta.zip > /dev/null 2>&1
			log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
			Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
			Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
			log_s
			Info
			read -p "Пожалуйста, введите пункт меню: " case
			case $case in
				1) dop_games;;     
				0) menu;;
			esac 
		  ;;
		6) 
			clear
			mkdir /home/cp/gameservers/files/mcpe > /dev/null 2>&1
			cd /home/cp/gameservers/files/mcpe > /dev/null 2>&1
			log_n "${BLUE}Load game MineCraft: PE"
			wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/mcpe.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then 
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			log_n "${BLUE}Unpacking game MineCraft: PE"
			unzip mcpe.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			rm mcpe.zip > /dev/null 2>&1
			log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
			Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
			Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
			log_s
			Info
			read -p "Пожалуйста, введите пункт меню: " case
			case $case in
				1) dop_games;;     
				0) menu;;
			esac 
		  ;;
		7) 
			clear
			mkdir /home/cp/gameservers/files/cs > /dev/null 2>&1
			cd /home/cp/gameservers/files/cs > /dev/null 2>&1
			log_n "${BLUE}Load game Counter Strike 1.6"
			wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/cs.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			log_n "${BLUE}Unpacking game Counter Strike 1.6"
			unzip cs.zip > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "${green}[SUCCESS]"
				tput sgr0
			else
				echo "${red}[ERROR]"
				tput sgr0
				exit
			fi
			rm cs.zip > /dev/null 2>&1
			log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
			Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
			Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
			log_s
			Info
			read -p "Пожалуйста, введите пункт меню: " case
			case $case in
				1) dop_games;;     
				0) menu;;
			esac 
		  ;;
			8) 
		clear
		mkdir /home/cp/gameservers/files/css > /dev/null 2>&1
		cd /home/cp/gameservers/files/css > /dev/null 2>&1
		log_n "${BLUE}Load game Counter Strike Source"
		wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/css.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		log_n "${BLUE}Unpacking game Counter Strike Source"
		unzip css.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		rm css.zip > /dev/null 2>&1
		log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
		Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
		Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
		log_s
		Info
		read -p "Пожалуйста, введите пункт меню: " case
		case $case in
			1) dop_games;;     
			0) menu;;
		esac 
	  ;;
		9) 
		clear
		mkdir /home/cp/gameservers/files/ragemp > /dev/null 2>&1
		cd /home/cp/gameservers/files/ragemp > /dev/null 2>&1
		log_n "${BLUE}Load game Counter Strike Source"
		wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/ragemp.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		log_n "${BLUE}Unpacking game GTA 5 RAGE:MP"
		unzip ragemp.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		rm ragemp.zip > /dev/null 2>&1
		log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
		Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
		Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
		log_s
		Info
		read -p "Пожалуйста, введите пункт меню: " case
		case $case in
			1) dop_games;;     
			0) menu;;
		esac 
	  ;;
		10) 
		clear
		mkdir /home/cp/gameservers/files/mine72 > /dev/null 2>&1
		cd /home/cp/gameservers/files/mine72 > /dev/null 2>&1
		log_n "${BLUE}Load game MineCraft"
		wget https://vipadmin.club/KJ2398D/hostinpl5_6/games/mine72.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		log_n "${BLUE}Unpacking game MineCraft"
		unzip mine72.zip > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${green}[SUCCESS]"
			tput sgr0
		else
			echo "${red}[ERROR]"
			tput sgr0
			exit
		fi
		rm mine72.zip > /dev/null 2>&1
		log_n "Игра успешно загружена на ваш сервер, включите ее для заказа в панели управления."
		Info "- ${white}1 ${green}- ${white}Вернуться в меню выбора игр"
		Info "- ${white}0 ${green}- ${white}Вернуться в главное меню"
		log_s
		Info
		read -p "Пожалуйста, введите пункт меню: " case
		case $case in
			1) dop_games;;     
			0) menu;;
		esac  
	  ;;
	    0) menu;;
 esac
}

menu()
{
	if [ ! $LOGIN = "root" ]; then
		log_n "${RED}Запустите установщик от имени root!"
		exit 1
	fi

	if [ $VIRT = "lxc" ] || [ $VIRT = "openvz" ]; then
		log_n "${RED}Виртуализация ${VIRT} не поддерживается!"
		exit 1
	fi

	if [ ! $VER = "11" ]; then
		log_n "${RED}У Вас не Debian 11!"
		exit 1
	fi

	if [ $RAM -lt "512" ]; then
		log_n "${RED}У Вас недостаточно RAM! Минимум 512 мб."
		exit 1
	fi
	clear
	log_s
	log_tt "${white}Добро пожаловать в установочное меню ${MAGENTA}ZEROHSP - АВТОР ПАНЕЛИ ГОВНОЕД  (Debian 11)"
	Info "- ${white}1 ${green}- ${white}Настроить веб-часть"
	Info "- ${white}2 ${green}- ${white}Настроить игровую локацию"
	Info "- ${white}3 ${green}- ${white}Загрузить игры на настроенную игровую локацию"
	Info "- ${white}4 ${green}- ${white}Подключить файл подкачки"
	Info "- ${white}0 ${green}- ${white}Выход из установщика"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню: " case
	case $case in
		1) install_panel;;     
		2) install_location;;
		3) dop_games;;
		4) install_swap;;
		0) exit;;
	esac
}
menu