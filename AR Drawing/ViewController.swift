import UIKit
import SceneKit
import SpriteKit
import ARKit
import PDColorPicker


extension UIColor {
    static let planeColor = UIColor.green.withAlphaComponent(0.2)
    static let planeColorHover = UIColor.blue.withAlphaComponent(0.2)
    static let imagePlaneColor = UIColor.red.withAlphaComponent(0.3)
    static let imagePlaneColorHover = UIColor.blue.withAlphaComponent(0.3)
}


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ARSCNViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, Dimmable {

    // Mark: Properties
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var drawingSceneView: SKView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var debugLabel: UILabel!
    @IBOutlet weak var sidebar: UIView!
    @IBOutlet weak var snapShotImage: UIImageView!
    @IBOutlet weak var hiddenTextField: UITextField!
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var colorButton: UIButton!
    @IBOutlet weak var brushSizeButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    
    
    @IBOutlet var pinchGesture: UIPinchGestureRecognizer!
    @IBOutlet var rotationGesture: UIRotationGestureRecognizer!
    @IBOutlet var panGesture: UIPanGestureRecognizer!
    
    let defaultDistance = CGFloat(1.0)          // place scribble at ...m when no featurepoints or planes are detected
    
    var currentState: State?
    
    var planes = [ARPlaneAnchor: Plane]()       // to store auto detected planes
    var previewNode: SCNNode?                   // to preview where the scribble will be placed
    var imagePlanes = [ARImageAnchor: SCNNode]()  // to store planes associated with detected images
    
    var lastScaleFactor: CGFloat = 1.0          // for scale and rotation gestures
    var scaleFactor: CGFloat = 1.0
    var lastRotation: CGFloat = 0.0
    var rotation: CGFloat = 0.0
    var lastPanFactor: CGPoint = CGPoint(x: 0, y: 0)
    var panFactor: CGPoint = CGPoint(x: 0, y: 0)
    
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
        configuration.maximumNumberOfTrackedImages = 3
        return configuration
    }
    
    var detectionImages: Set<ARReferenceImage> {                    // Images to detect and track
        guard let images = ARReferenceImage.referenceImages(inGroupNamed: "DetectionImages_cards", bundle: nil) else {
            fatalError("Detection Images could not be loaded")
        }
        return images
    }
    
    var attachToImagePlane: SCNNode?            // to attach scriblle to a tracked detection image plane
    
    var imagePicker = UIImagePickerController()
    
    var nodesForStep = [[SCNNode]]()
    var currentStep = 0
    
    //MARK: View Life Cycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.drawingScene = DrawingSceneColors(size: sceneView.frame.size)
        drawingSceneView.presentScene(drawingScene)
        
        panGesture.delegate = self
        pinchGesture.delegate = self
        rotationGesture.delegate = self
        
        hiddenTextField.delegate = self
        
        nodesForStep.append([])
        
        currentState = DrawingState()
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
            plane.renderingOrder = -10
            node.addChildNode(plane)
            self.imagePlanes[imageAnchor] = plane
        }
        
        // new ScribbleAnchor placed
        if let scribbleAnchor = anchor as? ScribbleAnchor {
            print("Scribble ARAnchor placed at: \(anchor.transform)")
            scribbleAnchor.node.simdTransform = matrix_identity_float4x4
            node.addChildNode(scribbleAnchor.node)
            nodesForStep[currentStep].append(node)
        }
        
        // new TextAnchor placed
        if let textAnchor = anchor as? TextAnchor {
            print("Text anchor place at: \(anchor.transform)")
            textAnchor.node.simdTransform = matrix_identity_float4x4
            node.addChildNode(textAnchor.node)
            nodesForStep[currentStep].append(node)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // existing plane updated
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.updatePlane(anchor: planeAnchor)
        }
        
        // imageAnchor went out of screen
        if let imageAnchor = anchor as? ARImageAnchor {
            if !imageAnchor.isTracked {
                self.imagePlanes[imageAnchor]?.isHidden = true
            } else {
                self.imagePlanes[imageAnchor]?.isHidden = false
            }
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
        
        currentState?.update(context: self)
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
    
    
    
    // MARK: UITextFieldDelegate
    
    
    
    //MARK: Functions
    
    func hitTestFromCenter() -> [ARHitTestResult] {
        let results = sceneView.hitTest(sceneView.center, types: [.existingPlaneUsingExtent, .featurePoint])
        return results
    }
    
    func hitTestDetectionImage() -> SCNHitTestResult? {
        let results = sceneView.hitTest(sceneView.center, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        let imagePlanes = results.filter { $0.node.name == "detection_image_plane" }
        if let hit = imagePlanes.first {
            return hit
        }
        return nil
    }

    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        let plane = Plane(anchor, in: sceneView)
        node.addChildNode(plane)
        planes[anchor] = plane
        print(planes)
    }
    
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    func getTransformInFrontOfCamera(_ distance: Float) -> simd_float4x4 {
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -distance
        
        let camTransform = sceneView.pointOfView?.simdTransform
        var transform = simd_mul(camTransform!, translation)
        
        return transform
    }
    
    func setInfoText(_ text: String) {
        DispatchQueue.main.async {
            self.infoLabel.text = text
        }
    }
    
    func setDebugText(_ text: String) {
        DispatchQueue.main.async {
            self.debugLabel.text = text
        }
    }
    
    func makePreviewNode(_ node: SCNNode) {
        node.geometry?.firstMaterial?.readsFromDepthBuffer = true // always visible
        node.renderingOrder = -10    // always on top
        sceneView.scene.rootNode.addChildNode(node)
        previewNode = node
    }
    
    func setState(_ state: State) {
        currentState?.onExitState(context: self)
        currentState = state
        currentState?.onEnterState(context: self)
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
    
    func resizeBrushSizeSliderImage() {
        let ratio = CGFloat((self.brushSizeSlider?.value ?? 5.0) + 10.0)
        let thumbImage = UIImage(named: "black-dot")!
        let size = CGSize(width: ratio, height: ratio)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .normal)
        self.brushSizeSlider?.setThumbImage(ResizeImage(image: thumbImage, targetSize: size), for: .highlighted)
    }
    
    func toggleSideBar(visible: Bool) {
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
    
    func setGestureDetectorsEnabled(_ enabled: Bool) {
        self.rotationGesture.isEnabled = enabled
        self.pinchGesture.isEnabled = enabled
        self.panGesture.isEnabled = enabled
    }
    
    func resetGestureValues() {
        self.lastScaleFactor = 1.0
        self.scaleFactor = 1.0
        self.lastRotation = 0.0
        self.rotation = 0.0
        self.lastPanFactor = CGPoint(x: 0, y: 0)
        self.panFactor = CGPoint(x: 0, y: 0)
    }
    
    func nextStep() {
        for node in nodesForStep[currentStep] {
            node.isHidden = true
        }
        
        if currentStep + 1 >= nodesForStep.count {
            if nodesForStep[currentStep].count > 0 {
                nodesForStep.append([])
                currentStep += 1
            }
        }
        else {
            currentStep += 1
            for node in nodesForStep[currentStep] {
                node.isHidden = false
            }
        }
        print("Next step. Now in step nr: \(currentStep)")
    }
    
    func prevStep() {
        guard currentStep >= 1 else { return }
        
        for node in nodesForStep[currentStep] {
            node.isHidden = true
        }
        currentStep -= 1
        
        for node in nodesForStep[currentStep] {
            node.isHidden = false
        }
        
        print("Prev step. Now in step nr: \(currentStep)")
    }
    
    
    //MARK: Actions
    
    @IBAction func clickedAddButton(_ sender: UIButton) {
        currentState?.handleAddButton(context: self)
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
        if(currentState is EditingState) {
            setState(DrawingState())
        }
        else {
            setState(EditingState())
        }
    }
    
    @IBAction func clickedDeleteButton(_ sender: UIButton) {
        if(currentState is PlacingState) {
            previewNode?.removeFromParentNode()
            setState(DrawingState())
        }
    }
    
    @IBAction func clickedTextButton(_ sender: UIButton) {
        hiddenTextField.becomeFirstResponder()
        hiddenTextField.addTarget(self, action: #selector(ViewController.hiddenTextFieldChanged(_:)), for: UIControl.Event.editingChanged)
        hiddenTextField.addTarget(self, action: #selector(ViewController.hiddenTextFieldEndEditing), for: UIControl.Event.editingDidEnd)
        
        print("Made new text node, set state to typing")
        let textnode = TextNode(text: "", color: (drawingScene?.lineColor)!)
        textnode.name = "text"
        makePreviewNode(textnode)
        setState(TypingState())
    }
    
    @objc func hiddenTextFieldChanged(_ textField: UITextField) {
        if let node = self.previewNode as? TextNode {
            print("Text changed: \(textField.text)")
            node.text = textField.text ?? ""
        }
    }
    
    @objc func hiddenTextFieldEndEditing() {
        print("end editing")
        if(hiddenTextField.text == "") {
            setState(DrawingState())
        } else {
            setState(PlacingState())
        }
        self.hiddenTextField.text = ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.hiddenTextField.resignFirstResponder()
        return true
    }
    
    @IBAction func clickedImageButton(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            imagePicker.modalPresentationStyle = .overCurrentContext
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        // image size in pixels, node size in meters
        let node = SCNNode(geometry: SCNPlane(width: image.size.width / 20000, height: image.size.height / 20000))
        
        node.geometry?.firstMaterial?.diffuse.contents = image
        node.simdTransform *= float4x4(simd_quatf(angle: Float.pi / 2, axis: float3(1,0,0)))
        node.name = "image"
        
        
        picker.dismiss(animated: true, completion: nil)
        
        makePreviewNode(node)
        setState(PlacingState())
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func clickedNextButton(_ sender: UIButton) {
        nextStep()
    }
    
    @IBAction func clickedPrevButton(_ sender: UIButton) {
        prevStep()
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
    
    @IBAction func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        if(sender.state == .began || sender.state == .changed) {
            let translation = sender.translation(in: sceneView)
            self.panFactor = CGPoint(x: (translation.x / sceneView.bounds.width) + self.lastPanFactor.x, y: (translation.y / sceneView.bounds.height) + self.lastPanFactor.y)
            print(panFactor)
        }
        else if(sender.state == .ended) {
            self.lastPanFactor = self.panFactor
        }
    }
    
    @IBAction func handleTapGesture(_ sender: UITapGestureRecognizer) {
        currentState?.handleTap(context: self, sender: sender)
    }
    
    
    // Simultaneous recognition for rotation and scale gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
            (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
    }
}
