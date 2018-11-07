import UIKit
import SceneKit
import ARKit

class Plane: SCNNode {
    
    let meshOpacity: CGFloat = 0.3
    let extentOpacity: CGFloat = 0.6
    
    var planeAnchor: ARPlaneAnchor
    var meshNode: SCNNode
    var extentNode: SCNNode
    
    init(_ anchor: ARPlaneAnchor, in sceneView: ARSCNView) {
        
        self.planeAnchor = anchor
        
        // mesh to visualize estimated borders of plane
        guard let geometry = ARSCNPlaneGeometry(device: sceneView.device!) else {
            fatalError("Cannot create plane geometry")
        }
        geometry.update(from: anchor.geometry)
        self.meshNode = SCNNode(geometry: geometry)
        self.meshNode.geometry?.firstMaterial?.isDoubleSided = true
        self.meshNode.opacity = 0.3
        self.meshNode.geometry?.firstMaterial?.diffuse.contents = UIColor.planeColor
        
        // node to visualize the plane's bounding rectangle.
        let extentPlane: SCNPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        self.extentNode = SCNNode(geometry: extentPlane)
        self.extentNode.simdPosition = anchor.center
        self.extentNode.opacity = 0.6
        self.extentNode.geometry?.firstMaterial?.diffuse.contents = UIColor.planeColor
        
        // Use a SceneKit shader modifier to render only the borders of the plane.
        guard let path = Bundle.main.path(forResource: "wireframe_shader", ofType: "metal", inDirectory: "Assets.scnassets")
            else { fatalError("Can't find wireframe shader") }
        do {
            let shader = try String(contentsOfFile: path, encoding: .utf8)
            self.extentNode.geometry?.firstMaterial!.shaderModifiers = [.surface: shader]
        } catch {
            fatalError("Can't load wireframe shader: \(error)")
        }
        
        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`.
        self.extentNode.eulerAngles.x = -.pi / 2
       
        super.init()
        
        self.addChildNode(self.meshNode)
        self.addChildNode(self.extentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor) {
        if let planeGeometry = self.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: anchor.geometry)
        }
        
        if let extendGeometry = self.extentNode.geometry as? SCNPlane {
            extendGeometry.width = CGFloat(anchor.extent.x)
            extendGeometry.height = CGFloat(anchor.extent.z)
            self.extentNode.simdPosition = anchor.center
        }
    }
    
    func setColor(_ color: UIColor) {
        self.meshNode.geometry?.firstMaterial?.diffuse.contents = color
        self.extentNode.geometry?.firstMaterial?.diffuse.contents = color
    }
    
}
