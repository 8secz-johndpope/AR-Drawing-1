import SceneKit
import ARKit

class WorldMapper {
    
    var controller: ViewController
    
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
    
    var snapshot: UIImage?
    var map: ARWorldMap?
    
    
    init(controller: ViewController) {
        self.controller = controller
    }
    
    private func getWorldMapURL(mapname: String) -> URL {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("\(mapname).arworldmap")
        } catch {
            fatalError("Can't get file save URL for worldmap: \(error.localizedDescription)")
        }
    }
    
    private func listDocumentsDirectory() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])
            print(contents)
        } catch {
            print("Listing Documents Directory failed: \(error)")
        }
    }
    
    private func writeWorldMap(_ worldMap: ARWorldMap, to url: URL) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: url, options: [.atomic])
    }
    
    private func readWorldMap(from url: URL) throws -> ARWorldMap {
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw ARError(.invalidWorldMap)
        }
        return worldMap
    }
    
    func prepareForSave() {
        self.controller.sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let map = worldMap else {
                print("Cannot get current world map: \(error?.localizedDescription)")
                return
            }
            
            guard let snapshotAnchor = SnapshotAnchor(capturing: self.controller.sceneView) else {
                fatalError("Cannot take snapshot")
            }
            map.anchors.append(snapshotAnchor)
            
            self.snapshot = UIImage(data: snapshotAnchor.imageData)
            self.map = map
            
            self.controller.performSegue(withIdentifier: "savemap", sender: self)
        }
    }
    
    func save(mapname: String) {
        guard let map = self.map else { return }
        
        let url = getWorldMapURL(mapname: mapname)
        
        do {
            try self.writeWorldMap(map, to: url)
            DispatchQueue.main.async {
                self.controller.loadButton.isHidden = false
                self.controller.loadButton.isEnabled = true
                print("world map saved: \(url.relativeString)")
            }
            for anchor in map.anchors {
                print(anchor)
            }
        } catch {
            fatalError("Can't save map: \(error.localizedDescription)")
        }
        
        self.listDocumentsDirectory()
    }
    
    func load() {
        let worldMap: ARWorldMap = {
            do {
                return try self.readWorldMap(from: self.worldMapURL)
            } catch {
                fatalError("Can't unarchive ARWorldMap from file data: \(error)")
            }
        }()
        
        // display SnapShotImage
        if let snapshotData = worldMap.snapshotAnchor?.imageData, let snapshot = UIImage(data: snapshotData) {
            self.controller.snapShotImage.image = snapshot
            print("Move device to the location shown in the image")
        } else {
            print("No snapshot image stored with worldmap!")
        }
        
        // remove snapshot from worldmap, not needed in scene
        worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })
        
        // set configuration with initialWorldMap
        let configuration = self.controller.defaultConfiguration
        configuration.initialWorldMap = worldMap
        self.controller.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        self.controller.resetToFirstStep()
    }
        
}
