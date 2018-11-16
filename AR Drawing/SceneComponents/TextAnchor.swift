import UIKit
import ARKit

class TextAnchor: ARAnchor {
    let node: TextNode
    
    init(textnode: TextNode, transform: simd_float4x4) {
        self.node = textnode
        super.init(name: "text", transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        self.node = (anchor as! TextAnchor).node
        super.init(anchor: anchor)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        if let node = aDecoder.decodeObject(of: TextNode.self, forKey: "text") {
            self.node = node
        } else {
            return nil
        }
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(node, forKey: "text")
    }
}
