#! /bin/bash

echo "Do not run this script. It will permanently damage the hardware!!"

systemctl --user stop wireplumber pipewire pipewire-pulse

amixer -c 0 cset name='WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia1' 1

amixer -c 0 cset numid=103 255

amixer -c 0 cset numid=73 2
amixer -c 0 cset numid=74 2
amixer -c 0 cset numid=90 2
amixer -c 0 cset numid=91 2


amixer -c 0 cset numid=78 3
amixer -c 0 cset numid=82 4
amixer -c 0 cset numid=95 3
amixer -c 0 cset numid=99 4

amixer -c 0 cset name='TweeterLeft COMP Switch' 1
amixer -c 0 cset name='TweeterRight COMP Switch' 1
amixer -c 0 cset name='TweeterLeft DAC Switch' on
amixer -c 0 cset name='TweeterRight DAC Switch' on
amixer -c 0 cset name='TweeterLeft PA Volume' 12
amixer -c 0 cset name='TweeterRight PA Volume' 12

amixer -c 0 cset name='WooferLeft COMP Switch' 1
amixer -c 0 cset name='WooferRight COMP Switch' 1
amixer -c 0 cset name='WooferLeft DAC Switch' on
amixer -c 0 cset name='WooferRight DAC Switch' on
amixer -c 0 cset name='WooferLeft PA Volume' 12
amixer -c 0 cset name='WooferRight PA Volume' 12

amixer -c 0 cset name='WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia1' 1
amixer -c 0 cset name='TweeterLeft COMP Switch' 1
amixer -c 0 cset name='TweeterRight COMP Switch' 1
amixer -c 0 cset name='TweeterLeft DAC Switch' on
amixer -c 0 cset name='TweeterRight DAC Switch' on
amixer -c 0 cset name='TweeterLeft PA Volume' 12
amixer -c 0 cset name='TweeterRight PA Volume' 12

aplay -D plughw:0,0 -c 2 -r 48000 -f S32_LE /dev/urandom
aplay -D plughw:0,0 -c 4 -r 48000 -f S32_LE /dev/urandom
