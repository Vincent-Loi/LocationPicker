//
//  LocationPickerViewController.swift
//  LocationPicker
//
//  Created by Almas Sapargali on 7/29/15.
//  Copyright (c) 2015 almassapargali. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

public class TargetView: UIView {
    
}

open class LocationPickerViewController: UIViewController {
	struct CurrentLocationListener {
		let once: Bool
		let action: (CLLocation) -> ()
	}
	
    public var completion: ((Location?) -> ())?
    public var cancelled: (() -> ())?
	
	// region distance to be used for creation region when user selects place from search results
	public var resultRegionDistance: CLLocationDistance = 600
	
	/// default: true
	public var showCurrentLocationButton = true
	
	/// default: true
	public var showCurrentLocationInitially = true
	
	/// see `region` property of `MKLocalSearchRequest`
	/// default: false
	public var useCurrentLocationAsHint = false
	
	/// default: "Search or enter an address"
	public var searchBarPlaceholder = "Search or enter an address"
	
	/// default: "Search History"
    public var searchHistoryLabel = "Search History"
    
    public var sendCurrentLocationText = "Send your current location"
    
    /// default: "Select"
    public var selectButtonTitle = "Send"
    
    public var sendUserLocationEnabled = true
    
    public var buttonBackgroundColor: UIColor = .red
    public var buttonTitleColor: UIColor = .white
	
	lazy public var currentLocationButtonBackground: UIColor = {
        return .white
//		if let navigationBar = self.navigationController?.navigationBar,
//			let barTintColor = navigationBar.barTintColor {
//				return barTintColor
//		} else { return .white }
	}()
    
    /// default: .Minimal
    public var searchBarStyle: UISearchBarStyle = .minimal

	/// default: .Default
	public var statusBarStyle: UIStatusBarStyle = .default
	
	public var mapType: MKMapType = .standard {
		didSet {
			if isViewLoaded {
				mapView.mapType = mapType
			}
		}
	}
	
	public var location: Location? {
		didSet {
			if isViewLoaded {
				searchBar.text = location.flatMap({ $0.title }) ?? ""
				updateAnnotation()
			}
		}
	}
    
    public var pinColor: MKPinAnnotationColor = .red
	
	static let SearchTermKey = "SearchTermKey"
	
	let historyManager = SearchHistoryManager()
	let locationManager = CLLocationManager()
	let geocoder = CLGeocoder()
	var localSearch: MKLocalSearch?
	var searchTimer: Timer?
    var closeButton: UIBarButtonItem!
	
	var currentLocationListeners: [CurrentLocationListener] = []
	
	var mapView: MKMapView!
	var locationButton: UIButton?
    var sendLocationView: UIButton?
	
	lazy var results: LocationSearchResultsViewController = {
		let results = LocationSearchResultsViewController()
		results.onSelectLocation = { [weak self] in self?.selectedLocation($0) }
		results.searchHistoryLabel = self.searchHistoryLabel
		return results
	}()
	
	lazy var searchController: UISearchController = {
		let search = UISearchController(searchResultsController: self.results)
		search.searchResultsUpdater = self
		search.hidesNavigationBarDuringPresentation = false
		return search
	}()
	
