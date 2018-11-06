import UIKit
import SceneKit
import ARKit

class Plane: SCNNode {
    let transparancy: CGFloat = 0.5
    
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: ARSCNPlaneGeometry
    var planeNode: SCNNode
    
    init(_ anchor: ARPlaneAnchor) {
        
        self.planeAnchor = anchor
        //self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        self.planeGeometry = ARSCNPlaneGeometry(device: MTLCreateSystemDefaultDevice()!)!
        self.planeGeometry.update(from: anchor.geometry)
        self.planeGeometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(transparancy)
        self.planeGeometry.firstMaterial?.isDoubleSided = true
        
        self.planeNode = SCNNode(geometry: self.planeGeometry)
        //self.planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        
        super.init()
        
        self.addChildNode(planeNode)
        
        self.position = SCNVector3(anchor.center.x, anchor.center.y, anchor.center.z)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor) {
        self.planeAnchor = anchor
        //self.planeGeometry.width = CGFloat(anchor.extent.x)
        //self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        self.planeGeometry.update(from: anchor.geometry)
        
        self.position = SCNVector3Make(anchor.center.x, anchor.center.y, anchor.center.z)
    }
    
    func setColor(_ color: UIColor) {
        self.planeGeometry.materials.first?.diffuse.contents = color.withAlphaComponent(transparancy)
    }
    
}
