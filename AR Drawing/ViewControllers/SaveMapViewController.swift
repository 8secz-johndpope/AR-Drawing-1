import Foundation
import UIKit
import ARKit

class SaveMapViewController: UIViewController {
    var mapName: String = ""
    var mapper: WorldMapper?
    
    @IBOutlet weak var txtMapName: UITextField!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        txtMapName.text = mapName
        image.image = mapper?.snapshot
    }
    
    
    @IBAction func clickedSaveButton(_ sender: Any) {
        mapper?.save(mapname: txtMapName.text ?? "map")
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func clickedCancelButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
