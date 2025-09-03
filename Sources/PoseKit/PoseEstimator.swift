import Foundation
import Vision
import CoreGraphics

// MARK: - Domain-Specific Data Models

/// Represents a detected human pose as a collection of named joints.
/// This struct is part of the app's domain model and is independent of the Vision framework.
public struct Pose: Sendable {
    public let joints: [Joint.Name: Joint]
    
    public init(joints: [Joint.Name : Joint]) {
        self.joints = joints
    }
}

/// Represents a single joint with its position and the model's confidence in its detection.
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
    }
}

// MARK: - Data Mapping

/// A utility responsible for mapping data from Vision framework types to the app's domain models.
struct PoseMapper {
    /// Maps an array of Vision observations to an array of `Pose` objects.
    static func map(_ observations: [VNHumanBodyPoseObservation]) -> [Pose] {
        return observations.compactMap { observation in
            guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
                return nil
            }
            
            var joints: [Joint.Name: Joint] = [:]
            // Iterate over the dictionary of recognized points.
            for (visionPointKey, recognizedPoint) in recognizedPoints where recognizedPoint.confidence > 0.1 {
                // Maps the Vision point key
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
    /// This initializer uses the older, deprecated keys as a workaround for the build issue.
    init?(from visionPointKey: VNRecognizedPointKey) {
        switch visionPointKey {
        case .bodyLandmarkKeyLeftShoulder: self = .leftShoulder
        case .bodyLandmarkKeyRightShoulder: self = .rightShoulder
        case .bodyLandmarkKeyLeftHip: self = .leftHip
        case .bodyLandmarkKeyRightHip: self = .rightHip
        case .bodyLandmarkKeyLeftKnee: self = .leftKnee
        case .bodyLandmarkKeyRightKnee: self = .rightKnee
        case .bodyLandmarkKeyLeftAnkle: self = .leftAnkle
        case .bodyLandmarkKeyRightAnkle: self = .rightAnkle
        default: return nil
        }
    }
}


// MARK: - Vision Request Handling Abstraction

/// Defines a generic interface for performing Vision requests.
public protocol VisionPerforming: Sendable {
    func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer) throws
}

/// The default implementation of `VisionPerforming` that uses the real `VNImageRequestHandler`.
public struct DefaultVisionPerformer: VisionPerforming {
    public init() {}
    
    public func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer) throws {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform(requests)
    }
}


// MARK: - Pose Estimator Service

public protocol PoseEstimatorProtocol: Sendable {
    /// Estimates human poses from a given video frame.
    /// - Parameter pixelBuffer: The `CVPixelBuffer` of the video frame to analyze.
    /// - Returns: An array of `Pose` objects, one for each person detected.
    func estimatePoses(on pixelBuffer: CVPixelBuffer) async throws -> [Pose]
}

/// A concrete implementation of `PoseEstimatorProtocol` that uses Apple's Vision framework.
public final class VisionPoseEstimator: PoseEstimatorProtocol {
    
    private let visionPerformer: VisionPerforming
    
    /// Initializes the estimator with a Vision request performer.
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

