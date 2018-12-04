
import UIKit
import SpriteKit
import ARKit

class DrawingSceneColors: SKScene {
    
    //MARK: Properties
    
    var lineColor: UIColor = UIColor.red {
        didSet {
            previewNode.strokeColor = lineColor
        }
    }
    
    var lineWidth: CGFloat = 5.0 {
        didSet {
            previewNode.lineWidth = lineWidth
        }
    }
    
    private var paths = [CGMutablePath]()
    private var previewNodes = [SKShapeNode]()
    
    private var previewNode: SKShapeNode
    private var previewPath: CGMutablePath
    
    var isEnabled = true
    
    var nodeCount: Int {
        get {
            return self.previewNodes.count
        }
    }

    
    override init(size: CGSize) {
        previewPath = CGMutablePath.init()
        previewNode = SKShapeNode.init()
        
        super.init(size: size)
        
        backgroundColor = .clear
        addChild(previewNode)
        previewNode.strokeColor = lineColor
        previewNode.lineWidth = lineWidth
        previewNode.zPosition = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        previewPath = CGMutablePath.init()
        previewNode = SKShapeNode.init()
        
        super.init(coder: aDecoder)
        
        backgroundColor = .clear
        addChild(previewNode)
        previewNode.strokeColor = lineColor
        previewNode.lineWidth = lineWidth
        previewNode.zPosition = 1
    }
    
    
    
    
    // Creates node with current color and width settings
    func createNode() -> SKShapeNode {
        let node = SKShapeNode()
        node.lineWidth = lineWidth
        node.strokeColor = lineColor
        node.path = CGMutablePath.init()
        
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
    
    func removeLastNode() {
        if(previewNodes.count > 0) {
            previewNodes.last?.removeFromParent()
            previewNodes.removeLast()
        }
    }
    
    func getSnapShot() -> UIImage {
        UIGraphicsBeginImageContext(self.view!.bounds.size)
        self.view!.drawHierarchy(in: self.view!.bounds, afterScreenUpdates: true)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    //MARK: Touch Methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        guard let touch = touches.first else { return }
        var location = touch.location(in: self.view)
        location = convertPoint(fromView: location)
        
        previewPath = CGMutablePath.init()
        previewPath.move(to: location)
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        guard let touch = touches.first else { return }
        var location = touch.location(in: self.view)
        location = convertPoint(fromView: location)
        
        // adding to path:
        previewPath.addLine(to: location)
        previewNode.path = previewPath.copy()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isEnabled == false { return }
        
        let node = previewNode.copy() as! SKShapeNode
        previewNodes.append(node)
        addChild(node)
        node.zPosition = 0
        
        previewNode.path = nil
    }
    
    
}
