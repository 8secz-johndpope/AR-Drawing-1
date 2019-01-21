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
                
                
                if anchor.alignment == ARPlaneAnchor.Alignment.horizontal {
                    // horizontal planes
                    
                    context.previewNode?.simdTransform = transform
                    if context.sceneView.pointOfView!.eulerAngles.x <= 0 {
                        context.previewNode?.eulerAngles.x = -Float.pi / 2
                        context.previewNode?.eulerAngles.z = 0
                    }
                    else {
                        context.previewNode?.eulerAngles.x = Float.pi / 2
                        context.previewNode?.eulerAngles.z = Float.pi
                    }
                    
                    // bug correction
                    if context.sceneView.pointOfView!.eulerAngles.z == 0 {
                        let rotation = float4x4(simd_quatf(angle: Float.pi, axis: float3(0, 0 , 1)))
                        context.previewNode?.simdTransform *= rotation
                        print("correcting")
                    }
                    
                    
                    print("previewNode: ", context.previewNode?.eulerAngles)
                    print("pointOfView: ", context.sceneView.pointOfView!.eulerAngles)
                    print("plane: ", context.planes[anchor]!.eulerAngles)
                
                } else {
                    // Vertical planes
                    context.previewNode?.simdTransform = target!.worldTransform
                    
                    let rotation = float4x4(simd_quatf(angle: -Float.pi / 2, axis: float3(1, 0, 0)))
                    context.previewNode?.simdTransform *= rotation
                }
            
                /*
                 R=atan2(m12, m22)
                 c2 = sqrt(m00^2 + m01^2)
                 P = atan2(-m02, c2)
                 s1 = sin(R), c1 = cos(R)
                 Y = atan2(s1*m20 - c1*m10, c1*m11-s1*m21)
                 */
                
                /*
                let roll: Double = Double(atan2(anchor.transform.columns.2.y, anchor.transform.columns.2.z))
                let c2: Double = Double(sqrt(anchor.transform.columns.0.x * anchor.transform.columns.0.x + anchor.transform.columns.1.x * anchor.transform.columns.1.x))
                let pitch = atan2(Double(-anchor.transform.columns.2.x), c2)
                let s1: Double = sin(roll)
                let c1: Double = cos(roll)
                let yaw = atan2(s1 * anchor.transform.columns.0.z - c1 * anchor.transform.columns.0.y, c1 * anchor.transform.columns.1.y - s1 * anchor.transform.columns.1.z)
                */
                
                //let rotation2 = float4x4(simd_quatf(angle: povAngle - planeAngle, axis: float3(0, 0, 1)))
                //context.previewNode?.simdTransform *= rotation2
                
                
                
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
            /*if let node = context.previewNode as? TextNode {
                anchor = TextAnchor(textnode: node, transform: context.previewNode!.simdTransform)
            } else {
                // create an ARAnchor at the transform of the previewNode
                // in 'func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)' a node gets associated with this anchor
                anchor = ScribbleAnchor(scribble: context.previewNode!, transform: context.previewNode!.simdTransform)
            }*/
            if let node = context.previewNode {
                anchor = NodeAnchor(node: node, step: context.currentStep, transform: node.simdTransform)
                context.sceneView.session.add(anchor: anchor)
            }
        }
        context.setState(DrawingState())
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        // nothing to do
    }
    
    
}
