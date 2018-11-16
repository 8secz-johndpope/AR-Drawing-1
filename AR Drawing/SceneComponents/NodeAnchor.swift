import ARKit
import SceneKit

class NodeAnchor: ARAnchor {
    let node: SCNNode
    
    init(node: SCNNode, transform: simd_float4x4) {
        self.node = node
        super.init(name: "nodeanchor", transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        self.node = (anchor as! NodeAnchor).node
        super.init(anchor: anchor)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        if let node = aDecoder.decodeObject(of: SCNNode.self, forKey: "node") {
            self.node = node
        } else {
            return nil
        }
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(node, forKey: "node")
    }
}
