PoseKit
A Swift package for real-time human pose estimation and analysis, built on top of Apple's Vision framework.

Overview
PoseKit is designed to provide a high-level, protocol-oriented API for performing on-device human pose estimation. It decouples the low-level Vision framework implementation from the application's domain logic.

Whether you're building a fitness app, an interactive game, or an accessibility tool, PoseKit provides the foundational components to analyze human movement from a video feed.

Features
On-Device: All processing is done directly on the user's device, ensuring real-time performance and complete data privacy.

Modular: Built with a protocol-oriented design. The core components (pose estimation, analysis, video processing) are decoupled and can be replaced or extended.

Testable: The protocol-based architecture makes it easy to write unit tests and mock dependencies.

Real-Time: Designed to work with live or pre-recorded video streams for interactive experiences.

Extensible: Includes a rule-based engine for analyzing exercises that can be easily configured with new rules for different movements.

Architecture
PoseKit is built on a foundation of several key protocols to ensure a clean separation of concerns:

PoseEstimatorProtocol: Defines a service that can detect human poses in a video frame. The default implementation, VisionPoseEstimator, uses Apple's Vision framework.

AnalysisEngineProtocol: Defines a service that can analyze a Pose object against a set of rules. The RuleBasedAnalysisEngine is a concrete implementation that can be configured with any rules conforming to the ExerciseRule protocol.

VideoProcessing: Defines a service that orchestrates the entire pipeline, from reading video frames to producing frame-by-frame analysis.

Usage
Here's a basic example of how to set up and use the core components of PoseKit.

import PoseKit
import AVFoundation

// 1. Set up the analysis engine with the desired rules.
// PoseKit comes with pre-built rules for squat analysis.
let squatEngine = RuleBasedAnalysisEngine.squatEngine()

// 2. Set up the pose estimator.
// The default implementation uses Apple's Vision framework.
let poseEstimator = VisionPoseEstimator()

// 3. Set up the video processor with its dependencies.
let videoProcessor = VideoProcessor(
    frameProvider: AVFoundationFrameProvider(),
    poseEstimator: poseEstimator,
    analysisEngine: squatEngine
)

// 4. Process a video and receive a real-time stream of analysis results.
func analyzeVideo(at url: URL) async {
    let stream = videoProcessor.processVideo(from: url)
    do {
        for try await frameAnalysis in stream {
            print("Timestamp: \(frameAnalysis.timestamp)s, Feedback: \(frameAnalysis.feedback)")
        }
    } catch {
        print("An error occurred: \(error.localizedDescription)")
    }
}

Installation
You can add PoseKit to your Xcode project as a Swift Package dependency.

In Xcode, select File > Add Packages...

Paste the URL of your public PoseKit GitHub repository.

Follow the prompts to add the package to your app target.

# PoseKit
