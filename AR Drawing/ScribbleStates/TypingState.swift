import SceneKit

class TypingState: State {
    
    func onEnterState(context: ViewController) {
        context.setInfoText("Type some text to add to the scene")
        context.drawingSceneView?.isHidden = true
        context.drawingSceneView?.isUserInteractionEnabled = false
        context.drawingScene?.isEnabled = false
        context.debugLabel.isHidden = false
        context.setGestureDetectorsEnabled(false)
        context.toggleSideBar(visible: false)
    }
    
    func onExitState(context: ViewController) {
        // nothing to do
    }
    
    func update(context: ViewController) {
        context.previewNode?.simdTransform = context.getTransformInFrontOfCamera(Float(context.defaultDistance))
        context.previewNode?.localTranslate(by: SCNVector3(0, 0.1, 0))
    }
    
    func handleAddButton(context: ViewController) {
        // nothing to do
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        // nothing to do
    }
    
    
}
