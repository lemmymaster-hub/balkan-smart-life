import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B18),
        elevation: 0,
        title: const Text('BSL profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 42,
              backgroundColor: Colors.cyanAccent,
              child: Icon(
                Icons.person,
                color: Color(0xFF070B18),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Nepoznat korisnik',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            _profileCard(
              icon: Icons.stars,
              title: 'BSL bodovi',
              value: '0',
            ),
            _profileCard(
              icon: Icons.local_parking,
              title: 'Parkiraj.ba bodovi',
              value: '0',
            ),
            _profileCard(
              icon: Icons.directions_car,
              title: 'Registrovane tablice',
              value: '0',
            ),
            _profileCard(
              icon: Icons.favorite,
              title: 'Omiljeni parkinzi',
              value: '0',
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1428),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}