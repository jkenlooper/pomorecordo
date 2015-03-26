#!/bin/bash

# PomoRecordo.sh
# Record screen and audio for 25 min and then detach from tmux

# Take a screenshot of the default framebuffer a bunch of times a second for
# creating videos.  At the end the individual frames are converted to tiff and
# then into a movie, wee.
#
# Note. Writing bash scripts that are short like this works, I guess.  Not too
# much experience doing this, but it seems to work. Just learning as I go.

# Load the TASK variable with the todo text getting just the first line.
TASK=`sed -n ''"$1"' L' $HOME/.todo/todo.txt`;
echo "Starting timer for task: ${TASK}"
echo "Starting in:";
COUNTDOWNTOSCGREENGRAB=10;
while test $COUNTDOWNTOSCGREENGRAB -gt -1; do
    read -n 1 -p "$COUNTDOWNTOSCGREENGRAB.." -t 1 CANCELSCREENGRAB && break;
    COUNTDOWNTOSCGREENGRAB=$(($COUNTDOWNTOSCGREENGRAB-1));
done;

(
if test $CANCELSCREENGRAB; then
echo 'canceled screen grab';
else
START=`date +%s`;
SGDIR=sg-${START};
mkdir ${SGDIR};
cd ${SGDIR};


# Within the timer.sh script the TIMER gets decremented every minute.
TIMER=1;
timer.sh $1 $TIMER &
TIMER_PID=$!
END=`date -d "${TIMER} minutes" +%s`

# Start audio recording and put it in the background
arecord -d $(($TIMER * 60)) -f dat test.wav &
AUDIO_PID=$!

FRAME_TIMESTAMP=$(date +%s.%N);

# or more direct...
ffmpeg -f fbdev -r 12 -i /dev/fb0 -b:v 10000000 -vcodec mpeg4 out.mov;

while test $END -ge `date +%s`; do
  SG=$(($SG+1));

  FRAME_TIMESTAMP_NOW=$(date +%s.%N);
  DELAY=$(echo "scale=3; (($FRAME_TIMESTAMP_NOW - $FRAME_TIMESTAMP)/1) - 0.083;" | bc);
  FRAME_TIMESTAMP=$FRAME_TIMESTAMP_NOW

  fbgrab -d /dev/fb0 frame-${SG}.png 2> /dev/null &


  # create a canvas here and composite in all available slot images?
  #convert -size 1920x1080 canvas:black -gravity East -size 480x600 canvas:red  -compose Over -composite test.png;
  #convert -size 1920x1080 canvas:black \
  #    -gravity West frame-${SG}.png -scale x1080 -compose Over -composite \
  #    -gravity NorthEast -size 480x360 canvas:red  -compose Over -composite \
  #    -gravity East -size 480x360 canvas:green  -compose Over -composite \
  #    -gravity SouthEast -size 480x360 canvas:blue  -compose Over -composite \
  #    frame-${SG}.png;

  # 1920 - ((1080 / 768) * 1024) = 480
  # Allow for pressing a key to stop taking frames.

  # This is simply done to have something to trigger a stop.
  timeout=$(echo "0.083 - $DELAY" | bc);
  read -n 1 -t $timeout CANCELFBGRAB && break;
done;
if test $CANCELFBGRAB; then
    echo screen grab canceled.
    kill $TIMER_PID;
    kill $AUDIO_PID;
    #TODO: cleanup any frame-*.png created?
else
STOP=`date +%s`;
echo "Converting ${SG} frames...";

# TODO: count the frames created and from the duration of the time figure out what the fps is.
FPS=$((${SG}/(${STOP} - ${START})));
echo "START = ${START}";
echo "STOP = ${STOP}";
echo "SG = ${SG}";
echo "fps = ${FPS}";

# Yo, times up.
#tmux detach-client;

# But, continue

#convert frames.miff -coalesce -layers OptimizePlus frames.gif;
  #convert frame-${SG}.png frame-${SG}.gif;
  #rm frame-${SG}.png;

  #convert frames.miff -delay $DELAY frame-${SG}.gif frames.miff;
##mogrify -format tiff frame-*.png;
frame_index=0
#echo "convert frames.miff \\" > create_gif.sh;
#frame-${frame_index}.gif frames.miff;
while test $frame_index -lt $SG; do
    frame_index=$((${frame_index} + 1))
    frame=frame-${frame_index}.png
    #delay=`sed -n ''"${SG}"' L' delay.txt`;
    #convert frame-${frame_index}.png frame-${frame_index}.gif;
    #echo "-delay ${delay} frame-${frame_index}.gif \\" >> create_gif.sh;
    #convert frames.miff -delay $delay frame-${frame_index}.gif frames.miff;
    #rm frame-${frame_index}.png;

    #TODO: add in other screenshots for the other slots.
    #TODO: use an auto trim and scale from imagemagick.  This is so a 'title' can simply be typed out.
    #convert -size 1280x720 canvas:black -gravity West $frame -scale x720 -compose Over -composite $frame;
    #convert -size 1920x1080 canvas:black -gravity West $frame -scale x1080 -compose Over -composite $frame;
    #echo "building ${frame} of ${SG}";
    #mogrify -trim -scale 1440x1080 +repage ${frame};
    #convert -size 1920x1080 canvas:black \
    #    -gravity West $frame  -compose Over -composite \
    #    -gravity NorthEast -size 480x360 canvas:red  -compose Over -composite \
    #    -gravity East -size 480x360 canvas:green  -compose Over -composite \
    #    -gravity SouthEast -size 480x360 canvas:blue  -compose Over -composite \
    #    -compress LZW ${frame/.png/.tiff};
done;
#echo "frames.miff" >> create_gif.sh;
#bash create_gif.sh;
#rm frame-*.gif;
#convert frames.miff -coalesce -layers OptimizePlus frames.gif;

#mogrify -format tiff frame-*.png;

# The bitrate has been set to 10000kbps and also the scale is now 16:9 with a framerate of the computed fps

#ffmpeg -i frame-%d.tiff -b:v 10000000 -vcodec mpeg4 -r 1 out.mov;
#ffmpeg -i frame-%d.tiff -b:v 10000000 -vcodec mpeg4 -r ${FPS} out.mov;
ffmpeg -framerate ${FPS} -i frame-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r 12 out.mov;

fi
fi
)
