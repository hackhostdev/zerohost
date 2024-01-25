FROM debian:bullseye
RUN apt-get -qq update && apt-get -y upgrade
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386
RUN apt-get install -y wget libbabeltrace1 libc6-dbg libdw1 lib32stdc++6 libreadline8 libncursesw5 gdb-minimal gcc-multilib sudo screen
RUN wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt-get update && apt-get install -y dotnet-sdk-5.0
RUN ln -snf /usr/share/zoneinfo/Europe/Moscow /etc/localtime && echo Europe/Moscow > /etc/timezone