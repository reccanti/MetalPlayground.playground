import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    
    var rotation: Float = 0
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var rps: MTLRenderPipelineState!
    
    override public init() {
        super.init()
        createBuffers()
        registerShaders()
    }
    
    func createBuffers() {
        device = MTLCreateSystemDefaultDevice()
        queue = device.makeCommandQueue()
        
        // create vertex buffer
        let vertexData = [Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
                          Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
                          Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [0, 0, 1, 1]),
                          Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [1, 1, 1, 1]),
                          Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
                          Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 1, 1, 1]),
                          Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [1, 0, 0, 1]),
                          Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 0, 1])]
        vertexBuffer = device!.makeBuffer(bytes: vertexData, length: MemoryLayout<Vertex>.size * vertexData.count, options:[])

        // create index buffer
        let indexData: [uint16] = [
            0, 1, 2, 2, 3, 0,   // front
            
            1, 5, 6, 6, 2, 1,   // right
            
            3, 2, 6, 6, 7, 3,   // top
            
            4, 5, 1, 1, 0, 4,   // bottom
            
            4, 0, 3, 3, 7, 4,   // left
            
            7, 6, 5, 5, 4, 7,   // back
        ]
        indexBuffer = device!.makeBuffer(bytes: indexData, length: MemoryLayout<uint16>.size * indexData.count, options:[])
        
        // create uniform buffer
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size * 16, options:[])
        
        let bufferPointer = uniformBuffer.contents()
        
        let aspect = Float(1)
        let projMatrix = projectionMatrix(near: 1, far: 100, aspect: aspect, fovy: 1.1)
        let modelViewProjectionMatrix = matrix_multiply(projMatrix, matrix_multiply(viewMatrix(), modelMatrix()))

        var uniforms = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix)
        memcpy(bufferPointer, &uniforms, MemoryLayout<Float>.size * 16)
    }
    
    func update() {
        let scaled = scalingMatrix(scale: 0.5)
        rotation += 1 / 100 * Float.pi / 4
        let rotatedY = rotationMatrix(angle: rotation, axis: float3(0, 1, 0))
        let rotatedX = rotationMatrix(angle: Float.pi / 4, axis: float3(1, 0, 0))
        let modelMatrix = matrix_multiply(matrix_multiply(rotatedX, rotatedY), scaled)
        let cameraPosition = vector_float3(0, 0, -3)
        let viewMatrix = translationMatrix(position: cameraPosition)
        let aspect = Float(1)
        let projMatrix = projectionMatrix(near: 0, far: 10, aspect: aspect, fovy: 1)
        let modelViewProjectionMatrix = matrix_multiply(projMatrix, matrix_multiply(viewMatrix, modelMatrix))
        let bufferPointer = uniformBuffer.contents()
        var uniforms = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix)
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.size)
    }
    
    // registers all shaders from the resources folder
    func registerShaders() {
        let path = Bundle.main.path(forResource: "Shaders", ofType: "metal")
        let input: String?
        let library: MTLLibrary
        let vert_func: MTLFunction
        let frag_func: MTLFunction
        do {
            input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            library = try device!.makeLibrary(source: input!, options: nil)
            vert_func = library.makeFunction(name: "vertex_func")!
            frag_func = library.makeFunction(name: "fragment_func")!
            let rpld = MTLRenderPipelineDescriptor()
            rpld.vertexFunction = vert_func
            rpld.fragmentFunction = frag_func
            rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
            rps = try device!.makeRenderPipelineState(descriptor: rpld)
        } catch let e {
            Swift.print("\(e)")
        }
        
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        update()
        if let rpd = view.currentRenderPassDescriptor,
           let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            commandEncoder.setFrontFacing(.counterClockwise)
            commandEncoder.setCullMode(.back)
            commandEncoder.setRenderPipelineState(rps)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            commandEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexBuffer.length / MemoryLayout<uint16>.size,
                indexType: MTLIndexType.uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
