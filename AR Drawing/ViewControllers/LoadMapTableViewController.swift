import UIKit
import ARKit

class LoadMapTableViewController: UITableViewController {
    
    struct MapInfo {
        var name: String
        var file: URL
        var map: ARWorldMap
        var date: Date
    }
    var mapInfo = [MapInfo]()
    
    var cellSelectedHandler: ((MapInfo)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isHidden = false
        
        loadMaps()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.navigationBar.isHidden = true
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return mapInfo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "WorldMapTableCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? WorldMapTableViewCell else {
            fatalError("The dequeued cell is not an instance of WorldMapTableCell")
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"

        let map = mapInfo[indexPath.row].map
        cell.mapName.text = mapInfo[indexPath.row].name
        cell.mapDateCreated.text = formatter.string(from: mapInfo[indexPath.row].date)
        cell.mapDescription.text = "\(map.anchors.count) anchors\n\(map.rawFeaturePoints.points.count) features"
        
        if let imagedata = map.snapshotAnchor?.imageData, let snapshotImage = UIImage(data: imagedata) {
            cell.mapImage.image = snapshotImage
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if cellSelectedHandler != nil {
            cellSelectedHandler!(self.mapInfo[indexPath.row])
        }
        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                try FileManager.default.removeItem(at: self.mapInfo[indexPath.row].file)
                mapInfo.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Error deleting worldmap: \(error.localizedDescription)")
            }
        }
    }
    
    

    private func readWorldMap(from url: URL) throws -> ARWorldMap {
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw ARError(.invalidWorldMap)
        }
        return worldMap
    }
    
    func loadMaps() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])
            
            for url in urls {                
                let worldmap: ARWorldMap = {
                    do {
                        return try readWorldMap(from: url)
                    } catch {
                        fatalError("Error reading wordmap from url: \(error.localizedDescription)")
                    }
                }()
                
                let name = url.pathComponents.last!.components(separatedBy: ".").first!
                
                do {
                    let values = try url.resourceValues(forKeys: [.creationDateKey])
                    let date = values.creationDate!

                    let info = MapInfo(name: name, file: url, map: worldmap, date: date)
                    mapInfo.append(info)
                } catch {
                    fatalError("Cannot get attributes of \(url.absoluteString)")
                }
    
                print("added worldmap to table")
            }
        } catch {
            print("Error loading maps form filesystem: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: Content size of the popover
    
    
}
