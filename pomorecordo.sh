#!/bin/bash

# PomoRecordo.sh
# Record screen and audio for 25 min pomodoro and display-messages to tmux
# Includes bonus opening-title creation

TIMER=25;
OPENINGTITLE=4;
FRAMERATE=12;
FPS=12

#TODO: how to do a continuation?
REALTIME=1;
TIMELAPSE=1;
AUDIO=1;

# set this to the minium amount of time (seconds) between frames that are the same.
IDLE=5;
MAIN_IDLE=1;

# Load the TASK variable with the todo text
TASK=`sed -n ''"$1"' L' $HOME/.todo/todo.txt`;
echo "Starting timer for task: ${TASK}"
echo "Starting in:";
COUNTDOWNTOSCGREENGRAB=10;
while test $COUNTDOWNTOSCGREENGRAB -gt -1; do
    read -n 1 -p "$COUNTDOWNTOSCGREENGRAB.." -t 1 CANCELSCREENGRAB && break;
    tmux display-message -c /dev/tty1 "$COUNTDOWNTOSCGREENGRAB"
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

END=`date -d "${OPENINGTITLE} minutes" +%s`

FRAME_TIMESTAMP=$(date +%s.%N);

frameinterval=$(echo "scale=6; 1/12;" | bc);
# Record the opening title
SG=1
fbgrab -d /dev/fb0 frame-${SG}.png 2> /dev/null &
now=$(date +%s)
last_frame_date=$now
last_message_date=$now
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
  if test $(($now - $last_frame_date)) -lt $IDLE && test $(compare -metric AE ${previous_frame} ${frame} diff.png 2>&1) -eq 0; then
      rm ${frame};
      SG=$(($SG - 1));
  else
      # It's been more then $IDLE seconds since the last frame or it was different.
      # The last_frame_date marks the time each frame has been added.
      last_frame_date=$now
  fi

  # Allow for pressing a key to stop taking frames.
  # This is simply done to have something to trigger a stop.
  timeout=$(echo "$frameinterval - $DELAY" | bc);
  read -n 1 -t $timeout CANCELFBGRAB && break;

  # Display time left to tmux session occasionaly
  if test $(($now - $last_message_date)) -gt 1 && test $((($END - $now) % 60)) -eq 0 || \
      test $(($END - $now)) -lt 10 && test $(($END - $now)) -gt 5; then
      tmux display-message -c /dev/tty1 "$(($END - $now)) seconds left"
      # Update last_message_date to avoid displaying multiple messages.
      last_message_date=$now
  fi
done;
if test $CANCELFBGRAB; then
    echo screen grab canceled.
    #TODO: cleanup any frame-*.png created?
else

# copy the last frame a bunch so the opening title will show longer.
# 50 being FRAMERATE * 2 for about 2 seconds
# TODO: could be done a different way by using ffmpeg -concat
#for i in {1..50}; do
#    cp frame-${SG}.png frame-$(($SG + 1)).png
#    SG=$(($SG+1));
#done;

# signal that recording has now begun.
tmux display-message -c /dev/tty1 "${TASK}"

# Start audio recording and put it in the background
if test $AUDIO -eq 1; then
arecord -d $(($TIMER * 60)) -f dat out.wav &
AUDIO_PID=$!
fi

timer.sh $1 $TIMER &
TIMER_PID=$!
STOP=`date +%s`;

END=`date -d "$TIMER minutes" +%s`
# start recording the main session
if test $REALTIME -eq 1; then
ffmpeg -t $((60 * $TIMER)) -f fbdev -r $FPS -i /dev/fb0 -b:v 10000000 -vcodec mpeg4 realtime.mov &
fi
if test $TIMELAPSE -eq 1; then
FRAME_TIMESTAMP=$(date +%s.%N);

