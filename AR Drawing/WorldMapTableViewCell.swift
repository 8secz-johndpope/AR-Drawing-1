import UIKit

class WorldMapTableViewCell: UITableViewCell {

    @IBOutlet weak var mapImage: UIImageView!
    @IBOutlet weak var mapName: UILabel!
    @IBOutlet weak var mapDescription: UILabel!
    @IBOutlet weak var mapDateCreated: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
