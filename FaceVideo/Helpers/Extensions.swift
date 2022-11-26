import UIKit


extension UIView {

	/// Flip and rotate view
	static func flipAndRotate() -> CGAffineTransform {
		let flip = CGAffineTransform(scaleX: -1, y: 1)
		let rotate = CGAffineTransform(rotationAngle: (180.0 * CGFloat(Double.pi)) / 180.0)
		return flip.concatenating(rotate)
	}
	
}


extension CGRect {
	
	/// Scale to screen size
	func scaleToScreen() -> CGRect {
		return CGRect(
			x: self.origin.x * UIApplication.shared.delegate!.window!!.rootViewController!.view.frame.width + self.origin.x,
			y: (1 - self.origin.y) * UIApplication.shared.delegate!.window!!.rootViewController!.view.frame.height,
			width: self.size.width * UIApplication.shared.delegate!.window!!.rootViewController!.view.frame.width,
			height: self.size.height * UIApplication.shared.delegate!.window!!.rootViewController!.view.frame.height)
	}
	
}


extension CGImagePropertyOrientation {
	
	/// Convert for use in Vision analysis.
	static func orientation() -> CGImagePropertyOrientation {
		switch UIDevice.current.orientation {
		case .portraitUpsideDown: return .rightMirrored
		case .landscapeLeft: return .downMirrored
		case .landscapeRight: return .upMirrored
		default: return .leftMirrored
		}
	}
	
}









