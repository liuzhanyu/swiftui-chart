import UIKit

final class IconTextButton: UIButton {

    @IBInspectable var normalTextColor: UIColor = .systemGray
    @IBInspectable var highlightedTextColor: UIColor = .white


    override func updateConfiguration() {
        super.updateConfiguration()

        let color = isHighlighted ? highlightedTextColor : normalTextColor

        var config = configuration ?? .plain()

        if let image = config.image ?? image(for: .normal) {
            config.image = image.withRenderingMode(.alwaysTemplate)
        }

        config.baseForegroundColor = color

        config.imageColorTransformer = UIConfigurationColorTransformer { _ in color }

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var attr = attr
            attr.foregroundColor = color
            return attr
        }
        config.contentInsets = .zero
        configuration = config
    }
}
//import UIKit
//
//final class IconTextButton: UIButton {
//
//    @IBInspectable var normalTextColor: UIColor = .systemGray
//    @IBInspectable var highlightedTextColor: UIColor = .white
//    @IBInspectable var highlightedImage: UIImage?
//
//    private var normalIcon: UIImage?
//    private var highlightedIcon: UIImage?
//
//    override func awakeFromNib() {
//        super.awakeFromNib()
//
//        normalIcon = configuration?.image ?? image(for: .normal)
//        highlightedIcon = highlightedImage ?? normalIcon
//
//        setNeedsUpdateConfiguration()
//    }
//
//    override func updateConfiguration() {
//        super.updateConfiguration()
//
//        var config = configuration ?? .plain()
//
//        if normalIcon == nil {
//            normalIcon = config.image ?? image(for: .normal)
//        }
//
//        if highlightedIcon == nil {
//            highlightedIcon = highlightedImage ?? normalIcon
//        }
//
//        let color = isHighlighted ? highlightedTextColor : normalTextColor
//        let icon = isHighlighted ? highlightedIcon : normalIcon
//
//        if let icon {
//            config.image = icon.withRenderingMode(.alwaysOriginal)
//        }
//
//        config.baseForegroundColor = color
//
//        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
//            var attr = attr
//            attr.foregroundColor = color
//            return attr
//        }
//        config.contentInsets = .zero
//        configuration = config
//    }
//}
