# Detect Face in Real Time and Track Users Nose
***
The [Vision](https://developer.apple.com/documentation/vision) framework can detect and track rectangles, faces, and other objects.
### Overview
This sample shows how to create requests to track a face in real time. Once it finds a face, it attempts to track the nose across subsequent frames of the video. With each video frame, nose properties are set, including a frame property along with other nose features, such as: left and right nostrils; top, bottom, left and right edges.

Other facial landmarks can easily be detected, but this sample only tracks the nose.

### Requirements:
iOS 11.0+
