import UIKit
import ARKit

class ScribbleAnchor: ARAnchor {
    let node: SCNNode
    
    init(scribble: SCNNode, image: UIImage, transform: simd_float4x4) {
        self.node = scribble
        super.init(name: "scribble", transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        self.node = (anchor as! ScribbleAnchor).node
        super.init(anchor: anchor)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        if let node = aDecoder.decodeObject(of: SCNNode.self, forKey: "scribble") {
            self.node = node
        } else {
            return nil
        }
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(node, forKey: "scribble")
    }
}
