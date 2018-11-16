import UIKit
import SceneKit

class EditingState: State {
    
    func onEnterState(context: ViewController) {
        context.setInfoText("Tap on a scribble to move or delete")
        context.drawingSceneView?.isHidden = true
        context.drawingSceneView?.isUserInteractionEnabled = false
        context.drawingScene?.isEnabled = false
        context.debugLabel.isHidden = true
        context.setGestureDetectorsEnabled(false)
        context.deleteButton.isHidden = true
        context.toggleSideBar(visible: false)
    }
    
    func onExitState(context: ViewController) {
        // nothing to do
    }
    
    func update(context: ViewController) {
        // nothing to do
    }
    
    func handleAddButton(context: ViewController) {
        context.setState(DrawingState())
    }
    
    func handleTap(context: ViewController, sender: UITapGestureRecognizer) {
        let location = sender.location(in: context.sceneView)
        let hits = context.sceneView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        
        for hit in hits {
            print(hit)
            if let text = (hit.node.geometry as? SCNText)?.string as? String,
                let color = (hit.node.geometry?.firstMaterial?.diffuse.contents) as? UIColor {
                let copy = TextNode(text: text, color: color)
                context.makePreviewNode(copy)
                hit.node.removeFromParentNode()
                context.setState(PlacingState())
            }
        }
        
        let nodes = hits.filter { $0.node.name == "scribble" || $0.node.name == "text" || $0.node.name == "image" }
        
        if !nodes.isEmpty {
            print("Tap detected: \(nodes.count) nodes hit")
            
            if let node = nodes.first?.node {
                // Make a new preview node from selected node
                let copy = node.copy() as! SCNNode
                context.makePreviewNode(copy)
                
                node.removeFromParentNode()
                
                context.setState(PlacingState())
            }
        }
    }
    
    
}
