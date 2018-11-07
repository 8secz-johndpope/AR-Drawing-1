import UIKit
import SceneKit
import SpriteKit
import ARKit
import PDColorPicker


extension UIColor {
    static let planeColor = UIColor.green
    static let planeColorHover = UIColor.blue
    static let imagePlaneColor = UIColor.red.withAlphaComponent(0.3)
    static let imagePlaneColorHover = UIColor.blue.withAlphaComponent(0.3)
}


class ViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, Dimmable {

    // Mark: Properties
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var drawingSceneView: SKView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var debugLabel: UILabel!
    @IBOutlet weak var sidebar: UIView!
    @IBOutlet weak var snapShotImage: UIImageView!
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var colorButton: UIButton!
    @IBOutlet weak var brushSizeButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    
    @IBOutlet var pinchGesture: UIPinchGestureRecognizer!
    @IBOutlet var rotationGesture: UIRotationGestureRecognizer!
    
    let defaultDistance = CGFloat(1.0)          // place scribble at ...m when no featurepoints or planes are detected
    
    enum ScribbleState {
        case drawing                            // first user draws a scribble on the screen
        case placing                            // then the scribble gets placed in the AR world
        case editing                            // looking around and selecting scribbles to be edited
    }
    var currentState = ScribbleState.drawing
    
    var planes = [ARPlaneAnchor: Plane]()       // to store auto detected planes
    var previewNode: SCNNode?                   // to preview where the scribble will be placed
    var imagePlanes = [ARImageAnchor: SCNNode]()  // to store planes associated with detected images
    
    var lastScaleFactor: CGFloat = 1.0          // for scale and rotation gestures
    var scaleFactor: CGFloat = 1.0
    var lastRotation: CGFloat = 0.0
    var rotation: CGFloat = 0.0
    
    var brushSizeSlider: UISlider?              // slider to change brush size
    var selected: SCNNode?                      // selected node in editing state
    var drawingScene: DrawingSceneColors?       // drawing scene, shown as transparant overlay
    
    var worldMapURL: URL = {                    // URL to archive ARWorldMap
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("map.arexperience")
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
    }()
    
    var defaultConfiguration: ARWorldTrackingConfiguration {        // Default ARWorldTrackingConfiguration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.detectionImages = self.detectionImages
        configuration.maximumNumberOfTrackedImages = 1
        return configuration
    }
    
    var detectionImages: Set<ARReferenceImage> {                    // Images to detect and track
        guard let images = ARReferenceImage.referenceImages(inGroupNamed: "DetectionImages", bundle: nil) else {
            fatalError("Detection Images could not be loaded")
        }
        return images
    }
    
    var attachToImagePlane: SCNNode?            // to attach scriblle to a tracked detection image plane
    
    //MARK: View Life Cycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        /*      BAD_ACCESS error originates from drawing on the overlaySKScene
         
        let drawingScene = DrawingSceneColors(size: sceneView.frame.size)
        sceneView.overlaySKScene = drawingScene
        
        */
        
        self.drawingScene = DrawingSceneColors(size: sceneView.frame.size)
        drawingSceneView.presentScene(drawingScene)
        
