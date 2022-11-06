import 'package:flutter/material.dart';
// for Dart API calls
import 'package:http/http.dart' as http; // use API calls (GET...)
import 'dart:convert'; // convert GET result to JSON/List
// for local file storage
import 'package:path_provider/path_provider.dart'; // use getApplicationDocumentsDirectory()
import 'dart:io'; // use Directory, File...

/* global variable for initial food list for all new users.
  will be filled as a future/from API call */
final _groceryItems = [];

// used for sorting based on frequency
final _groceryItemsFrequency = [];

/* used for unsorting: maintain the old order. Also for frequency sort.
  can also be used to keep old removed items, and add them back */
var _groceryItemsCopy = [];

var loggedIn = false; // needs to check if the user is logged in, currently does nothing

var filePath = ''; // path to where this app saves files, calculated in main()

// stores if the list has been alphabetically sorted. used if a new item is added, to put in proper place
var _alphabeticallySorted = false;
var _frequencySorted = false;

// make main() async for Futures
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // get the phone's path to where it saves files for this app
  Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
  var appDocumentsPath = appDocumentsDirectory.path;
  filePath = "$appDocumentsPath";

  // loggedIn boolean NOT IMPLEMENTED YET
  if (loggedIn) {
    /** get groceryList from API, check what group they're in...
        ACTUALLY, don't we want each user to have their own local list?
        SO, we probably don't want this.
        API calls should actually only happen when... clicking Add to Shared List / clicking Generate Shopping List? **/
  }

  // this will likely be changed to the first IF, and above removed
  // else check if there's a local file, and use that
  else if (File(filePath + "/groceryItems.json").existsSync() && File(filePath + "/groceryItemsCopy.json").existsSync()) {
    // convert the .json json and save in _groceryItems
    var fileContent = await File(filePath + "/groceryItems.json").readAsString();
    var jsonLocalList = jsonDecode(fileContent);
    /* populate the initial array with localList's
    items (their names) from the API call */
    for (int i = 0; i < jsonLocalList.length; i++) {
      _groceryItems.add(jsonLocalList[i]['name']);
    }

    var fileContentCopy = await File(filePath + "/groceryItemsCopy.json").readAsString();
    var jsonLocalListCopy = jsonDecode(fileContentCopy);
    /* populate the copy array with localListCopy's
    items (their names) from the API call.
     Frequency is based on the copy list, so also populate these */
    for (int i = 0; i < jsonLocalListCopy.length; i++) {
      _groceryItemsCopy.add(jsonLocalListCopy[i]['name']);
      _groceryItemsFrequency.add(jsonLocalListCopy[i]['frequency']);
    }

    // if the user never sorted but edited the list...
    if (!(File(filePath + "/sorted.json").existsSync())) {
      File file = File(filePath + "/sorted.json");
      file.writeAsString("");
    }

    var sortedFile = await File(filePath + "/sorted.json").readAsString();
    if (sortedFile == "_alphabeticallySorted") {
      _alphabeticallySorted = true;
    } else if (sortedFile == "_frequencySorted") {
      _frequencySorted = true;
    }
  }

  // else use the default list
  else { /** actually later let's not do this API call, and just initialize _groceryItems as the global pre-populated, like I did
      at the beginning of the original version, then we can clear it in the above else if and repopulate it there,
      making this API call not have to happen. Saving this for later use to see how API calls work, though... **/

    // API call to get the initial starting list every user will have
    var response = await http.get(Uri.parse('http://api.hungr.dev:5000/items?groceryList=startingList'));
    // convert the Response GET to a JSON (List)
    var jsonResponse = jsonDecode(response.body);
    /* populate the initial array with the groceryList startingList's
   items (their names) from the API call.
    Also initialize frequency values as all 0s */
    for (int i = 0; i < jsonResponse.length; i++) {
      _groceryItems.add(jsonResponse[i]['name']);
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
      title: 'Grocery Prototype',
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

  /* replaced with API call in main() else{} clause, but we're going to want this back */
  // our grocery list
  // final _groceryItems = ['Eggs', 'Milk', 'Fish Sauce', 'Bread', 'Apple Juice', 'Coke', 'Potato Chips',
  //  'Froot Loops', 'Oatmeal', 'Snickers', 'Cheddar Cheese', 'Beer', 'Water', 'Cigarettes',
  //  'Oreos', 'Ham', 'Wine', 'Bananas', 'Spinach', 'Cherries', 'Ketchup', 'Coffee', 'Hot Dogs'];

  /* replaced in main() else{} clause as a copy of _groceryItems */
  // final _groceryItemsCopy = ['Eggs', 'Milk', 'Fish Sauce', 'Bread', 'Apple Juice', 'Coke', 'Potato Chips',
  //  'Froot Loops', 'Oatmeal', 'Snickers', 'Cheddar Cheese', 'Beer', 'Water', 'Cigarettes',
  //  'Oreos', 'Ham', 'Wine', 'Bananas', 'Spinach', 'Cherries', 'Ketchup', 'Coffee', 'Hot Dogs'];

  var finalShoppingList = []; // holds bools for if the final shopping list is checked or unchecked
  var checkedList = []; // holds a copy of _checked that shouldn't be able to be updated for the final shopping list

  /* Replaced in main() else{} clause as less hard-coded version */
  // final _groceryItemsFrequency = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  // used for the finished shopping pop-up box
  var _finishedShopping = false;

  // holds all of the checked items in a set, so they can't be duplicated
  final _checked = <String>{};

  // home screen (1st) definition
  @override
  Widget build(BuildContext context) {
    /* wrap the ListView builder in the scaffold, and make the listview the body
    Now we can edit the app bar for this specific page */
    return Scaffold(

      // scaffold pt 1: appBar
      appBar: AppBar(
        title: const Text('Grocery Prototype'),
        actions: [
          SizedBox(
            width: 110,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(42)
                  )),
              onPressed: _viewSharedList,
              child: const Text('Add to Shared List',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black),),
            ),
            // make a popup menu (3 dot menu in the top right)
          ),
          PopupMenuButton(

            // logic for the option chosen goes here
            onSelected: (selectedValue) {
              if (selectedValue == 0) { // sort alphabetically
                // in setState to update the view
                setState(() {
                  // sort the list alphabetically, and set boolean to true
                  _groceryItems.sort();
                  _alphabeticallySorted = true;
                  _frequencySorted = false;

                  // save on file that it is sorted
                  File file = File(filePath + "/sorted.json");
                  file.writeAsString("_alphabeticallySorted");
                });
                _saveLocalList();
              } else if (selectedValue == 1) { // sort by purchase frequency
                _frequencySort();
              } else if (selectedValue == 2) { // unsort
                _unsort(); // call un-sort algorithm, using copy of the list
              } else if (selectedValue == 3) { // repopulate deleted items
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
                } else {
                  _unsort();
                }

              } else if (selectedValue == 4) { // check all
                _checked.clear();
                for (final item in _groceryItems) {
                  setState(() {
                    _checked.add(item);
                  });
                }
              } else if (selectedValue == 5) { // uncheck all
                setState(() {
                  _checked.clear();
                });
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
                child: Text('Unsort'),
              ),
              const PopupMenuItem(
                value: 3,
                child: Text('Repopulate Deleted Items'),
              ),
              const PopupMenuItem(
                value: 4,
                child: Text('Check All'),
              ),
              const PopupMenuItem(
                value: 5,
                child: Text('Uncheck All'),
              ),
            ],
          ),
        ],
      ),

      // scaffold pt 2: List View
      body: ListView.builder(
        itemCount: _groceryItems.length * 2, /* Set the list size.
                            * 2 for the divider after every item */
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, i) { // builds what we'll populate the list with
          if (i.isOdd) return const Divider(); // make a divider between items
          final index = i ~/ 2; // gets the number of items, by subtracting dividers

          // boolean to show if a box is already checked (contained in the _checked set) or not
          final alreadyChecked = _checked.contains(_groceryItems[index]);

          return Dismissible(key: ValueKey(_groceryItems[index]), /* wrapping the return ListTile
          return in a Dismissible, and making the ListTile a child: lets us swipe it right.
          We also need to remove it from the array, however */

            /* onDismissed sets the what happens when we swipe. Need to remove item from the array,
            and make sure we update the state. Setting the direction of the dismissible
            makes it only go start to end, for example: --> swipe right. Switched from onDismissed
             to confirmDismiss: */
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                setState(() {
                  // if remove an item from the viewable list, also remove it from shared/_checked list?
                  // previously it was keeping it, so you could check a box, and then remove it from your local list,
                  // but it would remain in _checked / middle list, with no way to remove it, without re-adding the item...
                  _checked.remove(_groceryItems[index]);
                  _groceryItems.remove(_groceryItems[index]);
                });
                _saveLocalList(); // update the locally saved list
                // disable swipe left, for now
              } else if (direction == DismissDirection.endToStart) {
              }
            },

            child: ListTile( // make a Text List tile and add it to the list
              title: Text(
                _groceryItems[index],
                style: const TextStyle(fontSize: 18),
              ),
              trailing: Icon(
                alreadyChecked ? Icons.check_box : Icons.check_box_outline_blank, /* if (alreadySaved) {
                                                                          return(?) Icons.favorite;
                                                                        } else { return(?) Icons.favorite_border } */
                semanticLabel: alreadyChecked ? 'Add to shared List' : 'Remove',
              ),
              onTap: () {
                // sets the state of the checkbox as above ^
                setState(() {
                  if (alreadyChecked) {
                    _checked.remove(_groceryItems[index]);
                  } else {
                    _checked.add(_groceryItems[index]);
                  }
                });
              },
              onLongPress: () {
                _popUp(_groceryItems[index]);
              },
            ),
          );
        },
      ),

      // scaffold pt 3: floating buttons
      floatingActionButton: Row(
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
            onPressed: _loginScreen,
            label: const Text('Join a Group'),
          ),
        ],
      ),

    );
  }

  /* pushes the new screen (2nd) on to the stack, after pressing the shared list view button
  in the app bar */
  void _viewSharedList() {
    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        // builder builds the scaffold with the app bar and the body with the list view rows
        builder: (context) { // context shows the relation of this context to others

          /* iterate the set using .map, and create a tile of each list item. list items
          are in variable checkedItems, iteratively. currently no trailing icon, because it's the end */
          final sharedListTiles = _checked.map((checkedItems) {
            return ListTile(
              title: Text(
                checkedItems,
                style: const TextStyle(fontSize: 18),
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
                    onPressed: _storeList,
                    child: const Text('Generate Shopping List',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black),),
                  ),
                ),
              ],
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  /* pushes the login screen (3rd) on to the stack, after pressing Join a Group button */
  void _loginScreen() {
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
                        onPressed: () {

                        },
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
  void _storeList() {
    // convert the dynamic set _checked to a personal shopping list, only for the shopper
    checkedList = _checked.toList();

    /* make a boolean for each item with a checkbox in the list, to update the icon with
    if true, icon's checked, if false, unchecked. Starts false */
    finalShoppingList = List.filled(checkedList.length, false);

    Navigator.of(context).push( // push on the new screen

      // create the new page / screen
      MaterialPageRoute<void>(

        /* builder builds the scaffold with the app bar and the body with the list view rows
        builder is required for MaterialPageRoute */
        builder: (BuildContext context) {

          /* we must return a StatefulBuilder if we want to update the state, else
          it seemingly doesn't update the view */
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) { // part of StatefulBuilder

                // iterates through the _checkedList, making each item checkedItems one at a time
                final sharedListTiles = checkedList.map((checkedItems) {

                  // make a ListTile
                  return ListTile(

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
                            finalShoppingList[checkedList.indexOf(checkedItems)] ? Icons.check_box : Icons.check_box_outline_blank,
                          ),
                        ],
                      ),

                      //
                    ),

                    /* when tapped, update the state by changing the boolean value, meaning checks and unchecks the box.
              this works here because we're using StatefulBuilder */
                    onTap: () {
                      setState(() {
                        finalShoppingList[checkedList.indexOf(checkedItems)] =
                        !finalShoppingList[checkedList.indexOf(checkedItems)];
                      });
                    },
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
      ),
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
                  onPressed: () {

                    // if submitting the completed shopping list
                    if (_finishedShopping) {
                      _checked.clear(); // clear shopping list, as shopping is done

                      /* increment _groceryItemsFrequency for submitted items, measuring frequency.
                      iterate bools of finalShoppingList */
                      for (var i = 0; i < finalShoppingList.length; i++) {
                        if (finalShoppingList[i] == true) { // if true when submitted,
                          // increment frequency of proper item, based on _groceryItemsCopy
                          _groceryItemsFrequency[_groceryItemsCopy.indexOf(checkedList[i])]++;
                        }
                      }
                      if (_frequencySorted) { // incremented frequencies, so re-sort
                        _frequencySort();
                      }

                      setState(() {});

                      /* return to the home screen by pushing. could change GroceryItems() to MyApp() also.
                      Not really sure why we need both of these commands, but with only one, it doesn't work? */
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GroceryItems()),
                      );
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

                      setState(() {
                        /* add the item to the list. if() statement checks if the item is already
                        in the list, and doesn't copy it if so. */
                        if (!_groceryItems.contains(controller.text)) {
                          _groceryItems.add(controller.text);
                          _saveLocalList(); // list is changed, so save locally
                        }
                        if (!_groceryItemsCopy.contains(controller.text)) {
                          _groceryItemsCopy.add(controller.text);
                          _groceryItemsFrequency.add(0); // starting frequency is 0
                        }

                        // maintain sorts, if true
                        if (_alphabeticallySorted) {
                          _groceryItems.sort();
                          _saveLocalList();
                        } else if (_frequencySorted) { // in case of re-adding an item stored in the copy
                          _frequencySort();
                        }
                      });

                      // if addOrDelete is false, we're deleting, not adding
                    } else if (!addOrDelete) {
                      setState(() {
                        // remove from _checked list if removing from local list, in case removing while checked
                        _checked.remove(groceryListValue);
                        // remove from view list
                        _groceryItems.remove(groceryListValue);
                        // permanently delete from long press, so delete from copy list and related frequency list
                        _groceryItemsFrequency.removeAt(_groceryItemsCopy.indexOf(groceryListValue));
                        _groceryItemsCopy.remove(groceryListValue);
                      });
                      _saveLocalList(); // re-save locally since we're going back to original sort
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
    setState(() {});

    // save on file that it is unsorted
    File file = File(filePath + "/sorted.json");
    file.writeAsString("");

    _saveLocalList(); // re-save locally since we're going back to original sort
  }

  void _frequencySort() {

    //re-set sorting bools
    _frequencySorted = true;
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
    //reset the view
    setState(() {});

    // save on file that it is sorted
    File file = File(filePath + "/sorted.json");
    file.writeAsString("_frequencySorted");

    // save the list again
    _saveLocalList();
  }

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
    File file = File(filePath + "/groceryItems.json");
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

    File fileCopy = File(filePath + "/groceryItemsCopy.json");
    fileCopy.writeAsString(localListCopy); // write the JSON to local file

  }

}