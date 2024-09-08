import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// ignore: library_prefixes
import 'package:firebase_storage/firebase_storage.dart' as fStorage;
import 'package:shared_preferences/shared_preferences.dart';
import '../authentication/login.dart';
import '../global/global.dart';
import '../screens/home_screen.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_dialog.dart';
import '../widgets/header_widget.dart';
import '../widgets/loading_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmpasswordController = TextEditingController();

  // Image picker
  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();

  // User image URL
  String userImageUrl = "";

  // Function to get image (web and mobile)
  Future<void> _getImage() async {
    if (kIsWeb) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final Uint8List imageData = await pickedFile.readAsBytes();
        setState(() {
          imageXFile = XFile.fromData(imageData, name: pickedFile.name);
        });
      }
    } else {
      imageXFile = await _picker.pickImage(source: ImageSource.gallery);
      setState(() {});
    }
  }

  // Form validation
  Future<void> signUpFormValidation() async {
    if (imageXFile == null) {
      showDialog(
        context: context,
        builder: (c) {
          return const ErrorDialog(message: "Please select an image");
        },
      );
    } else if (passwordController.text == confirmpasswordController.text) {
      if (nameController.text.isNotEmpty &&
          emailController.text.isNotEmpty &&
          passwordController.text.isNotEmpty) {
        
        showDialog(
          context: context,
          builder: (c) {
            return const LoadingDialog(message: "Registering Account");
          },
        );

        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        fStorage.Reference reference = fStorage.FirebaseStorage.instance
            .ref()
            .child("users")
            .child(fileName);

        if (kIsWeb) {
          // Web upload using data from XFile
          final Uint8List imageData = await imageXFile!.readAsBytes();
          fStorage.UploadTask uploadTask = reference.putData(imageData);
          fStorage.TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});
          await taskSnapshot.ref.getDownloadURL().then((url) {
            userImageUrl = url;
            AuthenticateSellerAndSignUp();
          });
        } else {
          // Mobile upload
          fStorage.UploadTask uploadTask =
              reference.putFile(File(imageXFile!.path));
          fStorage.TaskSnapshot taskSnapshot =
              await uploadTask.whenComplete(() {});
          await taskSnapshot.ref.getDownloadURL().then((url) {
            userImageUrl = url;
            AuthenticateSellerAndSignUp();
          });
        }
      } else {
        showDialog(
          context: context,
          builder: (c) {
            return const ErrorDialog(message: "Please fill in all fields");
          },
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (c) {
          return const ErrorDialog(message: "Passwords do not match");
        },
      );
    }
  }

  // Authenticate user and sign up
  void AuthenticateSellerAndSignUp() async {
    User? currentUser;
    await firebaseAuth
        .createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    )
        .then((auth) {
      currentUser = auth.user;
    }).catchError(
      (error) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (c) {
            return ErrorDialog(
              message: error.message.toString(),
            );
          },
        );
      },
    );

    if (currentUser != null) {
      saveDataToFirestore(currentUser!).then((value) {
        Navigator.pop(context);
        // Navigate to Home Screen
        Route newRoute = MaterialPageRoute(builder: (c) => const HomeScreen());
        Navigator.pushReplacement(context, newRoute);
      });
    }
  }

  // Save user data to Firestore
  Future saveDataToFirestore(User currentUser) async {
    FirebaseFirestore.instance.collection("users").doc(currentUser.uid).set(
      {
        "uid": currentUser.uid,
        "email": currentUser.email,
        "name": nameController.text.trim(),
        "photoUrl": userImageUrl,
        "status": "approved",
        "userCart": ['garbageValue'],
      },
    );

    // Save data locally
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences!.setString("uid", currentUser.uid);
    await sharedPreferences!.setString("email", currentUser.email.toString());
    await sharedPreferences!.setString("name", nameController.text.trim());
    await sharedPreferences!.setString("photoUrl", userImageUrl);
    await sharedPreferences!.setStringList(
        "userCart", ['garbageValue']); // Empty cart list on registration
  }

  // Function to get image data
  Future<Uint8List?> getImageData() async {
    if (imageXFile != null) {
      return await imageXFile!.readAsBytes();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: FractionalOffset(-2.0, 0.0),
            end: FractionalOffset(5.0, -1.0),
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFAC898),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Stack(
                children: [
                  const SizedBox(
                    height: 150,
                    child: HeaderWidget(
                      150,
                      false,
                      Icons.add,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    margin: const EdgeInsets.fromLTRB(25, 50, 25, 10),
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () {
                        _getImage();
                      },
                      child: FutureBuilder<Uint8List?>(
                        future: getImageData(),
                        builder: (context, snapshot) {
                          ImageProvider<Object>? imageProvider;
                          
                          if (snapshot.connectionState == ConnectionState.done) {
                            if (snapshot.data != null) {
                              if (kIsWeb) {
                                // For web, create a MemoryImage
                                imageProvider = MemoryImage(snapshot.data!);
                              } else {
                                // For mobile, create a FileImage
                                imageProvider = FileImage(File(imageXFile!.path));
                              }
                            }
                          }

                          return CircleAvatar(
                            radius: MediaQuery.of(context).size.width * 0.20,
                            backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
                            backgroundImage: imageProvider,
                            child: imageXFile == null
                                ? Icon(
                                    Icons.person_add_alt_1,
                                    size: MediaQuery.of(context).size.width * 0.20,
                                    color: Colors.grey,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      data: Icons.person,
                      controller: nameController,
                      hintText: "Name",
                      isObsecre: false,
                    ),
                    CustomTextField(
                      data: Icons.email,
                      controller: emailController,
                      hintText: "Email",
                      isObsecre: false,
                    ),
                    CustomTextField(
                      data: Icons.lock,
                      controller: passwordController,
                      hintText: "Password",
                      isObsecre: true,
                    ),
                    CustomTextField(
                      data: Icons.lock,
                      controller: confirmpasswordController,
                      hintText: "Confirm Password",
                      isObsecre: true,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        signUpFormValidation();
                      },
                      child: const Text("Sign Up"),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()));
                      },
                      child: const Text("Already have an account? Login"),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
