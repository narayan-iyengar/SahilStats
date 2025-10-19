//
//  PlayerTracker.swift
//  SahilStats
//
//  Track identified player across video frames using Vision
//

import Foundation
import Vision
import UIKit
import CoreImage

class PlayerTracker {
    static let shared = PlayerTracker()

    private init() {}

    enum TrackingError: Error {
        case noPlayersDetected
        case trackingFailed(String)
    }

    /// Detect all people in a frame and return them for manual selection
    func detectPeopleForSelection(in frame: VideoFrame) async throws -> [DetectedPerson] {
        debugPrint("🔍 Detecting people for manual selection at \(String(format: "%.1f", frame.timestamp))s...")

        guard let cgImage = frame.image.cgImage else {
            throw TrackingError.trackingFailed("Could not get CGImage from frame")
        }

        // Use simpler rectangle detection (more reliable than pose)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let detectRequest = VNDetectHumanRectanglesRequest()

        do {
            try requestHandler.perform([detectRequest])
        } catch {
            throw TrackingError.trackingFailed("Person detection failed: \(error.localizedDescription)")
        }

        guard let observations = detectRequest.results, !observations.isEmpty else {
            debugPrint("   ⚠️ No people detected in frame")
            return []
        }

        debugPrint("   ✅ Detected \(observations.count) person(s)")

        // Convert to DetectedPerson objects
        var detectedPeople: [DetectedPerson] = []

        for (index, observation) in observations.enumerated() {
            // Get upper body region (for jersey visibility)
            let bbox = observation.boundingBox

            let person = DetectedPerson(
                id: index,
                boundingBox: bbox,
                bodyPoints: [:], // Not using pose detection here
                confidence: observation.confidence,
                frame: frame
            )

            detectedPeople.append(person)
        }

        return detectedPeople
    }

    /// Track a selected person across multiple frames
    func trackPlayer(
        initialPerson: DetectedPerson,
        throughFrames frames: [VideoFrame],
        progress: @escaping (Double, Int) -> Void
    ) async throws -> [DetectedPerson] {
        debugPrint("🎯 Starting player tracking...")
        debugPrint("   Initial bounding box: \(initialPerson.boundingBox)")
        debugPrint("   Tracking through \(frames.count) frames")

        var trackedPeople: [DetectedPerson] = []

        // Create a single tracking request that will be reused (CRITICAL FIX)
        // VNTrackObjectRequest must be reused across frames - creating new ones exceeds Vision's tracker limit
        var trackingRequest: VNTrackObjectRequest? = nil
        var lastSuccessfulBox = initialPerson.boundingBox

        for (index, frame) in frames.enumerated() {
            guard let cgImage = frame.image.cgImage else {
                continue
            }

            // Create sequence request handler for this frame
            let requestHandler = VNSequenceRequestHandler()

            do {
                // On first frame or after re-detection, create new tracking request
                if trackingRequest == nil {
                    trackingRequest = VNTrackObjectRequest(
                        detectedObjectObservation: VNDetectedObjectObservation(boundingBox: lastSuccessfulBox)
                    )
                    trackingRequest?.trackingLevel = .accurate
                }

                // Perform tracking on this frame using the reused request
                try requestHandler.perform([trackingRequest!], on: cgImage)

                if let observation = trackingRequest?.results?.first as? VNDetectedObjectObservation,
                   observation.confidence > 0.5 {

                    // Successfully tracked
                    let trackedPerson = DetectedPerson(
                        id: initialPerson.id,
                        boundingBox: observation.boundingBox,
                        bodyPoints: [:],
                        confidence: observation.confidence,
                        frame: frame
                    )

                    trackedPeople.append(trackedPerson)
                    lastSuccessfulBox = observation.boundingBox

                    if index % 20 == 0 {
                        debugPrint("   ✅ Frame \(index): Tracked (confidence: \(String(format: "%.2f", observation.confidence)))")
                    }
                } else {
                    // Lost tracking, try to re-detect
                    if let redetected = try? await redetectPerson(near: lastSuccessfulBox, in: frame) {
                        trackedPeople.append(redetected)
                        lastSuccessfulBox = redetected.boundingBox

                        // Reset tracking request to start fresh from new position
                        trackingRequest = nil

                        if index % 20 == 0 {
                            debugPrint("   🔄 Frame \(index): Re-detected after tracking loss")
                        }
                    } else {
                        // Complete tracking loss - reset tracker
                        trackingRequest = nil

                        if index % 20 == 0 {
                            debugPrint("   ⚠️ Frame \(index): Lost tracking")
                        }
                    }
                }
            } catch {
                // On error, try to re-detect and reset tracker
                if let redetected = try? await redetectPerson(near: lastSuccessfulBox, in: frame) {
                    trackedPeople.append(redetected)
                    lastSuccessfulBox = redetected.boundingBox
                    trackingRequest = nil // Reset for next frame

                    if index % 20 == 0 {
                        debugPrint("   🔄 Frame \(index): Recovered from error via re-detection")
                    }
                } else {
                    trackingRequest = nil

                    if index % 20 == 0 {
                        debugPrint("   ⚠️ Frame \(index): Tracking error - \(error.localizedDescription)")
                    }
                }
            }

            // Report progress
            let progressValue = Double(index + 1) / Double(frames.count)
            await MainActor.run {
                progress(progressValue, trackedPeople.count)
            }
        }

        debugPrint("✅ Tracking complete!")
        debugPrint("   Successfully tracked in \(trackedPeople.count)/\(frames.count) frames")
        debugPrint("   Success rate: \(String(format: "%.1f", Double(trackedPeople.count) / Double(frames.count) * 100))%")

        return trackedPeople
    }

    /// Try to re-detect person near last known position
    private func redetectPerson(near lastBox: CGRect, in frame: VideoFrame) async throws -> DetectedPerson? {
        let people = try await detectPeopleForSelection(in: frame)

        // Find person closest to last known position
        let lastCenter = CGPoint(
            x: lastBox.midX,
            y: lastBox.midY
        )

        var closestPerson: DetectedPerson?
        var closestDistance: CGFloat = .infinity

        for person in people {
            let personCenter = CGPoint(
                x: person.boundingBox.midX,
                y: person.boundingBox.midY
            )

            let distance = hypot(
                personCenter.x - lastCenter.x,
                personCenter.y - lastCenter.y
            )

            if distance < closestDistance {
                closestDistance = distance
                closestPerson = person
            }
        }

        // Only accept if reasonably close (within 0.3 normalized distance)
        if closestDistance < 0.3, let person = closestPerson {
            return person
        }

        return nil
    }

    /// Extract thumbnail of detected person for UI display
    func extractThumbnail(for person: DetectedPerson, targetSize: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let cgImage = person.frame.image.cgImage else {
            return nil
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Convert normalized bounding box to pixel coordinates
        // Vision coordinates: (0,0) is bottom-left, need to flip Y
        let bbox = person.boundingBox
        let x = bbox.origin.x * imageSize.width
        let y = (1 - bbox.origin.y - bbox.height) * imageSize.height // Flip Y
        let width = bbox.width * imageSize.width
        let height = bbox.height * imageSize.height

        let cropRect = CGRect(x: x, y: y, width: width, height: height)

        guard let croppedImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedImage)
    }
}
