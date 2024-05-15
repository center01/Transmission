//
// Copyright (c) Nathan Tannar
//

#if os(iOS)

import UIKit

extension UIScreen {

    var displayCornerRadius: CGFloat {
        _displayCornerRadius
    }

    public var _displayCornerRadius: CGFloat {
        let key = String("suidaRrenroCyalpsid_".reversed())
        let value = value(forKey: key) as? CGFloat ?? 0
        return value
    }
}

#endif
