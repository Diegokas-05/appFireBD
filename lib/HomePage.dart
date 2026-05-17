import 'dart:convert';
import 'dart:typed_data';

import 'package:appFireBD/auth_page.dart';
import 'package:appFireBD/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  final Color primaryColor = Colors.blue;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  Future<void> _addPost() async {
    if (_postController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo o selecciona una imagen')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String imageBase64 = '';

      if (_selectedImage != null) {
        Uint8List imageBytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
      }

      String textoAPublicar = _postController.text.trim();
      String emailUsuario = user?.email ?? 'Usuario';
      String uidUsuario = user?.uid ?? '';

      _postController.clear();
      setState(() {
        _selectedImage = null;
      });

      await FirebaseFirestore.instance.collection('publicaciones_globales').add({
        'content': textoAPublicar,
        'userEmail': emailUsuario,
        'uid': uidUsuario,
        'imageBase64': imageBase64,
        'timestamp': Timestamp.now(),
        'likes': [],
        'dislikes': [],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación creada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId, String currentUid, List likes, List dislikes) async {
    final docRef = FirebaseFirestore.instance.collection('publicaciones_globales').doc(postId);
    if (likes.contains(currentUid)) {
      await docRef.update({'likes': FieldValue.arrayRemove([currentUid])});
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([currentUid]),
        'dislikes': FieldValue.arrayRemove([currentUid])
      });
    }
  }

  Future<void> _toggleDislike(String postId, String currentUid, List likes, List dislikes) async {
    final docRef = FirebaseFirestore.instance.collection('publicaciones_globales').doc(postId);
    if (dislikes.contains(currentUid)) {
      await docRef.update({'dislikes': FieldValue.arrayRemove([currentUid])});
    } else {
      await docRef.update({
        'dislikes': FieldValue.arrayUnion([currentUid]),
        'likes': FieldValue.arrayRemove([currentUid])
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('publicaciones_globales').doc(postId).delete();
  }

  Future<void> _editPost(String postId, String oldContent) async {
    TextEditingController editController = TextEditingController(text: oldContent);
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Editar publicación'),
          content: TextField(controller: editController, maxLines: 4),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('publicaciones_globales')
                    .doc(postId)
                    .update({'content': editController.text.trim()});
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Publicaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
            builder: (context, snapshot) {
              String profileImage = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                profileImage = data['profileImage'] ?? '';
              }
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImage.isNotEmpty ? MemoryImage(base64Decode(profileImage)) : null,
                    child: profileImage.isEmpty ? Icon(Icons.person, color: primaryColor) : null,
                  ),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _postController,
                  maxLines: 3,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: '¿Qué estás pensando?',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_selectedImage != null)
                  FutureBuilder<Uint8List>(
                    future: _selectedImage!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(snapshot.data!, height: 200, width: double.infinity, fit: BoxFit.cover),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : (_selectedImage == null ? _pickImage : () => setState(() => _selectedImage = null)),
                      icon: Icon(_selectedImage == null ? Icons.image : Icons.image_not_supported),
                      label: Text(_selectedImage == null ? 'Imagen' : 'Quitar imagen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedImage == null ? Colors.blue : Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (_postController.text.isNotEmpty || _selectedImage != null)
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          _postController.clear();
                          setState(() { _selectedImage = null; });
                        },
                        child: const Text('Cancelar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addPost,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Publicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('publicaciones_globales').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error al cargar posts'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final posts = snapshot.data!.docs;
                if (posts.isEmpty) return const Center(child: Text('No hay publicaciones'));

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    final content = data['content'] ?? '';
                    final userEmail = data['userEmail'] ?? '';
                    final imageBase64 = data['imageBase64'] ?? '';
                    final String postUid = data['uid'] ?? '';
                    final List likes = data['likes'] ?? [];
                    final List dislikes = data['dislikes'] ?? [];

                    String formattedDate = '';
                    if (data['timestamp'] != null) {
                      formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format((data['timestamp'] as Timestamp).toDate());
                    }

                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor,
                                  child: Text(userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (postUid == currentUser.uid)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _editPost(post.id, content);
                                      if (value == 'delete') _deletePost(post.id);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (content.isNotEmpty) Text(content, style: const TextStyle(fontSize: 16)),
                            if (imageBase64.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(base64Decode(imageBase64), height: 220, width: double.infinity, fit: BoxFit.cover),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(likes.contains(currentUser.uid) ? Icons.thumb_up : Icons.thumb_up_outlined, color: likes.contains(currentUser.uid) ? Colors.blue : Colors.grey),
                                  onPressed: () => _toggleLike(post.id, currentUser.uid, likes, dislikes),
                                ),
                                Text('${likes.length}', style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(dislikes.contains(currentUser.uid) ? Icons.thumb_down : Icons.thumb_down_outlined, color: dislikes.contains(currentUser.uid) ? Colors.red : Colors.grey),
                                  onPressed: () => _toggleDislike(post.id, currentUser.uid, likes, dislikes),
                                ),
                                Text('${dislikes.length}', style: const TextStyle(color: Colors.grey)),
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
      ),
    );
  }
}