	lazy var searchBar: UISearchBar = {
		let searchBar = self.searchController.searchBar
		searchBar.searchBarStyle = self.searchBarStyle
		searchBar.placeholder = self.searchBarPlaceholder
		return searchBar
	}()
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTimer?.invalidate()
        localSearch?.cancel()
        geocoder.cancelGeocode()
    }
    
    let defaultBlue = UIColor(red: 14/255, green: 122/255, blue: 254/255, alpha: 1.0)

	
	open override func loadView() {
		mapView = MKMapView(frame: UIScreen.main.bounds)
		mapView.mapType = mapType
		view = mapView
        navigationController?.navigationBar.tintColor = defaultBlue
		navigationController?.navigationBar.barTintColor = currentLocationButtonBackground
		if showCurrentLocationButton {
			let button = UIButton(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
			button.backgroundColor = .white
			button.layer.masksToBounds = true
			button.layer.cornerRadius = 16
            button.contentEdgeInsets = UIEdgeInsetsMake(2, 2, 2, 2)
			let bundle = Bundle(for: LocationPickerViewController.self)
			button.setImage(UIImage(named: "located", in: bundle, compatibleWith: nil), for: UIControlState())
			button.addTarget(self, action: #selector(LocationPickerViewController.currentLocationPressed),
			                 for: .touchUpInside)
			view.addSubview(button)
			locationButton = button
            
		}
        
        if sendUserLocationEnabled {
//            let bundle = Bundle(for: LocationPickerViewController.self)
//
//            
//            let sendLocationView: SendCurrentLocation = bundle.loadNibNamed("SendCurrentLocation", owner: nil, options: nil)?.first as! SendCurrentLocation
            
            let sendLocationView = UIButton(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 50))
            sendLocationView.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 248/255, alpha: 0.9)
            sendLocationView.setTitleColor(defaultBlue, for: .normal)
            sendLocationView.setTitle(sendCurrentLocationText, for: .normal)
            sendLocationView.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            sendLocationView.contentHorizontalAlignment = .left
            sendLocationView.imageEdgeInsets.left = 15
            sendLocationView.titleEdgeInsets.left = 20
            let bundle = Bundle(for: LocationPickerViewController.self)
            sendLocationView.setImage(UIImage(named: "icoCurrentLocation", in: bundle, compatibleWith: nil), for: UIControlState())
            sendLocationView.addTarget(self, action: #selector(LocationPickerViewController.sendCurrentLocation),
                             for: .touchUpInside)
            
            view.addSubview(sendLocationView)
            self.sendLocationView = sendLocationView
        }

	}
    
    func sendCurrentLocation() {
        let listener = CurrentLocationListener(once: true) { [weak self] location in
            print("here")
            
            self?.retrieveAddress(location: location)
            //self?.completion?(self?.location)
            //self?.dismissSelf()
        }
        
        self.currentLocationListeners.append(listener)
        //
        self.getCurrentLocation()
        self.showCurrentLocation()

    }
	
	open override func viewDidLoad() {
		super.viewDidLoad()
		
		locationManager.delegate = self
		mapView.delegate = self
		searchBar.delegate = self
		
		// gesture recognizer for adding by tap
        let locationSelectGesture = UILongPressGestureRecognizer(
            target: self, action: #selector(addLocation(_:)))
        locationSelectGesture.delegate = self
		mapView.addGestureRecognizer(locationSelectGesture)

		// search
		navigationItem.titleView = searchBar
		definesPresentationContext = true
		
		// user location
		mapView.userTrackingMode = .none
		mapView.showsUserLocation = showCurrentLocationInitially || showCurrentLocationButton
		
		if useCurrentLocationAsHint {
			getCurrentLocation()
		}
        
        //set close button on left if modal
        if self.isBeingPresented {
            closeButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(closeTapped))
            navigationItem.rightBarButtonItem = closeButton
        }
	}
    
    func closeTapped() {
        cancelled?()
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

	open override var preferredStatusBarStyle : UIStatusBarStyle {
		return statusBarStyle
	}
	
	var presentedInitialLocation = false
	
	open override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if let button = locationButton {
			button.frame.origin = CGPoint(
				x: view.frame.width - button.frame.width - 16,
				y: view.frame.height - button.frame.height - 70
			)
		}
        if let sendButton = sendLocationView {
            sendButton.frame.origin = CGPoint(
                x: 0,
                y: view.frame.height - sendButton.frame.height
            )
        }
		
		// setting initial location here since viewWillAppear is too early, and viewDidAppear is too late
		if !presentedInitialLocation {
			setInitialLocation()
			presentedInitialLocation = true
		}
	}
	
	func setInitialLocation() {
		if let location = location {
			// present initial location if any
			self.location = location
			showCoordinates(location.coordinate, animated: false)
		} else if showCurrentLocationInitially {
			showCurrentLocation(false)
		}
	}
	
	func getCurrentLocation() {
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
	func currentLocationPressed() {
		showCurrentLocation()
	}
	
	func showCurrentLocation(_ animated: Bool = true) {
		let listener = CurrentLocationListener(once: true) { [weak self] location in
			self?.showCoordinates(location.coordinate, animated: animated)
		}
		currentLocationListeners.append(listener)
        //
		getCurrentLocation()
	}
	
	func updateAnnotation() {
		mapView.removeAnnotations(mapView.annotations)
		if let location = location {
			mapView.addAnnotation(location)
			mapView.selectAnnotation(location, animated: true)
		}
	}
	
	func showCoordinates(_ coordinate: CLLocationCoordinate2D, animated: Bool = true) {
		let region = MKCoordinateRegionMakeWithDistance(coordinate, resultRegionDistance, resultRegionDistance)
		mapView.setRegion(region, animated: animated)
	}
}

extension LocationPickerViewController: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.first else { return }
        currentLocationListeners.forEach { $0.action(location) }
		currentLocationListeners = currentLocationListeners.filter { !$0.once }
		manager.stopUpdatingLocation()
	}
}

// MARK: Searching

extension LocationPickerViewController: UISearchResultsUpdating {
    
	public func updateSearchResults(for searchController: UISearchController) {
		guard let term = searchController.searchBar.text else { return }
		
		searchTimer?.invalidate()

		let searchTerm = term.trimmingCharacters(in: CharacterSet.whitespaces)
		
		if searchTerm.isEmpty {
			results.locations = historyManager.history()
			results.isShowingHistory = true
			results.tableView.reloadData()
		} else {
			// clear old results
			showItemsForSearchResult(nil)
			
			searchTimer = Timer.scheduledTimer(timeInterval: 0.2,
				target: self, selector: #selector(LocationPickerViewController.searchFromTimer(_:)),
				userInfo: [LocationPickerViewController.SearchTermKey: searchTerm],
				repeats: false)
		}
	}
	
