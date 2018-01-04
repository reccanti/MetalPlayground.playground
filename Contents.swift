import MetalKit
import PlaygroundSupport
import Cocoa

let frame = NSRect(x: 0, y: 0, width: 400, height: 400)
let delegate = MetalView()
let view = MTKView(frame: frame, device: delegate.device)
view.delegate = delegate
PlaygroundPage.current.liveView = view

