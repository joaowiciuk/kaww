# Base image
FROM ubuntu:latest

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget

# Install 32-bit libraries
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y libc6:i386 libstdc++6:i386 libglapi-mesa:i386 libgl1-mesa-glx:i386 libxxf86vm1:i386 libxext6:i386 libx11-6:i386 libfreetype6:i386 libxdamage1:i386 libxfixes3:i386 libx11-xcb1:i386 libxcb-glx0:i386 libxcb-dri2-0:i386 libxcb1:i386  libdrm2:i386 libxdmcp6:i386

# Download and configure dedicated server executable
RUN wget http://dl.kag2d.com/kag-linux32-dedicated-release.tar.gz
RUN tar -zxf kag-linux32-dedicated-release.tar.gz
RUN chmod +x KAGdedi
RUN rm kag-linux32-dedicated-release.tar.gz

# Configure server
COPY autoconfig.cfg autoconfig.cfg

# Configure mod
RUN echo "kaww" > mods.cfg

# Copy mod file to server folder
ADD BlavsArmoredWarfare Mods/kaww
ADD BlavsArmoredWarfare_Music Mods/kaww
ADD tickets Mods/kaww

# Expose ports for server and RCON
EXPOSE 50301/tcp 50301/udp 50328/udp

# Start server with mod
CMD ["./KAGdedi"]