frameinterval=$(echo "scale=6; 1/12;" | bc);
#MainScreenGrab ... not the Mono Sodium Glutamate...
MSG=1
fbgrab -d /dev/fb0 m-${MSG}.png 2> /dev/null &
now=$(date +%s)
show_large_diff=$now
idle=$MAIN_IDLE
last_frame_date=$now
last_message_date=$now
while test $END -ge $now; do
  now=$(date +%s)
  MSG=$(($MSG+1));

  FRAME_TIMESTAMP_NOW=$(date +%s.%N);
  DELAY=$(echo "scale=3; (($FRAME_TIMESTAMP_NOW - $FRAME_TIMESTAMP)/1) - $frameinterval;" | bc);
  FRAME_TIMESTAMP=$FRAME_TIMESTAMP_NOW
  previous_frame=m-$(($MSG - 1)).png
  frame=m-${MSG}.png

  fbgrab -d /dev/fb0 m-${MSG}.png 2> /dev/null

  # Throw out this frame if it's the same as previous ( and adjust $findex )
  if test $(($now - $last_frame_date)) -lt $MAIN_IDLE && \
      test $(compare -metric AE ${previous_frame} ${frame} -compose Src diff.png 2>&1 | tee diff) -eq 0; then
      # Only remove the frame if the skipframe flag is set.
      if test $show_large_diff -lt $now; then
          rm ${frame};
          MSG=$(($MSG - 1));
      fi
  else
      #mogrify -scale 1440x1080 +repage ${frame} &
      # It's been more then $MAIN_IDLE seconds since the last frame or it was different.
      # The last_frame_date marks the time each frame has been added.
      last_frame_date=$now

      #last frame was different
      if test -f diff.png; then
          # check the diff.png for the size of the difference and set the skipframe flag
          if test $(echo "$(convert diff.png -trim -format '%w * %h' info:)" | bc) -gt 248000; then
              show_large_diff=$(($now+6))
              rm diff.png;
          fi
      fi
  fi

  # Allow for pressing a key to stop taking frames.
  # This is simply done to have something to trigger a stop.
  timeout=$(echo "$frameinterval - $DELAY" | bc);
  read -n 1 -t $timeout CANCELFBGRAB && break;

done;

tmux display-message -c /dev/tty1 "Complete... Take 5. That's a wrap."

screensize=$(identify -format %wx%h m-1.png)

# Create a time lapse of the m-*.png with about 12 fps
ffmpeg -framerate ${FRAMERATE} -i m-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r ${FRAMERATE} timelapse.mov && \
    rm m-*.png;

rm m-*.png;
rm diff.png;
fi

# Stall while the REALTIME recording might still be going
now=$(date +%s)
if test $END -ge $now; then
echo "waiting every 5 seconds since timer not complete."
fi
while test $END -ge $now; do
  read -n 1 -t 5 -p "." && break
  now=$(date +%s)
done;

if test $AUDIO -eq 1; then
kill $AUDIO_PID
fi


echo "Converting ${SG} frames for opening title";


frame_index=0
GS=$SG
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

    # Add black bg with cropped frame positioned on top
    # Using default gravity of top left to avoid jumpiness ( as long as the top and left edges remain the same )
    mogrify -background black -extent ${last_dim_w}x${last_dim_h} +repage ${frame};

    # Make it big ( use -scale as it's better for keeping the pixels crisp )
    # Also center it within the frame.
    # 1440x1080
    mogrify -scale ${screensize} +repage ${frame};
    convert -size ${screensize} canvas:black \
        -gravity center $frame -compose Over -composite \
        f-${GS}.png;
    rm $frame;

    # And this is how it is reversed
    GS=$((${GS} - 1))

done;

cp f-1.png opening-title.png;

# Now do an unreverse since the f-*.png have been properly cropped
# f-*.png -> g-*.png but in reversed index
frame_index=$SG;
newframe_index=1;
while test $frame_index -gt 0; do
    mv f-${frame_index}.png g-${newframe_index}.png;
    newframe_index=$((${newframe_index} + 1))
    frame_index=$((${frame_index} - 1))
done;

# Note that this is effectivley at a fast speed which should result in a short 5~ second opening title mov.
inputframerate=$((${SG}/5));
ffmpeg -framerate $inputframerate -i g-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r ${FRAMERATE} opening-title.mov && \
    rm g-*.png;

# Combine the two vidoes using ffmpeg.
ffmpeg -f concat -i <(for f in $PWD/opening-title.mov $PWD/timelapse.mov; do echo "file '$f'"; done) -c copy opening-and-timelapse.mov && \
    rm opening-title.mov timelapse.mov;



fi
fi
)
