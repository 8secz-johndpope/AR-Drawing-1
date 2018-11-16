import SceneKit
import UIKit
import ARKit

class PlacingState: State {
    
    func onEnterState(context: ViewController) {
        context.setInfoText("Tap the screen to place your scribble in the world")
        context.resetGestureValues()
        context.drawingSceneView?.isHidden = true
        context.drawingSceneView?.isUserInteractionEnabled = false
        context.drawingScene?.isEnabled = false
        context.drawingScene?.clear()
        context.debugLabel.isHidden = false
        context.setGestureDetectorsEnabled(true)
        context.deleteButton.isHidden = false
        context.toggleSideBar(visible: false)
    }
    
    func onExitState(context: ViewController) {
        // nothing to do
    }
    
    func update(context: ViewController) {
        // reset colors
        for (_, plane) in context.planes { plane.setColor(UIColor.planeColor) }
        context.imageTracker?.resetPlaneColors()
        context.attachToImagePlane = nil
        
        let detectionImageNode = context.imageTracker?.hitTestTrackedImage(in: context.sceneView, from: context.sceneView.center)
        if let hit = detectionImageNode {
            print("Detection Image plane hit: \(hit)")
            let imagePlane = hit.node
            imagePlane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColorHover
            context.previewNode?.simdTransform = context.sceneView.anchor(for: imagePlane)!.transform
            context.previewNode?.simdTransform *= float4x4(simd_quatf(angle: -Float.pi / 2, axis: float3(1,0,0)))
            
            // place scribble little bit in front of plane
            var depthCorrection = matrix_identity_float4x4
            depthCorrection.columns.3.z = -0.001
            context.previewNode?.simdTransform *= depthCorrection
            
            if let planeGeometry = imagePlane.geometry as? SCNPlane {
                print("Plane size: \(planeGeometry)")
                let pan = CGPoint(x: context.panFactor.x * planeGeometry.width, y: context.panFactor.y * planeGeometry.height)
                print("Pan: \(pan)")
                context.previewNode?.localTranslate(by: SCNVector3(pan.x, -pan.y, 0))
            }
            context.attachToImagePlane = imagePlane
        }
        else {
            
            let results = context.hitTestFromCenter()
            var target: ARHitTestResult? = nil
            
            // look for first plane detected in results
            // if no planes are detected take the first featurepoint
            for result in results {
                if result.type == ARHitTestResult.ResultType.existingPlaneUsingExtent {
                    target = result
                    break // select closest plane as target
                }
                else if result.type == ARHitTestResult.ResultType.featurePoint {
                    if target == nil { // no plane or closer feature point selected as target
                        target = result
                    }
                }
            }
            
            let distance = results.first?.distance ?? context.defaultDistance
            let transform = context.getTransformInFrontOfCamera(Float(distance))
            
            switch target?.type {
            case ARHitTestResult.ResultType.existingPlaneUsingExtent:
                guard let anchor = target?.anchor as? ARPlaneAnchor else { return }
                
                context.setDebugText("hitting plane")
                context.planes[anchor]?.setColor(UIColor.planeColorHover)
                context.previewNode?.simdTransform = (target?.worldTransform)!
                let rotation = float4x4(simd_quatf(angle: -Float.pi / 2, axis: float3(1, 0, 0)))
                context.previewNode?.simdTransform *= rotation
                
            case ARHitTestResult.ResultType.featurePoint:
                context.setDebugText("hitting feature point  \(distance)m")
                context.previewNode?.simdTransform = transform
                
            default:
                context.setDebugText("hitting nothing \(distance)m")
                context.previewNode?.simdTransform = transform
            }
        }
        
        // scale gesture
        context.previewNode?.scale = SCNVector3(context.scaleFactor, context.scaleFactor, context.scaleFactor)
        
        // rotation gesture
        let rotation = float4x4(simd_quatf(angle: Float(-context.rotation), axis: float3(0, 0, 1)))
        context.previewNode?.simdTransform *= rotation
    }
    
    func handleAddButton(context: ViewController) {
        if let attachedTo = context.attachToImagePlane {
            // attach SCNNode to the Plane associated with the ARImageAnchor
            attachedTo.addChildNode(context.previewNode!)
            
            // previewnode becomes child of attachedTo, instead of rootNode
            // convert transform from one parent to the other
            context.previewNode?.transform = context.sceneView.scene.rootNode.convertTransform(context.previewNode!.transform, to: attachedTo)
        }
        else {
            var anchor: ARAnchor
            if let node = context.previewNode as? TextNode {
                anchor = TextAnchor(textnode: node, transform: context.previewNode!.simdTransform)
            } else {
                // create an ARAnchor at the transform of the previewNode
                // in 'func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)' a node gets associated with this anchor
                anchor = ScribbleAnchor(scribble: context.previewNode!, transform: context.previewNode!.simdTransform)
            }
            context.sceneView.session.add(anchor: anchor)
        }
        context.setState(DrawingState())
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        // nothing to do
    }
    
    
}
