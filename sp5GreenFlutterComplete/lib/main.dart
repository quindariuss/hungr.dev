/** Things to do:
 * iOS PUSH NOTIFICATIONS: Android is Done
 * Ads
 * Stop user from double tapping buttons **/

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // use API calls (GET...)
import 'dart:convert'; // convert GET result to JSON/List
// for local file storage
import 'package:path_provider/path_provider.dart'; // to use getApplicationDocumentsDirectory()
import 'dart:io'; // to use Directory, File...
import 'dart:math'; // for random number for joining a group
import 'package:flutter/services.dart'; // to be able to copy to clipboard
import 'dart:async'; // to user Timers
import 'package:flutter/rendering.dart'; // for scroll notification to hide action buttons
// imports for firebase / auth / push notification stuff
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';


// global variable for initial food list for all new users.
final _groceryItems = ['Eggs', 'Milk', 'Fish Sauce', 'Bread', 'Apple Juice', 'Coke', 'Potato Chips',
  'Froot Loops', 'Oatmeal', 'Snickers', 'Cheddar Cheese', 'Beer', 'Water', 'Cigarettes',
  'Oreos', 'Ham', 'Wine', 'Bananas', 'Spinach', 'Cherries', 'Ketchup', 'Coffee', 'Hot Dogs'];

// used for sorting based on frequency
final _groceryItemsFrequency = [];

/* used for unsorting: maintain the old order. Also for frequency sort.
  can also be used to keep old removed items, and add them back */
var _groceryItemsCopy = [];

// holds all items that were added by pressing "add to shared list," and used through any following logic
final _checked = <String>{};
// holds the checked items for the first page view, then is cleared
final _decoupledChecked = <String>{};

// stores _checked + other items in the groceryList group (other user's in the groups' _checked items)
var _checkedAllUsers = [];

var filePath = ''; // path to where this app saves files, calculated in main()

// stores if the list has been alphabetically sorted. used if a new item is added, to put in proper place
var _alphabeticallySorted = false;
var _frequencySorted = false;
var _groupFrequencySorted = false;

// account variables
var userID = "";
var loggedIn = false;
var joinedGroup = "No Group Joined";
var joinableGroup = "";

// to reset the timer
var submitted = false;

// make API calls every few seconds to update shared list screen
Timer? timer; // ? makes this nullable, so we don't have to initialize it

// FIREBASE VARS
FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

// gets push notifications when app is in background/terminated?
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp(); // called this in main() before this, so I don't think we need to here?
  // ("Handling a background message: ${message.messageId}");
}

// make main() async for Futures
Future<void> main() async {

  // firebase background/terminated stuff
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // for background and terminated(?) push notification reception
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // for foreground notification?
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // you can receive data and do things with it here
  });

  // get the phone's path to where it saves files for this app
  Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
  var appDocumentsPath = appDocumentsDirectory.path;
  // convert to string
  filePath = "$appDocumentsPath";

  // check if the user is logged in from local storage, and update vars
  if ((File(filePath + "/loggedIn.txt").existsSync())) {
    var loggedInResponse = await File("$filePath/loggedIn.txt").readAsString();
    if (loggedInResponse == "true") {
      loggedIn = true;
    }
  }

  // update userID if logged in
  if ((File("$filePath/userID.txt").existsSync())) {
    userID = await File("$filePath/userID.txt").readAsString();
    // verify that the user is logged in or not
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // delete local save files and reset variables
        if ((File("$filePath/userID.txt").existsSync())) {
          File file = File("$filePath/userID.txt");
          file.deleteSync();
        }
        if ((File(filePath + "/loggedIn.txt").existsSync())) {
          File file2 = File(filePath + "/loggedIn.txt");
          file2.deleteSync();
        }
        if ((File("$filePath/joinedGroup.txt").existsSync())) {
          File file3 = File("$filePath/joinedGroup.txt");
          file3.deleteSync();
        }
        if ((File("$filePath/checked.json").existsSync())) {
          File file4 = File("$filePath/checked.json");
          file4.writeAsString("[]");
        }
        if ((File("$filePath/purchases.txt").existsSync())) {
          File file = File("$filePath/purchases.txt");
          file.deleteSync();
        }
        if (joinedGroup != "No Group Joined") {
          try {_firebaseMessaging.unsubscribeFromTopic(joinedGroup);} catch (e) {}
        }
        userID = "";
        loggedIn = false;
        joinedGroup = "No Group Joined";
        _checked.clear();
        if (_groupFrequencySorted) {
          _groupFrequencySorted = false;
          File file5 = File("$filePath/sorted.txt");
          file5.writeAsString("");
        }
      }
    });
  }

  if (!(File("$filePath/joinableGroup.txt").existsSync())) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    // generate a random number from 20 - 100
    var randomNumber = Random.secure().nextInt(81) + 20;
    // generate a random string with randomNumber number of characters, and selecting a random character from _chars
    joinableGroup = String.fromCharCodes(Iterable.generate(randomNumber, (_) => chars.codeUnitAt(Random.secure().nextInt(chars.length))));
    File file = File("$filePath/joinableGroup.txt");
    file.writeAsString(joinableGroup);
  } else {
    joinableGroup = await File("$filePath/joinableGroup.txt").readAsString();
  }

  if ((File("$filePath/joinedGroup.txt").existsSync())) {
    joinedGroup = await File("$filePath/joinedGroup.txt").readAsString();
    try {_firebaseMessaging.subscribeToTopic(joinedGroup);} catch (e) {}
  } else {
    try {_firebaseMessaging.unsubscribeFromTopic(joinedGroup);} catch (e) {}
  }

  if (File("$filePath/groceryItems.json").existsSync() && File("$filePath/groceryItemsCopy.json").existsSync()) {

    // clear hard-coded first-time-use items
    _groceryItems.clear();

    // convert the .json json and save in _groceryItems
    var fileContent = await File("$filePath/groceryItems.json").readAsString();
    var jsonLocalList = jsonDecode(fileContent);
    /* populate the initial array with localList's
    items (their names) from the API call */
    for (int i = 0; i < jsonLocalList.length; i++) {
      _groceryItems.add(jsonLocalList[i]['name']);
    }

    var fileContentCopy = await File("$filePath/groceryItemsCopy.json").readAsString();
    var jsonLocalListCopy = jsonDecode(fileContentCopy);
    /* populate the copy array with localListCopy's
    items (their names) from the API call.
     Frequency is based on the copy list, so also populate these */
    for (int i = 0; i < jsonLocalListCopy.length; i++) {
      _groceryItemsCopy.add(jsonLocalListCopy[i]['name']);
      _groceryItemsFrequency.add(jsonLocalListCopy[i]['frequency']);
    }

    // if the user never sorted but edited the list...
    if (!(File("$filePath/sorted.txt").existsSync())) {
      File file = File("$filePath/sorted.txt");
      file.writeAsString("");
    }

    // check if the app last had a sort applied, and re-apply it
    var sortedFile = await File("$filePath/sorted.txt").readAsString();
    if (sortedFile == "_alphabeticallySorted") {
      _alphabeticallySorted = true;
    } else if (sortedFile == "_frequencySorted") {
      _frequencySorted = true;
    } else if (sortedFile == "_groupFrequencySorted") {
      _groupFrequencySorted = true;
    }

    // repopulate _checked
    if (File("$filePath/checked.json").existsSync()) {
      var fileChecked = await File("$filePath/checked.json").readAsString();
      var jsonChecked = jsonDecode(fileChecked);
      for (int i = 0; i < jsonChecked.length; i++) {
        _checked.add(jsonChecked[i]['name']);
      }
    }

    if (loggedIn && joinedGroup != "No Group Joined" && userID != "" && _checked.length > 0) {
      var response = await http.get(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));
      var jsonResponse = jsonDecode(response.body);
      File file = File(filePath + "/purchases.txt");
      var fileString = await File(filePath + "/purchases.txt").readAsString();
      if (fileString != jsonResponse[0]['purchases'].toString()) {
        _checked.clear();
        if (File(filePath + "/checked.json").existsSync()) {
          File file2 = File(filePath + "/checked.json");
          file2.deleteSync();
        }
      }
      file.writeAsString(jsonResponse[0]['purchases'].toString());
      }
    }

  // else use the default list, populated in globals
  else {

    // initialize frequency values as all 0s
    for (int i = 0; i < _groceryItems.length; i++) {
      _groceryItemsFrequency.add(0);
    }

    // make starting copy list
    _groceryItemsCopy = _groceryItems.toList();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hungr',
      home: GroceryItems(),
    );
  }
}

