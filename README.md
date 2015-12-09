PNGS2MP4
========

A command line utility that generates a movie from a series of images. The output video will be encoded in H.264 codec using High Profile 4.1. All parameters will be set to default values if not supplied.

Usage:

    pngs2mp4 [options] <dir_1> <dir_2> ...

        -f       Frames per second of the movie.
        -b       Bits per second of the movie.
        -h       Height of the frame.
        -l       Logo at the corner.
        -o       Output filename.
        -w       Fit to 16 x 9 widescreen.
        -v       Increase verbose level.

        <dir_x>  Directories that contains the images, which must contain the same number of images.

    Defaults:

        f = 15
        b = <auto calculate, 1 bit / pixel / frame>
        h = <same as the image height>
        l = <none>
        o = <current directory name>.mp4
        v = 0


EXAMPLE 1:
----------

    pngs2mp4 -f 15 -o sample.mp4 images/

generates a 15-fps movie named sample.mp4 in the current folder using images in the folder 'images' relative to the current folder. Verbosity will be kept minimal.


EXAMPLE 2:
----------

    pngs2mp4 -v -f 10 -l logo.png -o sample.mp4 images/

generates a 10-fps movie named sample.mp4 in the current folder using images in the folder 'images'. The utility runs in a verbose mode, which generates a lot of internal messages. A logo named 'logo.png' will also be imprinted at the lower right corner.

Copyright (c) 2014-2016 Boon Leng Cheong. All Rights Reserved.
