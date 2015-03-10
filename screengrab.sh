#!/bin/bash

# Take a screenshot of the default framebuffer every 25th of a second for
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
  #fbgrab -c 1 frame-${SG}.png;
  fbgrab -d /dev/fb0 frame-${SG}.png;
  #sleep 0.025;
  read -n 1 -t 0.025 && break;
done;
echo "Converting ${SG} frames...";

mogrify -format tiff frame-*.png;

# TODO: improve quality here?
ffmpeg -i frame-%d.tiff -vcodec mpeg4 -r 25 out.mov
fi
)
