//
//  Bundle+MuscleMap.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-10.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

#if !SWIFT_PACKAGE
private class BundleFinder {}

extension Bundle {
    /// Resolves the MuscleMap resource bundle for CocoaPods.
    static let module: Bundle = {
        let bundleName = "MuscleMap"
        let candidates = [
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.resourceURL,
        ]
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        return Bundle(for: BundleFinder.self)
    }()
}
#endif
