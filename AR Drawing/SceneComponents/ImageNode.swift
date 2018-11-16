import UIKit
import SceneKit
import ARKit

// Plane node with image content

class ImageNode: SCNNode {
    var node: SCNNode
    var image: UIImage
    
    init(image: UIImage, size: CGSize) {
        self.image = image
        
        let geometry = SCNPlane(width: size.width, height: size.height)
        geometry.firstMaterial?.diffuse.contents = image
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.emission.contents = UIColor.black
        geometry.firstMaterial?.transparencyMode = .aOne
        
        self.node = SCNNode(geometry: geometry)
        //self.node.simdTransform *= float4x4(simd_quatf(angle: Float.pi / 2, axis: float3(1,0,0)))
        
        super.init()
        
        self.name = "image"
        self.node.name = "imagenode"
        
        self.addChildNode(node)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
