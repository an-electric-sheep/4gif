# 4gif

An optimizing video to gif converter for a certain image board

---

Goal: Squeeze maxium quality and/or resolution out of the 3MiB limit

Available resolution/compression quality tradeoffs:

* framerate decimation
* dithering/banding
* approximate color substitution (inter-frame fuzzing)
* per frame palettes/single global color palette

Additional features:

* splicing multiple timecode ranges from multiple videos into a single gif
* parallel processing of ranges where possible
* resolution/quality tradeoffs can be configured separately for each range 
* cropping
* insert still images in the gif sequence
* change playback speed
* forward-rewind loops
* extend last-frame duration at range boundaries to make cuts less rapid


RTFM (no, not this one, baka)