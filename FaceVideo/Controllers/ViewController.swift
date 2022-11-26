import UIKit
import AVKit
import Vision


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private lazy var face = UIView()
    private lazy var nose = UIView()
    
    // Vision requests
    private lazy var detectionRequests = [VNDetectFaceRectanglesRequest]()
    private lazy var trackingRequests = [VNTrackObjectRequest]()
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nose.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        nose.transform = UIView.flipAndRotate() // flip and rotate to match CALayer
        face.addSubview(nose)
        
        startFaceTracking()
    }
    
    
    func startFaceTracking() {
        guard setupSession() else { print("Set up session error"); return }
        prepareVisionRequest()
    }
    
    // MARK: - Setup
    
    private func setupSession() -> Bool {
        let session = AVCaptureSession()
        
        let ds = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        guard let device = ds.devices.first, let input = try? AVCaptureDeviceInput(device: device) else { return false }
        
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        
        configureVideo(for: device, session: session)
        addLayer(session)
        
        session.startRunning()
        
        return true
    }
    
    
    private func configureVideo(for inputDevice: AVCaptureDevice, session: AVCaptureSession) {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        
        // Dispatch queue for the sample buffer delegate as well as when a still image is captured. A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "faceTrack"))
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        output.connection(with: .video)?.isEnabled = true
        
        if let connection = output.connection(with: AVMediaType.video) {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = connection.isCameraIntrinsicMatrixDeliverySupported ? true : false
        }
    }
    
    
    private func addLayer(_ session: AVCaptureSession) {
        let	videoLayer = AVCaptureVideoPreviewLayer(session: session)
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoLayer.frame = view.frame
        
        face.transform = UIView.flipAndRotate()
        videoLayer.addSublayer(face.layer)
        
        view.layer.addSublayer(videoLayer)
    }
    
    
    private func configureLayers() {
        // Render layers as bitmaps before compositing to speed up the UI
        view.layer.shouldRasterize = true
        view.layer.rasterizationScale = UIScreen.main.scale
        view.layer.sublayers?.forEach({
            $0.shouldRasterize = true
            $0.rasterizationScale = UIScreen.main.scale
        })
    }
    
    
    private func prepareVisionRequest() {
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { request, error in
            
            guard let request = request as? VNDetectFaceRectanglesRequest, let results = request.results else { return }
            
            // Add observations to tracking list
            for observation in results {
                let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                requests.append(trackingRequest)
            }
            self.trackingRequests = requests
        })
        
        // Start with detection.  Find face, then track it.
        detectionRequests = [faceDetectionRequest]
        sequenceRequestHandler = VNSequenceRequestHandler()
        configureLayers()
    }
    
    
    // MARK: - Delegate: Captured video frame.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        var handler = [VNImageOption: AnyObject]()
        
        if let cameraData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            handler[VNImageOption.cameraIntrinsics] = cameraData
        }
        
        let orientation = CGImagePropertyOrientation.orientation()
        
        if trackingRequests.isEmpty {
            // No tracking object detected, so perform initial detection
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: handler).perform(detectionRequests)
            } catch let error as NSError {
                NSLog("Request the error: %@", error)
            }
            return
        }
        
        do {
            try sequenceRequestHandler.perform(trackingRequests, on: pixelBuffer, orientation: orientation)
        } catch let error as NSError {
            NSLog("sequenceRequestHandler Failed: %@", error)
        }
        
        // Setup the next round of tracking.
        var newRequests = [VNTrackObjectRequest]()
        for r in trackingRequests {
            guard let results = r.results else { return }
            let observation = results[0] as! VNDetectedObjectObservation
            if !r.isLastFrame {
                if observation.confidence > 0.1 {
                    r.inputObservation = observation
                } else {
                    r.isLastFrame = true
                }
                newRequests.append(r)
            }
        }
        
        trackingRequests = newRequests
        
        if newRequests.isEmpty { return }
        
        // Perform face landmark tracking
        landmarkDetection(pixelBuffer: pixelBuffer, orientation: orientation, handler: handler)
    }
    
    
    func landmarkDetection(pixelBuffer: CVImageBuffer, orientation: CGImagePropertyOrientation, handler: [VNImageOption: AnyObject]) {
        var landmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        for r in trackingRequests {
            // Perform landmark detection on tracked faces.
            let request = VNDetectFaceLandmarksRequest(completionHandler: { request, error in
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest, let results = landmarksRequest.results else { return }
                for face in results {
                    self.track(face: face)
                }
            })
            
            guard let trackingResults = r.results, let observation = trackingResults[0] as? VNDetectedObjectObservation else { return }
            
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            request.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            landmarkRequests.append(request)
            
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: handler).perform(landmarkRequests)
            } catch {
                print("Failed Face Landmark Request")
            }
        }
        
    }
    
    // MARK: - Tracking
    
    private func track(face: VNFaceObservation) {
        DispatchQueue.main.async {
            
            let bounds = face.boundingBox.scaleToScreen()
            
            self.face.frame.size = bounds.size
            self.face.frame.origin.x = bounds.origin.x
            self.face.frame.origin.y = bounds.origin.y - bounds.size.height
            
            self.trackNose(points: face.landmarks!.allPoints!.normalizedPoints, face: (width: Int(bounds.size.width), height: Int(bounds.size.height)))
        }
    }
    
    
    private func trackNose(points: [CGPoint], face: (width: Int, height: Int)) {
        Nose.top = VNImagePointForNormalizedPoint(points[60], face.width, face.height)
        Nose.bottom = VNImagePointForNormalizedPoint(points[55], face.width, face.height)
        Nose.tip = VNImagePointForNormalizedPoint(points[62], face.width, face.height)
        Nose.leftEdge = VNImagePointForNormalizedPoint(points[53], face.width, face.height).x
        Nose.rightEdge = VNImagePointForNormalizedPoint(points[57], face.width, face.height).x
        Nose.leftNostril = VNImagePointForNormalizedPoint(points[54], face.width, face.height).y
        Nose.rightNostril = VNImagePointForNormalizedPoint(points[56], face.width, face.height).y
        
        nose.frame = Nose.frame
    }
    
}
