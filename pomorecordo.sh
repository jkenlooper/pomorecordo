#!/bin/bash

# PomoRecordo.sh
# Record screen and audio for 25 min pomodoro and display-messages to tmux.
# Includes bonus opening-title creation with both forward and backward.
#
# First arg is the todo line number, Second is optional directory to use.  Will continue if there is an existing vid.

# Lazy way of setting options...
# Minutes for the Pomodoro timer.
TIMER=${TIMER-25};

# 0 is off and 1 is on.
OPENINGTITLE=${OPENINGTITLE-1}
REALTIME=${REALTIME-1}
TIMELAPSE=${TIMELAPSE-1}
CLEANUP_REALTIME=${CLEANUP_REALTIME-1}
AUDIO=${AUDIO-1}

FRAMERATE=${FRAMERATE-12}
FPS=${FPS-12}

# Set this to the minium amount of time (seconds) between frames that are the same.
IDLE=${IDLE-5}
MAIN_IDLE=${MAIN_IDLE-1}

BACKGROUND_COLOR=${BACKGROUND_COLOR-"#262626"}

CONTINUATION=0;
# If second arg then this is a continuation if there is an existing vid, otherwise use the directory if it exists
SGDIR=$2;
if test "$2" -a -d "$2" -a -f "$2/opening-and-timelapse.mp4"; then
  CONTINUATION=1;
  echo "Continuing recording in: $2";
fi

# Load the TASK variable with the todo text
#TASK=`sed -n ''"$1"' L' $HOME/.todo/todo.txt`;
#echo "Starting timer for task: ${TASK}"
echo "Starting in:";
COUNTDOWNTOSCGREENGRAB=10;
while test $COUNTDOWNTOSCGREENGRAB -gt -1; do
  read -n 1 -p "$COUNTDOWNTOSCGREENGRAB.." -t 1 CANCELSCREENGRAB && break;
  tmux display-message "$COUNTDOWNTOSCGREENGRAB"
  COUNTDOWNTOSCGREENGRAB=$(($COUNTDOWNTOSCGREENGRAB-1));
done;

if test $CANCELSCREENGRAB; then
  echo 'cancelled screen grab';
  exit 0
fi

# Make a new directory in the cwd if no SGDIR has been set
START=`date +%s`;
if test ! -n "$SGDIR"; then
  SGDIR=sg-${START};
fi
mkdir -p ${SGDIR};

echo "Recording in ${SGDIR}";
cd ${SGDIR};


import -silent -window root screensize-test.png
screensize=$(identify -format %wx%h screensize-test.png)
rm screensize-test.png

if test $CONTINUATION -eq 0; then

  END=`date -d "${OPENINGTITLE} minutes" +%s`

  FRAME_TIMESTAMP=$(date +%s.%N);

  frameinterval=$(echo "scale=6; 1/12;" | bc);
  # Record the opening title
  SG=1
  import -silent -window root frame-${SG}.png
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

    import -silent -window root frame-${SG}.png

    # Throw out this frame if it's the same as previous ( and adjust $findex )
    if test $(($now - $last_frame_date)) -lt $IDLE && test "$(compare -metric AE ${previous_frame} ${frame} diff.png 2>&1)" -eq 0; then
        rm ${frame};
        SG=$(($SG - 1));
    else
        # It's been more then $IDLE seconds since the last frame or it was different.
        # The last_frame_date marks the time each frame has been added.
        last_frame_date=$now
    fi

    # Allow for pressing a key to stop taking frames.
    # This is simply done to have something to trigger a stop.
    # timeout should only be an integer and not be less than 0.
    timeout=$(echo "$frameinterval - $DELAY" | bc | xargs printf "%.*f" 0 );
    timeout=$(test $timeout -lt 0 && echo "0" || echo $timeout)

    read -n 1 -t $timeout CANCELFBGRAB && break;

    # Display time left to tmux session occasionally
    if test $(($now - $last_message_date)) -gt 1 && test $((($END - $now) % 60)) -eq 0 || \
        test $(($END - $now)) -lt 10 && test $(($END - $now)) -gt 5; then
        tmux display-message "$(($END - $now)) seconds left"
        # Update last_message_date to avoid displaying multiple messages.
        last_message_date=$now
    fi
  done;

fi
if test $CANCELFBGRAB; then
    echo screen grab canceled.
    #TODO: cleanup any frame-*.png created?
    exit 0
fi

# signal that recording has now begun.
#tmux display-message "${TASK}"

# Start audio recording and put it in the background
if test $AUDIO -eq 1; then
  # TODO: don't overwrite existing out.wav
  arecord -d $(($TIMER * 60)) -f dat out.wav &
  AUDIO_PID=$!
fi

timer.sh $1 $TIMER &
TIMER_PID=$!
STOP=`date +%s`;

END=`date -d "$TIMER minutes" +%s`
# start recording the main session
if test $REALTIME -eq 1; then
  REALTIME_I=''
  while test -f realtime${REALTIME_I}.mp4; do
      REALTIME_I=$((${REALTIME_I}+1));
  done;

  ffmpeg -t $((60 * $TIMER)) -f x11grab -video_size $screensize -framerate $FPS -i :0.0 -vcodec huffyuv realtime${REALTIME_I}.avi &

