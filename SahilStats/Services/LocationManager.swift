// File: SahilStats/Services/LocationManager.swift

import Foundation
import CoreLocation
import Combine
import SwiftUI
import MapKit // Add MapKit import
import Contacts // Add Contacts import for CNPostalAddress

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLoading = false
    @Published var error: LocationError?
    @Published var locationName: String = ""
    
    private let locationManager = CLLocationManager()
    // Replace CLGeocoder with MKLocalSearchCompleter (we'll use MKLocalSearch for reverse geocoding)
    
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
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    // MARK: - Public Methods
    
    func requestLocation() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationRequest()
        case .notDetermined:
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
        // Move the location services check to a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            guard CLLocationManager.locationServicesEnabled() else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = .unavailable
                }
                return
            }
            
            // Start location updates on main queue
            DispatchQueue.main.async {
                self.locationManager.startUpdatingLocation()
            }
        }
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isLoading {
                self.locationManager.stopUpdatingLocation()
                self.isLoading = false
                self.error = .timeout
            }
        }
    }
    
    // Updated reverse geocoding method using MapKit instead of CLGeocoder
    private func reverseGeocode(_ location: CLLocation) {
        let coordinate = location.coordinate
        
        // Create an MKLocalSearch request for reverse geocoding
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(coordinate.latitude), \(coordinate.longitude)"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        let search = MKLocalSearch(request: request)
        
        search.start { [weak self] (response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("MapKit reverse geocoding error: \(error)")
                DispatchQueue.main.async {
                    self.error = .geocodingFailed
                    self.isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                if let mapItem = response?.mapItems.first {
                    self.locationName = self.formatLocationName(from: mapItem)
                } else {
                    // Fallback to coordinate display if no results
                    self.locationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                }
                self.isLoading = false
            }
        }
    }

    // Updated to work with MKMapItem using modern iOS 26+ APIs
    private func formatLocationName(from mapItem: MKMapItem) -> String {
        var components: [String] = []
        
        // Use the map item's name first
        if let name = mapItem.name {
            components.append(name)
        }
        
        // Use addressRepresentations for modern iOS 26+ API
        if let addressReps = mapItem.addressRepresentations {
            // Use the full address from MKAddressRepresentations
            let _ = addressReps.fullAddress(includingRegion: true, singleLine: true)
        } else {
            // Fallback to placemark for older iOS versions or if addressRepresentations is not available
            let _ = mapItem.address
            
        }
        
        if !components.isEmpty {
            return components.joined(separator: ", ")
        }
        
        // Fallback to coordinates using the modern location property
        let coordinate = mapItem.location.coordinate
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
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
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLoading {
                startLocationRequest()
            }
        case .denied, .restricted:
            if isLoading {
                isLoading = false
                error = .denied
            }
        case .notDetermined:
            break
        @unknown default:
            if isLoading {
                isLoading = false
                error = .unavailable
            }
        }
    }
}
