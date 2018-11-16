import UIKit
import SceneKit

class DrawingState: State {
    
    func onEnterState(context: ViewController) {
        context.setInfoText("Draw something on the screen, press + when you're done")
        context.drawingSceneView?.isHidden = false
        context.drawingSceneView?.isUserInteractionEnabled = true
        context.drawingScene?.isEnabled = true
        context.debugLabel.isHidden = true
        context.setGestureDetectorsEnabled(false)
        context.deleteButton.isHidden = true
        context.previewNode = nil
        context.toggleSideBar(visible: true)
    }
    
    func onExitState(context: ViewController) {
        // nothing to do
    }
    
    func update(context: ViewController) {
        // nothing to do
    }
    
    func handleAddButton(context: ViewController) {
        // make preview node from screen scribble
        if let drawingScene = context.drawingScene {
            if drawingScene.isEmpty() {
                print("Emty scene, draw something on screen first")
                return
            }
            
            let heightToWidthRatio = context.view.frame.size.height / context.view.frame.size.width
            let width: CGFloat = 0.30   // 30 cm wide
            let height = width * heightToWidthRatio
            let plane = SCNPlane(width: width, height: height)
            
            let image = context.drawingScene?.getSnapShot()
            plane.firstMaterial?.diffuse.contents = image
            plane.firstMaterial?.isDoubleSided = true
            plane.firstMaterial?.emission.contents = UIColor.black
            plane.firstMaterial?.transparencyMode = .aOne
            let node = SCNNode(geometry: plane)
            node.name = "scribble"
            
            context.makePreviewNode(node)
            context.setState(PlacingState())
        }
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        // nothing to do
    }
    
    
}