fi

if test $TIMELAPSE -eq 1; then
  FRAME_TIMESTAMP=$(date +%s.%N);

  frameinterval=$(echo "scale=6; 1/12;" | bc);
  #MainScreenGrab ... not the Mono Sodium Glutamate...
  MSG=1
  import -silent -window root m-${MSG}.png
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

    import -silent -window root m-${MSG}.png

    # Throw out this frame if it's the same as previous ( and adjust $findex )
    if test $(($now - $last_frame_date)) -lt $MAIN_IDLE && \
        test "$(compare -metric AE ${previous_frame} ${frame} -compose Src diff.png 2>&1 | tee diff)" -eq 0; then
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
            if test "$(echo "$(convert diff.png -trim -format '%w * %h' info:)" | bc)" -gt 248000; then
                show_large_diff=$(($now+6))
                rm diff.png;
            fi
        fi
    fi

    # Allow for pressing a key to stop taking frames.
    # This is simply done to have something to trigger a stop.
    # timeout should only be an integer and not be less than 0.
    timeout=$(echo "$frameinterval - $DELAY" | bc | xargs printf "%.*f" 0 );
    timeout=$(test $timeout -lt 0 && echo "0" || echo $timeout)
    #echo "timeout is $timeout"
    read -n 1 -t $timeout CANCELFBGRAB && break;

  done;

  # Stop the timer.sh in case the screen grab was cancelled.
  kill $TIMER_PID 2> /dev/null || echo 'timer finished'

  DONEMSG=5;
  while test $DONEMSG -gt -1; do
      # so cheesy...
      tmux display-message "Complete... Take 5. That's a wrap."
      sleep 1;
      DONEMSG=$(($DONEMSG-1));
  done;

  # Create a time lapse of the m-*.png with about 12 fps
  ffmpeg -framerate ${FRAMERATE} -i m-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r ${FRAMERATE} timelapse.mp4

  rm -f m-*.png;
  rm -f diff.png;
  rm -f diff
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

if test $CONTINUATION -eq 0; then

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
      mogrify -crop +0-80 +repage -crop +40+0 +repage \
          -trim +repage -bordercolor $BACKGROUND_COLOR -border 40x40 ${frame};

      frame_w=$(identify -format "%w" ${frame});
      frame_h=$(identify -format "%h" ${frame});
      if test $frame_w -gt $last_dim_w; then
          last_dim_w=$frame_w
      fi
      if test $frame_h -gt $last_dim_h; then
          last_dim_h=$frame_h
      fi

      # Add background color with cropped frame positioned on top
      # Using default gravity of top left to avoid jumpiness ( as long as the top and left edges remain the same )
      mogrify -background $BACKGROUND_COLOR -extent ${last_dim_w}x${last_dim_h} +repage ${frame};

      # Make it big ( use -scale as it's better for keeping the pixels crisp )
      # Also center it within the frame.
      # 1440x1080
      mogrify -filter box -scale ${screensize} +repage ${frame};
      convert -size ${screensize} canvas:$BACKGROUND_COLOR \
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
      cp f-${frame_index}.png g-${newframe_index}.png;
      newframe_index=$((${newframe_index} + 1))
      frame_index=$((${frame_index} - 1))
  done;

  # Note that this is effectivley at a fast speed which should result in a short 5~ second opening title mp4.
  inputframerate=$((${SG}/5));
  ffmpeg -framerate $inputframerate -i g-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r ${FRAMERATE} opening-title--forward.mp4 \
    && rm g-*.png;
  ffmpeg -framerate $inputframerate -i f-%d.png -c:v libx264 -pix_fmt yuv420p -b:v 10000000 -vcodec mpeg4 -r ${FRAMERATE} opening-title--backward.mp4 \
    && rm f-*.png;

  # Combine the two videos using ffmpeg.
  ffmpeg -f concat -safe 0 -i <(for f in $PWD/opening-title--backward.mp4 $PWD/timelapse.mp4; do echo "file '$f'"; done) -c copy opening-and-timelapse.mp4 \
    && rm opening-title--forward.mp4 opening-title--backward.mp4 timelapse.mp4;

else

  # Combine this video on the last one since this is a CONTINUATION
  mv opening-and-timelapse.mp4 previous.mp4;
  ffmpeg -f concat -safe 0 -i <(for f in $PWD/previous.mp4 $PWD/timelapse.mp4; do echo "file '$f'"; done) -c copy opening-and-timelapse.mp4 \
    && rm previous.mp4 timelapse.mp4;

fi

# Clean up the huge avi files after converting to mp4
if test $REALTIME -eq 1 -a $CLEANUP_REALTIME -eq 1; then
  for f in realtime*.avi; do
    ffmpeg -i $f -i out.wav -map 0:v -map 1:a ${f%.avi}.mp4
    rm $f
  done
fi

