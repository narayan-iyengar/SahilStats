//
//  PlayerDetector.swift
//  SahilStats
//
//  Detect players in video frames using Apple Vision
//

import Foundation
import Vision
import UIKit
import CoreImage

class PlayerDetector {
    static let shared = PlayerDetector()

    private init() {}

    enum DetectionError: Error {
        case noPersonsDetected
        case targetPlayerNotFound
        case visionRequestFailed(String)
    }

    /// Detect all people in a frame using body pose detection
    func detectPeople(in frame: VideoFrame) async throws -> [DetectedPerson] {
        debugPrint("🔍 Detecting people in frame at \(String(format: "%.1f", frame.timestamp))s...")

        guard let cgImage = frame.image.cgImage else {
            throw DetectionError.visionRequestFailed("Could not get CGImage from frame")
        }

        // Create Vision request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Create body pose detection request
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([bodyPoseRequest])
        } catch {
            throw DetectionError.visionRequestFailed("Body pose detection failed: \(error.localizedDescription)")
        }

        guard let observations = bodyPoseRequest.results, !observations.isEmpty else {
            debugPrint("   ⚠️ No people detected in frame")
            return []
        }

        debugPrint("   ✅ Detected \(observations.count) person(s)")

        // Convert observations to DetectedPerson objects
        var detectedPeople: [DetectedPerson] = []

        for (index, observation) in observations.enumerated() {
            // Extract key body points
            var bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

            let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .neck,
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist,
                .leftHip, .rightHip,
                .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]

            for jointName in jointNames {
                if let point = try? observation.recognizedPoint(jointName), point.confidence > 0.3 {
                    bodyPoints[jointName] = point.location
                }
            }

            // Calculate bounding box from body points
            let boundingBox = calculateBoundingBox(from: bodyPoints)

            let person = DetectedPerson(
                id: index,
                boundingBox: boundingBox,
                bodyPoints: bodyPoints,
                confidence: observation.confidence,
                frame: frame
            )

