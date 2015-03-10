# Reference: http://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu

# Get the Dependencies

sudo apt-get update;
sudo apt-get -y install wget;
sudo apt-get -y --force-yes install autoconf automake build-essential libass-dev libfreetype6-dev libgpac-dev libtheora-dev libtool libvorbis-dev pkg-config texi2html zlib1g-dev;
mkdir ~/sources/ffmpeg_sources;



# Install yasm ( or apt-get install if >= 1.3.0 )
(
cd ~/sources/ffmpeg_sources;
wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz;
tar xzvf yasm-1.3.0.tar.gz;
cd yasm-1.3.0;
./configure --prefix="$HOME/sources/ffmpeg_build" --bindir="$HOME/bin";
make;
make install;
make distclean;
)

# Install h.264 video encoder
# Requires ffmpeg to be configured with --enable-gpl --enable-libx264.
sudo apt-get -y install libx264-dev;

# Install mp3 audio encoder
sudo apt-get -y install libmp3lame-dev;

# Install libvpx ( for encoding video to .webm )
(
cd ~/sources/ffmpeg_sources;
wget http://webm.googlecode.com/files/libvpx-v1.3.0.tar.bz2;
tar xjvf libvpx-v1.3.0.tar.bz2;
cd libvpx-v1.3.0;
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/sources/ffmpeg_build" --disable-examples;
PATH="$HOME/bin:$PATH" make;
make install;
make clean;
)

# Support for png
sudo apt-get install -y zlib1g-dev;

# Install ffmpeg

(
cd ~/sources/ffmpeg_sources;
wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2;
tar xjvf ffmpeg-snapshot.tar.bz2;
cd ffmpeg;
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/sources/ffmpeg_build/lib/pkgconfig" ./configure \
    --prefix="$HOME/sources/ffmpeg_build" \
    --extra-cflags="-I$HOME/sources/ffmpeg_build/include" \
    --extra-ldflags="-L$HOME/sources/ffmpeg_build/lib" \
    --bindir="$HOME/bin" \
    --enable-gpl \
    --enable-decoder=png \
    --enable-encoder=png \
    --enable-zlib \
    --enable-libass \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-nonfree
PATH="$HOME/bin:$PATH" make;
make install;
make distclean;
hash -r
)


echo "MANPATH_MAP $HOME/bin $HOME/sources/ffmpeg_build/share/man" >> ~/.manpath;
. ~/.profile;
