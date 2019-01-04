import UIKit


struct Nose {
	
	static var tip = CGPoint.zero

	static var top = CGPoint.zero
	static var bottom = CGPoint.zero
	
	static var leftEdge: CGFloat = 0.0
	static var rightEdge: CGFloat = 0.0
	
	static var leftNostril: CGFloat = 0.0
	static var rightNostril: CGFloat = 0.0
	
	static var frame: CGRect { return CGRect(x: leftEdge, y: bottom.y, width: rightEdge - leftEdge, height: top.y - bottom.y) }

}

