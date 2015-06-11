## PomoRecordo.sh

Record screen and audio for 25 min pomodoro and display-messages to
tmux

Includes bonus opening-title creation

## Why?

This script started off as a few lines and then got more complex.
I wouldn't say it's pretty or has much use beyond my own, but maybe it
could potentially be useful to someone else.  

## Usage

This records the screen from the framebuffer and uses ffmpeg as well as a few
other commands.  It basically takes two args: the first is the line number of
a todo item in todo.txt, and the other is an optional directory where to store
the video.  It will append to an existing video if present.