        pinchGesture.delegate = self
        rotationGesture.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = self.defaultConfiguration
        sceneView.session.run(configuration)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setState(ScribbleState.drawing)
    }
    

    
    // MARK: ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // new plane detected
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.addPlane(node: node, anchor: planeAnchor)
        }
        
        // new image detected
        if let imageAnchor = anchor as? ARImageAnchor {
            print("Detection Image detected")
            let size = imageAnchor.referenceImage.physicalSize
            let plane = SCNNode(geometry: SCNPlane(width: size.width, height: size.height))
            plane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColor
            plane.geometry?.firstMaterial?.isDoubleSided = true
            plane.simdTransform *= float4x4(simd_quatf(angle: Float.pi / 2, axis: float3(1,0,0)))
            plane.name = "detection_image_plane"
            plane.renderingOrder = -5
            node.addChildNode(plane)
            self.imagePlanes[imageAnchor] = plane
        }
        
        // new ScribbleAnchor placed
        if let scribbleAnchor = anchor as? ScribbleAnchor {
            print("Scribble ARAnchor placed at: \(anchor.transform)")
            scribbleAnchor.node.simdTransform = matrix_identity_float4x4
            node.addChildNode(scribbleAnchor.node)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // existing plane updated
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.updatePlane(anchor: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // enable Save button only when the mapping status is good and an object has been placed
        if let frame = sceneView.session.currentFrame {
            let enableSaveButton = (frame.worldMappingStatus == .extending || frame.worldMappingStatus == .mapped)
            
            DispatchQueue.main.async {
                self.saveButton.isEnabled = enableSaveButton
            }
        }
        
        // update position of preview node
        if(currentState == ScribbleState.placing && previewNode != nil) {
            for (_, plane) in planes {
                plane.setColor(UIColor.planeColor)
            }
            for(_, plane) in imagePlanes {
                plane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColor
            }
            attachToImagePlane = nil
            
            let detectionImageNode = hitTestDetectionImage()
            if let imagePlane = detectionImageNode {
                setDebugText("Detection Image plane hit")
                imagePlane.geometry?.firstMaterial?.diffuse.contents = UIColor.imagePlaneColorHover
                self.previewNode?.simdTransform = sceneView.anchor(for: imagePlane)!.transform
                self.previewNode?.simdTransform *= float4x4(simd_quatf(angle: -Float.pi / 2, axis: float3(1,0,0)))
                
                var translation = matrix_identity_float4x4
                translation.columns.3.z = -0.001
                
                self.previewNode?.simdTransform *= translation
                
                attachToImagePlane = imagePlane
            }
            else {
            
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
                    self.planes[anchor]?.setColor(UIColor.planeColorHover)
                    self.previewNode?.simdTransform = (target?.worldTransform)!
                    let rotation = float4x4(simd_quatf(angle: -Float.pi / 2, axis: float3(1, 0, 0)))
                    self.previewNode?.simdTransform *= rotation
                    
                case ARHitTestResult.ResultType.featurePoint:
                    setDebugText("hitting feature point  \(distance)m")
                    self.previewNode?.simdTransform = transform
                    
                default:
                    setDebugText("hitting nothing \(distance)m")
                    self.previewNode?.simdTransform = transform
                }
            }
            
            // scale gesture
            self.previewNode?.scale = SCNVector3(self.scaleFactor, self.scaleFactor, self.scaleFactor)
            
            // rotation gesture
            let rotation = float4x4(simd_quatf(angle: Float(-self.rotation), axis: float3(0, 0, 1)))
            self.previewNode?.simdTransform *= rotation
        }
    }
    
    
    
    // MARK: ARSessionObserver
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        print("Session failed with error: \(error.localizedDescription)")
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("Camera tracking state changed: \(camera.trackingState)")
        
        let trackingState = camera.trackingState
        let frame = session.currentFrame!
        
        self.snapShotImage.isHidden = true
        switch (trackingState, frame.worldMappingStatus) {
        case (.limited(.relocalizing), _):
            print("Move device to position shown in image")
            self.snapShotImage.isHidden = false
        default:
            print("")
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        print("Session was interupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        print("Session interruption ended")
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        // Attempt relocalization after session interuption
        return true
    }
    
    
    
    //MARK: Functions
    
    private func hitTestFromCenter() -> [ARHitTestResult] {
        let results = sceneView.hitTest(sceneView.center, types: [.existingPlaneUsingExtent, .featurePoint])
        return results
    }
    
    private func hitTestDetectionImage() -> SCNNode? {
        let results = sceneView.hitTest(sceneView.center, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        let imagePlanes = results.filter { $0.node.name == "detection_image_plane" }
        print("image planes hit: \(imagePlanes.count)")
        if let plane = imagePlanes.first?.node {
            return plane
        }
        return nil
    }

    private func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        let plane = Plane(anchor, in: sceneView)
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
        node.name = "scribble"
        sceneView.scene.rootNode.addChildNode(node)
        previewNode = node
    }
    
    private func setState(_ state: ScribbleState) {
        if(state == ScribbleState.drawing) {
            setInfoText("Draw something on the screen, press + when you're done")
            self.drawingSceneView?.isHidden = false
            self.drawingSceneView?.isUserInteractionEnabled = true
            self.drawingScene?.isEnabled = true
            
            currentState = ScribbleState.drawing
            debugLabel.isHidden = true
            pinchGesture.isEnabled = false
            rotationGesture.isEnabled = false
            
            self.deleteButton.isHidden = true
            
            toggleSideBar(visible: true)
        }
        else if(state == ScribbleState.placing) {
            setInfoText("Tap the screen to place your scribble in the world")
            self.drawingSceneView?.isHidden = true
            self.drawingSceneView?.isUserInteractionEnabled = false
            self.drawingScene?.isEnabled = false
            self.drawingScene?.clear()
        
            currentState = ScribbleState.placing
            debugLabel.isHidden = false
            pinchGesture.isEnabled = true
            rotationGesture.isEnabled = true
            self.scaleFactor = 1.0
            self.rotation = 0.0
            
            self.deleteButton.isHidden = false
            
            toggleSideBar(visible: false)
        }
        else if(state == ScribbleState.editing) {
            setInfoText("Tap on a scribble to move or delete")
            self.drawingSceneView?.isHidden = true
            self.drawingSceneView?.isUserInteractionEnabled = false
            self.drawingScene?.isEnabled = false
            
            currentState = ScribbleState.editing
            debugLabel.isHidden = true
            
            self.deleteButton.isHidden = true
            
            toggleSideBar(visible: false)
        }
    }
    
    private func toggleBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        
        let hidden = slider.isHidden
        
        if hidden == true {
            showBrushSizeSlider()
        } else {
            hideBrushSizeSlider()
        }
        //UIView.transition(with: slider, duration: 0.5, options: .transitionCrossDissolve, animations: {slider.isHidden})
    }
    
    private func hideBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        UIView.animate(withDuration: 0.3, animations: { slider.alpha = 0 }, completion: { (finished) in slider.isHidden = finished })
    }
    
    private func showBrushSizeSlider() {
        guard let slider = brushSizeSlider else { return }
        slider.alpha = 0
        slider.isHidden = false
        UIView.animate(withDuration: 0.3, animations: { slider.alpha = 1 })
    }
    
    private func resizeBrushSizeSliderImage() {
        let ratio = CGFloat((self.brushSizeSlider?.value ?? 5.0) + 10.0)
        let thumbImage = UIImage(named: "black-dot")!
        let size = CGSize(width: ratio, height: ratio)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .normal)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .highlighted)
    }
    
    private func toggleSideBar(visible: Bool) {
        if visible == false {
            //sidebar.isHidden = true
            hideBrushSizeSlider()
            UIView.animate(withDuration: 0.3, animations: {
                self.sidebar.transform = CGAffineTransform(translationX: -self.sidebar.frame.width, y: 0)
            }, completion: { (finished) in
                self.sidebar.isHidden = true
            })
        } else {
            self.sidebar.isHidden = false
            UIView.animate(withDuration: 0.3, animations: {
                self.sidebar.transform = .identity
            })
        }
    }
    
    
    
    //MARK: Actions
    
    @IBAction func clickedAddButton(_ sender: UIButton) {
        if(currentState == ScribbleState.drawing) {
            // make preview node from screen scribble
            if let drawingScene = self.drawingScene {
                if drawingScene.isEmpty() {
                    print("Emty scene, draw something on screen first")
                    return
                }
                
                let heightToWidthRatio = view.frame.size.height / view.frame.size.width
                let width: CGFloat = 0.30   // 30 cm wide
                let height = width * heightToWidthRatio
                let plane = SCNPlane(width: width, height: height)
                
                let image = self.drawingScene?.getSnapShot()
                plane.firstMaterial?.diffuse.contents = image
                plane.firstMaterial?.isDoubleSided = true
                plane.firstMaterial?.emission.contents = UIColor.black
                plane.firstMaterial?.transparencyMode = .aOne
                let node = SCNNode(geometry: plane)
                
                makePreviewNode(node)
                setState(ScribbleState.placing)
            }
        }
        else if(currentState == ScribbleState.placing) {
            if let attachedTo = attachToImagePlane {
                // attach SCNNode to the Plane associated with the ARImageAnchor
                attachedTo.addChildNode(previewNode!)
                
                // transform here is relative to parent, transform of the preview node is relative to the world
                previewNode?.simdTransform = matrix_identity_float4x4
                previewNode?.simdTransform *= float4x4(simd_quatf(angle: Float.pi, axis: float3(1,0,0)))
                previewNode?.scale = SCNVector3(self.scaleFactor, self.scaleFactor, self.scaleFactor)
                previewNode?.simdTransform *= float4x4(simd_quatf(angle: Float(-self.rotation), axis: float3(0,0,1)))
            }
            else {
                // create an ARAnchor at the transform of the previewNode
                // in 'func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)' a node gets associated with this anchor
                let anchor = ScribbleAnchor(scribble: previewNode!, transform: previewNode!.simdTransform)
                sceneView.session.add(anchor: anchor)
            }
            setState(ScribbleState.drawing)
        }
        else if(currentState == ScribbleState.editing) {
            setState(ScribbleState.drawing)
        }
    }
    
    @IBAction func clickedColorButton(_ sender: UIButton) {
        guard let initColor = drawingScene?.lineColor else { return }
        hideBrushSizeSlider()
        let picker = PDColorPickerViewController(initialColor: initColor, tintColor: .black)
        picker.completion = {
            [weak self] newColor in
            
            self?.undim()
            
            guard let color = newColor else {
                print("cancel color selection")
                return
            }
            
            
            self!.drawingScene?.lineColor = color.uiColor
            print("color selected: \(String(describing: color))")
        }
        
        dim()
        
        present(picker, animated: true)
    }
    
    
    @IBAction func clickedBrushSizeButton(_ sender: UIButton) {
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
            slider.value = Float((self.drawingScene?.lineWidth)!)
            
            // vertical slider
            slider.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
            
            self.view.addSubview(slider)
            self.brushSizeSlider = slider
            
            resizeBrushSizeSliderImage()
        }
        
        toggleBrushSizeSlider()
    }    
    
    @objc func brushSliderValueChanged(_ sender: UISlider) {
        resizeBrushSizeSliderImage()
        self.drawingScene?.lineWidth = CGFloat(sender.value)
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
    
    @IBAction func clickedUndoButton(_ sender: UIButton) {
        self.drawingScene?.removeLastNode()
    }
    
    @IBAction func clickedEditButton(_ sender: UIButton) {
        if(currentState == ScribbleState.editing) {
            setState(ScribbleState.drawing)
        }
        else {
            setState(ScribbleState.editing)
        }
    }
    
    @IBAction func clickedDeleteButton(_ sender: UIButton) {
        if(currentState == ScribbleState.placing) {
            previewNode?.removeFromParentNode()
            setState(ScribbleState.drawing)
        }
    }
    
    // Persisitence
    
    func saveWorldMap(_ worldMap: ARWorldMap, to url: URL) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: url, options: [.atomic])
    }
    
    func loadWorldMap(from url: URL) throws -> ARWorldMap {
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw ARError(.invalidWorldMap)
        }
        return worldMap
    }
    
    @IBAction func clickedSaveButton(_ sender: UIButton) {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let map = worldMap else {
                print("Cannot get current world map \(error!.localizedDescription)")
                return
            }
            
            // add snapshot image to the worldmap
            guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView) else {
                fatalError("Can't take snapshot")
            }
            map.anchors.append(snapshotAnchor)
            
            do {
                try self.saveWorldMap(map, to: self.worldMapURL)
                DispatchQueue.main.async {
                    self.loadButton.isHidden = false
                    self.loadButton.isEnabled = true
                    print("world map is saved")
                }
                for anchor in map.anchors {
                    print(anchor)
                }
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func clickedLoadButton(_ sender: UIButton) {
        // load worldmap
        let worldMap: ARWorldMap = {
            do {
                return try self.loadWorldMap(from: self.worldMapURL)
            } catch {
                fatalError("Can't unarchive ARWorldMap from file data: \(error)")
            }
        }()
        
        // display SnapShotImage
        if let snapshotData = worldMap.snapshotAnchor?.imageData, let snapshot = UIImage(data: snapshotData) {
            self.snapShotImage.image = snapshot
            print("Move device to the location shown in the image")
        } else {
            print("No snapshot image stored with worldmap!")
        }
        
        // remove snapshot from worldmap, not needed in scene
        worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })
        
        // set configuration with initialWorldMap
        let configuration = self.defaultConfiguration
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    
    // Gestures
    
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
    
    @IBAction func handleTapGesture(_ sender: UITapGestureRecognizer) {
        if(currentState == ScribbleState.editing) {
            let location = sender.location(in: sceneView)
            let hits = sceneView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            
            let scribbleNodes = hits.filter { $0.node.name == "scribble" }
            
            if !scribbleNodes.isEmpty {
                print("Tap detected: \(hits.count) scribbles hit")
                
                if let node = scribbleNodes.first?.node {
                    // Make a new preview node from selected node
                    let copy = node.copy() as! SCNNode
                    makePreviewNode(copy)
                    
                    // remove selected node along with its anchor
                    // the new node gets it anchor after replacement
                    if let anchorForNode = sceneView.anchor(for: node) {
                        sceneView.session.remove(anchor: anchorForNode)
                    }
                    
                    if node.parent?.name == "detection_image_plane" {
                        node.removeFromParentNode()
                    }
                    setState(ScribbleState.placing)
                }
            }
        }
    }
    
    // Simultaneous recognition for rotation and scale gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
            (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
    }
}
