# 4gif

An optimizing video to gif converter for a certain image board

---

Goal: Squeeze maximum quality and/or resolution out of the 3MiB limit

Available resolution/compression quality tradeoffs:

* framerate decimation
* ordered dithering/error diffusion dithering/simple posterization
* fuzzy transparency optimization
* per frame palettes/single global color palette

Additional features:

* color quantization/dithering is performed in L*a*b* color space for perceptually optimal results
* high bit depth processing right up to the quantization step
* splicing multiple timecode sequences from multiple videos into a single gif
* parallel processing of ranges where possible. it's still horribly slow, especially with ordered dithering. but it would be worse without
* resolution/quality tradeoffs can be configured separately for individual timecode sequences 
* cropping
* insert still images in the gif sequence
* adjust playback speed
* forward-rewind loops
* extend last-frame duration at range boundaries to make cuts less rapid


---

Requirements:

* ruby 2.x, preferably rubinius for multithreading
* imagemagick, preferably a Q16 build
* gifsicle
* ffmpeg
* loads of RAM and CPU cores, this won't run on shiny plastic toys

Also, RTFM (no, not this one, baka)

---

Features I might add in the future:

* Improved threshold maps for ordered dithering (Imagemagick's OD sucks in comparison to Photoshop's arbitrary palette implementation)
* burning softsubs into the gif

Merge requests welcome.