	func searchFromTimer(_ timer: Timer) {
		guard let userInfo = timer.userInfo as? [String: AnyObject],
			let term = userInfo[LocationPickerViewController.SearchTermKey] as? String
			else { return }
		
		let request = MKLocalSearchRequest()
		request.naturalLanguageQuery = term
		
		if let location = locationManager.location, useCurrentLocationAsHint {
			request.region = MKCoordinateRegion(center: location.coordinate,
				span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
		}
		
		localSearch?.cancel()
		localSearch = MKLocalSearch(request: request)
		localSearch!.start { response, _ in
			self.showItemsForSearchResult(response)
		}
	}
	
	func showItemsForSearchResult(_ searchResult: MKLocalSearchResponse?) {
		results.locations = searchResult?.mapItems.map { Location(name: $0.name, placemark: $0.placemark) } ?? []
		results.isShowingHistory = false
		results.tableView.reloadData()
	}
	
	func selectedLocation(_ location: Location) {
		// dismiss search results
		dismiss(animated: true) {
			// set location, this also adds annotation
			self.location = location
			self.showCoordinates(location.coordinate)
			
			self.historyManager.addToHistory(location)
		}
	}
}

// MARK: Selecting location with gesture

extension LocationPickerViewController {
	func addLocation(_ gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == .began {
			let point = gestureRecognizer.location(in: mapView)
			let coordinates = mapView.convert(point, toCoordinateFrom: mapView)
			let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
			
			// add point annotation to map
			let annotation = MKPointAnnotation()
			annotation.coordinate = coordinates
			mapView.addAnnotation(annotation)
			
            retrieveAddress(location: location)
			geocoder.cancelGeocode()
			geocoder.reverseGeocodeLocation(location) { response, error in
				if let error = error as? NSError, error.code != 10 { // ignore cancelGeocode errors
					// show error and remove annotation
					let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
					alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in }))
					self.present(alert, animated: true) {
						self.mapView.removeAnnotation(annotation)
					}
				} else if let placemark = response?.first {
					// get POI name from placemark if any
					let name = placemark.areasOfInterest?.first
					
					// pass user selected location too
					self.location = Location(name: name, location: location, placemark: placemark)
				}
			}
		}
	}
    
    func retrieveAddress(location: CLLocation, annotation: MKPointAnnotation? = nil) {
        // clean location, cleans out old annotation too
        self.location = nil
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { response, error in
            if let error = error {
                // show error and remove annotation
//                let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in }))
//                self.present(alert, animated: true) {
//                    if let annotation = annotation {
//                        self.mapView.removeAnnotation(annotation)
//                    }
//                }
            } else if let placemark = response?.first {
                // get POI name from placemark if any
                let name = placemark.name
                
                // pass user selected location too
                self.location = Location(name: name, location: location, placemark: placemark)
            }
        }
    }
}

// MARK: MKMapViewDelegate

extension LocationPickerViewController: MKMapViewDelegate {
	public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if annotation is MKUserLocation { return nil }
		
		let pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
		pin.pinColor = pinColor
		// drop only on long press gesture
		let fromLongPress = annotation is MKPointAnnotation
		pin.animatesDrop = fromLongPress
		pin.rightCalloutAccessoryView = selectLocationButton()
		pin.canShowCallout = !fromLongPress
		return pin
	}
    
	func selectLocationButton() -> UIButton {
		let button = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 50))
		button.setTitle(selectButtonTitle, for: UIControlState())
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = buttonBackgroundColor
		button.setTitleColor(buttonTitleColor, for: .normal)
		return button
	}
	
	public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		completion?(location)
		dismissSelf()
	}
    
    func dismissSelf() {
        if let navigation = navigationController, navigation.viewControllers.count > 1 {
            navigation.popViewController(animated: true)
        } else {
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
	
	public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
		let pins = mapView.annotations.filter { $0 is MKPinAnnotationView }
		assert(pins.count <= 1, "Only 1 pin annotation should be on map at a time")

        if let userPin = views.first(where: { $0.annotation is MKUserLocation }) {
            userPin.canShowCallout = false
        }
	}
}

extension LocationPickerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: UISearchBarDelegate

extension LocationPickerViewController: UISearchBarDelegate {
	public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		// dirty hack to show history when there is no text in search bar
		// to be replaced later (hopefully)
		if let text = searchBar.text, text.isEmpty {
			searchBar.text = " "
		}
	}
	
	public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		// remove location if user presses clear or removes text
		if searchText.isEmpty {
			location = nil
			searchBar.text = " "
		}
    }
    
    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        navigationItem.rightBarButtonItem = nil
        return true
    }
    
    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        navigationItem.rightBarButtonItem = closeButton
    }
}
