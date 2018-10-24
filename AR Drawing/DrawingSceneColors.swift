
import UIKit
import SpriteKit
import ARKit

class DrawingSceneColors: SKScene {
    
    //MARK: Properties
    
    var lineColor: UIColor = UIColor.red
    var lineWidth: CGFloat = 5.0
    
    private var paths = [CGMutablePath]()
    private var previewNodes = [SKShapeNode]()
    
    private var currentNode = SKShapeNode()
    private var currentPath = CGMutablePath()
    
    var isEnabled = true
    
    func initialize() {
        backgroundColor = UIColor.clear
    }
    
    // Creates node with current color and width settings
    func createNode() -> SKShapeNode {
        let node = SKShapeNode()
        node.lineWidth = lineWidth
        node.strokeColor = lineColor
        node.path = CGMutablePath()
        
        return node
    }
    
    func clear() {
        for node in previewNodes {
            node.removeFromParent()
        }
        previewNodes.removeAll()
    }
    
    func isEmpty() -> Bool {
        return previewNodes.count < 1
    }
    
    
    //MARK: Touch Methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        guard let touch = touches.first else { return }
        var location = touch.location(in: self.view)
        location = convertPoint(fromView: location)
        
        previewNodes.append(createNode())
        currentNode = previewNodes.last!
        currentPath = previewNodes.last!.path as! CGMutablePath
        
        currentNode.path = currentPath
        currentPath.move(to: location)
        
        addChild(currentNode)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        guard let touch = touches.first else { return }
        var location = touch.location(in: self.view)
        location = convertPoint(fromView: location)
        
        currentPath.addLine(to: location)
        currentNode.path = currentPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        
    }
}
