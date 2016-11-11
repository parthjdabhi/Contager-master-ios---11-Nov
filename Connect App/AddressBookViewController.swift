//
//  AddressBookViewController.swift
//  Connect App
//
//  Created by Dustin Allen on 7/6/16.
//  Copyright © 2016 Harloch. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import SDWebImage

class AddressBookViewController: UIViewController,UITableViewDataSource, UITableViewDelegate {
    
    var ref:FIRDatabaseReference!
    var userArry: [UserData] = []
    var userName: String?
    var photoURL: String?
    
    var selectedUserId: String?
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        ref = FIRDatabase.database().reference()
        let userID = FIRAuth.auth()?.currentUser?.uid
        
        let frRef = ref.child("users").child(userID!).child("friends")
        CommonUtils.sharedUtils.showProgress(self.view, label: "Loading....")
        print("Started")
        
        frRef.observeEventType(.Value, withBlock: { snapshot in
            self.userArry.removeAll()
            print(snapshot.value)
            if let friendRequests = snapshot.value as?[String: String] {
                print("if pritned")
                for(_, value) in friendRequests{
                    
                    let uRef = self.ref.child("users").child(value)
                    uRef.observeSingleEventOfType(FIRDataEventType.Value, withBlock: { snapshot in
                        if snapshot.exists()
                        {
                            let userFirstName = snapshot.value!["userFirstName"] as! String!
                            let userLastName = snapshot.value!["userLastName"] as! String!
                            
                            var noImage = false
                            var image = UIImage(named: "no-pic.png")
                            if let base64String = snapshot.value!["image"] as! String! {
                                image = CommonUtils.sharedUtils.decodeImage(base64String)
                            } else {
                                noImage = true
                            }
                            
                            if snapshot.hasChild("facebookData") {
                                let facebookData = snapshot.value!["facebookData"]
                                let data = facebookData as! NSDictionary!
                                self.photoURL = data.valueForKey("profilePhotoURL") as! String!
                                
                            }
                            else {
                                if snapshot.hasChild("twitterData") {
                                    let facebookData = snapshot.value!["twitterData"]
                                    let data = facebookData as! NSDictionary!
                                    self.photoURL = data.valueForKey("profile_image_url") as! String!
                                }
                                else {
                                    self.photoURL = ""
                                }
                            }
                            self.userName = userFirstName + " " + userLastName
                            
                            if self.photoURL == nil {
                                self.photoURL = ""
                            }
                            
                            
                            if let email = snapshot.value!["email"] as? String {
                                self.userArry.append(UserData(userName: self.userName!, photoURL: self.photoURL!, uid: snapshot.key, image: image!, email: email, noImage: noImage))
                            } else {
                                self.userArry.append(UserData(userName: self.userName!, photoURL: self.photoURL!, uid: snapshot.key, image: image!, email: "test@test.com", noImage: noImage))
                            }
                            
                            self.tableView.reloadData()
                        }
                        
                    })
                }
            }
            else {
                CommonUtils.sharedUtils.hideProgress()
            }
        })
    }
    
    override func viewDidAppear(animated: Bool) {
        
    }
    
    override func  preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    @IBAction func backButtonTapped(sender: AnyObject) {
        //self.dismissViewControllerAnimated(true, completion: nil)
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    //Mark :- UITableView DataSource and Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userArry.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell2") as! FriendTableViewCell
        
        cell.profilePic.layer.masksToBounds = true
        cell.profilePic.layer.cornerRadius = cell.profilePic.frame.width/2
        
        cell.userNameLabel.text = userArry[indexPath.row].getUserName()
        let imageExist = userArry[indexPath.row].imageExist()
        if imageExist {
            let image = userArry[indexPath.row].getImage()
            cell.profilePic.image = image
        } else {
            if !userArry[indexPath.row].getUserPhotoURL().isEmpty {
                cell.profilePic.sd_setImageWithURL(NSURL(string: userArry[indexPath.row].getUserPhotoURL()), placeholderImage: UIImage(named: "no-pic.png"))
            }
        }
        
        cell.onDeleteButtonTapped = {
            
            let alert = UIAlertController(title: "Confirm", message: "Do you want to really delete friend?", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Default, handler: { action in
                if let oldfriends = AppState.sharedInstance.currentUser.value!["friends"] {
                    let fid = self.userArry[indexPath.row].getUid()
                    var friends = oldfriends as! [String:String]
                    
                    for (key, value) in friends {
                        if value == fid {
                            friends.removeValueForKey(key)
                        }
                    }
                    
                    let userID = FIRAuth.auth()?.currentUser?.uid
                    let userRef = self.ref.child("users").child(userID!)
                    
                    let dic = ["friends" : friends]
                    
                    userRef.updateChildValues(dic)
                    
                    // Delete friends of Friend
                    let fRef = self.ref.child("users").child(fid)
                    fRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
                        print(snapshot.value)
                        var friends = snapshot.value!["friends"] as! [String:String]
                        
                        for (key, value) in friends {
                            if value == userID {
                                friends.removeValueForKey(key)
                            }
                        }
                        
                        let dic = ["friends" : friends]
                        
                        fRef.updateChildValues(dic)
                    })
                    
                    self.userArry.removeAtIndex(indexPath.row)
                    self.tableView.reloadData()
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        print("\(indexPath.row)" + "\n")
        CommonUtils.sharedUtils.hideProgress()
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        print("Index Path: ", indexPath.row)
        print("User Array: ", self.userArry)
        let friend = self.userArry[indexPath.row]
        selectedUserId = friend.getUid()
        AppState.sharedInstance.friend = friend
        
        let vc = self.storyboard?.instantiateViewControllerWithIdentifier("FriendPortalViewController") as! FriendPortalViewController!
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func selectAddContacts(sender: AnyObject) {        
        
        let vc = self.storyboard?.instantiateViewControllerWithIdentifier("AddContactsViewController") as! AddContactsViewController!
        self.navigationController?.pushViewController(vc, animated: true)
    }
}