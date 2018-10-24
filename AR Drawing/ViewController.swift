import UIKit
import SceneKit
import SpriteKit
import ARKit
import PDColorPicker

class ViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, Dimmable {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var debugLabel: UILabel!
    @IBOutlet var pinchGesture: UIPinchGestureRecognizer!
    @IBOutlet var rotationGesture: UIRotationGestureRecognizer!
    
    @IBOutlet weak var colorBtn: UIButton!
    @IBOutlet weak var brushSizeButton: UIButton!
    
    
    let defaultDistance = CGFloat(1.0)      // place scribble at ...m when no featurepoints or planes are detected
    
    enum ScribbleState {
        case drawing                        // first user draws a scribble on the screen
        case placing                        // then the scribble gets placed in the AR world
    }
    var currentState = ScribbleState.drawing
    
    var planes = [ARPlaneAnchor: Plane]()
    var previewNode: SCNNode?
    var scribbles = [SCNNode]()
    
    var lastScaleFactor: CGFloat = 1.0
    var scaleFactor: CGFloat = 1.0
    var lastRotation: CGFloat = 0.0
    var rotation: CGFloat = 0.0
    
    var brushSizeSlider: UISlider?
    
    
    //MARK: View Life Cycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        //sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Set the drawing scene as the overlaying scene
        let drawingScene = DrawingSceneColors(fileNamed: "DrawingScene")
        drawingScene?.initialize()
        sceneView.overlaySKScene = drawingScene
        
        pinchGesture.delegate = self
        rotationGesture.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    override func viewDidAppear(_ animated: Bool) {
        setState(ScribbleState.drawing)
        // preview screen
        /*
        let heightToWidthRatio = view.frame.height / view.frame.width
        let width: CGFloat = 0.30   // 30 cm wide
        let height = width * heightToWidthRatio
        
        
        let previewScene = DrawingScene(size: CGSize(width: view.frame.width, height: view.frame.height))
        previewScene.makeExamplePath()
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = previewScene
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.blendMode = .alpha
        previewNode = SCNNode(geometry: plane)
        
        guard let node = previewNode else { return }
        sceneView.scene.rootNode.addChildNode(node)
        */
    }
    

    
    
    // MARK: - ARSCNViewDelegate
    
    /* Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
     */
    
