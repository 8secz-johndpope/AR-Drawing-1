import UIKit
import SceneKit
import ARKit
import AudioToolbox

class CameraState: State {
    
    var featurePointsVisible: Bool?
    var planesVisible: Bool?
    
    func onEnterState(context: ViewController) {
        context.setInfoText("Take a picture using by pressing the add button")
        context.drawingSceneView?.isHidden = true
        context.drawingSceneView?.isUserInteractionEnabled = false
        context.drawingScene?.isEnabled = false
        context.debugLabel.isHidden = true
        context.setGestureDetectorsEnabled(false)
        context.deleteButton.isHidden = true
        context.previewNode = nil
        context.toggleSideBar(visible: false)
        
         featurePointsVisible = context.sceneView.debugOptions.contains(ARSCNDebugOptions.showFeaturePoints)
         planesVisible = !context.hidePlanes
        
        context.setPlanesVisible(false)
        context.setFeaturePointsVisible(false)
        context.setObjectsVisible(false)
    }
    
    func onExitState(context: ViewController) {
        print("exit camera state")
        context.setPlanesVisible(planesVisible!)
        context.setFeaturePointsVisible(featurePointsVisible!)
        context.setObjectsVisible(true)
    }
    
    func update(context: ViewController) {
        // nothing to do
    }
    
    func handleAddButton(context: ViewController) {
        // make preview node from screenshot
        
        let image = context.sceneView.snapshot()
        
        let heightToWidthRatio = context.view.frame.size.height / context.view.frame.size.width
        let width: CGFloat = 0.30   // 30 cm wide
        let height = width * heightToWidthRatio
        
        let node = ImageNode(image: image, size: CGSize(width: width, height: height))
        
        // play camera shutter sound
        AudioServicesPlaySystemSound(1108)
        
        context.makePreviewNode(node)
        context.setState(PlacingState())
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        // nothing to do
    }
    
    
}
