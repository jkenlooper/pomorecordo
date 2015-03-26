#!/bin/bash

# PomoRecordo.sh
# Record screen and audio for 25 min and then detach from tmux

# Take a screenshot of the default framebuffer a bunch of times a second for
# creating videos.  At the end the individual frames are converted to tiff and
# then into a movie, wee.
#
# Note. Writing bash scripts that are short like this works, I guess.  Not too
# much experience doing this, but it seems to work. Just learning as I go.
FPS=12

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

FRAME_TIMESTAMP=$(date +%s.%N);

frameinterval=$(echo "scale=6; 1/12;" | bc);
# Record the opening title
SG=1
fbgrab -d /dev/fb0 frame-${SG}.png 2> /dev/null &
now=$(date +%s)
while test $END -ge $now; do
  now=$(date +%s)
  SG=$(($SG+1));

  FRAME_TIMESTAMP_NOW=$(date +%s.%N);
  DELAY=$(echo "scale=3; (($FRAME_TIMESTAMP_NOW - $FRAME_TIMESTAMP)/1) - $frameinterval;" | bc);
  FRAME_TIMESTAMP=$FRAME_TIMESTAMP_NOW
  previous_frame=frame-$(($SG - 1)).png
  frame=frame-${SG}.png

  fbgrab -d /dev/fb0 frame-${SG}.png 2> /dev/null

  # Throw out this frame if it's the same as previous ( and adjust $findex )
  if test $(compare -metric AE ${previous_frame} ${frame} diff.png 2>&1) -eq 0; then
      rm ${frame};
      SG=$(($SG - 1));
  fi


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
  timeout=$(echo "$frameinterval - $DELAY" | bc);
  read -n 1 -t $timeout CANCELFBGRAB && break;
  if test $((($END - $now) % 10)) -eq 0; then
      tmux display-message -c /dev/tty1 "$(($END - $now))"
      # Sleep for a second to avoid displaying multiple messages.
      sleep 1s
  fi
done;
if test $CANCELFBGRAB; then
    echo screen grab canceled.
    kill $TIMER_PID;
    #TODO: cleanup any frame-*.png created?
else

# signal that recording has now begun.
tmux display-message -c /dev/tty1 "${TASK}"

# Start audio recording and put it in the background
arecord -d $(($TIMER * 60)) -f dat out.wav &
AUDIO_PID=$!

STOP=`date +%s`;

# start recording the main session
ffmpeg -t $((60 * $TIMER)) -f fbdev -r $FPS -i /dev/fb0 -b:v 10000000 -vcodec mpeg4 out.mov;
kill $AUDIO_PID

tmux display-message -c /dev/tty1 "Complete..."

echo "Converting ${SG} frames for opening title";

adjusted_fps=$((${SG}/(${STOP} - ${START})));
echo "START = ${START}";
echo "STOP = ${STOP}";
echo "SG = ${SG}";
echo "fps = ${adjusted_fps}";

#convert frames.miff -coalesce -layers OptimizePlus frames.gif;
  #convert frame-${SG}.png frame-${SG}.gif;
  #rm frame-${SG}.png;

  #convert frames.miff -delay $DELAY frame-${SG}.gif frames.miff;
##mogrify -format tiff frame-*.png;
frame_index=0
GS=$SG
#echo "convert frames.miff \\" > create_gif.sh;
#frame-${frame_index}.gif frames.miff;
last_dim_w=1
last_dim_h=1
while test $frame_index -lt $SG; do
    frame_index=$((${frame_index} + 1))
    frame=frame-${frame_index}.png
    echo "building opening title ${frame} of ${SG}";

    # Crop out the left and bottom edges and then trim what's left
    mogrify -crop +0-80 +repage -crop +30+0 +repage \
        -trim +repage -bordercolor black -border 20x20 ${frame};

    frame_w=$(identify -format "%w" ${frame});
    frame_h=$(identify -format "%h" ${frame});
    if test $frame_w -gt $last_dim_w; then
        last_dim_w=$frame_w
    fi
    if test $frame_h -gt $last_dim_h; then
        last_dim_h=$frame_h
    fi
    mogrify -background black -gravity center -extent ${last_dim_w}x${last_dim_h} +repage ${frame};
    mogrify -scale 1024x768 +repage ${frame};
    convert -size 1024x768 canvas:black \
        -gravity center $frame -compose Over -composite \
        f-${GS}.png;
    rm $frame;

    GS=$((${GS} - 1))

    #delay=`sed -n ''"${SG}"' L' delay.txt`;
    #convert frame-${frame_index}.png frame-${frame_index}.gif;
    #echo "-delay ${delay} frame-${frame_index}.gif \\" >> create_gif.sh;
    #convert frames.miff -delay $delay frame-${frame_index}.gif frames.miff;
    #rm frame-${frame_index}.png;

    #TODO: add in other screenshots for the other slots.
    #TODO: use an auto trim and scale from imagemagick.  This is so a 'title' can simply be typed out.
    #convert -size 1280x720 canvas:black -gravity West $frame -scale x720 -compose Over -composite $frame;
    #convert -size 1920x1080 canvas:black -gravity West $frame -scale x1080 -compose Over -composite $frame;
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

ffmpeg -framerate 25 -i f-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r 25 opening-title.mov;

fi
fi
)
