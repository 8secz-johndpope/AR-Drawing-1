import ARKit
import SceneKit

class NodeAnchor: ARAnchor {
    let node: SCNNode
    let step: Int
    
    init(node: SCNNode, step: Int, transform: simd_float4x4) {
        self.node = node
        self.step = step
        super.init(name: "nodeanchor", transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        self.node = (anchor as! NodeAnchor).node
        self.step = (anchor as! NodeAnchor).step
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
        
        self.step = aDecoder.decodeInteger(forKey: "step")
        
        print("In decoder constructor of NodeAnchor: step=\(step) node=\(node)")
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        print("In encode of NodeAnchor: step=\(step) node=\(node)")
        aCoder.encode(node, forKey: "node")
        aCoder.encode(step, forKey: "step")
    }
}
