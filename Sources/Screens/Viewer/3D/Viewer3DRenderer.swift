// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import GLTFKit2
import SceneKit
import SwiftUI

struct Viewer3DRenderer: UIViewRepresentable {
    @State private var isLoading = true
    private let file: VOFile.Entity
    private let data: Data

    init(file: VOFile.Entity, data: Data) {
        self.file = file
        self.data = data
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)

        let sceneView = context.coordinator.sceneView
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemBackground

        sceneView.isHidden = true
        containerView.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: containerView.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        containerView.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])

        context.coordinator.spinner = spinner
        context.coordinator.loadAsset()

        return containerView
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        uiView.subviews.first { $0 is SCNView }?.isHidden = isLoading
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneView: SCNView(), data: data, isLoading: $isLoading)
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var data: Data
        var asset: GLTFAsset?
        var sceneView: SCNView
        var animations = [GLTFSCNAnimation]()
        let cameraNode = SCNNode()
        var spinner: UIActivityIndicatorView?
        @Binding var isLoading: Bool

        init(sceneView: SCNView, data: Data, isLoading: Binding<Bool>) {
            self.sceneView = sceneView
            self.data = data
            _isLoading = isLoading

            let camera = SCNCamera()
            camera.usesOrthographicProjection = false
            camera.zNear = 0.1
            camera.zFar = 100
            cameraNode.camera = camera

            super.init()

            sceneView.delegate = self

            // Initially pause the scene view
            sceneView.isPlaying = false
        }

        func loadAsset() {
            loadAsset(data: data) { [self] asset, _ in
                if let asset {
                    self.asset = asset
                    setupScene()
                    isLoading = false
                }
            }
        }

        func loadAsset(data: Data, completion: @escaping (GLTFAsset?, Error?) -> Void) {
            DispatchQueue.global(qos: .userInitiated).async {
                GLTFAsset.load(
                    with: data,
                    options: [:]
                ) { _, status, maybeAsset, maybeError, _ in
                    DispatchQueue.main.async {
                        if status == .complete {
                            completion(maybeAsset, nil)
                        } else if let error = maybeError {
                            completion(nil, error)
                        }
                    }
                }
            }
        }

        private func setupScene() {
            guard let asset else { return }
            let source = GLTFSCNSceneSource(asset: asset)
            if let scene = source.defaultScene {
                sceneView.scene = scene
                sceneView.pointOfView = cameraNode

                // Remove the spinner once the asset is loaded
                DispatchQueue.main.async {
                    self.spinner?.removeFromSuperview()
                }

                // Adjust the camera to fit the object using SceneKit's built-in API
                adjustCameraToFitObject()
            }
            animations = source.animations
            if let defaultAnimation = animations.first {
                defaultAnimation.animationPlayer.animation.usesSceneTimeBase = false
                defaultAnimation.animationPlayer.animation.repeatCount = .greatestFiniteMagnitude

                sceneView.scene?.rootNode.addAnimationPlayer(defaultAnimation.animationPlayer, forKey: nil)

                defaultAnimation.animationPlayer.play()
            }
            sceneView.scene?.rootNode.addChildNode(cameraNode)
        }

        private func adjustCameraToFitObject() {
            guard let scene = sceneView.scene else { return }

            // Calculate the bounding box of the entire scene, including transformations
            let (minVec, maxVec) = scene.rootNode.boundingBoxRelativeToCurrentObject()
            let center = SCNVector3(
                (minVec.x + maxVec.x) / 2,
                (minVec.y + maxVec.y) / 2,
                (minVec.z + maxVec.z) / 2
            )
            let extents = SCNVector3(
                maxVec.x - minVec.x,
                maxVec.y - minVec.y,
                maxVec.z - minVec.z
            )
            let maxExtent = max(extents.x, extents.y, extents.z)

            // Scale the model if it's too small
            let scaleFactor: Float = maxExtent < 0.5 ? 1.0 / maxExtent : 1.0
            scene.rootNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)

            // Assuming a comfortable distance factor
            let adjustedExtent = maxExtent * scaleFactor
            let distance = adjustedExtent * 2.0

            cameraNode.position = SCNVector3(center.x, center.y + extents.y / 2, center.z + distance)

            // Update the camera's look-at point on the main thread to ensure synchronization
            DispatchQueue.main.async {
                self.cameraNode.look(at: center)

                // Only start playing the view after the camera is adjusted and asset is loaded
                self.sceneView.isPlaying = true
            }
        }
    }
}
