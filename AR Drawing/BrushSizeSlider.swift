import UIKit

class BrushSizeSlider: UIControl {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        setupSlider()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isUserInteractionEnabled = true
        setupSlider()
    }
    
    
    
    func setupSlider() {
        let slider = UISlider(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        slider.minimumValue = 0
        slider.maximumValue = 50
        slider.isContinuous = true
        slider.tintColor = .blue
        slider.addTarget(self, action: #selector(BrushSizeSlider.brushSliderValueChanged(_:)), for: .valueChanged)
        slider.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
        
        addSubview(slider)
    }
    
    
    @objc func brushSliderValueChanged(_ sender: UISlider) {
        print("slider value changed: \(sender.value)")
    }
}
