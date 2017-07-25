//
//  ViewController.swift
//  PokeMap
//
//  Created by Danny Luong on 7/19/17.
//  Copyright © 2017 dnylng. All rights reserved.
//

import UIKit
import MapKit
import GeoFire
import FirebaseDatabase

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var mapHasCenteredOnce = false
    var geoFire: GeoFire!
    var geoFireRef: DatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        mapView.userTrackingMode = MKUserTrackingMode.follow

        // Create a reference to the data base and init GeoFire with that database reference
        geoFireRef = Database.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
    }

    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }
    
    func locationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let location = userLocation.location {
            if !mapHasCenteredOnce {
                centerMapOnLocation(location: location)
                mapHasCenteredOnce = true
            }
        }
    }
    
    // Whenever addAnnotation is called, this func will be called to set up that annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView: MKAnnotationView?
        let annotationId = "Pokemon"
        
        if annotation.isKind(of: MKUserLocation.self) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
        } else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annotationId) {
            // Reuse annotation if needed, create the annotation it self if we can't
            annotationView = deqAnno
            annotationView?.annotation = annotation
        } else {
            let newAnnoView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationId)
            newAnnoView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = newAnnoView
        }
        
        // Make sure annotationView is not nil so that you can customize it
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
            // Popup
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokeId)")
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        }
        
        return annotationView
    }
    
    func createSighting(forLocation location: CLLocation, withPokemon pokeId: Int) {
        geoFire.setLocation(location, forKey: "\(pokeId)")
    }
    
    func showSightingsOnMap(location: CLLocation) {
        let circleQuery = geoFire!.query(at: location, withRadius: 2.5)
        
        _ = circleQuery?.observe(GFEventType.keyEntered, with: { (key, location) in
            if let key = key, let location = location {
                let annotation = PokeAnnotation(coordinate: location.coordinate, pokeId: Int(key)!)
                self.mapView.addAnnotation(annotation)
            }
        })
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        showSightingsOnMap(location: loc)
    }
    
    // Handles the button in the annotation
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        // Navigate to pokemon through apple maps
        if let anno = view.annotation as? PokeAnnotation {
            // Starting placemark
            let place = MKPlacemark(coordinate: anno.coordinate)
            
            // Destination, or where the pokemon is located
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            
            // How much of the map do you want to show
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            // Default options for the map
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking] as [String : Any]
            
            // Open the map with directions to the pokemon
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }
    
    @IBAction func spotRandomPokemon(_ sender: Any) {
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        let rand = arc4random_uniform(151) + 1
        
        createSighting(forLocation: loc, withPokemon: Int(rand))
    }
    
}

