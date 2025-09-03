import Foundation
import CoreGraphics

// MARK: - Data Structures

/// Represents a discrete piece of feedback related to a user's exercise form.
/// A enum designed to be easily extensible for different exercises.
public enum FormFeedback: Hashable, Sendable {
    case keepBackStraight
    case squatDeeper
    case goodForm

    /// A user-facing message describing the feedback.
    public var message: String {
        switch self {
        case .keepBackStraight:
            return "Keep your back straight to protect your spine."
        case .squatDeeper:
            return "Squat deeper to engage more muscles."
        case .goodForm:
            return "Excellent form! Keep it up."
        }
    }
    
    /// The name of a system symbol to visually represent the feedback in the UI.
    public var symbolName: String {
        switch self {
        case .keepBackStraight: "figure.stand.line.dotted.figure"
        case .squatDeeper: "arrow.down.to.line.compact"
        case .goodForm: "checkmark.circle.fill"
        }
    }
    
    /// indicates if the feedback is positive reinforcement.
    public var isPositive: Bool {
        self == .goodForm
    }
}


// MARK: - Exercise Rule Protocol

/// Defines the requirements for a single, reusable rule that can evaluate a human pose.
public protocol ExerciseRule: Sendable {
    /// The specific feedback to return if this rule's evaluation fails.
    var feedback: FormFeedback { get }
    
    /// Evaluates a given pose against the rule's criteria.
    /// - Parameter pose: The `Pose` object to evaluate.
    /// - Returns: `true` if the pose satisfies the rule, otherwise `false`.
    func evaluate(pose: Pose) -> Bool
}


// MARK: - Concrete Rule Implementations

/// A rule that checks if the back is kept relatively straight.
public struct BackStraightRule: ExerciseRule {
    public let feedback: FormFeedback = .keepBackStraight
    
    public init() {}
    
    public func evaluate(pose: Pose) -> Bool {
        guard let leftShoulder = pose.joints[.leftShoulder],
              let leftHip = pose.joints[.leftHip] else {
            // Not enough joints detected to make a determination, so pass the rule.
            return true
        }
        // A simple check assuming a side-on view: the shoulder should be vertically aligned with or behind the hip.
        return leftShoulder.position.y > leftHip.position.y
    }
}

/// A rule that checks if a squat is performed to sufficient depth.
public struct SquatDepthRule: ExerciseRule {
    public let feedback: FormFeedback = .squatDeeper

    public init() {}

    public func evaluate(pose: Pose) -> Bool {
        guard let leftHip = pose.joints[.leftHip],
              let leftKnee = pose.joints[.leftKnee] else {
            // Not enough joints detected to make a determination.
            return true
        }
        // For a deep squat, the hip joint should be at or below the level of the knee joint.
        return leftHip.position.y <= leftKnee.position.y
    }
}


// MARK: - Analysis Engine Protocol

/// Defines the requirements for an engine that analyzes a detected human pose
/// and returns actionable feedback based on a set of rules.
public protocol AnalysisEngineProtocol: Sendable {
    /// Analyzes a given pose against the engine's configured rules.
    /// - Parameter pose: The `Pose` object captured from a single frame.
    /// - Returns: An array of `FormFeedback` items for any rules that failed.
    func analyze(pose: Pose) -> [FormFeedback]
}


// MARK: - Rule-Based Analysis Engine Implementation

/// A concrete implementation of `AnalysisEngineProtocol` that evaluates a pose against an array of `ExerciseRule` objects.
public final class RuleBasedAnalysisEngine: AnalysisEngineProtocol {
    
    /// A set of rules to be evaluated against the pose.
    private let rules: [ExerciseRule]
    
    /// Initializes the engine with a specific set of exercise rules.
    /// - Parameter rules: An array of objects conforming to `ExerciseRule`.
    public init(rules: [ExerciseRule]) {
        self.rules = rules
    }
    
    /// A convenience factory method to create an engine pre-configured for squat analysis.
    public static func squatEngine() -> RuleBasedAnalysisEngine {
        return RuleBasedAnalysisEngine(rules: [
            BackStraightRule(),
            SquatDepthRule()
        ])
    }
    
    public func analyze(pose: Pose) -> [FormFeedback] {
        // Evaluate each rule and collect feedback for any that fail.
        let feedback = rules.compactMap { rule in
            return rule.evaluate(pose: pose) ? nil : rule.feedback
        }
        
        // If all rules passed, provide positive reinforcement.
        if feedback.isEmpty {
            return [.goodForm]
        } else {
            return feedback
        }
    }
}

