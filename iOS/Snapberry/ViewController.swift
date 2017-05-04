//
//  ViewController.swift
//  Snapberry
//
//  Created by Adib Behjat on 4/29/17.
//  Copyright © 2017 AB. All rights reserved.
//
// Tutorials: https://gist.github.com/jrmullins/3e6bf1da189955565f88#file-viewcontroller-swift

import UIKit
import CoreLocation
import MapKit
import AVFoundation
import Firebase
import FirebaseDatabase

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    // Capture the necessary outlets
    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var theMap: MKMapView!
    
    // Text-to-speech component
    let synth = AVSpeechSynthesizer()
    var voiceAssist = AVSpeechUtterance(string: "")
    
    
    // Variable that will handle location management
    var manager:CLLocationManager!
    
    // Create an empty list of locations
    var myLocations: [CLLocation] = []
    
    // Create a variable that handles polylines
    var polyline: MKPolyline!
    
    // Global variables
    var result = [:] as [String: Any]
    var keySet = 0
    var firstCall = true as Bool
    var didUpdate = false as Bool
    var ref: FIRDatabaseReference!
    var scenesRef: FIRDatabaseReference!
    var latLoc: String!
    var lonLoc: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Connect with firebase
        self.ref = FIRDatabase.database().reference(withPath: "user-data").child("user_1")
        self.scenesRef = FIRDatabase.database().reference(withPath: "user-data/user_1/scenes")
        
        self.ref.observe(.value, with: { snapshot in
            
            // Capture the information from firebase
            if let dictionary = snapshot.value! as? [String: Any] {
                
                var max = 0 as Int
                
                // Capture the nested information
                if let scenes = dictionary["scenes"] as? [String: Any] {
                    
                    // access nested dictionary values by key
                    for (key,value) in scenes {
                        
                        // Find max
                        if (Int(key)! > max) {
                            max = Int(key)!
                            self.keySet = max
                            self.result = value as! [String : Any]
                        } // End of max
                        
                    } // End of for-loop
                    if (self.firstCall) {
                        self.result["description"] = "Starting Point"
                        self.firstCall = false
                    }
                    
                } // End of if let scenes
                
            } // End of if let dictionary
            
        }) // End of firebase observe
        
        
        // Listen for any new updates
        scenesRef.observe(.childAdded, with: { snapshot in
            // If it's not the first call, run this
            if (!self.firstCall) {
                
                // Capture the key that changed
                if (Int(snapshot.key)! > 0) {
                    
                    if let dictionary = snapshot.value! as? [String: Any] {
                        let message = dictionary["description"] as! String
                        self.result["description"] = message as String!
                        self.voiceAssist = AVSpeechUtterance(string: message)
                        self.voiceAssist.rate = 0.5
                        self.synth.speak(self.voiceAssist)
                        self.msgLabel.text = message
                    }
                    
                    // Append location to the data set
                    let updates = ["/scenes/\(snapshot.key)/location": ["lat":self.latLoc,"long":self.lonLoc]]
                    self.ref.updateChildValues(updates)
                    
                    
                }
            }
            self.didUpdate = true
        })
        
        // Location Manager Setup
        // Responsible for finding the user's current location
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        
        // Map view setup
        theMap.delegate = self
        theMap.showsUserLocation = true
        
    }
    
    // Location Manager Function
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let coord = locations[0].coordinate
        // Output the location detail
        latLoc = "\(coord.latitude)"
        lonLoc = "\(coord.longitude)"
        
        // Append the current location into the local DB
        myLocations.append(locations[0])
        
        // Assign the zooming
        let spanX = 0.020
        let spanY = 0.020
        
        // Define new map region
        let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate, span:MKCoordinateSpanMake(spanX, spanY))
        
        // Set the new region to the map. Do not animate the zoom (otherwise lag)
        theMap.setRegion(newRegion, animated: false)
        
        // If the array of locations if there are at least 2 points, create a line
        // to track the location and movement of the user
        if (myLocations.count > 1){
            
            // Get location 1
            let destinationIndex = myLocations.count - 1
            let c1 = myLocations[destinationIndex].coordinate
            
            // Get location 2
            let sourceIndex = myLocations.count - 2
            let c2 = myLocations[sourceIndex].coordinate
            
            // Annotation creator
            if (didUpdate) {
                
                // Update in database
                // ref.child(keySet).child("location").setValue()
                
                // Reset
                didUpdate = false
                
                // Annotate
                let anno = CustomPointAnnotation()
                
                // Set the coordinates
                anno.coordinate = locations[0].coordinate
                
                // Describe what happened
                anno.title = result["description"] as! String!
                
                // Place on the map
                theMap.addAnnotation(anno)
            }
            
            
            
            // Create a line called 'a'
            var a = [c1, c2]
            polyline = MKPolyline(coordinates: &a, count: a.count)
            
            // Add the line unto the map
            theMap.add(polyline)
        }
        
    } // End of location manager function
    
    // If the map just
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        if (myLocations.count == 1) {
            theMap.remove(polyline)
        }
        
    }
    
    
    // Even though we told the map that we want to line over it, the Map API is too
    // stupid to understand what's going on. Therefore, we have to create a renderer
    // to combine polygonal elements unto the map.
    // For this operation to work, we need to inherit the MKMapView delegation.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        // The first thing we wish to check is whether the overlay is of tyoe
        // MKPolyline (or simply a line), which will then process the work.
        if overlay is MKPolyline {
            
            // Create an object that contains rendering function
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            
            // Color of the line
            polylineRenderer.strokeColor = UIColor.init(red: 90/255.0, green: 200/255.0, blue: 250/255.0, alpha: 1.0)
            
            // Width of the line
            polylineRenderer.lineWidth = 4
            
            // Print that line on the map
            return polylineRenderer
        }
        
        // Return empty polynomial
        return MKPolylineRenderer()
    }
    
    
    // This mapView function is dedicated for annotation.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        // If the annotation is user's current location, do nothing
        if annotation is MKUserLocation {
            
            return nil
            
        } else {
            
            // else, let's add custom pin
            let reuseIdentifier = "pin"
            
            // Note that we're using a queue model in order to reuse the original annotation we placed
            // earlier. This method is implemented as means to minimize memory usage
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            // If there were no annotations in the view, create one
            if annotationView == nil {
                
                // Create the annotation and call out when pressed
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                annotationView?.canShowCallout = true
                
                // The info button on the callout for the annotation
                // let rightCalloutButton = UIButton(type: .detailDisclosure)
                // annotationView?.rightCalloutAccessoryView = rightCalloutButton
                
                
                
            // recycle the view
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image based on the emoji
            annotationView?.image = "👁‍🗨".image()
            
            return annotationView
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

// String extension to translate string (emoji) into images
extension String {
    
    func image() -> UIImage? {
        let size = CGSize(width: 30, height: 35)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).set()
        let rect = CGRect(origin: CGPoint(), size: size)
        UIRectFill(CGRect(origin: CGPoint(), size: size))
        (self as NSString).draw(in: rect, withAttributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 30)])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
}

