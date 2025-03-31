import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart'; // Import LoginScreen for logout navigation

class CustomerScreen extends StatefulWidget {
  @override
  _CustomerScreenState createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final TextEditingController _jobDetailsController = TextEditingController();
  final TextEditingController _propertyDetailsController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _flooringTypeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _location; // Store location
  List<DocumentSnapshot> _jobs = []; // Store fetched jobs

  // Function to fetch the jobs from Firestore
  Future<void> fetchJobs() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var jobSnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('userId', isEqualTo: user.uid)
          .get();
      setState(() {
        _jobs = jobSnapshot.docs;
      });
    }
  }

  // Function to calculate the price based on job details
  double calculatePrice(int rooms, int bathrooms) {
    const double pricePerRoom = 2500;
    const double pricePerBathroom = 3000;

    return (rooms * pricePerRoom) + (bathrooms * pricePerBathroom);
  }


  // Function to add job details to Firestore (including date, time, location, and price)
  Future<void> addJobToFirestore() async {
    if (_selectedDate != null && _selectedTime != null && _location != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user details from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("User details not found!")));
          return;
        }

        // Extract user name and email
        String userName = userDoc['name'] ?? "Unknown";
        String userEmail = userDoc['email'] ?? "Unknown";

        // Calculate job price
        int rooms = int.tryParse(_roomsController.text) ?? 0;
        int bathrooms = int.tryParse(_bathroomsController.text) ?? 0;

        // Calculate price based on rooms and bathrooms
        double price = calculatePrice(rooms, bathrooms);


        // Save job to Firestore
        await FirebaseFirestore.instance.collection('jobs').add({
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'jobDetails': _jobDetailsController.text,
          'propertyDetails': _propertyDetailsController.text,
          'numberOfRooms': _roomsController.text,
          'numberOfBathrooms': _bathroomsController.text,
          'flooringType': _flooringTypeController.text,
          'jobDate': _selectedDate,
          'jobTime': _selectedTime!.format(context),
          'location': _location,
          'price': price,
          'timestamp': FieldValue.serverTimestamp(),
        });


        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Job added successfully")));

        fetchJobs(); // Refresh the job list
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select all fields")));
    }
  }


  // Edit job function
  Future<void> editJob(String jobId) async {
    // Navigate to an edit screen or open a dialog to edit job
    // Update the job in Firestore with the new details.
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Edit Job functionality not implemented yet")));
  }

  // Delete job function
  Future<void> deleteJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
    fetchJobs(); // Refresh the job list after deletion
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Job deleted successfully")));
  }

  // Function to get the user's current location
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  @override
  void initState() {
    super.initState();
    fetchJobs(); // Load jobs on screen initialization
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text("Elite Shine - Customer"),
          backgroundColor: Colors.blue,
          bottom: TabBar(
            tabs: [
              Tab(text: "Add Jobs"),
              Tab(text: "Accepted Jobs & Reviews"),
              Tab(text: "Profile"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            addJobsTab(),
            paymentsTab(),
            profileTab(context),
          ],
        ),
      ),
    );
  }

  // Add Jobs Tab
  Widget addJobsTab() {
    return SingleChildScrollView( // Wrap the content in a scrollable view
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Job Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(
              controller: _jobDetailsController,
              decoration: InputDecoration(labelText: 'Enter Job Details'),
            ),
            SizedBox(height: 10),
            Text("Property Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(
              controller: _propertyDetailsController,
              decoration: InputDecoration(labelText: 'Enter Property Details'),
            ),
            SizedBox(height: 10),
            Text("House Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(
              controller: _roomsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Number of Rooms'),
            ),
            TextField(
              controller: _bathroomsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Number of Bathrooms'),
            ),
            TextField(
              controller: _flooringTypeController,
              decoration: InputDecoration(labelText: 'Flooring Type'),
            ),
            SizedBox(height: 10),
            Text("Select Date", style: TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text(_selectedDate == null ? 'Pick Date' : '${_selectedDate!.toLocal()}'.split(' ')[0]),
            ),
            SizedBox(height: 20),
            Text("Select Time", style: TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: () => _selectTime(context),
              child: Text(_selectedTime == null ? 'Pick Time' : _selectedTime!.format(context)),
            ),
            SizedBox(height: 20),
            Text("Select Location", style: TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: () async {
                Position position = await _getCurrentLocation();
                setState(() {
                  _location = 'Lat: ${position.latitude}, Long: ${position.longitude}';
                });
              },
              child: Text(_location ?? 'Pick Location'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: addJobToFirestore,
              child: Text("Submit Job"),
            ),
            SizedBox(height: 20),
            // Displaying jobs
            Text("Submitted Jobs:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _jobs.length,
              itemBuilder: (context, index) {
                var job = _jobs[index].data() as Map<String, dynamic>;
                double price = job['price'] ?? 0.0;
                return Card(
                  child: ListTile(
                    title: Text(job['jobDetails']),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            editJob(_jobs[index].id);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            deleteJob(_jobs[index].id);
                          },
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Convert Firestore Timestamp to readable format
                        Text('Rooms: ${job['numberOfRooms'] ?? 'N/A'}', style: TextStyle(fontSize: 14)),
                        Text('Bathrooms: ${job['numberOfBathrooms'] ?? 'N/A'}', style: TextStyle(fontSize: 14)),
                        Text('Flooring: ${job['flooringType'] ?? 'N/A'}', style: TextStyle(fontSize: 14)),

                        Text("Date: ${formatTimestamp(job['jobDate'])}"),

                        Text(
                          'Time: ${job['jobTime']}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Location: ${job['location']}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Price: \$${price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate(); // Convert Firestore timestamp to DateTime
    return "${dateTime.day}-${dateTime.month}-${dateTime.year}"; // Format as DD-MM-YYYY
  }

  // Payments & Reviews Tab
  // Payments & Reviews Tab
  // Payments & Reviews Tab
  Widget paymentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Accepted Jobs",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // Ongoing Jobs List
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('jobs')
                .where('status', isEqualTo: 'Accepted')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error loading jobs"));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("No Ongoing Jobs Available."));
              }

              var jobs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  var jobData = jobs[index].data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Job Details: ${jobData['jobDetails'] ?? 'N/A'}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Date: ${jobData['jobDate'].toDate().toLocal()}"),
                          Text("Time: ${jobData['jobTime']}"),
                          Text("Rooms: ${jobData['numberOfRooms']} | Bathrooms: ${jobData['numberOfBathrooms']}"),
                          Text("Flooring: ${jobData['flooringType']}"),
                          Text("Price: ${jobData['price']}"),
                          Text("Location: ${jobData['location']}"),
                          SizedBox(height: 8),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(jobData['assignedCleaner'])
                                .get(),
                            builder: (context, cleanerSnapshot) {
                              if (cleanerSnapshot.connectionState == ConnectionState.waiting) {
                                return Text("Loading cleaner details...");
                              }

                              if (cleanerSnapshot.hasError || !cleanerSnapshot.hasData) {
                                return Text("Cleaner: Unknown");
                              }

                              var cleanerData = cleanerSnapshot.data!.data() as Map<String, dynamic>;
                              return Text("Assigned Cleaner: ${cleanerData['name'] ?? 'Unknown'}", style: TextStyle(color: Colors.green));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Divider(height: 32, thickness: 1),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Reviews",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // Reviews Section (Already provided)
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: fetchReviews(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error loading reviews"));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("No reviews found"));
              }

              var reviews = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.all(16.0),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  var reviewDoc = reviews[index];
                  var review = reviewDoc.data() as Map<String, dynamic>;
                  TextEditingController replyFieldController =
                  TextEditingController(text: review['replyText'] ?? '');

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(review['cleanerId'])
                                .get(),
                            builder: (context, cleanerSnapshot) {
                              if (cleanerSnapshot.connectionState == ConnectionState.waiting) {
                                return Text("Loading cleaner name...");
                              }

                              if (cleanerSnapshot.hasError || !cleanerSnapshot.hasData) {
                                return Text("Unknown Cleaner");
                              }

                              var cleanerData = cleanerSnapshot.data!.data() as Map<String, dynamic>;
                              return Text(cleanerData['name'] ?? 'Unknown Cleaner',
                                  style: TextStyle(fontWeight: FontWeight.bold));
                            },
                          ),
                          SizedBox(height: 8),
                          Text('Review: ${review['review'] ?? 'No review text'}'),
                          Text('Date: ${formatTimestamp(review['timestamp'])}'),
                          SizedBox(height: 8),
                          review['replyText'] != null && review['replyText'].isNotEmpty
                              ? Text('Your Reply: ${review['replyText']}',
                              style: TextStyle(color: Colors.green))
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: replyFieldController,
                                decoration: InputDecoration(
                                  hintText: "Write a reply...",
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  String reply = replyFieldController.text.trim();
                                  if (reply.isNotEmpty) {
                                    await FirebaseFirestore.instance
                                        .collection('reviews')
                                        .doc(reviewDoc.id)
                                        .update({'replyText': reply});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Reply sent')),
                                    );
                                    (context as Element).reassemble();
                                  }
                                },
                                child: Text("Send Reply"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


// Function to fetch reviews from Firestore
  Future<QuerySnapshot> fetchReviews() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Fetch reviews for the current user (using customerId)
      return await FirebaseFirestore.instance
          .collection('reviews')
          .where('customerId', isEqualTo: user.uid)
          .get();
    }

    // Return an empty QuerySnapshot by querying an impossible condition
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('customerId', isEqualTo: '__NO_USER__')
        .get();
  }


  // Profile Tab
  Widget profileTab(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error loading profile"));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No user data found"));
        }

        // Get the user data
        var userData = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Picture & Name Section
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(userData['profilePicture'] ?? 'https://www.silcharmunicipality.in/wp-content/uploads/2021/02/male-face.jpg'),
                ),
                SizedBox(height: 20),
                Text(
                  userData['name'] ?? 'Name not available',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Email: ${userData['email']}',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  'User Type: ${userData['userType']}',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                // Profile Information Card
                Card(
                  elevation: 5,
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Name: ${userData['name']}'),
                        ),
                        ListTile(
                          leading: Icon(Icons.email),
                          title: Text('Email: ${userData['email']}'),
                        ),
                        ListTile(
                          leading: Icon(Icons.account_circle),
                          title: Text('User Type: ${userData['userType']}'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Edit Button (Optional)
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Edit Profile functionality not implemented yet")));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Button color
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text("Edit Profile", style: TextStyle(fontSize: 18)),
                ),
                SizedBox(height: 20),
                // Logout Button
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red logout button
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text("Logout", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userData.data() as Map<String, dynamic>;
    }
    return {}; // Return an empty map if no user is logged in
  }

  // Function to pick the date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate)
      setState(() {
        _selectedDate = picked;
      });
  }

  // Function to pick the time
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime)
      setState(() {
        _selectedTime = picked;
      });
  }
// Function to fetch reviews from Firestore


}