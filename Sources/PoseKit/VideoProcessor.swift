import Foundation
import AVFoundation

// MARK: - Domain-Specific Data Models

/// A data structure that encapsulates the complete analysis results for a single video frame.
public struct FrameAnalysis: Sendable {
    /// The presentation timestamp of the frame within the video, in seconds.
    public let timestamp: TimeInterval
    
    /// An array of all `Pose` objects detected in the frame.
    public let poses: [Pose]
    
    /// An array of `FormFeedback` items generated from the analysis of the detected poses.
    public let feedback: [FormFeedback]
}

// MARK: - Frame Provider Abstraction

/// Defines the requirements for an object that can provide a stream of video frames from a source.
public protocol FrameProviding: Sendable {
    /// Provides a stream of sample buffers from a video asset at the given URL.
    /// - Parameter url: The URL of the video source.
    /// - Returns: An `AsyncThrowingStream` that yields a `CMSampleBuffer` for each frame.
    func frameStream(from url: URL) -> AsyncThrowingStream<CMSampleBuffer, Error>
}

/// A concrete implementation of `FrameProviding` that uses `AVAssetReader` to read frames from a video file.
public struct AVFoundationFrameProvider: FrameProviding {
    
    public init() {}
    
    public func frameStream(from url: URL) -> AsyncThrowingStream<CMSampleBuffer, Error> {
        return AsyncThrowingStream { continuation in
            Task(priority: .userInitiated) {
                do {
                    let asset = AVAsset(url: url)
                    let reader = try AVAssetReader(asset: asset)
                    
                    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                        continuation.finish(throwing: VideoProcessorError.noVideoTrackFound)

                        return
                    }
                    
                    let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
                        String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)
                    ])
                    
                    reader.add(trackOutput)
                    
                    guard reader.startReading() else {
                        continuation.finish(throwing: reader.error ?? VideoProcessorError.failedToStartReading)
                        return
                    }
                    
                    while let sampleBuffer = trackOutput.copyNextSampleBuffer(), !Task.isCancelled {
                        continuation.yield(sampleBuffer)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}


// MARK: - Video Processor Service

/// Defines the primary interface for a service that processes a video to produce frame-by-frame analysis.
public protocol VideoProcessing: Sendable {
    /// Processes a video from a given URL, orchestrating pose estimation and form analysis for each frame.
    /// - Parameter url: The `URL` of the video file to process.
    /// - Returns: An `AsyncThrowingStream` that yields a `FrameAnalysis` object for each processed frame.
    func processVideo(from url: URL) -> AsyncThrowingStream<FrameAnalysis, Error>
}

/// A concrete implementation of `VideoProcessing` that coordinates the entire analysis pipeline.
public final class VideoProcessor: VideoProcessing {
    
    private let frameProvider: FrameProviding
    private let poseEstimator: PoseEstimatorProtocol
    private let analysisEngine: AnalysisEngineProtocol
    
    /// Initializes the processor with its required dependencies.
    /// - Parameters:
    ///   - frameProvider: A service that provides video frames.
    ///   - poseEstimator: A service that estimates human poses from a frame.
    ///   - analysisEngine: A service that analyzes poses to generate feedback.
    public init(
        frameProvider: FrameProviding,
        poseEstimator: PoseEstimatorProtocol,
        analysisEngine: AnalysisEngineProtocol
    ) {
        self.frameProvider = frameProvider
        self.poseEstimator = poseEstimator
        self.analysisEngine = analysisEngine
    }
    
    public func processVideo(from url: URL) -> AsyncThrowingStream<FrameAnalysis, Error> {
        return AsyncThrowingStream { continuation in
            Task(priority: .userInitiated) {
                do {
                    for try await sampleBuffer in frameProvider.frameStream(from: url) {
                        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
                        
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                        
                        let poses = try await self.poseEstimator.estimatePoses(on: pixelBuffer)
                        
                        let allFeedback = poses.flatMap { self.analysisEngine.analyze(pose: $0) }
                        
                        let frameAnalysis = FrameAnalysis(timestamp: timestamp, poses: poses, feedback: allFeedback)
                        
                        continuation.yield(frameAnalysis)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Custom Errors

/// Defines specific errors that can occur during the video processing setup.
public enum VideoProcessorError: Error, LocalizedError {
    case noVideoTrackFound
    case failedToStartReading

    public var errorDescription: String? {
        switch self {
        case .noVideoTrackFound:
            return "A valid video track could not be found in the provided file."
        case .failedToStartReading:
            return "The asset reader failed to start processing video frames."
        }
    }
}
