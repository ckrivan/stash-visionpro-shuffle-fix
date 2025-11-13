//
//  MetalVRRenderer.swift
//  Stash VR Player - Metal-based VR Video Renderer
//
//  Moon Player-style rendering using Metal shaders for proper equirectangular projection.
//  This replaces the failed RealityKit UV mapping approach with direct Metal rendering.
//

import AVFoundation
import Metal
import MetalKit
import RealityKit
import SwiftUI
import VideoToolbox

/// VR video format types
enum MetalVRFormat: Int {
    case mono = 0
    case sideBySide = 1
    case overUnder = 2
    case fisheye = 3
}

/// Projection type (180° or 360°)
enum MetalVRProjection: Int {
    case projection180 = 0
    case projection360 = 1
}

/// Uniforms structure matching Metal shader
struct VRUniforms {
    var modelViewProjection: simd_float4x4
    var modelMatrix: simd_float4x4
    var videoFormat: Int32
    var projectionType: Int32
    var zoom: Float
    var rotation: Float
    var tilt: Float
}

/// Metal-based VR video renderer
/// Extracts frames from AVPlayer and renders them with proper VR projection using Metal shaders
@MainActor
class MetalVRRenderer: NSObject, ObservableObject {
    // Metal rendering components
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var uniformsBuffer: MTLBuffer!

    // Video components
    private var videoOutput: AVPlayerItemVideoOutput!
    private var displayLink: CADisplayLink?
    private weak var player: AVPlayer?

    // Current video texture from AVPlayer
    private var currentVideoTexture: MTLTexture?

    // VR parameters
    @Published var format: MetalVRFormat = .sideBySide
    @Published var projection: MetalVRProjection = .projection180
    @Published var zoom: Float = 1.0
    @Published var rotation: Float = 0.0
    @Published var tilt: Float = 0.0

    // Rendering state
    @Published var isReady = false
    private var textureCache: CVMetalTextureCache?

    override init() {
        super.init()
        setupMetal()
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal is not supported on this device")
            return
        }
        self.device = device
        print("✅ Metal device created: \(device.name)")

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Failed to create Metal command queue")
            return
        }
        self.commandQueue = commandQueue

        // Create texture cache for video frames
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        self.textureCache = textureCache

        // Create shaders and pipeline
        setupShaders()

        // Create sphere geometry
        createSphereGeometry()

        // Create uniforms buffer
        let uniformsSize = MemoryLayout<VRUniforms>.stride
        uniformsBuffer = device.makeBuffer(length: uniformsSize, options: [.storageModeShared])

        isReady = true
        print("✅ Metal VR renderer initialized successfully")
    }

    private func setupShaders() {
        guard let library = device.makeDefaultLibrary() else {
            print("❌ Failed to create Metal library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "vrVertexShader"),
              let fragmentFunction = library.makeFunction(name: "vrFragmentShader") else {
            print("❌ Failed to load shader functions")
            return
        }

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // TexCoord attribute
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 5  // 3 position + 2 texCoord
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ Metal pipeline state created")
        } catch {
            print("❌ Failed to create pipeline state: \(error)")
        }

        // Create depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    // MARK: - Sphere Geometry Generation

    private func createSphereGeometry() {
        // Generate sphere mesh for inside-out viewing
        let segments = 64  // High detail for smooth VR
        var vertices: [Float] = []
        var indices: [UInt16] = []

        // Generate sphere vertices
        for lat in 0...segments {
            let theta = Float(lat) / Float(segments) * .pi
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for lon in 0...segments {
                let phi = Float(lon) / Float(segments) * 2.0 * .pi
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)

                // Position (inverted for inside viewing)
                let x = -cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta

                // Texture coordinates
                let u = Float(lon) / Float(segments)
                let v = Float(lat) / Float(segments)

                vertices.append(contentsOf: [x, y, z, u, v])
            }
        }

        // Generate indices
        for lat in 0..<segments {
            for lon in 0..<segments {
                let first = UInt16(lat * (segments + 1) + lon)
                let second = UInt16(first + segments + 1)

                indices.append(contentsOf: [first, second, first + 1])
                indices.append(contentsOf: [second, second + 1, first + 1])
            }
        }

        // Create Metal buffers
        let vertexDataSize = vertices.count * MemoryLayout<Float>.stride
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataSize, options: [])

        let indexDataSize = indices.count * MemoryLayout<UInt16>.stride
        indexBuffer = device.makeBuffer(bytes: indices, length: indexDataSize, options: [])

        print("✅ Sphere geometry created: \(vertices.count / 5) vertices, \(indices.count / 3) triangles")
    }

    // MARK: - Video Frame Extraction

    func attachToPlayer(_ player: AVPlayer) {
        self.player = player

        // Create video output for extracting frames
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)

        if let playerItem = player.currentItem {
            playerItem.add(videoOutput)
            print("✅ Video output attached to player")
        }

        // Start display link for frame updates
        startDisplayLink()
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateVideoFrame))
        displayLink?.add(to: .main, forMode: .common)
        print("✅ Display link started for video frame updates")
    }

    @objc private func updateVideoFrame() {
        guard let player = player,
              let videoOutput = videoOutput,
              let textureCache = textureCache else { return }

        let currentTime = player.currentTime()

        // Check if new frame is available
        guard videoOutput.hasNewPixelBuffer(forItemTime: currentTime) else { return }

        // Get pixel buffer
        guard let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: currentTime,
            itemTimeForDisplay: nil
        ) else { return }

        // Convert to Metal texture
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var textureRef: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &textureRef
        )

        if status == kCVReturnSuccess, let textureRef = textureRef {
            currentVideoTexture = CVMetalTextureGetTexture(textureRef)
        }
    }

    // MARK: - Rendering

    /// Render VR video frame to a Metal texture
    /// This texture can then be used by RealityKit as a material
    func renderFrame(to drawable: CAMetalDrawable, viewMatrix: simd_float4x4, projectionMatrix: simd_float4x4) {
        guard let pipelineState = pipelineState,
              let videoTexture = currentVideoTexture,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Update uniforms
        updateUniforms(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)

        // Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        // Set pipeline and buffers
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(videoTexture, index: 0)

        // Draw sphere
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer.length / MemoryLayout<UInt16>.stride,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func updateUniforms(viewMatrix: simd_float4x4, projectionMatrix: simd_float4x4) {
        // Create model matrix (identity for now, can add transformations)
        let modelMatrix = simd_float4x4(1.0)

        // Calculate MVP matrix
        let modelViewProjection = projectionMatrix * viewMatrix * modelMatrix

        // Fill uniforms structure
        var uniforms = VRUniforms(
            modelViewProjection: modelViewProjection,
            modelMatrix: modelMatrix,
            videoFormat: Int32(format.rawValue),
            projectionType: Int32(projection.rawValue),
            zoom: zoom,
            rotation: rotation,
            tilt: tilt
        )

        // Copy to buffer
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<VRUniforms>.stride)
    }

    // MARK: - Cleanup

    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil

        if let playerItem = player?.currentItem {
            playerItem.remove(videoOutput)
        }

        player = nil
        currentVideoTexture = nil
        print("🧹 Metal VR renderer cleaned up")
    }

    deinit {
        cleanup()
    }
}

// MARK: - Helper: Matrix Extensions

extension simd_float4x4 {
    init(_ value: Float) {
        self.init(
            SIMD4<Float>(value, 0, 0, 0),
            SIMD4<Float>(0, value, 0, 0),
            SIMD4<Float>(0, 0, value, 0),
            SIMD4<Float>(0, 0, 0, value)
        )
    }
}
