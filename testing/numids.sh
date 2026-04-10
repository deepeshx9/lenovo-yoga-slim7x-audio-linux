#! /bin/bash

set -e

set -u

amixer -c 0 cset numid=103 255

amixer -c 0 cset numid=73 2
amixer -c 0 cset numid=74 2
amixer -c 0 cset numid=90 2
amixer -c 0 cset numid=91 2


amixer -c 0 cset numid=78 3
amixer -c 0 cset numid=82 4
amixer -c 0 cset numid=95 3
amixer -c 0 cset numid=99 4
