import Foundation
import Vision
import CoreGraphics

public struct Pose: Sendable {
    public let joints: [Joint.Name: Joint]
    
    public init(joints: [Joint.Name : Joint]) {
        self.joints = joints
    }
    
    /// Provides a static list of joint pairs to connect for drawing a more complete upper-body skeleton.
    public static var boneConnections: [(Joint.Name, Joint.Name)] {
        [
            // Torso
            (.leftShoulder, .rightShoulder),
            (.leftShoulder, .leftHip),
            (.rightShoulder, .rightHip),
            (.leftHip, .rightHip),
            
            // Left Arm
            (.leftShoulder, .leftElbow),
            (.leftElbow, .leftWrist),
            
            // Right Arm
            (.rightShoulder, .rightElbow),
            (.rightElbow, .rightWrist),
            
            // Legs
            (.leftHip, .leftKnee),
            (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee),
            (.rightKnee, .rightAnkle)
        ]
    }
}

public struct Joint: Sendable {
    public let name: Name
    public let position: CGPoint
    public let confidence: Float

    public init(name: Name, position: CGPoint, confidence: Float) {
        self.name = name
        self.position = position
        self.confidence = confidence
    }

    /// An enumeration of the body joints that this model can recognize.
    public enum Name: String, Hashable, Sendable {
        case leftShoulder, rightShoulder, leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle
        case leftElbow, rightElbow, leftWrist, rightWrist
    }
}

// MARK: - Data Mapping
struct PoseMapper {
    static func map(_ observations: [VNHumanBodyPoseObservation]) -> [Pose] {
        return observations.compactMap { observation in
            guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
                return nil
            }
            
            var joints: [Joint.Name: Joint] = [:]
            for (visionPointKey, recognizedPoint) in recognizedPoints where recognizedPoint.confidence > 0.1 {
                guard let jointName = Joint.Name(from: visionPointKey.rawValue) else { continue }
                
                let joint = Joint(
                    name: jointName,
                    position: CGPoint(x: recognizedPoint.location.x, y: recognizedPoint.location.y),
                    confidence: recognizedPoint.confidence
                )
                joints[jointName] = joint
            }
            
            return Pose(joints: joints)
        }
    }
}

private extension Joint.Name {
    /// Creates a `Joint.Name` from a Vision framework `VNRecognizedPointKey`.
    init?(from visionPointKey: VNRecognizedPointKey) {
        switch visionPointKey {
        // Existing joints
        case .bodyLandmarkKeyLeftShoulder: self = .leftShoulder
        case .bodyLandmarkKeyRightShoulder: self = .rightShoulder
        case .bodyLandmarkKeyLeftHip: self = .leftHip
        case .bodyLandmarkKeyRightHip: self = .rightHip
        case .bodyLandmarkKeyLeftKnee: self = .leftKnee
        case .bodyLandmarkKeyRightKnee: self = .rightKnee
        case .bodyLandmarkKeyLeftAnkle: self = .leftAnkle
        case .bodyLandmarkKeyRightAnkle: self = .rightAnkle
        case .bodyLandmarkKeyLeftElbow: self = .leftElbow
        case .bodyLandmarkKeyRightElbow: self = .rightElbow
        case .bodyLandmarkKeyLeftWrist: self = .leftWrist
        case .bodyLandmarkKeyRightWrist: self = .rightWrist
            
        default: return nil // ignore other joints(neck or head).
        }
    }
}


// MARK: - Vision Request Handling Abstraction

public protocol VisionPerforming: Sendable {
    func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer) throws
}

public struct DefaultVisionPerformer: VisionPerforming {
    public init() {}
    public func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer) throws {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform(requests)
    }
}


// MARK: - Pose Estimator Service

public protocol PoseEstimatorProtocol: Sendable {
    func estimatePoses(on pixelBuffer: CVPixelBuffer) async throws -> [Pose]
}

public final class VisionPoseEstimator: PoseEstimatorProtocol {
    private let visionPerformer: VisionPerforming
    
    public init(visionPerformer: VisionPerforming = DefaultVisionPerformer()) {
        self.visionPerformer = visionPerformer
    }
    
    public func estimatePoses(on pixelBuffer: CVPixelBuffer) async throws -> [Pose] {
        let request = VNDetectHumanBodyPoseRequest()
        
        try visionPerformer.perform([request], on: pixelBuffer)
        
        guard let observations = request.results else {
            return []
        }
        return PoseMapper.map(observations)
    }
}

