// File: SahilStats/Services/LocationManager.swift

import Foundation
import CoreLocation
import Combine
import SwiftUI

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLoading = false
    @Published var error: LocationError?
    @Published var locationName: String = ""
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // MARK: - Added Properties for GameSetupView compatibility
    
    var canRequestLocation: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
    
    var shouldShowSettingsAlert: Bool {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
    
    enum LocationError: LocalizedError {
        case denied
        case restricted
        case unavailable
        case timeout
        case geocodingFailed
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .denied: return "Location access denied. Please enable in Settings."
            case .restricted: return "Location access is restricted on this device."
            case .unavailable: return "Location services are not available."
            case .timeout: return "Location request timed out. Please try again."
            case .geocodingFailed: return "Could not determine location name."
            case .networkError: return "Network error while getting location."
            }
        }
    }
    
    override init() {
        super.init()
        // We only set the delegate here. We won't check for status until it's requested.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    // MARK: - Public Methods
    
    func requestLocation() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        // Get the most current authorization status directly from the manager
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // If we already have permission, start the location request.
            startLocationRequest()
        case .notDetermined:
            // If permission hasn't been asked for, request it now.
            // The delegate will handle the response.
            locationManager.requestWhenInUseAuthorization()
        case .denied:
            isLoading = false
            error = .denied
        case .restricted:
            isLoading = false
            error = .restricted
        @unknown default:
            isLoading = false
            error = .unavailable
        }
    }
    
    // MARK: - Added Method for GameSetupView compatibility
    
    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func startLocationRequest() {
        guard CLLocationManager.locationServicesEnabled() else {
            isLoading = false
            error = .unavailable
            return
        }
        
        locationManager.requestLocation()
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isLoading {
                self.locationManager.stopUpdatingLocation()
                self.isLoading = false
                self.error = .timeout
            }
        }
    }
    
    // This is the stable, working version of the function using CLGeocoder
    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("CLGeocoder error: \(error)")
                DispatchQueue.main.async {
                    self.error = .geocodingFailed
                    self.isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self.locationName = self.formatLocationName(from: placemark)
                }
                self.isLoading = false
            }
        }
    }

    private func formatLocationName(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        } else if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if !components.isEmpty {
            return components.joined(separator: ", ")
        }
        
        let lat = placemark.location?.coordinate.latitude ?? 0
        let lon = placemark.location?.coordinate.longitude ?? 0
        return String(format: "%.4f, %.4f", lat, lon)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        manager.stopUpdatingLocation() // Stop updates to save power
        currentLocation = location
        reverseGeocode(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.error = .unavailable
            print("Location manager failed with error: \(error.localizedDescription)")
        }
    }
    
    // This delegate method is now the central point for handling authorization changes.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // If the user just granted permission and we were in the process of loading,
            // we can now start the location request.
            if isLoading {
                startLocationRequest()
            }
        case .denied, .restricted:
            // If the user denied permission, update the state.
            if isLoading {
                isLoading = false
                error = .denied
            }
        case .notDetermined:
            // This state is handled when the requestLocation button is tapped.
            break
        @unknown default:
            if isLoading {
                isLoading = false
                error = .unavailable
            }
        }
    }
}
