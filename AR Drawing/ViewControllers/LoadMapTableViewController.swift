import UIKit
import ARKit

class LoadMapTableViewController: UITableViewController {

    var maps = [ARWorldMap]()
    var names = [String]()
    
    var cellSelectedHandler: ((ARWorldMap)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isHidden = false
        
        loadMaps()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
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
        return maps.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "WorldMapTableCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? WorldMapTableViewCell else {
            fatalError("The dequeued cell is not an instance of WorldMapTableCell")
        }

        let map = maps[indexPath.row]
        if let imagedata = map.snapshotAnchor?.imageData, let snapshotImage = UIImage(data: imagedata) {
            cell.mapName.text = names[indexPath.row]
            cell.mapImage.image = snapshotImage
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if cellSelectedHandler != nil {
            cellSelectedHandler!(maps[indexPath.row])
        }
        dismiss(animated: true, completion: nil)
    }
    
    

    private func readWorldMap(from url: URL) throws -> ARWorldMap {
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw ARError(.invalidWorldMap)
        }
        return worldMap
    }
    
    func loadMaps() {
        
        print("in load maps function")
        
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
                
                maps += [worldmap]
                names += [url.pathComponents.last!]
                
                print("added worldmap to table")
            }
        } catch {
            print("Error loading maps form filesystem: \(error.localizedDescription)")
        }
    }
}