    /// - Tag: PlaceARContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // new plane detected
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.addPlane(node: node, anchor: planeAnchor)
        }
    }
    
    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // existing plane update
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.updatePlane(anchor: planeAnchor)
        }
    }
    
    /// - TAG: UpdateFrame
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if(currentState == ScribbleState.placing && previewNode != nil) {
            
            for (_, plane) in planes {
                plane.setColor(UIColor.green)
            }
            
            let results = hitTestFromCenter()
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
            
            let distance = results.first?.distance ?? defaultDistance
            let transform = getTransformInFrontOfCamera(Float(distance))
            
            switch target?.type {
            case ARHitTestResult.ResultType.existingPlaneUsingExtent:
                guard let anchor = target?.anchor as? ARPlaneAnchor else { return }
                
                setDebugText("hitting plane")
                self.planes[anchor]?.setColor(UIColor.blue)
                self.previewNode?.simdTransform = (target?.worldTransform)!
                let rotation = float4x4(simd_quatf(angle: Float.pi / 2, axis: float3(1, 0, 0)))
                self.previewNode?.simdTransform *= rotation
            
                // print(anchor.transform)
                //let a = getRotation(anchor.transform).x
                //let b = Float((sceneView.pointOfView?.eulerAngles.y)!)
                
                //self.rotation = CGFloat(-a)
                
            case ARHitTestResult.ResultType.featurePoint:
                setDebugText("hitting feature point  \(distance)m")
                
                self.previewNode?.simdTransform = transform
                
            default:
                setDebugText("hitting nothing \(distance)m")
                
                self.previewNode?.simdTransform = transform
            }
            
            self.previewNode?.scale = SCNVector3(self.scaleFactor, self.scaleFactor, self.scaleFactor)
            
            let rotation = float4x4(simd_quatf(angle: Float(self.rotation), axis: float3(0, 0, 1)))
            self.previewNode?.simdTransform *= rotation
            
            
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    
    
    
    //MARK: Private Functions
    
    private func getRotation(_ matrix: simd_float4x4) -> float3 {
        var yaw, pitch, roll: Float
        if matrix.columns.0.x == 1.0 {
            yaw = atan2f(matrix.columns.2.x , matrix.columns.3.z)
            pitch = 0.0
            roll = 0.0
        }
        else if matrix.columns.0.x == -1.0 {
            yaw = atan2f(matrix.columns.2.x, matrix.columns.3.y)
            pitch = 0.0
            roll = 0.0
        }
        else {
            yaw = atan2f(-matrix.columns.0.z, matrix.columns.0.x)
            pitch = asin(matrix.columns.0.y)
            roll = atan2f(-matrix.columns.2.y, matrix.columns.1.y)
        }
        return float3(yaw, pitch, roll)
    }
    
    private func hitTestFromCenter() -> [ARHitTestResult] {
        let results = sceneView.hitTest(sceneView.center, types: [.existingPlaneUsingExtent, .featurePoint])
        return results
    }
    
    private func clearWorld() {
        for scribble in scribbles {
            scribble.removeFromParentNode()
        }
    }

    private func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        let plane = Plane(anchor)
        node.addChildNode(plane)
        planes[anchor] = plane
        print(planes)
    }
    
    private func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    private func getTransformInFrontOfCamera(_ distance: Float) -> simd_float4x4 {
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -distance
        
        let camTransform = sceneView.pointOfView?.simdTransform
        var transform = simd_mul(camTransform!, translation)
        
        let rotation = float4x4(simd_quatf(angle: Float.pi, axis: float3(1, 0, 0)))
        transform *= rotation
        
        return transform
    }
    
    private func setInfoText(_ text: String) {
        DispatchQueue.main.async {
            self.infoLabel.text = text
        }
    }
    
    private func setDebugText(_ text: String) {
        DispatchQueue.main.async {
            self.debugLabel.text = text
        }
    }
    
    private func makePreviewNode(_ node: SCNNode) {
        node.geometry?.firstMaterial?.readsFromDepthBuffer = false // always visible
        node.renderingOrder = -10    // always on top
        sceneView.scene.rootNode.addChildNode(node)
        previewNode = node
    }
    
    func setState(_ state: ScribbleState) {
        if(state == ScribbleState.drawing) {
            if let drawingScene = sceneView.overlaySKScene as? DrawingSceneColors {
                drawingScene.isEnabled = true
            }
            setInfoText("Draw something on the screen, press + when you're done")
            currentState = ScribbleState.drawing
            debugLabel.isHidden = true
            pinchGesture.isEnabled = false
        }
        else if(state == ScribbleState.placing) {
            if let drawingScene = sceneView.overlaySKScene as? DrawingSceneColors {
                currentState = ScribbleState.placing
                drawingScene.isEnabled = false
                drawingScene.clear()
            }
            setInfoText("Tap the screen to place your scribble in the world")
            currentState = ScribbleState.placing
            debugLabel.isHidden = false
            pinchGesture.isEnabled = true
            self.scaleFactor = 1.0
            self.rotation = 0.0
        }
    }
    
    func toggleBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        
        let hidden = slider.isHidden
        
        if hidden == true {
            showBrushSizeSlider()
        } else {
            hideBrushSizeSlider()
        }
        //UIView.transition(with: slider, duration: 0.5, options: .transitionCrossDissolve, animations: {slider.isHidden})
    }
    
    func hideBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        UIView.animate(withDuration: 0.3, animations: { slider.alpha = 0 }, completion: { (finished) in slider.isHidden = finished })
    }
    
    func showBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        slider.alpha = 0
        slider.isHidden = false
        UIView.animate(withDuration: 0.3, animations: { slider.alpha = 1 })
    }
    
    //MARK: Actions
    
    @IBAction func btnPressed(_ sender: UIButton) {
        
        if(currentState == ScribbleState.drawing) {
            // make preview node from screen scribble
            if let drawingScene = sceneView.overlaySKScene as? DrawingSceneColors {
                if drawingScene.isEmpty() {
                    print("Emty scene, draw something on screen first")
                    return
                }
                
                /*  attempt at doing it with SCNShape
 
                let path = UIBezierPath(cgPath: drawingScene.path)
                let shape = SCNShape(path: path, extrusionDepth: 0.5)
                let node = SCNNode(geometry: shape)
                node.scale = SCNVector3(0.1, 0.1, 0.1)
                node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                node.geometry?.firstMaterial?.isDoubleSided = true
                
                */
                
                let heightToWidthRatio = view.frame.size.height / view.frame.size.width
                let width: CGFloat = 0.30   // 30 cm wide
                let height = width * heightToWidthRatio
                let plane = SCNPlane(width: width, height: height)
                
                // copy is necessary
                let scene = sceneView.overlaySKScene?.copy() as! SKScene
                plane.firstMaterial?.diffuse.contents = scene
                plane.firstMaterial?.isDoubleSided = true
                plane.firstMaterial?.emission.contents = UIColor.black
                plane.firstMaterial?.transparencyMode = .aOne
                let node = SCNNode(geometry: plane)
                
                makePreviewNode(node)
                setState(ScribbleState.placing)
            }
        }
        else if(currentState == ScribbleState.placing) {
            // place the scribble at the current location of the previewNode
            // calculating where to put the scribble gets done in the renderer(_:updatedAtTime:) function
            print("scribble placed")
            if let preview = previewNode {
                scribbles.append(preview)
                print("# scribbles in world: \(scribbles.count)")
                print(scribbles)
            }

            setState(ScribbleState.drawing)
        }
    }
    
    
    @IBAction func hitTestBtnPressed(_ sender: UIButton) {
        let results = hitTestFromCenter()
        
        print("Hit test found \(results.count) results")
        for result in results {
            print("\(result.distance)m away from camera")
            print(result)
        }
        print("-------------")
    }
    
    @IBAction func clearBtnPressed(_ sender: UIButton) {
        print("Clear btn pressed")
        clearWorld()
    }
    
    
    @IBAction func handePinchGesture(_ sender: UIPinchGestureRecognizer) {
        if(sender.state == .began || sender.state == .changed) {
            self.scaleFactor = self.lastScaleFactor * sender.scale
        }
        else if(sender.state == .ended) {
            self.lastScaleFactor = self.scaleFactor
        }
    }
    
    
    @IBAction func handleRotationGesture(_ sender: UIRotationGestureRecognizer) {
        if(sender.state == .began || sender.state == .changed) {
            self.rotation = self.lastRotation + sender.rotation
        }
        else if(sender.state == .ended) {
            self.lastRotation = self.rotation
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
        (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
    }
    
    @IBAction func clickedColorButton(_ sender: UIButton) {
        print("select color")
        hideBrushSizeSlider()
        
        let picker = PDColorPickerViewController(initialColor: .red, tintColor: .black)
        picker.completion = {
            [weak self] newColor in
            
            self?.undim()
            
            guard let color = newColor else {
                print("cancel color selection")
                return
            }
            
            if let drawingScene = self!.sceneView.overlaySKScene as? DrawingSceneColors {
                drawingScene.lineColor = color.uiColor
                print("color selected: \(String(describing: color))")
            }
        }
        
        dim()
        
        present(picker, animated: true)
    }
    
    
    @IBAction func clickedBrushSizeButton(_ sender: UIButton) {
        print("brush size button clicked")
        
        
        if(brushSizeSlider == nil) {
            // instantiatie new slider
            let btnRect = sender.convert(sender.bounds, to: self.view)
            let slider = UISlider(frame: CGRect(x: btnRect.origin.x, y: btnRect.midY, width: 300, height: 20))
            slider.minimumValue = 2
            slider.maximumValue = 50
            slider.isContinuous = true
            slider.tintColor = UIColor.darkGray
            slider.addTarget(self, action: #selector(ViewController.brushSliderValueChanged(_:)), for: .valueChanged)
            slider.thumbTintColor = UIColor.black
            slider.isHidden = true
            
            slider.value = Float(((self.sceneView.overlaySKScene as? DrawingSceneColors)?.lineWidth)!)
            
            slider.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
            
            self.view.addSubview(slider)
            self.brushSizeSlider = slider
            
            toggleBrushSizeSlider()
        }
        else {
            toggleBrushSizeSlider()
        }
    }
    
    
    @objc func brushSliderValueChanged(_ sender: UISlider) {
        print("slider value changed: \(sender.value)")
        
        let ratio = CGFloat(sender.value + 10)
        let thumbImage = UIImage(named: "black-dot")!
        let size = CGSize(width: ratio, height: ratio)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .normal)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .highlighted)
        
        
        if let drawingScene = self.sceneView.overlaySKScene as? DrawingSceneColors {
            drawingScene.lineWidth = CGFloat(sender.value)
        }
    }
    
    func ResizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
