import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart';

class CleanerScreen extends StatelessWidget {
  // Fetch jobs assigned to cleaners (only unaccepted jobs)
  Stream<QuerySnapshot> getJobsStream() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedCleaner', isEqualTo: null) // Only show unassigned jobs
        .snapshots();
  }

  // Accept a job
  Future<void> acceptJob(String jobId, String customerId, BuildContext context) async {
    User? cleaner = FirebaseAuth.instance.currentUser;
    if (cleaner != null) {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'assignedCleaner': cleaner.uid,
        'status': 'Accepted',
      });

      // Send notification to customer
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId,
        'message': 'Your job has been accepted by a cleaner!',
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Job accepted and notification sent!");

      // Show success message and navigate to the next tab
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job Accepted Successfully!')),
      );

      // Navigate to the Payments & Reviews Tab (index 1)
      DefaultTabController.of(context)?.animateTo(1); // This changes to the 2nd tab (Payments & Reviews)
    }
  }

  // Jobs Tab (Displays list of available jobs)
  Widget jobsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getJobsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error loading jobs"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No jobs available"));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var job = doc.data() as Map<String, dynamic>;
            String jobId = doc.id;

            String rooms = job['numberOfRooms'] ?? 0;
            String bathrooms = job['numberOfBathrooms'] ?? 0;
            double price = job['price']?.toDouble() ?? 0.0;

            return Card(
              margin: EdgeInsets.all(10),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Job Details: ${job['jobDetails']}",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("Customer: ${job['userName']}"),
                    Text("Email: ${job['userEmail']}"),
                    Text("Date: ${formatTimestamp(job['jobDate'])}"),
                    Text("Time: ${job['jobTime']}"),
                    Text("Location: ${job['location']}"),
                    Text("Property: ${job['propertyDetails']}"),
                    Text("Rooms: $rooms, Bathrooms: $bathrooms"),
                    Text("Price: Rs.${price.toStringAsFixed(2)}"),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => acceptJob(jobId, job['userId'], context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text("Accept Job"),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return "${dateTime.day}-${dateTime.month}-${dateTime.year}";
  }

  Widget paymentsAndReviewsTab(BuildContext context) {
    return Column(
      children: [
        // Section 1: Ongoing Jobs
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Ongoing Jobs",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(
          flex: 1,
          child: StreamBuilder<QuerySnapshot>(
            stream: getAcceptedJobsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("No jobs in progress"));
              }

              return ListView(
                padding: EdgeInsets.symmetric(horizontal: 10),
                children: snapshot.data!.docs.map((doc) {
                  var job = doc.data() as Map<String, dynamic>;
                  String jobId = doc.id;

                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Job: ${job['jobDetails']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Text("Customer: ${job['userName']}"),
                          Text("Email: ${job['userEmail']}"),
                          Text("Date: ${formatTimestamp(job['jobDate'])}"),
                          Text("Time: ${job['jobTime']}"),
                          Text("Price: Rs.${job['price'].toStringAsFixed(2)}"),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () async {
                              await endJob(jobId, job['userId'], context);
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Leave a Review'),
                                  content: ReviewForm(jobId: jobId, customerId: job['userId']),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: Text("End Job"),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        Divider(thickness: 2, height: 30),

        // Section 2: Reviews
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Reviews",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(
          flex: 1,
          child: StreamBuilder<QuerySnapshot>(
            stream: fetchReviewsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("No reviews found"));
              }

              var reviews = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 10),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  var reviewDoc = reviews[index];
                  var review = reviewDoc.data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fetch and display customer name and email
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(review['customerId'])
                                .get(),
                            builder: (context, customerSnapshot) {
                              if (customerSnapshot.connectionState == ConnectionState.waiting) {
                                return Text("Loading customer...");
                              }
                              if (!customerSnapshot.hasData) {
                                return Text("Unknown Customer");
                              }

                              var customerData = customerSnapshot.data!.data() as Map<String, dynamic>;
                              return Text(
                                "Customer: ${customerData['name'] ?? 'Unknown'} (${customerData['email'] ?? 'No email'})",
                                style: TextStyle(fontStyle: FontStyle.italic),
                              );
                            },
                          ),
                          SizedBox(height: 8),
                          Text('Your Review: ${review['review'] ?? 'No review'}'),
                          Text('Date: ${formatTimestamp(review['timestamp'])}'),
                          SizedBox(height: 8),
                          review['replyText'] != null && review['replyText'].isNotEmpty
                              ? Text('Customer Reply: ${review['replyText']}',
                              style: TextStyle(color: Colors.green))
                              : Text('No reply provided yet', style: TextStyle(color: Colors.red)),
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
  Stream<QuerySnapshot> fetchReviewsStream() {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return FirebaseFirestore.instance
          .collection('reviews')
          .where('cleanerId', isEqualTo: user.uid)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('reviews')
        .where('cleanerId', isEqualTo: '__NO_USER__')
        .snapshots();
  }



  // Profile Tab (Displays Cleaner Profile)
  Widget profileTab(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text("User data not found"));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(
                  userData['profilePicture'] ??
                      'https://www.silcharmunicipality.in/wp-content/uploads/2021/02/male-face.jpg',
                ),
                backgroundColor: Colors.grey[200],
              ),
              SizedBox(height: 20),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(Icons.person, color: Colors.blue),
                        title: Text('Name: ${userData['name']}',
                            style: TextStyle(fontSize: 18)),
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.email, color: Colors.blue),
                        title: Text('Email: ${userData['email']}',
                            style: TextStyle(fontSize: 18)),
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.account_circle, color: Colors.blue),
                        title: Text('User Type: ${userData['userType']}',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text("Logout", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Fetch accepted jobs for the current cleaner
  Stream<QuerySnapshot> getAcceptedJobsStream() {
    User? cleaner = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedCleaner', isEqualTo: cleaner?.uid)
        .where('status', isEqualTo: 'Accepted')
        .snapshots();
  }

  // End Job and mark as completed
  Future<void> endJob(String jobId, String customerId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'Completed',
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Job Finished Successfully')));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Elite Shine - Cleaner"),
          backgroundColor: Colors.green,
          bottom: TabBar(
            tabs: [
              Tab(text: "Jobs"),
              Tab(text: "Ongoing Jobs & Reviews"),
              Tab(text: "Profile"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            jobsTab(),
            paymentsAndReviewsTab(context),
            profileTab(context),
          ],
        ),
      ),
    );
  }
}

class ReviewForm extends StatefulWidget {
  final String jobId;
  final String customerId;

  ReviewForm({required this.jobId, required this.customerId});

  @override
  _ReviewFormState createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final TextEditingController _reviewController = TextEditingController();

  Future<void> submitReview() async {
    User? cleaner = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('reviews').add({
      'jobId': widget.jobId,
      'cleanerId': cleaner?.uid,
      'customerId': widget.customerId,
      'review': _reviewController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context); // Close dialog
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review submitted!')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _reviewController,
          decoration: InputDecoration(labelText: "Write your review"),
          maxLines: 3,
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: submitReview,
          child: Text("Submit"),
        ),
      ],
    );
  }
}
