//
//  RemmyWidgetBundle.swift
//  RemmyWidget
//
//  Widget extension entry point.
//  Declares all WidgetKit widgets available on the watch face.
//

import SwiftUI
import WidgetKit

@main
struct RemmyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemmyWidgets()
    }
}
