import UIKit
import ARKit

class TextNode: SCNNode {
    var node: SCNNode
    
    var text: String {
        didSet {
            (self.node.geometry as! SCNText).string = text
            recenterPivot()
        }
    }
    
    let extrusionDepth: CGFloat = 0.02
    
    
    init(text: String, color: UIColor) {
        self.text = text
        
        let geometry = SCNText(string: self.text, extrusionDepth: self.extrusionDepth)
        geometry.alignmentMode = "center"
        geometry.font = UIFont(name: "Arial", size: 0.2)
        geometry.firstMaterial?.diffuse.contents = color
        self.node = SCNNode(geometry: geometry)
        
        
        super.init()
        
        self.name = "text"
        
        self.recenterPivot()
        self.addChildNode(node)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func recenterPivot() {
        
        let (min, max) = self.node.boundingBox
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        self.node.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
    }
}