            detectedPeople.append(person)
        }

        return detectedPeople
    }

    /// Detect jersey number using OCR in the upper body region
    func detectJerseyNumber(for person: DetectedPerson) async throws -> String? {
        debugPrint("   🔢 Detecting jersey number for person \(person.id)...")

        guard let cgImage = person.frame.image.cgImage else {
            return nil
        }

        // Create a cropped region focusing on upper torso (where jersey number usually is)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Convert normalized bounding box to pixel coordinates
        // Vision coordinates: (0,0) is bottom-left
        let bbox = person.boundingBox
        let x = bbox.origin.x * imageSize.width
        let y = (1 - bbox.origin.y - bbox.height) * imageSize.height // Flip Y coordinate
        let width = bbox.width * imageSize.width
        let height = bbox.height * imageSize.height

        // Focus on upper 40% of bounding box (chest area)
        let upperBodyHeight = height * 0.4
        let upperBodyRect = CGRect(
            x: x,
            y: y,
            width: width,
            height: upperBodyHeight
        )

        // Crop image to upper body region
        guard let croppedImage = cgImage.cropping(to: upperBodyRect) else {
            debugPrint("      ⚠️ Could not crop to upper body region")
            return nil
        }

        // Create Vision request handler for cropped region
        let requestHandler = VNImageRequestHandler(cgImage: croppedImage, options: [:])

        // Create text recognition request
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = false // Numbers don't need language correction

        do {
            try requestHandler.perform([textRequest])
        } catch {
            debugPrint("      ⚠️ OCR failed: \(error.localizedDescription)")
            return nil
        }

        guard let observations = textRequest.results, !observations.isEmpty else {
            debugPrint("      ⚠️ No text detected")
            return nil
        }

        // Look for single or double digit numbers
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string.trimmingCharacters(in: .whitespaces)

            // Check if it's a 1 or 2 digit number
            if let number = Int(text), number >= 0 && number <= 99 {
                debugPrint("      ✅ Found jersey number: #\(number) (confidence: \(String(format: "%.2f", topCandidate.confidence)))")
                return String(number)
            }
        }

        debugPrint("      ⚠️ No valid jersey number found")
        return nil
    }

    /// Detect jersey color (simplified approach using average color in torso region)
    func detectJerseyColor(for person: DetectedPerson) async throws -> JerseyColor? {
        debugPrint("   🎨 Detecting jersey color for person \(person.id)...")

        guard let cgImage = person.frame.image.cgImage else {
            return nil
        }

        // Get torso region (middle 60% height of bounding box)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let bbox = person.boundingBox

        let x = bbox.origin.x * imageSize.width
        let y = (1 - bbox.origin.y - bbox.height) * imageSize.height
        let width = bbox.width * imageSize.width
        let height = bbox.height * imageSize.height

        // Focus on torso (skip top 20%, take middle 60%)
        let torsoY = y + height * 0.2
        let torsoHeight = height * 0.6
        let torsoRect = CGRect(x: x, y: torsoY, width: width, height: torsoHeight)

        guard let croppedImage = cgImage.cropping(to: torsoRect) else {
            return nil
        }

        // Get average color
        let uiImage = UIImage(cgImage: croppedImage)
        guard let averageColor = uiImage.averageColor() else {
            return nil
        }

        // Classify color as black or white based on brightness
        var brightness: CGFloat = 0
        averageColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)

        let color: JerseyColor = brightness < 0.5 ? .black : .white
        debugPrint("      ✅ Detected color: \(color.rawValue) (brightness: \(String(format: "%.2f", brightness)))")

        return color
    }

    /// Calculate bounding box from body joint points
    private func calculateBoundingBox(from bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> CGRect {
        guard !bodyPoints.isEmpty else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }

        let points = Array(bodyPoints.values)
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }

        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }

        // Add some padding (10% on each side)
        let padding = 0.1
        let width = maxX - minX
        let height = maxY - minY
        let paddedMinX = max(0, minX - width * padding)
        let paddedMinY = max(0, minY - height * padding)
        let paddedWidth = min(1.0 - paddedMinX, width * (1 + 2 * padding))
        let paddedHeight = min(1.0 - paddedMinY, height * (1 + 2 * padding))

        return CGRect(x: paddedMinX, y: paddedMinY, width: paddedWidth, height: paddedHeight)
    }

    /// Find the target player (Sahil #3 in specified color) in a frame
    func findTargetPlayer(
        in frame: VideoFrame,
        targetNumber: String,
        targetColor: JerseyColor
    ) async throws -> DetectedPerson? {
        debugPrint("🎯 Looking for #\(targetNumber) in \(targetColor.rawValue) jersey...")

        // Detect all people
        let people = try await detectPeople(in: frame)

        guard !people.isEmpty else {
            return nil
        }

        // Try to identify each person
        for person in people {
            // Detect jersey number
            if let number = try await detectJerseyNumber(for: person),
               number == targetNumber {

                // Verify jersey color
                if let color = try await detectJerseyColor(for: person),
                   color == targetColor {
                    debugPrint("   ✅ Found target player: #\(number) in \(color.rawValue)")
                    return person
                }
            }
        }

        debugPrint("   ⚠️ Target player not found in this frame")
        return nil
    }
}

// MARK: - Supporting Types

struct DetectedPerson {
    let id: Int
    let boundingBox: CGRect // Normalized coordinates (0-1)
    let bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let confidence: Float
    let frame: VideoFrame

    /// Get specific body joint location
    func getJoint(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        return bodyPoints[name]
    }

    /// Check if person is in shooting pose (arms raised)
    var isShootingPose: Bool {
        guard let leftWrist = getJoint(.leftWrist),
              let rightWrist = getJoint(.rightWrist),
              let leftShoulder = getJoint(.leftShoulder),
              let rightShoulder = getJoint(.rightShoulder) else {
            return false
        }

        // Check if either wrist is above shoulder (simplified shooting detection)
        let leftArmRaised = leftWrist.y > leftShoulder.y
        let rightArmRaised = rightWrist.y > rightShoulder.y

        return leftArmRaised || rightArmRaised
    }
}

enum JerseyColor: String {
    case black = "BLACK"
    case white = "WHITE"
    case unknown = "UNKNOWN"
}

// MARK: - UIImage Extension for Average Color

extension UIImage {
    func averageColor() -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }

        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var rgba: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let red = CGFloat(rgba[0]) / 255.0
        let green = CGFloat(rgba[1]) / 255.0
        let blue = CGFloat(rgba[2]) / 255.0
        let alpha = CGFloat(rgba[3]) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
