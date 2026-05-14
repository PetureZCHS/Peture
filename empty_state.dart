import 'package:flutter/material.dart';

// ignore_for_file: unused_element

void _addCustomProject(String name, {String? soundPath}) {}
void _showAddProjectDialog() {}

Widget _buildEmptyActionChip(String label, String icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2F36).withOpacity(0.9),
            const Color(0xFF1C1E22).withOpacity(0.9)
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF8B77FF).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5A8EFA).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF5A8EFA).withOpacity(0.3), width: 1),
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 48,
              color: Color(0xFF8B77FF),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            '开启宠物训练',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '响片训练可以有效固定宠物的良好行为。\n挑选一个动作开启第一次互动吧！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildEmptyActionChip('坐下', '🐕', () {
                _addCustomProject('坐下', soundPath: 'mp3/1.mp3');
              }),
              _buildEmptyActionChip('握手', '🤝', () {
                _addCustomProject('握手', soundPath: 'mp3/2.mp3');
              }),
              _buildEmptyActionChip('趴下', '🐾', () {
                _addCustomProject('趴下', soundPath: 'mp3/3.mp3');
              }),
            ],
          ),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('或', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _showAddProjectDialog,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                '自定义专属动作',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF5A8EFA),
                elevation: 0,
                side: const BorderSide(color: Color(0xFF5A8EFA), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
