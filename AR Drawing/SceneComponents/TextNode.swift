import UIKit
import ARKit

// Node with text

class TextNode: SCNNode {
    let extrusionDepth: CGFloat = 0.02
    
    var node: SCNNode?

    var text: String {
        didSet {
            (self.node!.geometry as! SCNText).string = text
            recenterPivot()
        }
    }
    
    init(text: String, color: UIColor) {
        self.text = text
        
        let geometry = SCNText(string: self.text, extrusionDepth: self.extrusionDepth)
        geometry.alignmentMode = "center"
        geometry.font = UIFont(name: "Arial", size: 0.2)
        geometry.firstMaterial?.diffuse.contents = color
        self.node = SCNNode(geometry: geometry)
        
        super.init()
        
        self.name = "text"
        self.node!.name = "textnode"
        
        self.recenterPivot()
        self.addChildNode(node!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.node = aDecoder.decodeObject(of: SCNNode.self, forKey: "node")
        self.text = aDecoder.decodeObject(forKey: "text") as! String
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(node, forKey: "node")
        aCoder.encode(text, forKey: "text")
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    func recenterPivot() {
        let (min, max) = self.node!.boundingBox
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        self.node!.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
    }
}
