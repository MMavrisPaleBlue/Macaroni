//
// Containerable
// Macaroni
//
// Created by Alex Babaev on 26 March 2021.
// Copyright © 2021 Alex Babaev. All rights reserved.
// License: MIT License, https://github.com/bealex/Macaroni/blob/main/LICENSE
//

import Foundation

public protocol Containerable {
    var container: Container.FindPolicy.Finder { get }
}
