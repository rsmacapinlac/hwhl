#!/bin/bash

sudo sh -c 'echo $1 > /etc/hostname'; sudo hostname $1
