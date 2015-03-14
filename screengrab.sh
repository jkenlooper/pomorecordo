#!/bin/bash

# Take a screenshot of the default framebuffer every 12th of a second for
# creating videos.  At the end the individual frames are converted to tiff and
# then into a movie, wee.
#
# Note. Writing bash scripts that are short like this works, I guess.  Not too
# much experience doing this, but it seems to work.

echo "Starting screen grab in:";
COUNTDOWNTOSCGREENGRAB=10;
while test $COUNTDOWNTOSCGREENGRAB -gt -1; do
    read -n 1 -p "$COUNTDOWNTOSCGREENGRAB.." -t 1 CANCELSCREENGRAB && break;
    COUNTDOWNTOSCGREENGRAB=$(($COUNTDOWNTOSCGREENGRAB-1));
done;

(
if test $CANCELSCREENGRAB; then
echo 'canceled screen grab';
else
SGDIR=sg-`date +%s`;
mkdir ${SGDIR};
cd ${SGDIR};
while true; do
  SG=$(($SG+1));

  fbgrab -d /dev/fb0 frame-${SG}.png;

  # Allow for pressing a key to stop taking frames.
  read -n 1 -t 0.05 && break;
done;
echo "Converting ${SG} frames...";

# TODO: remove duplicate adjacent frames or not?

#mogrify -scale 640x480 -format tiff frame-*.png;
for frame in frame-*.png; do
    #convert -size 1280x720 canvas:black -gravity West $frame -scale x720 -compose Over -composite $frame;
    convert -size 1920x1080 canvas:black -gravity West $frame -scale x1080 -compose Over -composite $frame;
done;

mogrify -format tiff frame-*.png;

# The bitrate has been set to 5000kbps and also the scale is now 16:9

ffmpeg -i frame-%d.tiff -b:v 10000000 -vcodec mpeg4 -r 12 out.mov;

fi
)