class GroceryItems extends StatefulWidget {
  const GroceryItems({Key? key}) : super(key: key);
  @override
  State<GroceryItems> createState() => _GroceryItemsState();
}

class _GroceryItemsState extends State<GroceryItems> {

  var finalShoppingList = []; // holds bools for if the final shopping list is checked or unchecked

  // used for the finished shopping pop-up box
  var _finishedShopping = false;

  var fabVisibility = true;

  // home screen (1st) definition
  @override
  Widget build(BuildContext context) {
    /* wrap the ListView builder in the scaffold, and make the listview the body
    Now we can edit the app bar for this specific page */
    return Scaffold(

      // scaffold pt 1: appBar
      appBar: AppBar(
        title: const Text('Local List'),
        actions: [
          SizedBox(
            width: 110,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(42)
                  )),
              child: const Text('Add to Shared List',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black),),
              onPressed: () async {
                // clear _checked if the list has been submitted since the last time the user has added to the shared list
                  if (loggedIn && joinedGroup != "No Group Joined" && userID != "" && _checked.length > 0) {
                  // we want this to happen before we call _syncChecked... could make it a method
                  var response = await http.get(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));
                  var jsonResponse = jsonDecode(response.body);
                  File file = File(filePath + "/purchases.txt");
                  var fileString = await File(filePath + "/purchases.txt").readAsString();
                  if (fileString != jsonResponse[0]['purchases'].toString()) {
                    _checked.clear();
                    _checkedAllUsers.clear();
                  }
                  file.writeAsString(jsonResponse[0]['purchases'].toString());
                }

                /* push a notification to the group, if they're in one, and if adding new items to the list:
                 that is, that there are still items in _decoupledPlaceHolder after removing everything in _checked/_checkedAllUsers */
                if (loggedIn && joinedGroup != "No Group Joined " && userID != "" && _decoupledChecked.isNotEmpty) {
                  var _decoupledPlaceHolder = _decoupledChecked.toList();
                  _decoupledPlaceHolder.removeWhere((e) => _checked.contains(e));
                  _decoupledPlaceHolder.removeWhere((e) => _checkedAllUsers.contains(e));
                  if (_decoupledPlaceHolder.isNotEmpty) {
                    pushNotification("New Grocery List Items Added");
                  }
                }

                /* add all items to _checked from _decoupledChecked so the rest of the logic continues.
                   _decoupledChecked's logic ends here. */
                _checked.addAll(_decoupledChecked);
                _saveLocalList();
                // update _checkedAllUsers for our view including other user's _checked items
                _checkedAllUsers = List.from(_checked);
                var addedItems = _checkedAllUsers;

                // sync our _checked list to the server, also adds other user's _checked items to _checkedAllUsers
                if (loggedIn && joinedGroup != "No Group Joined" && userID != "") {
                  addedItems = await _syncCheckedToServer(false);
                }

                // display new screen with _checkedAllUsers making the tiles
                _viewSharedList(addedItems);
                setState(() {
                  _decoupledChecked.clear();
                });
              },
            ),
            // make a popup menu (3 dot menu in the top right)
          ),
          PopupMenuButton(

            // logic for the option chosen goes here
            onSelected: (selectedValue) async {
              if (selectedValue == 0) { // sort alphabetically
                // in setState to update the view
                setState(() {
                  // sort the list alphabetically, and set boolean to true
                  _groceryItems.sort();
                  _alphabeticallySorted = true;
                  _frequencySorted = false;
                  _groupFrequencySorted = false;
                  // save on file that it is sorted
                  File file = File("$filePath/sorted.txt");
                  file.writeAsString("_alphabeticallySorted");
                });
                _saveLocalList();
              } else if (selectedValue == 1) { // sort by purchase frequency
                _frequencySort();
              } else if (selectedValue == 2 && loggedIn && userID != "" && joinedGroup != "No Group Joined") { // sort by group purchase frequency
                await _groupFrequencySort();
              } else if (selectedValue == 3) { // unsort
                _unsort(); // call un-sort algorithm, using copy of the list
              } else if (selectedValue == 4) { // repopulate deleted items
                // re add items in the copy that aren't in the view
                for (final item in _groceryItemsCopy) {
                  // if not in _groceryItems
                  if (!_groceryItems.contains(item)) {
                    // add the item in the copy to the view
                    _groceryItems.add(item);
                  }
                }

                // re-sort if needed.
                if (_alphabeticallySorted) {
                  setState(() {
                    _groceryItems.sort();
                  });
                  _saveLocalList();
                } else if (_frequencySorted) {
                  _frequencySort();
                } else if (_groupFrequencySorted && loggedIn && joinedGroup != "No Group Joined" && userID != "") {
                  await _groupFrequencySort();
                } else {
                  _unsort();
                }

              } else if (selectedValue == 5) { // check all
                _decoupledChecked.clear();
                for (final item in _groceryItems) {
                  setState(() {
                    _decoupledChecked.add(item);
                  });
                }
              } else if (selectedValue == 6) { // uncheck all
                setState(() {
                  _decoupledChecked.clear();
                });
              } else if (selectedValue == 7) { // log out
                // delete local save files and reset variables
                if (loggedIn) {
                  if ((File("$filePath/userID.txt").existsSync())) {
                    File file = File("$filePath/userID.txt");
                    file.deleteSync();
                  }
                  if ((File(filePath + "/loggedIn.txt").existsSync())) {
                    File file2 = File(filePath + "/loggedIn.txt");
                    file2.deleteSync();
                  }
                  if ((File("$filePath/joinedGroup.txt").existsSync())) {
                    File file3 = File("$filePath/joinedGroup.txt");
                    file3.deleteSync();
                  }
                  if ((File("$filePath/checked.json").existsSync())) {
                    File file4 = File("$filePath/checked.json");
                    file4.writeAsString("[]");
                  }
                  if ((File("$filePath/purchases.txt").existsSync())) {
                    File file = File("$filePath/purchases.txt");
                    file.deleteSync();
                  }
                  if (joinedGroup != "No Group Joined") {
                    try {
                      _firebaseMessaging.unsubscribeFromTopic(joinedGroup);
                    } catch (e) {}
                  }
                  userID = "";
                  loggedIn = false;
                  joinedGroup = "No Group Joined";
                  _checked.clear();
                  _checkedAllUsers.clear();
                  _decoupledChecked.clear();
                  if (_groupFrequencySorted) {
                    _groupFrequencySorted = false;
                    File file5 = File("$filePath/sorted.txt");
                    file5.writeAsString("");
                  }
                  await FirebaseAuth.instance.signOut();
                  setState(() {});
                }
              }
            },
            // lambda expression => creates and populates popupmenu entries with child's
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Text('Sort Alphabetically'),
              ),
              const PopupMenuItem(
                value: 1,
                child: Text('Sort By Purchase Frequency'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('Sort By Group Purchase Frequency'),
              ),
              const PopupMenuItem(
                value: 3,
                child: Text('Unsort'),
              ),
              const PopupMenuItem(
                value: 4,
                child: Text('Repopulate Deleted Items'),
              ),
              const PopupMenuItem(
                value: 5,
                child: Text('Check All'),
              ),
              const PopupMenuItem(
                value: 6,
                child: Text('Uncheck All'),
              ),
              const PopupMenuItem(
                value: 7,
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),

      // scaffold pt 2: List View
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          final ScrollDirection direction = notification.direction;
          setState(() {
            if (direction == ScrollDirection.reverse) {
              fabVisibility = false;
            } else if (direction == ScrollDirection.forward) {
              fabVisibility = true;
            }
          });
          return true;
        },
        child: ListView.builder(

        itemCount: _groceryItems.length * 2, /* Set the list size.
                            * 2 for the divider after every item */
        //padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, i) { // builds what we'll populate the list with
          final index = i ~/ 2; // gets the number of items, by subtracting dividers
          if (i.isOdd) return Container( color: _checked.contains(_groceryItems[index]) ? Colors.blue[50] : Colors.grey[50],
              child: Divider()); // make a divider between items

          /* boolean to show if a box is checked (contained in _decoupledChecked set) or not
             note that this is now cleared upon pressing add to shared list */
          final alreadyChecked = _decoupledChecked.contains(_groceryItems[index]);

          // wrap in a container to set tile background color
          return Container( color: _checked.contains(_groceryItems[index]) ? Colors.blue[50] : Colors.grey[50],
          child: Dismissible(key: ValueKey(_groceryItems[index]), /* wrapping the return ListTile
          return in a Dismissible, and making the ListTile a child: lets us swipe it right.
          We also need to remove it from the array, however */

            /* onDismissed sets what happens when we swipe. Need to remove item from the array,
            and make sure we update the state. Setting the direction of the dismissible
            makes it only go start to end, for example: --> swipe right. Switched from onDismissed
             to confirmDismiss: */
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                setState(() {
                  // if remove an item from the viewable list, also remove it from shared/_checked list?
                  // previously it was keeping it, so you could check a box, and then remove it from your local list,
                  // but it would remain in _checked / middle list, with no way to remove it, without re-adding the item...
                  _decoupledChecked.remove(_groceryItems[index]);
                  _groceryItems.remove(_groceryItems[index]);
                });
                _saveLocalList(); // update the locally saved list
                // disable swipe left, for now
              } else if (direction == DismissDirection.endToStart) {
                // swiping left... do nothing currently
              }
            },

            child: ListTile( // make a Text List tile and add it to the list
              title: Text(
                _groceryItems[index],
                style: const TextStyle(fontSize: 18),
              ),
              trailing: Icon(
                alreadyChecked ? Icons.check_box : Icons.check_box_outline_blank, /* if (alreadyChecked) {
                                                                          return(?) Icons.check_box;
                                                                        } else { return(?) Icons.check_box_outline_blank } */
                semanticLabel: alreadyChecked ? 'Add to shared List' : 'Remove',
              ),
              onTap: () {
                // sets the state of the checkbox as above ^
                setState(() {
                  if (alreadyChecked) {
                    _decoupledChecked.remove(_groceryItems[index]);
                  } else {
                    _decoupledChecked.add(_groceryItems[index]);
                  }
                });
              },
              onLongPress: () {
                _popUp(_groceryItems[index]);
              },
            ),
          ),
          );
        },
      ),
      ),

      // scaffold pt 3: floating buttons
      floatingActionButton: Visibility(visible: fabVisibility, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: <Widget> [
          const SizedBox(
            width: 20,
          ),

          // left floating action button to add items to the grocery list
          FloatingActionButton(
            heroTag: null, // I got an error, not sure why. Appears needed to set this heroTag: what is that?
            onPressed: () {
              _popUp(null);
            },
            child: const Icon(Icons.add),
          ),

          const SizedBox(
            width: 70,
          ),

          FloatingActionButton.extended(
            heroTag: null, // I got an error, not sure why. Appears needed to set this heroTag: what is that?
            onPressed: () {
              if (!loggedIn) {
                _makeAccountOrLogin();
              } else {
                // push on the new screen
                Navigator.of(context).push(_joinGroup()).then((value) => setState((){}));
              }
            },
            label: const Text('Join a Group'),
          ),
        ],
      ),
      ),

    );
  }

  // pushes the new screen (2nd) on to the stack, after pressing the add to shared list button in the app bar
  void _viewSharedList(addedItems) {

    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        // builder builds the scaffold with the app bar and the body with the list view rows
        builder: (context) { // context shows the relation of this context to others

          return StatefulBuilder (builder: (BuildContext context, StateSetter setState) {

            /* start a timer to make API calls if logged in and a group is joined
            This probably shouldn't be in a builder, hence needing if (timer == null)
            so it doesn't keep making timers in an infinite loop due to calling setState over and over,
            but it works and I'm not sure where/how to move it */
            if (loggedIn && joinedGroup != "No Group Joined" && userID != "" && timer == null) {
              timer = Timer.periodic(Duration(seconds: 10), (Timer t) async {
                // use addedItems to update backgrounds correctly
                addedItems = await _syncCheckedToServer(true);
                setState((){});
              });
            }

      /* iterate the set using .map, and create a tile of each list item. list items
          are in variable checkedItems, iteratively. currently no trailing icon */
      final sharedListTiles = _checkedAllUsers.map((checkedItems) {

        // return a Container to set background to blue where a user added a listTile
        return Container(color: addedItems.contains(checkedItems) ? Colors.blue[50] : Colors.grey[50], //

            child: !(addedItems.contains(checkedItems)) ?
                // if item not in addedItems: just a ListTile
            ListTile(
              title: Text(checkedItems, style: const TextStyle(fontSize: 18)
                ,),) : // basic ListTile if added by another user, OR Dismissible one if added by us

            // if item in addedItems: Dismissible ListTile child
            Dismissible(key: ValueKey(checkedItems), /* wrapping the return ListTile
          return in a Dismissible, and making the ListTile a child: lets us swipe it right.
          We also need to remove it from the array, however */

        /* onDismissed sets what happens when we swipe. Need to remove item from the array,
            and make sure we update the state. Setting the direction of the dismissible
            makes it only go start to end, for example: --> swipe right. Switched from onDismissed
             to confirmDismiss: */
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // the actual logic
            _checked.remove(checkedItems);
            _saveLocalList();
            // to update the view (this is recalculated upon pushing generate shopping list later)
            _checkedAllUsers.remove(checkedItems);
            // sync our _checked list to the server, also adds other user's _checked items to _checkedAllUsers
            if (loggedIn && joinedGroup != "No Group Joined" && userID != "") {
              await _syncCheckedToServer(false);
            };
            setState((){});
          }
        },

          // make a list tile with the text of checkedItems (the item iterable from _checkedAllUsers)
          child: ListTile(
            title: Text(
              checkedItems,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        );
      },
      );

      /* if the list of checked tiles isn't empty, divideTiles() puts a divider
          between each row in sharedListTiles, then .toList() turns it into a list
           else, it returns an empty <Widget>[] */
      final divided = sharedListTiles.isNotEmpty ? ListTile.divideTiles(context: context, tiles: sharedListTiles,).toList() : <Widget>[];

      // return the new app bar for the new screen
      return Scaffold(
        appBar: AppBar(
          title: const Text('Shared List'),
          actions: [
            SizedBox(
              width: 150,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(42)
                    )),
                child: const Text('Generate Shopping List',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black),),
                onPressed: () async {
                  // cancel the timer so it doesn't keep running
                  timer?.cancel();
                  timer = null;
                  // update _checkedAllUsers for our view including other user's _checked items
                  _checkedAllUsers = List.from(_checked);

                  // add other user's _checked items to _checkedAllUsers
                  if (loggedIn && joinedGroup != "No Group Joined" && userID != "") {
                    await _getChecked();
                  }

                  // display new screen with _checkedAllUsers making the tiles
                  Navigator.of(context).push(_storeList()).then((value) {
                    if (!submitted) {
                      setState((){});
                    }
                    submitted = false;
                  });
                },

              ),
            ),
          ],
        ),
        body: ListView(children: divided),
      );
    });
        },
      ),
      // do then() for if we pop back to last screen, to stop the timer
    ).then((value) {
      timer?.cancel();
      timer = null;
      setState((){});
    });
  }

  /* if NOT loggedIn pushes the login/make account screen (3rd) on to the stack, after pressing Join a Group button */
  void _makeAccountOrLogin() {
    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        // builder builds the scaffold with the app bar and the body with the list view rows
        builder: (context) { // context shows the relation of this context to others

          // return the new app bar for the new screen
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login or Create an Account'),
            ),

            // create body
            body: Center(

              // populate body: make a Column
              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget> [
                  SizedBox(
                      width: 250,
                      height: 75,
                      child: ElevatedButton(
                        child: const Text("Login",
                          style: TextStyle(fontSize: 24),
                        ),
                        onPressed: _loginScreen,
                      )
                  ),

                  const SizedBox(
                    height:25,
                  ),

                  SizedBox(
                      width: 250,
                      height: 75,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffE3F2FF),
                        ),
                        child: const Text("Make an Account",
                          style: TextStyle(fontSize: 24),
                        ),
                        onPressed: () {
                          _makeAccountScreen();
                        },
                      )
                  ),
                ],
              ),

            ),
          );
        },
      ),
    );
  }

  /* pushes the final shopping list screen (4th) on to the stack, after pressing
  the generate shopping list button in the app bar */
  MaterialPageRoute<void> _storeList() {

    /* make a boolean for each item with a checkbox in the list, to update the icon with
    if true, icon's checked, if false, unchecked. Starts false */
    finalShoppingList = List.filled(_checkedAllUsers.length, false);

      // create the new page / screen
      return MaterialPageRoute<void>(

        /* builder builds the scaffold with the app bar and the body with the list view rows
        builder is required for MaterialPageRoute */
        builder: (BuildContext context) {

          /* we must return a StatefulBuilder if we want to update the state, else
          it seemingly doesn't update the view */
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) { // part of StatefulBuilder

                // iterates through the _checkedAllUsers, making each item checkedItems one at a time
                final sharedListTiles = _checkedAllUsers.map((checkedItems) {

                  // make a ListTile
                  return Container ( color: _checked.contains(checkedItems) ? Colors.blue[50] : Colors.grey[50],
                  child: ListTile(

                    // the text is the item in the list
                    title: Text(
                      checkedItems,
                      style: const TextStyle(fontSize: 18),
                    ),

                    /* trailing icon check box, with a label. Put in a Row and SizedBox
                    for spacing. If no width, causes an error */
                    trailing: SizedBox(
                      width: 80,
                      // our child IS a Row, which can have CHILDREN
                      child: Row (
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        // 2 children: the Text and the Icon
                        children: [
                          const Text('In Cart?'), // our "label" for our check box
                          Icon(
                            // if the matching boolean to checkedItems is true, check_box, if false, check_box_outline_blank
                            finalShoppingList[_checkedAllUsers.indexOf(checkedItems)] ? Icons.check_box : Icons.check_box_outline_blank,
                          ),
                        ],
                      ),

                      //
                    ),

                    /* when tapped, update the state by changing the boolean value, meaning checks and unchecks the box.
              this works here because we're using StatefulBuilder */
                    onTap: () {
                      setState(() {
                        finalShoppingList[_checkedAllUsers.indexOf(checkedItems)] =
                        !finalShoppingList[_checkedAllUsers.indexOf(checkedItems)];
                      });
                    },
                  ),
                  );
                },
                );

                /* if the list of checked tiles isn't empty, divideTiles() puts a divider
          between each row in sharedListTiles, then .toList() turns it into a list
           else, it returns an empty <Widget>[] */
                final divided = sharedListTiles.isNotEmpty ? ListTile.divideTiles(
                  context: context,
                  tiles: sharedListTiles,
                ).toList() : <Widget>[];

                /* return the new Scaffold with app bar for the new screen and our created
          ListTiles now in a ListView and divided */
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Shopping List'),
                    actions: [
                      SizedBox(
                        width: 80,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(42)
                              )),
                          onPressed: () {
                            _finishedShopping = true;
                            _popUp(null);
                          },
                          child: const Text('Submit',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black),),
                        ),
                      ),
                    ],
                  ),
                  body: ListView(children: divided),
                );
              });
        },
      );
  }

  /* pushes the login screen (5th) on to the stack, after pressing
  the login button */
  void _loginScreen() {

    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        /* builder builds the scaffold with the app bar and the body with the list view rows
        builder is required for MaterialPageRoute */
        builder: (BuildContext context) {

          // declare variables here
          final usernameController = TextEditingController();
          final passwordController = TextEditingController();

          var loggedInDisplay = false;
          var _isVisible = false;
          var pressed = false;
          var text = "";

          /* we must return a StatefulBuilder if we want to update the state, else
          it seemingly doesn't update the view */
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) { // part of StatefulBuilder

                // return the new app bar for the new screen
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Login'),
                  ),

                  // create body
                  body: Center(

                    // populate body: make a Column
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget> [

                        // label for Enter Username:
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            'Enter Email Address:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // text field to enter username
                        SizedBox(
                            width: 250,
                            height: 75,
                          child: TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Username',
                              floatingLabelBehavior:FloatingLabelBehavior.auto,
                            ),
                          ),
                        ),

                        Visibility(
                          visible: _isVisible,
                          child: const SizedBox(
                            width: 250,
                            height: 25,
                            child: Text (
                              'Incorrect Username or Password',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // label to enter password
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            'Enter Password:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),


                        // text box to enter password
                        SizedBox(
                                width: 250,
                                height: 60,
                                child: TextField(
                                  obscureText: true,
                                  //obscuringCharacter: '*', the default DOT looks more modern
                                  controller: passwordController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Password',
                                    floatingLabelBehavior:FloatingLabelBehavior.auto,                            ),
                                ),
                              ),

                              SizedBox(
                                width: 250,
                                child: TextButton(
                                  child: Align(
                                    alignment: pressed ? Alignment.bottomLeft
                                    : Alignment.bottomRight,
                                    child: pressed ?
                                    Text(
                                      text,
                                    ) :
                                    Text(
                                    "Forgot Password?",
                                  ),
                                  ),
                                  onPressed: () async {
                                    if (usernameController.text.trim().isNotEmpty) {

                                      await FirebaseAuth.instance.sendPasswordResetEmail(email: usernameController.text.trim());
                                      setState((){
                                        pressed = true;
                                        text = "Please check your spam folder, an email has been sent to " + usernameController.text.trim();
                                      });
                                    } else {
                                      setState(() {
                                        pressed = true;
                                        text = "Please enter an email address.";
                                      });
                                    }
                                  },
                                ),
                              ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // login button
                        SizedBox(
                            width: 250,
                            height: 55,
                            child: ElevatedButton(
                              child: loggedInDisplay ? CircularProgressIndicator(
                                color: Colors.grey[50],
                              ) : const Text("Login",
                                style: TextStyle(fontSize: 24),
                              ),
                              onPressed: () async {
                                // set loggedIn bool based on provided credentials
                                setState(() {
                                  pressed = false;
                                  loggedInDisplay = true;
                                });
                                if (usernameController.text.trim().isNotEmpty && passwordController.text.trim().isNotEmpty) {
                                  // login the user
                                  try {
                                    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                        email: usernameController.text.trim(),
                                        password: passwordController.text.trim()
                                    );

                                    // update our vars
                                    FirebaseAuth.instance.authStateChanges().listen((User? user) {
                                      if (user != null) {
                                        userID = user.uid;
                                        loggedIn = true;
                                        File file = File(filePath + "/loggedIn.txt");
                                        file.writeAsString("true");
                                        File file2 = File(filePath + "/userID.txt");
                                        file2.writeAsString(userID);
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const GroceryItems()),);
                                      } else {
                                        setState(() {
                                          loggedInDisplay = false;
                                        });
                                      }
                                    });

                                  } on FirebaseAuthException catch (e) {
                                    if (e.code == 'user-not-found') {
                                      setState(() {
                                        loggedInDisplay = false;
                                        _isVisible = true;
                                      });
                                    }
                                    else if (e.code == 'wrong-password') {
                                      setState(() {
                                        loggedInDisplay = false;
                                        _isVisible = true;
                                      });
                                    } else {
                                      setState(() {
                                        loggedInDisplay = false;
                                        _isVisible = true;
                                      });
                                    }
                                  }
                                } else {
                                  setState(() {
                                    loggedInDisplay = false;
                                    _isVisible = true;
                                  });
                                }

                              },
                            )
                        ),
                      ],
                    ),

                  ),
                );
              });
        },
      ),
    );
  }
  /* pushes the make an account screen (6th) on to the stack, after pressing
  the make account button */
  void _makeAccountScreen() {

    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        /* builder builds the scaffold with the app bar and the body with the list view rows
        builder is required for MaterialPageRoute */
        builder: (BuildContext context) {

          // declare variables here
          final usernameController = TextEditingController();
          final passwordController = TextEditingController();
          final passwordController2 = TextEditingController();
          var _passwordsMatch = true;
          var _usernameTaken = false;
          var loggedInDisplay = false;
          var shortUsername = false;

          /* we must return a StatefulBuilder if we want to update the state, else
          it seemingly doesn't update the view */
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) { // part of StatefulBuilder

                // return the new app bar for the new screen
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Make Account'),
                  ),

                  // create body
                  body: Center(
                  child: SingleChildScrollView (
                    // populate body: make a Column
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget> [

                        // label for Enter Username:
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            'Email Address:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // text field to enter username
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Username',
                              floatingLabelBehavior:FloatingLabelBehavior.auto,
                            ),
                          ),
                        ),

                        Visibility(
                          visible: _usernameTaken,
                          child: SizedBox(
                            width: 250,
                            height: shortUsername ? 35 : 25,
                            child: shortUsername ? Text (
                              'The password provided is too weak.',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 15),
                            ) : Text (
                              'The account already exists for that email.',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // label to enter password
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            'Choose a Password:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // text box to enter password
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: TextField(
                            obscureText: true,
                            //obscuringCharacter: '*',
                            controller: passwordController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Password',
                              floatingLabelBehavior:FloatingLabelBehavior.auto,
                            ),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // label to enter password
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            'Re-Enter Password:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // text box to enter password
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: TextField(
                            obscureText: true,
                            //obscuringCharacter: '*', the automatic DOT looks more modern than setting this
                            controller: passwordController2,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Confirm Password',
                              floatingLabelBehavior:FloatingLabelBehavior.auto,
                            ),
                          ),
                        ),

                        Visibility(
                          visible: !_passwordsMatch,
                          child: SizedBox(
                            width: 250,
                            height: 25,
                            child: Text (
                              'Passwords Do Not Match',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // make account button
                        SizedBox(
                            width: 250,
                            height: 55,
                            child: ElevatedButton(
                              child: loggedInDisplay ? CircularProgressIndicator(
                                color: Colors.grey[50],
                              ) : const Text("Make Account",
                                style: TextStyle(fontSize: 24),
                              ),
                              onPressed: () async {
                                setState((){
                                  loggedInDisplay = true;
                                });
                                // check if the 2 passwords match, and attempt to signup if so
                                if (passwordController.text.trim() != passwordController2.text.trim()) {
                                  setState(() {
                                    _passwordsMatch = false;
                                    _usernameTaken = false;
                                    loggedInDisplay = false;
                                    shortUsername = false;
                                  });
                                } else if (usernameController.text.trim().length < 6 || passwordController.text.trim().length < 6) {
                                  shortUsername = true;
                                  _usernameTaken = true;
                                  _passwordsMatch = true;
                                  loggedInDisplay = false;
                                } else if (((passwordController.text.trim() == passwordController2.text.trim()) && passwordController.text.trim().isNotEmpty)) {

                                    // Make an account using firebase
                                    try {
                                      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                        email: usernameController.text.trim(),
                                        password: passwordController.text.trim(),
                                      );
                                    } on FirebaseAuthException catch (e) {
                                      if (e.code == 'weak-password') {
                                        shortUsername = true;
                                        _usernameTaken = true;
                                        _passwordsMatch = true;
                                        loggedInDisplay = false;
                                      } else if (e.code == 'email-already-in-use') {
                                        setState(() {
                                          _usernameTaken = true;
                                          _passwordsMatch = true;
                                          loggedInDisplay = false;
                                          shortUsername = false;
                                        });
                                      }
                                    } catch (e) {
                                      loggedInDisplay = false;
                                    }

                                    // login the user
                                    try {
                                      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                          email: usernameController.text.trim(),
                                          password: passwordController.text.trim()
                                      );

                                      // update our vars
                                        FirebaseAuth.instance.authStateChanges().listen((User? user) {
                                          if (user != null) {
                                            userID = user.uid;
                                            loggedIn = true;
                                            File file = File(filePath + "/loggedIn.txt");
                                            file.writeAsString("true");
                                            File file2 = File(filePath + "/userID.txt");
                                            file2.writeAsString(userID);
                                            Navigator.of(context).popUntil((route) => route.isFirst);
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => const GroceryItems()),
                                            );
                                          } else {
                                            loggedInDisplay = false;
                                          }
                                        });

                                    } on FirebaseAuthException catch (e) {
                                      if (e.code == 'user-not-found') {}
                                      else if (e.code == 'wrong-password') {}
                                    }
                                }
                              },
                            )
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              });
        },
      ),
    );
  }

  /* if loggedIn, pushes the join a group screen (7th) on to the stack, after pressing
  the join a group button */
  MaterialPageRoute<void> _joinGroup() {

      // create the new page / screen
      return MaterialPageRoute<void>(

        /* builder builds the scaffold with the app bar and the body with the list view rows
        builder is required for MaterialPageRoute */
        builder: (BuildContext context) {

          // declare variables here
          final controller = TextEditingController();

          /* we must return a StatefulBuilder if we want to update the state, else
          it seemingly doesn't update the view */
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) { // part of StatefulBuilder

                // return the new app bar for the new screen
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Join a Group'),
                  ),

                  // create body
                  body: //Center(
                    // large screen so make it scrollable...
                     SingleChildScrollView (
                    // populate body: make a Column
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget> [

                        // spacer
                        const SizedBox(
                          height:30,
                        ),

                        // label to show what group a user is in
                        SizedBox(
                          width: 250,
                          height: 25,
                          child: Text (
                            "You are in group:",
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // show what group a user is in
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: SelectableText (
                            joinedGroup,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),

                        const Divider(thickness: 3),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        // label for row
                        SizedBox(
                          width: 250,
                          height: 50,
                          child: Text (
                            'Share (and use) this code so others can join your group!',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:5,
                        ),

                        SizedBox(
                          width: 250,
                          height: 75,
                          child: SelectableText (
                            joinableGroup,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),

                        Row (
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget> [
                            ElevatedButton(
                              child: const Icon(Icons.content_copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: joinableGroup));
                              },
                            ),

                            ElevatedButton(
                              child: const Icon(Icons.refresh),
                              onPressed: () {
                                setState(() {
                                  _generateGroupCode();
                                });
                              },
                            ),
                          ],
                        ),

                        const Divider(thickness: 3),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // label for enter group code
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: Text (
                            'Enter above code or a code from a friend to join a group:',
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // text box to enter group code
                        SizedBox(
                          width: 250,
                          height: 75,
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Group Code',
                              floatingLabelBehavior:FloatingLabelBehavior.auto,                            ),
                          ),
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // join group button
                        SizedBox(
                            width: 250,
                            height: 55,
                            child: ElevatedButton(
                              child: const Text("Join Group",
                                style: TextStyle(fontSize: 24),
                              ),
                              onPressed: () async {
                                if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(controller.text.replaceAll(' ', ''))) {
                                var joinedGroupCopy = joinedGroup;
                                joinedGroup = controller.text.replaceAll(' ', '');
                                setState(() {
                                  controller.clear();
                                });
                                var response = await http.post(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));
                                // in case they're joining an already existing group
                                if (response.body == 'success' || response.body == 'Group Already Added') {
                                  try {_firebaseMessaging.unsubscribeFromTopic(joinedGroupCopy);} catch(e) {}
                                  response = await http.get(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));
                                  var jsonResponse = jsonDecode(response.body);
                                  File file = File("$filePath/joinedGroup.txt");
                                  file.writeAsString(joinedGroup);
                                  File file2 = File("$filePath/purchases.txt");
                                  file2.writeAsString(jsonResponse[0]['purchases'].toString());
                                  _checkedAllUsers.clear();
                                  _checked.clear();
                                  _decoupledChecked.clear();
                                  response = await http.get(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup'));
                                  jsonResponse = jsonDecode(response.body);
                                  for (var i = 0; i < jsonResponse.length; i++) {
                                    if (jsonResponse[i]['username'] == userID && jsonResponse[i]['visible'] == 1) {
                                      _checked.add(jsonResponse[i]['name']);
                                    }
                                  }
                                  _saveLocalList();
                                  try {_firebaseMessaging.subscribeToTopic(joinedGroup);} catch (e) {}
                                  // if there's some error and the group doesn't added AND doesn't exist? Ex API failure
                                } else {
                                    setState(() {
                                      joinedGroup = joinedGroupCopy;
                                    });
                                }
                                }
                              },
                            )
                        ),

                        // spacer
                        const SizedBox(
                          height:10,
                        ),

                        // leave group button
                        SizedBox(
                            width: 250,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffE3F2FF),
                              ),
                              child: const Text("Leave Group",
                                style: TextStyle(fontSize: 24),
                              ),
                              onPressed: () {
                                if ((File("$filePath/joinedGroup.txt").existsSync())) {
                                  File file = File("$filePath/joinedGroup.txt");
                                  file.deleteSync();
                                }
                                if ((File("$filePath/purchases.txt").existsSync())) {
                                  File file = File("$filePath/purchases.txt");
                                  file.deleteSync();
                                }
                                if (File("$filePath/checked.json").existsSync()) {
                                  File file = File("$filePath/checked.json");
                                  file.deleteSync();
                                }
                                 _checkedAllUsers.clear();
                                _checked.clear();
                                _decoupledChecked.clear();
                                if (_groupFrequencySorted) {
                                  _groupFrequencySorted = false;
                                  File file5 = File("$filePath/sorted.txt");
                                  file5.writeAsString("");
                                }

                                try { _firebaseMessaging.unsubscribeFromTopic(joinedGroup); } catch (e) {};
                                setState(() {
                                  joinedGroup = "No Group Joined";
                                });
                              },
                            )
                        ),

                      ],
                    ),
                  ),
                  //),
                );
              });
        },
    );
  }

  /* create pop up boxes, takes a String to determine what method called it, to
  determine what the popup should look like (adding or deleting an item) */
  void _popUp(groceryListValue) {

    // returns True if adding an item, or False if removing an item
    final addOrDelete = (groceryListValue == null);

    // controller to get TextField value
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {

        // pops up a text box to input an item in to
        return AlertDialog(
          /* ask to add or delete based on addOrDelete, which is based on which
          thing called the pop up: long press or +. Also check if popup is for finishing shopping */
          title: _finishedShopping ? const Text('Finished Shopping?') : addOrDelete ? const Text('Add Item to Grocery List? ') :
          Text('Permanently delete \'$groceryListValue\' from Grocery List?'), /* "interpolation":
           putting the value in the string directly, instead of concatenating */
          actions: <Widget> [
            Visibility(
              // don't show input box for finishing shopping, or for deleting: make visible false
              visible: _finishedShopping ? false : addOrDelete,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter Item to Add',
                ),
              ),
            ),
            Row (
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget> [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  /* Say confirm or submit based on addOrDelete */
                  child: addOrDelete ? const Text('Submit') : const Text('Confirm'),
                  onPressed: () async {

                    // if submitting the completed shopping list
                    if (_finishedShopping) {
                      submitted = true;
                      /* increment _groceryItemsFrequency for submitted items, measuring frequency.
                      iterate bools of finalShoppingList */
                      for (var i = 0; i < finalShoppingList.length; i++) {
                        if (finalShoppingList[i] == true) { // if true when submitted,
                          // increment frequency of proper item, based on _groceryItemsCopy
                          if (_checked.contains(_checkedAllUsers[i])) {
                            _groceryItemsFrequency[_groceryItemsCopy.indexOf(_checkedAllUsers[i])]++;
                          }
                        }
                      }

                      _checked.clear(); // clear shopping list, as shopping is done

                      if (_frequencySorted) { // incremented frequencies, so re-sort
                        _frequencySort();
                      } else if (_groupFrequencySorted && userID != "" && loggedIn && joinedGroup != "No Group Joined") {
                        await _groupFrequencySort();
                      }
                      // _frequencySort() calls _saveLocalList(), so make this an else so it doesn't happen twice
                      else {
                        // update saved files for frequency / checked
                        _saveLocalList();
                      }

                      // set all visibility in DB to 0, and increment frequencies in DB
                      if (loggedIn && joinedGroup != "No Group Joined" && userID != "") {
                        await _submitAPI(finalShoppingList);
                      }

                      /* return to the home screen by pushing. could change GroceryItems() to MyApp() also.
                      Not really sure why we need both of these commands, but with only one, it doesn't work? */
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GroceryItems()),
                      );
                      // set state of homescreen being put back
                      setState((){});

                      // else if adding a custom item to _groceryItems
                    } else if (controller.text.trim().isNotEmpty) { // don't add if length = 0 or only spaces entered

                      /* get the value of the TextField with the controller, and then setState (refresh the current page)
                     with the value, adding it to the list, which updates the view. Trim the leading and trailing white space,
                     and only add it if the string isn't empty. Also make the first letter of every word uppercase,
                     and the following letters lowercase, for sorting [.sort() considers all lowercase letters, ex 'a'
                     to come after all uppercase letters, ex. 'Z'].*/
                      final splitBySpace = controller.text.trim().split(' '); // split string into array of words
                      splitBySpace.removeWhere((element) => element == ''); // remove extra spaces
                      for (var i = 0; i < splitBySpace.length; i++) {
                        // uppercase the first letter of each word, followed by lowercasing the other letters
                        splitBySpace[i] = splitBySpace[i][0].toUpperCase() + splitBySpace[i].substring(1).toLowerCase();
                      }
                      controller.text = splitBySpace.join(' '); // join words back with spaces

                        /* add the item to the list. if() statement checks if the item is already
                        in the list, and doesn't copy it if so. */
                        if (!_groceryItems.contains(controller.text)) {
                          _groceryItems.add(controller.text);
                        }

                        if (!_groceryItemsCopy.contains(controller.text)) {
                          _groceryItemsCopy.add(controller.text);
                          _groceryItemsFrequency.add(0); // starting frequency is 0
                        }

                        // maintain sorts, if true
                        if (_alphabeticallySorted) {
                          _groceryItems.sort();
                        } else if (_frequencySorted) { // in case of re-adding an item stored in the copy
                          _frequencySort();
                        } else if (_groupFrequencySorted && userID != "" && loggedIn && joinedGroup != "No Group Joined") {
                          await _groupFrequencySort();
                          // if _groupFrequencySorted is true, but one of the above is false, set it to false
                        } else if (_groupFrequencySorted) {
                          _groupFrequencySorted = false;
                        }

                      // _frequencySort() calls this, so only call it if it's false (wasn't called just above)
                      if (!_frequencySorted && !_groupFrequencySorted) {
                        _saveLocalList(); // list is changed, so save locally
                      }

                      setState((){});

                      // if addOrDelete is false, we're deleting, not adding
                    } else if (!addOrDelete) {
                      setState(() {
                        // remove from view list
                        _groceryItems.remove(groceryListValue);
                        // permanently delete from long press, so delete from copy list and related frequency list
                        _groceryItemsFrequency.removeAt(_groceryItemsCopy.indexOf(groceryListValue));
                        _groceryItemsCopy.remove(groceryListValue);
                        _decoupledChecked.remove(groceryListValue);
                      });
                      _saveLocalList(); // re-save locally
                    }

                    // close the AlertDialog
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
      /* .then() [after] showDialog (popup), do this... set _finishedShopping to false [this is in case
      they click out of the box, without clicking 'cancel' or 'submit']. Also takes care of those 2 cases. */
    ).then((value) => _finishedShopping = false);
  }

  // un-sorts the list, based on the original order, held in _groceryItemsCopy
  void _unsort() {
    // set boolean to false, now that we're unsorting
    _alphabeticallySorted = false;
    _frequencySorted = false;
    _groupFrequencySorted = false;
    // hold everything currently in the view, before we clear the view
    final groceryItemsPlaceHolder = List.from(_groceryItems);
    // clear the list that displays the view
    _groceryItems.clear();
    /* if items in the copy of the view are also in the placeholder, re-add them to the view. */
    for(final listEntry in _groceryItemsCopy) {
      if (groceryItemsPlaceHolder.contains(listEntry)) {
        _groceryItems.add(listEntry);
      }
    }
    setState((){});

    // save on file that it is unsorted
    File file = File("$filePath/sorted.txt");
    file.writeAsString("");

    _saveLocalList(); // re-save locally since we're going back to original sort
  }

  // sorts the list on local (individual) frequency
  void _frequencySort() {

    //re-set sorting bools
    _frequencySorted = true;
    _groupFrequencySorted = false;
    _alphabeticallySorted = false;
    // hold everything currently in the view/needed for sorting, before we clear the view
    final groceryItemsCopyPlaceHolder = List.from(_groceryItemsCopy);
    final groceryItemsFrequencyPlaceHolder = List.from(_groceryItemsFrequency);
    // store the frequencies in reverse order sorted: largest-->smallest for re-sorting
    final sortedGroceryItemsFrequency = (List.from(groceryItemsFrequencyPlaceHolder)..sort()).reversed.toList();
    final groceryItemsPlaceHolder = List.from(_groceryItems);

    // clear the list that displays the view
    _groceryItems.clear();

    // loop through frequencies, re-sorting the view based on the sorted frequency list
    for (var i = 0; i < sortedGroceryItemsFrequency.length; i++) {

      // find the index of the item with the highest frequency, per the sortedGroceryItemsFrequency list
      var index = groceryItemsFrequencyPlaceHolder.indexOf(sortedGroceryItemsFrequency[i]);

      // if the item held at that index was still in _groceryItems [ex, not deleted])
      if (groceryItemsPlaceHolder.contains(groceryItemsCopyPlaceHolder[index])) {
        // add it to the top of _groceryItems
        _groceryItems.add(groceryItemsCopyPlaceHolder[index]);
      }
      // remove the first instance of the highest frequency item from the frequency list and grocery list
      groceryItemsFrequencyPlaceHolder.remove(sortedGroceryItemsFrequency[i]);
      groceryItemsCopyPlaceHolder.remove(groceryItemsCopyPlaceHolder[index]);

    }
    // reset the view
    setState((){});

    // save on file that it is sorted
    File file = File("$filePath/sorted.txt");
    file.writeAsString("_frequencySorted");

    // save the list again
    _saveLocalList();
  }

  // saves groceryItems, groceryItemsCopy, checked, and frequencies locally
  void _saveLocalList() {

    // start json string
    var localList = "[";

    // add all grocery Items to the json string with appropriate names/values in the json
    for (int i = 0; i < _groceryItems.length; i++) {
      // add a comma for the 2nd and on items
      if (i != 0) {
        localList += ", ";
      }
      // ID and the list that this is saved on shouldn't really be used... counts and notes are not implemented in the app
      localList += "{\"id\": $i, \"name\": \"" + _groceryItems[i] + "\", \"count\": 1, \"note\": null, \"groceryList\": \"localList\"}";
    }
    // finish the json string
    localList += "]";

    // write the json to a file saved locally on user's phone
    File file = File("$filePath/groceryItems.json");
    file.writeAsString(localList); // write the JSON to local file

    // do the same as above with the copy list that we use for "unsort", "repopulate deleted items", and frequency sort
    var localListCopy = "[";

    for (int i = 0; i < _groceryItemsCopy.length; i++) {
      if (i != 0) {
        localListCopy += ", ";
      }
      // add a new frequency category in the JSON to also save our frequency array
      // ID and the list that this is saved on shouldn't really be used... counts and notes are not implemented in the app
      localListCopy += "{\"id\": $i, \"name\": \"" + _groceryItemsCopy[i] + "\", \"count\": 1, \"note\": null, \"groceryList\": \"localList\", \"frequency\": " + _groceryItemsFrequency[i].toString() + "}";
    }
    localListCopy += "]";

    File fileCopy = File("$filePath/groceryItemsCopy.json");
    fileCopy.writeAsString(localListCopy); // write the JSON to local file

    // do the same as above with _checkedList
    var checkedList = _checked.toList();
    var localListChecked = "[";
    for (int i = 0; i < checkedList.length; i++) {
      if (i != 0) {
        localListChecked += ", ";
      }
      // add a new frequency category in the JSON to also save our frequency array
      // ID and the list that this is saved on shouldn't really be used... counts and notes are not implemented in the app
      localListChecked += "{\"id\": $i, \"name\": \"" + checkedList[i] + "\", \"count\": 1, \"note\": null, \"groceryList\": \"localList\"}";
    }
    localListChecked += "]";
    File fileChecked = File("$filePath/checked.json");
    fileChecked.writeAsString(localListChecked); // write the JSON to local file

  }

  /* syncs our _checked list to the server, adds other user's _checked items to _checkedAllUsers,
  and returns which items we added to the DB in addedItems */
  Future<List<dynamic>> _syncCheckedToServer(idling) async {

    var _checkedCopy = List.from(_checked); // keeps track of what items to add to DB

    // API call to get all items in the groceryList group we have joined
    var response = await http.get(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup'));
    // convert the Response GET to a JSON (List)
    var jsonResponse = jsonDecode(response.body);

    // string to keep track of items to set visibility to 0 in the DB
    var uncheckedString = '';
    // string to keep track of items to set visibility to 1 in the DB
    var patchString = '';
    // array to keep track of which item names the user specifically added
    var addedItems = [];

    if (idling) {
      var response2 = await http.get(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));
      var jsonResponse2 = jsonDecode(response2.body);
      File file = File("$filePath/purchases.txt");
      var fileString = await File("$filePath/purchases.txt").readAsString();
      if (fileString != jsonResponse2[0]['purchases'].toString()) {
        _checked.clear();
        if (File("$filePath/checked.json").existsSync()) {
          File file2 = File("$filePath/checked.json");
          file2.deleteSync();
        }
        _checkedCopy.clear();
      }
      file.writeAsString(jsonResponse2[0]['purchases'].toString());
    }

    // iterate through all items in the server's groceryList for our group
    for (int i = 0; i < jsonResponse.length; i++) {

      // remove already posted things from checked so no duplicates
      if (_checkedCopy.contains(jsonResponse[i]['name']) && jsonResponse[i]['visible'] == 1) {
        _checkedCopy.remove(jsonResponse[i]['name']);
        if (jsonResponse[i]['username'] == userID) {
          addedItems.add(jsonResponse[i]['name']);
        }
      }

      // if already in the DB, prepare to PATCH visibility from 0 --> 1
      else if (_checkedCopy.contains(jsonResponse[i]['name']) && jsonResponse[i]['visible'] == 0) {
        if (patchString != "") {
          patchString += ",";
        }
        patchString += jsonResponse[i]['id'].toString();
        _checkedCopy.remove(jsonResponse[i]['name']);
        addedItems.add(jsonResponse[i]['name']);
      }

      // else if it was added by us, but is no longer in _checkedCopy
      // prepare to remove (set visibility to 0) items that are swiped right by the user: add to string for API URL
      else if (jsonResponse[i]['username'] == userID && jsonResponse[i]['visible'] == 1) {
        if (uncheckedString != "") {
          uncheckedString += ",";
        }
        uncheckedString += jsonResponse[i]['id'].toString();
      }

      // else if visible it was added by another user and isn't already in _checked, so add it to _checkedAllUsers
      else if (jsonResponse[i]['visible'] == 1) {
        if (!(_checkedAllUsers.contains(jsonResponse[i]['name']))) {
          _checkedAllUsers.add(jsonResponse[i]['name']);
        }
      }

      // else if it is in _checkedAllUsers but visibility is 0, remove it from _checkedAllUsers, as another user removed it
      else if (_checkedAllUsers.contains(jsonResponse[i]['name']) && jsonResponse[i]['visible'] == 0) {
        _checkedAllUsers.remove(jsonResponse[i]['name']);
      }
    }

    // set uncheckedString visibility to 0
    if (uncheckedString != '') {
      await http.patch(Uri.parse('https://api.hungr.dev/items?visible=0&id=$uncheckedString'));
    }

    // set patchString visibility to 1, and change username to ours, as now we're the one adding it to the sharedList
    if (patchString != '') {
      await http.patch(Uri.parse('https://api.hungr.dev/items?visible=1&username=$userID&id=$patchString'));
    }

    // add items not already in DB that are checked to the DB: create String for URL
    var checkedString = '';
    for (var item in _checkedCopy) {
      if (checkedString != '') {
        checkedString += ",";
      }
      checkedString += item;
      addedItems.add(item);
    }

    // if not blank, then post
    if (checkedString != '') {
      await http.post(Uri.parse('https://api.hungr.dev/items?name=$checkedString&count=1&groceryList=$joinedGroup&username=$userID'));
    }

    // return what items have our username on them in the DB to color them blue, to show we can remove them
    return addedItems;

  }

  // adds other user's _checked items to _checkedAllUsers
  Future<void> _getChecked() async {

    // API call to get all items in the groceryList group we have joined
    var response = await http.get(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup'));
    // convert the Response GET to a JSON (List)
    var jsonResponse = jsonDecode(response.body);

    // iterate through all items in the server's groceryList for our group
    for (int i = 0; i < jsonResponse.length; i++) {

      // add any new items to _checkedAllUsers
      if (!(_checkedAllUsers.contains(jsonResponse[i]['name'])) && jsonResponse[i]['visible'] == 1) {
        _checkedAllUsers.add(jsonResponse[i]['name']);
      }
    }
  }

  /* sets every item in the group's visible var to 0 after submitting the list,
  and increments purchased item frequencies in the DB */
  Future<void> _submitAPI(finalShoppingList) async {

    // increment purchases counter
    await http.patch(Uri.parse('https://api.hungr.dev/groceryList?name=$joinedGroup'));

    // increment purchases counter
    // API call to get all items in the groceryList group we have joined
    var response = await http.get(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup'));
    // convert the Response GET to a JSON (List)
    var jsonResponse = jsonDecode(response.body);

    // figure out which items' frequencies to increment in DB
    var purchasedItems = [];
    for (var i = 0; i < finalShoppingList.length; i++) {
      if (finalShoppingList[i] == true) { // if true when submitted,
        purchasedItems.add(_checkedAllUsers[i]);
      }
    }

    // patch all items in the list's visibility to 0 and increment the item ID matching those in purchasedItems
    var patchString = '';
    var patchFrequencies = '';
    for (var i = 0; i < jsonResponse.length; i++) {
      // add all items to patchString to set visibility=0
      if (patchString != '') {
        patchString += ',';
      }
      patchString += jsonResponse[i]['id'].toString();

      // add items in purchasedItems to patchFrequencies string, and their new frequency to frequencies
      if (purchasedItems.contains(jsonResponse[i]['name'])) {
        if (patchFrequencies != '') {
          patchFrequencies += ',';
        }
        patchFrequencies += "'";
        patchFrequencies += jsonResponse[i]['name'].toString();
        patchFrequencies += "'";
      }
    }

    if (patchString != '') {
      await http.patch(Uri.parse('https://api.hungr.dev/items?visible=0&id=$patchString'));
    }
    if (patchFrequencies != '') {
      await http.patch(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup&names=$patchFrequencies'));
    }

    File file2 = File("$filePath/purchases.txt");
    var incrementString = await File("$filePath/purchases.txt").readAsString();
    var incrementInt = int.parse(incrementString);
    incrementInt++;
    file2.writeAsString(incrementInt.toString());
  }

  // generates a random group code for users to join
  void _generateGroupCode() {
    const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    // generate a random number from 20 - 100
    int randomNumber = Random.secure().nextInt(81) + 20;
    // generate a random string with randomNumber number of characters, and selecting a random character for each index from _chars
    joinableGroup = String.fromCharCodes(Iterable.generate(randomNumber, (_) => _chars.codeUnitAt(Random.secure().nextInt(_chars.length))));
    File file = File("$filePath/joinableGroup.txt");
    file.writeAsString(joinableGroup);
  }

  // sort the list by the frequency purchases of the joined group stored in the DB
  Future<void> _groupFrequencySort() async {

    // API call to get all items in the groceryList group we have joined
    var response = await http.get(Uri.parse('https://api.hungr.dev/items?groceryList=$joinedGroup&desc=desc'));
    // convert the Response GET to a JSON (List)
    var jsonResponse = jsonDecode(response.body);

    //re-set sorting bools
    _frequencySorted = false;
    _alphabeticallySorted = false;
    _groupFrequencySorted = true;

    // store a copy of _groceryItems to repopulate from
    final groceryItemsPlaceHolder = List.from(_groceryItems);

    // clear the list that displays the view
    _groceryItems.clear();

    // loop through our sorted response, repopulating _groceryItems in the correct order
    for (var i = 0; i < jsonResponse.length; i++) {
      if (groceryItemsPlaceHolder.contains(jsonResponse[i]['name'])) {
        groceryItemsPlaceHolder.remove(jsonResponse[i]['name']);
        _groceryItems.add(jsonResponse[i]['name']);
      }
    }

    // add any items that are local but not in DB back as well
    for (var i = 0; i < groceryItemsPlaceHolder.length; i++) {
      _groceryItems.add(groceryItemsPlaceHolder[i]);
    }

    // reset the view
    setState((){});

    // save on file that it is sorted
    File file = File("$filePath/sorted.txt");
    file.writeAsString("_groupFrequencySorted");

    // save the list again
    _saveLocalList();
  }

  // pushes notifications to everyone in the same group
  Future<bool> pushNotification(String title) async {
    try {

      var url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      var header = {
        "Content-Type": "application/json",
        "Authorization":
        "key=AAAAuQkjNLQ:APA91bFt60NPmkdCRhHj_fWVVgtZcM8GlthHt-sCVqU_5AklKvw7syP7F3Z8osE2Ub9KFIbATCLW8h_8yIdwpzV7im3MFpTsxw63yJ0Sy2cM1NdVf2cfNyJamdTTv9zsQNkkMOEyN-vq",
      };
      var request = {
        "notification": {
          "title": title,
          "body": "$userID has added items to your group's grocery list.",
        },
        "priority": "high",
        "to": "/topics/$joinedGroup", // everyone who joins a group also subscribes to the topic
      };

      await http.Client().post(url, headers: header, body: json.encode(request));
      return true;
    } catch (e) {return false;}
  }

}