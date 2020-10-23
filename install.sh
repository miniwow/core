#!/bin/sh


# install requirements
sudo apt update
sudo apt install -y \
  git clang cmake make gcc g++ libmariadbclient-dev libssl-dev libbz2-dev \
  libreadline-dev libncurses-dev libboost-all-dev mariadb-server p7zip \
  libmariadb-client-lgpl-dev-compat transmission-cli wget screen killall
sudo update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100
sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang 100
curl -fsSL https://deno.land/x/install/install.sh | sh
git submodule update --init --recursive


# configure and build
mkdir -p build
cd build
cmake \
	-DSCRIPTS="minimal-static" \
	-DTOOLS=1 \
	-DWITH_WARNINGS=1 \
	-DCONF_DIR="$(realpath "$(pwd)/../../conf")" \
	-DCMAKE_INSTALL_PREFIX="$(realpath "$(pwd)/../../")" \
	..
#	-DCMAKE_BUILD_TYPE="Debug" \
make -j $(nproc)
make install
cd ../../

# copy initial configs
cp conf/authserver.conf.dist conf/authserver.conf
cp conf/worldserver.conf.dist conf/worldserver.conf

# apply config patch
patch conf/worldserver.conf core/worldserver.conf.patch


# download client
tmpfile=$(mktemp)
chmod a+x $tmpfile
echo "killall transmission-cli" > $tmpfile
transmission-cli \
  -f $tmpfile \
  -w "$(pwd)" \
  'magnet:?xt=urn:btih:b296ea8947b36c68f6e022f5a642ecc406ad8968&dn=World+of+Warcraft+3.3.5'
rm $tmpfile


# extract data
cd 'World of Warcraft 3.3.5a (no install)'
mkdir -p vmaps
mkdir -p mmaps
../bin/mapextractor
../bin/vmap4extractor
../bin/vmap4assembler Buildings vmaps
../bin/mmaps_generator
rm -rf Buildings Cameras
mv mmaps vmaps dbc maps ../../bin
cd ..


# init DB
cd core/sql
cat create/create_mysql.sql | sudo mysql
wget https://github.com/TrinityCore/TrinityCore/releases/download/TDB335.20101/TDB_full_world_335.20101_2020_10_15.7z
p7zip -d TDB_full_world_335.20101_2020_10_15.7z
cat TDB_full_world_335.20101_2020_10_15.sql | sudo mysql world
rm TDB_full_world_335.20101_2020_10_15.sql
cd ../..


# add services
echo '\nRegister worldserver.service'
echo '
[Unit]
Description=World Server (TrinityCore)

[Service]
Type=forking
WorkingDirectory='$(pwd)'/bin
User='$USER'
ExecStart=/usr/bin/screen -dmS worldserver '$(pwd)'/bin/worldserver
ExecReload=/usr/bin/screen -S worldserver -p 0 -X stuff "server shutdown force 0\\r\\n"; /usr/bin/screen -dmS worldserver '$(pwd)'/bin/worldserver
ExecStop=/usr/bin/screen -S worldserver -p 0 -X stuff "server shutdown force 0\\r\\n"
RestartSec=10s
Restart=always

[Install]
WantedBy=multi-user.target
' | sudo dd of=/lib/systemd/system/worldserver.service
sudo chmod +rx /lib/systemd/system/worldserver.service

echo '\nRegister authserver.service'
echo '
[Unit]
Description=Authentification Server (TrinityCore)

[Service]
Type=forking
WorkingDirectory='$(pwd)'/bin
User='$USER'
ExecStart=/usr/bin/screen -dmS authserver '$(pwd)'/bin/authserver
ExecReload=/usr/bin/screen -S authserver -p 0 -X stuff "^C"; /usr/bin/screen -dmS authserver '$(pwd)'/bin/authserver
ExecStop=/usr/bin/screen -S authserver -p 0 -X stuff "^C"
RestartSec=10s
Restart=always

[Install]
WantedBy=multi-user.target
' | sudo dd of=/lib/systemd/system/authserver.service
sudo chmod +rx /lib/systemd/system/authserver.service


echo '\nRegister website.service'
echo '
[Unit]
Description=Website (TrinityCore)

[Service]
Type=forking
WorkingDirectory='$(pwd)'/bin
User='$USER'
ExecStart=/usr/bin/screen -dmS website '$HOME'/.deno/bin/deno run -A '$(pwd)'/site/api/discord.js
ExecReload=/usr/bin/screen -X -S website quit; /usr/bin/screen -dmS website '$HOME'/.deno/bin/deno run -A '$(pwd)'/site/api/discord.js
ExecStop=/usr/bin/screen -X -S website quit
RestartSec=10s
Restart=always

[Install]
WantedBy=multi-user.target
' | sudo dd of=/lib/systemd/system/website.service
sudo chmod +rx /lib/systemd/system/website.service

sudo systemctl daemon-reload

echo '
alias website="screen -r website"
alias authserver="screen -r authserver"
alias worldserver="screen -r worldserver"
alias stop="sudo systemctl stop"
alias start="sudo systemctl start"
alias reload="sudo systemctl reload"
' >> "$HOME"/.bash_aliases

echo reload your shell with
echo source $HOME/.bashrc

# echo "update auth.realmlist set address='dev.oct.ovh';" | sudo mysql
