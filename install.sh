#!/bin/bash

git clone --recursive https://github.com/MTACS/LookinLoader.git
cd layout/usr/lib/Lookin/LookinServer.framework/
ldid -S LookinServer
cd ../../../../../
