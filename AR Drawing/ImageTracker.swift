import SceneKit
import ARKit

class ImageTracker {
    var trackedImages: Set<ARReferenceImage>
    var trackedImagePlanes: [ARImageAnchor: SCNNode]
    
    init(imageGroup: String) {
        guard let images = ARReferenceImage.referenceImages(inGroupNamed: imageGroup, bundle: nil) else {
            fatalError("Tracking images could not be loaded!")
        }
        
        self.trackedImages = images
        self.trackedImagePlanes = [ARImageAnchor: SCNNode]()
    }
    
    
    func detectedImage(imageAnchor: ARImageAnchor, newNode: SCNNode) {
        print("New tracked image detected")
        
        let size = imageAnchor.referenceImage.physicalSize
        let plane = SCNNode(geometry: SCNPlane(width: size.width, height: size.height))
        plane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColor
        plane.geometry?.firstMaterial?.isDoubleSided = true
        plane.simdTransform *= float4x4(simd_quatf(angle: Float.pi / 2, axis: float3(1,0,0)))
        plane.name = "tracked_image_plane"
        plane.renderingOrder = -10
        newNode.addChildNode(plane)
        self.trackedImagePlanes[imageAnchor] = plane
    }
    
    func updateTrackedImageAnchor(imageAnchor: ARImageAnchor) {
        // hide plane if image cannot be tracked
        self.trackedImagePlanes[imageAnchor]?.isHidden = !imageAnchor.isTracked
    }
    
    func hitTestTrackedImage(in sceneView: ARSCNView, from point: CGPoint) -> SCNHitTestResult? {
        let results = sceneView.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        let planes = results.filter { $0.node.name == "tracked_image_plane" }
        if let hit = planes.first {
            return hit
        }
        return nil
    }
    
    func resetPlaneColors() {
        for(_, plane) in trackedImagePlanes {
            plane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColor
        }
    }
}
