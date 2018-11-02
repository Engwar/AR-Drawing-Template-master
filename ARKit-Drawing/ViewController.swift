import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    
    var selectedNode: SCNNode?
    
    var placedNodes = [SCNNode]() //массив размещенных объектов
    var planeNodes = [SCNNode]() // массив поверхностей, которые мы будем находить
    
    var showPlanes = false {  //свойство для сокрытия поверхности
        didSet {             // наблюдатель. если где то у нас поменялось значение свойства то мы проходим по всем поверхностям и пряем их или показываем
            for node in planeNodes {
                node.isHidden = !showPlanes
            }
        }
    }
    
    var lastObjectPlacePoint: CGPoint?
    let touchDistance: CGFloat = 40
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration(removeAnchors: false)
        }
    }
    
 
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    func reloadConfiguration(removeAnchors: Bool = true) {
        //определяем только горизонтальные поверхности
        configuration.planeDetection = .horizontal
        // определяем картинку (можно в группу добавлять несколько картинок)
        configuration.detectionImages = (objectMode == .image) ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil
        
        let options: ARSession.RunOptions
        
        if removeAnchors {
            options = [.removeExistingAnchors]
            for node in planeNodes {
                node.removeFromParentNode()
            }
            planeNodes.removeAll()
            for node in placedNodes {
                node.removeFromParentNode()
            }
            placedNodes.removeAll()
        } else {
            options = []
        }
        
        sceneView.session.run(configuration, options: options)
    }
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
}

//MARK: OptionViewControllerDelegate
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        showPlanes = !showPlanes
    }
    
    func undoLastObject() {
        if let lastNode = placedNodes.last {
            lastNode.removeFromParentNode()
            placedNodes.removeLast()
        }
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
        reloadConfiguration()
    }
}

//MARK: Touches Managment
extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let node = selectedNode, let touch = touches.first else { return }
        
        switch objectMode{
        case .freeform:
            addNodeInFront(node)
        case .plane:
            let point = touch.location(in: sceneView)
            addNode(node, point: point)
        case .image:
            break
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard objectMode == .plane,
            let node = selectedNode,
            let touch = touches.first,
            let lastTouchPoint = lastObjectPlacePoint
            else {return}
        
        let newTouchPoint = touch.location(in: sceneView)
        let distance = sqrt(
            pow(newTouchPoint.x - lastTouchPoint.x, 2) +
            pow(newTouchPoint.y - lastTouchPoint.y, 2)
        )
        
        if touchDistance < distance {
            addNode(node, point: newTouchPoint)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        lastObjectPlacePoint = nil
    }
}

//MARK: Placement Methods
extension ViewController {
    // Добавляем узел перед нами путем перемножения матриц и делаем отступ в 20 см.
    func addNodeInFront(_ node: SCNNode) {
        guard let frame = sceneView.session.currentFrame else {return}
        
        let transform = frame.camera.transform
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        
        node.simdTransform = matrix_multiply(transform, translation)
        
        addNodeToSceneRoot(node)
    }
    
    func addNode(_ node: SCNNode, point: CGPoint){
        let results = sceneView.hitTest(point, types: [.existingPlaneUsingExtent])
        
        if let match = results.first{
            let position = match.worldTransform.columns.3
            node.position = SCNVector3(position.x, position.y, position.z)
            addNodeToSceneRoot(node)
            lastObjectPlacePoint = point
        }
    }
    
    //этот метод размещает узлы(ноды)
    func addNodeToSceneRoot(_ node: SCNNode) {
        let cloneNode = node.clone()
        sceneView.scene.rootNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode) //здесь мы добавляем эти ноды в массив
    }

}

//MARK: ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
 //       sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
    }
    
    //в этой функции мы разделяем определение поверхности и картинки двумя методами с одним названием, в первом случае
    // for anchor - image, во втором plane
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let anchor = anchor as? ARImageAnchor {
            nodeAdded(node, for: anchor)
        } else if let anchor = anchor as? ARPlaneAnchor {
            nodeAdded(node, for: anchor)
        }
    }
    
    // в этой функции мы меняем размеры найденной поверхности
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor, //делаем проверку что Энкор это ПлейнЭнкор и присваиваем наследника ARAnchor -> ARPlaneAnchor чтобы получить его свойства
            let node = node.childNodes.first, // проверяем что у ноды есть хотя бы один наследник и присваиваем первого наследника Ноды
            let plane = node.geometry as? SCNPlane // далее берем этого наследника и проверяем его геометрию что она ЭССИЭНПлейн
            else { return }
        
        node.position = SCNVector3(anchor.center.x, 0, anchor.center.z) //меняем позицию после проверок
        plane.width = CGFloat(anchor.extent.x)   //меняем размеры
        plane.height = CGFloat(anchor.extent.z)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor){
        if let selectedNode = selectedNode {
            addNode(selectedNode, parentNode: node)
        }
    }
    //функция которой передаются два параметра: узел и куда добавлять узел,
    //которая добавляет узел к родительскому узлу и в массив узлов
    func addNode(_ node: SCNNode, parentNode: SCNNode){
        let cloneNode = node.clone()
        parentNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor){
        let floor = createFloor(anchor:anchor)
        floor.isHidden = !showPlanes
        node.addChildNode(floor)
        planeNodes.append(floor)
    }
    
    //создаем поверхность для привязки к ней ноды(объекта)
    func createFloor(anchor: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode()
        let extent = anchor.extent
        let geometry = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        node.geometry = geometry
        
        node.eulerAngles.x = -.pi / 2
        node.opacity = 0.25
        return node
    }
}
