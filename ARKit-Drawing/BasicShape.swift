import UIKit

//Опции 
enum ShapeOption: String, RawRepresentable {
    case addShape = "Select Basic Shape"
    case addScene = "Select Scene File"
    case togglePlane = "Enable/Disable Plane Visualization"
    case undoLastShape = "Undo Last Shape"
    case resetScene = "Reset Scene"
}


//Виды объектов, их формы
enum Shape: String {
    case box = "Box", sphere = "Sphere", cylinder = "Cylinder", cone = "Cone", pyramid = "Pyramid"
}


//Размеры объектов
enum Size: String {
    case small = "Small", medium = "Medium", large = "Large", extraLarge = "Extra Large"
}
