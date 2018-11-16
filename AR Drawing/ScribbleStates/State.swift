import UIKit.UITapGestureRecognizer

protocol State {
    func onEnterState(context: ViewController)
    func onExitState(context: ViewController)
    func update(context: ViewController)
    func handleAddButton(context: ViewController)
    func handleTap(context: ViewController, sender: UITapGestureRecognizer)
}
