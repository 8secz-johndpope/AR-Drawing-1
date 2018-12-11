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
        guard let name = txtMapName.text, name != "" else {
            let alert = UIAlertController(title: "No map name", message: "Please enter a name for the map before saving.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        mapper?.save(mapname: name)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func clickedCancelButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
