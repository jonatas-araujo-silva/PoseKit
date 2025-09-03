import Foundation
import CoreGraphics

// MARK: - Pose Smoothing Protocol

/// Defines a generic interface for a strategy that smooths pose data over time.
/// Allows different smoothing algorithms to be used interchangeably.
public protocol PoseSmoothing: Sendable {
    /// Smooths a new pose based on the previously smoothed pose.
    /// - Parameters:
    ///   - newPose: The new `Pose` object detected in the current frame.
    ///   - previousPose: The smoothed `Pose` from the previous frame, if available.
    /// - Returns: A new `Pose` with smoothed joint positions.
    func smooth(newPose: Pose, previousPose: Pose?) -> Pose
}

// MARK: - Concrete Smoothing Implementation

/// A concrete implementation of `PoseSmoothing` that uses an Exponential Moving Average (EMA) algorithm.
public final class ExponentialMovingAverageSmoother: PoseSmoothing {

    /// The smoothing factor, typically called alpha. A lower value results in more smoothing
    /// but introduces more latency. A value of 1.0 would result in no smoothing.
    private let alpha: CGFloat
    
    /// Initializes the smoother with a specific smoothing factor.
    /// - Parameter smoothingFactor: A value between 0.0 and 1.0 that controls the degree of smoothing.
    public init(smoothingFactor: CGFloat = 0.15) {
        // Clamp the alpha value to the valid range [0.0, 1.0] to ensure correct behavior.
        self.alpha = max(0.0, min(1.0, smoothingFactor))
    }

    public func smooth(newPose: Pose, previousPose: Pose?) -> Pose {
        guard let previousPose = previousPose else {
            // If there is no previous pose to average with, return the new pose directly.
            return newPose
        }
        
        var smoothedJoints: [Joint.Name: Joint] = [:]

        // Iterate through all joints in the newly detected pose.
        for (jointName, newJoint) in newPose.joints {
            guard let previousJoint = previousPose.joints[jointName] else {
                // If this joint was not present in the previous frame, it cannot be smoothed.
                smoothedJoints[jointName] = newJoint
                continue
            }

            // Apply the Exponential Moving Average formula to the joint's position.
            let smoothedPosition = CGPoint(
                x: (newJoint.position.x * alpha) + (previousJoint.position.x * (1 - alpha)),
                y: (newJoint.position.y * alpha) + (previousJoint.position.y * (1 - alpha))
            )
            
            // Create a new joint using the smoothed position but preserving the original confidence score.
            let smoothedJoint = Joint(
                name: newJoint.name,
                position: smoothedPosition,
                confidence: newJoint.confidence
            )
            smoothedJoints[jointName] = smoothedJoint
        }

        return Pose(joints: smoothedJoints)
    }
}
